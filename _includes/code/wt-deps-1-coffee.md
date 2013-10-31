{% highlight coffeescript %}
task "push", describe: "push new code to production", must: "verify-site", run: ->
  # ...

task "verify-site", describe: "verify that the production site is healthy", run: ->
  # ...
{% endhighlight %}
