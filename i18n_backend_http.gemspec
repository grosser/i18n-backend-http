$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
name = "i18n_backend_http"
require "#{name}/version"

Gem::Specification.new name, I18nBackendHttp::VERSION do |s|
  s.summary = "Rails I18n Backend for Http APIs with etag-aware background polling and memory+[memcache] caching"
  s.authors = ["Michael Grosser"]
  s.email = "michael@grosser.it"
  s.homepage = "http://github.com/grosser/#{name}"
  s.files = `git ls-files`.split("\n")
  s.license = 'MIT'
end
