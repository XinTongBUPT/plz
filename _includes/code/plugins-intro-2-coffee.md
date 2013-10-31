{% highlight coffeescript %}
plugins["c++"] = ->
  task "build", ->
    exec "g++ ..."

plugins["c--"] = ->
  task "build", ->
    exec "g-- ..."
{% endhighlight %}
