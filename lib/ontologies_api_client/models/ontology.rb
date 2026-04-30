# frozen_string_literal: true

require 'cgi'
require_relative '../base'

module LinkedData
  module Client
    module Models
      class Ontology < LinkedData::Client::Base
        include LinkedData::Client::Collection
        include LinkedData::Client::ReadWrite

        @media_type = 'http://data.bioontology.org/metadata/Ontology'
        @include_attrs = 'all'

        def flat?
          self.flat
        end

        def private?
          viewingRestriction && viewingRestriction.downcase.eql?('private')
        end

        def licensed?
          viewingRestriction && viewingRestriction.downcase.eql?('licensed')
        end

        def viewing_restricted?
          private? || licensed?
        end

        def view?
          viewOf && viewOf.length > 1
        end

        def purl
          if self.acronym
            "#{LinkedData::Client.settings.purl_prefix}/#{acronym}"
          else
            ''
          end
        end

        def access?(user)
          return true if !viewing_restricted?
          return false if user.nil?
          return true if user.admin?
          return self.full_acl.any? { |u| u == user.id }
        end

        def admin?(user)
          return false if user.nil?
          return true if user.admin?
          return administeredBy.any? { |u| u == user.id }
        end

        # ACL with administrators
        def full_acl
          ((self.acl || []) + self.administeredBy).uniq
        end

        # For use with select lists, always includes the admin by default
        def acl_select
          select_opts = []
          self.full_acl.each do |userId|
            select_opts << [User.get(userId).username, userId]
          end
          select_opts
        end

        ##
        # Method to get the property tree for a given ontology
        # Gets the properties from the REST API and then returns a tree
        def property_tree
          properties = Hash[self.explore.properties.map { |p| [p.id, p] }]
          properties.each_key do |key|
            prop = properties[key]
            prop.parents.each { |par| properties[par].children << prop if properties[par] }
          end
          roots = properties.values.select { |p| p.parents.empty? }
          root = LinkedData::Client::Models::Property.new
          root.children = roots
          root
        end

        ##
        # Find a resource by a combination of attributes
        # Override to search for views as well by default
        # Views get hidden on the REST service unless the `include_views`
        # parameter is set to `true`
        def self.find_by(attrs, *args)
          params = args.shift
          if params.is_a?(Hash)
            params[:include_views] = params[:include_views] || true
          else
            # Stick params back and create a new one
            args.push({ include_views: true })
          end
          args.unshift(params)
          super(attrs, *args)
        end

        ##
        # Find a resource by id
        # Override to search for views as well by default
        # Views get hidden on the REST service unless the `include_views`
        # parameter is set to `true`
        def self.find(id, params = {})
          params[:include_views] = params[:include_views] || true
          super(id, params)
        end

        def self.find_by_acronym(acronym, params = {})
          [find(acronym, params)]
        end

        ##
        # Include parameters commonly used with ontologies
        def self.include_params
          'acronym,administeredBy,group,hasDomain,name,notes,projects,reviews,summaryOnly,viewingRestriction'
        end
      end
    end
  end
end
