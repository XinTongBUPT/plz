fs = require 'fs'
path = require 'path'
Q = require 'q'
sprintf = require 'sprintf'
util = require 'util'
vm = require 'vm'

Config = require("./config").Config
context = require("./context")
logging = require("./logging")
rulesfile = require("./rulesfile")
task = require("./task")
task_table = require("./task_table")

DEFAULT_TASK = "build"

parseTaskList = (options) ->
  tasklist = []
  settings = {}
  for word in options.argv.remain
    if word.match task.TASK_REGEX
      tasklist.push word
    else if (m = word.match /([-\w]+)=(.*)/)
      settings[m[1]] = m[2]
    else
      throw new Error("I don't know what to do with '#{word}'")
  if tasklist.length == 0 then tasklist.push DEFAULT_TASK
  options.tasklist = tasklist
  options.settings = settings
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
  rulesfile.loadRules(options)
  .then (table) ->
    table.validate()
    table.consolidate()
    if options.help or options.tasks then displayHelp(table)
    parseTaskList(options)
    for name in options.tasklist
      if not table.getTask(name)? then throw new Error("No task named '#{name}'")
    options.table = table
    for k, v of options.settings then table.settings[k] = v
  .fail (error) ->
    logging.error "#{error.stack}"
    process.exit 1
  .then ->
    table = options.table
    table.activate(persistent: options.run, interval: 250)
  .then ->
    table = options.table
    for name in options.tasklist then table.enqueue(name)
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


exports.run = run
exports.parseTaskList = parseTaskList

