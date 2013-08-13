#
# build a vm context object with globals that can be used by tasks.
#

child_process = require 'child_process'
glob = require 'glob'
path = require 'path'
Q = require 'q'
shell = require 'shelljs'
touch = require 'touch'
util = require 'util'

Config = require("./config").Config
logging = require("./logging")
plugins = require("./plugins")
task = require("./task")

# commands to copy from shelljs into globals.
ShellCommands = [
  "cat", "cd", "chmod", "cp", "dirs", "echo", "env", "exit", "find", "grep",
  "ls", "mkdir", "mv", "popd", "pushd", "pwd", "rm", "sed", "test", "which"
]

exec = (command, options={}) ->
  if typeof command == "string"
    logging.info "+ #{command}"
    # i bet this doesn't work on windows.
    command = [ "/bin/sh", "-c", command ]
  else
    logging.info "+ #{trace(command)}"
  if not options.env? then options.env = process.env
  if not options.cwd? then options.cwd = process.cwd()
  if not options.stdio? then options.stdio = "inherit"

  deferred = Q.defer()
  p = child_process.spawn command[0], command[1...], options
  logging.debug "spawn #{p.pid}: #{util.inspect(command)}"
  p.on "exit", (code, signal) ->
    if signal?
      deferred.reject(new Error("Killed by signal: #{signal}"))
    else if code? and code != 0
      deferred.reject(new Error("Exit code: #{code}"))
    else
      logging.debug "spawn #{p.pid} finished"
      deferred.resolve(p)
  p.on "error", (error) ->
    logging.error error.message
    deferred.reject(error)

  promise = deferred.promise
  promise.process = p
  promise

trace = (args) -> args.map((x) -> util.inspect(x)).join(' ')

defaultGlobals =
  # copy from node
  console: console
  process: process
  Buffer: Buffer
  Q: Q
  glob: (pattern, options) ->
    deferred = Q.defer()
    glob pattern, options, (error, files) ->
      if error? then deferred.reject(error) else deferred.resolve(files)
    deferred.promise
  # logging:
  debug: logging.debug
  info: logging.info
  notice: logging.notice
  warning: logging.warning
  error: logging.error
  mark: logging.mark
  # local convenience
  touch: (args...) ->
    logging.info "+ touch #{trace(args)}"
    touch.sync(args...)
  exec: exec
  plz: Config
  load: plugins.load
  plugins: plugins.plugins
  extend: (map1, map2) ->
    for k, v of map2 then map1[k] = v
    map1

makeContext = (filename, table) ->
  globals = {}
  for k, v of defaultGlobals then globals[k] = v
  for command in ShellCommands then do (command) ->
    globals[command] = (args...) ->
      logging.info "+ #{command} #{trace(args)}"
      shell[command](args...)

  # define new task
  globals.task = (name, options) ->
    logging.debug "Defining task: #{name}"
    table.addTask(new task.Task(name, options))
  globals.runTask = (name, args={}) ->
    logging.debug "Injecting task: #{name}"
    table.runner.enqueue(name, args)

  globals.settings = table.runner.settings

  # stub in a "project" object for plugins to play with.
  globals.project =
    name: path.basename(process.cwd())
    type: "basic"

  plugins.createContext(filename, globals)

exports.makeContext = makeContext
