# frozen_string_literal: true

require 'faraday/follow_redirects'
require_relative '../test_case'

class ClassTest < LinkedData::Client::TestCase
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

    res = fetch_response(cls.purl)
    assert_equal 200, res.status
    assert_equal 'https://bioportal.bioontology.org/ontologies/BRO'\
                 '?p=classes&conceptid=http%3A%2F%2Fbioontology.org%2Fontologies%2FActivity.owl%23Activity',
                 res.env[:url].to_s
  end

  # Test PURL generation for a class in a UMLS format ontology
  def test_purl_umls
    cls = LinkedData::Client::Models::Class.find(
      'http://purl.bioontology.org/ontology/SNOMEDCT/64572001',
      'https://bioportal.bioontology.org/ontologies/SNOMEDCT'
    )
    refute_nil cls

    res = fetch_response(cls.purl)
    assert_equal 200, res.status
    assert_equal 'https://bioportal.bioontology.org/ontologies/SNOMEDCT?p=classes&conceptid=64572001',
                 res.env[:url].to_s
  end

  # Test PURL generation for a class in an OBO format ontology
  def test_purl_obo
    cls = LinkedData::Client::Models::Class.find(
      'http://purl.obolibrary.org/obo/DOID_4',
      'https://bioportal.bioontology.org/ontologies/DOID'
    )
    refute_nil cls

    res = fetch_response(cls.purl)
    assert_equal 200, res.status
    assert_equal 'https://bioportal.bioontology.org/ontologies/DOID'\
                 '?p=classes&conceptid=http%3A%2F%2Fpurl.obolibrary.org%2Fobo%2FDOID_4',
                 res.env[:url].to_s
  end

  private

  def fetch_response(url)
    conn = Faraday.new do |f|
      f.response :follow_redirects
      f.adapter Faraday.default_adapter
    end
    conn.get(url)
  end
end
