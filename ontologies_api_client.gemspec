# frozen_string_literal: true

require_relative 'lib/ontologies_api_client/version'

Gem::Specification.new do |gem|
  gem.authors       = ['Paul R Alexander']
  gem.email         = ['support@bioontology.org']
  gem.description   = 'Models and serializers for ontologies and related artifacts backed by an RDF database'
  gem.summary       = 'This library can be used for interacting with an AllegroGraph or 4store instance that stores ' \
                      'BioPortal-based ontology information. Models in the library are based on Goo. Serializers ' \
                      'support RDF serialization as Rack Middleware and automatic generation of hypermedia links.'
  gem.homepage      = 'https://github.com/ncbo/ontologies_api_ruby_client'

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = 'ontologies_api_client'
  gem.require_paths = ['lib']
  gem.version       = LinkedData::Client::VERSION

  gem.add_dependency('activesupport', '8.0.3')
  gem.add_dependency('addressable', '~> 2.8')
  gem.add_dependency('excon')
  gem.add_dependency('faraday')
  gem.add_dependency('faraday-excon')
  gem.add_dependency('faraday-multipart')
  gem.add_dependency('lz4-ruby')
  gem.add_dependency('multi_json')
  gem.add_dependency('oj')

  gem.add_development_dependency('faraday-follow_redirects', '~> 0.3')
  gem.add_development_dependency('minitest', '~> 5.26')
  gem.add_development_dependency('minitest-hooks', '~> 1.5')
end
