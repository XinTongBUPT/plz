{% highlight coffeescript %}
settings.gcc.warn = "-Wall"

task "compile", run: ->
  # ...
  exec "gcc #{settings.gcc.warn} ..."
{% endhighlight %}
