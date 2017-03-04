# encoding: utf-8
# frozen_string_literal: true

require_relative 'spec_helper'
require_relative '../bin/check-meta'

describe CheckMeta do
  let(:argv) { %w(-c fake-check.rb) }
  let(:check) { described_class.new(argv) }

  after(:all) do
    allow_any_instance_of(described_class).to receive(:at_exit)
  end

  describe '#initialize' do
    let(:c) { nil }
    let(:s) { nil }
    let(:f) { nil }
    let(:argv) do
      [
        (['-c', c] if c), (['-s', s] if s), (['-f', f] if f)
      ].flatten.compact
    end

    context 'all required switches provided' do
      let(:c) { 'fake-check.rb' }
      let(:s) { 'fake config' }

      it 'saves the config for later' do
        expected = { check: 'fake-check.rb', config_string: 'fake config' }
        expect(check.config).to eq(expected)
      end
    end

    context 'no check provided' do
      let(:c) { nil }
      let(:s) { 'fake config' }

      it 'raises an error' do
        allow_any_instance_of(described_class).to receive(:puts)
        expect { check }.to raise_error(SystemExit)
      end
    end
  end

  describe '#run' do
    let(:check) do
      c = super()
      c.config[:check] = 'fake-check.rb'
      c
    end
    before do
      %w(
        require
        puts
        status_information
        summarize!
      ).each do |m|
        allow_any_instance_of(described_class).to receive(m)
        allow_any_instance_of(described_class).to receive(:threads)
          .and_return(double(each: true))
      end
    end

    it 'imports the configured check' do
      c = check
      expect(c).to receive(:require)
        .with(File.expand_path('../fake-check.rb', $PROGRAM_NAME))
      c.run
    end

    it 'joins all the subcheck threads' do
      c = check
      thread1 = double
      thread2 = double
      expect(c).to receive(:threads).and_return([thread1, thread2])
      expect(thread1).to receive(:join)
      expect(thread2).to receive(:join)
      c.run
    end

    it 'prints the subcheck status to stdout' do
      c = check
      expect(c).to receive(:status_information).and_return('stubstatus')
      expect(c).to receive(:puts).with('stubstatus')
      c.run
    end

    it 'summarizes and exits' do
      c = check
      expect(c).to receive(:summarize!)
      c.run
    end
  end

  describe '#summarize!' do
    let(:ok) { [] }
    let(:warning) { [] }
    let(:critical) { [] }
    let(:unknown) { [] }
    let(:results) do
      { ok: ok, warning: warning, critical: critical, unknown: unknown }
    end
    let(:check) do
      c = super()
      c.instance_variable_set(:@results, results)
      c
    end

    before do
      allow_any_instance_of(described_class).to receive(:summary)
        .and_return('fake summary')
    end

    context 'a mix of results' do
      let(:ok) { %w(1 2) }
      let(:warning) { %w(1 2 3) }
      let(:critical) { %w(1) }
      let(:unknown) { %w(1 2 3 4) }

      it 'ends with the expected status' do
        c = check
        expect(c).to receive(:critical).with('fake summary')
        %w(warning unknown ok).each { |m| allow(c).to receive(m) }
        c.summarize!
      end
    end

    context 'only ok results' do
      let(:ok) { %w(1 2) }

      it 'ends with the expected status' do
        c = check
        expect(c).to receive(:ok).with('fake summary')
        c.summarize!
      end
    end

    context 'only warning results' do
      let(:warning) { %w(1 2 3) }

      it 'ends with the expected status' do
        c = check
        expect(c).to receive(:warning).with('fake summary')
        allow(c).to receive(:ok)
        c.summarize!
      end
    end

    context 'only critical results' do
      let(:critical) { %w(1) }

      it 'ends with the expected status' do
        c = check
        expect(c).to receive(:critical).with('fake summary')
        allow(c).to receive(:ok)
        c.summarize!
      end
    end

    context 'only unknown results' do
      let(:unknown) { %w(1 2 3 4) }

      it 'ends with the expected status' do
        c = check
        expect(c).to receive(:unknown).with('fake summary')
        allow(c).to receive(:ok)
        c.summarize!
      end
    end
  end

  describe '#status_information' do
    let(:ok) { [] }
    let(:warning) { [] }
    let(:critical) { [] }
    let(:unknown) { [] }
    let(:results) do
      { ok: ok, warning: warning, critical: critical, unknown: unknown }
    end
    let(:check) do
      c = super()
      c.instance_variable_set(:@results, results)
      c
    end

    context 'a mix of results' do
      let(:ok) { ['Check: 1 ok', 'Check: 2 ok'] }
      let(:warning) { ['Check: 1 warn'] }
      let(:critical) { ['Check: 1 crit', 'Check: 2 crit'] }
      let(:unknown) { ['Check: 1 unknown'] }
      it 'returns a string of check results' do
        expected = <<-EOH.gsub(/^ +/, '').strip
          UNKNOWN: Check: 1 unknown
          WARNING: Check: 1 warn
          CRITICAL: Check: 1 crit
          CRITICAL: Check: 2 crit
        EOH
        expect(check.status_information).to eq(expected)
      end
    end

    context 'only ok results' do
      let(:ok) { ['Check: 1 ok', 'Check: 2 ok', 'Check: 3 ok'] }

      it 'returns a string of check results' do
        expect(check.status_information).to eq('')
      end
    end

    context 'only warning results' do
      let(:warning) { ['Check: 1 warn', 'Check: 2 warn', 'Check: 3 warn'] }

      it 'returns a string of check results' do
        expected = <<-EOH.gsub(/^ +/, '').strip
          WARNING: Check: 1 warn
          WARNING: Check: 2 warn
          WARNING: Check: 3 warn
        EOH
        expect(check.status_information).to eq(expected)
      end
    end

    context 'only critical results' do
      let(:critical) { ['Check: 1 crit', 'Check: 2 crit', 'Check: 3 crit'] }

      it 'returns a string of check results' do
        expected = <<-EOH.gsub(/^ +/, '').strip
          CRITICAL: Check: 1 crit
          CRITICAL: Check: 2 crit
          CRITICAL: Check: 3 crit
        EOH
        expect(check.status_information).to eq(expected)
      end
    end

    context 'only unknown results' do
      let(:unknown) { ['Check: 1 ???', 'Check: 2 ???', 'Check: 3 ???'] }

      it 'returns a string of check results' do
        expected = <<-EOH.gsub(/^ +/, '').strip
          UNKNOWN: Check: 1 ???
          UNKNOWN: Check: 2 ???
          UNKNOWN: Check: 3 ???
        EOH
        expect(check.status_information).to eq(expected)
      end
    end
  end

  describe '#summary' do
    let(:check) do
      results = { ok: %w(ok1 ok2),
                  warning: %w(warn1),
                  critical: %w(crit1 crit2 crit3 crit4),
                  unknown: %w(un1 un2 un3) }
      c = super()
      c.instance_variable_set(:@results, results)
      c
    end

    it 'returns the expected summary message' do
      expected = 'Results: 4 critical, 1 warning, 3 unknown, 2 ok'
      expect(check.summary).to eq(expected)
    end
  end

  describe '#check_class' do
    it 'patches and returns the check class' do
      klass = Class.new(Sensu::Plugin::Check::CLI)
      c = check
      expect(c).to receive(:patch_class!).with(klass)
      expect(c.check_class).to eq(klass)
    end
  end

  describe '#patch_class!' do
    it 'patches in a status method' do
      klass = Class.new(Sensu::Plugin::Check::CLI)
      check.patch_class!(klass)
      obj = klass.new([])
      obj.instance_variable_set(:@status, 'ok')
      expect(obj.status).to eq('ok')
    end

    it 'patches the existing output method' do
      klass = Class.new(Sensu::Plugin::Check::CLI)
      check.patch_class!(klass)
      obj = klass.new([])
      expect(obj.output('msg')).to match(/^#<Class:[0-9a-z]+>: msg$/)
    end
  end

  describe '#threads' do
    let(:parsed_config) { [{ key: 'val1' }, { key: 'val2' }] }

    before do
      allow_any_instance_of(described_class).to receive(:parsed_config)
        .and_return(parsed_config)
    end

    it 'returns an array of threads' do
      c = check
      expect(c).to receive(:thread_for).with(key: 'val1').and_return(1)
      expect(c).to receive(:thread_for).with(key: 'val2').and_return(2)
      expect(c.threads).to eq([1, 2])
    end
  end

  describe '#parsed_config' do
    let(:string) { nil }
    let(:file) { nil }
    let(:file_content) { nil }
    let(:argv) do
      [
        %w(-c fake-check.rb),
        (['-s', string] if string),
        (['-f', file] if file)
      ].flatten.compact
    end

    before(:each) do
      allow(File).to receive(:read).with(file).and_return(file_content) if file
    end

    context 'a config string' do
      let(:string) { '[{"key": "val"}]' }

      it 'returns the parsed config' do
        expect(check.parsed_config).to eq([{ key: 'val' }])
      end
    end

    context 'a config file' do
      let(:file) { '/tmp/check.json' }
      let(:file_content) { '[{"key": "val"}]' }

      it 'returns the parsed config' do
        expect(check.parsed_config).to eq([{ key: 'val' }])
      end
    end
  end

  describe '#thread_for' do
    let(:check_opts) { { host: 'example.com' } }
    let(:check_args) { %w(--host example.com) }
    let(:check_class) { Class.new(Sensu::Plugin::Check::CLI) }

    before do
      allow(Thread).to receive(:new).and_yield
      allow_any_instance_of(described_class).to receive(:check_class)
        .and_return(check_class)
      allow_any_instance_of(described_class).to receive(:check_args_for)
        .with(check_opts).and_return(check_args)
      allow(check_class).to receive(:new).with(check_args)
        .and_return('stub check')
    end

    it 'returns a thread for running the check' do
      c = check
      expect(c).to receive(:run_check!).with('stub check')
      c.thread_for(check_opts)
    end
  end

  describe '#run_check!' do
    let(:subcheck_output) { nil }
    let(:subcheck_exit_status) { nil }
    let(:subcheck_exception) { nil }
    let(:subcheck) { double }

    before(:each) do
      if subcheck_exit_status
        allow(subcheck).to receive(:output).and_return(subcheck_output)
        expect(subcheck).to receive(:run).and_raise(SystemExit,
                                                    subcheck_exit_status)
      else
        expect(subcheck).to receive(:run).and_raise(RuntimeError,
                                                    subcheck_exception)
      end
    end

    let(:check) do
      c = super()
      c.run_check!(subcheck)
      c
    end

    context 'a subcheck that returns ok' do
      let(:subcheck_output) { 'Okay!' }
      let(:subcheck_exit_status) { 0 }

      it 'correctly preserves the result' do
        expected = { ok: %w(Okay!), warning: [], critical: [], unknown: [] }
        expect(check.results).to eq(expected)
      end
    end

    context 'a subcheck that returns warning' do
      let(:subcheck_output) { 'Warning!' }
      let(:subcheck_exit_status) { 1 }

      it 'correctly preserves the result' do
        expected = { ok: [], warning: %w(Warning!), critical: [], unknown: [] }
        expect(check.results).to eq(expected)
      end
    end

    context 'a subcheck that returns critical' do
      let(:subcheck_output) { 'Critical!' }
      let(:subcheck_exit_status) { 2 }

      it 'correctly preserves the result' do
        expected = { ok: [], warning: [], critical: %w(Critical!), unknown: [] }
        expect(check.results).to eq(expected)
      end
    end

    context 'a subcheck that returns unknown' do
      let(:subcheck_output) { 'Unknown!' }
      let(:subcheck_exit_status) { 3 }

      it 'correctly preserves the result' do
        expected = { ok: [], warning: [], critical: [], unknown: %w(Unknown!) }
        expect(check.results).to eq(expected)
      end
    end

    context 'a subcheck that raises some other exception' do
      let(:subcheck_exception) { 'Oh no!' }

      it 'correctly preserves the result' do
        expected = { ok: [], warning: [], critical: [], unknown: ['Oh no!'] }
        expect(check.results).to eq(expected)
      end
    end
  end

  describe '#exit_statuses' do
    it 'returns the expected array of exit statuses' do
      expect(check.exit_statuses).to eq(%i(ok warning critical unknown))
    end
  end

  describe '#check_args_for' do
    let(:check_opts) { nil }
    let(:res) { check.check_args_for(check_opts) }

    context 'a short switch' do
      let(:check_opts) { { s: 'wiggling' } }

      it 'returns the correct argv set' do
        expect(res).to eq(%w(-s wiggling))
      end
    end

    context 'a long switch' do
      let(:check_opts) { { state: 'wiggling' } }

      it 'returns the correct argv set' do
        expect(res).to eq(%w(--state wiggling))
      end
    end

    context 'a boolean switch' do
      let(:check_opts) { { fail_immediately: nil } }

      it 'returns the correct argv set' do
        pending
        expect(res).to eq(%w(--fail-immediately))
      end
    end

    context 'a mix of switches' do
      let(:check_opts) { { s: 'wiggling', on_time: 'no', delayed: nil } }

      it 'returns the correct argv set' do
        pending
        expect(res).to eq(%w(-s wiggling --on-time no --delayed))
      end
    end
  end

  describe '#results' do
    it 'saves an empty hash in an instance variable' do
      expected = { ok: [], warning: [], critical: [], unknown: [] }
      c = check
      expect(c.results).to eq(expected)
      expect(c.instance_variable_get(:@results)).to eq(expected)
    end
  end
end
