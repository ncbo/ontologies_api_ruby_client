require 'digest/sha1'
require 'active_support/cache'
require 'lz4_flex'
require_relative '../http'

module Faraday
  class ObjectCacheResponse < Faraday::Response
    attr_accessor :parsed_body
  end

  ##
  # This middleware causes Faraday to return an actual object instead of a response
  # This is done so that the object is cached instead of the unparsed json body.
  # Otherwise, we have to re-parse the json on every cache hit, which is extrememly costly
  # when compared to unmarshaling an object.
  class ObjectCache < Faraday::Middleware
    def initialize(app, *arguments)
      super(app)

      if arguments.last.is_a? Hash
        options = arguments.pop
        @logger = options.delete(:logger)
      else
        options = arguments
      end

      @store = options[:store] || ActiveSupport::Cache.lookup_store(store, options)
    end

    def call(env)
      invalidate_cache = env[:request_headers].delete(:invalidate_cache)

      # Add if newer than last modified statement to headers
      request_key = cache_key_for(create_request(env))
      last_modified_key = "LM::#{request_key}"
      last_retrieved_key = "LR::#{request_key}"

      # If we invalidate the cache, then it forces a clean request
      if invalidate_cache
        cache_delete(request_key)
        cache_delete(last_modified_key)
        cache_delete(last_retrieved_key)
        env[:request_headers]["Cache-Control"] = "no-cache"
        puts "Invalidated key #{request_key}" if enable_debug(request_key)
      end

      # If we made the last request within the expiry
      if cache_exist?(last_retrieved_key) && cache_exist?(request_key)
        puts "Not expired: #{env[:url].to_s}, key #{request_key}" if enable_debug(request_key)
        cached_item = cache_read(request_key)
        ld_obj = cached_item.is_a?(Hash) && cached_item.key?(:ld_obj) ? cached_item[:ld_obj] : cached_item
        env[:status] = 304
        cached_response = ObjectCacheResponse.new(env)
        cached_response.parsed_body = ld_obj
        return cached_response
      end

      last_modified = cache_read(last_modified_key)
      headers = env[:request_headers]
      puts "last modified: " + last_modified.to_s if last_modified && enable_debug(request_key)
      headers['If-Modified-Since'] = last_modified if last_modified

      @app.call(env).on_complete do |response_env|
        # Only cache get and head requests
        if [:get, :head].include?(response_env[:method])
          puts "Response status for key #{request_key}: " + response_env[:status].to_s if enable_debug(request_key)
          last_modified = response_env[:response_headers]["Last-Modified"]
          # Generate key using header hash
          key = request_key

          # If the last retrieve time is less than expiry
          if response_env[:status] == 304 && cache_exist?(key)
            stored_obj = cache_read(key)

            # Update if last modified is different
            if stored_obj[:last_modified] != last_modified
              puts "Updating cache #{response_env[:url].to_s}, key #{request_key}" if enable_debug(request_key)
              stored_obj[:last_modified] = last_modified
              cache_write(last_modified_key, last_modified)
              cache_write(key, stored_obj)
            end

            ld_obj = stored_obj[:ld_obj]
          else
            if response_env[:body].nil? || response_env[:body].empty?
              # We got here with an empty body, meaning the object wasn't
              # in the cache (weird). So re-do the request.
              puts "REDOING REQUEST, NO CACHE ENTRY for #{response_env[:url].to_s}, key #{request_key}" if enable_debug(request_key)
              env[:request_headers].delete("If-Modified-Since")
              response_env = @app.call(env).env
              puts "REDOING REQUEST expiry: #{response_env[:response_headers]["Cache-Control"]}, last_modified: #{last_modified} for key #{request_key}" if enable_debug(request_key)
            end

            ld_obj = LinkedData::Client::HTTP.object_from_json(response_env[:body])
            # This stmt was missing in the old code, resulting in repeated calls to REST because object failed to cache
            last_modified = response_env[:response_headers]["Last-Modified"]
            expiry = response_env[:response_headers]["Cache-Control"].to_s.split("max-age=").last.to_i
            puts "Before storing object: expiry: #{expiry}, last_modified: #{last_modified} for key #{request_key}" if enable_debug(request_key)

            if expiry > 0 && last_modified
              # This request is cacheable, store it
              puts "Storing object: #{response_env[:url].to_s}, key #{request_key}" if enable_debug(request_key)
              stored_obj = {last_modified: last_modified, ld_obj: ld_obj}
              cache_write(last_modified_key, last_modified)
              cache_write(last_retrieved_key, true, expires_in: expiry)
              cache_write(key, stored_obj)
            end
          end

          response = ObjectCacheResponse.new(response_env)
          response.parsed_body = ld_obj
          return response
        end
      end
    end

    private

    def enable_debug(key)
      return true if LinkedData::Client.settings.debug_client && (LinkedData::Client.settings.debug_client_keys.empty? || LinkedData::Client.settings.debug_client_keys.include?(key))
      false
    end

    def cache_write(key, obj, *args)
      begin
        result = @store.write(key, obj, *args)
      rescue
        puts "Key too large for cache_write: #{key}" if enable_debug(key)
        result = nil
      end

      if result
        return result
      else
        # This should still get stored in memcache
        # keep it in memory, though, because
        # marshal/unmarshal is too slow.
        # This way memcache will act as a backup
        # and you load from there if it isn't
        # in memory yet.
        @large_object_cache ||= {}
        @large_object_cache[key] = obj
        cache_write_compressed(key, obj, *args)
        return true
      end
    end

    def cache_read(key)
      obj = @store.read(key)
      return if obj.nil?
      if obj.is_a?(CompressedMemcache)
        # Try to get from the large object cache
        large_obj = @large_object_cache[key] if @large_object_cache
        # Fallback to the memcache version
        large_obj ||= cache_read_compressed(key)
        obj = large_obj
      end
      obj.dup
    end

    def cache_exist?(key)
      @store.exist?(key)
    end

    class CompressedMemcache; attr_accessor :key; end

    ##
    # Compress cache entry
    def cache_write_compressed(key, obj, *args)
      # Keep the size-prefixed block format used by existing cache entries.
      compressed = Lz4Flex::VarInt.compress(Marshal.dump(obj))
      placeholder = CompressedMemcache.new
      placeholder.key = "#{key}::#{(Time.now.to_f * 1000).to_i}::LZ4"
      begin
        @store.write(key, placeholder)
        @store.write(placeholder.key, compressed)
      rescue
        puts "Key that failed to cache in cache_write_compressed: #{key}" if enable_debug(key)
        @store.delete(key)
        @store.delete(placeholder.key)
      end
    end

    ##
    # Read compressed cache entry
    def cache_read_compressed(key)
      obj = @store.read(key)
      if obj.is_a?(CompressedMemcache)
        begin
          uncompressed = Lz4Flex::VarInt.decompress(@store.read(obj.key))
          obj = Marshal.load(uncompressed)
        rescue StandardError => e
          # There is a problem with the stored value, let's remove it so we don't get the error again
          @store.delete(key)
          @store.delete(obj.key)
          raise e
        end
      end
      obj
    end

    def cache_delete(key)
      @store.delete(key)
    end

    # Internal: Generates a String key for a given request object.
    # The request object is folded into a sorted Array (since we can't count
    # on hashes order on Ruby 1.8), encoded as JSON and digested as a `SHA1`
    # string.
    #
    # Returns the encoded String.
    def cache_key_for(request)
      array = request.stringify_keys.to_a.sort
      Digest::SHA1.hexdigest(Marshal.dump(array))
    end

    # Internal: Creates a new 'Hash' containing the request information.
    #
    # env - the environment 'Hash' from the Faraday stack.
    #
    # Returns a 'Hash' containing the ':method', ':url' and 'request_headers'
    # entries.
    def create_request(env)
      request = env.to_hash.slice(:method, :url, :request_headers)
      request[:request_headers] = request[:request_headers].dup
      request
    end

    def clean_request_headers(request)
      request[:request_headers].delete("If-Modified-Since")
      request[:request_headers].delete("Expect")
      request
    end

  end
end

if Faraday.respond_to?(:register_middleware)
  Faraday.register_middleware object_cache: Faraday::ObjectCache
elsif Faraday::Middleware.respond_to?(:register_middleware)
  Faraday::Middleware.register_middleware object_cache: Faraday::ObjectCache
end
