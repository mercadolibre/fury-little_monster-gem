lib = File.expand_path('lib', __dir__)
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

  spec.add_runtime_dependency 'activesupport', '6.1.7.6'# '7.0.4.2'
  spec.add_runtime_dependency 'multi_json', '1.15.0'
  spec.add_runtime_dependency 'thor', '1.2.1'
  spec.add_runtime_dependency 'tilt', '2.1.0'
  spec.add_runtime_dependency 'toiler', '0.7.1'
  spec.add_runtime_dependency 'typhoeus', '1.4.0'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'byebug', '11.1.3'
  spec.add_development_dependency 'oj', '3.14.2'
  spec.add_development_dependency 'pry', '0.14.2'
  spec.add_development_dependency 'rake', '13.0.6'
  spec.add_development_dependency 'require_all', '3.0.0'
  spec.add_development_dependency 'rspec', '3.12.0'
  spec.add_development_dependency 'rubocop', '1.46.0'
  spec.add_development_dependency 'simplecov', '0.22.0'
  spec.add_development_dependency 'webmock', '3.20.0'

  spec.metadata['rubygems_mfa_required'] = 'true'
end
