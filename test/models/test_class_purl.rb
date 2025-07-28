# frozen_string_literal: true

require_relative '../test_case'

class ClassTest < LinkedData::Client::TestCase

  # Test PURL generation for a class in an OWL format ontology
  def test_purl_owl
    cls = LinkedData::Client::Models::Class.find(
      'http://bioontology.org/ontologies/Activity.owl#Activity',
      'https://data.bioontology.org/ontologies/BRO'
    )
    refute_nil cls

    res = fetch_response(cls.purl)
    assert_equal 302, res.status
    assert_equal 'https://bioportal.bioontology.org/ontologies/BRO'\
                 '/classes?conceptid=http%3A%2F%2Fbioontology.org%2Fontologies%2FActivity.owl%23Activity',
                 res.headers['location']
  end

  # Test PURL generation for a class in a UMLS format ontology
  def test_purl_umls
    cls = LinkedData::Client::Models::Class.find(
      'http://purl.bioontology.org/ontology/SNOMEDCT/64572001',
      'https://bioportal.bioontology.org/ontologies/SNOMEDCT'
    )
    refute_nil cls

    res = fetch_response(cls.purl)
    assert_equal 302, res.status
    assert_equal 'https://bioportal.bioontology.org/ontologies/SNOMEDCT/classes/64572001',
                 res.headers['location']
  end

  # Test PURL generation for a class in an OBO format ontology
  def test_purl_obo
    cls = LinkedData::Client::Models::Class.find(
      'http://purl.obolibrary.org/obo/DOID_4',
      'https://bioportal.bioontology.org/ontologies/DOID'
    )
    refute_nil cls

    res = fetch_response(cls.purl)
    assert_equal 302, res.status
    assert_equal 'https://bioportal.bioontology.org/ontologies/DOID'\
                 '/classes?conceptid=http%3A%2F%2Fpurl.obolibrary.org%2Fobo%2FDOID_4',
                 res.headers['location']
  end

  private

  def fetch_response(url)
    conn = Faraday.new do |f|
      f.adapter Faraday.default_adapter
    end
    conn.get(url)
  end
end
