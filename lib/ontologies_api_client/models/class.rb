require 'addressable/uri'
require "uri"
require_relative "../base"

module LinkedData
  module Client
    module Models
      class Class < LinkedData::Client::Base
        HTTP = LinkedData::Client::HTTP
        @media_type = %w[http://www.w3.org/2002/07/owl#Class http://www.w3.org/2004/02/skos/core#Concept]
        @include_attrs = "prefLabel,definition,synonym,obsolete,hasChildren"
        @include_attrs_full = "prefLabel,definition,synonym,obsolete,properties,hasChildren,children"
        @attrs_always_present = :prefLabel, :definition, :synonym, :obsolete, :properties, :hasChildren, :children

        alias :fullId :id

        # triple store predicate is <http://www.w3.org/2002/07/owl#deprecated>
        def obsolete?
          self.obsolete
        end

        def prefLabel(options = {})
          if options[:use_html]
            if self.obsolete
              return "<span class='obsolete_class' title='obsolete class'>#{@prefLabel}</span>"
            else
              return "<span class='prefLabel'>#{@prefLabel}</span>"
            end
          else
            return @prefLabel
          end
        end

        # TODO: Implement properly
        def relation_icon(parent)
          return "" if self.explore.ontology.explore.latest_submission.nil?
          return "" unless self.explore.ontology.explore.latest_submission.hasOntologyLanguage.eql?("OBO")
          non_subclassOf_parent_rel = !self.subClassOf ||
              (self.subClassOf && (self.subClassOf.include?("http://www.w3.org/2002/07/owl#Thing") || self.subClassOf.include?(parent.id)))
          return "" if non_subclassOf_parent_rel
          " <span class='ui-icon ui-icon-info' style='display: inline-block !important; vertical-align: -4px; cursor: help;' title='The parent of this class is not defined with a subClassOf relationship'></span>"
        end

        def to_jsonld
          HTTP.get(self.links["self"], {}, {raw: true})
        end

        def purl
          return "" if self.links.nil?
          return self.id if self.id.include? LinkedData::Client.settings[:purl_host]

          ont = self.explore.ontology
          encoded_id = Addressable::URI.encode_component(self.id, Addressable::URI::CharacterClasses::UNRESERVED)
          "#{LinkedData::Client.settings.purl_prefix}/#{ont.acronym}?conceptid=#{encoded_id}"
        end

        def ontology
          self.explore.ontology
        end

        def self.find(id, ontology, params = {})
          ontology = HTTP.get(ontology, params)
          ontology.explore.single_class(id)
        end

        def self.search(*args)
          query = args.shift
          params = args.shift || {}
          params[:q] = query
          raise ArgumentError, "You must provide a search query: Class.search(query: 'melanoma')" if query.nil? || !query.is_a?(String)
          HTTP.post("/search", params)
        end

        def expanded?
          !self.children.nil? && self.children.length > 0
        end

      end
    end
  end
end
