require 'oj'
require 'multi_json'
require 'digest'
require 'ostruct'

##
# This monkeypatch makes OpenStruct act like Struct objects
class OpenStruct
  alias :each :each_pair

  def member?(key)
    @table.key?(key)
  end

  def members
    @table.keys
  end

  def length
    @table.keys.length
  end

  alias :size :length

  def to_a
    @table.to_a
  end

  def values
    @table.values
  end

  def values_at(*selectors)
    @table.values.values_at(*selectors)
  end
end

module LinkedData
  module Client
    module HTTP
      $DEBUG_API_CLIENT ||= false

      class Link < String
        attr_accessor :media_type;
      end

      def self.conn
        unless LinkedData::Client.connection_configured?
          if Kernel.const_defined?('Rails')
            rails = Kernel.const_get('Rails')
            store = rails.cache if rails.cache
          end
          LinkedData::Client.config_connection(cache_store: store)
        end
        LinkedData::Client.settings.conn
      end

      def self.get(path, params = {}, options = {})
        headers = options[:headers] || {}
        raw = options[:raw] || false # return the unparsed body of the request
        params = params.delete_if { |k, v| v.nil? || v.to_s.empty? }
        params[:ncbo_cache_buster] = Time.now.to_f if raw # raw requests don't get cached to ensure body is available
        invalidate_cache = params.delete(:invalidate_cache) || false

        begin
          puts "Getting: #{path} with #{params}" if $DEBUG_API_CLIENT
          begin
            response = conn.get do |req|
              req.url path
              req.params = params.dup
              req.options[:timeout] = 60
              req.headers.merge(headers)
              req.headers[:invalidate_cache] = invalidate_cache
            end
          rescue StandardError => e
            params = Faraday::Utils.build_query(params)
            path += '?' unless params.empty? || path.include?('?')
            raise e, "Problem retrieving:\n#{path}#{params}\n\nError: #{e.message}\n#{e.backtrace.join("\n\t")}"
          end

          raise Exception, "Problem retrieving:\n#{path}\n#{response.body}" if response.status >= 500

          if raw
            obj = response.body
          elsif response.respond_to?(:parsed_body) && response.parsed_body
            obj = response.parsed_body
            obj = obj.dup if obj.frozen?
          else
            obj = recursive_struct(load_json(response.body))
          end
        rescue StandardError => e
          puts "Problem getting #{path}" if $DEBUG_API_CLIENT
          raise e
        end
        obj
      end

      def self.get_batch(paths, params = {})
        responses = []
        if conn.in_parallel?
          conn.in_parallel do
            paths.each { |p| responses << conn.get(p, params) }
          end
        else
          responses = threaded_request(paths, params)
        end
        responses
      end

      def self.post(path, obj, options = {})
        file, file_attribute = params_file_handler(obj)
        response = conn.post do |req|
          req.url path
          custom_req(obj, file, file_attribute, req)
        end
        raise StandardError, response.body if response.status >= 500

        if options[:raw] || false # return the unparsed body of the request
          response.body
        else
          recursive_struct(load_json(response.body))
        end
      end

      def self.put(path, obj)
        file, file_attribute = params_file_handler(obj)
        response = conn.put do |req|
          req.url path
          custom_req(obj, file, file_attribute, req)
        end
        raise StandardError, response.body if response.status >= 500

        recursive_struct(load_json(response.body))
      end

      def self.patch(path, obj)
        file, file_attribute = params_file_handler(obj)
        response = conn.patch do |req|
          req.url path
          custom_req(obj, file, file_attribute, req)
        end
        raise StandardError, response.body if response.status >= 500

        response
      end

      def self.object_from_json(json)
        recursive_struct(load_json(json))
      end

      def self.delete(path, params = {}, options = {})
        headers = options[:headers] || {}
        raw = options[:raw] || false # return response.body (string)
        parse = options[:parse] || false # return parsed object (similar to 'get')

        params = (params || {}).dup
        params = params.delete_if { |k, v| v.nil? || v.to_s.empty? }

        begin
          puts "Deleting #{path} with #{params}" if $DEBUG_API_CLIENT
          response = conn.delete do |req|
            req.url path
            req.params = params.dup
            req.options[:timeout] = options[:timeout] || 60
            req.headers.merge!(headers)
          end
        rescue StandardError => e
          query  = Faraday::Utils.build_query(params)
          pretty = path.dup
          pretty += '?' unless query.empty? || pretty.include?('?')
          raise e, "Problem deleting:\n#{pretty}#{query}\n\nError: #{e.message}\n#{e.backtrace.join("\n\t")}"
        end

        raise StandardError, response.body if response.status >= 500

        if raw
          response.body
        elsif parse
          if response.respond_to?(:parsed_body) && response.parsed_body
            obj = response.parsed_body
            obj = obj.dup if obj.frozen?
          else
            obj = recursive_struct(load_json(response.body))
          end
          obj
        else
          response  # backward compatibility preserved
        end
      end

      private

      def self.custom_req(obj, file, file_attribute, req)
        req.headers['Content-Type'] = 'application/json'

        if file
          # multipart
          boundary = 'OntologiesAPIMultipartPost'
          req.headers['Content-Type'] = "multipart/mixed; boundary=#{boundary}; type=application/json; start=json"
          parts = []
          parts << Faraday::Parts::Part.new(boundary, "json\"\r\nContent-Type: \"application/json; charset=UTF-8", MultiJson.dump(obj))
          parts << Faraday::Parts::Part.new(boundary, file_attribute, file)
          parts << Faraday::Parts::EpiloguePart.new(boundary)
          req.body = Faraday::CompositeReadIO.new(parts)
          req.headers['Content-Length'] = req.body.length.to_s
        else
          # normal
          req.body = MultiJson.dump(obj)
        end

        true
      end

      def self.params_file_handler(params)
        return if params.nil?

        file, return_attribute = nil, nil
        params.dup.each do |attribute, value|
          next unless value.is_a?(File) || value.is_a?(Tempfile) || value.is_a?(ActionDispatch::Http::UploadedFile)

          filename = value.original_filename
          file = Faraday::UploadIO.new(value.path, 'text/plain', filename)
          return_attribute = attribute
          params.delete(attribute)
        end
        return file, return_attribute
      end

      def self.threaded_request(paths, params)
        threads = []
        responses = []
        paths.each do |path|
          threads << Thread.new do
            responses << get(path, params)
          end
        end
        threads.join
        responses
      end

      def self.recursive_struct(json_obj)
        # TODO: Convert dates to date objects
        if json_obj.is_a?(Hash)
          return if json_obj.empty?

          value_cls = LinkedData::Client::Base.class_for_type(json_obj['@type'])
          links = prep_links(json_obj) # strip links
          context = json_obj.delete('@context') # strip context

          # Create a struct with the left-over attributes to store data
          attributes = json_obj.keys.map { |k| k.to_sym }
          attributes_always_present = value_cls.attrs_always_present || [] rescue []
          attributes = (attributes + attributes_always_present).uniq

          # Add attributes to instance
          if value_cls
            instance = value_cls.new
            attributes.each do |attr|
              attr = attr[1..-1] if attr[0].eql?('@')
              instance.class.class_eval do
                unless method_defined?(attr.to_sym)
                  define_method attr.to_sym do
                    instance_variable_get("@#{attr}")
                  end
                end
                unless method_defined?("#{attr}=")
                  define_method "#{attr}=" do |val|
                    instance_variable_set("@#{attr}", val)
                  end
                end
              end
            end

            # Create objects for each key/value pair, recursively
            json_obj.each do |attr, value|
              attr = attr[1..-1] if attr[0].eql?('@')
              instance.instance_variable_set("@#{attr}", recursive_struct(value))
            end
          else
            # Get the struct class
            recursive_obj_hash = { links: nil, context: nil }
            json_obj.each do |key, value|
              recursive_obj_hash[key] = recursive_struct(value)
            end
            instance = OpenStruct.new(recursive_obj_hash)
          end

          # Assign links/context
          instance.links = links if links
          instance.context = context if context
        elsif json_obj.is_a?(Array)
          instance = []
          json_obj.each do |value|
            instance << recursive_struct(value)
          end
        else
          instance = value_cls ? value_cls.new(values: json_obj) : json_obj
        end
        instance
      end

      def self.prep_links(obj)
        links = obj.delete(LinkedData::Client.settings.links_attr)
        return if links.nil?

        context = links.delete('@context')
        return if context.nil?

        links.keys.each do |link_type|
          link = Link.new(links[link_type])
          link.media_type = context[link_type]
          links[link_type] = link
        end
        links
      end

      def self.load_json(json)
        return if json.nil? || json.empty?

        begin
          MultiJson.load(json)
        rescue Exception => e
          raise e, "Problem loading json\n#{json}"
        end
      end

      def self.dump_json(json)
        MultiJson.dump(json)
      end
    end
  end
end
