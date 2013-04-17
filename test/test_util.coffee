
# run a test as a future, and call mocha's 'done' method at the end of the chain.
exports.futureTest = (f) ->
  (done) ->
    f().then((-> done()), ((error) -> done(error)))
