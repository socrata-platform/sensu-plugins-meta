# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'date'
require 'sensu_plugins_meta'

Gem::Specification.new do |s|
  s.authors = ['Sensu-Plugins and contributors']
  s.date = Date.today.to_s
  s.description = 'This plugin provides a way to call other check plugins ' \
                  'multiple times as a single check.'
  s.email = '<sensu-users@googlegroups.com>'
  s.executables = Dir.glob('bin/**/*.rb').map { |file| File.basename(file) }
  s.files = [
    Dir.glob('{bin,lib}/**/*'),
    'LICENSE',
    'README.md',
    'CHANGELOG.md'
  ]
  s.homepage = 'https://github.com/socrata-platform/sensu-plugins-meta'
  s.license = 'MIT'
  s.metadata = { 'maintainer' => 'sensu-plugin',
                 'development_status' => 'active',
                 'production_status' => 'unstable - testing recommended',
                 'release_draft' => 'false',
                 'release_prerelease' => 'false' }
  s.name = 'sensu-plugins-meta'
  s.platform = Gem::Platform::RUBY
  s.post_install_message = 'You can use the embedded Ruby by setting ' \
                           'EMBEDDED_RUBY=true in /etc/default/sensu'
  s.require_paths = %w[lib]
  s.required_ruby_version = '>= 2.1.0'
  s.summary = 'Sensu plugins for batching multiple checks as one'
  s.test_files = s.files.grep(%r{^(test|spec|features)/})
  s.version = SensuPluginsMeta::Version::VER_STRING

  s.add_runtime_dependency 'sensu-plugin', '>= 1.2', '< 3.0'

  s.add_development_dependency 'berkshelf', '~> 6.3'
  s.add_development_dependency 'bundler', '~> 1.7'
  s.add_development_dependency 'coveralls', '~> 0.8'
  s.add_development_dependency 'github-markup', '~> 2.0'
  s.add_development_dependency 'kitchen-dokken', '~> 2.6'
  s.add_development_dependency 'kitchen-inspec', '~> 0.22'
  s.add_development_dependency 'pry', '~> 0.10'
  s.add_development_dependency 'rake', '~> 12.0'
  s.add_development_dependency 'redcarpet', '~> 3.2'
  s.add_development_dependency 'rspec', '~> 3.1'
  s.add_development_dependency 'rubocop', '~> 0.52'
  s.add_development_dependency 'simplecov', '~> 0.12'
  s.add_development_dependency 'simplecov-console', '~> 0.4'
  s.add_development_dependency 'test-kitchen', '~> 1.6'
  s.add_development_dependency 'yard', '~> 0.9'
end
