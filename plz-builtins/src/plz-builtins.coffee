util = require 'util'

# default tasks for cleaning

console.log "HELLO: " + util.inspect(settings)
Q().then ->
  console.log "HELLO: " + util.inspect(settings)
  if settings.clean?.length > 0
    console.log "ok"
    task "clean", description: "erase build products: #{util.inspect(settings.clean)}", run: ->
      if not settings.clean? then settings.clean = []
      if not Array.isArray(settings.clean) then settings.clean = [ settings.clean ]
      plz.monitor(false)
      (settings.clean or []).map (f) -> rm "-rf", f
      rm "-f", plz.stateFile()

    if settings.distclean?.length > 0
      task "distclean", must: "clean", description: "erase everything that isn't part of a distribution: #{util.inspect(settings.distclean)}", run: ->
        if not settings.distclean? then settings.distclean = []
        if not Array.isArray(settings.distclean) then settings.distclean = [ settings.distclean ]
        (settings.distclean or []).map (f) -> rm "-rf", f




# ----- coffee plugin
extend settings,
  coffee:
    bin: "./node_modules/coffee-script/bin/coffee"
    target: "./lib"
    source: "./src"
    options: []

plugins.coffee = ->
  settings.mocha.options.push "--compilers coffee:coffee-script"

  task "build-coffee", attach: "build", description: "compile coffee-script source", watch: "#{settings.coffee.source}/**/*.coffee", run: ->
    mkdir "-p", settings.coffee.target
    exec "#{settings.coffee.bin} -o #{settings.coffee.target} -c #{settings.coffee.source} #{settings.coffee.options.join(' ')}"

  task "test-coffee", attach: "test", watch: [ "#{settings.mocha.testSource}/**/*.coffee" ]

# ----- mocha plugin
extend settings,
  mocha:
    bin: "./node_modules/mocha/bin/mocha"
    source: "./lib"
    testSource: "./test"
    display: "spec"
    grep: null
    options: [ "--colors" ]

plugins.mocha = ->
  task "test-mocha",
    attach: "test",
    description: "run unit tests",
    watch: [ "#{settings.mocha.source}/**/*.js", "#{settings.mocha.testSource}/**/*.js" ],
    run: ->
      if settings.mocha.grep? then settings.mocha.options.push "--grep '#{settings.mocha.grep}'"
      exec "#{settings.mocha.bin} -R #{settings.mocha.display} #{settings.mocha.options.join(' ')}"

