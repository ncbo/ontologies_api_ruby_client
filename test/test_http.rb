# frozen_string_literal: true

require 'minitest/autorun'
require 'rack/multipart'
require 'stringio'
require_relative '../lib/ontologies_api_client'

class HTTPTest < Minitest::Test
  def test_multipart_upload_can_be_parsed_by_rack
    metadata = { 'hasOntologyLanguage' => 'OWL', 'description' => 'Ontology café' }
    contents = "<rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"/>\n"
    upload = Faraday::UploadIO.new(StringIO.new(contents), 'application/rdf+xml', 'ontology.owl')
    request = Faraday.new.build_request(:post)

    LinkedData::Client::HTTP.custom_req(metadata, upload, :file, request)

    body = request.body.read
    assert_equal body.bytesize.to_s, request.headers['Content-Length']
    env = {
      'CONTENT_TYPE' => request.headers['Content-Type'],
      'CONTENT_LENGTH' => request.headers['Content-Length'],
      'rack.input' => StringIO.new(body)
    }

    # Rack 3.2.9 rejects an unquoted type=application/json parameter.
    parsed = Rack::Multipart.parse_multipart(env)

    assert_equal %w[file json], parsed.keys.sort
    assert_equal metadata, MultiJson.load(parsed.fetch('json'))
    file = parsed.fetch('file')
    assert_equal 'ontology.owl', file.fetch(:filename)
    assert_equal 'application/rdf+xml', file.fetch(:type)
    assert_equal contents, file.fetch(:tempfile).read
  ensure
    request&.body&.close
    Array(env && env['rack.tempfiles']).each(&:close!)
  end

  def test_request_without_file_sends_json
    metadata = { 'hasOntologyLanguage' => 'OWL', 'description' => 'Ontology café' }
    request = Faraday.new.build_request(:post)

    LinkedData::Client::HTTP.custom_req(metadata, nil, nil, request)

    assert_equal 'application/json', request.headers['Content-Type']
    assert_equal metadata, MultiJson.load(request.body)
  end
end
