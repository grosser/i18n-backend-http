module I18n
  module Backend
    class Http
    end
  end
end

# http://codesnippets.joyent.com/posts/show/12329
class I18n::Backend::Http::LRUCache
  def initialize(size = 10)
    @size = size
    @store = {}
    @lru = []
  end

  def []=(key, value)
    @store[key] = value
    set_lru(key)
    @store.delete(@lru.pop) if @lru.size > @size
  end

  def [](key)
    set_lru(key)
    @store[key]
  end

  def keys
    @store.keys
  end

  def values
    @store.values
  end

  private

  def set_lru(key)
    @lru.unshift(@lru.delete(key) || key)
  end
end
