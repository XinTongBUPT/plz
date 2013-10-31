{% highlight javascript %}
task("images", {
  watch: "images/**/*.jpg",
  run: function (context) {
    for (var i = 0; i < context.filenames.length; i++) {
      notice("File " + context.filenames[i] + " is an image.");
    }
  }
});
{% endhighlight %}
