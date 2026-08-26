/**
 * Cozy Corner Native Device Bridge (Capacitor.js)
 * Enables native Android & iOS hardware controls, back-button handling, and status bar integration
 */

(function () {
  'use strict';

  const isNative = typeof window !== 'undefined' && Boolean(window.Capacitor?.isNativePlatform?.());
  window.isNativeApp = isNative;

  if (!isNative) {
    return;
  }

  document.addEventListener('DOMContentLoaded', initNativeBridge);
  if (document.readyState === 'complete' || document.readyState === 'interactive') {
    initNativeBridge();
  }

  let isBridgeInitialized = false;

  async function initNativeBridge() {
    if (isBridgeInitialized) return;
    isBridgeInitialized = true;

    document.body.classList.add('is-native-app');

    const Plugins = window.Capacitor?.Plugins || {};
    const { App, StatusBar, SplashScreen, Keyboard, Haptics } = Plugins;

    // 1. Hide Splash Screen smoothly
    try {
      if (SplashScreen) {
        setTimeout(async () => {
          try { await SplashScreen.hide({ fadeOutDuration: 300 }); } catch (_) {}
        }, 800);
      }
    } catch (_) {}

    // 2. Android Hardware Back-Button Management
    let lastBackPress = 0;
    if (App && typeof App.addListener === 'function') {
      try {
        App.addListener('backButton', async ({ canGoBack }) => {
          // A. Close open modal if present
          const activeModal = document.querySelector('.modal[style*="display: block"], .modal.show, #modal-overlay, #bottom-sheet-overlay');
          if (activeModal) {
            if (window.Modal?.close) { window.Modal.close(); return; }
            if (window.BottomSheet?.close) { window.BottomSheet.close(); return; }
            activeModal.remove();
            return;
          }

          // B. Close sidebar drawer if open on mobile
          const sidebar = document.getElementById('sidebar');
          if (sidebar && sidebar.classList.contains('mobile-open')) {
            sidebar.classList.remove('mobile-open');
            document.getElementById('sidebar-overlay')?.classList.remove('visible');
            return;
          }

          // C. If inside Student Portal or Admin with a sub-hash, navigate back
          const hash = window.location.hash || '';
          if (hash && hash !== '#/dashboard' && hash !== '#/portal' && hash !== '#dashboard' && hash !== '#idpass') {
            if (window.history.length > 1) {
              window.history.back();
              return;
            }
          }

          // D. Double-tap back within 2000ms to exit app
          const now = Date.now();
          if (now - lastBackPress < 2000) {
            App.exitApp();
          } else {
            lastBackPress = now;
            if (window.Toast?.info) {
              window.Toast.info('Press back again to exit');
            }
          }
        });
      } catch (err) {
        console.warn('Native backButton listener warning:', err);
      }
    }

    // 3. Status Bar Color Synchronization
    const syncStatusBar = async () => {
      if (!StatusBar) return;
      try {
        const isDark = document.documentElement.getAttribute('data-theme') === 'dark' ||
                       document.body.classList.contains('dark-theme');
        const barColor = isDark ? '#0b101b' : '#6c5ce7';
        await StatusBar.setBackgroundColor({ color: barColor });
        await StatusBar.setStyle({ style: 'DARK' });
      } catch (_) {}
    };

    syncStatusBar();
    window.addEventListener('theme-changed', syncStatusBar);

    // 4. Native Haptics Bridge Helper
    window.nativeHaptic = async function (type = 'light') {
      if (!Haptics) return;
      try {
        if (type === 'heavy') await Haptics.impact({ style: 'HEAVY' });
        else if (type === 'medium') await Haptics.impact({ style: 'MEDIUM' });
        else if (type === 'success') await Haptics.notification({ type: 'SUCCESS' });
        else if (type === 'warning') await Haptics.notification({ type: 'WARNING' });
        else await Haptics.impact({ style: 'LIGHT' });
      } catch (_) {}
    };
  }
})();
