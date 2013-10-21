---
layout: page
title: How it works
description: "?"
category: articles
---

When you launch plz, it will search for a rules file, looking in these places, in order, until it finds one or fails:

1. a filename passed via the `-f` option
2. a filename passed via the `PLZ_RULES` environment variable
3. a file named `build.plz` in the current folder
4. a file named `build.plz` in the parent folder, recursively, until hitting the filesystem root

It will also try to load a saved-state file, from these places, in order:

1. a filename passed via the `PLZ_STATE` environment variable
2. a file named `.plz/state` in the folder where the rules file was found

It will then assemble a list of tasks to execute, based on:

1. tasks listed by name on the command-line
2. tasks triggered by file watches

Plz uses the saved-state file to notice any files that have changed since the last execution, so tasks may be triggered immediately.

After assembling the list of tasks to execute, it will add any `must` dependencies (see <a href="{{ baseurl }}/articles/writing-tasks.html#dependencies">Dependencies</a>), and sorts them (topologically) so that the deepest dependencies come first. Chains of dependencies are followed, but cycles aren't allowed. These are all then enqueued, uniquely, so that no task is enqueued twice. The tasks may then be re-ordered based on `depends` dependencies, if necessary.

Plz then runs each task in the queue, one at a time, in order, until there's an error or the queue is finished.

When it's done running the queue, plz collects any file watches that were triggered in the meantime. If new tasks should be executed, they (and their dependencies) are enqueued and the cycle begins again. This continues until all of the tasks in the queue can be run without triggering new file watches.

Normally, plz will then exit.

If it's running in `--watch` (`-w`) mode, plz will block instead, waiting for file watches to trigger, until killed (usually by hitting control-C).

The `--verbose` (`-v`) option will make plz display the names of tasks as it
executes them.

The `--debug` (`-D`) option will make it dump more detailed debugging info about file watches and internal state, including which file changes triggered which tasks.
