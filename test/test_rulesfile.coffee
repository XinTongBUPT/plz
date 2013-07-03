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

Config = require("../lib/plz/config").Config
rulesfile = require("../lib/plz/rulesfile")

dump = (x) -> util.inspect x, false, null, true


describe "rulesfile", ->
  it "findRulesFile", futureTest withTempFolder (folder) ->
    Q(true).then ->
      fs.writeFileSync "#{folder}/rules.x", "# hello."
      # find with explicit filename.
      rulesfile.findRulesFile(filename: "rules.x")
      Config.cwd().should.eql(folder)
      Config.rulesFile().should.eql("#{folder}/rules.x")
      # find in current folder.
      fs.writeFileSync "#{folder}/#{rulesfile.DEFAULT_FILENAME}", "# hello."
      rulesfile.findRulesFile()
      Config.cwd().should.eql(folder)
      Config.rulesFile().should.eql("#{folder}/#{rulesfile.DEFAULT_FILENAME}")
      # find by walking up folders.
      shell.mkdir "-p", "#{folder}/nested/very/deeply"
      process.chdir("#{folder}/nested/very/deeply")
      fs.writeFileSync "#{folder}/nested/#{rulesfile.DEFAULT_FILENAME}", "# hello."
      rulesfile.findRulesFile()
      Config.cwd().should.eql("#{folder}/nested")
      Config.rulesFile().should.eql("#{folder}/nested/#{rulesfile.DEFAULT_FILENAME}")

  it "compiles coffeescript", futureTest withTempFolder (folder) ->
    code = "task 'destroy', run: -> 3"
    table = rulesfile.compile(code)
    table.getNames().should.eql [ "destroy" ]
    table.getTask("destroy").run().then (n) ->
      n.should.eql(3)

  it "evals javascript", futureTest withTempFolder (folder) ->
    code = "task('destroy', { run: function() { return 3; } });"
    table = rulesfile.compile(code)
    table.getNames().should.eql [ "destroy" ]
    table.getTask("destroy").run().then (n) ->
      n.should.eql(3)

  it "can call 'require'", futureTest withTempFolder (folder) ->
    fs.writeFileSync "#{folder}/test.x", "name = require('./name').name; task name, run: -> 3"
    fs.writeFileSync "#{folder}/name.coffee", "exports.name = 'daffy'\n"
    Config.rulesFile("#{folder}/test.x")
    rulesfile.compileRulesFile().then (table) ->
      table.getNames().should.eql [ "daffy" ]

  it "loadRules", futureTest withTempFolder (folder) ->
    fs.writeFileSync "#{folder}/test.x", "task \"daffy\", run: -> 3"
    rulesfile.loadRules(filename: "#{folder}/test.x").then (table) ->
      table.getNames().should.eql [ "daffy" ]
