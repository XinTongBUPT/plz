coffee = require 'coffee-script'
fs = require 'fs'
path = require 'path'
Q = require 'q'
shell = require 'shelljs'
should = require 'should'
util = require 'util'
vm = require 'vm'

test_util = require("../../test/test_util")
futureTest = test_util.futureTest
withTempFolder = test_util.withTempFolder

BUILTINS = fs.readFileSync("./lib/plz-builtins.js").toString()

makeGlobals = ->
  tasks = {}
  globals =
    console: console
    extend: (map1, map2) ->
      for k, v of map2 then map1[k] = v
      map1
    plugins: {}
    plz:
      monitor: ->
      stateFile: ->
    Q: Q
    require: (name) ->
      if name == "util" then util
    rm: shell.rm
    settings: {}
    tasks: tasks
    task: (name, options) -> tasks[name] = options
  globals

loadBuiltins = (globals) ->
  context = vm.createContext(globals)
  Q().then ->
    vm.runInContext(BUILTINS, context)


describe "plz-builtins", ->
  describe "clean/distclean", ->
    it "not defined without settings", futureTest ->
      g = makeGlobals()
      loadBuiltins(g).then ->
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

    it "actually erases files", futureTest withTempFolder (folder) ->
      g = makeGlobals()
      g.settings.clean = [ "#{folder}/trash.x" ]
      loadBuiltins(g).then ->
        fs.writeFileSync("#{folder}/alive.x", "alive!")
        fs.writeFileSync("#{folder}/trash.x", "trash!")
        Q(g.tasks.clean.run())
      .then ->
        fs.existsSync("#{folder}/alive.x").should.eql(true)
        fs.existsSync("#{folder}/trash.x").should.eql(false)

