require_relative 'config'
require_relative 'http'

module LinkedData
  module Client
    module Collection

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        PAGED_COLLECTION_SIZE = 5_000

        ##
        # Allows for arbitrary find_by methods. For example:
        #   Ontology.find_by_acronym("BRO")
        #   Ontology.find_by_group_and_category("UMLS", "Anatomy")
        def method_missing(meth, *args, &block)
          if meth.to_s =~ /^find_by_(.+)$/
            find_by($1, *args, &block)
          else
            super
          end
        end

        ##
        # Get all top-level links for the API
        def top_level_links(link = LinkedData::Client.settings.rest_url)
          @top_level_links ||= {}
          @top_level_links[link] ||= HTTP.get(link)
        end

        #
        # Return a link given an object (with links) and a media type
        def uri_from_context(object, media_type)
          object.links.each do |type, link|
            return link.dup if link.media_type && link.media_type.downcase.eql?(media_type.downcase)
          end
        end

        ##
        # Get the first collection of resources for a given type
        def entry_point(media_type, params = {})
          params = {include: @include_attrs}.merge(params)
          HTTP.get(uri_from_context(top_level_links, media_type), params)
        end

        ##
        # For a type that is already defined, get the collection path
        def collection_path
          uri_from_context(top_level_links, @media_type)
        end

        ##
        # Get all resources from the base collection for a resource
        def all(*args)
          params = args.shift || {}
          request_params = collection_request_params(params)
          response = entry_point(@media_type, request_params)

          return response if page_requested?(params) || !paged_collection?(response)

          all_pages(response, request_params)
        end

        ##
        # Get all resources from the base collection for a resource as a hash with resource ids as the keys
        def all_to_hash(*args)
          all = all(*args)
          Hash[all.map {|e| [e.id, e]}]
        end

        ##
        # Find certain resources from the collection by passing a block that filters results
        def where(params = {}, &block)
          if block_given?
            return all(params).select {|e| block.call(e)}
          else
            raise ArgumentError("Must provide a block to find items")
          end
        end

        # Find a resource by id
        #
        # @deprecated Use {#get} instead
        def find(id, params = {})
          get(id, params)
        end

        ##
        # Get a resource by id (this will retrieve it from the REST service)
        def get(id, params = {})
          path = collection_path
          id = "#{path}/#{id}" unless id.include?(path)
          HTTP.get(id, params)
        end

        ##
        # Find a resource by a combination of attributes
        def find_by(attrs, *args)
          attributes = attrs.split("_and_")
          values_to_find = args.slice!(0..attributes.length-1)
          params = args.shift
          unless params.is_a?(Hash)
            args.unshift(params)
            params = {}
          end
          where(params) do |obj|
            bools = []
            attributes.each_with_index do |attr, index|
              if obj.respond_to?(attr)
                value = obj.send(attr)
                if value.is_a?(Enumerable)
                  bools << value.include?(values_to_find[index])
                else
                  bools << (value == values_to_find[index])
                end
              end
            end
            bools.all?
          end
        end

        private

        def all_pages(first_page, params)
          collection = Array(first_page.collection)
          next_page = first_page.nextPage

          while next_page
            page = entry_point(@media_type, next_page_params(params, next_page))
            collection.concat(Array(page.collection))
            next_page = page.nextPage
          end

          collection
        end

        def collection_request_params(params)
          return params if page_requested?(params) || page_size_requested?(params)

          params.merge(pagesize: PAGED_COLLECTION_SIZE)
        end

        def next_page_params(params, page)
          page_params = params.dup
          page_params[page_params.key?("page") ? "page" : :page] = page
          page_params[:pagesize] = PAGED_COLLECTION_SIZE unless page_size_requested?(page_params)
          page_params
        end

        def page_requested?(params)
          params.key?(:page) || params.key?("page")
        end

        def page_size_requested?(params)
          params.key?(:pagesize) || params.key?("pagesize")
        end

        def paged_collection?(response)
          response.respond_to?(:collection) &&
            response.respond_to?(:pageCount) &&
            response.respond_to?(:nextPage) &&
            response.collection.is_a?(Array)
        end
      end
    end
  end
end
