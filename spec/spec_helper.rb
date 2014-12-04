require "codeclimate-test-reporter"
CodeClimate::TestReporter.start

require 'webmock/rspec'
require_relative '../lib/i18n/backend/jargon'
Dir["./spec/**/*.rb"].each { |f| require f }

I18n::Backend::Jargon.configure do |config|
  config.host = 'http://www.example.com'
  config.uuid = 'Test'
end

