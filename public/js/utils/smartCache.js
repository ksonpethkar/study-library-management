/**
 * Smart Client-Side In-Memory Cache with TTL & Invalidation Tags
 */
class SmartCache {
  constructor() {
    this.cache = new Map();
    this.tags = new Map();
  }

  set(key, value, ttlSeconds = 60, tag = null) {
    const expiresAt = Date.now() + (ttlSeconds * 1000);
    this.cache.set(key, { value, expiresAt, tag });

    if (tag) {
      if (!this.tags.has(tag)) {
        this.tags.set(tag, new Set());
      }
      this.tags.get(tag).add(key);
    }
  }

  get(key) {
    if (!this.cache.has(key)) return null;

    const item = this.cache.get(key);
    if (Date.now() > item.expiresAt) {
      this.cache.delete(key);
      return null;
    }
    return item.value;
  }

  invalidate(key) {
    this.cache.delete(key);
  }

  invalidateTag(tag) {
    if (this.tags.has(tag)) {
      this.tags.get(tag).forEach(key => this.cache.delete(key));
      this.tags.delete(tag);
    }
  }

  clear() {
    this.cache.clear();
    this.tags.clear();
  }
}

export const smartCache = new SmartCache();
