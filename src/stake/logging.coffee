
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
    s

error = (text) -> console.error inColor("red", "ERROR: " + text)
warning = (text) -> console.log inColor("orange", "Warning: " + text)
notice = (text) -> console.log text
info = (text) -> if isVerbose then console.log inColor("cyan", text)
debug = (text) -> if isDebug then console.log inColor("green", text)

exports.useColors = useColors
exports.setVerbose = setVerbose
exports.setDebug = setDebug
exports.inColor = inColor
exports.error = error
exports.warning = warning
exports.notice = notice
exports.info = info
exports.debug = debug
