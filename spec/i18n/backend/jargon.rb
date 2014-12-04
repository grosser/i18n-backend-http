require_relative '../../spec_helper'

RSpec.describe 'I18n::Backend::Jargon' do
  before(:each) do
    stub_request(:get, "www.example.com/api/uuid/Test").to_return(body: File.new('./spec/support/uuid.json'), status: 200)
    stub_request(:get, "www.example.com/api/uuid/Test/locales").to_return(body: File.new('./spec/support/locales.json'), status: 200)
    stub_request(:get, "www.example.com/api/uuid/Test/en").to_return(body: File.new('./spec/support/en.json'), status: 200)
    stub_request(:get, "www.example.com/api/uuid/Test/sp").to_return(body: File.new('./spec/support/sp.json'), status: 200)
  end

  describe '.available_locales' do
    subject { I18n::Backend::Jargon.available_locales }
    it { is_expected.to contain_exactly('en', 'sp')}
    it 'should initialize translations' do
      subject
      expect(I18n::Backend::Jargon.initialized?).to be_truthy
    end
  end

  describe '.localization_path' do
    subject { I18n::Backend::Jargon.localization_path }
    it { is_expected.to eq 'api/uuid/Test' }
  end

  describe '.locale_path' do
    subject { I18n::Backend::Jargon.locale_path('en') }
    it { is_expected.to eq 'api/uuid/Test/en' }
  end

  describe '.translate' do
    it 'returns hello in en' do
      expect(I18n::Backend::Jargon.translate('en', 'hello')).to eq 'Hello'
    end
    it 'returns hola in sp' do
      expect(I18n::Backend::Jargon.translate('sp', 'hello')).to eq 'Hola'
    end
  end
end
