globwatcher = require 'globwatcher'
Q = require 'q'
util = require 'util'

logging = require "./logging"

TASK_REGEX = /^[a-z][-a-z0-9_]*$/

# how long to wait to run a job after it is triggered (msec)
QUEUE_DELAY = 100

# task "name",
#   description: "displayed in help"
#   before: "task"  # run immediately before another task, when that task is run
#   after: "task"   # run immediately after another task, when that task is run
#   must: [ "task", "task" ]  # run these dependent tasks first, always
#   watch: [ "file-glob" ]    # run this task when any of these files change
#   run: (options) -> ...     # code to run when executing

class Task
  constructor: (@name, options={}) ->
    if not @name.match TASK_REGEX
      throw new Error("Task name must be letters, digits, - or _")
    @description = options.description or options.desc or "(unknown)"
    run = options.run or (->)
    name = @name
    @run = (options) ->
      logging.info ">>> #{name}"
      logging.debug ">>> #{name}: #{util.inspect(options)}"
      # coerce return value into a promise if it isn't one already.
      Q(run(options))
    @must = options.must
    if typeof @must == "string" then @must = [ @must ]
    @before = options.before?.toString()
    @after = options.after?.toString()
    @watch = options.watch
    if typeof @watch == "string" then @watch = [ @watch ]
    # quick sanity checks
    if @before? and @after?
      throw new Error("Task can be before or after another task, but not both!")
    # list all tasks "covered" by this one, in case of consolidation.
    @covered = [ @name ]

  toString: -> "<Task #{@name}>"

  # combine this task with another, to create a new combined task.
  # the tasks are combined left-to-right, but properties that can't be
  # meaningfully merged are pulled from 'primaryTask'.
  combine: (task, primaryTask) ->
    t = new Task(primaryTask.name, description: primaryTask.description)
    if @watch? or task.watch?
      t.watch = (@watch or []).concat(task.watch or [])
    if @must? or task.must?
      t.must = (@must or [])
      for m in task.must then if t.must.indexOf(m) < 0 then t.must.push(m)
    t.run = (options) => @run(options).then -> task.run(options)
    if primaryTask.before? then t.before = primaryTask.before
    if primaryTask.after? then t.after = primaryTask.after
    for c in @covered.concat(task.covered)
      if t.covered.indexOf(c) < 0 then t.covered.push c
    t


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
        watcher = globwatcher.globwatcher(task.watch, options)
        handler = =>
          if @enqueue(name) then logging.info "* File change triggered: #{name}"
        watcher.on "added", handler
        watcher.on "deleted", handler
        watcher.on "changed", handler
        promises.push watcher.ready
    Q.all(promises)

  # queue a task (by name), and start a timer to actually run it.
  enqueue: (name, args={}) ->
    for [ n, a ] in @queue then if n == name then return false
    @queue.push [ name, args ]
    if not @timer? then @timer = setTimeout((=> @runQueue()), QUEUE_DELAY)
    true

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


exports.TASK_REGEX = TASK_REGEX
exports.QUEUE_DELAY = QUEUE_DELAY
exports.Task = Task
exports.TaskTable = TaskTable
