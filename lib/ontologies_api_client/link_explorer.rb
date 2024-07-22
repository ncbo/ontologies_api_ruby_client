require 'addressable/uri'
require_relative 'http'

module LinkedData
  module Client
    class LinkExplorer
      HTTP = LinkedData::Client::HTTP

      def initialize(links, instance)
        @links = links
        @instance = instance
      end

      def method_missing(meth, *args, &block)
        if combined_links.key?(meth.to_s)
          explore_link(meth, *args)
        elsif meth == :batch
          explore_link(args)
        else
          super
        end
      end

      def respond_to?(meth, private = false)
        if combined_links.key?(meth.to_s) || meth == :batch
          return true
        else
          super
        end
      end

      def explore_link(*args)
        link = combined_links[args.shift.to_s]
        params = args.shift
        unless params.is_a?(Hash)
          args.push(params)
          params = {}
        end
        replacements = args.shift
        full_attributes = params.delete(:full)
        if link.is_a?(Array)
          value_cls = LinkedData::Client::Base.class_for_type(link.first.media_type)
          ids = link.map {|l| l.to_s}
          value_cls.where {|o| ids.include?(o.id)}
        else
          url = replace_template_elements(link.to_s, replacements)
          value_cls = LinkedData::Client::Base.class_for_type(link.media_type)
          params[:include] ||= value_cls.attributes(full_attributes)
          HTTP.get(url, params)
        end
      end

      def combined_links
        linkable_attributes.merge(@links)
      end

      private

      def replace_template_elements(url, values = [])
        return url if values.nil? || values.empty?

        values = values.dup
        values = [values] unless values.is_a?(Array)
        escaped_value = Addressable::URI.encode_component(values.shift, Addressable::URI::CharacterClasses::UNRESERVED)
        if url.match(/(\{.*?\})/)
          url.gsub(/(\{.*?\})/) do
            escaped_value
          end
        else
          url + '/' + escaped_value
        end

      end

      def linkable_attributes
        linkable = {}
        (@instance.context || {}).each do |attr, val|
          next unless val.is_a?(Hash) && val["@id"]
          links = (@instance.send(attr.to_sym) || []).dup
          if links.is_a?(Array)
            new_links = []
            links.each do |link|
              link = HTTP::Link.new(link)
              link.media_type = val["@id"]
              new_links << link
            end
            links = new_links
          else
            links = HTTP::Link.new(links)
            links.media_type = val["@id"]
          end
          linkable[attr.to_s] = links
        end
        linkable
      end
    end
  end
end