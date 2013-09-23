fs = require 'fs'
minimatch = require 'minimatch'
path = require 'path'
Q = require 'q'
shell = require 'shelljs'
should = require 'should'
touch = require 'touch'
util = require 'util'

Config = require("../lib/plz/config").Config
logging = require("../lib/plz/logging")
Task = require("../lib/plz/task").Task
TaskTable = require("../lib/plz/task_table").TaskTable
TaskRunner = require("../lib/plz/task_runner").TaskRunner

test_util = require("./test_util")
futureTest = test_util.futureTest
withTempFolder = test_util.withTempFolder

describe "TaskRunner", ->
  beforeEach ->
    Config.reset()

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
    runner.start()
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
    runner.start()
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
    runner.start()
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
    runner.start()
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

  it "will re-enqueue a task that triggers itself", futureTest withTempFolder (folder) ->
    completed = []
    runner = new TaskTable().runner
    runner.table.tasks =
      "primary": new Task "primary", must: "setup", watch: "#{folder}/out.x", run: ->
        completed.push "primary"
        if fs.existsSync "#{folder}/out2.x" then return
        if fs.existsSync "#{folder}/out.x"
          fs.writeFileSync "#{folder}/out.x", "second write!"
          fs.writeFileSync "#{folder}/out2.x", "now stop."
        else
          fs.writeFileSync "#{folder}/out.x", "first write!"
      "setup": new Task "setup", run: ->
        completed.push "setup"
    runner.start()
    runner.table.activate(persistent: false, interval: 250)
    .then ->
      runner.enqueue "primary"
      completed.should.eql []
      runner.runQueue()
    .then ->
      # 1. write out.x; 2. notice out.x, write out.x and out2.x; 3. notice out2.x and stop.
      completed.should.eql [ "setup", "primary", "primary", "primary" ]
      # great. but after a delay, it should both setup & primary again.
      completed = []
      Q.delay(100)
    .then ->
      fs.writeFileSync "#{folder}/out.x", "AGAIN! :) :) :) :) :)"
      Q.delay(300)
    .then ->
      completed.should.eql [ "setup", "primary" ]
      runner.queue.length.should.eql(0)
      runner.table.close()

  it "won't re-run a dependency task that it's already run", futureTest withTempFolder (folder) ->
    completed = []
    runner = new TaskTable().runner
    runner.table.tasks =
      "build": new Task "build", run: ->
        completed.push "build"
        fs.writeFileSync "#{folder}/out.x", "build!"
      "test": new Task "test", must: "build", watch: "#{folder}/out.x", run: ->
        completed.push "test"
    runner.start()
    runner.table.activate(persistent: false, interval: 250)
    .then ->
      runner.enqueue "build"
      completed.should.eql []
      runner.runQueue()
    .then ->
      completed.should.eql [ "build", "test" ]
      runner.queue.length.should.eql(0)
      runner.table.close()

  it "passes global settings to the task", futureTest withTempFolder (folder) ->
    completed = []
    runner = new TaskTable().runner
    runner.settings.peaches = "10"
    runner.table.tasks =
      "go": new Task "go", run: (context) -> completed.push context.settings.peaches
    runner.enqueue "go"
    completed.should.eql []
    runner.start()
    runner.runQueue().then ->
      completed.should.eql [ "10" ]

  it "passes the changed filename list to the task", futureTest withTempFolder (folder) ->
    completed = []
    runner = new TaskTable().runner
    runner.table.tasks =
      "go": new Task "go", run: (context) -> completed.push context.filenames
    runner.enqueue "go", "file1"
    runner.enqueue "go", "file2"
    runner.enqueue "go", "file1"
    completed.should.eql []
    runner.start()
    runner.runQueue().then ->
      completed.should.eql [ [ "file1", "file2" ] ]

  it "collects filename changes from events while a task is enqueued", futureTest withTempFolder (folder) ->
    completed = []
    runner = new TaskTable().runner
    runner.table.tasks =
      "helper": new Task "helper", run: (context) -> runner.enqueue "go", "file2"
      "go": new Task "go", run: (context) -> completed.push context.filenames
    runner.enqueue "helper"
    runner.enqueue "go", "file1"
    completed.should.eql []
    runner.start()
    runner.runQueue().then ->
      completed.should.eql [ [ "file1", "file2" ] ]
