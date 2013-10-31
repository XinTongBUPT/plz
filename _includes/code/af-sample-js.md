{% highlight javascript %}
glob("assets/js/*.js").then(function (filenames) {
  for (var i = 0; i < filenames.length; i++) {
    notice("Another glorious javascript file! I found: " + filenames[i]);
  }
});

var cat = {
  name: "Snowball II"
};
extend(cat, { color: "black" });
// 'cat' now has both fields
{% endhighlight %}
