Sensu Plugins Meta
==================

[![Build Status](https://img.shields.io/travis/socrata-platform/sensu-plugins-meta.svg)][travis]
[![Gem Version](https://img.shields.io/gem/v/sensu-plugins-meta.svg)][rubygems]
[![Code Climate](https://img.shields.io/codeclimate/github/socrata-platform/sensu-plugins-meta.svg)][codeclimate]
[![Test Coverage](https://img.shields.io/coveralls/socrata-platform/sensu-plugins-meta.svg)][coveralls]
[![Dependency Status](https://gemnasium.com/socrata-platform/sensu-plugins-meta.svg)][gemnasium]

[travis]: https://travis-ci.org/socrata-platform/sensu-plugins-meta
[rubygems]: https://rubygems.org/gems/sensu-plugins-meta
[codeclimate]: https://codeclimate.com/github/socrata-platform/sensu-plugins-meta
[coveralls]: https://coveralls.io/r/socrata-platform/sensu-plugins-meta
[gemnasium]: https://gemnasium.com/socrata-platform/sensu-plugins-meta

Functionality
-------------

This Sensu plugin can be used to run another plugin multiple times as one
batch check.

Files
-----

* bin/check-meta-ruby.rb

Usage
-----

The `check-meta-ruby.rb` script requires another Sensu plugin to run and a JSON
array of options to run it with. The JSON can be provided either as a string:

    check-meta-ruby.rb -c /opt/sensu/embedded/bin/check-http.rb \
      -j '[{"url": "http://pants.com/"}, {"url": "https://www.google.com"}]'

...or as a path to a file:

    check-meta-ruby.rb -c /opt/sensu/embedded/bin/check-http.rb \
      -j /etc/sensu/http_checks.json

If a full path is not provided for the Sensu plugin file, an attempt will be
made to find it relative to the `check-meta-ruby.rb` file.

Installation
------------

[Installation and Setup](http://sensu-plugins.io/docs/installation_instructions.html)

Notes
-----

The Ruby check makes certain assumptions about the plugin it's being asked to
run:

* It must be a child of the `Sensu::Plugin::Check::CLI` class
* It must be the only Sensu check defined in the configured plugin file
