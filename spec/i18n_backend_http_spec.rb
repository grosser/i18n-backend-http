require 'spec_helper'

describe I18nBackendHttp do
  it "has a VERSION" do
    I18nBackendHttp::VERSION.should =~ /^[\.\da-z]+$/
  end
end
