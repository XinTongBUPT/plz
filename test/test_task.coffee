fs = require 'fs'
minimatch = require 'minimatch'
path = require 'path'
Q = require 'q'
shell = require 'shelljs'
should = require 'should'
touch = require 'touch'
util = require 'util'

task = require("../lib/plz/task")

test_util = require("./test_util")
futureTest = test_util.futureTest

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

    it "like a cross-reference", ->
      table = new task.TaskTable()
      table.tasks =
        "a": new task.Task("a", must: [ "b", "c" ])
        "b": new task.Task("b", after: "d")
        "c": new task.Task("c", before: "d")
        "d": new task.Task("d")
      (-> table.validate()).should.throw(/a -> b -> d and a -> c -> d/)

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
