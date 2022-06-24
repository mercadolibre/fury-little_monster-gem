
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'little_monster/version'

Gem::Specification.new do |spec|
  spec.name          = 'little_monster'
  spec.version       = LittleMonster::VERSION
  spec.authors       = ['arq']
  spec.email         = ['arquitectura@mercadolibre.com']

  spec.summary       = 'Write a short summary, because Rubygems requires one.'
  spec.description   = 'Write a longer description or delete this line.'
  spec.homepage      = 'http://github.com/mercadolibre/fury-little_monster-gem'
  spec.license       = 'MIT'

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  #  if spec.respond_to?(:metadata)
  #    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  #  else
  #    raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  #  end
  #
  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = ['lm']
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'activesupport'
  spec.add_runtime_dependency 'multi_json'
  spec.add_runtime_dependency 'thor'
  spec.add_runtime_dependency 'tilt'
  spec.add_runtime_dependency 'toiler'
  spec.add_runtime_dependency 'typhoeus'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'byebug'
  spec.add_development_dependency 'oj'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'require_all'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'simplecov'
end
