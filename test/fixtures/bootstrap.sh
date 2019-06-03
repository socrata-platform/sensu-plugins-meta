#!/bin/bash
#
# Set up a stub Nginx service with a variety of endpoints and return codes.
#

set -e

apt-get update
apt-get -y install wget software-properties-common build-essential nginx
rm /etc/nginx/sites-enabled/default

cat << CONF > /etc/nginx/sites-enabled/sensu-plugins-meta.conf
server {
  listen 80;

  location / {
    limit_except GET {
      deny all;
    }
    return 200;
  }

  location /okay {
    limit_except GET {
      deny all;
    }
    return 200;
  }

  location /okaytoo {
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
CONF
service nginx restart

wget -qO - https://packagecloud.io/sensu/community/gpgkey | apt-key add
add-apt-repository -y https://packagecloud.io/sensu/community/ubuntu
apt-get -y install sensu-plugins-ruby

BIN_PATH="/opt/sensu-plugins-ruby/embedded/bin"

"${BIN_PATH}/gem" install sensu-plugins-http
"${BIN_PATH}/gem" install sensu-plugins-ssl

"${BIN_PATH}/gem" install bundler
pushd /tmp/kitchen/data
"${BIN_PATH}/bundle" install --without=development
SIGN_GEM=false "${BIN_PATH}/gem" build sensu-plugins-meta.gemspec
"${BIN_PATH}/gem" install sensu-plugins-meta-*.gem
popd

exit 0
