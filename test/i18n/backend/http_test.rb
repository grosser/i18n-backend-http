require_relative '../../test_helper'

SingleCov.covered! uncovered: 3
SingleCov.covered! file: 'lib/i18n/backend/http/etag_http_client.rb', uncovered: 1
SingleCov.covered! file: 'lib/i18n/backend/http/lru_cache.rb', uncovered: 1

describe I18n::Backend::Http do
  class SimpleCache
    def initialize
      @cache = {}
    end

    def read(key)
      @cache[key]
    end

    def write(key, value, options={})
      if !options[:unless_exist] || !@cache[key]
        @cache[key] = value
      end
    end
  end

  class ZenEnd < ::I18n::Backend::Http
    def initialize(options={})
      super({
        host: "https://support.zendesk.com",
      }.merge(options))
    end

    # TODO remove conversion
    def lookup(locale, key, scope = [], options = {})
      locale = locale.to_s[/\d+/].to_s

      # we only care about the id en-EN-x-ID, everything else could cause duplicate caches
      super(locale, key, scope, options)
    end

    def parse_response(body)
      JSON.load(body)["locale"]["translations"]
    end

    def path(locale)
      "/api/v2/locales/#{locale}.json?include=translations"
    end
  end

  def silence_backend
    $stderr.stubs(:puts)
  end

  def with_local_available
    VCR.use_cassette("simple") do
      yield
    end
  end

  def with_error
    VCR.use_cassette("error") do
      I18n.locale = "de_DE-x-888888888"
      yield
    end
  end

  def add_local_change
    ::I18n.backend.send(:translations, '8')[@key] = "OLD"
  end

  def update_caches
    I18n.backend.send(:update_caches)
  end

  let(:version) { '/v2' }

  describe I18n::Backend::Http do
    before do
      @existing_key = "txt.modal.welcome.browsers.best_support"
      @missing_key = "txt.blublublub"
      Thread.list.each { |thread| thread.exit unless thread == Thread.current } # stop all polling threads
    end

    after do
      I18n.backend && I18n.backend.respond_to?(:stop_polling) && I18n.backend.stop_polling
    end

    describe '#available_locales' do
      before do
        I18n.locale = "de_DE-x-8"
        I18n.backend = ZenEnd.new
      end

      it "supplies multiple available locales" do
        VCR.use_cassette("multiple_locales") do
          # ZenEnd loads locales on-demand: trigger ES and DE
          I18n.t(@existing_key)
          I18n.locale = "es_ES-x-2"
          I18n.t(@existing_key)
          assert_equal [:'8', :'2'], I18n.available_locales
        end
      end
    end

    describe "#translate" do
      before do
        I18n.locale = "de_DE-x-8"
        I18n.backend = ZenEnd.new
      end

      it "translate via api" do
        with_local_available do
          assert_equal "Am besten", I18n.t(@existing_key)
        end
      end

      it "translate via api and :scope" do
        with_local_available do
          assert_equal "Am besten", I18n.t("browsers.best_support", scope: "txt.modal.welcome")
        end
      end

      it "translate via :default" do
        with_local_available do
          assert_equal "XXX", I18n.t("txt.blublublub", default: "XXX")
        end
      end

      it "caches the locale" do
        with_local_available do
          assert_equal "Am besten", I18n.t(@existing_key)
          JSON.expects(:load).never
          assert_equal "By group", I18n.t("txt.admin.helpers.rules_helper.by_group_label")
        end
      end

      it "fail when key is unknown" do
        with_local_available do
          assert_equal "translation missing: de_DE-x-8.#{@missing_key}", I18n.t(@missing_key).gsub(', ', '.')
        end
      end

      it "fail when I mess up the host" do
        silence_backend
        I18n.backend = ZenEnd.new(host: "https://MUAHAHAHAHA.com")
        VCR.use_cassette("invalid_host") do
          assert_equal "translation missing: de_DE-x-8.#{@missing_key}", I18n.t(@missing_key).gsub(', ', '.')
        end
      end

      it "fail with invalid locale" do
        silence_backend
        with_error do
          assert_equal "translation missing: #{I18n.locale}.#{@existing_key}", I18n.t(@existing_key).gsub(', ', '.')
        end
      end

      it "call :exception_handler when error occurs" do
        exception = nil
        I18n.backend = ZenEnd.new(exception_handler: -> (e) { exception = e })
        $stderr.expects(:puts).never

        with_error do
          I18n.t(@existing_key).gsub(', ', '.')
        end

        assert_equal exception.class, RuntimeError
      end

      it "keep :memory_cache_size items in memory cache" do
        I18n.backend = ZenEnd.new(memory_cache_size: 1)

        VCR.use_cassette("multiple_locales") do
          assert_equal "Am besten", I18n.t(@existing_key)
          I18n.locale = "es-ES-x-2"
          assert_equal "Mejor", I18n.t(@existing_key)
        end

        assert_equal "Mejor", I18n.t(@existing_key) # still in memory

        I18n.locale = "de-DE-x-8"
        I18n.backend.expects(:download_translations).returns([{}, nil])
        I18n.t(@existing_key).must_include "translation missing" # dropped from memory -> fetch
      end

      it "pass along :headers" do
        I18n.backend = ZenEnd.new(headers: {"Host" => "pod6.zendesk.com"})

        VCR.use_cassette("custom_headers") do
          I18n.t(@existing_key)

          # Don't care about the URL, just want to check the headers
          assert_requested :get, /.*/, headers: {"Host" => "pod6.zendesk.com"}, times: 1
        end
      end

      describe "with :statsd_client present" do
        let(:statsd) { stub }

        before do
          I18n.backend = ZenEnd.new(headers: {"Host" => "pod6.zendesk.com"}, statsd_client: statsd)
        end

        it "reports on success" do
          VCR.use_cassette("simple") do
            statsd.stubs(:histogram)
            statsd.expects(:increment)

            I18n.t(@existing_key)
          end
        end

        it "reports on failure" do
          with_error do
            statsd.stubs(:histogram)
            statsd.expects(:increment).times(2) # once for the HTTP fail, once for the #download_translations failure

            I18n.t(@existing_key)
          end
        end

        it "reports request timing" do
          VCR.use_cassette("simple") do
            statsd.stubs(:increment)
            statsd.expects(:histogram)

            I18n.t(@existing_key)
          end
        end
      end

      describe 'retrying' do
        before do
          I18n.backend = ZenEnd.new(http_open_retries: 3, http_read_retries: 4)
        end

        it "retries specified number of times for an open timeout" do
          VCR.use_cassette("simple") do
            exception = Faraday::ConnectionFailed.new(Net::OpenTimeout.new)
            I18n::Backend::Http::EtagHttpClient.any_instance.expects(:download).times(4).raises(exception)

            I18n.t(@existing_key)
          end
        end

        it "retries specified number of times for a read timeout" do
          VCR.use_cassette("simple") do
            exception = Faraday::TimeoutError.new(Net::ReadTimeout.new)
            I18n::Backend::Http::EtagHttpClient.any_instance.expects(:download).times(5).raises(exception)

            I18n.t(@existing_key)
          end
        end

        describe "with a statsd client" do
          let(:statsd) { stub }

          before do
            I18n.backend = ZenEnd.new(http_open_retries: 3, http_read_retries: 4, statsd_client: statsd)
          end

          it "records the open retries to statsd" do
            VCR.use_cassette("simple") do
              exception = Faraday::ConnectionFailed.new(Net::OpenTimeout.new)
              I18n::Backend::Http::EtagHttpClient.any_instance.stubs(:download).raises(exception)
              statsd.expects(:increment).times(4)

              I18n.t(@existing_key)
            end
          end

          it "records the read retries to statsd" do
            VCR.use_cassette("simple") do
              exception = Faraday::TimeoutError.new(Net::ReadTimeout.new)
              I18n::Backend::Http::EtagHttpClient.any_instance.stubs(:download).raises(exception)
              statsd.expects(:increment).times(5)

              I18n.t(@existing_key)
            end
          end
        end
      end

      # FIXME how to simulate http timeouts !?
      #it "fails when api is slower then set timeout" do
      #  Timeout.timeout 0.8 do
      #    assert_equal "translation missing: de_DE-x-8.#{@missing_key}", I18n.t(@missing_key).gsub(', ', '.')
      #  end
      #end

      describe "with cache" do
        before do
          @cache = SimpleCache.new
          I18n.backend = ZenEnd.new(cache: @cache)
        end

        it "loads translations from cache" do
          @cache.write "i18n/backend/http/translations/8#{version}", [{"foo" => "bar"}, 'e-tag', Time.now + 10]
          assert_equal "bar", I18n.t("foo")
        end

        it "downloads translations on cache miss" do
          with_local_available do
            assert_equal "Am besten", I18n.t(@existing_key)
          end
          assert @cache.read("i18n/backend/http/translations/8#{version}")
        end

        it "stores invalid responses in cache" do
          silence_backend
          with_error do
            assert_equal "translation missing: #{I18n.locale}.#{@existing_key}", I18n.t(@existing_key).gsub(', ', '.')
          end
          @cache.read("i18n/backend/http/translations/#{I18n.locale.to_s[/\d+/]}#{version}").first.must_equal({})
        end

        it "use the memory cache before the cache" do
          @cache.write "i18n/backend/http/translations/8#{version}", [{"foo" => "bar"}, 'e-tag', Time.now + 10]
          assert_equal "bar", I18n.t("foo")
          @cache.write "i18n/backend/http/translations/8#{version}", [{"foo" => "baZZZ"}, 'e-tag', Time.now + 10]
          assert_equal "bar", I18n.t("foo")
        end
      end
    end

    describe "#start_polling" do
      it "not start polling when poll => false is given" do
        I18n.locale = "de_DE-x-8"
        I18n.backend = ZenEnd.new(poll: false, polling_interval: 0.2)
        sleep 0.1
        I18n.backend.expects(:update_caches).never
        I18n.backend.stop_polling
        sleep 0.5
      end

      it "update_caches" do
        I18n.locale = "de_DE-x-8"
        I18n.backend = ZenEnd.new(polling_interval: 0.2)
        I18n.backend.expects(:update_caches).twice
        sleep 0.5
      end

      it "stop when calling stop_polling" do
        I18n.locale = "de_DE-x-8"
        I18n.backend = ZenEnd.new(polling_interval: 0.2)
        sleep 0.1
        I18n.backend.expects(:update_caches).once
        I18n.backend.stop_polling
        sleep 0.5
      end
    end

    describe "#update_caches" do
      before do
        I18n.locale = "de_DE-x-8"
        I18n.backend = ZenEnd.new
        @key = @existing_key
      end

      it "update translations" do
        # init it
        with_local_available do
          assert_equal "Am besten", I18n.t(@key)
        end

        # add a change
        add_local_change
        assert_equal "OLD", I18n.t(@key)

        # update
        with_local_available do
          update_caches
        end

        assert_equal "Am besten", I18n.t(@key)
      end

      it "does not update if api did not change" do
        VCR.use_cassette("matching_etag") do
          assert_equal "Am besten", I18n.t(@key) # initial request

          # add a change
          add_local_change

          # update -> not modified!
          update_caches
          assert_equal "OLD", I18n.t(@key)
        end
      end

      it "does not update if api failed" do
        with_error do
          I18n.backend.instance_variable_set(:@translations, {"888888888" => [{@key => "bar"}, "E-TAG"]})
          assert_equal "bar", I18n.t(@key)

          silence_backend
          # update -> error -> local cache not modified!
          update_caches
          assert_equal "bar", I18n.t(@key)
        end
      end

      describe "with cache" do
        before do
          @key = @existing_key
          @cache = SimpleCache.new
          I18n.backend = ZenEnd.new(cache: @cache)
        end

        it "does not update when values are fresh" do
          # init it via cache
          @cache.write "i18n/backend/http/translations/8#{version}", [{@key => "bar"}, 'E-TAG', Time.now + 10]
          assert_equal "bar", I18n.t(@key)

          # add a change
          add_local_change
          assert_equal "OLD", I18n.t(@key)

          # update via api
          with_local_available do
            update_caches
          end

          assert_equal "OLD", I18n.t(@key)
        end

        it "update cache hen values are stale" do
          # init it via cache
          @cache.write "i18n/backend/http/translations/8#{version}", [{@key => "bar"}, 'E-TAG', Time.now - 10]
          assert_equal "bar", I18n.t(@key)

          # add a change
          add_local_change
          assert_equal "OLD", I18n.t(@key)

          # update via api
          with_local_available do
            update_caches
          end

          assert_equal "Am besten", I18n.t(@key)

          # loading from cache should have new translations
          I18n.backend = ZenEnd.new(cache: @cache)
          assert_equal "Am besten", I18n.t(@key)
        end

        it "pick one server to update the cache" do
          @cache.write "i18n/backend/http/translations/8#{version}", [{@key => "bar"}, 'E-TAG', Time.now - 10]
          ZenEnd.any_instance.expects(:download_translations).once.returns([{@key => "foo"}, "NEW-TAG"])
          4.times do
            backend = ZenEnd.new(polling_interval: 0.3, cache: @cache)
            assert_equal "bar", backend.translate("de-DE-x-8", @key)
          end
          sleep 0.7
        end

        it "update all translations known by all clients" do
          VCR.use_cassette("multiple_locales") do
            @cache.write "i18n/backend/http/translations/8#{version}", [{@key => "bar"}, 'E-TAG', Time.now - 10]
            @cache.write "i18n/backend/http/translations/2#{version}", [{@key => "bar"}, 'E-TAG', Time.now - 10]

            a = ZenEnd.new(polling_interval: 0.3, cache: @cache)
            b = ZenEnd.new(polling_interval: 0.3, cache: @cache)

            # initial fetch from cache ... everything is new so nothing is updated
            assert_equal "bar", a.translate("de-DE-x-8", @key)
            assert_equal "bar", b.translate("es-Es-x-2", @key)

            sleep 0.5 # to refresh vcr: a.stop_polling; b.stop_polling; sleep 10

            assert_equal "Am besten", a.translate("de-DE-x-8", @key)
            assert_equal "Mejor", b.translate("es-Es-x-2", @key)
          end
        end

        it "updates translations from cache if its a slave" do
          VCR.use_cassette("matching_etag") do
            @cache.write "i18n/backend/http/translations/8#{version}", [{@key => "bar"}, 'E-TAG', Time.now - 10]
            backends = Array.new(4)

            backends = backends.map do
              ZenEnd.new(polling_interval: 0.3, cache: @cache)
            end

            translate = -> do
              backends.map do |backend|
                backend.translate(I18n.locale, @key)
              end
            end
            assert_equal ["bar", "bar", "bar", "bar"], translate.call

            sleep 0.8

            assert_equal ["Am besten", "Am besten", "Am besten", "Am besten"], translate.call
          end
        end
      end
    end
  end
end
