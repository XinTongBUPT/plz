logging = require("./logging")
Q = require 'q'
util = require 'util'

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
class TaskRunner
  constructor: (@table) ->
    @queue = []
    @state = "waiting"
    @settings = {}

  # queue a task (by name). doesn't actually run the queue.
  enqueue: (name, filename = null) ->
    pushUnique @queue, name, (if filename? then [filename] else [])

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
    @runTasks(tasklist).then (completed) =>
      again = (@state == "run-again") or (@queue.length > 0)
      @state = "waiting"
      if again
        for name, v of completed then skip[name] = true
        @runQueue(skip)

  # flush the queued tasks (and their dependencies) into a given task list.
  flushQueue: (tasklist = [], skip = {}) ->
    for [ name, filenames ] in @queue
      for t in @table.topoSort(name, skip)
        if t == name
          pushUnique tasklist, name, filenames
        else
          pushUnique tasklist, t
    @queue = []
    tasklist

  # loop through a tasklist, running one at a time, skipping dupes.
  runTasks: (tasklist, completed = {}) ->
    if tasklist.length == 0 then return Q(completed)
    [ name, filenames ] = tasklist.shift()
    if completed[name]?
      @runTasks(tasklist, completed)
    else
      @runTask(name, filenames, completed).then =>
        # remove anything from the queue that's already in the current tasklist.
        @queue = @queue.filter ([ name, filenames ]) ->
          for [ tasklist_name, tasklist_filenames ] in tasklist
            if name == tasklist_name
              for f in filenames then if tasklist_filenames.indexOf(f) < 0 then tasklist_filenames.push(f)
              return false
          true
        @runTasks(tasklist, completed)

  # run one task, then check for watch triggers
  runTask: (name, filenames, completed = {}) ->
    completed[name] = true
    context = { settings: @settings }
    if filenames.length > 0 then context.changed_files = filenames
    task = @table.getTask(name)
    for w in (task.watchers or []) then context.current_files = (context.current_files or []).concat(w.currentSet())
    task.run(context)
    .fail (error) ->
      error.message = "Task '#{name}' failed: #{error.message}"
      throw error
    .then =>
      @table.checkWatches()

exports.TaskRunner = TaskRunner
