logging = require("./logging")
Q = require 'q'
util = require 'util'

# add a [ name, args ] to a list, but only if the named task isn't already in the list.
pushUnique = (list, name) ->
  for n in list then if n == name then return false
  list.push name
  true

# handle the queue of tasks to run, and run them.
class TaskRunner
  constructor: (@table) ->
    @queue = []
    @state = "waiting"
    @settings = {}

  # queue a task (by name). doesn't actually run the queue.
  enqueue: (name) ->
    pushUnique @queue, name

  # run all queued tasks, and their depedencies. 
  # returns a promise that will resolve when all the tasks have run.
  # 'skip' is a set of tasks that have already been run.
  runQueue: (skip = {}) ->
    # if we're in the middle of running the queue already, chillax.
    if @state in [ "running", "run-again" ]
      @state = "run-again"
      return
    # fill in all the dependencies
    tasklist = []
    @flushQueue(tasklist, skip)
    logging.debug "Run tasks: #{tasklist.join(' ')}"
    @state = "running"
    @runTasks(tasklist).then =>
      again = (@state == "run-again") or (@queue.length > 0)
      @state = "waiting"
      if again then @runQueue(skip)

  # flush the queued tasks (and their dependencies) into a given task list.
  flushQueue: (tasklist = [], skip = {}) ->
    for name in @queue
      for t in @table.topoSort(name, skip)
        if t == name
          pushUnique tasklist, name
        else
          pushUnique tasklist, t
    @queue = []
    tasklist

  # loop through a tasklist, running one at a time, skipping dupes.
  runTasks: (tasklist, skip = {}) ->
    if tasklist.length == 0 then return Q(true)
    name = tasklist.shift()
    (if skip[name]? then Q(null) else @runTask(name, skip)).then =>
      # remove anything from the queue that's already in the current tasklist.
      @queue = @queue.filter ([ name, args ]) ->
        for [ n, a ] in tasklist then if name == n then return false
        true
      @runTasks(tasklist, skip)

  # run one task, then check for watch triggers
  runTask: (name, skip = {}) ->
    skip[name] = true
    @table.getTask(name).run(@settings)
    .fail (error) ->
      error.message = "Task '#{name}' failed: #{error.message}"
      throw error
    .then =>
      @table.checkWatches()

exports.TaskRunner = TaskRunner
