#!/usr/bin/env ruby
# encoding: utf-8
# frozen_string_literal: false

#
#   check-meta-ruby.rb
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
#     check-meta-ruby.rb -c check-http.rb -j /etc/sensu/http_checks.json
#
#   Run a check multiple times using an inline JSON config string:
#
#     check-meta-ruby.rb -c check-http.rb -j '[
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
class CheckMetaRuby < Sensu::Plugin::Check::CLI
  option :check,
         short: '-c CHECK_SCRIPT',
         long: '--check CHECK_SCRIPT',
         description: 'The Sensu Ruby check to run multiple times',
         required: true

  option :json_config,
         short: '-j CONFIG_STRING_OR_PATH',
         long: '--json-config CONFIG_STRING_OR_PATH',
         description: 'A JSON config string or path to a config file',
         required: true

  #
  # Import the check we want to run and dispatch threads for every instance of
  # it. Once all threads are complete, batch the results and return any
  # non-ok status messages.
  #
  def run
    require File.expand_path("../#{config[:check]}", $PROGRAM_NAME)

    threads.each(&:join)

    puts status_information unless status_information.empty?
    summarize!
  end

  #
  # Send all the information about this run to stdout and exit with the
  # appropriate status.
  #
  def summarize!
    %i[critical warning unknown].each do |status|
      send(status, summary) unless results[status].empty?
    end
    ok(summary)
  end

  #
  # Construct a string of the results of all the subchecks that have been run
  # and not returned okay.
  #
  # @return [String] a long string of all the non-ok subcheck statuses
  #
  def status_information
    %i[unknown warning critical].map do |status|
      results[status].map { |result| "#{status.upcase}: #{result}" }
    end.flatten.compact.join("\n")
  end

  #
  # Construct the final summary message for our metacheck output.
  #
  # @return [String] a summary status of all the checks that have been run
  #
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
        klass < Sensu::Plugin::Check::CLI && \
          klass != self.class && \
          !klass.ancestors.include?(self.class)
      end
      patch_class!(c)
      c
    end
  end

  #
  # Patch a Sensu check class so it saves its output instead of sending it
  # to stdout. Otherwise the threading screws up the rendering.
  #
  # @param klass [Sensu::Plugin::Check::CLI] the check class to patch
  #
  def patch_class!(klass)
    klass.class_eval do
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
  end

  #
  # Work through the array generated from our JSON config and return an array
  # of corresponding thread objects.
  #
  #
  # @return [Array<Thread>] an array of threads to run
  #
  def threads
    parsed_config.map { |check_opts| thread_for(check_opts) }
  end

  #
  # Return a parsed and symbolized version of our JSON config.
  #
  # @return [Hash] the metacheck config
  #
  def parsed_config
    @parsed_config ||= begin
                         JSON.parse(config[:json_config], symbolize_names: true)
                       rescue JSON::ParserError
                         JSON.parse(File.read(config[:json_config]),
                                    symbolize_names: true)
                       end
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
      run_check!(chk)
    end
  end

  #
  # Accept and run a given sub-check object, catch its resultant status and
  # output, and preserve that data for later processing.
  #
  # @param chk [Sensu::Plugin::Check::CLI] a Sensu check object
  #
  def run_check!(chk)
    chk.run
  rescue SystemExit => e
    results[exit_statuses[e.status]] << chk.output
  rescue StandardError => e
    # Though an argument could be made to treat other exceptions as
    # critical instead of unknown.
    results[:unknown] << e.to_s
  end

  #
  # Invert Sensu's exit codes hash so it's an array of exit codes to statuses,
  # downcased and symbolized, e.g. exit_status[0] => :ok.
  #
  # @return [Array<Symbol>] an inverted index of Sensu exit codes and statues
  #
  def exit_statuses
    Sensu::Plugin::EXIT_CODES.each_with_object([]) do |(status, code), arr|
      arr[code] = status.downcase.to_sym
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
      arr << (k.length == 1 ? "-#{k}" : "--#{k.to_s.tr('_', '-')}")
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
