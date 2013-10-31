<img src="https://github.com/robey/plz/raw/master/docs/images/plz.png" width="80">

[![Build Status](https://travis-ci.org/robey/plz.png?branch=master)](https://travis-ci.org/robey/plz)

![Install](https://nodei.co/npm/plz.png?compact=1)

Plz is a script automation system like "make", "rake", and "cake". It aims to make simple tasks trivial, and difficult tasks easier. Highlights:

- **Fast.** Rules are written in javascript or coffee-script and executed by the v8 engine. No waiting for a JVM to lanuch.
- **Clean.** No console spew. The default logging level runs silent unless there's an error.
- **Simple.** Most of the basic shell commands are exposed as global functions via [shelljs](https://github.com/arturadib/shelljs), or just call "exec". You don't have to learn a new syntax for copying files.
- **Powerful.** Tasks can be executed by name, or automatically when files change, based on glob patterns. Plugins are easy to write, and can attach new features to existing tasks.

When tasks are triggered by watching for changed files, dependencies become automatic, and less "manual wiring" is required. It adds surprising leverage.

**Check out the [copious documentation](http://robey.github.io/plz/articles/what-is-it.html).**


Install
-------

Make sure you have node installed (http://nodejs.org/), then:

```sh
$ sudo npm install -g plz
```


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
