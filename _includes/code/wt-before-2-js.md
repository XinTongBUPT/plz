{% highlight javascript %}
task("build-coffee", {
  attach: "build",
  description: "compile coffee-script source",
  run: function () {
    mkdir("-p", "lib");
    exec("coffee -o lib -c src");
  }
});
{% endhighlight %}
