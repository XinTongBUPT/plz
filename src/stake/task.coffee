class Task
  constructor: (@name, @options) ->
    # FIXME: name must be [a-z]([-a-z0-9_])+

  toString: -> "<Task #{@name}>"


exports.Task = Task
