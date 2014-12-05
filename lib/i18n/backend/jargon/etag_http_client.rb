require 'faraday'

module I18n
  module Backend
    class Jargon
      class EtagHttpClient
        def initialize(options)
          @options = options
          @etags = {}
        end

        def download(path)
          @client ||= Faraday.new(@options[:host])
          response = @client.get(path) do |request|
            request.headers["If-None-Match"] = @etags[path] if @etags[path]
            request.headers["Accept"] = 'application/json'
            request.options[:timeout] = @options[:http_read_timeout]
            request.options[:open_timeout] = @options[:http_open_timeout]
          end

          @etags[path] = response['ETag']

          case response.status
            when 200 then yield response.body
            when 304
            else
              raise "Failed request: #{response.inspect}"
          end
        end
      end
    end
  end
end
