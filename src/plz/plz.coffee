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

VERSION = "0.1-20130418"
DEFAULT_FILENAME = "plz-rules.coffee"

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
  table = new task.TaskTable()
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

runTasks = (tasklist, table, executed={}) ->
  if tasklist.length == 0 then return Q(true)
  [ name, args ] = tasklist.shift()
  if executed[name]?
    runTasks(tasklist, table, executed)
  else
    executed[name] = true
    table.getTask(name).run(args).then ->
      runTasks(tasklist, table, executed)

run = (options) ->
  startTime = Date.now()
  findRulesFile(options)
  .fail (error) ->
    if options.help
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
  .then (table) ->
    table.validate()
    table.consolidate()
    options.table = table
    options
  .fail (error) ->
    logging.error "#{error.stack}"
    process.exit 1
  .then (options) ->
    if options.help then displayHelp(options.table)
    parseTaskList(options)
  .fail (error) ->
    logging.error "#{error.stack}"
    process.exit 1
  .then (options) ->
    tasklist = []
    table = options.table
    for [ name, args ] in options.tasklist
      if not table.getTask(name)?
        logging.error "No task named '#{name}'"
        process.exit 1
      for t in table.topoSort(name)
        tasklist.push(if t == name then [ name, args ] else [ t, {} ])
    logging.debug "Run tasks: #{tasklist.map((x) -> x[0]).join(' ')}"
    runTasks(tasklist, table)
  .then ->
    duration = Date.now() - startTime
    logging.notice "Finished in #{duration} msec."


exports.VERSION = VERSION
exports.DEFAULT_FILENAME = DEFAULT_FILENAME
exports.run = run
exports.findRulesFile = findRulesFile
exports.compileRulesFile = compileRulesFile
exports.parseTaskList = parseTaskList

