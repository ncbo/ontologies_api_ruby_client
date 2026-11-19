# frozen_string_literal: true

require 'active_support'
require 'minitest/autorun'
require_relative '../lib/ontologies_api_client'
require_relative '../lib/ontologies_api_client/middleware/faraday-object-cache'

class FaradayObjectCacheTest < Minitest::Test
  def test_reads_entry_written_by_lz4_ruby
    expected = {
      last_modified: 'Fri, 01 Jan 2021 00:00:00 GMT',
      ld_obj: "Ontology label café\n" * 8
    }
    # Captured with LZ4.compress(Marshal.dump(expected)) from lz4-ruby 0.3.3.
    legacy_blob = File.binread(File.join(__dir__, 'fixtures', 'lz4-ruby-0.3.3-cache-entry.lz4'))

    store = ActiveSupport::Cache::MemoryStore.new
    key = 'legacy-cache-entry'
    marker = Faraday::ObjectCache::CompressedMemcache.new
    marker.key = "#{key}::1609459200000::LZ4"
    store.write(key, marker)
    store.write(marker.key, legacy_blob)

    middleware = Faraday::ObjectCache.new(nil, store: store)
    assert_equal expected, middleware.send(:cache_read, key)
  end

  def test_writes_compressed_entry_in_varint_format
    payload = { ld_obj: "Ontology label café\n" * 8 }
    store = ActiveSupport::Cache::MemoryStore.new
    middleware = Faraday::ObjectCache.new(nil, store: store)
    key = 'new-cache-entry'

    middleware.send(:cache_write_compressed, key, payload)

    marker = store.read(key)
    assert_instance_of Faraday::ObjectCache::CompressedMemcache, marker
    blob = store.read(marker.key)
    assert_instance_of String, blob
    assert_equal Marshal.dump(payload), Lz4Flex::VarInt.decompress(blob)
  end
end
