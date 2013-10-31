{% highlight javascript %}
mkdir("-p", "build/classes/main");
cp("src/" + filename, "dist/original/" + filename);
touch("/tmp/stop");
{% endhighlight %}
