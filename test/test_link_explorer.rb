# frozen_string_literal: true

require_relative 'test_case'

class LinkExplorerTest < LinkedData::Client::TestCase
  def test_explore_ontology_submission_by_id
    ont = LinkedData::Client::Models::Ontology.get('FMA')
    sub = ont.explore.submissions('29')
    refute_nil(sub)
    assert_instance_of(LinkedData::Client::Models::OntologySubmission, sub)
    assert_equal(29, sub.submissionId)
  end

  def test_explore_ontology_class_by_id
    ont = LinkedData::Client::Models::Ontology.get('FMA')
    cls = ont.explore.classes('http://purl.org/sig/ont/fma/fma70742')
    refute_nil(cls)
    assert_instance_of(LinkedData::Client::Models::Class, cls)
    assert_equal('http://purl.org/sig/ont/fma/fma70742', cls.id)
    assert_equal('Set of eyelashes', cls.prefLabel)
  end

  def test_explore_ontology_single_class
    ont = LinkedData::Client::Models::Ontology.get('FMA')
    cls = ont.explore.single_class('http://purl.org/sig/ont/fma/fma322428')
    refute_nil(cls)
    assert_instance_of(LinkedData::Client::Models::Class, cls)
    assert_equal('http://purl.org/sig/ont/fma/fma322428', cls.id)
    assert_equal('Set of salivary glands', cls.prefLabel)
  end
end
