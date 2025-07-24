# frozen_string_literal: true

require 'logger'
require 'active_support'
require 'active_support/logger'

require 'minitest/autorun'
require 'minitest/hooks/test'
require_relative '../lib/ontologies_api_client'
require_relative '../config/config'

Logger = ::Logger unless defined?(Logger)
module Rails
  def self.cache
    @cache ||= ActiveSupport::Cache::MemoryStore.new
  end
end

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
