coffee = require 'coffee-script'
fs = require 'fs'
path = require 'path'
Q = require 'q'
util = require 'util'
vm = require 'vm'

VERSION = "0.1-20130418"
DEFAULT_FILENAME = "Stakerules.coffee"

findRulesFile = (options) ->
  if not options.cwd? then options.cwd = process.cwd()
  if options.filename?
    if options.filename[0] != "/" then options.filename = path.join(options.cwd, options.filename)
    return Q(options) 

  parent = path.dirname(options.cwd)
  while true
    options.filename = path.join(options.cwd, DEFAULT_FILENAME)
    if fs.existsSync(options.filename)
      process.chdir(options.cwd)
      return Q(options)
    if parent == options.cwd then return Q.reject(new Error("Can't find #{DEFAULT_FILENAME}"))
    options.cwd = parent
    parent = path.dirname(parent)

readRulesFile = (filename) ->
  deferred = Q.defer()
  fs.readFile filename, deferred.makeNodeResolver()
  deferred.promise
  .then (data) ->
    data.toString()

compileRulesFile = (filename, script) ->
  try
    script = coffee.compile(script)
    vm.runInNewContext(script, makeContext(), filename)
    Q(true)
  catch error
    Q.reject(error)

tasks = {}
makeContext = ->
  console: console
  task: (name, options) -> tasks[name] = new Task(name, options)

run = (options) ->
  findRulesFile(options)
  .fail (error) ->
    console.log "ERROR: #{error.message}"
    process.exit 1
  .then (options) ->
    readRulesFile(options.filename)
  .fail (error) ->
    console.log "ERROR: Unable to open #{options.filename}: #{error.message}"
    process.exit 1
  .then (script) ->
    compileRulesFile(options.filename, script)
  .fail (error)
    console.log "ERROR: #{filename} failed to execute: #{error.message}"
    process.exit 1
  .then ->
    console.log util.inspect(tasks)
    console.log "done."


class Task
  constructor: (@name, @options) ->
    # FIXME: name must be [a-z]([-a-z0-9_])+

  toString: -> "<Task #{@name}>"


exports.VERSION = VERSION
exports.DEFAULT_FILENAME = DEFAULT_FILENAME
exports.run = run
exports.findRulesFile = findRulesFile
