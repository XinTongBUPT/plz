globwatcher = require 'globwatcher'
Q = require 'q'
simplesets = require 'simplesets'
util = require 'util'

logging = require "./logging"

Set = simplesets.Set

TASK_REGEX = /^[a-z][-a-z0-9_]*$/

cloneOptions = (options) ->
  rv = {}
  for k, v of options then rv[k] = v
  rv

# merge two lists, keeping only the unique items.
mergeUnique = (a, b) ->
  rv = a[...]
  if b? then for item in b then if rv.indexOf(item) < 0 then rv.push(item)
  rv

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

# task "name",
#   description: "displayed in help"
#   before: "task"  # run immediately before another task, when that task is run
#   after: "task"   # run immediately after another task, when that task is run
#   attach: "task"  # run immediately after another task, or if that task doesn't exist, replace it
#   depends: [ "task", "task" ]     # if these tasks will run in the same execution, run them first
#   must: [ "task", "task" ]        # run these dependent tasks first, always
#   watch: [ "file-glob" ]          # run this task when any of these files change
#   watchall: [ "file-glob" ]       # run this task when any of these files change or are deleted
#   always: true    # run this task always
#   run: (context) -> ...           # code to run when executing

class Task
  constructor: (@name, options={}) ->
    if not @name.match TASK_REGEX
      throw new Error("Task name must be letters, digits, - or _")
    @description = options.description or options.desc or "(unknown)"
    run = options.run or (->)
    name = @name
    @run = (context) ->
      logging.taskinfo ">>> #{name}"
      # coerce return value into a promise if it isn't one already.
      try
        Q(run(context))
      catch e
        Q.reject(e)
    @must = options.must
    if typeof @must == "string" then @must = [ @must ]
    @depends = options.depends
    if typeof @depends == "string" then @depends = [ @depends ]
    @before = options.before?.toString()
    @after = options.after?.toString()
    @attach = options.attach?.toString()
    @always = options.always or false
    @watch = options.watch
    if typeof @watch == "string" then @watch = [ @watch ]
    @watchall = options.watchall
    if typeof @watchall == "string" then @watchall = [ @watchall ]
    # quick sanity checks
    if (@before? and @after?) or (@before? and @attach?) or (@after? and @attach?)
      throw new Error("Task can be only be one of: before, after, attach")
    # list all tasks "covered" by this one, in case of consolidation.
    @covered = [ @name ]

  toString: -> "<Task #{@name}>"

  # combine this task with another, to create a new combined task.
  # the tasks are combined left-to-right, but properties that can't be
  # meaningfully merged are pulled from 'primaryTask'.
  combine: (task, primaryTask) ->
    t = new Task(primaryTask.name, description: primaryTask.description)
    if t.description == "(unknown)" then t.description = task.description
    if @watch? or task.watch?
      t.watch = (@watch or []).concat(task.watch or [])
    if @must? or task.must? then t.must = mergeUnique(@must or [], task.must)
    if @depends? or task.depends? then t.depends = mergeUnique(@depends or [], task.depends)
    t.run = (options) => @run(options).then -> task.run(options)
    if primaryTask.before? then t.before = primaryTask.before
    if primaryTask.after? then t.after = primaryTask.after
    for c in @covered.concat(task.covered)
      if t.covered.indexOf(c) < 0 then t.covered.push c
    t

  # turn on watches, if present.
  # options: { persistent, debounceInterval, interval }
  activateWatches: (optionsIn, snapshots, handler) ->
    @watchers = []
    for item in [ [ @watch, false ], [ @watchall, true ] ]
      [ w, alsoDeletes ] = item
      if w? then do (w) =>
        options = cloneOptions(optionsIn)
        options.snapshot = snapshots[w.join("\n")] or {}
        options.debug = (text) => logging.debug "watch (#{@name}): #{text}"
        watcher = globwatcher.globwatcher(w, options)
        h = (filename) -> handler(filename, w)
        watcher.on "added", h
        watcher.on "changed", h
        if alsoDeletes then watcher.on "deleted", h
        @watchers.push watcher
    Q.all(for w in @watchers then w.ready)

  # collect currentSet() for all watchers
  currentSet: ->
    rv = new Set()
    for w in (@watchers or []) then rv = rv.union(new Set(w.currentSet()))
    rv.array()

  toDebug: ->
    "#{@name}: must=#{util.inspect(@must)} description=#{util.inspect(@description)} watch=#{@watch} watchall=#{@watchall} before=#{@before} after=#{@after} attach=#{@attach}"


exports.TASK_REGEX = TASK_REGEX
exports.Task = Task
