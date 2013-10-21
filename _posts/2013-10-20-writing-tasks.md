---
layout: page
title: Writing tasks
description: "?"
category: articles
---

Tasks are defined with the `task` function:

```coffeescript
task(name, options)
```

The options object should contain, at minimum, a description and some code to run. For example:

```coffeescript
task "lucky", description: "calculate your lucky number", run: ->
  notice "Your lucky number is #{Math.round(Math.random() * 100)}!"
```

The description is used in the output of `--help` or `--tasks`:

```bash
$ plz --tasks
Known tasks:
  lucky - calculate your lucky number
```

The complete list of options is:

- `description`: long-form description for humans
- `before`: prepend this task to another task, by name
- `after`: append this task to another task, by name
- `attach`: append this task to another task, by name, creating the task if necessary
- `must`: execute the listed tasks before this task, no matter what
- `depends`: if the listed tasks are queued for execution, prioritize them ahead of this task
- `watch`: execute this task if any of the listed files change
- `watchall`: execute this task if any of the listed files change or are deleted
- `always`: execute this task every time, no matter what
- `run`: function to run when executing this task

They're described in more detail below.


## Watching files

If a task is "watching" files, it will be queued for execution whenever any of those files change.

The `watch` or `watchall` option takes a pattern (or list of patterns) in the style of [glob](https://npmjs.org/package/glob) or [globwatcher](https://npmjs.org/package/globwatcher). The patterns use normal shell syntax:

- `?` matches a single character
- `*` matches any part of a filename
- `**` matches zero or more folder/directory names

For example, this task will execute whenever any file in the "images" folder that ends with "jpg" is created or changed:

```coffeescript
task "images", watch: "images/**/*.jpg", run: (context) ->
  for filename in context.filenames
    notice "File #{filename} is an image."
```

A `watch` is triggered whenever a file matching that pattern is created or modified. Modified files are detected by size changes or "modification time" changes -- but be aware that some operating systems like OS X and Windows only track file modification times to the nearest second or two.

A `watchall` is additionally triggered when any file matching that pattern is deleted. Usually you don't want this mode, because if you have a "clean" task that deletes files, it may trigger build tasks, with unexpected (but hilarious) results.

Watches are powerful and are key to plz's power. Whenever possible, you should prefer watches over explicit dependencies. If you ever wonder why a task is executing, use the "-v" (verbose) option to see when a task is triggered by a file watch, and "-D" to see which files are changing and which tasks they're triggering.


## Run function

The `run` function takes an optional argument: a `context` object with the following fields:

- `settings` - a copy of the global settings object
- `filenames` - the list of filenames that caused this task to be executed

The `filenames` field is only meaningful if the task is watching files. If this task is being executed because a watch triggered, `filenames` will be the list of files that changed or were newly created. (For "watchall", newly deleted files are also included.) If the task is triggered for some other reason -- for example, by being listed on the command line -- then `filenames` will be the list of all files that currently exist and match the watch.

The function may return any value, which is ignored. If the function returns a promise, plz will wait for the promise to complete before moving on.


## Dependencies

You may set explicit dependencies between tasks in two ways: `must` or `depends`.

A task that *must* run before this task forces the dependent task to be executed whenever this task is. For example, to force the "push" task to verify that the site is healthy first, you might use:

```coffeescript
task "push", describe: "push new code to production", must: "verify-site", run: ->
  # ...

task "verify-site", describe: "verify that the production site is healthy", run: ->
  # ...
```

To enforce a general ordering of tasks that only takes effect if both tasks will be executed, use `depends`. This is useful for hinting that there's an optimal ordering to execute some tasks. For example, changing a source file might trigger both "compile" to re-compile the source, and "test" to run the unit tests. But it would be pointless to run the tests before compiling, since re-compiling will just trigger the tests again, so:

```coffeescript
task "compile", watch: "src/**/*.c", run: ->
  # ...

task "test", watch: [ "src/**/*.c", "test/*" ], depends: "compile", run: ->
  # ...
```


## Before and after tasks

A task may ask to run before or after some other task, which will merge the two tasks. The attached task's function will be executed before or after the original task, and any dependencies or watches will be merged. The attached task won't show up in the task list -- it's now part of the original task.

For example, to ensure that all folders are created before compiling:

```coffeescript
task "make-folders", before: "compile", run: ->
  mkdir "-p", "target"
```

`attach` works exactly like `after`, but doesn't require the original task to exist. This is a convenience for letting plugins run code for common tasks without having to test if those tasks exist.

```coffeescript
task "build-coffee", attach: "build", description: "compile coffee-script source", run: ->
  mkdir "-p", "lib"
  exec "coffee -o lib -c src"
```
