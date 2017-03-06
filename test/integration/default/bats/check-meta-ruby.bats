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

@test "Check a batch of SSL certs from the CLI, ok" {
  run $CHECK -c check-ssl-host.rb -j '
    [
      {"host": "www.google.com", "port": 443, "warning": 7, "critical": 3},
      {"host": "www.socrata.com", "port": 443, "warning": 10, "critical": 7},
      {"host": "www.bing.com", "port": 443, "warning": 14, "critical": 10}
    ]
  '
  echo "Check status: $status"
  echo "Check output: $output"
  [ $status = 0 ]
  [ "$output" = "CheckMetaRuby OK: Results: 0 critical, 0 warning, 0 unknown, 3 ok" ]
}

@test "Check a batch of SSL certs from the CLI, warning" {
  run $CHECK -c check-ssl-host.rb -j '
    [
      {"host": "www.google.com", "port": 443, "warning": 7, "critical": 3},
      {"host": "www.socrata.com", "port": 443, "warning": 10000, "critical": 7},
      {"host": "www.bing.com", "port": 443, "warning": 14, "critical": 10}
    ]
  '
  echo "Check status: $status"
  echo "Check output: $output"
  [ $status = 1 ]
  [ -n `echo ${lines[0]} | grep "^WARNING: check_ssl_host: www.socrata.com - "` ]
  [ "${lines[1]}" = "CheckMetaRuby WARNING: Results: 0 critical, 1 warning, 0 unknown, 2 ok" ]
}

@test "Check a batch of SSL certs from the CLI, critical" {
  run $CHECK -c check-ssl-host.rb -j '
    [
      {"host": "www.google.com", "port": 443, "warning": 7, "critical": 3},
      {"host": "www.socrata.com", "port": 443, "warning": 10000, "critical": 9999},
      {"host": "www.bing.com", "port": 443, "warning": 14000, "critical": 10}
    ]
  '
  echo "Check status: $status"
  echo "Check output: $output"
  [ $status = 2 ]
  [ -n `echo $output | grep "^CRITICAL: check_ssl_host: www.socrata.com - "` ]
  [ -n `echo $output | grep "^WARNING: check_ssl_host: www.bing.com - "` ]
  [ "${lines[2]}" = "CheckMetaRuby CRITICAL: Results: 1 critical, 1 warning, 0 unknown, 1 ok" ]
}

@test "Check a batch of SSL certs from the CLI, unknown" {
  run $CHECK -c check-ssl-host.rb -j '
    [
      {"host": "www.google.com", "port": 443, "warning": 7, "critical": 3},
      {"host": "www.socrata.com", "port": 443, "warning": 10, "critical": 7},
      {"host": "jojaduhafuhaduha.biz", "port": 443, "warning": 30, "critical": 14},
      {"host": "www.bing.com", "port": 443, "warning": 14, "critical": 10}
    ]
  '
  echo "Check status: $status"
  echo "Check output: $output"
  [ $status = 3 ]
  [ "${lines[0]}" = "UNKNOWN: getaddrinfo: Name or service not known" ]
  [ "${lines[1]}" = "CheckMetaRuby UNKNOWN: Results: 0 critical, 0 warning, 1 unknown, 3 ok" ]
}

@test "Check a batch of SSL certs from a file, ok" {
  echo '
    [
      {"host": "www.google.com", "port": 443, "warning": 7, "critical": 3},
      {"host": "www.socrata.com", "port": 443, "warning": 10, "critical": 7},
      {"host": "www.bing.com", "port": 443, "warning": 14, "critical": 10}
    ]
  ' > /tmp/check-ssl.json
  run $CHECK -c check-ssl-host.rb -j /tmp/check-ssl.json
  echo "Check status: $status"
  echo "Check output: $output"
  [ $status = 0 ]
  [ "$output" = "CheckMetaRuby OK: Results: 0 critical, 0 warning, 0 unknown, 3 ok" ]
}

@test "Check a batch of SSL certs from a file, warning" {
  echo '
    [
      {"host": "www.google.com", "port": 443, "warning": 7, "critical": 3},
      {"host": "www.socrata.com", "port": 443, "warning": 10000, "critical": 7},
      {"host": "www.bing.com", "port": 443, "warning": 14, "critical": 10}
    ]
  ' > /tmp/check-ssl.json
  run $CHECK -c check-ssl-host.rb -j /tmp/check-ssl.json
  echo "Check status: $status"
  echo "Check output: $output"
  [ $status = 1 ]
  [ -n `echo ${lines[0]} | grep "^WARNING: check_ssl_host: www.socrata.com - "` ]
  [ "${lines[1]}" = "CheckMetaRuby WARNING: Results: 0 critical, 1 warning, 0 unknown, 2 ok" ]
}

@test "Check a batch of SSL certs from a file, critical" {
  echo '
    [
      {"host": "www.google.com", "port": 443, "warning": 7, "critical": 3},
      {"host": "www.socrata.com", "port": 443, "warning": 10000, "critical": 9999},
      {"host": "www.bing.com", "port": 443, "warning": 14000, "critical": 10}
    ]
  ' > /tmp/check-ssl.json
  run $CHECK -c check-ssl-host.rb -j /tmp/check-ssl.json
  echo "Check status: $status"
  echo "Check output: $output"
  [ $status = 2 ]
  [ -n `echo $output | grep "^CRITICAL: check_ssl_host: www.socrata.com - "` ]
  [ -n `echo $output | grep "^WARNING: check_ssl_host: www.bing.com - "` ]
  [ "${lines[2]}" = "CheckMetaRuby CRITICAL: Results: 1 critical, 1 warning, 0 unknown, 1 ok" ]
}

@test "Check a batch of SSL certs from a file, unknown" {
  echo '[
      {"host": "www.google.com", "port": 443, "warning": 7, "critical": 3},
      {"host": "www.socrata.com", "port": 443, "warning": 10, "critical": 7},
      {"host": "jojaduhafuhaduha.biz", "port": 443, "warning": 30, "critical": 14},
      {"host": "www.bing.com", "port": 443, "warning": 14, "critical": 10}
    ]
  ' > /tmp/check-ssl.json
  run $CHECK -c check-ssl-host.rb -j /tmp/check-ssl.json
  echo "Check status: $status"
  echo "Check output: $output"
  [ $status = 3 ]
  [ "${lines[0]}" = "UNKNOWN: getaddrinfo: Name or service not known" ]
  [ "${lines[1]}" = "CheckMetaRuby UNKNOWN: Results: 0 critical, 0 warning, 1 unknown, 3 ok" ]
}
