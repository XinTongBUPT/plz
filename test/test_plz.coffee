fs = require 'fs'
minimatch = require 'minimatch'
path = require 'path'
Q = require 'q'
shell = require 'shelljs'
should = require 'should'
touch = require 'touch'
util = require 'util'

rulesfile = require("../lib/plz/rulesfile")
test_util = require("./test_util")
futureTest = test_util.futureTest
withTempFolder = test_util.withTempFolder

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
    tasklist.should.eql [ "build" ]
    settings.should.eql({})
