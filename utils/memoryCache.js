/**
 * In-Memory High-Speed Cache Utility
 * Provides sub-millisecond responses for read-heavy public and static configurations.
 * Supports automated TTL expiration and tag-based instant invalidation.
 */

class MemoryCache {
  constructor() {
    this.cache = new Map();
    this.tags = new Map(); // tag -> Set of cache keys
  }

  /**
   * Get a cached value
   * @param {string} key 
   * @returns {*} Cached value or null if expired/missing
   */
  get(key) {
    const item = this.cache.get(key);
    if (!item) return null;
    if (Date.now() > item.expiresAt) {
      this.delete(key);
      return null;
    }
    return item.value;
  }

  /**
   * Set a cached value with TTL in seconds
   * @param {string} key 
   * @param {*} value 
   * @param {number} ttlSeconds Default 300s (5 minutes)
   * @param {string[]} tags Optional invalidation tags
   */
  set(key, value, ttlSeconds = 300, tags = []) {
    const expiresAt = Date.now() + (ttlSeconds * 1000);
    this.cache.set(key, { value, expiresAt });

    if (Array.isArray(tags)) {
      tags.forEach(tag => {
        if (!this.tags.has(tag)) {
          this.tags.set(tag, new Set());
        }
        this.tags.get(tag).add(key);
      });
    }
  }

  /**
   * Delete a specific cache key
   * @param {string} key 
   */
  delete(key) {
    this.cache.delete(key);
  }

  /**
   * Invalidate all cache entries matching a tag (e.g. 'plans', 'branches', 'settings', 'custom_fields')
   * @param {string} tag 
   */
  invalidateTag(tag) {
    if (this.tags.has(tag)) {
      const keys = this.tags.get(tag);
      keys.forEach(k => this.cache.delete(k));
      this.tags.delete(tag);
    }
  }

  /**
   * Clear all cache entries
   */
  clear() {
    this.cache.clear();
    this.tags.clear();
  }

  /**
   * Middleware wrapper for Express routes
   * @param {number} ttlSeconds 
   * @param {string} tag 
   */
  middleware(ttlSeconds = 60, tag = '') {
    return (req, res, next) => {
      // Only cache GET requests
      if (req.method !== 'GET') return next();

      const key = `__express__${req.originalUrl || req.url}`;
      const cachedResponse = this.get(key);

      if (cachedResponse) {
        res.setHeader('X-Cache', 'HIT');
        res.setHeader('Content-Type', 'application/json');
        return res.send(cachedResponse);
      }

      res.setHeader('X-Cache', 'MISS');
      const originalSend = res.send.bind(res);
      res.send = (body) => {
        if (res.statusCode === 200) {
          this.set(key, body, ttlSeconds, tag ? [tag] : []);
        }
        return originalSend(body);
      };
      next();
    };
  }
}

const memoryCache = new MemoryCache();
module.exports = memoryCache;
