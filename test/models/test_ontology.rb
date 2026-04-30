# frozen_string_literal: true

require_relative '../test_case'

class OntologyTest < LinkedData::Client::TestCase
  def test_find_by_acronym
    result = LinkedData::Client::Models::Ontology.find_by_acronym('SNOMEDCT')
    refute_empty result
    assert_instance_of Array, result
    assert_equal 1, result.length

    ont = result.first
    assert_instance_of LinkedData::Client::Models::Ontology, ont
    assert_equal 'https://data.bioontology.org/ontologies/SNOMEDCT', ont.id
    assert_equal 'SNOMEDCT', ont.acronym
  end

  def test_find
    ont = LinkedData::Client::Models::Ontology.find('SNOMEDCT')
    refute_nil ont
    assert_instance_of LinkedData::Client::Models::Ontology, ont
    assert_equal 'https://data.bioontology.org/ontologies/SNOMEDCT', ont.id
    assert_equal 'SNOMEDCT', ont.acronym

    ont = LinkedData::Client::Models::Ontology.find('BiositemapIM')
    refute_nil ont
    assert_instance_of LinkedData::Client::Models::Ontology, ont
    assert_equal 'https://data.bioontology.org/ontologies/BiositemapIM', ont.id
    assert_equal 'BiositemapIM', ont.acronym
  end
end
