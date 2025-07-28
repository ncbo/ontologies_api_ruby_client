# frozen_string_literal: true

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
end
