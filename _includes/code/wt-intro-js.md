{% highlight javascript %}
task("lucky", {
  description: "calculate your lucky number",
  run: function() {
    notice("Your lucky number is " + Math.round(Math.random() * 100) + "!");
  }
});
{% endhighlight %}
