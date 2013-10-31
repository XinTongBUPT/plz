{% highlight javascript %}
settings.gcc.warn = "-Wall";

task("compile", { run: function() {
  // ...
  exec("gcc " + settings.gcc.warn + " ...");
}});
{% endhighlight %}
