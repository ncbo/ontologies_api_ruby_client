# config.rb is required for testing
# unit test makes calls to bioportal api so it needs a valid API key which can
# be set via ENV variable UT_APIKEY
abort('env variable UT_APIKEY is not set. Canceling tests...') unless ENV.include?('UT_APIKEY')
abort('env variable UT_APIKEY set to empty value. Canceling tests') unless ENV['UT_APIKEY'].size > 5

LinkedData::Client.config do |config|
  config.rest_url   = 'https://data.bioontology.org'
  config.apikey     = ENV['UT_APIKEY']
#  config.apikey     = 'xxxxx-xxxxx-xxxxxxxxxx'
  config.links_attr = 'links'
  config.cache      = false
end
