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
__builtin_require = require

class ModuleLoader
  constructor: ->
    @cache = {}

  load: (code, filename) ->
    if not code? then code = fs.readFileSync(filename)
    m = new Module(filename)
    m.filename = filename
    m.paths = Module._nodeModulePaths(path.dirname(filename))
    @evalInModule(code, filename, m)
    m.exports

  # build a "require" method for a module
  makeRequire: (parent) ->
    (name) =>
      if name in Natives then return __builtin_require(name)
      filename = Module._resolveFilename(name, parent)
      if @cache[filename]? then return @cache[filename].exports

      m = new Module(filename, parent)
      m.filename = filename
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
    f = vm.runInThisContext(wrapped, filename, false)
    f(m.exports, @makeRequire(m), m, filename, path.dirname(filename))


exports.ModuleLoader = ModuleLoader
exports.plugins = plugins
exports.load = load
