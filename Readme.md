I18n-compatible backend for the [Jargon](cb-talent-development/jargon) localization engine.

Install
=======

    gem install i18n-backend-jargon

Usage
=====

```Ruby

require 'i18n/backend/jargon'

I18n::Backend::Jargon.configure do |config|
  config.host = "http://localhost:3000/"
  config.uuid = "61267710-4286-4db9-a074-3dd5ae9993c1"
end

I18n.backend = I18n::Backend::Jargon

```

### Polling
Tries to update all used translations every 10 minutes (using ETag and :cache), can be stopped via `I18n.backend.stop_polling`.<br/>
If a :cache is given, all backends pick one master to do the polling, all others refresh from :cache

```Ruby

require 'i18n/backend/jargon'

I18n::Backend::Jargon.configure do |config|
  config.host = "http://localhost:3000/"
  config.uuid = "61267710-4286-4db9-a074-3dd5ae9993c1"
  config.cache = Rails.cache
end

I18n.backend = I18n::Backend::Jargon

I18n.t('some.key') == "Old value"
# change in backend + wait 30 minutes
I18n.t('some.key') == "New value"
```

### :cache
If you pass `:cache => Rails.cache`, translations will be loaded from cache and updated in the cache.<br/>
The cache **MUST** support :unless_exist, so [gem_of_thrones](https://github.com/grosser/gem_of_thrones) can do its job,<br/>
MemCacheStore + LibmemcachedStore + ActiveSupport::Cache::MemoryStore (edge) work.

### Exceptions
To handle http exceptions provide e.g. `:exception_handler => lambda{|e| puts e }` (prints to stderr by default).

### Fallback
If the http backend is down, it does not translate, but also does not constantly try to query -> your app is untranslated but not down.</br>
You should either use :default for all I18n.t or use a Chain, so when http is down e.g. english is used.

```Ruby
I18n.backend = I18n::Backend::Chain.new(
  I18n::Backend::Jargon,
  I18n::Backend::Simple.new
)
```


Author
======
Colin Ewen

colin.ewen@careerbuilder.com

License: MIT

Forked from i18n-backend-http, created by

[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
