module I18n
  module Backend
    class Http
    end
  end
end

class I18n::Backend::Http::NullCache
  def fetch(*args)
    yield
  end

  def read(key)
  end

  def write(key, value)
    value
  end
end
