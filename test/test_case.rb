# frozen_string_literal: true
# Start simplecov if this is a coverage task or if it is run in the CI pipeline
if ENV['COVERAGE'] || ENV['CI']
  require 'simplecov'
  require 'simplecov-cobertura'

  SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::CoberturaFormatter, # writes coverage/cobertura.xml
  ])

  SimpleCov.start do
    enable_coverage :branch
    add_filter %w[/test/ /config/]
  end
end

require 'bundler/setup'
require 'pry'
require 'minitest/autorun'
require 'minitest/hooks/test'
require_relative '../lib/ontologies_api_client'
require_relative '../config/config'

module LinkedData
  module Client
    class TestCase < Minitest::Test
      include Minitest::Hooks

      def before_all
        super
        params = { q: 'Conceptual Entity', ontologies: 'STY', require_exact_match: 'true', display_links: 'false' }
        response = LinkedData::Client::HTTP.get('/search', params)
        if response.respond_to?('status') && response.status.eql?(401)
          abort('ABORTED! You must provide a valid API key.')
        end
      end
    end
  end
end
