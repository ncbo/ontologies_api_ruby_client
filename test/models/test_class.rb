# frozen_string_literal: true

require_relative '../test_case'

class ClassTest < LinkedData::Client::TestCase
  @@purl_prefix = LinkedData::Client.settings.purl_prefix

  def test_find
    id = 'http://bioontology.org/ontologies/Activity.owl#Activity'
    ontology = 'https://data.bioontology.org/ontologies/BRO'
    cls = LinkedData::Client::Models::Class.find(id, ontology)
    refute_nil cls
    assert_instance_of LinkedData::Client::Models::Class, cls
    assert_equal id, cls.id
    assert_equal 'http://www.w3.org/2002/07/owl#Class', cls.type
    assert_equal 'Activity', cls.prefLabel
    assert_equal ontology, cls.links['ontology']
    assert cls.hasChildren
  end

  # Test PURL generation for a class in an OWL format ontology
  def test_purl_owl
    cls = LinkedData::Client::Models::Class.find(
      'http://bioontology.org/ontologies/Activity.owl#Activity',
      'https://data.bioontology.org/ontologies/BRO'
    )
    refute_nil cls
    expected_purl = "#{@@purl_prefix}/BRO?conceptid=http%3A%2F%2Fbioontology.org%2Fontologies%2FActivity.owl%23Activity"
    assert_equal expected_purl, cls.purl

    res = fetch_response(cls.purl)
    assert_equal 302, res.status
    assert_equal 'https://bioportal.bioontology.org/ontologies/BRO/classes?conceptid=http%3A%2F%2Fbioontology.org%2Fontologies%2FActivity.owl%23Activity',
                 res.headers['location']
  end

  # Test PURL generation for a class in a UMLS format ontology
  def test_purl_umls
    skip 'Disable until #41 is fixed: https://github.com/ncbo/ontologies_api_ruby_client/issues/41'

    cls = LinkedData::Client::Models::Class.find(
      'http://purl.bioontology.org/ontology/SNOMEDCT/64572001',
      'https://bioportal.bioontology.org/ontologies/SNOMEDCT'
    )
    refute_nil cls

    # The ID already contains the PURL host, so .purl should return it as-is
    assert_equal cls.id, cls.purl

    res = fetch_response(cls.purl)
    assert_equal 302, res.status
    assert_equal 'https://bioportal.bioontology.org/ontologies/SNOMEDCT/classes/64572001',
                 res.headers['location']
  end

  # Test PURL generation for a class in an OBO format ontology
  def test_purl_obo
    skip 'Disable until #41 is fixed: https://github.com/ncbo/ontologies_api_ruby_client/issues/41'

    cls = LinkedData::Client::Models::Class.find(
      'http://purl.obolibrary.org/obo/DOID_4',
      'https://bioportal.bioontology.org/ontologies/DOID'
    )
    refute_nil cls

    expected_purl = "#{@@purl_prefix}/DOID?conceptid=http%3A%2F%2Fpurl.obolibrary.org%2Fobo%2FDOID_4"
    assert_equal expected_purl, cls.purl

    res = fetch_response(cls.purl)
    assert_equal 302, res.status

    expected_location = 'https://bioportal.bioontology.org/ontologies/DOID/classes?conceptid=http%3A%2F%2Fpurl.obolibrary.org%2Fobo%2FDOID_4'
    actual_location = res.headers['location']
    normalize = ->(url) { url&.sub(%r{/(\?)}, '\1') }
    assert_equal normalize.call(expected_location), normalize.call(actual_location)
  end

  private

  def fetch_response(url)
    Faraday.new do |f|
      f.adapter Faraday.default_adapter
    end.get(url)
  end
end
