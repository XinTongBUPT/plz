#
# coffee-script plugin for plz
#
# - settings.coffee
# - project.type = "coffee"
#

util = require 'util'

extend settings,
  coffee:
    bin: "./node_modules/coffee-script/bin/coffee"
    target: "./lib"
    source: "./src"
    options: []

plugins.coffee = ->
  project.type = "coffee"
  settings.mocha.options.push "--compilers coffee:coffee-script"

  task "build-coffee",
    attach: "build",
    description: "compile coffee-script source",
    watch: [ "#{settings.coffee.source}/**/*.coffee" ],
    run: (context) ->
      mkdir "-p", settings.coffee.target
      exec "#{settings.coffee.bin} -o #{settings.coffee.target} -c #{settings.coffee.source} #{settings.coffee.options.join(' ')}"

  task "test-coffee",
    attach: "test",
    watch: [ "#{settings.mocha.testSource}/**/*.coffee" ]
