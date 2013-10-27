#
# if tasks are listed on the CLI, don't run watches first.
#

fs = require 'fs'
path = require 'path'
Q = require 'q'
util = require 'util'

context = require("./context")
Config = require("./config").Config
logging = require("./logging")
plugins = require("./plugins")
TaskTable = require("./task_table").TaskTable

DEFAULT_FILENAME = "build.plz"
BUILTINS_HOME = path.join path.dirname(__filename), "../../node_modules/plz-builtins/lib/plz-builtins.js"
BUILTINS = fs.readFileSync(BUILTINS_HOME)

# scan the path for a rules file and compile it. returns a Future[TaskTable]
# if successful.
loadRules = (options, settings={}) ->
  try
    findRulesFile(options)
  catch error
    if options.help or options.tasks
      console.log "(No #{DEFAULT_FILENAME} found.)"
      process.exit 0
    logging.error "#{error.message}"
    process.exit 1
  compileRulesFile(settings).fail ->
    process.exit 1

findRulesFile = (options={}) ->
  if options.filename?
    if options.filename[0] != "/" then options.filename = path.join(Config.cwd(), options.filename)
    Config.rulesFile(options.filename)
    return
  if process.env["PLZ_RULES"]?
    Config.rulesFile(process.env["PLZ_RULES"])
    return
  parent = path.dirname(Config.cwd())
  while true
    filename = path.join(Config.cwd(), DEFAULT_FILENAME)
    if fs.existsSync(filename)
      process.chdir(Config.cwd())
      Config.rulesFile(filename)
      return
    if parent == Config.cwd() then throw new Error("Can't find #{DEFAULT_FILENAME}")
    Config.cwd(parent)
    parent = path.dirname(parent)

compileRulesFile = (settings) ->
  deferred = Q.defer()
  fs.readFile Config.rulesFile(), (error, data) ->
    try
      if error?
        logging.error("Unable to open #{Config.rulesFile()}: #{error.stack}")
        throw error
      deferred.resolve(compile(data, settings))
    catch error
      logging.error "#{Config.rulesFile()} failed to execute: #{error.stack}"
      deferred.reject(error)
  deferred.promise

compile = (data, settings={}) ->
  table = new TaskTable()
  table.runner.settings = settings
  globals = context.makeContext(table)
  loader = new plugins.ModuleLoader()
  loader.load("require(\"#{BUILTINS_HOME}\");", "<builtins>", globals)
  loader.load(data, Config.rulesFile() or "<build.plz>", globals)
  table


exports.loadRules = loadRules
exports.findRulesFile = findRulesFile
exports.compileRulesFile = compileRulesFile
exports.compile = compile
exports.DEFAULT_FILENAME = DEFAULT_FILENAME
