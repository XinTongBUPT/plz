globwatcher = require 'globwatcher'
logging = require "./logging"
Q = require 'q'

# how long to wait to run a job after it is triggered (msec)
QUEUE_DELAY = 100

class TaskTable
  constructor: ->
    @tasks = {}
    @timer = null
    @queue = []
    @state = "waiting"

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
        if t.before? or t.after?
          target = t.before or t.after
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
      for t in (task.must or []).concat(task.before or [], task.after or []).sort()
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

  # turn on all the watches.
  # options: { persistent, debounceInterval, interval }
  activate: (options) ->
    options.debug = logging.debug
    promises = []
    for name in @getNames()
      task = @getTask(name)
      if task.watch?
        watcher = globwatcher.globwatcher(task.watch, persistent: false)
        handler = =>
          if @enqueue(name) then logging.info "* File change triggered: #{name}"
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

  # queue a task (by name), and start a timer to actually run it.
  enqueue: (name, args={}) ->
    for [ n, a ] in @queue then if n == name then return false
    @queue.push [ name, args ]
    if not @timer? then @timer = setTimeout((=> @runQueue()), QUEUE_DELAY)
    true

  # run all queued tasks, and their dependencies, using runQueue.
  # then scan for updated files, and if any new tasks are enqueued by the
  # watches, run them. loop until no more tasks are queued.
  runQueueWithWatches: ->
    @runQueue().then =>
      Q.all(
        for name in @getNames()
          task = @getTask(name)
          if task.watcher? then task.watcher.check() else Q(null)
      )
    .then =>
      if @queue.length > 0
        logging.debug "Watched files triggered #{@queue.length} new tasks; running them."
        @runQueueWithWatches()

  # run all queued tasks, and their depedencies. 
  # returns a promise that will resolve when all the tasks have run.
  runQueue: ->
    # if we're in the middle of running the queue already, chillax.
    if @state in [ "running", "run-again" ]
      @state = "run-again"
      return
    if @timer? then clearTimeout(@timer)
    @timer = null
    # fill in all the dependencies
    tasklist = []
    for [ name, args ] in @queue
      for t in @topoSort(name)
        tasklist.push(if t == name then [ name, args ] else [ t, {} ])
    @queue = []
    logging.debug "Run tasks: #{tasklist.map((x) -> x[0]).join(' ')}"
    @state = "running"
    @runTasks(tasklist).then =>
      again = @state == "run-again"
      @state = "waiting"
      if again then @runQueue()

  # loop through a tasklist, running one at a time, skipping dupes.
  runTasks: (tasklist, executed={}) ->
    if tasklist.length == 0 then return Q(true)
    [ name, args ] = tasklist.shift()
    if executed[name]?
      @runTasks(tasklist, executed)
    else
      executed[name] = true
      @getTask(name).run(args)
      .fail (error) ->
        error.message = "Task '#{name}' failed: #{error.message}"
        throw error
      .then =>
        @runTasks(tasklist, executed)

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


exports.QUEUE_DELAY = QUEUE_DELAY
exports.TaskTable = TaskTable
