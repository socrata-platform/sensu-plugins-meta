# frozen_string_literal: true

require 'json'

check = '/opt/sensu/embedded/bin/check-meta-ruby.rb -c check-http.rb'

#
# Check a batch of HTTP hosts from a file
#

# OK
json = [
  { host: '127.0.0.1', port: 80, request_uri: '/okay' },
  { 'user-agent': 'Test', url: 'http://127.0.0.1/okay' },
  { url: 'http://127.0.0.1/okaytoo' }
].to_json
command("echo '#{json}' > /tmp/check-http-ok.json").stdout
describe command("#{check} -j /tmp/check-http-ok.json") do
  its(:exit_status) { should eq(0) }
  its(:stdout) do
    exp = "CheckMetaRuby OK: Results: 0 critical, 0 warning, 0 unknown, 3 ok\n"
    should eq(exp)
  end
end

# WARNING
json = [
  { host: '127.0.0.1', port: 80, request_uri: '/okay' },
  { 'user-agent': 'Test', url: 'http://127.0.0.1/okay' },
  { url: 'http://127.0.0.1/gooverthere' }
].to_json
command("echo '#{json}' > /tmp/check-http-warning.json").stdout
describe command("#{check} -j /tmp/check-http-warning.json") do
  its(:exit_status) { should eq(1) }
  its(:stdout) do
    exp = "WARNING: CheckHttp: 301\n" \
          'CheckMetaRuby WARNING: Results: 0 critical, 1 warning, ' \
          "0 unknown, 2 ok\n"
    should eq(exp)
  end
end

# CRITICAL
json = [
  { host: '127.0.0.1', port: 443, request_uri: '/okay' },
  { 'user-agent': 'Test', url: 'http://127.0.0.1/okay' },
  { url: 'http://127.0.0.1/okaytoo' }
].to_json
command("echo '#{json}' > /tmp/check-http-critical.json").stdout
describe command("#{check} -j /tmp/check-http-critical.json") do
  its(:exit_status) { should eq(2) }
  its(:stdout) do
    exp = 'CRITICAL: CheckHttp: Request error: Failed to open TCP ' \
          'connection to 127.0.0.1:443 (Connection refused - connect(2) for ' \
          "\"127.0.0.1\" port 443)\n" \
          'CheckMetaRuby CRITICAL: Results: 1 critical, 0 warning, ' \
          "0 unknown, 2 ok\n"
    should eq(exp)
  end
end

# UNKNOWN
json = [
  { port: 80, request_uri: '/okay' },
  { 'user-agent': 'Test', url: 'http://127.0.0.1/okay' },
  { url: 'http://127.0.0.1/okaytoo' }
].to_json
command("echo '#{json}' > /tmp/check-http-unknown.json").stdout
describe command("#{check} -j /tmp/check-http-unknown.json") do
  its(:exit_status) { should eq(3) }
  its(:stdout) do
    exp = "UNKNOWN: CheckHttp: No URL specified\n" \
          'CheckMetaRuby UNKNOWN: Results: 0 critical, 0 warning, ' \
          "1 unknown, 2 ok\n"
    should eq(exp)
  end
end
