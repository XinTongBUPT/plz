{% highlight coffeescript %}
task "build-coffee",
  attach: "build",
  description: "compile coffee-script source",
  run: ->
    mkdir "-p", "lib"
    exec "coffee -o lib -c src"
{% endhighlight %}
