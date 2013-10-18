fs = require 'fs'
minimatch = require 'minimatch'
mocha_sprinkles = require 'mocha-sprinkles'
path = require 'path'
Q = require 'q'
shell = require 'shelljs'
should = require 'should'
touch = require 'touch'
util = require 'util'

exec = mocha_sprinkles.exec
future = mocha_sprinkles.future
withTempFolder = mocha_sprinkles.withTempFolder

dump = (x) -> util.inspect x, false, null, true

binplz = "#{process.cwd()}/bin/plz"

#
# effectively integration tests.
# verify the behavior of 'bin/plz'.
#
describe "plz (system binary)", ->
  it "responds to --help", future ->
    exec("#{binplz} --help").then (p) ->
      p.stderr.toString().should.eql("")
      p.stdout.toString().should.match /usage:/
      p.stdout.toString().should.match /options:/

  it "describes existing tasks in --help and --tasks", future withTempFolder (folder) ->
    fs.writeFileSync "#{folder}/rules", "task 'xyzzy', desc: 'plover', run: ->\n"
    exec("#{binplz} -f rules --help")
    .then (p) ->
      p.stderr.toString().should.eql("")
      p.stdout.toString().should.match /xyzzy/
      p.stdout.toString().should.match /plover/
      exec("#{binplz} -f rules --tasks")
    .then (p) ->
      p.stdout.should.match(/Known tasks:\n  xyzzy - plover\n/)

  it "obeys --colors and --no-colors", future withTempFolder (folder) ->
    fs.writeFileSync "#{folder}/rules", "task 'xyzzy', desc: 'plover', run: ->\n"
    exec("#{binplz} -D -f rules --color --help")
    .then (p) ->
      p.stdout.should.match(/\n\u001b\[32m\[\d\d\.\d\d\d] Defining task: xyzzy/)
      exec("#{binplz} -D -f rules --no-color --help")
    .then (p) ->
      p.stdout.should.match(/\n\[\d\d\.\d\d\d\] Defining task: xyzzy/)

  it "can be made verbose via .plzrc", future withTempFolder (folder) ->
    fs.writeFileSync "#{folder}/rules", 'task "build", run: -> info "hello!"\n'
    fs.writeFileSync "#{folder}/plzrc", "options=--verbose\n"
    env = { "PLZRC": "#{folder}/plzrc" }
    for k, v of process.env then env[k] = v
    exec("#{binplz} -f rules build", env: env)
    .then (p) ->
      p.stdout.should.match(/hello!\n/)

  it "can do basic shell commands", future withTempFolder (folder) ->
    fs.writeFileSync "#{folder}/rules", SHELL_TEST
    exec("#{binplz} -f rules wiggle")
    .then (p) ->
      p.stdout.should.match(/Warning: bumblebee cicada rules\n/)

  it "can do glob", future withTempFolder (folder) ->
    fs.writeFileSync "#{folder}/rules", GLOB_TEST
    shell.mkdir "-p", "#{folder}/stuff"
    fs.writeFileSync "#{folder}/stuff/file1", "first"
    fs.writeFileSync "#{folder}/stuff/file2", "not first"
    exec("#{binplz} -f rules build")
    .then (p) ->
      p.stdout.should.match(/Warning: files: stuff\/file1, stuff\/file2\n/)

  it "can attach a task before another one", future withTempFolder (folder) ->
    fs.writeFileSync "#{folder}/rules", BEFORE_TEST
    exec("#{binplz} -f rules main")
    .then (p) ->
      p.stdout.should.match(/even worse.\nbarnacle.\nmain.\n/)

  it "can attach a task after another one", future withTempFolder (folder) ->
    fs.writeFileSync "#{folder}/rules", AFTER_TEST
    exec("#{binplz} -f rules main")
    .then (p) ->
      p.stdout.should.match(/main.\nbarnacle.\neven worse.\n/)

  it "can attach tasks on both sides", future withTempFolder (folder) ->
    fs.writeFileSync "#{folder}/rules", AROUND_TEST
    exec("#{binplz} -f rules --tasks")
    .then (p) ->
      p.stdout.should.match(/Known tasks:\n  main - plover\n\n/)
      exec("#{binplz} -f rules main")
    .then (p) ->
      p.stdout.should.match(/barnacle 1.\nmain.\nbarnacle 2.\n/)

  it "can execute lines sequentially", future withTempFolder (folder) ->
    fs.writeFileSync "#{folder}/rules", EXEC_TEST
    exec("#{binplz} -f rules sleeper")
    .then (p) ->
      p.stdout.should.match(/hello\ngoodbye\n/)

  it "topo-sorts dependent tasks and runs each only once", future withTempFolder (folder) ->
    fs.writeFileSync "#{folder}/rules", TOPO_TEST
    exec("#{binplz} -f rules pets")
    .then (p) ->
      p.stdout.should.eql "bee\ncat\ndog\npets!\n"
      exec("#{binplz} -f rules pets cat")
    .then (p) ->
      p.stdout.should.eql "bee\ncat\ndog\npets!\n"

  it "runs without exiting, waiting for file changes", future withTempFolder (folder) ->
    fs.writeFileSync "#{folder}/rules", RUN_TEST.replace("%FOLDER%", folder)
    f1 = exec("#{binplz} -w -f rules main").then (p) ->
      p.stdout.should.match(/hello\ngoodbye\n/)
    f2 = Q.delay(500).then ->
      fs.writeFileSync "#{folder}/die.x", "die!"
    Q.all([ f1, f2 ])

  describe "watches files", ->
    it "for adds & changes", future withTempFolder (folder) ->
      shell.mkdir "-p", "#{folder}/stuff"
      fs.writeFileSync "#{folder}/rules", RUN_TEST_2.replace(/%STUFF%/g, "#{folder}/stuff").replace(/%FOLDER%/g, "#{folder}")
      fs.writeFileSync "#{folder}/stuff/exists.x", "exists"
      f1 = exec("#{binplz} -w -f rules build").then (p) ->
        p.stdout.should.match(/hi.\nnormal watch\nnormal watch\n/)
      f2 = Q.delay(500).then ->
        fs.writeFileSync "#{folder}/stuff/new.x", "new"
        Q.delay(1000).then ->
          fs.writeFileSync "#{folder}/stuff/exists.x", "different!"
      f3 = Q.delay(2000).then ->
        fs.writeFileSync "#{folder}/die.x", "die!"
      Q.all([ f1, f2, f3 ])

    it "for deletes too", future withTempFolder (folder) ->
      shell.mkdir "-p", "#{folder}/stuff"
      fs.writeFileSync "#{folder}/rules", RUN_TEST_3.replace(/%STUFF%/g, "#{folder}/stuff").replace(/%FOLDER%/g, "#{folder}")
      fs.writeFileSync "#{folder}/stuff/exists.x", "exists"
      f1 = exec("#{binplz} -w -f rules").then (p) ->
        p.stdout.should.match(/normal watch\nall watch\nall watch\n/)
      f2 = Q.delay(500).then ->
        fs.unlinkSync "#{folder}/stuff/exists.x"
      f3 = Q.delay(2000).then ->
        fs.writeFileSync "#{folder}/die.x", "die!"
      Q.all([ f1, f2, f3 ])

    it "and reports their names", future withTempFolder (folder) ->
      re = new RegExp("#{folder}/stuff", "g")
      shell.mkdir "-p", "#{folder}/stuff"
      fs.writeFileSync "#{folder}/rules", RUN_TEST_4.replace(/%STUFF%/g, "#{folder}/stuff").replace(/%FOLDER%/g, "#{folder}")
      fs.writeFileSync "#{folder}/stuff/exists.x", "exists"
      f1 = exec("#{binplz} -w -f rules build").then (p) ->
        p.stdout.replace(re, "%STUFF%").should.match(/hi.\nchanged: %STUFF%\/exists.x\nchanged: %STUFF%\/new.x\n/)
      f2 = Q.delay(500).then ->
        fs.writeFileSync "#{folder}/stuff/new.x", "new"
      f3 = Q.delay(2000).then ->
        fs.writeFileSync "#{folder}/die.x", "die!"
      Q.all([ f1, f2, f3 ])

  describe "keeps state on watchers", ->
    it "across executions", future withTempFolder (folder) ->
      re = new RegExp("#{folder}/stuff", "g")
      shell.mkdir "-p", "#{folder}/stuff"
      fs.writeFileSync "#{folder}/rules", RUN_TEST_4.replace(/%STUFF%/g, "#{folder}/stuff").replace(/%FOLDER%/g, "#{folder}")
      fs.writeFileSync "#{folder}/stuff/exists.x", "exists"
      exec("#{binplz} -f rules").then (p) ->
        p.stdout.replace(re, "%STUFF%").should.match(/changed: %STUFF%\/exists.x\n/)
        fs.writeFileSync "#{folder}/stuff/exists2.x", "exists"
        exec("#{binplz} -f rules")
      .then (p) ->
        p.stdout.replace(re, "%STUFF%").should.match(/%STUFF%\/exists2.x\n/)

    it "in an odd place via PLZ_STATE", future withTempFolder (folder) ->
      shell.mkdir "-p", "#{folder}/stuff"
      fs.writeFileSync "#{folder}/rules", RUN_TEST_4.replace(/%STUFF%/g, "#{folder}/stuff").replace(/%FOLDER%/g, "#{folder}")
      fs.writeFileSync "#{folder}/stuff/exists.x", "exists"
      env = { "PLZ_STATE": "#{folder}/kitten" }
      for k, v of process.env then env[k] = v
      exec("#{binplz} -f rules", env: env).then (p) ->
        fs.readFileSync("#{folder}/kitten").toString().should.match /stuff\/exists.x/

    it "tracks incomplete tasks", future withTempFolder (folder) ->
      fs.writeFileSync "#{folder}/rules", RESUME_TEST.replace(/%FOLDER%/g, "#{folder}")
      exec("#{binplz} -f rules first second").then (p) ->
        throw new Error("Expected failure.")
      .fail (error) ->
        fs.writeFileSync "#{folder}/live.x", "live!!!"
        exec("#{binplz} -f rules").then (p) ->
          p.stdout.should.not.match(/first\n/)
          p.stdout.should.match(/second\n/)

  it "can turn off monitoring watches", future withTempFolder (folder) ->
    fs.writeFileSync "#{folder}/rules", MONITOR_OFF_TEST.replace(/%FOLDER%/g, "#{folder}")
    exec("#{binplz} -f rules stop").then (p) ->
      p.stdout.should.not.match(/changed:/)
      fs.existsSync("#{folder}/.plz/state").should.eql false

  it "can get and set configs", future withTempFolder (folder) ->
    fs.writeFileSync "#{folder}/rules", CONFIG_TEST
    exec("#{binplz} -f rules test").then (p) ->
      p.stdout.should.match(/ok!\ninfo 1\ndone\n/)

  it "can enqueue a task manually", future withTempFolder (folder) ->
    fs.writeFileSync "#{folder}/rules", ENQUEUE_TEST
    exec("#{binplz} -f rules start").then (p) ->
      p.stdout.should.match(/start\ncontinue\n/)

  it "enqueues 'always' tasks", future withTempFolder (folder) ->
    fs.writeFileSync "#{folder}/rules", ALWAYS_TEST
    exec("#{binplz} -f rules start").then (p) ->
      p.stdout.should.match(/always\nstart\n/)

  describe "can deliver settings to a task", ->
    it "from the command line", future withTempFolder (folder) ->
      fs.writeFileSync "#{folder}/rules", SETTINGS_TEST_1
      exec("#{binplz} -f rules citrus=\'hello there\' build").then (p) ->
        p.stdout.should.match(/^hello there\n/)

    it "from a .plzrc file", future withTempFolder (folder) ->
      fs.writeFileSync "#{folder}/rules", SETTINGS_TEST_1
      fs.writeFileSync "#{folder}/plzrc", "citrus=hello there\n"
      env = { "PLZRC": "#{folder}/plzrc" }
      for k, v of process.env then env[k] = v
      exec("#{binplz} -f rules build", env: env).then (p) ->
        p.stdout.should.match(/^hello there\n/)

    it "into the run function as a parameter", future withTempFolder (folder) ->
      fs.writeFileSync "#{folder}/rules", SETTINGS_TEST_2
      exec("#{binplz} -f rules citrus=\'hello there\' build").then (p) ->
        p.stdout.should.match(/^hello there\n/)

    it "nested", future withTempFolder (folder) ->
      fs.writeFileSync "#{folder}/rules", SETTINGS_TEST_3
      exec("#{binplz} -f rules names.commie=brown eaters.grass=cow build").then (p) ->
        p.stdout.should.match(/^brown cow\n/)

    it "following precedence", future withTempFolder (folder) ->
      # alpha: rules -> plzrc. beta: rules -> command-line. gamma: plzrc -> command-line.
      fs.writeFileSync "#{folder}/rules", SETTINGS_TEST_4
      fs.writeFileSync "#{folder}/plzrc", "alpha=rc\ngamma=rc\n"
      env = { "PLZRC": "#{folder}/plzrc" }
      for k, v of process.env then env[k] = v
      exec("#{binplz} -f rules beta=cmd gamma=cmd build", env: env).then (p) ->
        p.stdout.should.match(/^alpha: rc\nbeta: cmd\ngamma: cmd\n$/)

  describe "can load modules", ->
    it "from PLZPATH", future withTempFolder (folder) ->
      shell.mkdir "-p", "#{folder}/hidden"
      fs.writeFileSync "#{folder}/hidden/plz-whine.coffee", LOAD_TEST_WHINE
      fs.writeFileSync "#{folder}/rules", LOAD_TEST
      env = { "PLZ_PATH": "#{folder}/hidden" }
      for k, v of process.env then env[k] = v
      exec("#{binplz} -f rules build", env: env).then (p) ->
        p.stdout.should.match(/whine.\nloaded.\n/)

    it "from .plz/plugins/", future withTempFolder (folder) ->
      shell.mkdir "-p", "#{folder}/.plz/plugins"
      fs.writeFileSync "#{folder}/.plz/plugins/plz-whine.coffee", LOAD_TEST_WHINE
      fs.writeFileSync "#{folder}/rules", LOAD_TEST
      exec("#{binplz} -f rules build").then (p) ->
        p.stdout.should.match(/whine.\nloaded.\n/)

    it "from a node module", future withTempFolder (folder) ->
      shell.mkdir "-p", "#{folder}/node_modules/plz-whine"
      fs.writeFileSync "#{folder}/node_modules/plz-whine/index.js", LOAD_TEST_WHINE_JS
      fs.writeFileSync "#{folder}/rules", LOAD_TEST
      env = { "NODE_PATH": "#{folder}/node_modules" }
      for k, v of process.env then env[k] = v
      exec("#{binplz} -f rules build", env: env).then (p) ->
        p.stdout.should.match(/whine.\nloaded.\n/)

    it "delayed from within a file", future withTempFolder (folder) ->
      shell.mkdir "-p", "#{folder}/.plz/plugins"
      fs.writeFileSync "#{folder}/.plz/plugins/plz-whine.coffee", LOAD_TEST_DELAYED
      fs.writeFileSync "#{folder}/rules", LOAD_TEST
      exec("#{binplz} -f rules build").then (p) ->
        p.stdout.should.match(/whine.\nloaded.\n/)

    it "delayed from within a different file", future withTempFolder (folder) ->
      shell.mkdir "-p", "#{folder}/.plz/plugins"
      fs.writeFileSync "#{folder}/.plz/plugins/plz-smile.coffee", LOAD_TEST_DELAYED_2
      fs.writeFileSync "#{folder}/rules", LOAD_TEST_2
      exec("#{binplz} -f rules build").then (p) ->
        p.stdout.should.match(/whine.\nloaded.\n/)

  it "loads PLZ_RULES if asked", future withTempFolder (folder) ->
    fs.writeFileSync "#{folder}/rules.x", 'task "hello", run: -> notice "hello"\n'
    env = { "PLZ_RULES": "#{folder}/rules.x" }
    for k, v of process.env then env[k] = v
    exec("#{binplz} hello", env: env).then (p) ->
      p.stdout.should.match(/hello\n/)


SHELL_TEST = """
task "wiggle", run: ->
  touch "aardvark"
  cp "aardvark", "bumblebee"
  mv "aardvark", "cicada"
  warning(ls(".").join(" "))
"""

GLOB_TEST = """
task "build", run: ->
  glob("stuff/*").then (files) ->
    warning("files: " + files.join(", "))
"""

BEFORE_TEST = """
task "main", run: -> echo "main."
task "barnacle", before: "main", run: -> echo "barnacle."
task "worse", before: "barnacle", run: -> echo "even worse."
"""

AFTER_TEST = """
task "main", run: -> echo "main."
task "barnacle", after: "main", run: -> echo "barnacle."
task "worse", after: "barnacle", run: -> echo "even worse."
"""

AROUND_TEST = """
task "main", description: "plover", run: -> echo "main."
task "barnacle1", before: "main", run: -> echo "barnacle 1."
task "barnacle2", after: "main", run: -> echo "barnacle 2."
"""

EXEC_TEST = """
task "sleeper", run: ->
  exec("sleep 1 && echo hello").then ->
    exec("echo goodbye")
"""

TOPO_TEST = """
task "bee", run: ->
  echo "bee"

task "cat", must: "bee", run: ->
  echo "cat"

task "dog", must: "bee", run: ->
  echo "dog"

task "pets", must: [ "cat", "dog" ], run: ->
  echo "pets!"
"""

RUN_TEST = """
task "main", run: ->
  echo "hello"

task "end", watch: "%FOLDER%/die.x", run: ->
  echo "goodbye"
  process.exit 0

"""

RUN_TEST_2 = """
task "build", run: -> notice "hi."

task "watch", watch: "%STUFF%/*", run: ->
  notice "normal watch"

task "end", watch: "%FOLDER%/die.x", run: ->
  process.exit 0
"""

RUN_TEST_3 = """
task "build", run: -> notice "hi."

task "watch", watch: "%STUFF%/*", run: ->
  notice "normal watch"

task "watchall", watchall: "%STUFF%/*", run: ->
  notice "all watch"

task "end", watch: "%FOLDER%/die.x", run: ->
  process.exit 0
"""

RUN_TEST_4 = """
task "build", run: -> notice "hi."

task "watch", watch: "%STUFF%/*.x", run: (context) ->
  notice "changed: \#{context.filenames.join(', ')}"

task "end", watch: "%FOLDER%/die.x", run: ->
  process.exit 0
"""

MONITOR_OFF_TEST = """
task "stop", run: (context) ->
  plz.monitor(false)
  require("fs").writeFileSync "%FOLDER%/hello.x", "hello!"

task "watch", watch: "%FOLDER%/*.x", run: (context) ->
  notice "changed: \#{context.filenames.join(', ')}"
"""

CONFIG_TEST = """
task "test", run: ->
  notice "\#{plz.version()} ok!"
  plz.logVerbose(true)
  info "info 1"
  plz.logVerbose(false)
  info "info 2"
  notice "done"
"""

ENQUEUE_TEST = """
task "start", run: ->
  echo "start"
  runTask "continue"

task "continue", run: ->
  echo "continue"
"""

ALWAYS_TEST = """
task "start", run: -> echo "start"
task "notme", run: -> echo "not me"
task "always", always: true, run: -> echo "always"
"""

SETTINGS_TEST_1 = """
task "build", run: ->
  console.log settings.citrus
"""

SETTINGS_TEST_2 = """
task "build", run: (context) ->
  console.log context.settings.citrus
"""

SETTINGS_TEST_3 = '''
settings.names = { spooky: "black", commie: "gray" }

task "build", run: ->
  console.log "#{settings.names.commie} #{settings.eaters.grass}"
'''

SETTINGS_TEST_4 = '''
settings.alpha = "global"
settings.beta = "global"

task "build", run: ->
  notice "alpha: #{settings.alpha}"
  notice "beta: #{settings.beta}"
  notice "gamma: #{settings.gamma}"
'''

LOAD_TEST = """
load "whine"

task "build", run: ->
  console.log "loaded."
"""

LOAD_TEST_WHINE = """
task "prebuild", before: "build", run: ->
  console.log "whine."
"""

LOAD_TEST_WHINE_JS = """
task("prebuild", { before: "build", run: function() {
  console.log("whine.");
}})
"""

LOAD_TEST_DELAYED = """
plugins.whine = ->
  task "prebuild", before: "build", run: ->
    console.log "whine."
"""

LOAD_TEST_DELAYED_2 = """
plugins.whine = ->
  task "prebuild", before: "build", run: ->
    console.log "whine."
"""

LOAD_TEST_2 = """
load "smile"
load "whine"

task "build", run: ->
  console.log "loaded."
"""

RESUME_TEST = """
fs = require 'fs'

task "first", run: ->
  notice "first"

task "second", run: ->
  if not fs.existsSync("%FOLDER%/live.x") then throw new Error("die!")
  notice "second"
"""
