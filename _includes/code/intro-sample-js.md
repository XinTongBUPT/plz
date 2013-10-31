{% highlight javascript %}
task("shrink", {
  description: "make icon-sized forms of images",
  watch: [ "./assets/original/*.jpg" ],
  run: function (context) {
    for (var i = 0; i < context.filenames.length; i++) {
      exec("shrink --size=128 -o assets/icons/ " + context.filenames[i]);
    }
  }
});

task("restart-web", {
  description: "restart the local web server",
  watch: [ "./assets/**/*" ],
  run: function (context) {
    notice("Restarting webserver on localhost:8000");
    exec("./simpleweb restart");
  }
});

settings.clean = [ "./assets/icons" ];
{% endhighlight %}
