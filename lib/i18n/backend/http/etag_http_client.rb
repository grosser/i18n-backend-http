require 'faraday'

module I18n
  module Backend
    class Http
      class I18n::Backend::Http::EtagHttpClient
        def initialize(options)
          @options = options
          @statsd_client = options[:statsd_client]
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

          record :timing, time: (Time.now - start).to_i, tags: {path: path}

          case response.status
          when 200
            record :success, tags: {status_code: response.status, path: path}
            [response.body, response['ETag']]
          when 304
            record :success, tags: {status_code: response.status, path: path}
            nil
          else
            record :failure, tags: {status_code: response.status, path: path}
            raise "Failed request: #{response.inspect}"
          end
        end

        private

        def record(event, options = {})
          return unless @statsd_client

          case event
          when :success
            @statsd_client.increment('i18n-backend-http.etag_client.success', tags: options[:tags])
          when :failure
            @statsd_client.increment('i18n-backend-http.etag_client.failure', tags: options[:tags])
          when :timing
            @statsd_client.histogram('i18n-backend-http.etag_client.request_time', options[:time], tags: options[:tags])
          end
        end
      end
    end
  end
end
