sprintf = require 'sprintf'

usingColors = process.stdout.isTTY
useColors = (bool) -> usingColors = bool

isVerbose = false
setVerbose = (bool) -> isVerbose = bool

isDebug = false
setDebug = (bool) -> isDebug = bool

colors =
  yellow: "33;1"
  orange: "33"
  red: "31"
  purple: "35"
  blue: "34;1"
  brightCyan: "36;1"
  cyan: "36"
  green: "32"
  black: "30"
  gray: "37"
  white: "37;1"
  off: "0"

inColor = (color, text) ->
  if usingColors
    "\u001b[#{colors[color]}m#{text}\u001b[0m"
  else
    text

appStartTime = Date.now()

error = (text) -> console.error inColor("red", "ERROR: " + text)
warning = (text) -> console.log inColor("orange", "Warning: " + text)
notice = (text) -> console.log text
taskinfo = (text) -> if isVerbose or isDebug then console.log inColor("cyan", text)
info = (text) -> if isVerbose or isDebug then console.log inColor("blue", text)
debug = (text) ->
  if not isDebug then return
  now = (Date.now() - appStartTime) / 1000.0
  console.log inColor("green", sprintf.sprintf "[%06.3f] %s", now, text)

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
