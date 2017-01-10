require 'bundler/setup'

require 'single_cov'
SingleCov.setup :minitest

require 'maxitest/autorun'
require 'mocha/mini_test'
require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'test/fixtures/vcr'
  c.hook_into :webmock
end

$LOAD_PATH.unshift 'lib'
require 'i18n/backend/http'
require 'i18n/backend/simple' # is used when I18n first starts
require 'json'
require 'webmock/minitest'

I18n.enforce_available_locales = false
