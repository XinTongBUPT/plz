{% highlight coffeescript %}
task "shrink",
  description: "make icon-sized forms of images"
  watch: [ "./assets/original/*.jpg" ]
  run: (context) ->
    for filename in context.filenames
      exec "shrink --size=128 -o assets/icons/ #{filename}"

task "restart-web",
  description: "restart the local web server"
  watch: [ "./assets/**/*" ]
  run: (context) ->
    notice "Restarting webserver on localhost:8000"
    exec "./simpleweb restart"

settings.clean = [ "./assets/icons" ]
{% endhighlight %}
