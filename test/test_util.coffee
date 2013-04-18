shell = require 'shelljs'

# run a test as a future, and call mocha's 'done' method at the end of the chain.
exports.futureTest = (f) ->
  (done) ->
    f().then((-> done()), ((error) -> done(error)))

exports.withTempFolder = (f) ->
  (x...) ->
    uniq = "/tmp/xtestx#{Date.now()}"
    shell.mkdir "-p", uniq
    f(uniq, x...).fin ->
      shell.rm "-r", uniq
