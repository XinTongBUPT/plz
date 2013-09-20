coffee = require 'coffee-script'
fs = require 'fs'
path = require 'path'
util = require 'util'
vm = require 'vm'

logging = require("./logging")

plugins = {}

# load a plugin, or die trying.
load = (name) ->
  if plugins[name]? then return plugins[name]()
  filename = findPlugin(name)
  if not filename? then throw new Error("Can't find plugin: #{name}")
  logging.debug "Loading plugin: #{filename}"
  eval$(fs.readFileSync(filename), filename: filename)
  # plugin could be indirect
  if plugins[name]? then plugins[name]()

# search for a plugin, first in plz-specific locations, then in node locations.
findPlugin = (name) ->
  home = process.env["HOME"] or process.env["USERPROFILE"]
  pluginPath = [ "#{home}/.plz/plugins", "#{process.cwd()}/.plz/plugins" ]
  if process.env["PLZ_PATH"]? then pluginPath.push process.env["PLZ_PATH"]
  pluginPath = pluginPath.map (folder) -> path.resolve(folder)

  for p in pluginPath
    for ext in [ "coffee", "js" ]
      for filename in [ "#{p}/plz-#{name}.#{ext}", "#{p}/plz-#{name}/index.#{ext}" ]
        if fs.existsSync(filename) then return filename

  # hm, try node.
  try
    # do not look too closely at this line.
    return contextStack[0].require.resolve("plz-#{name}")
  catch e
    return null

# gibberish copied over from coffee-script.
createContext = (filename, globals) ->
  Module = require('module')

  # this feels wrong, like we're missing some "normal" way to initialize a new node module.
  m = new Module("build.plz")
  m.filename = filename
  r = (path) -> Module._load(path, m, true)
  for key, value of require then if key != "paths" then r[key] = require[key]
  r.paths = m.paths = Module._nodeModulePaths(path.dirname(filename))
  r.resolve = (request) -> Module._resolveFilename(request, m)

  globals.module = m
  globals.require = r
  vm.createContext(globals)

# have to save the current context for recursive calls.
contextStack = [ null ]
eval$ = (code, options={}) ->
  code = code.toString()
  # FIXME can we do better at detecting js?
  isCoffee = (code.indexOf("->") >= 0) or (code.indexOf("{") < 0)
  if isCoffee
    code = try
      logging.debug "Compiling rules from coffee-script"
      coffee.compile(code, bare: true)
    catch e
      # might not be coffee-script. try js.
      code
  sandbox = options.sandbox or contextStack[0]
  contextStack.unshift sandbox
  try
    if sandbox?
      vm.runInContext(code, sandbox)
    else
      vm.runInThisContext(js)
  finally
    contextStack.shift()

exports.plugins = plugins
exports.load = load
exports.createContext = createContext
exports.eval$ = eval$
