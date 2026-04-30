require_relative '../test_case'
require 'pry'

module Models
  def self.method_missing
    binding.pry
  end
end

class LinkExploreTest < LinkedData::Client::TestCase
  def test_explore
    sub_direct_explore = LinkedData::Client::Models::Ontology.explore('MEDDRA')
                                                             .latest_submission
                                                             .get(include: 'all')

    sub_indirect_explore = LinkedData::Client::Models::Ontology.find('MEDDRA').explore.latest_submission

    refute_nil sub_direct_explore
    refute_nil sub_indirect_explore

    sub_direct_explore.to_hash.each do |key, value|
      value_to_compare = sub_indirect_explore.to_hash[key]
      if value.class.ancestors.include?(LinkedData::Client::Base)
        value = value.to_hash
        value_to_compare = value_to_compare.to_hash
      end
      # assert_equal value_to_compare, value, "Mismatch for key #{key}"
      assert value == value_to_compare, "Mismatch for key #{key}: #{value.inspect} != #{value_to_compare.inspect}"
    end
  end

  def test_explore_class

    id = 'http://purl.org/sig/ont/fma/fma62955'
    cls = LinkedData::Client::Models::Ontology.explore('FMA')
                                              .classes(id)
                                              .children
                                              .get

    refute_empty cls.collection

    cls = LinkedData::Client::Models::Ontology.explore('FMA')
                                              .classes(id)
                                              .children
                                              .get(include: 'prefLabel')

    refute_empty cls.collection
  end

end
