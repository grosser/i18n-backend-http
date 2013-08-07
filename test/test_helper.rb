require 'bundler/setup'
require 'minitest/spec'
require 'minitest/rg'
require 'minitest/autorun'
require 'mocha'
require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'test/fixtures/vcr'
  c.hook_into :webmock
end

$LOAD_PATH.unshift 'lib'
require 'i18n/backend/http'
require 'i18n/backend/simple' # is used when I18n first starts
require 'json'
