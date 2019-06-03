# frozen_string_literal: true

require 'rspec'
require 'simplecov'
require 'simplecov-console'

SimpleCov.formatter = SimpleCov::Formatter::Console
SimpleCov.minimum_coverage(100)
SimpleCov.start { add_filter 'test/' }
