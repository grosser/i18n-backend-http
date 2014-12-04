require 'webmock/rspec'
require_relative '../lib/i18n/backend/jargon'

I18n::Backend::Jargon.configure do |config|
  config.host = 'http://www.example.com'
  config.uuid = 'Test'
end

