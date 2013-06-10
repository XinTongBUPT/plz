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
  it "parseTaskList", futureTest ->
    parse = (list) -> plz.parseTaskList(argv: { remain: list })
    parse([ "clean", "build" ]).then (options) ->
      options.tasklist.should.eql([ "clean", "build" ])
      options.settings.should.eql({})
    .then ->
      parse([ "setup", "dbhost=db.example.com", "port=900" ])
    .then (options) ->
      options.tasklist.should.eql [ "setup" ]
      options.settings.should.eql(dbhost: "db.example.com", port: "900")
    .then ->
      parse([ "clean", "setup", "port=900", "erase", "x=several words", "install" ])
    .then (options) ->
      options.tasklist.should.eql [ "clean", "setup", "erase", "install" ]
      options.settings.should.eql(port: "900", x: "several words")
    .then ->
      parse([ "name=ralph", "start" ])
    .then (options) ->
      options.tasklist.should.eql [ "start" ]
      options.settings.should.eql(name: "ralph")
    .then ->
      parse([ ])
    .then (options) ->
      options.tasklist.should.eql [ "build" ]
      options.settings.should.eql({})
