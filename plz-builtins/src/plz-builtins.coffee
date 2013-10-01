path = require 'path'
util = require 'util'

# default tasks for cleaning

Q().then ->
  if settings.clean?.length > 0
    task "clean",
      description: "erase build products: #{util.inspect(settings.clean)}",
      run: ->
        if not settings.clean? then settings.clean = []
        if not Array.isArray(settings.clean) then settings.clean = [ settings.clean ]
        plz.monitor(false)
        (settings.clean or []).map (f) -> rm "-rf", f
        if plz.stateFile()? then rm "-f", plz.stateFile()

    if settings.distclean?.length > 0
      task "distclean",
        must: "clean",
        description: "erase everything that isn't part of a distribution: #{util.inspect(settings.distclean)}",
        run: ->
          if not settings.distclean? then settings.distclean = []
          if not Array.isArray(settings.distclean) then settings.distclean = [ settings.distclean ]
          (settings.distclean or []).map (f) -> rm "-rf", f

require "./plugins/coffeescript"
require "./plugins/mocha"
