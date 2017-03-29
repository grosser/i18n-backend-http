require 'faraday'

module I18n
  module Backend
    class Http
      class I18n::Backend::Http::EtagHttpClient
        STATS_NAMESPACE = 'i18n-backend-http.etag_client'.freeze

        def initialize(options)
          @options = options
        end

        def download(path, etag:)
          @client ||= Faraday.new(@options[:host])
          start     = Time.now

          response = @client.get(path) do |request|
            request.headers.merge!(@options[:headers]) if @options[:headers]
            request.headers["If-None-Match"] = etag if etag
            request.options[:timeout]        = @options[:http_read_timeout]
            request.options[:open_timeout]   = @options[:http_open_timeout]
          end

          tags = {status_code: response.status, path: path}

          record :timing, time: (Time.now - start).to_f * 1000, tags: tags

          case response.status
          when 200
            record :success, tags: tags
            [response.body, response['ETag']]
          when 304
            record :success, tags: tags
            nil
          else
            record :failure, tags: tags
            raise "Failed request: #{response.inspect}"
          end
        end

        private

        def record(event, options = {})
          return unless client = @options[:statsd_client]

          case event
          when :success
            client.increment("#{STATS_NAMESPACE}.success", tags: options[:tags])
          when :failure
            client.increment("#{STATS_NAMESPACE}.failure", tags: options[:tags])
          when :timing
            client.histogram("#{STATS_NAMESPACE}.request_time", options[:time], tags: options[:tags])
          else
            raise "Unknown statsd event type to record"
          end
        end
      end
    end
  end
end
