fs = require 'fs'
minimatch = require 'minimatch'
mocha_sprinkles = require 'mocha-sprinkles'
path = require 'path'
Q = require 'q'
shell = require 'shelljs'
should = require 'should'
touch = require 'touch'
util = require 'util'

rulesfile = require("../lib/plz/rulesfile")
future = mocha_sprinkles.future
withTempFolder = mocha_sprinkles.withTempFolder

plz = require("../lib/plz/plz")

dump = (x) -> util.inspect x, false, null, true


describe "plz", ->
  it "parseTaskList", ->
    parse = (list) -> plz.parseTaskList(argv: { remain: list })
    [ tasklist, settings ] = parse([ "clean", "build" ])
    tasklist.should.eql([ "clean", "build" ])
    settings.should.eql({})
    [ tasklist, settings ] = parse([ "setup", "dbhost=db.example.com", "port=900" ])
    tasklist.should.eql [ "setup" ]
    settings.should.eql(dbhost: "db.example.com", port: "900")
    [ tasklist, settings ] = parse([ "clean", "setup", "port=900", "erase", "x=several words", "install" ])
    tasklist.should.eql [ "clean", "setup", "erase", "install" ]
    settings.should.eql(port: "900", x: "several words")
    [ tasklist, settings ] = parse([ "name=ralph", "start" ])
    tasklist.should.eql [ "start" ]
    settings.should.eql(name: "ralph")
    [ tasklist, settings ] = parse([ ])
    tasklist.should.eql [ ]
    settings.should.eql({})

  describe "readRcFile", ->
    it "trims", future withTempFolder (folder) ->
      fs.writeFileSync "#{folder}/plzrc", PLZRC_1
      process.env["PLZRC"] = "#{folder}/plzrc"
      plz.readRcFile({}).then (settings) ->
        settings.should.eql(hello: "alpha")
      .fin ->
        delete process.env["PLZRC"]

    it "ignores comments and blank lines", future withTempFolder (folder) ->
      fs.writeFileSync "#{folder}/plzrc", PLZRC_2
      process.env["PLZRC"] = "#{folder}/plzrc"
      plz.readRcFile({}).then (settings) ->
        settings.should.eql(hello: "alpha", truck: "car")
      .fin ->
        delete process.env["PLZRC"]


PLZRC_1 = """
  hello=alpha
"""

PLZRC_2 = """
# test .plzrc
hello=alpha

# comment
truck=car

# more comments
"""
