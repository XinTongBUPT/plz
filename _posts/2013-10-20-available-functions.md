---
layout: page
title: Available functions
description: "?"
category: articles
---

Plz provides a number of global functions (and a few objects) for use in build files or tasks.


## <a name="basic-globals"></a> Basic globals

- `console` - the node [console object](http://nodejs.org/api/stdio.html)
- `process` - the node [process library](http://nodejs.org/api/process.html)
- `Buffer` - node's [buffer data type](http://nodejs.org/api/buffer.html)
- `Q` - the [Q promise library](http://documentup.com/kriskowal/q/), auto-imported
- `glob(pattern, [options])` - a wrapper for [glob](https://github.com/isaacs/node-glob) which returns a promise instead of taking a callback
- `extend(object, properties)` - simple object merge that shallow-copies all fields from `properties` into `object` and returns `object`
- `load(name)` - load a plz plugin (see [Plugins](./plugins.html))
- `plugins` - object mapping plugin names to plugins that have already been loaded

Some examples:

```coffeescript
glob("assets/js/*.js").then (filenames) ->
  for filename in filenames
    notice "Another glorious javascript file! I found: #{filename}"

cat =
  name: "Snowball II"
extend(cat, color: "black")
# 'cat' now has both fields
```


## <a name="logging"></a> Logging

Several global functions will write to the terminal, based on the current verbose/debugging mode, and using colors (when available) to indicate severity.

- `debug(text)` - displayed with `--debug` (`-D`)
- `info(text)` - displayed with `--verbose` (`-v`) or `--debug` (`-D`)
- `notice(text)`
- `warning(text)`
- `error(text)`
- `mark()` - to quickly log the current date/time


## <a name="shell-commands"></a> Shell commands

The following functions are imported from [shelljs](https://github.com/arturadib/shelljs) and [node-touch](https://github.com/isaacs/node-touch) into the global namespace:

- `cat`
- `cd`
- `chmod`
- `cp`
- `dirs`
- `echo`
- `env`
- `exit`
- `find`
- `grep`
- `ls`
- `mkdir`
- `mv`
- `popd`
- `pushd`
- `pwd`
- `rm`
- `sed`
- `test`
- `touch`
- `which`

They generally work just like the corresponding shell commands (including commonly supported options):

```coffeescript
mkdir "-p", "build/classes/main"
cp "src/#{filename}" "dist/original/#{filename}"
touch "/tmp/stop"
```

All of the shell functions are blocking: they don't return until they're complete.


## <a name="exec"></a> Exec

For running external commands, `exec` is a lightweight wrapper around node's `spawn` function.

- `exec(command, [options])`

If the command is a single string, it's passed to a nested shell. If it's an array, it's passed directly to `spawn`. The options are the same as for `spawn`, with sensible defaults.

For example, to launch the coffee-script compiler:

```coffeescript
exec("./node_modules/coffee-script/bin/coffee -o lib/ -c src/").then ->
  info "done!"
```

`exec` returns a promise which will be fulfilled with a success or failure, but doesn't block. If you call `exec` twice in a row, *both commands will run at the same time*. This is a limitation of node -- there's currently no way to spawn a process in a blocking way. You can work around this by chaining the promises:

```coffeescript
exec "something".then ->
  exec "something else"
```


## <a name="settings"></a> Settings

A global `settings` object is available to tasks for configuration. Each field in this object is either a string, or a nested object (to allow for namespaced settings). They're loaded in this order:

1. Any javascript/coffeescript global code in the rules file (or plugins or loaded modules) will run first. Usually this is used to set default values.

2. If the file `$HOME/.plzrc` exists, or the environment variable `PLZRC` is set, that file is loaded. It should contain `key=value` pairs, one per line. Blank lines and comments (lines starting with "#") are allowed.

3. Finally, any `key=value` pairs on the command line will take effect.

For `key=value` pairs, the key can be a dotted path like "mocha.display" to access the nested field "display" on the settings object "mocha". Plugins use dotted paths for namespacing.

```coffeescript
settings.gcc.warn = "-Wall"

task "compile", run: ->
  # ...
  exec "gcc #{settings.gcc.warn} ..."
```


## <a name="project-info"></a> Project info

A `project` object in the global namespace has at least two properties:

- `name` - the name of the project folder
- `type` - "basic"

Plz doesn't use this setting itself, but plugins may add more info, or change the name or type. For example, a coffee-script plugin might set the project type to "coffee" to indicate to other plugins and tasks that this is primarily a coffee-script project.


## <a name="configuration"></a> Configuration

A `plz` object contains function for getting or setting global configuration. Each function returns the current value, and takes a single parameter to optionally change it.

- `useColors([value])` - the `--colors` command-line option
- `logVerbose([value])` - the `--verbose` command-line option
- `logDebug([value])` - the `--debug` command-line option
- `cwd([value])` - the current folder (equivalent to `process.chdir` and `process.cwd`)
- `rulesFile([filename])` - the filename rules were loaded from
- `stateFile([filename])` - the filename that file-watch state was loaded from and will be written
- `monitor([value])` - whether file watches should run
- `version()` - current plz version string

Obviously, it's useless to set `rulesFile` once plz is running, and `version` can't be changed.

`monitor` allows you to shut off the file watching system, which should cause plz to exit after the current queue of tasks is finished. This is used by the "clean" task to avoid triggering file watches when build products are erased.

```coffeescript
info "Current color setting: #{plz.useColors()}"
plz.useColors(false)
info "Colors are now OFF."
```

## <a name="tasks"></a> Tasks

You can, of course, create and execute tasks directly.

- `task(name, options)` - create a new task (see [Writing tasks](./writing-tasks.html))
- `runTask(name, [filename])` - run a task, by name

The optional filename to `runTask` will add a filename to the list of files that triggered the task to run, as if it were triggered by a file watch. Any triggered tasks are enqueued, and will be executed once the current set of tasks is finished.

For example, the task "check" will trigger the task "stop" if a certain file exists:

```coffeescript
task "check", run: ->
  if fs.existsSync(STOP_FILENAME) then runTask("stop")

task "stop", run: ->
  # stop! ...
```
