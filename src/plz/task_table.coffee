globwatcher = require 'globwatcher'
Q = require 'q'
util = require 'util'

logging = require("./logging")
Task = require("./task").Task

# how long to wait to run a job after it is triggered (msec)
QUEUE_DELAY = 100

class TaskTable
  constructor: ->
    @tasks = {}
    @queue = []
    @state = "waiting"
    @settings = {}

  getNames: -> Object.keys(@tasks).sort()
  getTask: (name) -> @tasks[name]
  addTask: (task) -> @tasks[task.name] = task

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
    for name in @getNames()
      task = @tasks[name]
      for dep in (task.must or []).sort()
        t = @tasks[dep]
        if t.before? or t.after? or t.attach?
          target = t.before or t.after or t.attach?
          throw new Error("Task #{name} can't require #{dep} because #{dep} is a decorator for #{target}")

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

  # turn on all the watches.
  # options: { persistent, debounceInterval, interval }
  activate: (options) ->
    options.debug = (text) -> logging.debug "watch: #{text}"
    promises = []
    for name in @getNames() then do (name) =>
      task = @getTask(name)
      if task.watch?
        watcher = globwatcher.globwatcher(task.watch, options)
        handler = =>
          if @enqueue(name)
            logging.taskinfo "--- File change triggered: #{name}"
            @runQueue()
        watcher.on "added", handler
        watcher.on "deleted", handler
        watcher.on "changed", handler
        promises.push watcher.ready
        task.watcher = watcher
    Q.all(promises)

  # turn off all watches
  close: ->
    for name in @getNames()
      task = @getTask(name)
      if task.watcher? then task.watcher.close()

  # queue a task (by name). doesn't actually run the queue.
  enqueue: (name) ->
    @pushUnique @queue, name

  # run all queued tasks, and their depedencies. 
  # returns a promise that will resolve when all the tasks have run.
  runQueue: ->
    # if we're in the middle of running the queue already, chillax.
    if @state in [ "running", "run-again" ]
      @state = "run-again"
      return
    # fill in all the dependencies
    tasklist = @flushQueue([])
    logging.debug "Run tasks: #{tasklist.join(' ')}"
    @state = "running"
    @runTasks(tasklist).then =>
      again = (@state == "run-again") or (@queue.length > 0)
      @state = "waiting"
      if again then @runQueue()

  # loop through a tasklist, running one at a time, skipping dupes.
  runTasks: (tasklist, executed={}) ->
    if tasklist.length == 0 then return Q(true)
    name = tasklist.shift()
    (if executed[name]? Q(null) else @runTask(name, executed)).then =>
      # remove anything from the queue that's already in the current tasklist.
      @queue = @queue.filter ([ name, args ]) ->
        for [ n, a ] in tasklist then if name == n then return false
        true
      @runTasks(tasklist, executed)

  # run one task, then check for watch triggers
  runTask: (name, executed={}) ->
    executed[name] = true
    @getTask(name).run(@settings)
    .fail (error) ->
      error.message = "Task '#{name}' failed: #{error.message}"
      throw error
    .then =>
      @checkWatches()

  # check any watched files, proactively.
  # returns a promise that will be fulfilled when the checks are done.
  checkWatches: ->
    Q.all(
      for name in @getNames()
        task = @getTask(name)
        if task.watcher? then task.watcher.check() else Q(null)
    )

  # flush the queued tasks (and their dependencies) into a given task list.
  flushQueue: (tasklist = [], executed = {}) ->
    for name in @queue
      for t in @topoSort(name)
        if t == name
          @pushUnique tasklist, name
        else
          @pushUnique tasklist, t
    @queue = []
    tasklist

  # return a list of task names, sorted by dependency order, needed for this task.
  topoSort: (name) ->
    rv = []
    # make a copy of 'graph' so we don't destroy it. it's mutable in JS.
    tasks = {}
    for k, v of @tasks then tasks[k] = v
    visit = (name) ->
      for t in (tasks[name]?.must or []) then visit(t)
      delete tasks[name]
      rv.push name
    visit(name)
    rv

  # add a [ name, args ] to a list, but only if the named task isn't already in the list.
  pushUnique: (list, name) ->
    for n in list then if n == name then return false
    list.push name
    true


exports.QUEUE_DELAY = QUEUE_DELAY
exports.TaskTable = TaskTable
