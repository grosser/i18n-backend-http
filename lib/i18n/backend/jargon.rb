require 'i18n'
require 'i18n/backend/transliterator'
require 'i18n/backend/base'
require 'gem_of_thrones'
require 'i18n/backend/jargon/version'
require 'i18n/backend/jargon/etag_http_client'
require 'i18n/backend/jargon/null_cache'

module I18n
  module Backend
    class Jargon
      include ::I18n::Backend::Base

      def initialize(options)
        @config = {
          host: 'http://localhost',
          http_open_timeout: 1,
          http_read_timeout: 1,
          polling_interval: 10*60,
          cache: NullCache.new,
          poll: true,
          exception_handler: lambda{|e| $stderr.puts e },
          memory_cache_size: 10
          }.merge(options)
          raise ArgumentError if @config[:uuid].nil?
        end

        def initialized?
          @initialized ||= false
        end

        def stop_polling
          @stop_polling = true
        end

        def reload!
          @initialized  = false
          @translations = nil
        end

        def available_locales
          init_translations unless initialized?
          download_localization
          @available_locales
        end

        def locale_path(locale)
          localization_path + "/#{locale}"
        end

        def localization_path
          "api/uuid/#{@config[:uuid]}"
        end

        def translate(locale, key, options = {})
          raise InvalidLocale.new(locale) unless locale
          entry = key && lookup(locale, key, options[:scope], options)

          if options.empty?
            entry = resolve(locale, key, entry, options)
          else
            count, default = options.values_at(:count, :default)
            values         = options.except(*RESERVED_KEYS)
            entry          = entry.nil? && default ?
            default(locale, key, default, options) : resolve(locale, key, entry, options)
          end

          throw(:exception, I18n::MissingTranslation.new(locale, key, options)) if entry.nil?
          entry = entry.dup if entry.is_a?(String)

          entry = pluralize(locale, entry, count) if count
          entry = interpolate(locale, entry, values) if values
          entry
        end

        protected

        def init_translations
          @http_client  = EtagHttpClient.new(@config)
          @translations = {}
          start_polling if @config[:poll]
          @initialized = true
        end

        def start_polling
          Thread.new do
            until @stop_polling
              sleep(@config[:polling_interval])
              update_caches
            end
          end
        end

        def lookup(locale, key, scope = [], options = {})
          init_translations unless initialized?
          key = ::I18n.normalize_keys(locale, key, scope, options[:separator])[1..-1].join('.')
          lookup_key translations(locale), key
        end

        def resolve(locale, object, subject, options = {})
          return subject if options[:resolve] == false
          result = catch(:exception) do
            case subject
            when Symbol
              I18n.translate(subject, options.merge(:locale => locale, :throw => true))
            when Proc
              date_or_time = options.delete(:object) || object
              resolve(locale, object, subject.call(date_or_time, options))
            else
              subject
            end
          end
          result unless result.is_a?(MissingTranslation)
        end

        def translations(locale)
          download_and_cache_translations(locale)
          @translations[locale]
        end

        def update_caches
          @translations.keys.each do |locale|
            if @config[:cache].is_a?(NullCache)
              download_and_cache_translations(locale)
            else
              locked_update_cache(locale)
            end
          end
        end

        def locked_update_cache(locale)
          @aspirants ||= {}
          aspirant   = @aspirants[locale] ||= GemOfThrones.new(
            :cache     => @config[:cache],
            :timeout   => (@config[:polling_interval] * 3).ceil,
            :cache_key => "i18n/backend/http/locked_update_caches/#{locale}"
            )
          if aspirant.rise_to_power
            download_and_cache_translations(locale)
          else
            update_memory_cache_from_cache(locale)
          end
        end

        def update_memory_cache_from_cache(locale)
          @translations[locale] = translations_from_cache(locale)
        end

        def translations_from_cache(locale)
          @config[:cache].read(cache_key(locale))
        end

        def cache_key(locale)
          "i18n/backend/http/translations/#{locale}"
        end

        def download_and_cache_translations(locale)
          @http_client.download(locale_path(locale)) do |result|
            translations = parse_locale(result)
            @config[:cache].write(cache_key(locale), translations)
            @translations[locale] = translations
          end
          rescue => e
            @config[:exception_handler].call(e)
            @translations[locale] = {} # do not write distributed cache
        end

        def download_localization
          @http_client.download(localization_path) do |result|
            @available_locales = parse_localization(result)
          end
        end

        def parse_locale(body)
          j = JSON.load(body)['locale']['data']
          flat_hash(j).map{ |k,v| [k.sub(/\.$/, ''), v] }.to_h
        end

        def parse_localization(body)
          JSON.load(body)['localization']['available_locales']
        end

        def flat_hash(hash, k = '')
          return {k => hash} unless hash.is_a?(Hash)
          hash.inject({}){ |h, v| h.merge! flat_hash(v[-1], k +v[0].to_s + '.') }
        end

        # hook for extension with other resolution method
        def lookup_key(translations, key)
          translations[key]
        end
      end
    end
  end
