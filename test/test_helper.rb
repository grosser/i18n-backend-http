require 'bundler'
Bundler.setup

require 'test/unit'
require 'shoulda'
require 'mocha'
require 'vcr'
require 'redgreen'

VCR.configure do |c|
  c.cassette_library_dir = 'test/fixtures/vcr'
  c.hook_into :webmock
end

$LOAD_PATH.unshift 'lib'
require 'i18n/backend/http'
require 'i18n/backend/simple' # is used when I18n first starts
require 'json'
