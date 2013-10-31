{% highlight javascript %}
task("make-folders", {
  before: "compile",
  run: function () {
    mkdir("-p", "target");
  }
});
{% endhighlight %}
