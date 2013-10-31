{% highlight javascript %}
task("compile", {
  watch: "src/**/*.c",
  run: function () {
    // ...
  }
});

task("test", {
  watch: [ "src/**/*.c", "test/*" ],
  depends: "compile",
  run: function () {
    // ...
  }
});
{% endhighlight %}
