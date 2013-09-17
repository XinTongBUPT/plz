Q = require 'q'
util = require 'util'

logging = require "./logging"

TASK_REGEX = /^[a-z][-a-z0-9_]*$/

# task "name",
#   description: "displayed in help"
#   before: "task"  # run immediately before another task, when that task is run
#   after: "task"   # run immediately after another task, when that task is run
#   attach: "task"  # run immediately after another task, or if that task doesn't exist, replace it
#   must: [ "task", "task" ]  # run these dependent tasks first, always
#   watch: [ "file-glob" ]    # run this task when any of these files change
#   watchall: [ "file-glob" ] # run this task when any of these files change or are deleted
#   run: (options) -> ...     # code to run when executing

class Task
  constructor: (@name, options={}) ->
    if not @name.match TASK_REGEX
      throw new Error("Task name must be letters, digits, - or _")
    @description = options.description or options.desc or "(unknown)"
    run = options.run or (->)
    name = @name
    @run = (settings) ->
      logging.taskinfo ">>> #{name}"
      # coerce return value into a promise if it isn't one already.
      Q(run(settings))
    @must = options.must
    if typeof @must == "string" then @must = [ @must ]
    @before = options.before?.toString()
    @after = options.after?.toString()
    @attach = options.attach?.toString()
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
    if @must? or task.must?
      t.must = (@must or [])
      if task.must? then for m in task.must then if t.must.indexOf(m) < 0 then t.must.push(m)
    t.run = (options) => @run(options).then -> task.run(options)
    if primaryTask.before? then t.before = primaryTask.before
    if primaryTask.after? then t.after = primaryTask.after
    for c in @covered.concat(task.covered)
      if t.covered.indexOf(c) < 0 then t.covered.push c
    t

  toDebug: ->
    "#{@name}: must=#{util.inspect(@must)} description=#{util.inspect(@description)} watch=#{@watch} watchall=#{@watchall} before=#{@before} after=#{@after} attach=#{@attach}"


exports.TASK_REGEX = TASK_REGEX
exports.Task = Task
