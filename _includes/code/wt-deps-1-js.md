{% highlight javascript %}
task("push", {
  describe: "push new code to production",
  must: "verify-site",
  run: function () {
    // ...
  }
});

task("verify-site", {
  describe: "verify that the production site is healthy",
  run: function() {
    // ...
  }
});
{% endhighlight %}
