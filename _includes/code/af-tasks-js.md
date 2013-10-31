{% highlight javascript %}
task("check", { run: function() {
  if (fs.existsSync(STOP_FILENAME)) runTask("stop");
}});

task("stop", { run: function() {
  // stop! ...
}});
{% endhighlight %}
