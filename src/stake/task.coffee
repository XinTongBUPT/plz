TASK_REGEX = /^[a-z][-a-z0-9_]*$/

class Task
  constructor: (@name, @options={}) ->
    if not @name.match TASK_REGEX
      throw new Error("Task name must be letters, digits, - or _")
    @description = @options.description or @options.desc or "(unknown)"

  toString: -> "<Task #{@name}>"


exports.Task = Task
exports.TASK_REGEX = TASK_REGEX
