# frozen_string_literal: true

apt_update 'default'

package %w[build-essential nginx]

file '/etc/nginx/sites-enabled/default' do
  action :delete
end

nginx_conf = <<-CONF.gsub(/^ {2}/, '')
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
file '/etc/nginx/sites-enabled/sensu-plugins-meta.conf' do
  content nginx_conf
  notifies :restart, 'service[nginx]'
end

service 'nginx' do
  action %i[enable start]
end

apt_repository 'sensu' do
  uri 'http://repositories.sensuapp.org/apt'
  key 'http://repositories.sensuapp.org/apt/pubkey.gpg'
  distribution node['lsb']['codename']
  components %w[main]
end

package 'sensu' do
  version node['sensu_version'] unless node['sensu_version'].nil?
end

%w[sensu-plugins-http sensu-plugins-ssl].each do |p|
  gem_package p do
    gem_binary '/opt/sensu/embedded/bin/gem'
  end
end

directory node['build_dir'] do
  recursive true
  action :delete
end

execute 'Copy everything into the build dir' do
  command "cp -a #{node['staging_dir']} #{node['build_dir']}"
end

execute 'Build plugin gem' do
  cwd node['build_dir']
  command 'SIGN_GEM=false /opt/sensu/embedded/bin/gem build ' \
          'sensu-plugins-meta.gemspec'
end

execute 'Install plugin gem' do
  cwd node['build_dir']
  command '/opt/sensu/embedded/bin/gem install sensu-plugins-meta-*.gem'
end
