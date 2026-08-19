/**
 * Study Library Management System — Web Push Notifications Manager
 * Provides utility methods for browser notification permission requests
 * and Service Worker push subscription registration.
 */

export class PushNotificationsManager {
  constructor() {
    this.storageKey = 'sl_push_enabled';
  }

  /**
   * Check if Web Push Notifications are supported by current browser
   * @returns {boolean}
   */
  isSupported() {
    return (
      typeof window !== 'undefined' &&
      'serviceWorker' in navigator &&
      'PushManager' in window &&
      'Notification' in window
    );
  }

  /**
   * Get current browser notification permission status
   * @returns {string} 'granted' | 'denied' | 'default' | 'unsupported'
   */
  getPermissionStatus() {
    if (typeof window === 'undefined' || !('Notification' in window)) return 'unsupported';
    return Notification.permission;
  }

  /**
   * Check if push notifications are enabled locally
   * @returns {boolean}
   */
  isEnabled() {
    return this.getPermissionStatus() === 'granted' && localStorage.getItem(this.storageKey) === 'true';
  }

  /**
   * Asks for browser Push Notification permission
   * @returns {Promise<string>} 'granted', 'denied', or 'default'
   */
  async requestPermission() {
    if (typeof window === 'undefined' || !('Notification' in window)) {
      console.warn('Push Notifications are not supported in this browser.');
      return 'unsupported';
    }

    try {
      const permission = await Notification.requestPermission();
      if (permission === 'granted') {
        localStorage.setItem(this.storageKey, 'true');
      } else {
        localStorage.setItem(this.storageKey, 'false');
      }
      return permission;
    } catch (error) {
      console.error('Error requesting notification permission:', error);
      return Notification.permission || 'denied';
    }
  }

  /**
   * Registers push subscription with Service Worker
   * @param {Object} options Options containing optional serverPublicKey / applicationServerKey
   * @returns {Promise<PushSubscription|null>}
   */
  async subscribe(options = {}) {
    if (!this.isSupported()) {
      throw new Error('Push notifications are not supported in this browser.');
    }

    const currentPermission = this.getPermissionStatus();
    if (currentPermission !== 'granted') {
      const requested = await this.requestPermission();
      if (requested !== 'granted') {
        throw new Error('Push notification permission denied by user.');
      }
    }

    try {
      const registration = await navigator.serviceWorker.ready;
      let subscription = await registration.pushManager.getSubscription();

      if (!subscription) {
        const subscribeOptions = {
          userVisibleOnly: true
        };

        const serverKey = options.applicationServerKey || options.serverPublicKey;
        if (serverKey) {
          subscribeOptions.applicationServerKey = typeof serverKey === 'string'
            ? this.urlBase64ToUint8Array(serverKey)
            : serverKey;
        }

        subscription = await registration.pushManager.subscribe(subscribeOptions);
      }

      localStorage.setItem(this.storageKey, 'true');
      return subscription;
    } catch (error) {
      console.error('Failed to subscribe to push notifications:', error);
      throw error;
    }
  }

  /**
   * Unsubscribes current push notification subscription
   * @returns {Promise<boolean>}
   */
  async unsubscribe() {
    if (!this.isSupported()) return false;
    try {
      const registration = await navigator.serviceWorker.ready;
      const subscription = await registration.pushManager.getSubscription();
      if (subscription) {
        await subscription.unsubscribe();
      }
      localStorage.setItem(this.storageKey, 'false');
      return true;
    } catch (error) {
      console.error('Error unsubscribing push notifications:', error);
      return false;
    }
  }

  /**
   * Helper utility to convert VAPID base64 public key to Uint8Array
   * @param {string} base64String
   * @returns {Uint8Array}
   */
  urlBase64ToUint8Array(base64String) {
    const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
    const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);
    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  }
}

export const PushNotifications = new PushNotificationsManager();
export default PushNotifications;
