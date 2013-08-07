$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
name = "i18n-backend-http"
require "i18n/backend/http/version"

Gem::Specification.new(name, I18n::Backend::Http::VERSION) do |s|
  s.summary = "Rails I18n Backend for Http APIs with etag-aware background polling and memory+[memcache] caching"
  s.authors = ["Michael Grosser"]
  s.email = "michael@grosser.it"
  s.homepage = "http://github.com/grosser/#{name}"
  s.files = `git ls-files lib`.split("\n")
  s.license = 'MIT'
  s.add_runtime_dependency "i18n"
  s.add_runtime_dependency "gem_of_thrones"
  s.add_runtime_dependency "faraday"
end
