# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'
require 'minitest/mock'
require_relative '../../lib/ontologies_api_client'

class PropertyTreeTest < Minitest::Test
  def test_builds_and_serializes_a_normal_tree
    parent = property('parent')
    child = property('child', ['parent'])

    tree = property_tree([parent, child])
    hash = tree.to_hash

    assert_equal [parent], tree.children
    assert_equal [child], parent.children
    assert_equal 1, hash[:childrenCount]
    assert_equal 'parent', hash[:children].first[:id]
    child_hash = hash[:children].first[:children].first
    assert_equal 'child', child_hash[:id]
    assert_equal 'child', child_hash[:prefLabel]
    assert_equal ['parent'], child_hash[:parents]
    assert_equal 0, child_hash[:childrenCount]
  end

  def test_ignores_self_parent_but_keeps_other_parent
    parent = property('parent')
    child = property('child', ['parent', 'child'])

    tree = property_tree([parent, child])

    assert_equal [parent], tree.children
    assert_equal [child], parent.children
    assert_empty child.children
    assert_equal ['parent', 'child'], child.parents
    assert_equal 0, tree.to_hash[:children].first[:children].first[:childrenCount]
  end

  def test_self_parent_only_property_becomes_a_root
    self_parent = property('self-parent', ['self-parent'])

    tree = property_tree([self_parent])

    assert_equal [self_parent], tree.children
    assert_empty self_parent.children
    assert_equal ['self-parent'], self_parent.parents
    assert_equal 'self-parent', tree.to_hash[:children].first[:id]
  end

  def test_serialization_omits_self_child_and_preserves_other_children
    parent = property('parent')
    child = property('child')
    parent.children = [parent, child]

    hash = parent.to_hash

    assert_equal ['child'], hash[:children].map { |p| p[:id] }
    assert_equal 1, hash[:childrenCount]
    assert_equal [parent, child], parent.children
  end

  def test_serialization_terminates_for_a_self_child_only
    parent = property('parent')
    parent.children = [parent]

    hash = parent.to_hash

    assert_empty hash[:children]
    assert_equal 0, hash[:childrenCount]
    assert_equal [parent], parent.children
  end

  def test_serialization_terminates_for_a_two_property_cycle
    first = property('first')
    second = property('second')
    first.children = [second]
    second.children = [first]

    hash = first.to_hash
    second_hash = hash[:children].first

    assert_equal 1, hash[:childrenCount]
    assert_equal 'second', second_hash[:id]
    assert_empty second_hash[:children]
    assert_equal 0, second_hash[:childrenCount]
    assert_equal [first], second.children
    assert_equal hash, first.to_hash
  end

  def test_shared_property_and_its_descendants_appear_under_each_parent
    left = property('left')
    right = property('right')
    shared = property('shared', ['left', 'right'])
    leaf = property('leaf', ['shared'])

    hash = property_tree([left, right, shared, leaf]).to_hash

    assert_equal 2, hash[:childrenCount]
    hash[:children].each do |parent_hash|
      assert_equal 1, parent_hash[:childrenCount]
      shared_hash = parent_hash[:children].first
      assert_equal 'shared', shared_hash[:id]
      assert_equal 1, shared_hash[:childrenCount]
      assert_equal 'leaf', shared_hash[:children].first[:id]
    end
  end

  private

  def property(id, parents = [])
    LinkedData::Client::Models::Property.new(values: { id: id, label: [id], parents: parents })
  end

  def property_tree(properties)
    ontology = LinkedData::Client::Models::Ontology.new
    explorer = Struct.new(:properties).new(properties)
    ontology.stub(:explore, explorer) { ontology.property_tree }
  end
end
