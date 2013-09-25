coffee = require 'coffee-script'
fs = require 'fs'
path = require 'path'
Q = require 'q'
should = require 'should'
util = require 'util'
vm = require 'vm'

makeGlobals = ->
  tasks = {}
  globals =
    console: console
    extend: (map1, map2) ->
      for k, v of map2 then map1[k] = v
      map1
    plugins: {}
    Q: Q
    require: (name) ->
      if name == "util" then util
    settings: {}
    tasks: tasks
    task: (name, options) -> tasks[name] = options
  globals

loadBuiltins = (globals) ->
  context = vm.createContext(globals)
  code = fs.readFileSync("./lib/plz-builtins.js").toString()
  Q().then ->
    vm.runInContext(code, context)

# run a test as a future, and call mocha's 'done' method at the end of the chain.
futureTest = (f) ->
  (done) ->
    f().then((-> done()), ((error) -> done(error)))


# test_util = require("./test_util")
# futureTest = test_util.futureTest
# withTempFolder = test_util.withTempFolder
# execFuture = test_util.execFuture


describe "plz-builtins", ->
  describe "clean/distclean", ->
    it "not defined without settings", futureTest ->
      g = makeGlobals()
      loadBuiltins(g).then ->
        console.log "TEST"
        Object.keys(g.tasks).length.should.eql(0)

    it "can define only clean", futureTest ->
      g = makeGlobals()
      g.settings.clean = "foo"
      loadBuiltins(g).then ->
        Object.keys(g.tasks).should.eql [ "clean" ]

    it "can define clean and distclean", futureTest ->
      g = makeGlobals()
      g.settings.clean = "foo"
      g.settings.distclean = "foo"
      loadBuiltins(g).then ->
        Object.keys(g.tasks).sort().should.eql [ "clean", "distclean" ]
