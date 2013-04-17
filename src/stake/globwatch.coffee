
events = require 'events'
fs = require 'fs'
glob = require 'glob'
minimatch = require 'minimatch'
path = require 'path'
Q = require 'q'
util = require 'util'

futureGlob = (pattern, options) ->
  deferred = Q.defer()
  glob pattern, options, deferred.makeNodeResolver()
  deferred.promise

futureReaddir = (folderName) ->
  deferred = Q.defer()
  fs.readdir folderName, deferred.makeNodeResolver()
  deferred.promise


exports.globwatch = (pattern, options) ->
  g = new GlobWatch(pattern, options)

class GlobWatch extends events.EventEmitter
  constructor: (pattern, options={}) ->
    @closed = false
    @cwd = options.cwd or process.cwd()
    @debounceInterval = options.debounceInterval or 100
    @interval = options.interval or 1000
    @debug = options.debug or (->)
    # map of (absolute) folderName -> filenames[]
    @watchMap = {}
    # map of (absolute) folderName -> FSWatcher
    @watchers = {}
    # (ordered) list of glob patterns to watch
    @patterns = []
    @add(pattern)

  add: (patterns...) ->
    @debug "add: #{util.inspect(patterns)}"
    for p in patterns
      p = @absolutePath(p)
      if @patterns.indexOf(p) < 0 then @patterns.push(p)

    @ready = Q.all(
      for p in @patterns
        futureGlob(p, nonegate: true).then (files) =>
          for filename in files then @addWatch(filename)
    ).then =>
      @stopWatches()
      @startWatches()
      # give a little delay to wait for things to calm down
      Q.delay(@debounceInterval)
    .then =>
      @debug "add complete: #{util.inspect(patterns)}"
      @

  close: ->
    @debug "close"
    @stopWatches()
    @watchMap = {}
    @closed = true

  # ----- internals:

  absolutePath: (p) ->
    if p[0] == '/' then p else path.join(@cwd, p)

  isMatch: (filename) ->
    for p in @patterns then if minimatch(filename, p, nonegate: true) then return true
    false

  addWatch: (filename) ->
    isdir = try
      fs.statSync(filename).isDirectory()
    catch e
      false
    if isdir
      # watch whole folder
      filename += "/"
      @watchMap[filename] or= []
    parent = path.dirname(filename)
    if parent != "/" then parent += "/"
    (@watchMap[parent] or= []).push filename

  stopWatches: ->
    for filename, watcher of @watchers then watcher.close()
    for folderName, filenames of @watchMap
      fs.unwatchFile(folderName)
      for filename in filenames then fs.unwatchFile(filename)
    @watchers = {}

  startWatches: ->
    for folderName, filenames of @watchMap
      @watchFolder folderName
      for filename in filenames
        if filename[filename.length - 1] != "/" then @watchFile filename

  # FIXME may throw an exception
  watchFolder: (folderName) ->
    @watchers[folderName] = fs.watch folderName, (event) =>
      @debug "watch event: #{util.inspect(folderName)}"
      # wait a short interval to make sure the new folder has some staying power.
      setTimeout((=> @folderChanged(folderName)), @debounceInterval)
    
  # FIXME may throw an exception
  watchFile: (filename) ->
    fs.watchFile filename, { persistent: false, interval: @interval }, (curr, prev) =>
      @debug "watchFile event: #{filename} #{prev.mtime.getTime()} -> #{curr.mtime.getTime()}"
      if curr.mtime.getTime() != prev.mtime.getTime() and fs.existsSync(filename) then @emit 'changed', filename

  unwatch: (filename) ->
    if @watchMap[filename]?
      # folder!
      fs.unwatchFile(filename)
      for f in @watchMap[filename] then fs.unwatchFile(f)
      delete @watchMap[filename]
    else
      parent = path.dirname(filename)
      if parent != "/" then parent += "/"
      index = (@watchMap[parent] or []).indexOf(filename)
      if index >= 0
        fs.unwatchFile(filename)
        delete @watchMap[parent][index]
    if @watchers[filename]
      @watchers[filename].close()
      delete @watchers[filename]

  folderChanged: (folderName) ->
    return if @closed
    futureReaddir(folderName)
    .fail (error) =>
      []
    .then (current) =>
      return if @closed
      # add "/" to folders
      current = current.map (filename) ->
        filename = path.join(folderName, filename)
        try
          if fs.statSync(filename).isDirectory() then filename += "/"
        catch e
          # file vanished before we could stat it!
        filename
      previous = @watchMap[folderName] or []

      for f in previous.filter((x) -> current.indexOf(x) < 0)
        @debug "file deleted: #{f}"
        @unwatch f
        if f[f.length - 1] != '/' then @emit 'deleted', f

      for f in current.filter((x) -> previous.indexOf(x) < 0)
        if f[f.length - 1] != '/'
          if @isMatch(f)
            @debug "file added: #{f}"
            (@watchMap[folderName] or= []).push f
            @watchFile f
            @emit 'added', f
        else
          # if the folder is new, recursively check for new matching files.
          @folderChanged(f)
