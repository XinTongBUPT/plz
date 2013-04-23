Q = require 'q'

logging = require "./logging"

TASK_REGEX = /^[a-z][-a-z0-9_]*$/

class Task
  constructor: (@name, options={}) ->
    if not @name.match TASK_REGEX
      throw new Error("Task name must be letters, digits, - or _")
    @description = options.description or options.desc or "(unknown)"
    @block = options.run

  toString: -> "<Task #{@name}>"

  run: (options) ->
    logging.info ">>> #{@name}"
    # coerce return value into a promise if it isn't one already.
    Q(if @block then @block(options) else null)


exports.Task = Task
exports.TASK_REGEX = TASK_REGEX
