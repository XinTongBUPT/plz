plz
===

Plz is a script automation system like "make", "rake", and "cake". It aims to
make simple tasks trivial, and difficult tasks easier. Highlights:

- No waiting for a JVM to launch. Rules are written in coffeescript (or
  javascript) and executed by the (fast) v8 engine. 
- No console spew. The default logging level runs silent unless there's an
  error.
- Most of the basic shell commands are exposed as global functions via
  shelljs (https://github.com/arturadib/shelljs), or just call "exec".
- Tasks can depend on other tasks, attach themselves before/after other
  tasks, or they can be run automatically when a file changes, based on glob
  patterns.


Install
-------

Make sure you have node installed (http://nodejs.org/), then:

```sh
$ sudo npm install -g plz --registry http://www.lag.net/npm
```


Example
-------

Here's a sample `build.plz` rules file that says:

- for "build", compile coffeescript from `src/` to `lib/`
- whenever anything in `lib/` changes, run the (mocha) tests again

Since it's just a normal script, we pull out the coffee & mocha binaries to
the top, in case we need to change them later.

```coffeescript
coffee = "./node_modules/coffee-script/bin/coffee"
mocha = "./node_modules/mocha/bin/mocha"

task "build", description: "compile coffeescript", run: ->
  mkdir "-p", "lib"
  exec "#{coffee} -o lib -c src"

task "test", description: "run unit tests", watch: "lib/**/*", run: (options) ->
  display = options.display or "spec"
  exec "#{mocha} -R #{display} --compilers coffee:coffee-script --colors"
```

You can run plz alone, which will find the `build.plz` and run the default
rule (`build`):

```sh
$ plz
```

or you can run tests alone, choosing the dot display:

```sh
$ plz test display=dot
```


Execution
---------

For every task listed on the command line, plz looks up the recursive
dependencies based on the `must` field of each task, and inserts them into the
list so they're executed before that task. Each task is executed exactly once,
and in the order listed (unless dependencies required it to be executed
earlier).

At the end of this cycle, if any file watches triggered tasks to be executed,
plz will execute these new tasks following the same rules above. As long as
file watches trigger during each cycle, plz will continue running tasks.

If a cycle completes without triggering any file watches, plz normally exits
successfully. If it's running in `--watch` mode, it will sit blocked, waiting
for files watches to trigger, until killed (usually by hitting control-C).

The `--verbose` (`-v`) option will make plz display the names of tasks as it
executes them. `--debug` will make it dump more detailed debugging info about
file watches and internal state.


Defining tasks
--------------

Tasks are defined with the `task` function:

```coffeescript
task(name, options)
```

If a task returns a promise (such as by calling `exec` -- see below), the task
execution will "block" and not run any further tasks until the promise is
fulfilled, or finished.

The options are:

- `description`: a help line to be displayed for `--help` or `--tasks`
- `must`: list of tasks that this task depends on
- `watch`/`watchall`: list of file globs that will cause this task to run
- `before`/`after`/`attach`: combine this rule with another existing rule
- `run`: the actual code to run for this task

The following globals are available to tasks:

- `task(name, options)`: create a new task
- `runTask(name)`: queue up a task to run
- `settings`: global settings object (see settings section below)
- `project`: object with project details:
    - `name`: name of the project (usually just the current folder name)
    - `type`: a string describing the project type, if a plugin has identified the project
- shell commands from [shelljs](https://github.com/arturadib/shelljs):
    - cat
    - cd
    - chmod
    - cp
    - dirs
    - echo
    - env
    - exit
    - find
    - grep
    - ls
    - mkdir
    - mv
    - popd
    - pushd
    - pwd
    - rm
    - sed
    - test
    - which
- `exec(command, options)`: see below
- `touch(filename)` which is `touch.sync` from [node-touch](https://github.com/isaacs/node-touch)
- node builtins and the Q promises library:
    - console
    - process
    - Buffer
    - Q
- logging functions, which take a string to log:
    - debug (displayed with `--debug`)
    - info (displayed with `--verbose`)
    - notice
    - warning
    - error
- `plz` object containing global state functions:
    - `useColors()`: get or set `--color`
    - `logVerbose()`: get or set `--verbose`
    - `logDebug()`: get or set `--debug`
    - `version()`: current plz version
    - `cwd()`: get or set the current folder
    - `rulesFile()`: get or set the name of the plz rules file (usually "build.plz")
- `load(pluginName)`: see the section on plugins below
- `plugins`: object that maps plugin names to functions -- see the section on plugins below

### exec

The `exec` function in plz is a lightweight wrapper around node's `spawn`
function.

```coffeescript
exec(command, options)
```

If the command is a single string, it's passed to a nested shell. If it's an
array, it's passed directly to `spawn`. The options are the same as for
`spawn`, with sensible defaults.

`exec` returns a promise which will be fulfilled with a success or failure,
but doesn't block. If you call exec twice in a row, *both commands will run at
the same time*. This is a limitation of node -- there's currently no way to
spawn a process in a blocking way. You can work around this by chaining the
promises:

```coffeescript
exec "something".then ->
  exec "something else"
```


Settings
--------

FIXME...


File watches
------------

FIXME...


Before and after tasks
----------------------

A task can ask to run before or after some other task, like:

```coffeescript
task "prebuild", before: "build", run: ->
  # perform some setup work
```

These "barnacle" tasks won't appear in the task list for `--help` or
`--tasks`. They're combined with the task they're modifying. So in this case,
the "build" task will run the setup work defined in "prebuild" before running
its own code.

Here's another example, which will print the letters A, B, C in order when the
task "hello" is executed:

```coffeescript
task "hello", run: -> notice "B"
task "pre-hello", before: "hello", run: -> notice "A"
task "post-hello", after: "hello", run: -> notice "C"
```

A task can also "attach" to another task, like this:

```coffeescript
task "build-coffee", attach: "build", description: "compile coffee-script source", run: ->
  mkdir "-p", "lib"
  exec "coffee -o lib -c src"
```

Attached tasks work exactly the same as "after", but they don't require the
original task to exist. In the above example, if the "build" task was never
defined, plz will make an empty "build" task to attach to. This is mostly a
convenience for plugins to add code to common targets like "build" and "test".


Plugins
-------

FIXME...


Manifesto
---------

Why does this exist?

"Make" is 1000 years old, and somehow still the gold standard of build
automation. "Ant" was an embarrassment; "Maven" thought maybe the problem with
ant was that it didn't have enough bureaucracy; both conflate builds with
package management. The high-level language world is on the right track with
things like "rake" and "cake", but they aren't flexible enough to grow with
you when you need to do more than just run a few shell commands.

You should be able to write some simple rules to describe how to build your
library or app or website, and those rules shouldn't require you to learn a
new language. It should be basically a list of shell commands, with some
javascript/coffeescript code if you want to get fancy, and it should run
automatically when watched files are changed.

In short, you should be able to automate command pipelines without getting
bogged down in "frameworks" or trying to figure out how to read an environment
variable or copy a file. Shell commands have been able to do this -- and so
have you -- since you were a kitten.


Developing
----------

Install dependencies using node, then build with a current version of plz:

    $ npm install
    $ plz build

Pull requests and bug reports are tracked on github:
https://github.com/robey/plz


License
-------

Apache 2 (open-source) license, included in 'LICENSE.txt'.


Authors
-------

@robey - Robey Pointer <robeypointer@gmail.com>
