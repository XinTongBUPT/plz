fs = require 'fs'
minimatch = require 'minimatch'
mocha_sprinkles = require 'mocha-sprinkles'
path = require 'path'
Q = require 'q'
shell = require 'shelljs'
should = require 'should'
touch = require 'touch'
util = require 'util'

logging = require("../lib/plz/logging")
task = require("../lib/plz/task")

future = mocha_sprinkles.future
withTempFolder = mocha_sprinkles.withTempFolder

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
    (-> new task.Task("name", before: "x", after: "y")).should.throw(/only be one of/)

  it "combines two tasks", future ->
    t1 = new task.Task "first",
      description: "i'm first"
      before: "b1"
      must: [ "requisite", "apples" ]
      run: (options) -> options.x += 1
    t2 = new task.Task "second",
      description: "i'm second"
      before: "b2"
      must: [ "oranges", "apples" ]
      depends: [ "nothing" ]
      watch: "*.js"
      run: (options) -> options.z = options.x
    t3 = t1.combine(t2, t1)
    t3.name.should.eql("first")
    t3.description.should.eql("i'm first")
    t3.must.should.eql [ "requisite", "apples", "oranges" ]
    t3.depends.should.eql [ "nothing" ]
    t3.watch.should.eql [ "*.js" ]
    t3.before.should.eql("b1")
    options = { x: 9 }
    t3.run(options).then ->
      options.should.eql(x: 10, z: 10)
  
  it "adds a must to a task", ->
    t1 = new task.Task "first",
      description: "i'm first"
      must: [ "oranges", "apples" ]
      run: (options) -> options.x += 1
    t2 = new task.Task "second",
      description: "i'm second"
      run: (options) -> options.z = options.x
    t3 = t1.combine(t2, t2)
    t3.must.should.eql [ "oranges", "apples" ]

  it "activates watches", future withTempFolder (folder) ->
    fs.writeFileSync "#{folder}/file1.x", "hello"
    fs.writeFileSync "#{folder}/file2.y", "hello"
    t = new task.Task "build", watch: "#{folder}/*.x", run: -> 3
    t.activateWatches({}, {}, (->)).then ->
      try
        t.watchers.length.should.eql 1
        t.watchers[0].originalPatterns.should.eql [ "#{folder}/*.x" ]
        t.currentSet().should.eql [ "#{folder}/file1.x" ]
      finally
        t.watchers.map (w) -> w.close()

