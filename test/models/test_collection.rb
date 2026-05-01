# frozen_string_literal: true

require 'pry'
require_relative '../test_case'

class TestOntology < LinkedData::Client::Base
  include LinkedData::Client::Collection
  include LinkedData::Client::ReadWrite

  @media_type    = 'http://data.bioontology.org/metadata/Ontology'
  @include_attrs = 'all'
end

class CollectionTest < LinkedData::Client::TestCase
  def test_all
    onts = LinkedData::Client::Models::Ontology.all
    assert onts.length > 350
  end

  def test_all_flattens_paged_collections
    calls = []
    pages = {
      1 => OpenStruct.new(collection: %w[a b], pageCount: 2, nextPage: 2),
      2 => OpenStruct.new(collection: %w[c], pageCount: 2, nextPage: nil)
    }

    TestOntology.stub(:entry_point, ->(_media_type, params) {
      calls << params
      pages.fetch(params[:page] || 1)
    }) do
      assert_equal %w[a b c], TestOntology.all
    end

    assert_equal [{ pagesize: 5_000 }, { pagesize: 5_000, page: 2 }], calls
  end

  def test_all_returns_page_when_page_requested
    requested_page = OpenStruct.new(collection: %w[a b], pageCount: 2, nextPage: 2)

    TestOntology.stub(:entry_point, ->(_media_type, _params) { requested_page }) do
      assert_same requested_page, TestOntology.all(page: 1)
    end
  end

  # Back-compat invariant: when an endpoint returns a flat Array (i.e. it
  # hasn't been paginated yet — e.g. /ontologies, /groups, /categories
  # today), Collection#all must pass the response through unchanged. This
  # is what keeps non-paginated endpoints working after this gem's
  # auto-flatten change. Guards against future refactors of the page-walk
  # logic accidentally breaking the non-paged path; complements the
  # network-dependent `test_all` which would only catch the regression
  # against a live API.
  def test_all_passes_through_array_response
    array_response = [OpenStruct.new(id: 'a'), OpenStruct.new(id: 'b'), OpenStruct.new(id: 'c')]
    calls = []

    TestOntology.stub(:entry_point, ->(_media_type, params) {
      calls << params
      array_response
    }) do
      assert_same array_response, TestOntology.all
    end

    # Sanity: pagesize is still injected on the request — the API simply
    # ignores it and returns an Array, which we hand back as-is.
    assert_equal [{ pagesize: 5_000 }], calls
  end

  def test_user_all_uses_lightweight_defaults
    calls = []

    LinkedData::Client::Models::User.stub(:entry_point, ->(_media_type, params) {
      calls << params
      []
    }) do
      assert_equal [], LinkedData::Client::Models::User.all
    end

    assert_equal "username,email,role,firstName,lastName,created", LinkedData::Client::Models::User.include_attrs
    assert_equal false, calls.first[:display_context]
    assert_equal false, calls.first[:display_links]
  end

  def test_class_for_type
    media_type = 'http://data.bioontology.org/metadata/Category'
    type_cls = LinkedData::Client::Base.class_for_type(media_type)
    assert_equal LinkedData::Client::Models::Category, type_cls
  end

  def test_find_by
    bro = TestOntology.find_by_acronym('BRO')
    assert bro.length >= 1
    assert(bro.any? { |o| o.acronym.eql?('BRO') })

    onts = TestOntology.find_by_hasDomain_and_doNotUpdate('https://data.bioontology.org/categories/Health', true)
    assert onts.length >= 1

    onts = TestOntology.find_by_hasDomain_and_hasDomain('https://data.bioontology.org/categories/Phenotype', 'https://data.bioontology.org/categories/Human')
    assert onts.length >= 1
  end

  def test_where
    onts = TestOntology.where { |o| o.name.downcase.start_with?('c') }
    assert onts.length >= 1
  end

  def test_find
    ont = TestOntology.find('https://data.bioontology.org/ontologies/SNOMEDCT')
    refute_nil ont
  end

  def test_get
    ont = TestOntology.get('https://data.bioontology.org/ontologies/SNOMEDCT')
    refute_nil ont
    assert_instance_of LinkedData::Client::Models::Ontology, ont
    assert_equal 'https://data.bioontology.org/ontologies/SNOMEDCT', ont.id
    assert_equal 'SNOMEDCT', ont.acronym

    ont = TestOntology.get('SNOMEDCT')
    refute_nil ont
    assert_instance_of LinkedData::Client::Models::Ontology, ont
    assert_equal 'https://data.bioontology.org/ontologies/SNOMEDCT', ont.id
    assert_equal 'SNOMEDCT', ont.acronym
  end
end
