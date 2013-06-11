fs = require 'fs'
minimatch = require 'minimatch'
path = require 'path'
Q = require 'q'
shell = require 'shelljs'
should = require 'should'
touch = require 'touch'
util = require 'util'

logging = require("../lib/plz/logging")
task = require("../lib/plz/task")
task_table = require("../lib/plz/task_table")

test_util = require("./test_util")
futureTest = test_util.futureTest
withTempFolder = test_util.withTempFolder

describe "TaskTable", ->
  describe "validates that all referenced tasks exist", ->
    it "when they do", ->
      table = new task_table.TaskTable()
      table.tasks =
        "a": new task.Task("a", after: "b")
        "b": new task.Task("b", before: "c")
        "c": new task.Task("c")
      table.validate()

    it "when they don't", ->
      table = new task_table.TaskTable()
      table.tasks =
        "a": new task.Task("a", after: "b")
        "b": new task.Task("b", before: "c")
        "c": new task.Task("c", after: "d")
      (-> table.validate()).should.throw(/d \(referenced by c\)/)
      table = new task_table.TaskTable()
      table.tasks =
        "mercury": new task.Task("mercury", after: "mars")
        "venus": new task.Task("venus", before: "mars")
        "earth": new task.Task("earth", after: "luna")
      (-> table.validate()).should.throw(/luna \(referenced by earth\), mars \(referenced by mercury, venus\)/)

  describe "validates that tasks don't have conflicting dependencies", ->
    it "like a cycle", ->
      table = new task_table.TaskTable()
      table.tasks =
        "a": new task.Task("a", after: "b")
        "b": new task.Task("b", after: "c")
        "c": new task.Task("c", after: "a")
      (-> table.validate()).should.throw(/a -> b -> c -> a/)
      table.tasks =
        "a": new task.Task("a", must: [ "b", "d" ])
        "b": new task.Task("b", must: "c")
        "c": new task.Task("c")
        "d": new task.Task("d", must: "a")
      (-> table.validate()).should.throw(/a -> d -> a/)

    it "but diamond dependencies are okay", ->
      table = new task_table.TaskTable()
      table.tasks =
        "a": new task.Task("a", must: [ "b", "c" ])
        "b": new task.Task("b", must: "d")
        "c": new task.Task("c", must: "d")
        "d": new task.Task("d")
      table.validate()

  it "validates that tasks don't depend on decorators", ->
    table = new task_table.TaskTable()
    table.tasks =
      "a": new task.Task("a", must: [ "b", "c" ])
      "b": new task.Task("b", after: "d")
      "c": new task.Task("c", before: "d")
      "d": new task.Task("d")
    (-> table.validate()).should.throw(/b is a decorator for d/)

  describe "consolidates", ->
    it "before/after", futureTest ->
      table = new task_table.TaskTable()
      table.tasks =
        "a": new task.Task("a", after: "b", watch: "a.js", run: (options) -> options.x *= 3)
        "b": new task.Task("b", after: "c", watch: "b.js", run: (options) -> options.x += 10)
        "c": new task.Task("c", watch: "c.js", run: (options) -> options.x *= 2)
      table.consolidate()
      table.getNames().should.eql [ "c" ]
      c = table.getTask("c")
      c.name.should.eql("c")
      c.watch.should.eql [ "c.js", "b.js", "a.js" ]
      c.covered.sort().should.eql [ "a", "b", "c" ]
      options = { x: 100 }
      c.run(options).then ->
        options.should.eql(x: 630)

    describe "attach", ->
      it "when the attached-to task exists", futureTest ->
        table = new task_table.TaskTable()
        table.tasks =
          "a": new task.Task("a", run: (options) -> options.x *= 3)
          "b": new task.Task("b", attach: "a", run: (options) -> options.x += 10)
        table.validate()
        table.consolidate()
        table.getNames().should.eql [ "a" ]
        a = table.getTask("a")
        a.covered.sort().should.eql [ "a", "b" ]
        options = { x: 10 }
        a.run(options).then ->
          options.should.eql(x: 40)

      it "when the attached-to task doesn't exist", futureTest ->
        table = new task_table.TaskTable()
        table.tasks =
          "b": new task.Task("b", attach: "a", run: (options) -> options.x += 10)
        table.validate()
        table.consolidate()
        table.getNames().should.eql [ "a" ]
        a = table.getTask("a")
        a.covered.sort().should.eql [ "a", "b" ]
        options = { x: 10 }
        a.run(options).then ->
          options.should.eql(x: 20)

  it "enqueues", ->
    table = new task_table.TaskTable()
    table.queue.length.should.eql(0)
    table.enqueue "start", {}
    table.queue.length.should.eql(1)
    table.enqueue "start", {}
    table.queue.length.should.eql(1)

  it "runs enqueued tasks", futureTest ->
    completed = []
    table = new task_table.TaskTable()
    table.tasks =
      "first": new task.Task "first", run: -> completed.push "first"
      "second": new task.Task "second", run: -> completed.push "second"
    table.enqueue "first"
    table.enqueue "second"
    completed.should.eql []
    table.runQueue().then ->
      completed.should.eql [ "first", "second" ]

  it "waits for the run queue to finish before running again", futureTest ->
    completed = []
    table = new task_table.TaskTable()
    table.tasks =
      "first": new task.Task "first", run: ->
        completed.push "first1"
        # try to force "last" to run now!
        table.enqueue "last"
        table.runQueue()
        completed.push "first2"
      "second": new task.Task "second", run: -> completed.push "second"
      "last": new task.Task "last", run: -> completed.push "last"
    table.enqueue "first"
    table.enqueue "second"
    completed.should.eql []
    table.runQueue().then ->
      completed.should.eql [ "first1", "first2", "second", "last" ]

  it "notices file-based dependencies immediately", futureTest withTempFolder (folder) ->
    completed = []
    table = new task_table.TaskTable()
    table.tasks =
      "first": new task.Task "first", run: ->
        completed.push "first"
        fs.writeFileSync "#{folder}/out.x", "hello!"
      "second": new task.Task "second", watch: "#{folder}/out.x", run: ->
        completed.push "second"
    table.activate(persistent: false, interval: 250)
    .then ->
      table.enqueue "first"
      completed.should.eql []
      table.runQueue()
    .then ->
      completed.should.eql [ "first", "second" ]
      table.queue.length.should.eql(0)
      table.close()

  it "won't queue up a task if that task is about to run anyway", futureTest withTempFolder (folder) ->
    completed = []
    table = new task_table.TaskTable()
    table.tasks =
      "first": new task.Task "first", run: ->
        completed.push "first"
        fs.writeFileSync "#{folder}/out.x", "hello!"
      "second": new task.Task "second", watch: "#{folder}/out.x", run: ->
        completed.push "second"
    table.activate(persistent: false, interval: 250)
    .then ->
      table.enqueue "first"
      table.enqueue "second"
      completed.should.eql []
      table.runQueue()
    .then ->
      completed.should.eql [ "first", "second" ]
      table.queue.length.should.eql(0)
      table.close()
