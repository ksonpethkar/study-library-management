/**
 * High-Speed In-Memory Cache with TTL & Pattern Invalidation
 * Provides sub-1ms response times for frequently requested static / configuration endpoints.
 */

class MemoryCache {
  constructor() {
    this.cache = new Map();
  }

  set(key, value, ttlSeconds = 60) {
    const expiresAt = Date.now() + (ttlSeconds * 1000);
    this.cache.set(key, { value, expiresAt });
  }

  get(key) {
    const item = this.cache.get(key);
    if (!item) return null;
    if (Date.now() > item.expiresAt) {
      this.cache.delete(key);
      return null;
    }
    return item.value;
  }

  delete(key) {
    this.cache.delete(key);
  }

  invalidatePattern(pattern) {
    const regex = pattern instanceof RegExp ? pattern : new RegExp(pattern);
    for (const key of this.cache.keys()) {
      if (regex.test(key)) {
        this.cache.delete(key);
      }
    }
  }

  clear() {
    this.cache.clear();
  }

  middleware(ttlSeconds = 60) {
    return (req, res, next) => {
      // Only cache GET requests
      if (req.method !== 'GET') return next();
      
      // Do not cache authenticated user requests with specific user ID query
      if (req.headers.authorization && !req.originalUrl.includes('public')) {
        return next();
      }

      const key = req.originalUrl || req.url;
      const cached = this.get(key);
      if (cached) {
        res.setHeader('X-Cache', 'HIT');
        return res.json(cached);
      }

      res.setHeader('X-Cache', 'MISS');
      const originalJson = res.json.bind(res);
      res.json = (data) => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          this.set(key, data, ttlSeconds);
        }
        return originalJson(data);
      };

      next();
    };
  }
}

const memoryCache = new MemoryCache();
module.exports = memoryCache;
