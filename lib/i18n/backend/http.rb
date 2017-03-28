require 'i18n'
require 'i18n/backend/transliterator'
require 'i18n/backend/base'
require 'i18n/backend/http/version'
require 'i18n/backend/http/etag_http_client'
require 'i18n/backend/http/lru_cache'
require 'socket'

module I18n
  module Backend
    class Http
      include ::I18n::Backend::Base
      FAILED_GET = {}.freeze

      def initialize(options)
        @options = {
          http_open_timeout: 1,
          http_read_timeout: 1,
          polling_interval: 10*60,
          cache: nil,
          poll: true,
          exception_handler: -> (e) { $stderr.puts e },
          memory_cache_size: 10,
        }.merge(options)

        @http_client   = EtagHttpClient.new(@options)
        @translations  = LRUCache.new(@options[:memory_cache_size])
        @statsd_client = @options[:statsd_client]

        start_polling if @options[:poll]
      end

      def available_locales
        @translations.keys.map(&:to_sym).select { |l| l != :i18n }
      end

      def stop_polling
        @stop_polling = true
      end

      protected

      def start_polling
        Thread.new do
          until @stop_polling
            sleep(@options.fetch(:polling_interval))
            update_caches
          end
        end
      end

      def lookup(locale, key, scope = [], options = {})
        key = ::I18n.normalize_keys(locale, key, scope, options[:separator])[1..-1].join('.')
        lookup_key translations(locale), key
      end

      def translations(locale)
        (@translations[locale] ||= fetch_and_update_cached_translations(locale, nil, update: false)).first
      end

      def fetch_and_update_cached_translations(locale, old_etag, update:)
        if cache = @options.fetch(:cache)
          key = cache_key(locale)
          interval = @options.fetch(:polling_interval)
          now = Time.now # capture time before we do slow work to stay on schedule
          old_value, old_etag, expires_at = cache.read(key) # assumes the cache is more recent then our local storage

          if old_value && (!update || expires_at > now || !updater?(cache, key, interval))
            return [old_value, old_etag]
          end

          new_value, new_etag = download_translations(locale, etag: old_etag)
          new_expires_at = now + interval
          cache.write(key, [new_value, new_etag, new_expires_at])
          [new_value, new_etag]
        else
          download_translations(locale, etag: old_etag)
        end
      end

      # sync with the cache who is going to update the cache
      # this overlaps with the expiration interval, so worst case we will get 2x the interval
      # if all servers are in sync and check updater at the same time
      def updater?(cache, key, interval)
        cache.write(
          "#{key}-lock",
          true,
          expires_in: interval,
          unless_exist: true
        )
      end

      # when download fails we keep our old caches since they are most likely better then nothing
      def update_caches
        @translations.keys.each do |locale|
          _, old_etag = @translations[locale]
          result = fetch_and_update_cached_translations(locale, old_etag, update: true)
          if result && result.first != self.class::FAILED_GET
            @translations[locale] = result
          end
        end
      end

      def cache_key(locale)
        "i18n/backend/http/translations/#{locale}/v2"
      end

      def download_translations(locale, etag:)
        result, etag = @http_client.download(path(locale), etag: etag)
        [parse_response(result), etag] if result
      rescue => e
        @options.fetch(:exception_handler).call(e)
        [self.class::FAILED_GET, nil]
      end

      def parse_response(body)
        raise "implement parse_response"
      end

      def path(locale)
        raise "implement path"
      end

      # hook for extension with other resolution method
      def lookup_key(translations, key)
        translations[key]
      end
    end
  end
end
