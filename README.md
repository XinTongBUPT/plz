<img src="https://github.com/robey/plz/raw/master/docs/images/plz.png" width="80">

[![Build Status](https://travis-ci.org/robey/plz.png?branch=master)](https://travis-ci.org/robey/plz)

![Install](https://nodei.co/npm/plz.png?compact=1)

Plz is a script automation system like "make", "rake", and "cake". It aims to make simple tasks trivial, and difficult tasks easier. Highlights:

- No waiting for a JVM to launch. Rules are written in coffeescript or javascript, and executed by the (fast) v8 engine. 
- No console spew. The default logging level runs silent unless there's an error.
- Most of the basic shell commands are exposed as global functions via [shelljs](https://github.com/arturadib/shelljs), or just call "exec".
- Tasks can depend on other tasks, attach themselves before/after other tasks, or they can be run automatically when a file changes, based on glob patterns.


Install
-------

Make sure you have node installed (http://nodejs.org/), then:

```sh
$ sudo npm install -g plz
```


Using it
--------

Check out the [copious documentation](http://robey.github.io/plz/articles/what-is-it.html).


Developing
----------

Install dependencies using node, then build with a current version of plz:

    $ npm install
    $ plz

Pull requests and bug reports are tracked on github:
https://github.com/robey/plz


License
-------

Apache 2 (open-source) license, included in 'LICENSE.txt'.


Authors
-------

- @robey - Robey Pointer <robeypointer@gmail.com>


Thanks
------

- @azer for introducing me to the idea of having file triggers launch tasks.
- @dbrock for letting me use the name on npm.
