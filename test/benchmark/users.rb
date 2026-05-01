# frozen_string_literal: true

require 'benchmark'
require 'json'
require 'net/http'
require 'optparse'
require 'uri'

$stdout.sync = true

ENV['UT_APIKEY'] ||= 'manual-timing'

require_relative '../../lib/ontologies_api_client'
require_relative '../../config/config'

options = { pagesize: 5_000 }
OptionParser.new do |opts|
  opts.banner = 'Usage: ruby test/benchmark/users.rb [--page=N] [--pagesize=M]'
  opts.on('--page=N', Integer, 'Single-page mode: fetch one page (skips all-pages walk)') { |v| options[:page] = v }
  opts.on('--pagesize=M', Integer, "Page size (default: #{options[:pagesize]})") { |v| options[:pagesize] = v }
end.parse!

def users_uri(params = {})
  uri = URI.join(LinkedData::Client.settings.rest_url.chomp('/') + '/', 'users')
  uri.query = URI.encode_www_form(params)
  uri
end

def get_json(uri)
  request = Net::HTTP::Get.new(uri)
  request['Accept'] = 'application/json'
  request['Authorization'] = "apikey token=#{LinkedData::Client.settings.apikey}"
  request['User-Agent'] = "NCBO API Ruby Client v#{LinkedData::Client::VERSION}"

  Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
    http.request(request)
  end
end

def summarize_json(body)
  parsed = JSON.parse(body)

  if parsed.is_a?(Array)
    { shape: 'array', count: parsed.length }
  elsif parsed.is_a?(Hash) && parsed['collection'].is_a?(Array)
    {
      shape: 'page',
      count: parsed['collection'].length,
      page: parsed['page'],
      page_count: parsed['pageCount'],
      total_count: parsed['totalCount'],
      next_page: parsed['nextPage']
    }
  else
    { shape: parsed.class.name }
  end
rescue JSON::ParserError => e
  { shape: 'unparseable', error: e.message }
end

def time_raw(label, params)
  uri = users_uri(params)
  response = nil

  elapsed = Benchmark.realtime { response = get_json(uri) }

  summary = summarize_json(response.body)
  puts "\n#{label}"
  puts "  uri: #{uri}"
  puts "  status: #{response.code}"
  puts "  elapsed: #{format('%.3f', elapsed)}s"
  puts "  bytes: #{response.body.bytesize}"
  puts "  summary: #{summary}"
end

def time_raw_users_include_all
  time_raw('Raw GET /users?include=all (no pagination params)', include: 'all')
end

def time_raw_users_paged(page:, pagesize:)
  time_raw("Raw GET /users (page=#{page}, pagesize=#{pagesize}, include=all)",
           page: page, pagesize: pagesize, include: 'all')
end

def time_user_all
  users = nil

  elapsed = Benchmark.realtime do
    users = LinkedData::Client::Models::User.all
  end

  puts "\nLinkedData::Client::Models::User.all (auto-paginate, walks all pages)"
  puts "  elapsed: #{format('%.3f', elapsed)}s"
  puts "  class: #{users.class}"
  puts "  count: #{users.respond_to?(:length) ? users.length : 'n/a'}"
  puts "  first: #{users.first.username if users.respond_to?(:first) && users.first.respond_to?(:username)}"
end

def time_user_single_page(page:, pagesize:)
  result = nil

  elapsed = Benchmark.realtime do
    result = LinkedData::Client::Models::User.all(page: page, pagesize: pagesize)
  end

  puts "\nLinkedData::Client::Models::User.all(page: #{page}, pagesize: #{pagesize})"
  puts "  elapsed: #{format('%.3f', elapsed)}s"
  puts "  class: #{result.class}"
  if result.respond_to?(:collection)
    puts "  page: #{result.page} / #{result.pageCount}"
    puts "  total_count: #{result.totalCount}"
    puts "  collection.length: #{result.collection.length}"
    puts "  next_page: #{result.nextPage.inspect}"
    first = result.collection.first
    puts "  first: #{first.username if first.respond_to?(:username)}"
  else
    puts "  (response was not paged) preview: #{result.inspect[0, 200]}"
  end
end

puts "REST URL: #{LinkedData::Client.settings.rest_url}"

if options[:page]
  time_raw_users_paged(page: options[:page], pagesize: options[:pagesize])
  time_user_single_page(page: options[:page], pagesize: options[:pagesize])
else
  time_raw_users_include_all
  time_user_all
end
