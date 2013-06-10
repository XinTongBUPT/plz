# completed stories

- a task list, with help (description) lines, shows up at "--help" and
  "--tasks".

- a default ("all") command runs when nothing else is specified.

- can turn off colors with "--no-colors" or a dotfile.

- a task can also say it should be run before or after any other task.

- before/after tasks are consolidated with their target so that they behave
  as a single task.

- all basic shelljs commands are available in the global context, as well as
  a version of "exec" that returns a promise (in case you want to do some
  sequential "exec"s).

- almost nothing is logged by default, but "--verbose" logs some basic info,
  and "--debug" tells you what it's thinking as it works.

- dependent tasks are topo-sorted and executed in that order.

- the syntax is something like:

```coffeescript
task 'name', description: "do something", run: ->
  mkdir "-p", "whatever"
  exec "gcc -O3 --stuff"
```

- a task can handle its own command-line options, using "key=value"
  command-line arguments.

- each task listed on the command line is run in order, sequentially, without
  overlap. the same applies to before/after execution, and dependencies.

- instead of manual dependency lists, a task can auto-run when a file is
  changed (or created or deleted), based on a list of globs. for example,
  the executable ELF file is created when any "*.o" file changes. the C
  files are recompiled when any "*.[ch]" file changes. touching a C file
  will cause a recompile, which touches the object files, which causes the
  ELF file to be rebuilt.

- by default, the requested commands are executed, and the program exits.
  a command-line option makes it stay running, watching the requested files,
  and starting commands as they change.

- the config object (with things like "--no-color") is accessible in task
  files as "plz".

- new tasks can be queued ("queueTask"?) from inside running tasks.

- javascript should be okay (just detect a lack of "->").

- plugins can be loaded via a "plugin" function that searches PLZPATH.

- any command-line options can be passed in a .plzrc also (PLZRC).


# unfinished stories

- plugins can add features to the global context (like 'mocha' or 'coffee').

- a global "project" object can be used to determine at minimum the "type"
  (folder layout, like "node") and "name" (name of the folder), for use by
  plugins.

- a "base rules" file can be loaded by naming it in an env var ("PLZRULES"?).

