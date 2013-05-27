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

describe "Task", ->
  it "is restrictive about names", ->
    (new task.Task("a")).name.should.eql("a")
    (new task.Task("destroy")).name.should.eql("destroy")
    (new task.Task("go-away")).name.should.eql("go-away")
    (new task.Task("y4k")).name.should.eql("y4k")
    (-> new task.Task("what.ever")).should.throw(/must be letters/)
    (-> new task.Task("900")).should.throw(/must be letters/)
    (-> new task.Task("a=b")).should.throw(/must be letters/)

  it "won't let you have a before and after", ->
    (-> new task.Task("name", before: "x", after: "y")).should.throw(/not both/)

  it "combines two tasks", futureTest ->
    t1 = new task.Task "first",
      description: "i'm first"
      before: "b1"
      must: [ "requisite", "apples" ]
      run: (options) -> options.x += 1
    t2 = new task.Task "second",
      description: "i'm second"
      before: "b2"
      must: [ "oranges", "apples" ]
      watch: "*.js"
      run: (options) -> options.z = options.x
    t3 = t1.combine(t2, t1)
    t3.name.should.eql("first")
    t3.description.should.eql("i'm first")
    t3.must.should.eql [ "requisite", "apples", "oranges" ]
    t3.watch.should.eql [ "*.js" ]
    t3.before.should.eql("b1")
    options = { x: 9 }
    t3.run(options).then ->
      options.should.eql(x: 10, z: 10)

describe "TaskTable", ->
  describe "validates that all referenced tasks exist", ->
    it "when they do", ->
      table = new task.TaskTable()
      table.tasks =
        "a": new task.Task("a", after: "b")
        "b": new task.Task("b", before: "c")
        "c": new task.Task("c")
      table.validate()

    it "when they don't", ->
      table = new task.TaskTable()
      table.tasks =
        "a": new task.Task("a", after: "b")
        "b": new task.Task("b", before: "c")
        "c": new task.Task("c", after: "d")
      (-> table.validate()).should.throw(/d \(referenced by c\)/)
      table = new task.TaskTable()
      table.tasks =
        "mercury": new task.Task("mercury", after: "mars")
        "venus": new task.Task("venus", before: "mars")
        "earth": new task.Task("earth", after: "luna")
      (-> table.validate()).should.throw(/luna \(referenced by earth\), mars \(referenced by mercury, venus\)/)

  describe "validates that tasks don't have conflicting dependencies", ->
    it "like a cycle", ->
      table = new task.TaskTable()
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
      table = new task.TaskTable()
      table.tasks =
        "a": new task.Task("a", must: [ "b", "c" ])
        "b": new task.Task("b", must: "d")
        "c": new task.Task("c", must: "d")
        "d": new task.Task("d")
      table.validate()

  it "validates that tasks don't depend on decorators", ->
    table = new task.TaskTable()
    table.tasks =
      "a": new task.Task("a", must: [ "b", "c" ])
      "b": new task.Task("b", after: "d")
      "c": new task.Task("c", before: "d")
      "d": new task.Task("d")
    (-> table.validate()).should.throw(/b is a decorator for d/)

  it "consolidates", futureTest ->
    table = new task.TaskTable()
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

  it "enqueues", ->
    table = new task.TaskTable()
    (table.timer?).should.eql(false)
    table.enqueue "start", {}
    (table.timer?).should.eql(true)
    clearTimeout(table.timer)
    table.timer = "WAT"
    table.enqueue "start", {}
    (table.timer?).should.eql(true)
    table.timer.should.eql("WAT")

  it "delays a bit before running enqueued tasks", futureTest ->
    completed = []
    table = new task.TaskTable()
    table.tasks =
      "first": new task.Task "first", run: -> completed.push "first"
      "second": new task.Task "second", run: -> completed.push "second"
    table.enqueue "first"
    table.enqueue "second"
    completed.should.eql []
    Q.delay(task.QUEUE_DELAY + 50).then ->
      completed.should.eql [ "first", "second" ]

  it "waits for the run queue to finish before running again", futureTest ->
    completed = []
    table = new task.TaskTable()
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
    logging.setDebug true
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
      table.runQueueWithWatches()
    .then ->
      completed.should.eql [ "first", "second" ]
      table.queue.length.should.eql(0)
      table.close()



