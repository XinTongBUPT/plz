{% highlight coffeescript %}
task "compile", watch: "src/**/*.c", run: ->
  # ...

task "test", watch: [ "src/**/*.c", "test/*" ], depends: "compile", run: ->
  # ...
{% endhighlight %}
