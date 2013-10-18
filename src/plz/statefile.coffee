fs = require 'fs'
path = require 'path'
Q = require 'q'
shelljs = require 'shelljs'
util = require 'util'

Config = require("./config").Config
logging = require("./logging")

DEFAULT_FILENAME = ".plz/state"

findStateFile = ->
  # the state file should (normally) be kept in the same folder as the rules file.
  if Config.stateFile()? then return
  if process.env["PLZ_STATE"]?
    Config.stateFile(process.env["PLZ_STATE"])
    return
  Config.stateFile(path.join(path.dirname(Config.rulesFile()), DEFAULT_FILENAME))

loadState = ->
  findStateFile()
  logging.debug "Loading state file #{Config.stateFile()}"
  if not fs.existsSync(Config.stateFile()) then return Q({})
  deferred = Q.defer()
  fs.readFile Config.stateFile(), (error, data) ->
    if error?
      logging.error("Unable to read state file #{Config.stateFile()}: #{error.stack}")
      return deferred.reject(error)
    try
      data = data.toString()
      deferred.resolve(if data.length == 0 then {} else JSON.parse(data))
    catch error
      logging.error("Corrupted state file #{Config.stateFile()}: #{error.stack}")
      deferred.reject(error)
  deferred.promise

saveState = (state) ->
  findStateFile()
  logging.debug "Saving state file #{Config.stateFile()}"
  shelljs.mkdir "-p", path.dirname(Config.stateFile())
  deferred = Q.defer()
  fs.writeFile Config.stateFile(), JSON.stringify(state), (error) ->
    if error?
      logging.error("Unable to write state file #{Config.stateFile()}: #{error.stack}")
      return deferred.reject(error)
    deferred.resolve(null)
  deferred.promise


exports.loadState = loadState
exports.saveState = saveState
