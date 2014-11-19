module I18n
  module Backend
    class Jargon
      class Configuration
        attr_accessor :host, :uuid, :http_open_timeout, :http_read_timeout, :polling_interval, :cache, :poll, :exception_handler, :memory_cache_size

        def initialize
          @host = "http://localhost/"
          @http_open_timeout = 1
          @http_read_timeout = 1
          @polling_interval = 10*60
          @cache = NullCache.new
          @poll = true
          @exception_handler = lambda{|e| $stderr.puts e }
          @memory_cache_size = 10
        end

        def [](value)
          self.public_send(value)
        end
      end

      def self.configure(&block)
        @config ||= Configuration.new
        block.call(@config) if block_given?
        raise ArgumentError if @config[:uuid].nil?
        @config
      end

      def config
        @config || configure
      end
    end
  end
end
