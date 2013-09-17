globwatcher = require 'globwatcher'
Q = require 'q'
util = require 'util'

logging = require("./logging")
statefile = require("./statefile")
Task = require("./task").Task
TaskRunner = require("./task_runner").TaskRunner

# how long to wait to run a job after it is triggered (msec)
QUEUE_DELAY = 100

class TaskTable
  constructor: ->
    @tasks = {}
    @runner = new TaskRunner(@)

  getNames: -> Object.keys(@tasks).sort()
  getTask: (name) -> @tasks[name]
  addTask: (task) -> @tasks[task.name] = task
  allTasks: -> for name in @getNames() then @getTask(name)
  allWatchers: -> [].concat.apply([], for task in @allTasks() then (task.watchers or []))

  validate: ->
    @validateReferences()
    @validateDependenciesExist()
    @validateCycles()

  # make sure each dependency or before/after refers to a real task.
  validateReferences: ->
    missing = {}
    for name, task of @tasks
      if task.before? and (not @tasks[task.before]?)
        (missing[task.before] or= []).push name
      if task.after? and (not @tasks[task.after]?)
        (missing[task.after] or= []).push name
      if task.attach? and (not @tasks[task.attach]?)
        @addTask new Task(task.attach)
      if task.must? then for t in task.must then if not @tasks[t]?
        (missing[t] or= []).push name
    if Object.keys(missing).length > 0
      complaint = (for name, list of missing then "#{name} (referenced by #{list.sort().join(', ')})").sort().join(", ")
      throw new Error("Missing task(s): #{complaint}")

  # can't depend on a task that's before/after some other task (cuz it'll go away in consolidation).
  validateDependenciesExist: ->
    for task in @allTasks()
      for dep in (task.must or []).sort()
        t = @tasks[dep]
        if t.before? or t.after? or t.attach?
          target = t.before or t.after or t.attach?
          throw new Error("Task #{t.name} can't require #{dep} because #{dep} is a decorator for #{target}")

  # look for cycles.
  validateCycles: ->
    copy = (x) ->
      rv = {}
      for k, v of x then rv[k] = v
      rv
    walk = (name, seen={}, path) =>
      task = @tasks[name]
      if not path? then path = [ name ]
      seen[name] = path
      for t in (task.must or []).concat(task.before or [], task.after or [], task.attach or []).sort()
        if seen[t]?
          throw new Error("Dependency loop: #{path.concat(t).join(' -> ')}")
        walk(t, copy(seen), path.concat(t))
    for name in @getNames() then walk(name)

  # combine before/after tasks into the task they're amending.
  consolidate: ->
    # forwarding addresses for tasks we eliminate:
    forwarding = {}
    lookup = (name) =>
      while not @tasks[name]? then name = forwarding[name]
      @tasks[name]
    process = (task, fieldName) =>
      return if not task?
      if task[fieldName]?
        oldtask = lookup(task[fieldName])
        newtask = if fieldName == "before" then task.combine(oldtask, oldtask) else oldtask.combine(task, oldtask)
        forwarding[name] = newtask.name
        @tasks[oldtask.name] = newtask
        delete @tasks[name]
    for name in @getNames() then process(@tasks[name], "before")
    for name in @getNames() then process(@tasks[name], "after")
    for name in @getNames() then process(@tasks[name], "attach")

  runQueue: ->
    @runner.runQueue().then =>
      statefile.saveState(@snapshotWatches())

  # turn on all the watches.
  # options: { persistent, debounceInterval, interval, snapshots }
  activate: (options) ->
    snapshots = options.snapshots
    delete options.snapshots
    options.debug = (text) -> logging.debug "watch: #{text}"
    promises = []
    for task in @allTasks() then do (task) =>
      task.watchers = []
      if task.watch?
        watcher = @activateWatch(task.watch, snapshots, options, task.name, false)
        promises.push watcher.ready
        task.watchers.push watcher
      if task.watchall?
        watcher = @activateWatch(task.watchall, snapshots, options, task.name, true)
        promises.push watcher.ready
        task.watchers.push watcher
    Q.all(promises)

  activateWatch: (watch, snapshots, optionsIn, name, alsoDeletes) ->
    options = {}
    for k, v of optionsIn then options[k] = v
    if snapshots? then options.snapshot = snapshots[watch.join("\n")] or {}
    watcher = globwatcher.globwatcher(watch, options)
    handler = (filename) =>
      if @runner.enqueue(name, filename)
        logging.taskinfo "--- File change triggered: #{name} on #{util.inspect(watch)} by #{filename}"
        @runQueue()
    watcher.on "added", handler
    watcher.on "changed", handler
    if alsoDeletes then watcher.on "deleted", handler
    watcher

  # turn off all watches
  close: ->
    for w in @allWatchers() then w.close()

  # check any watched files, proactively.
  # returns a promise that will be fulfilled when the checks are done.
  checkWatches: ->
    Q.all(for w in @allWatchers() then w.check())

  # return a union of the saved states of any watchers
  snapshotWatches: ->
    snapshots = {}
    for w in @allWatchers()
      key = w.originalPatterns.join("\n")
      snapshots[key] = w.snapshot()
    snapshots

  # return a list of task names, sorted by dependency order, needed for this task.
  # 'skip' is a list of dependencies to skip.
  topoSort: (name, skip = {}) ->
    rv = []
    # make a copy of 'graph' so we don't destroy it. it's mutable in JS.
    tasks = {}
    for k, v of @tasks then tasks[k] = v
    visit = (name) ->
      deps = (tasks[name]?.must or [])
      delete tasks[name]
      for t in deps then if (not skip[t]?) and tasks[t]? then visit(t)
      rv.push name
    visit(name)
    rv

  toDebug: ->
    (for task in @allTasks() then task.toDebug()).join("\n")


exports.QUEUE_DELAY = QUEUE_DELAY
exports.TaskTable = TaskTable
