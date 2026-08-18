/**
 * Study Library Management System — PWA & Mobile Native Experience Manager
 * Handles PWA Install Prompt, iOS Add to Home Screen, Haptic Vibration & Native Web Share
 */

let deferredInstallPrompt = null;

export function initPWA() {
  // Register Service Worker
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('/sw.js').then((reg) => {
        console.log('PWA ServiceWorker registered with scope:', reg.scope);
      }).catch((err) => {
        console.warn('PWA ServiceWorker registration failed:', err);
      });
    });
  }

  // Handle Chrome / Android / Edge PWA Install Prompt
  window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    deferredInstallPrompt = e;
    showPWAInstallButtons();
  });

  window.addEventListener('appinstalled', () => {
    deferredInstallPrompt = null;
    hidePWAInstallButtons();
    console.log('StudyLib PWA App successfully installed!');
  });

  // Haptic feedback on button clicks
  document.addEventListener('click', (e) => {
    if (e.target.closest('.btn, .action-btn, .nav-item, .seat-card, .tab-item')) {
      vibrate(12);
    }
  });
}

export function promptPWAInstall() {
  // Check if iOS Safari
  const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) && !window.MSStream;
  const isStandalone = window.navigator.standalone || window.matchMedia('(display-mode: standalone)').matches;

  if (isStandalone) {
    alert('StudyLib App is already installed and running in standalone mode!');
    return;
  }

  if (deferredInstallPrompt) {
    deferredInstallPrompt.prompt();
    deferredInstallPrompt.userChoice.then((choiceResult) => {
      if (choiceResult.outcome === 'accepted') {
        console.log('User accepted PWA install prompt');
      }
      deferredInstallPrompt = null;
      hidePWAInstallButtons();
    });
  } else if (isIOS) {
    showIOSInstallInstructions();
  } else {
    alert('To install StudyLib App on your phone, tap the menu (⋮ or 3 dots) in your browser and select "Add to Home screen" or "Install App".');
  }
}

function showPWAInstallButtons() {
  document.querySelectorAll('.btn-pwa-install').forEach(btn => {
    btn.style.display = 'inline-flex';
  });
}

function hidePWAInstallButtons() {
  document.querySelectorAll('.btn-pwa-install').forEach(btn => {
    btn.style.display = 'none';
  });
}

function showIOSInstallInstructions() {
  const overlay = document.createElement('div');
  overlay.style.cssText = `
    position: fixed; bottom: 0; left: 0; right: 0; top: 0;
    background: rgba(15, 23, 42, 0.75); backdrop-filter: blur(8px);
    z-index: 99999; display: flex; align-items: flex-end; justify-content: center;
    padding: 1rem; animation: slideUp 0.3s ease;
  `;

  overlay.innerHTML = `
    <div style="background: var(--color-surface, #ffffff); width: 100%; max-width: 480px; border-radius: 20px; padding: 1.5rem; color: var(--color-text-primary, #1e293b); box-shadow: 0 -10px 40px rgba(0,0,0,0.3);">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;">
        <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; display: flex; align-items: center; gap: 8px;">
          📲 Install StudyLib on iPhone / iPad
        </h3>
        <button id="btn-close-ios-pwa" style="background: none; border: none; font-size: 1.2rem; cursor: pointer; color: #94a3b8;">✕</button>
      </div>

      <p style="font-size: 0.9rem; color: #64748b; line-height: 1.5; margin-bottom: 1rem;">
        Install StudyLib App on your iOS home screen for instant 1-tap access, full screen view, and offline portal access.
      </p>

      <div style="background: #f8fafc; padding: 1rem; border-radius: 12px; font-size: 0.9rem; display: flex; flex-direction: column; gap: 10px; margin-bottom: 1.25rem;">
        <div style="display: flex; align-items: center; gap: 12px;">
          <span style="font-size: 1.4rem;">1️⃣</span>
          <span>Tap the <strong>Share button</strong> <span style="font-size: 1.2rem;">⎋</span> (bottom bar in Safari).</span>
        </div>
        <div style="display: flex; align-items: center; gap: 12px;">
          <span style="font-size: 1.4rem;">2️⃣</span>
          <span>Scroll down & tap <strong>"Add to Home Screen"</strong> <span style="font-size: 1.1rem;">➕</span>.</span>
        </div>
        <div style="display: flex; align-items: center; gap: 12px;">
          <span style="font-size: 1.4rem;">3️⃣</span>
          <span>Tap <strong>"Add"</strong> in top right corner to launch App!</span>
        </div>
      </div>

      <button id="btn-gotit-ios-pwa" class="btn btn-primary" style="width: 100%; font-weight: 700; padding: 10px; border-radius: 10px;">
        Got it!
      </button>
    </div>
  `;

  document.body.appendChild(overlay);

  const close = () => overlay.remove();
  overlay.querySelector('#btn-close-ios-pwa')?.addEventListener('click', close);
  overlay.querySelector('#btn-gotit-ios-pwa')?.addEventListener('click', close);
}

/**
 * Haptic Vibration Feedback Helper
 */
export function vibrate(ms = 15) {
  if (typeof navigator !== 'undefined' && 'vibrate' in navigator) {
    try {
      navigator.vibrate(ms);
    } catch (e) {}
  }
}

/**
 * Native Phone Web Share Helper
 */
export async function nativeShare(data = {}) {
  if (navigator.share) {
    try {
      await navigator.share(data);
      return true;
    } catch (e) {
      return false;
    }
  }
  return false;
}

// Auto init on module load
if (typeof window !== 'undefined') {
  initPWA();
}
