$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require "i18n/backend/jargon/version"

Gem::Specification.new(I18n::Backend::Jargon::VERSION) do |s|
  s.summary = "Rails I18n Backend for Http APIs with etag-aware background polling and memory+[memcache] caching"
  s.authors = ["Michael Grosser"]
  s.name = 'i18n-backend-jargon'
  s.version = I18n::Backend::Jargon::VERSION
  s.email = "michael@grosser.it"
  s.homepage = "http://github.com/grosser/"
  s.files = `git ls-files lib`.split("\n")
  s.license = 'MIT'
  s.add_runtime_dependency "i18n"
  s.add_runtime_dependency "gem_of_thrones"
  s.add_runtime_dependency "faraday"
end
