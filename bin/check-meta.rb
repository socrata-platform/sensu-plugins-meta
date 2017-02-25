#!/usr/bin/env ruby
# encoding: utf-8
# frozen_string_literal: false
#
#   check-meta.rb
#
# DESCRIPTION:
#   Give this check a file with another Sensu check and a JSON config and it
#   will dispatch threads to run that check multiple times and batch up the
#   results.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#   Run a check multiple times using a JSON config file:
#
#     check-meta.rb -c check-http.rb -f /etc/sensu/http_checks.json
#
#   Run a check multiple times using inline JSON:
#
#     check-meta.rb -c check-http.rb -s '[
#       {"host": "pants.com", "port": 80}, {"host": "google.com", "port": 443}
#     ]'
#
# NOTES:
#
# LICENSE:
#   Copyright 2017, Socrata, Inc <sysadmin@socrata.com>
#
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'json'
require 'sensu-plugin/check/cli'

#
# Check Meta
#
class CheckMeta < Sensu::Plugin::Check::CLI
  option :check,
         short: '-c CHECK_SCRIPT',
         long: '--check CHECK_SCRIPT',
         description: 'The Sensu Ruby check to run multiple times',
         required: true

  option :config_string,
         short: '-s CONFIG_STRING',
         long: '--config-string CONFIG_STRING',
         description: 'A JSON config passed in as a string'

  option :config_file,
         short: '-f FILE_PATH',
         long: '--config-file FILE_PATH',
         description: 'A JSON config passed in as a file'

  #
  # Import the check we want to run and dispatch threads for every instance of
  # it. Once all threads are complete, batch the results and return any
  # non-ok status messages.
  #
  def run
    require File.expand_path("../#{config[:check]}", $PROGRAM_NAME)

    threads_for(parsed_config).each(&:join)

    %i(critical warning unknown).each do |status|
      send(status, message) unless results[status].empty?
    end
    ok(message)
  end

  def parsed_config
    JSON.parse(config[:config_string] || File.read(config[:config_file]),
               symbolize_names: true)
  end

  #
  # Construct a string summary of our check results.
  #
  # @return [String] a summary of check results
  #
  def message
    lines = %i(unknown warning critical).map do |status|
      results[status].map { |result| "#{status.upcase}: #{result}" }
    end.flatten.compact
    (lines << summary).join("\n")
  end

  def summary
    "Results: #{results[:critical].size} critical, " \
      "#{results[:warning].size} warning, " \
      "#{results[:unknown].size} unknown, #{results[:ok].size} ok"
  end

  #
  # Find and patch the Sensu check class that was imported from the
  # config[:check] file. Some assumptions are made here that will hopefully
  # usually be valid.
  #
  #   * The check is a child of Sensu::Plugin::Check::CLI
  #   * The check and we are the only check classes in Ruby's object space
  #
  def check_class
    @check_class ||= begin
      c = ObjectSpace.each_object(Class).find do |klass|
        klass < Sensu::Plugin::Check::CLI && klass != self.class
      end

      c.class_eval do
        #
        # Make the check status accessible as a reader method.
        #
        attr_reader :status

        #
        # Patch the output method so it returns the output string instead of
        # sending it to stdout.
        #
        def output(msg = @message)
          @output ||= self.class.check_name + (msg ? ": #{msg}" : '')
        end
      end
      c
    end
  end

  #
  # Work through the array generated from our JSON config and return an array
  # of corresponding thread objects.
  #
  # @param json [Array<Hash>] an array of check option hashes
  #
  # @return [Array<Thread>] an array of threads to run
  #
  def threads_for(json)
    json.map { |check_opts| thread_for(check_opts) }
  end

  #
  # Build a new thread object for a given set of check options. The options
  # will be parsed into the command line arguments for the check, e.g.
  #
  #   {
  #     host: 'example.com',
  #     port: 443,
  #     c: /etc/config.conf,
  #     do_something: nil
  #   }
  #
  # will get translated into the CLI arguments:
  #
  #   --host example.com --port 443 -c /etc/config.conf --do-something
  #
  # @param check_opts [Hash] a hash of switches and their values.
  #
  def thread_for(check_opts)
    Thread.new do
      chk = check_class.new(check_args_for(check_opts))

      begin
        chk.run
      rescue SystemExit => e
        Sensu::Plugin::EXIT_CODES.each do |status, code|
          if e.status == code
            results[status.downcase.to_sym] << chk.output
            break
          end
        end
      rescue StandardError => e
        # Though an argument could be made to treat other exceptions as
        # critical instead of unknown.
        results[:unknown] << e.to_s
      end
    end
  end

  #
  # Construct the arg values for a check call based on a given set of options.
  # Adhere to the following rules:
  #
  #   * A single character option translates to "-o arg"
  #   * A >1 character option translates to "--option arg"
  #   * An option with a nil value translates to "--option"
  #
  # @param check_opts [Hash] a hash of check flags and values (or nil)
  #
  # @return [Array<String>] the correct argv for the given check options
  #
  def check_args_for(check_opts)
    check_opts.each_with_object([]) do |(k, v), arr|
      arr << (k.length == 1 ? "-#{k}" : "--#{k}")
      arr << v.to_s unless v.nil?
    end
  end

  #
  # Set up an object-level hash of result arrays so we can save the output
  # from every check thread.
  #
  # @return [Hash] A hash of Sensu statuses => check output messages
  #
  def results
    @results ||= { ok: [], warning: [], critical: [], unknown: [] }
  end
end
