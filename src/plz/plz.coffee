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
SETTING_RE = /^(\w[-\w]*)=(.*)$/

parseTaskList = (options, settings={}) ->
  tasklist = []
  for word in options.argv.remain
    if word.match task.TASK_REGEX
      tasklist.push word
    else if (m = word.match SETTING_RE)
      settings[m[1]] = m[2]
    else
      throw new Error("I don't know what to do with '#{word}'")
  if tasklist.length == 0 then tasklist.push DEFAULT_TASK
  options.tasklist = tasklist
  [ tasklist, settings ]

readRcFile = (settings) ->
  filename = if process.env["PLZRC"]?
    process.env["PLZRC"]
  else
    user_home = process.env["HOME"] or process.env["USERPROFILE"]
    "#{user_home}/.plzrc"
  if fs.existsSync(filename)
    deferred = Q.defer()
    fs.readFile filename, (error, data) ->
      if error?
        deferred.reject(error)
      else
        for line in data.toString().split("\n")
          line = line.trim()
          if line.match /^\#/
            # ignore
          else if (m = line.match SETTING_RE)
            settings[m[1]] = m[2]
        deferred.resolve(settings)
    deferred.promise
  else
    Q(settings)

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
    options.table = table
    readRcFile(table.settings)
  .then (settings) ->
    table = options.table
    parseTaskList(options, settings)
    logging.debug "Settings: #{util.inspect(settings)}"
    for name in options.tasklist
      if not table.getTask(name)? then throw new Error("No task named '#{name}'")
    table.activate(persistent: options.run, interval: 250)
  .fail (error) ->
    logging.error "#{error.stack}"
    process.exit 1
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

