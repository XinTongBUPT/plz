coffee = require 'coffee-script'
fs = require 'fs'
path = require 'path'
Q = require 'q'
util = require 'util'
vm = require 'vm'

context = require("./context")

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
  tasks = {}
  try
    sandbox = context.makeContext(filename, tasks)
    coffee["eval"](script, sandbox: sandbox, filename: filename)
    Q(tasks)
  catch error
    Q.reject(error)


run = (options) ->
  findRulesFile(options)
  .fail (error) ->
    console.log "ERROR: #{error.stack}"
    process.exit 1
  .then (options) ->
    readRulesFile(options.filename)
  .fail (error) ->
    console.log "ERROR: Unable to open #{options.filename}: #{error.stack}"
    process.exit 1
  .then (script) ->
    compileRulesFile(options.filename, script)
  .fail (error) ->
    console.log "ERROR: #{options.filename} failed to execute: #{error.stack}"
    process.exit 1
  .then ->
    console.log util.inspect(Object.keys(tasks).map((x) -> tasks[x].toString()))
    console.log "done."


exports.VERSION = VERSION
exports.DEFAULT_FILENAME = DEFAULT_FILENAME
exports.run = run
exports.findRulesFile = findRulesFile
exports.compileRulesFile = compileRulesFile

