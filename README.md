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


API
---

FIXME...

Tasks are defined with the `task` function:

```coffeescript
task(name, options)
```

The options are:

- `description`: a help line to be displayed for `--help` or `--tasks`
- `must`: list of tasks that this task depends on
- `watch`: list of file globs that will cause this task to run
- `before` or `after`: combine this rule with another existing rule
- `run`: the actual code to run for this task


Dependent tasks
---------------

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
