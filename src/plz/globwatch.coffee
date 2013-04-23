
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

# FIXME this should probably be in a minimatch wrapper class
folderMatchesMinimatchPrefix = (folderSegments, minimatchSet) ->
  for segment, i in folderSegments
    if i >= minimatchSet.length then return false
    miniSegment = minimatchSet[i]
    if miniSegment == minimatch.GLOBSTAR then return true
    if typeof miniSegment == "string"
      if miniSegment != segment then return false
    else
      if not miniSegment.test(segment) then return false
  true

exports.folderMatchesMinimatchPrefix = folderMatchesMinimatchPrefix


# map (absolute) folder names, which are being folder-level watched, to a
# set of (absolute) filenames in that folder that are being file-level
# watched.
class WatchMap
  constructor: ->
    # folderName -> (filename -> true)
    @map = {}

  clear: ->
    @map = {}

  watchFolder: (folderName) ->
    @map[folderName] or= {}

  unwatchFolder: (folderName) ->
    delete @map[folderName]

  watchFile: (filename, parent) ->
    if not parent? then parent = path.dirname(filename)
    (@map[parent] or= {})[filename] = true

  unwatchFile: (filename, parent) ->
    if not parent? then parent = path.dirname(filename)
    delete @map[parent][filename]

  getFolders: -> Object.keys(@map)

  getFilenames: (folderName) -> Object.keys(@map[folderName] or {})

  watchingFolder: (folderName) -> @map[folderName]?

  watchingFile: (filename, parent) ->
    if not parent? then parent = path.dirname(filename)
    @map[parent]?[filename]?


exports.globwatch = (pattern, options) ->
  g = new GlobWatch(pattern, options)

class GlobWatch extends events.EventEmitter
  constructor: (pattern, options={}) ->
    @closed = false
    @cwd = options.cwd or process.cwd()
    @debounceInterval = options.debounceInterval or 100
    @interval = options.interval or 1000
    @debug = options.debug or (->)
    @watchMap = new WatchMap
    # map of (absolute) folderName -> FSWatcher
    @watchers = {}
    # (ordered) list of glob patterns to watch
    @patterns = []
    # minimatch sets for our patterns
    @minimatchSets = []
    @add(pattern)

  add: (patterns...) ->
    @debug "add: #{util.inspect(patterns)}"
    for p in patterns
      p = @absolutePath(p)
      if @patterns.indexOf(p) < 0 then @patterns.push(p)
    @minimatchSets = []
    for p in @patterns
      @minimatchSets = @minimatchSets.concat(new minimatch.Minimatch(p, nonegate: true).set)
    for set in @minimatchSets then @watchPrefix(set)

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
    @watchMap.clear()
    @closed = true

  # ----- internals:

  # make sure we are watching at least the non-glob prefix of this pattern,
  # in case the pattern represents a folder that doesn't exist yet.
  watchPrefix: (minimatchSet) ->
    index = 0
    while index < minimatchSet.length and typeof minimatchSet[index] == "string" then index += 1
    prefix = path.join("/", minimatchSet[...index]...)
    parent = path.dirname(prefix)
    # if the prefix doesn't exist, backtrack within reason (don't watch "/").
    while not fs.existsSync(prefix) and parent != path.dirname(parent)
      prefix = path.dirname(prefix)
      parent = path.dirname(parent)
    if fs.existsSync(prefix) then @watchMap.watchFolder(prefix + "/")

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
      @watchMap.watchFolder(filename)
    parent = path.dirname(filename)
    if parent != "/" then parent += "/"
    @watchMap.watchFile(filename, parent)

  stopWatches: ->
    for filename, watcher of @watchers then watcher.close()
    for folderName in @watchMap.getFolders()
      fs.unwatchFile(folderName)
      for filename in @watchMap.getFilenames(folderName) then fs.unwatchFile(filename)
    @watchers = {}

  startWatches: ->
    for folderName in @watchMap.getFolders()
      @watchFolder folderName
      for filename in @watchMap.getFilenames(folderName)
        if filename[filename.length - 1] != "/" then @watchFile filename

  # FIXME may throw an exception
  watchFolder: (folderName) ->
    @debug "watch: #{folderName}"
    @watchers[folderName] = fs.watch folderName, (event) =>
      @debug "watch event: #{folderName}"
      # wait a short interval to make sure the new folder has some staying power.
      setTimeout((=> @folderChanged(folderName)), @debounceInterval)
    
  # FIXME may throw an exception
  watchFile: (filename) ->
    @debug "watchFile: #{filename}"
    fs.watchFile filename, { persistent: false, interval: @interval }, (curr, prev) =>
      @debug "watchFile event: #{filename} #{prev.mtime.getTime()} -> #{curr.mtime.getTime()}"
      if curr.mtime.getTime() != prev.mtime.getTime() and fs.existsSync(filename) then @emit 'changed', filename

  unwatch: (filename) ->
    @debug "unwatch: #{filename}"
    if @watchMap.watchingFolder(filename)
      # folder!
      fs.unwatchFile(filename)
      for f in @watchMap.getFilenames(filename) then fs.unwatchFile(f)
      @watchMap.unwatchFolder(filename)
    else
      parent = path.dirname(filename)
      if parent != "/" then parent += "/"
      if @watchMap.watchingFile(filename, parent)
        fs.unwatchFile(filename)
        @watchMap.unwatchFile(filename, parent)
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
      previous = @watchMap.getFilenames(folderName)

      # deleted files/folders
      for f in previous.filter((x) -> current.indexOf(x) < 0)
        @debug "file deleted: #{f}"
        @unwatch f
        if f[f.length - 1] != '/' then @emit 'deleted', f

      # new files/folders
      for f in current.filter((x) -> previous.indexOf(x) < 0)
        if f[f.length - 1] != '/'
          if @isMatch(f)
            @debug "file added: #{f}"
            @watchMap.watchFile(f, folderName)
            @watchFile f
            @emit 'added', f
        else
          # new folder! if it potentially matches the prefix of a glob we're
          # watching, start watching it, and recursively check for new files.
          if @folderIsInteresting(f)
            @watchMap.watchFolder(f)
            @watchFolder f
            @folderChanged(f)

  # does this folder match the prefix for an existing watch-pattern?
  folderIsInteresting: (folderName) ->
    folderSegments = folderName.split("/")[0...-1]
    for set in @minimatchSets then if folderMatchesMinimatchPrefix(folderSegments, set) then return true
    false