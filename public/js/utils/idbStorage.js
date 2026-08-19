/**
 * High-performance IndexedDB Storage Engine Wrapper for Study Library System
 * Database Name: sl_db_v1
 * Stores: students, seats, payments, settings
 */

const DB_NAME = 'sl_db_v1';
const DB_VERSION = 1;
const STORES = ['students', 'seats', 'payments', 'settings'];

class IDBStorageWrapper {
  constructor() {
    this.dbPromise = null;
  }

  _getDB() {
    if (this.dbPromise) return this.dbPromise;

    this.dbPromise = new Promise((resolve, reject) => {
      if (typeof indexedDB === 'undefined') {
        return reject(new Error('IndexedDB is not supported in this environment'));
      }

      const request = indexedDB.open(DB_NAME, DB_VERSION);

      request.onupgradeneeded = (event) => {
        const db = event.target.result;
        STORES.forEach((storeName) => {
          if (!db.objectStoreNames.contains(storeName)) {
            db.createObjectStore(storeName);
          }
        });
      };

      request.onsuccess = (event) => {
        resolve(event.target.result);
      };

      request.onerror = (event) => {
        this.dbPromise = null;
        reject(event.target.error || new Error('Failed to open IndexedDB database'));
      };
    });

    return this.dbPromise;
  }

  /**
   * Store a value in specified store by key
   * @param {string} store - Object store name (students, seats, payments, settings)
   * @param {string} key - Cache key identifier
   * @param {*} val - Value to store
   */
  async set(store, key, val) {
    try {
      const db = await this._getDB();
      return new Promise((resolve, reject) => {
        const tx = db.transaction(store, 'readwrite');
        const objectStore = tx.objectStore(store);
        const req = objectStore.put(val, key);

        req.onsuccess = () => resolve(true);
        req.onerror = () => reject(req.error);
      });
    } catch (err) {
      console.warn(`[IDBStorage] set error for store '${store}', key '${key}':`, err);
      return false;
    }
  }

  /**
   * Retrieve a value from specified store by key
   * @param {string} store - Object store name
   * @param {string} key - Cache key identifier
   */
  async get(store, key) {
    try {
      const db = await this._getDB();
      return new Promise((resolve, reject) => {
        const tx = db.transaction(store, 'readonly');
        const objectStore = tx.objectStore(store);
        const req = objectStore.get(key);

        req.onsuccess = () => resolve(req.result !== undefined ? req.result : null);
        req.onerror = () => reject(req.error);
      });
    } catch (err) {
      console.warn(`[IDBStorage] get error for store '${store}', key '${key}':`, err);
      return null;
    }
  }

  /**
   * Retrieve all records from specified store
   * @param {string} store - Object store name
   */
  async getAll(store) {
    try {
      const db = await this._getDB();
      return new Promise((resolve, reject) => {
        const tx = db.transaction(store, 'readonly');
        const objectStore = tx.objectStore(store);
        const req = objectStore.getAll();

        req.onsuccess = () => resolve(req.result || []);
        req.onerror = () => reject(req.error);
      });
    } catch (err) {
      console.warn(`[IDBStorage] getAll error for store '${store}':`, err);
      return [];
    }
  }

  /**
   * Clear all records from specified store
   * @param {string} store - Object store name
   */
  async clear(store) {
    try {
      const db = await this._getDB();
      return new Promise((resolve, reject) => {
        const tx = db.transaction(store, 'readwrite');
        const objectStore = tx.objectStore(store);
        const req = objectStore.clear();

        req.onsuccess = () => resolve(true);
        req.onerror = () => reject(req.error);
      });
    } catch (err) {
      console.warn(`[IDBStorage] clear error for store '${store}':`, err);
      return false;
    }
  }
}

export const IDBStorage = new IDBStorageWrapper();
if (typeof window !== 'undefined') {
  window.IDBStorage = IDBStorage;
}
export default IDBStorage;
