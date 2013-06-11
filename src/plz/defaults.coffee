exports.defaults = '''

extend = (map1, map2) ->
  for k, v of map2 then map1[k] = v
  map1

# ----- coffee plugin
extend settings,
  coffee_bin: "./node_modules/coffee-script/bin/coffee"
  coffee_lib: "./lib"
  coffee_src: "./src"
  coffee_options: []

plugins.coffee = ->
  settings.mocha_options.push "--compilers coffee:coffee-script"
  task "build-coffee", attach: "build", run: ->
    mkdir "-p", settings.coffee_lib
    exec "#{settings.coffee_bin} -o #{settings.coffee_lib} -c #{settings.coffee_src} #{settings.coffee_options.join(' ')}"

  task "test-coffee", attach: "test", watch: "#{settings.coffee_lib}/**/*"

# ----- mocha plugin
extend settings,
  mocha_bin: "./node_modules/mocha/bin/mocha"
  mocha_display: "spec"
  mocha_grep: null
  mocha_options: [ "--colors" ]

plugins.mocha = ->
  task "test-mocha", attach: "test", run: ->
    if settings.mocha_grep? then settings.mocha_options.push "--grep #{settings.mocha_grep}"
    exec "#{settings.mocha_bin} -R #{settings.mocha_display} #{settings.mocha_options.join(' ')}"

'''
