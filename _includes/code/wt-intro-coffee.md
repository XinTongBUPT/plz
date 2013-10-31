{% highlight coffeescript %}
task "lucky", description: "calculate your lucky number", run: ->
  notice "Your lucky number is #{Math.round(Math.random() * 100)}!"
{% endhighlight %}
