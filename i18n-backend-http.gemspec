name = "i18n-backend-http"
require "./lib/i18n/backend/http/version"

Gem::Specification.new(name, I18n::Backend::Http::VERSION) do |s|
  s.summary = "Rails I18n Backend for Http APIs with etag-aware background polling and memory+[memcache] caching"
  s.authors = ["Michael Grosser"]
  s.email = "michael@grosser.it"
  s.homepage = "https://github.com/grosser/#{name}"
  s.files = `git ls-files lib`.split("\n")
  s.license = 'MIT'
  s.add_runtime_dependency "i18n"
  s.add_runtime_dependency "faraday"
  s.add_development_dependency 'rake'
  s.add_development_dependency 'maxitest'
  s.add_development_dependency 'vcr', '~> 2.5'
  s.add_development_dependency 'webmock'
  s.add_development_dependency 'mocha'
  s.add_development_dependency 'wwtd'
  s.add_development_dependency 'json'
  s.add_development_dependency 'bump'
  s.add_development_dependency 'single_cov'
  s.add_development_dependency 'byebug'
  s.required_ruby_version = '>= 2.1.0'
end
