Q = require 'q'
simplesets = require 'simplesets'
util = require 'util'

logging = require("./logging")
Set = simplesets.Set

# add a (name, arg) to a list.
# if 'name' is not in the list, [ name, [ arg ] ] is added to the end.
# if 'name' is already in the list, 'arg' is added to the arg-list using the
# same algorithm -- it's only added if it's not already there.
pushUnique = (list, name, arg = []) ->
  for [ n, args ] in list
    if n == name
      for a in arg then if args.indexOf(a) < 0 then args.push a
      return false
  list.push [ name, arg ]
  true

# handle the queue of tasks to run, and run them.
# state:
# - idle: ready to start again on an event
# - running: currently processing a list of queued tasks
# - paused: will not run the queue until un-paused
class TaskRunner
  constructor: (@table) ->
    @queue = []
    @state = "paused"
    @settings = {}
    # if true, trigger another loop through the queue after running.
    @runAgain = false

  start: ->
    if @state == "paused" then @state = "idle"

  pause: ->
    if @state == "idle" then @state = "paused"

  # queue a task (by name). doesn't actually run the queue.
  enqueue: (name, filename = null) ->
    pushUnique @queue, name, (if filename? then (if Array.isArray(filename) then filename else [filename]) else [])

  # run all queued tasks, and their depedencies. 
  # returns a promise that will resolve when all the tasks have run.
  # 'skip' is a set of tasks that have already been run.
  runQueue: (skip = new Set()) ->
    # if we're in the middle of running the queue already, chillax.
    if @state in [ "running", "paused" ]
      @runAgain = true
      return Q(skip)
    # fill in all the dependencies
    tasklist = []
    @flushQueue(tasklist, skip)
    if tasklist.length > 0
      logging.debug "Run tasks: #{tasklist.map((x) -> x[0]).join(' ')}"
    else
      logging.debug "No tasks to run."
    @state = "running"
    @runAgain = false
    @runTasks(tasklist)
    .then (completed) =>
      skip = completed.union(skip)
      again = @runAgain or (@queue.length > 0)
      @state = "idle"
      if again
        @runQueue(skip)
      else
        Q(skip)
    .fail (error) ->
      error.plz.completed = error.plz.completed.union(skip)
      throw error

  # flush the queued tasks (and their dependencies) into a given task list.
  flushQueue: (tasklist = [], skip = new Set()) ->
    for [ name, filenames ] in @queue
      for t in @table.topoSort(name, skip)
        if t == name
          pushUnique tasklist, name, filenames
        else
          pushUnique tasklist, t
    @queue = []
    tasklist

  # loop through a tasklist, running one at a time, skipping dupes.
  runTasks: (tasklist, completed = new Set()) ->
    if tasklist.length == 0 then return Q(completed)
    [ name, filenames ] = tasklist.shift()
    if completed.has(name)
      @runTasks(tasklist, completed)
    else
      @runTask(name, filenames, completed)
      .then =>
        # remove anything from the queue that's already in the current tasklist.
        @queue = @queue.filter ([ name, filenames ]) ->
          for [ tasklistName, tasklistFilenames ] in tasklist
            if name == tasklistName
              for f in filenames then if tasklistFilenames.indexOf(f) < 0 then tasklistFilenames.push(f)
              return false
          true
        @runTasks(tasklist, completed)
      .fail (error) ->
        if not error.plz.tasklist?
          error.plz.tasklist = [ [ name, filenames ] ].concat(tasklist)
          error.plz.completed = completed
        throw error

  # run one task, then check for watch triggers
  runTask: (name, filenames, completed = new Set()) ->
    completed.add(name)
    task = @table.getTask(name)
    context = 
      settings: @settings
      filenames: if filenames.length > 0 then filenames else task.currentSet()
    task.run(context)
    .fail (error) ->
      error.message = "Task '#{name}' failed: #{error.message}"
      error.plz = { task: name }
      throw error
    .then =>
      @table.checkWatches()

exports.TaskRunner = TaskRunner
