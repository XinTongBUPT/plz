coffee = require 'coffee-script'
fs = require 'fs'
path = require 'path'
Q = require 'q'
sprintf = require 'sprintf'
util = require 'util'
vm = require 'vm'

context = require("./context")
logging = require("./logging")
task = require("./task")
task_table = require("./task_table")

VERSION = "0.5-20130605"
DEFAULT_FILENAME = "build.plz"

# ----- load rules

loadRules = (options) ->
  findRulesFile(options)
  .fail (error) ->
    if options.help or options.tasks
      console.log "(No #{DEFAULT_FILENAME} found.)"
      process.exit 0
    logging.error "#{error.message}"
    process.exit 1
  .then (options) ->
    readRulesFile(options.filename)
  .fail (error) ->
    logging.error "Unable to open #{options.filename}: #{error.stack}"
    process.exit 1
  .then (script) ->
    compileRulesFile(options.filename, script)
  .fail (error) ->
    logging.error "#{options.filename} failed to execute: #{error.stack}"
    process.exit 1

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
  table = new task_table.TaskTable()
  try
    sandbox = context.makeContext(filename, table)
    coffee["eval"](script, sandbox: sandbox, filename: filename)
    Q(table)
  catch error
    Q.reject(error)

parseTaskList = (options) ->
  tasklist = []
  globals = {}
  index = -1
  for word in options.argv.remain
    if word.match task.TASK_REGEX
      index += 1
      tasklist.push [ word, {} ]
    else if (m = word.match /([-\w]+)=(.*)/)
      if index < 0
        globals[m[1]] = m[2]
      else
        tasklist[index][1][m[1]] = m[2]
    else
      throw new Error("I don't know what to do with '#{word}'")
  if tasklist.length == 0 then tasklist.push [ "all", {} ]
  options.tasklist = tasklist
  options.globals = globals
  Q(options)

displayHelp = (table) ->
  taskNames = table.getNames()
  width = taskNames.map((x) -> x.length).reduce((a, b) -> Math.max(a, b))
  console.log "Known tasks:"
  for t in taskNames
    console.log sprintf.sprintf("  %#{width}s - %s", t, table.getTask(t).description)
  console.log ""
  process.exit 0

run = (options) ->
  startTime = Date.now()
  loadRules(options)
  .then (table) ->
    table.validate()
    table.consolidate()
    if options.help or options.tasks then displayHelp(table)
    parseTaskList(options)
    for [ name, args ] in options.tasklist
      if not table.getTask(name)? then throw new Error("No task named '#{name}'")
    options.table = table
  .fail (error) ->
    logging.error "#{error.stack}"
    process.exit 1
  .then ->
    table = options.table
    table.activate(persistent: options.run, interval: 250)
  .then ->
    table = options.table
    for [ name, args ] in options.tasklist then table.enqueue(name, args)
    table.runQueue()
  .then ->
    if options.run
      logging.taskinfo "Watching for changes..."
    else
      duration = Date.now() - startTime
      if duration <= 2000
        humanTime = "#{duration} milliseconds"
      else if duration <= 120000
        humanTime = sprintf.sprintf("%.1f seconds", duration / 1000.0)
      else
        humanTime = "#{Math.floor(duration / 60000.0)} minutes"
      logging.notice "Finished in #{humanTime}."
  .fail (error) ->
    logging.error error.message
    logging.info error.stack


exports.VERSION = VERSION
exports.DEFAULT_FILENAME = DEFAULT_FILENAME
exports.run = run
exports.findRulesFile = findRulesFile
exports.compileRulesFile = compileRulesFile
exports.parseTaskList = parseTaskList

