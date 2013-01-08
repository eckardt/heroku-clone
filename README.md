# heroku-clone [![Build Status](https://travis-ci.org/eckardt/heroku-clone.png?branch=master)](https://travis-ci.org/eckardt/heroku-clone)

Allows you to quickly create new heroku apps as clones of existing apps together with the list of collaborators and config variables.

## Installation

Add the heroku gem plugin:

    $ heroku plugins:install git://github.com/eckardt/heroku-clone.git
    heroku-clone installed


## Usage

You'll start with an existing app which has some custom config variables and collaborators set

    $ heroku apps:create
    Creating dry-oasis-7199... done, stack is cedar
    http://dry-oasis-7199.herokuapp.com/ | git@heroku.com:dry-oasis-7199.git
    Git remote heroku added
    $ heroku sharing:add someone@company.com
    Adding someone@company.com to dry-oasis-7199 collaborators... done
    $ heroku config:set FOO=bar
    Setting config vars and restarting dry-oasis-7199... done, v3
    FOO: bar

Now, creating an exact copy of this app is easy

    $ heroku clone:create
    Creating dry-oasis-7199-clone-19b3... done, stack is cedar
    http://dry-oasis-7199-clone-19b3.herokuapp.com/ | git@heroku.com:dry-oasis-7199-clone-19b3.git
    Copying someone@company.com to dry-oasis-7199-clone-19b3 collaborators... done
    Copying config vars from dry-oasis-7199 and restarting dry-oasis-7199-clone-19b3... done, v3

You can use the new app as a staging server or for quickly trying out another branch

    $ git push git@heroku.com:dry-oasis-7199-clone-19b3.git new-feature-which-needs-to-be-tested:master
    [...]
    -----> Launching... done, v6
       http://dry-oasis-7199-clone-19b3.herokuapp.com deployed to Heroku

    To git@heroku.com:dry-oasis-7199-clone-19b3.git
     * [new branch]      new-feature-which-needs-to-be-tested -> master

## Possible uses

You can use this for quickly spinning up new staging servers without needing to set up everything from scratch every time you need a new server. In a continuous integration workflow you can easily deploy and test individual branches manually after the automatic tests have passed.

## See also

For easily removing apps when they are not needed anymore you can use the https://github.com/ddollar/heroku-cleanup plugin.

## License

MIT License

## Author

Stephan Eckardt <mail@stephaneckardt.com>
