{% highlight coffeescript %}
glob("assets/js/*.js").then (filenames) ->
  for filename in filenames
    notice "Another glorious javascript file! I found: #{filename}"

cat =
  name: "Snowball II"
extend(cat, color: "black")
# 'cat' now has both fields
{% endhighlight %}
