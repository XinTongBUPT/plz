{% highlight coffeescript %}
task "make-folders", before: "compile", run: ->
  mkdir "-p", "target"
{% endhighlight %}
