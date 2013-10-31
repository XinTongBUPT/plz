{% highlight coffeescript %}
task "images", watch: "images/**/*.jpg", run: (context) ->
  for filename in context.filenames
    notice "File #{filename} is an image."
{% endhighlight %}
