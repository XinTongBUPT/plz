Q = require 'q'
simplesets = require 'simplesets'
util = require 'util'

logging = require("./logging")
statefile = require("./statefile")
Task = require("./task").Task
TaskRunner = require("./task_runner").TaskRunner
Set = simplesets.Set

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
    for name in @getNames() then process(@tasks[name], "attach")
    for name in @getNames() then process(@tasks[name], "after")

  # enqueue tasks that should always run (at startup)
  enqueueAlways: ->
    for task in @allTasks() then if task.always then @runner.enqueue(task.name)

  runQueue: ->
    @runner.runQueue()
    .then (completed) =>
      @saveState(completed?.size(), [])
    .fail (error) =>
      @saveState(error.plz?.completed?.size(), error.plz?.tasklist) ->
        throw error

  saveState: (completedCount, incomplete) ->
    if completedCount? and completedCount > 0
      state =
        version: 1
        snapshots: @snapshotWatches()
        incomplete: incomplete or []
      statefile.saveState(state)
    else
      Q(null)

  # turn on all the watches.
  activate: (snapshots, options) ->
    Q.all(
      for task in @allTasks() then do (task) =>
        handler = (filename, watch) =>
          logging.debug "File changed: #{filename} detected by #{util.inspect(watch)}"
          if @runner.enqueue(task.name, filename)
            logging.taskinfo "--- File change triggered: #{task.name}"
            @runQueue()
        task.activateWatches(options, snapshots, handler)
    )

  # turn off all watches
  close: ->
    for w in @allWatchers() then w.close()

  # check any watched files, proactively.
  # returns a promise that will be fulfilled when the checks are done.
  checkWatches: ->
    logging.debug "Check watches..."
    Q.all(for w in @allWatchers() then w.check()).then ->
      logging.debug "...done checking watches."

  # return a union of the saved states of any watchers
  snapshotWatches: ->
    snapshots = {}
    for w in @allWatchers()
      key = w.originalPatterns.join("\n")
      snapshots[key] = w.snapshot()
    snapshots

  # return a list of task names, sorted by dependency order, needed for this task.
  # 'skip' is a list of dependencies to skip.
  topoSort: (name, skip = new Set()) ->
    rv = []
    # make a copy of 'graph' so we don't destroy it. it's mutable in JS.
    tasks = {}
    for k, v of @tasks then tasks[k] = v
    visit = (name) ->
      deps = (tasks[name]?.must or [])
      delete tasks[name]
      for t in deps then if (not skip.has(t)) and tasks[t]? then visit(t)
      rv.push name
    visit(name)
    rv

  toDebug: ->
    (for task in @allTasks() then task.toDebug()).join("\n")


exports.QUEUE_DELAY = QUEUE_DELAY
exports.TaskTable = TaskTable
