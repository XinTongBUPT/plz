exports.defaults = '''

# ----- coffee plugin
extend settings,
  coffee:
    bin: "./node_modules/coffee-script/bin/coffee"
    lib: "./lib"
    src: "./src"
    options: []

plugins.coffee = ->
  settings.mocha.options.push "--compilers coffee:coffee-script"

  task "build-coffee", attach: "build", description: "compile coffee-script source", run: ->
    mkdir "-p", settings.coffee.lib
    exec "#{settings.coffee.bin} -o #{settings.coffee.lib} -c #{settings.coffee.src} #{settings.coffee.options.join(' ')}"

  task "test-coffee", attach: "test", watch: "#{settings.coffee.lib}/**/*"

# ----- mocha plugin
extend settings,
  mocha:
    bin: "./node_modules/mocha/bin/mocha"
    display: "spec"
    grep: null
    options: [ "--colors" ]

plugins.mocha = ->
  task "test-mocha", attach: "test", must: "build", description: "run unit tests", run: ->
    if settings.mocha.grep? then settings.mocha.options.push "--grep #{settings.mocha.grep}"
    exec "#{settings.mocha.bin} -R #{settings.mocha.display} #{settings.mocha.options.join(' ')}"

'''
