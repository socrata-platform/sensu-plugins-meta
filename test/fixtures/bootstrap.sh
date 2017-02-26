#!/bin/bash
#
# Set up a super simple web server, make it accept GET and POST requests for
# testing, and get the meta ready to run against it.
#

set -e

DATA_DIR=/tmp/kitchen/data
RUBY_HOME=/opt/sensu/embedded

if [ ! -d $RUBY_HOME ]; then
  wget -q http://repositories.sensuapp.org/apt/pubkey.gpg -O- | apt-key add -
  echo "deb http://repositories.sensuapp.org/apt sensu main" > /etc/apt/sources.list.d/sensu.list
  apt-get update
  apt-get install -y sensu build-essential nginx
  service nginx status || service nginx start
  rm -f /etc/nginx/sites-enabled/default
  
  $RUBY_HOME/bin/gem install sensu-plugins-http sensu-plugins-ssl

  echo "
    server {
      listen 80;

      location /okay {
        limit_except GET {
          deny all;
        }
        return 200;
      }

      location /notthere {
        limit_except GET {
          deny all;
        }
        return 404;
      }

      location /ohno {
        limit_except GET {
          deny all;
        }
        return 500;
      }

      location /gooverthere {
        limit_except GET {
          deny all;
        }
        return 301;
      }

      location /postthingshere {
        return 200;
      }
    }
  " > /etc/nginx/sites-enabled/sensu-plugins-meta.conf
  service nginx restart
fi

cd $DATA_DIR
SIGN_GEM=false $RUBY_HOME/bin/gem build sensu-plugins-meta.gemspec
$RUBY_HOME/bin/gem install sensu-plugins-meta-*.gem
