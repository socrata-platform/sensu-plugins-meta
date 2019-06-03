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

apt_repository 'sensu_community' do
  uri 'https://packagecloud.io/sensu/community/ubuntu'
  key 'https://packagecloud.io/sensu/community/gpgkey'
  components %w[main]
end

package 'sensu-plugins-ruby'

bin_path = '/opt/sensu-plugins-ruby/embedded/bin'

%w[sensu-plugins-http sensu-plugins-ssl].each do |p|
  gem_package p do
    gem_binary "#{bin_path}/gem"
  end
end

execute 'Install Bundler' do
  cwd node['build_dir']
  command "#{bin_path}/gem install bundler"
end

execute 'Bundle install' do
  cwd node['build_dir']
  command "#{bin_path}/bundle install --without=development"
end

execute 'Build plugin gem' do
  cwd node['build_dir']
  command "SIGN_GEM=false #{bin_path}/gem build sensu-plugins-meta.gemspec"
end

execute 'Install plugin gem' do
  cwd node['build_dir']
  command "#{bin_path}/gem install sensu-plugins-meta-*.gem"
end
