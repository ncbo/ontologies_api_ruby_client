Gem::Specification.new do |gem|
  gem.authors       = ["Paul R Alexander"]
  gem.email         = ["support@bioontology.org"]
  gem.description   = %q{Models and serializers for ontologies and related artifacts backed by 4store}
  gem.summary       = %q{This library can be used for interacting with a 4store instance that stores NCBO-based ontology information. Models in the library are based on Goo. Serializers support RDF serialization as Rack Middleware and automatic generation of hypermedia links.}
  gem.homepage      = "https://github.com/ncbo/ontologies_api_ruby_client"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "ontologies_api_client"
  gem.require_paths = ["lib"]
  gem.version       = "2.0.0"

  gem.add_dependency('multi_json')
  gem.add_dependency('oj')
  gem.add_dependency('faraday')
  gem.add_dependency('excon')
  gem.add_dependency('lz4-ruby')
  gem.add_dependency('spawnling', '2.1.5')
  gem.add_dependency('activesupport', '>= 5.1.7', '< 6.1.0')

  # gem.executables = %w()
end
