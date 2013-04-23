fs = require 'fs'
minimatch = require 'minimatch'
path = require 'path'
Q = require 'q'
shell = require 'shelljs'
should = require 'should'
touch = require 'touch'
util = require 'util'

task = require("../lib/stake/task")

dump = (x) -> util.inspect x, false, null, true


describe.only "Task", ->
  it "is restrictive about names", ->
    (new task.Task("a")).name.should.eql("a")
    (new task.Task("destroy")).name.should.eql("destroy")
    (new task.Task("go-away")).name.should.eql("go-away")
    (new task.Task("y4k")).name.should.eql("y4k")
    (-> new task.Task("what.ever")).should.throw(/must be letters/)
    (-> new task.Task("900")).should.throw(/must be letters/)
    (-> new task.Task("a=b")).should.throw(/must be letters/)
