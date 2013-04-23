fs = require 'fs'
minimatch = require 'minimatch'
path = require 'path'
Q = require 'q'
shell = require 'shelljs'
should = require 'should'
touch = require 'touch'
util = require 'util'

test_util = require("./test_util")
futureTest = test_util.futureTest
withTempFolder = test_util.withTempFolder

stake = require("../lib/stake/stake")

dump = (x) -> util.inspect x, false, null, true


describe "stake", ->
  it "findRulesFile", futureTest withTempFolder (folder) ->
    process.chdir(folder)
    folder = process.cwd()
    fs.writeFileSync "#{folder}/rules.x", "hello."
    options = { filename: "rules.x" }
    # find with explicit filename.
    stake.findRulesFile(options)
    .then (options) ->
      options.cwd.should.eql(folder)
      options.filename.should.eql("#{folder}/rules.x")
      # find in current folder.
      options = {}
      fs.writeFileSync "#{folder}/#{stake.DEFAULT_FILENAME}", "hello."
      stake.findRulesFile(options)
    .then (options) ->
      options.cwd.should.eql(folder)
      options.filename.should.eql("#{folder}/#{stake.DEFAULT_FILENAME}")
      # find by walking up folders.
      options = {}
      shell.mkdir "-p", "#{folder}/nested/very/deeply"
      process.chdir("#{folder}/nested/very/deeply")
      fs.writeFileSync "#{folder}/nested/#{stake.DEFAULT_FILENAME}", "hello."
      stake.findRulesFile(options)
    .then (options) ->
      options.cwd.should.eql("#{folder}/nested")
      options.filename.should.eql("#{folder}/nested/#{stake.DEFAULT_FILENAME}")

  describe "compileRulesFile", ->
    it "compiles", futureTest withTempFolder (folder) ->
      process.chdir(folder)
      folder = process.cwd()
      code = "task 'destroy', run: -> 3"
      stake.compileRulesFile("test.coffee", code).then (tasks) ->
        Object.keys(tasks).should.eql [ "destroy" ]

    it "can call 'require'", futureTest withTempFolder (folder) ->
      process.chdir(folder)
      folder = process.cwd()
      code = "name = require('./name').name; task name, run: -> 3"
      fs.writeFileSync "#{folder}/name.coffee", "exports.name = 'daffy'\n"
      stake.compileRulesFile("#{folder}/test.coffee", code).then (tasks) ->
        Object.keys(tasks).should.eql [ "daffy" ]

  it "parseTaskList", futureTest ->
    parse = (list) -> stake.parseTaskList(argv: { remain: list })
    parse([ "clean", "build" ]).then (options) ->
      options.tasklist.should.eql([ [ "clean", {} ], [ "build", {} ] ])
      options.globals.should.eql({})
    .then ->
      parse([ "setup", "dbhost=db.example.com", "port=900" ])
    .then (options) ->
      options.tasklist.should.eql([ [ "setup", { dbhost: "db.example.com", port: "900" } ] ])
      options.globals.should.eql({})
    .then ->
      parse([ "clean", "setup", "port=900", "erase", "x=several words", "install" ])
    .then (options) ->
      options.tasklist.should.eql [
        [ "clean", {} ]
        [ "setup", { port: "900" } ]
        [ "erase", { x: "several words" } ]
        [ "install", {} ]
      ]
      options.globals.should.eql({})
    .then ->
      parse([ "name=ralph", "start" ])
    .then (options) ->
      options.tasklist.should.eql [
        [ "start", {} ]
      ]
      options.globals.should.eql(name: "ralph")
    .then ->
      parse([ ])
    .then (options) ->
      options.tasklist.should.eql [
        [ "all", {} ]
      ]
      options.globals.should.eql({})

