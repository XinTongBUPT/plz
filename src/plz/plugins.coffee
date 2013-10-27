coffee = require 'coffee-script'
fs = require 'fs'
Module = require 'module'
path = require 'path'
util = require 'util'
vm = require 'vm'

logging = require("./logging")

plugins = {}
pluginPaths = []

buildPluginPaths = ->
  home = process.env["HOME"] or process.env["USERPROFILE"]
  pluginPaths = [
    "#{home}/.plz/plugins"
    "#{process.cwd()}/.plz/plugins"
  ]
  if process.env["PLZ_PATH"]? then pluginPaths.push process.env["PLZ_PATH"]
  pluginPaths = pluginPaths.map (folder) -> path.resolve(folder)

buildPluginPaths()

# load a plugin, or die trying.
load = (name, require) ->
  if plugins[name]? then return plugins[name]()
  require(findPlugin(name))
  # plugin could be indirect:
  if plugins[name]? then plugins[name]()

# if a plugin is in plz-specific locations, make it explicit.
findPlugin = (name) ->
  for p in pluginPaths
    for ext in [ "coffee", "js" ]
      for filename in [ "#{p}/plz-#{name}.#{ext}", "#{p}/plz-#{name}/index.#{ext}" ]
        if fs.existsSync(filename) then return filename
  return "plz-#{name}"


Natives = Object.keys(process.binding "natives")
__require = require

class ModuleLoader
  constructor: ->
    @cache = {}

  load: (code, filename, globals) ->
    if not code? then code = fs.readFileSync(filename)
    m = new Module(filename)
    m.filename = filename
    m.sandbox = vm.createContext(globals)
    m.sandbox.global = globals
    @evalInModule(code, filename, m)
    m.exports

  # build a "require" method for a module
  makeRequire: (parent) ->
    (name) =>
      if name in Natives then return __require(name)
      filename = Module._resolveFilename(name, parent)
      if @cache[filename]? then return @cache[filename].exports

      m = new Module(filename, parent)
      m.filename = filename
      m.sandbox = parent.sandbox
      try
        @cache[filename] = m
        @evalInModule(fs.readFileSync(filename), filename, m)
        m.exports
      catch e
        delete @cache[filename]
        throw e
      
  evalInModule: (code, filename, m) ->
    code = code.toString()
    # FIXME can we do better at detecting js?
    isCoffee = filename.match(/\.coffee/)? or (code.indexOf("->") >= 0) or (code.indexOf("{") < 0)
    if isCoffee
      code = try
        coffee.compile(code, bare: true)
      catch e
        # might not be coffee-script. try js.
        code
    wrapped = "(function (exports, require, module, __filename, __dirname) {\n#{code}\n});"
    f = vm.runInContext(wrapped, m.sandbox, filename)
    require = @makeRequire(m)
    # it can be convenient to access 'require' from inside the sandbox
    m.sandbox.global._require = require
    f(m.exports, require, m, filename, path.dirname(filename))


exports.ModuleLoader = ModuleLoader
exports.plugins = plugins
exports.load = load
