{% highlight javascript %}
exec("./node_modules/coffee-script/bin/coffee -o lib/ -c src/").then(function () {
  info("done!");
});
{% endhighlight %}
