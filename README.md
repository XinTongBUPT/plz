
# why does this exist?

"make" is 1000 years old, and somehow still the gold standard of build
automation. "ant" was an embarrassment; "maven" thought maybe the problem with
ant was that it didn't have enough bureaucracy. the high-level language world
is on the right track with things like "rake" and "cake", but they aren't
flexible enough to grow with you when you need to do more than just run a few
shell commands.

you should be able to write some simple rules to describe how to build your
library or app or website, and those rules shouldn't require you to learn a
new language. it should be basically a list of shell commands, with some
javascript/coffeescript code if you want to get fancy, and it should run
automatically when watched files are changed.

in short, you should be able to automate command pipelines without getting
bogged down in "frameworks" or trying to figure out how to read an environment
variable or copy a file. shell commands have been able to do this -- and so
have you -- since you were a kitten.

# completed stories

- a task list, with help (description) lines, shows up at "--help".


# stories

- a default ("all") command runs when nothing else is specified.

- instead of manual dependency lists, a task can auto-run when a file is
  changed (or created or deleted), based on a list of globs. for example,
  the executable ELF file is created when any "*.o" file changes. the C
  files are recompiled when any "*.[ch]" file changes. touching a C file
  will cause a recompile, which touches the object files, which causes the
  ELF file to be rebuilt.

- a task can also say it should be run before or after any other task.

- all basic shelljs commands are available in the global context, as well as
  a version of "exec" that returns a promise (in case you want to do some
  sequential "exec"s).

- the syntax is something like:

```coffeescript
    task 'name', description: "do something", run: ->
      mkdir "-p", "whatever"
      exec "gcc -O3 --stuff"
```

- almost nothing is logged by default, but "--verbose" logs some basic info,
  and "--debug" tells you what it's thinking as it works.

- a task can handle its own command-line options. HOW?

- by default, the requested commands are executed, and the program exits.
  a command-line option makes it stay running, watching the requested files,
  and starting commands as they change.

- can turn off colors with "--no-colors" or a dotfile.

- each task listed on the command line is run in order, sequentially, without
  overlap. the same applies to before/after execution, and dependencies.

- before/after tasks are consolidated with their target so that they behave
  as a single task.

- dependent tasks are topo-sorted and executed in that order.
