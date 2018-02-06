# frozen_string_literal: true

require 'json'

check = '/opt/sensu/embedded/bin/check-meta-ruby.rb -c check-ssl-host.rb'

#
# Check a batch of SSL certs from the CLI
#

# OK
json = [
  { host: 'www.google.com', port: 443, warning: 7, critical: 3 },
  { host: 'www.socrata.com', port: 443, warning: 10, critical: 7 },
  { host: 'www.bing.com', port: 443, warning: 14, critical: 10 }
].to_json
describe command("#{check} -j '#{json}'") do
  its(:exit_status) { should eq(0) }
  its(:stdout) do
    exp = "CheckMetaRuby OK: Results: 0 critical, 0 warning, 0 unknown, 3 ok\n"
    should eq(exp)
  end
end

# WARNING
json = [
  { host: 'www.google.com', port: 443, warning: 7, critical: 3 },
  { host: 'www.socrata.com', port: 443, warning: 10_000, critical: 7 },
  { host: 'www.bing.com', port: 443, warning: 14, critical: 10 }
].to_json
describe command("#{check} -j '#{json}'") do
  its(:exit_status) { should eq(1) }
  its(:stdout) do
    exp = Regexp.new('^WARNING: check_ssl_host: www\.socrata\.com - .*\n' \
                     'CheckMetaRuby WARNING: Results: 0 critical, ' \
                     '1 warning, 0 unknown, 2 ok\n')
    should match(exp)
  end
end

# CRITICAL
json = [
  { host: 'www.google.com', port: 443, warning: 7, critical: 3 },
  { host: 'www.socrata.com', port: 443, warning: 10_000, critical: 9999 },
  { host: 'www.bing.com', port: 443, warning: 14_000, critical: 10 }
].to_json
describe command("#{check} -j '#{json}'") do
  its(:exit_status) { should eq(2) }
  its(:stdout) do
    exp = Regexp.new('^WARNING: check_ssl_host: www.bing.com - .*\n' \
                     'CRITICAL: check_ssl_host: www.socrata.com - .*\n' \
                     'CheckMetaRuby CRITICAL: Results: 1 critical, ' \
                     '1 warning, 0 unknown, 1 ok\n')
    should match(exp)
  end
end

# UNKNOWN
json = [
  { host: 'www.google.com', port: 443, warning: 7, critical: 3 },
  { host: 'www.socrata.com', port: 443, warning: 10, critical: 7 },
  { host: 'jojaduhafuhaduha.biz', port: 443, warning: 30, critical: 14 },
  { host: 'www.bing.com', port: 443, warning: 14, critical: 10 }
].to_json
describe command("#{check} -j '#{json}'") do
  its(:exit_status) { should eq(3) }
  its(:stdout) do
    exp = "UNKNOWN: getaddrinfo: Name or service not known\n" \
          'CheckMetaRuby UNKNOWN: Results: 0 critical, 0 warning, ' \
          "1 unknown, 3 ok\n"
    should eq(exp)
  end
end
