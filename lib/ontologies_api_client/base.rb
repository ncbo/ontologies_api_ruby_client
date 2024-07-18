module LinkedData
  module Client
    class Base
      HTTP = LinkedData::Client::HTTP
      attr_writer :instance_values
      attr_accessor :context, :links

      class << self
        attr_accessor :act_as_media_type, :include_attrs, :include_attrs_full, :attrs_always_present
        def media_types
          Array(@media_type)
        end

        def media_type
          media_types.first
        end

      end

      ##
      # Passing full: true to explore methods will give you more attributes
      def self.attributes(full = false)
        if full && @include_attrs_full
          @include_attrs_full
        else
          @include_attrs
        end
      end

      def self.class_for_type(media_type)
        if defined? @media_type_class_map
          return @media_type_class_map[media_type]
        end
        @media_type_class_map = map_classes
        return @media_type_class_map[media_type]
      end

      def self.map_classes
        map = {}
        classes = LinkedData::Client::Models.constants.map {|c| LinkedData::Client::Models.const_get(c)}
        classes.each do |media_type_cls|
          next if map[media_type_cls] || !media_type_cls.respond_to?(:media_types) || !media_type_cls.ancestors.include?(LinkedData::Client::Base)
          media_type_cls.media_types.each do |type|
            next if map[type]
            map[type] = media_type_cls
          end
          media_type_cls.act_as_media_type.each {|mt| map[mt] = media_type_cls} if media_type_cls.act_as_media_type
        end
        return map
      end

      def initialize(options = {})
        values = options[:values]
        if values.is_a?(Hash) && !values.empty?
          create_attributes(values.keys)
          populate_attributes(values)
        end
        create_attributes(self.class.attrs_always_present || [])
      end

      def id
        @id
      end

      def type
        @type
      end

      ##
      # Retrieve a set of data using a link provided on an object
      # This instantiates an instance of this class and uses
      # method missing to determine which link to follow
      def explore
        LinkedData::Client::LinkExplorer.new(@links, self)
      end

      def to_hash
        dump = marshal_dump
        dump.keys.each do |k|
          next unless k.to_s[0].eql?("@")
          dump[k[1..-1].to_sym] = dump[k]
          dump.delete(k)
        end
        dump
      end
      alias :to_param :to_hash

      def to_jsonld
        HTTP.get(self.id, {}, {raw: true})
      end

      def marshal_dump
        Hash[self.instance_variables.map { |v| [v, self.instance_variable_get("#{v}")] }]
      end

      def marshal_load(data)
        data ||= {}
        create_attributes(data.keys)
        populate_attributes(data)
      end

      def method_missing(meth, *args, &block)
        if meth.to_s[-1].eql?("=")
          # This enables OpenStruct-like behavior for setting attributes that aren't defined
          attr = meth.to_s.chomp("=").to_sym
          create_attributes([attr])
          populate_attributes(attr => args.first)
        else
          nil
        end
      end

      def respond_to?(meth, private = false)
        true
      end

      def [](key)
        key = "@#{key}" unless key.to_s.start_with?("@")
        instance_variable_get(key)
      end

      def []=(key, value)
        create_attributes([key])
        populate_attributes({key.to_sym => value})
      end

      private

      def create_attributes(attributes)
        attributes.each do |attr|
          attr = attr.to_s[1..-1].to_sym if attr.to_s.start_with?("@")
          attr_exists = self.public_methods(false).include?(attr)
          unless attr_exists
            self.class.class_eval do
              define_method attr.to_sym do
                instance_variable_get("@#{attr}")
              end
              define_method "#{attr}=" do |val|
                instance_variable_set("@#{attr}", val)
              end
            end
          end
        end
      end

      def populate_attributes(hash)
        hash.each do |k,v|
          k = "@#{k}" unless k.to_s.start_with?("@")
          instance_variable_set(k, v)
        end
      end

    end
  end
end
