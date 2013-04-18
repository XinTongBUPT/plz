child_process = require 'child_process'
fs = require 'fs'
mocha = require 'mocha'
Q = require 'q'
util = require 'util'

exec = (args...) ->
  command = args.shift()
  process = child_process.spawn command, args
  process.stderr.on "data", (data) -> util.print(data.toString())
  process.stdout.on "data", (data) -> util.print(data.toString())
  deferred = Q.defer()
  process.on 'exit', (code) -> deferred.resolve(code)
  deferred.promise

run = (command) ->
  console.log "\u001b[35m+ " + command + "\u001b[0m"
  exec("/bin/sh", "-c", command).then (exitCode) ->
    if exitCode != 0
      console.error "\u001b[31m! Execution failed. :(\u001b[0m"
      process.exit(1)
    exitCode

## -----

task "test", "run unit tests", ->
  invoke("build").then ->
    # some tests are slow: --timeout 5000
    # would be nice to optionally grep: --grep xxx
    run("./node_modules/mocha/bin/mocha --timeout 5000 -R spec --compilers coffee:coffee-script --colors")

task "build", "build javascript", ->
  run("mkdir -p lib").then ->
    run("coffee -o lib -c src")

task "clean", "erase build products", ->
  run "rm -rf lib"

task "distclean", "erase everything that wasn't in git", ->
  run "rm -rf node_modules"

