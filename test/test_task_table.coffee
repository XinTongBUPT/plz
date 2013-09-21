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

test_util = require("./test_util")
futureTest = test_util.futureTest
withTempFolder = test_util.withTempFolder

describe "TaskTable", ->
  describe "validates that all referenced tasks exist", ->
    it "when they do", ->
      table = new TaskTable()
      table.tasks =
        "a": new Task("a", after: "b")
        "b": new Task("b", before: "c")
        "c": new Task("c")
      table.validate()

    it "when they don't", ->
      table = new TaskTable()
      table.tasks =
        "a": new Task("a", after: "b")
        "b": new Task("b", before: "c")
        "c": new Task("c", after: "d")
      (-> table.validate()).should.throw(/d \(referenced by c\)/)
      table = new TaskTable()
      table.tasks =
        "mercury": new Task("mercury", after: "mars")
        "venus": new Task("venus", before: "mars")
        "earth": new Task("earth", after: "luna")
      (-> table.validate()).should.throw(/luna \(referenced by earth\), mars \(referenced by mercury, venus\)/)

  describe "validates that tasks don't have conflicting dependencies", ->
    it "like a cycle", ->
      table = new TaskTable()
      table.tasks =
        "a": new Task("a", after: "b")
        "b": new Task("b", after: "c")
        "c": new Task("c", after: "a")
      (-> table.validate()).should.throw(/a -> b -> c -> a/)
      table.tasks =
        "a": new Task("a", must: [ "b", "d" ])
        "b": new Task("b", must: "c")
        "c": new Task("c")
        "d": new Task("d", must: "a")
      (-> table.validate()).should.throw(/a -> d -> a/)

    it "but diamond dependencies are okay", ->
      table = new TaskTable()
      table.tasks =
        "a": new Task("a", must: [ "b", "c" ])
        "b": new Task("b", must: "d")
        "c": new Task("c", must: "d")
        "d": new Task("d")
      table.validate()

  it "validates that tasks don't depend on decorators", ->
    table = new TaskTable()
    table.tasks =
      "a": new Task("a", must: [ "b", "c" ])
      "b": new Task("b", after: "d")
      "c": new Task("c", before: "d")
      "d": new Task("d")
    (-> table.validate()).should.throw(/b is a decorator for d/)

  describe "consolidates", ->
    it "before/after", futureTest ->
      table = new TaskTable()
      table.tasks =
        "a": new Task("a", after: "b", watch: "a.js", run: (options) -> options.x *= 3)
        "b": new Task("b", after: "c", watch: "b.js", run: (options) -> options.x += 10)
        "c": new Task("c", watch: "c.js", run: (options) -> options.x *= 2)
      table.consolidate()
      table.getNames().should.eql [ "c" ]
      c = table.getTask("c")
      c.name.should.eql("c")
      c.watch.should.eql [ "c.js", "b.js", "a.js" ]
      c.covered.sort().should.eql [ "a", "b", "c" ]
      options = { x: 100 }
      c.run(options).then ->
        options.should.eql(x: 630)

    it "in a promise-safe way", futureTest ->
      table = new TaskTable()
      table.tasks =
        "primary": new Task("primary", run: (options) -> Q.delay(100).then(-> options.x += 99))
        "barnacle": new Task("barnacle", after: "primary", run: (options) -> options.x *= 2)
      table.consolidate()
      options = { x: 1 }
      table.getTask("primary").run(options).then ->
        options.should.eql(x: 200)

    describe "attach", ->
      it "when the attached-to task exists", futureTest ->
        table = new TaskTable()
        table.tasks =
          "a": new Task("a", run: (options) -> options.x *= 3)
          "b": new Task("b", attach: "a", run: (options) -> options.x += 10)
        table.validate()
        table.consolidate()
        table.getNames().should.eql [ "a" ]
        a = table.getTask("a")
        a.covered.sort().should.eql [ "a", "b" ]
        options = { x: 10 }
        a.run(options).then ->
          options.should.eql(x: 40)

      it "when the attached-to task doesn't exist", futureTest ->
        table = new TaskTable()
        table.tasks =
          "b": new Task("b", attach: "a", run: (options) -> options.x += 10)
        table.validate()
        table.consolidate()
        table.getNames().should.eql [ "a" ]
        a = table.getTask("a")
        a.covered.sort().should.eql [ "a", "b" ]
        options = { x: 10 }
        a.run(options).then ->
          options.should.eql(x: 20)

    it "attach before after", futureTest ->
      table = new TaskTable()
      table.tasks =
        "a": new Task("a", run: (options) -> options.order.push "a")
        "b": new Task("b", attach: "a", run: (options) -> options.order.push "b")
        "c": new Task("c", after: "a", run: (options) -> options.order.push "c")
      table.validate()
      table.consolidate()
      table.getNames().should.eql [ "a" ]
      a = table.getTask("a")
      a.covered.sort().should.eql [ "a", "b", "c" ]
      options = { order: [] }
      a.run(options).then ->
        options.order.should.eql [ "a", "b", "c" ]

  it "enqueues 'always' tasks", ->
    table = new TaskTable()
    table.tasks =
      "a": new Task("a")
      "b": new Task("b", always: true)
    table.enqueueAlways()
    table.runner.queue.map((x) -> x[0]).should.eql [ "b" ]    

  describe "topologically sorts tasks", ->
    table = new TaskTable()
    table.tasks =
      "top": new Task("top", must: [ "left1", "right" ])
      "left1": new Task("left1", must: [ "left2" ])
      "left2": new Task("left2", must: [ "base" ])
      "right": new Task("right", must: [ "base" ])
      "base": new Task("base")

    it "simple", ->
      table.topoSort("top").should.eql([ "base", "left2", "left1", "right", "top" ])

    it "with skips", ->
      table.topoSort("top", left1: true).should.eql([ "base", "right", "top" ])
