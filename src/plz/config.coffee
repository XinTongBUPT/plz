logging = require("./logging")

VERSION = "1.1.0"

# put all runtime config stuff in here, so it can be accessed from a running
# build script too.
Config =
  useColors: logging.useColors
  logVerbose: logging.setVerbose
  logDebug: logging.setDebug

  cwd: (folder) ->
    if folder? then process.chdir(folder)
    process.cwd()

  rulesFile: (filename) ->
    if filename? then @_rulesFile = filename
    @_rulesFile

  stateFile: (filename) ->
    if filename? then @_stateFile = filename
    @_stateFile
  
  monitor: (value) ->
    if value? then @_monitor = value
    @_monitor

  version: ->
    VERSION

  # for tests
  reset: ->
    @_rulesFile = null
    @_stateFile = null
    @_monitor = true


Config.reset()

exports.Config = Config
exports.VERSION = VERSION
