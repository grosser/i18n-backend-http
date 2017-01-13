require 'faraday'

module I18n
  module Backend
    class Http
      class I18n::Backend::Http::EtagHttpClient
        def initialize(options)
          @options = options
        end

        def download(path, etag:)
          @client ||= Faraday.new(@options[:host])
          response = @client.get(path) do |request|
            request.headers["If-None-Match"] = etag if etag
            request.options[:timeout] = @options[:http_read_timeout]
            request.options[:open_timeout] = @options[:http_open_timeout]
          end

          case response.status
          when 200 then [response.body, response['ETag']]
          when 304 then nil
          else
            raise "Failed request: #{response.inspect}"
          end
        end
      end
    end
  end
end
