sprintf = require 'sprintf'
strftime = require 'strftime'

usingColors = process.stdout.isTTY
useColors = (bool) ->
  if bool? then usingColors = bool
  usingColors

isVerbose = false
setVerbose = (bool) ->
  if bool?
    isVerbose = bool
    if not bool then isDebug = false
  isVerbose

isDebug = false
setDebug = (bool) ->
  if bool?
    isDebug = bool
    if bool then isVerbose = true
  isDebug

colors =
  yellow: "38;5;11"
  orange: "33"
  red: "31"
  purple: "35"
  blue: "34"
  brightBlue: "38;5;12"
  brightCyan: "38;5;14"
  cyan: "36"
  green: "32"
  black: "30"
  gray: "37"
  white: "38;5;15"
  off: "0"

inColor = (color, text) ->
  if usingColors
    "\u001b[#{colors[color]}m#{text}\u001b[0m"
  else
    text

appStartTime = Date.now()

error = (text) -> console.error inColor("red", "ERROR: " + text)
warning = (text) -> console.log inColor("orange", "Warning: " + text)
notice = (text) -> console.log inColor("yellow", text)
taskinfo = (text) -> if isVerbose or isDebug then console.log inColor("cyan", text)
info = (text) -> if isVerbose or isDebug then console.log inColor("purple", text)
debug = (text) ->
  if not isDebug then return
  now = (Date.now() - appStartTime) / 1000.0
  console.log inColor("green", sprintf.sprintf "[%06.3f] %s", now, text)
mark = ->
  console.log inColor("yellow", "----- ") + inColor("brightCyan", strftime("%H:%M:%S [%d-%b-%Y]"))

exports.useColors = useColors
exports.setVerbose = setVerbose
exports.setDebug = setDebug
exports.inColor = inColor
exports.error = error
exports.warning = warning
exports.notice = notice
exports.taskinfo = taskinfo
exports.info = info
exports.debug = debug
exports.mark = mark

