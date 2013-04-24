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
execFuture = test_util.execFuture

dump = (x) -> util.inspect x, false, null, true

binplz = "#{process.cwd()}/bin/plz"

#
# effectively integration tests.
# verify the behavior of 'bin/plz'.
#
describe "bin/plz", ->
  it "responds to --help", futureTest ->
    execFuture("#{binplz} --help").then (p) ->
      p.stderr.toString().should.eql("")
      p.stdout.toString().should.match /usage:/
      p.stdout.toString().should.match /options:/

  it "describes existing tasks in --help", futureTest withTempFolder (folder) ->
    fs.writeFileSync "#{folder}/rules", "task 'xyzzy', desc: 'plover', run: ->\n"
    execFuture("#{binplz} -f rules --help").then (p) ->
      p.stderr.toString().should.eql("")
      p.stdout.toString().should.match /xyzzy/
      p.stdout.toString().should.match /plover/
