#!/usr/bin/env bats

setup() {
  export OLD_GEM_HOME=$GEM_HOME
  export OLD_GEM_PATH=$GEM_PATH
  unset GEM_HOME
  unset GEM_PATH

  RUBY_BIN=/opt/sensu/embedded/bin
  export CHECK="$RUBY_BIN/ruby $RUBY_BIN/check-meta-ruby.rb"
}

teardown() {
  unset CHECK
  export GEM_HOME=$OLD_GEM_HOME
  export GEM_PATH=$OLD_GEM_PATH
  unset OLD_GEM_HOME
  unset OLD_GEM_PATH
}

@test "Check a batch of HTTP hosts from the CLI, ok" {
  run $CHECK -c check-http.rb -j '
    [
      {"host": "127.0.0.1", "port": 80, "request_uri": "/okay"},
      {"user-agent": "Test", "url": "http://127.0.0.1/okay"},
      {"url": "http://127.0.0.1/okaytoo"}
    ]
  '
  echo "Check status: $status"
  echo "Check output: $output"
  [ $status = 0 ]
  [ "$output" = "CheckMetaRuby OK: Results: 0 critical, 0 warning, 0 unknown, 3 ok" ]
}

@test "Check a batch of HTTP hosts from the CLI, warning" {
  run $CHECK -c check-http.rb -j '
    [
      {"host": "127.0.0.1", "port": 80, "request_uri": "/okay"},
      {"user-agent": "Test", "url": "http://127.0.0.1/okay"},
      {"url": "http://127.0.0.1/gooverthere"}
    ]
  '
  echo "Check status: $status"
  echo "Check output: $output"
  [ $status = 1 ]
  [ "${lines[0]}" = "WARNING: CheckHttp: 301" ]
  [ "${lines[1]}" = "CheckMetaRuby WARNING: Results: 0 critical, 1 warning, 0 unknown, 2 ok" ]
}

@test "Check a batch of HTTP hosts from the CLI, critical" {
  run $CHECK -c check-http.rb -j '
    [
      {"host": "127.0.0.1", "port": 443, "request_uri": "/okay"},
      {"user-agent": "Test", "url": "http://127.0.0.1/okay"},
      {"url": "http://127.0.0.1/okaytoo"}
    ]
  '
  echo "Check status: $status"
  echo "Check output: $output"
  [ $status = 2 ]
  [ "${lines[0]}" = "CRITICAL: CheckHttp: Request error: Failed to open TCP connection to 127.0.0.1:443 (Connection refused - connect(2) for \"127.0.0.1\" port 443)" ]
  [ "${lines[1]}" = "CheckMetaRuby CRITICAL: Results: 1 critical, 0 warning, 0 unknown, 2 ok" ]
}

@test "Check a batch of HTTP hosts from the CLI, unknown" {
  run $CHECK -c check-http.rb -j '
    [
      {"port": 80, "request_uri": "/okay"},
      {"user-agent": "Test", "url": "http://127.0.0.1/okay"},
      {"url": "http://127.0.0.1/okaytoo"}
    ]
  '
  echo "Check status: $status"
  echo "Check output: $output"
  [ $status = 3 ]
  [ "${lines[0]}" = "UNKNOWN: CheckHttp: No URL specified" ]
  [ "${lines[1]}" = "CheckMetaRuby UNKNOWN: Results: 0 critical, 0 warning, 1 unknown, 2 ok" ]
}

@test "Check a batch of HTTP hosts from a file, ok" {
    echo '[
      {"host": "127.0.0.1", "port": 80, "request_uri": "/okay"},
      {"user-agent": "Test", "url": "http://127.0.0.1/okay"},
      {"url": "http://127.0.0.1/okaytoo"}
    ]
  ' > /tmp/check-http.json
  run $CHECK -c check-http.rb -j /tmp/check-http.json
  echo "Check status: $status"
  echo "Check output: $output"
  [ $status = 0 ]
  [ "$output" = "CheckMetaRuby OK: Results: 0 critical, 0 warning, 0 unknown, 3 ok" ]
}

@test "Check a batch of HTTP hosts from a file, warning" {
  echo '
    [
      {"host": "127.0.0.1", "port": 80, "request_uri": "/okay"},
      {"user-agent": "Test", "url": "http://127.0.0.1/okay"},
      {"url": "http://127.0.0.1/gooverthere"}
    ]
  ' > /tmp/check-http.json
  run $CHECK -c check-http.rb -j /tmp/check-http.json
  echo "Check status: $status"
  echo "Check output: $output"
  [ $status = 1 ]
  [ "${lines[0]}" = "WARNING: CheckHttp: 301" ]
  [ "${lines[1]}" = "CheckMetaRuby WARNING: Results: 0 critical, 1 warning, 0 unknown, 2 ok" ]
}

@test "Check a batch of HTTP hosts from a file, critical" {
  echo '
    [
      {"host": "127.0.0.1", "port": 443, "request_uri": "/okay"},
      {"user-agent": "Test", "url": "http://127.0.0.1/okay"},
      {"url": "http://127.0.0.1/okaytoo"}
    ]
  ' > /tmp/check-http.json
  run $CHECK -c check-http.rb -j /tmp/check-http.json
  echo "Check status: $status"
  echo "Check output: $output"
  [ $status = 2 ]
  [ "${lines[0]}" = "CRITICAL: CheckHttp: Request error: Failed to open TCP connection to 127.0.0.1:443 (Connection refused - connect(2) for \"127.0.0.1\" port 443)" ]
  [ "${lines[1]}" = "CheckMetaRuby CRITICAL: Results: 1 critical, 0 warning, 0 unknown, 2 ok" ]
}

@test "Check a batch of HTTP hosts from a file, unknown" {
  echo '
    [
      {"port": 80, "request_uri": "/okay"},
      {"user-agent": "Test", "url": "http://127.0.0.1/okay"},
      {"url": "http://127.0.0.1/okaytoo"}
    ]
  ' > /tmp/check-http.json
  run $CHECK -c check-http.rb -j /tmp/check-http.json
  echo "Check status: $status"
  echo "Check output: $output"
  [ $status = 3 ]
  [ "${lines[0]}" = "UNKNOWN: CheckHttp: No URL specified" ]
  [ "${lines[1]}" = "CheckMetaRuby UNKNOWN: Results: 0 critical, 0 warning, 1 unknown, 2 ok" ]
}
