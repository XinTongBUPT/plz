{% highlight coffeescript %}
task "check", run: ->
  if fs.existsSync(STOP_FILENAME) then runTask("stop")

task "stop", run: ->
  # stop! ...
{% endhighlight %}
