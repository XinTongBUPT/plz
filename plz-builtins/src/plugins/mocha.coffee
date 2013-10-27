#
# mocha plugin for plz
#
# - settings.mocha
#

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
    depends: "build",
    description: "run unit tests",
    watch: [ "#{settings.mocha.source}/**/*.js", "#{settings.mocha.testSource}/**/*.js" ],
    run: ->
      if settings.mocha.grep? then settings.mocha.options.push "--grep '#{settings.mocha.grep}'"
      exec "#{settings.mocha.bin} -R #{settings.mocha.display} #{settings.mocha.options.join(' ')}"
