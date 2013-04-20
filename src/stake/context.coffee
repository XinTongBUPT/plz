#
# build a vm context object with globals that can be used by tasks.
#

path = require 'path'
shell = require 'shelljs'
touch = require 'touch'
vm = require 'vm'

Task = require("./task").Task

# commands to copy from shelljs into globals.
ShellCommands = [
  "cat", "cd", "chmod", "cp", "dirs", "echo", "env", "exit", "find", "grep",
  "ls", "mkdir", "mv", "popd", "pushd", "pwd", "rm", "sed", "test", "which"
]

# gibberish copied over from coffee-script.
magick = (filename, context) ->
  Module = require('module')

  # this feels wrong, like we're missing some "normal" way to initialize a new node module.
  m = new Module("Stakerules")
  m.filename = filename
  r = (path) -> Module._load(path, m, true)
  for key, value of require then if key != "paths" then r[key] = require[key]
  r.paths = m.paths = Module._nodeModulePaths(path.dirname(filename))
  r.resolve = (request) -> Module._resolveFilename(request, m)

  context.module = m
  context.require = r

makeContext = (filename, tasks) ->
  globals =
    # copy from node
    console: console
    process: process
    Buffer: Buffer

    task: (name, options) -> tasks[name] = new Task(name, options)

  for command in ShellCommands
    globals[command] = shell[command]
  globals.touch = touch.sync

  magick(filename, globals)
  vm.createContext(globals)


exports.makeContext = makeContext

# to-do:
#   - exec
#   - logging
# execute another task
