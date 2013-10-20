---
layout: post
title: Writing tasks
description: "Just about everything you'll need to style in the theme: headings, paragraphs, blockquotes, tables, code blocks, and more."
category: articles
---

<section id="table-of-contents" class="toc">
  <header>
    <h3>Contents</h3>
  </header>
<div id="drawer" markdown="1">
*  Auto generated table of contents
{:toc}
</div>
</section><!-- /#table-of-contents -->

# Writing tasks

Tasks are defined with the `task` function:

```coffeescript
task(name, options)
```

The options are:

- `description`: a help line to be displayed for `--help` or `--tasks`

- `must`: list of tasks that this task depends on
- `depends`: list of tasks that should be run before this task if they run at all

- `watch`/`watchall`: list of file globs that will cause this task to run

- `before`/`after`/`attach`: combine this rule with another existing rule
- `always`:

- `run`: the actual code to run for this task

## Watching

```coffeescript
# task "name",
#   description: "displayed in help"
#   before: "task"  # run immediately before another task, when that task is run
#   after: "task"   # run immediately after another task, when that task is run
#   attach: "task"  # run immediately after another task, or if that task doesn't exist, replace it
#   depends: [ "task", "task" ]     # if these tasks will run in the same execution, run them first
#   must: [ "task", "task" ]        # run these dependent tasks first, always
#   watch: [ "file-glob" ]          # run this task when any of these files change
#   watchall: [ "file-glob" ]       # run this task when any of these files change or are deleted
#   always: true    # run this task always
#   run: (context) -> ...           # code to run when executing
```

## to-do

If a task returns a promise (such as by calling `exec` -- see below), the task
execution will "block" and not run any further tasks until the promise is
fulfilled, or finished.

context object, what's in it
