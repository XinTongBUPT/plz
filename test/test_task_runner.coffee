fs = require 'fs'
minimatch = require 'minimatch'
path = require 'path'
Q = require 'q'
shell = require 'shelljs'
should = require 'should'
touch = require 'touch'
util = require 'util'

logging = require("../lib/plz/logging")
Task = require("../lib/plz/task").Task
TaskTable = require("../lib/plz/task_table").TaskTable
TaskRunner = require("../lib/plz/task_runner").TaskRunner

test_util = require("./test_util")
futureTest = test_util.futureTest
withTempFolder = test_util.withTempFolder

describe "TaskRunner", ->
  it "enqueues", ->
    runner = new TaskTable().runner
    runner.queue.length.should.eql(0)
    runner.enqueue "start", {}
    runner.queue.length.should.eql(1)
    runner.enqueue "start", {}
    runner.queue.length.should.eql(1)

  it "runs enqueued tasks", futureTest ->
    completed = []
    runner = new TaskTable().runner
    runner.table.tasks =
      "first": new Task "first", run: -> completed.push "first"
      "second": new Task "second", run: -> completed.push "second"
    runner.enqueue "first"
    runner.enqueue "second"
    completed.should.eql []
    runner.runQueue().then ->
      completed.should.eql [ "first", "second" ]

  it "waits for the run queue to finish before running again", futureTest ->
    completed = []
    runner = new TaskTable().runner
    runner.table.tasks =
      "first": new Task "first", run: ->
        completed.push "first1"
        # try to force "last" to run now!
        runner.enqueue "last"
        runner.runQueue()
        completed.push "first2"
      "second": new Task "second", run: -> completed.push "second"
      "last": new Task "last", run: -> completed.push "last"
    runner.enqueue "first"
    runner.enqueue "second"
    completed.should.eql []
    runner.runQueue().then ->
      completed.should.eql [ "first1", "first2", "second", "last" ]

  it "notices file-based dependencies immediately", futureTest withTempFolder (folder) ->
    completed = []
    runner = new TaskTable().runner
    runner.table.tasks =
      "first": new Task "first", run: ->
        completed.push "first"
        fs.writeFileSync "#{folder}/out.x", "hello!"
      "second": new Task "second", watch: "#{folder}/out.x", run: ->
        completed.push "second"
    runner.table.activate(persistent: false, interval: 250)
    .then ->
      runner.enqueue "first"
      completed.should.eql []
      runner.runQueue()
    .then ->
      completed.should.eql [ "first", "second" ]
      runner.queue.length.should.eql(0)
      runner.table.close()

  it "won't queue up a task if that task is about to run anyway", futureTest withTempFolder (folder) ->
    completed = []
    runner = new TaskTable().runner
    runner.table.tasks =
      "first": new Task "first", run: ->
        completed.push "first"
        fs.writeFileSync "#{folder}/out.x", "hello!"
      "second": new Task "second", watch: "#{folder}/out.x", run: ->
        completed.push "second"
    runner.table.activate(persistent: false, interval: 250)
    .then ->
      runner.enqueue "first"
      runner.enqueue "second"
      completed.should.eql []
      runner.runQueue()
    .then ->
      completed.should.eql [ "first", "second" ]
      runner.queue.length.should.eql(0)
      runner.table.close()
