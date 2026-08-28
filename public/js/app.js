import api from './api.js';
import Router from './router.js';
import { initSetupWizard, initLoginPage, initAppEvents } from './auth.js';
import { t } from './i18n.js';
import ShortcutManager from './shortcuts.js';
import { Toast, Modal, Loading, renderMobileBottomNav, VoiceSearch, initPullToRefresh, initVisualViewportKeyboardListener, escapeHTML } from './ui.js';
import { SearchPalette, GlobalSearch } from './search.js';
import { AudioFeedback } from './utils/audioFeedback.js';
import SmartLoading from './smartLoading.js';
import { promptPWAInstall } from './pwaManager.js';
import { SidebarSortable } from './dragDrop.js';
import ErrorBoundary from './errorBoundary.js';
import PerformanceMonitor from './performanceMonitor.js';

/**
 * Global Crash Catchers & Error Recovery
 * Captures uncaught JS exceptions and unhandled promise rejections to prevent UI freezes.
 */
window.onerror = function (message, source, lineno, colno, error) {
  console.error('❌ Uncaught JS Exception:', { message, source, lineno, colno, error });
  const errorMsg = error?.message || (typeof message === 'string' ? message : 'An unexpected error occurred.');
  if (typeof document !== 'undefined' && document.body && typeof Toast !== 'undefined' && Toast.error) {
    Toast.error(`Application Error: ${errorMsg}`);
  }
  return true;
};

window.onunhandledrejection = function (event) {
  const reasonMsg = event.reason?.message || (typeof event.reason === 'string' ? event.reason : '');
  if (
    !reasonMsg ||
    reasonMsg.includes('Transition was skipped') ||
    reasonMsg.includes('Transition was aborted') ||
    reasonMsg.includes('timeout in DOM update') ||
    reasonMsg.includes('AbortError') ||
    reasonMsg.includes('canceled') ||
    reasonMsg.includes('Failed to fetch') ||
    reasonMsg.includes('Network error') ||
    reasonMsg.includes('Load failed') ||
    reasonMsg.includes('network error')
  ) {
    return;
  }
  if (typeof document !== 'undefined' && document.body && typeof Toast !== 'undefined' && Toast.error) {
    Toast.error(`Async Error: ${reasonMsg}`);
  }
};

/**
 * Reactive global state store
 */
const store = new Proxy(
  { user: null, businessProfile: null, theme: 'light', sidebarCollapsed: false, notifications: [] },
  {
    set(target, key, value) {
      target[key] = value;
      document.dispatchEvent(new CustomEvent('store-change', { detail: { key, value } }));
      return true;
    }
  }
);

/**
 * Main Application class
 */
class Application {
  constructor() {
    this.router = null;
    this.shortcuts = null;
    this.searchPalette = null;
    this._appEventsInit = false;
    this._rippleInit = false;
    this._offlineBannerInit = false;
  }

  /**
   * Main initialization — checks setup status, auth, and routes
   */
  async init() {
    ErrorBoundary.init();
    SmartLoading.init();
    PerformanceMonitor.init();

    // Apply saved theme
    const savedTheme = localStorage.getItem('sl_theme') ||
      (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    this.setTheme(savedTheme);

    // Init offline/online sync banner listeners
    this.initOfflineBanner();

    // Prevent pinch-to-zoom and multi-touch zoom on mobile screens while allowing desktop zoom
    this.initMobileZoomLock();

    // Init keyboard shortcuts & Unified Global Search (Ctrl + K)
    if (!this.searchPalette) {
      this.searchPalette = GlobalSearch;
    }
    if (!this.shortcuts) {
      this.shortcuts = new ShortcutManager();
      this.shortcuts.register('Ctrl+D', () => this.toggleTheme(), 'Toggle Dark Mode');
      this.shortcuts.register('Ctrl+K', () => {
        if (this.searchPalette) this.searchPalette.toggle();
      }, 'Open Unified Search & Command Palette');
    }

    // Init interactive ripples & audio feedback
    if (!this._rippleInit) {
      this._rippleInit = true;
      document.addEventListener('click', (e) => {
        const target = e.target.closest('.btn, .nav-item, .seat-card, .tab-item, .hub-tab-btn, .action-btn, .lang-option');
        if (!target) return;

        const rect = target.getBoundingClientRect();
        const circle = document.createElement('span');
        const diameter = Math.max(rect.width, rect.height);
        const radius = diameter / 2;

        circle.style.width = circle.style.height = `${diameter}px`;
        circle.style.left = `${e.clientX - rect.left - radius}px`;
        circle.style.top = `${e.clientY - rect.top - radius}px`;
        circle.classList.add('ripple-circle');

        target.classList.add('ripple-target');
        const existing = target.querySelector('.ripple-circle');
        if (existing) existing.remove();
        target.appendChild(circle);

        setTimeout(() => {
          circle.remove();
        }, 500);
      });
    }

    try {
      const res = await api.get('/api/auth/check-setup');
      const isSetupComplete = res?.data?.isSetupComplete || false;

      if (!isSetupComplete) {
        this.showSetup();
      } else {
        const token = this.getToken();
        if (!token) {
          this.showLogin();
        } else {
          try {
            const userData = await api.get('/api/auth/me');
            const user = userData?.data || userData?.user || (userData?.email ? userData : null);
            if (user && user.role) {
              store.user = user;
              await this.showApp();
            } else {
              this.logout();
            }
          } catch (e) {
            // Token invalid or expired
            this.logout();
          }
        }
      }
    } catch (e) {
      console.error('Initialization error:', e);
      // Server likely not running — show login page anyway
      Toast.error('Cannot connect to server. Make sure the backend is running.');
      this.showLogin();
    }
  }

  /**
   * Add dynamic Offline/Online banner listener
   */
  initOfflineBanner() {
    if (this._offlineBannerInit) return;
    this._offlineBannerInit = true;

    let autoHideTimer = null;

    const getOrCreateBanner = () => {
      let banner = document.getElementById('offline-sync-banner');
      if (!banner) {
        banner = document.createElement('div');
        banner.id = 'offline-sync-banner';
        banner.style.cssText = 'position:fixed; top:0; left:0; right:0; width:100%; z-index:100000; padding:10px 16px; text-align:center; font-weight:600; font-size:0.875rem; color:#ffffff; box-shadow:0 2px 10px rgba(0,0,0,0.2); transition:all 0.3s ease; display:none;';
        document.body.prepend(banner);
      }
      return banner;
    };

    window.addEventListener('offline', () => {
      if (autoHideTimer) {
        clearTimeout(autoHideTimer);
        autoHideTimer = null;
      }
      const banner = getOrCreateBanner();
      banner.textContent = '⚠️ Offline Mode — Viewing cached data';
      banner.style.background = '#d97706';
      banner.style.display = 'block';
    });

    window.addEventListener('online', () => {
      if (autoHideTimer) {
        clearTimeout(autoHideTimer);
      }
      const banner = getOrCreateBanner();
      banner.textContent = '🟢 Reconnected — Cloud Sync Restored!';
      banner.style.background = '#10b981';
      banner.style.display = 'block';

      autoHideTimer = setTimeout(() => {
        banner.style.display = 'none';
        autoHideTimer = null;
      }, 3000);
    });

    if (typeof navigator !== 'undefined' && navigator.onLine === false) {
      const banner = getOrCreateBanner();
      banner.textContent = '⚠️ Offline Mode — Viewing cached data';
      banner.style.background = '#d97706';
      banner.style.display = 'block';
    }
  }

  /**
   * Block zoom-in / zoom-out on mobile view across the entire system
   * Keeps desktop browser zoom (Ctrl + + / Ctrl + - / mouse wheel) fully functional.
   */
  initMobileZoomLock() {
    if (typeof window === 'undefined' || typeof document === 'undefined') return;

    const isMobileDevice = () => window.innerWidth <= 1024 || ('ontouchstart' in window && navigator.maxTouchPoints > 0 && window.innerWidth <= 1024);

    // 1. Block iOS Safari pinch-to-zoom gesture events
    document.addEventListener('gesturestart', (e) => {
      if (isMobileDevice()) {
        e.preventDefault();
      }
    }, { passive: false });

    document.addEventListener('gesturechange', (e) => {
      if (isMobileDevice()) {
        e.preventDefault();
      }
    }, { passive: false });

    document.addEventListener('gestureend', (e) => {
      if (isMobileDevice()) {
        e.preventDefault();
      }
    }, { passive: false });

    // 2. Block double-tap to zoom on mobile while preserving normal inputs
    let lastTouchEnd = 0;
    document.addEventListener('touchend', (e) => {
      if (!isMobileDevice()) return;
      const now = Date.now();
      const isInput = e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA' || e.target.tagName === 'SELECT' || e.target.isContentEditable);
      if (!isInput && now - lastTouchEnd <= 300) {
        if (e.cancelable) e.preventDefault();
      }
      lastTouchEnd = now;
    }, { passive: false });
  }

  /**
   * Set and persist theme
   */
  setTheme(theme) {
    store.theme = theme;
    if (window.applySystemTheme) {
      window.applySystemTheme(theme);
    }
  }

  /**
   * Toggle between light and dark theme
   */
  toggleTheme() {
    if (window.toggleSystemTheme) {
      const next = window.toggleSystemTheme(true);
      store.theme = next;
    }
  }

  /**
   * Show the first-time setup wizard
   */
  showSetup() {
    this._show('setup-wizard');
    initSetupWizard();
    Loading.hidePage();
  }

  /**
   * Show the login screen
   */
  showLogin() {
    this._show('login-page');
    // Ensure URL hash reflects login page instead of lingering protected routes like #/students
    if (window.location.hash && window.location.hash !== '#/login') {
      try {
        if (window.location.hash !== '#/portal') {
          sessionStorage.setItem('sl_login_redirect', window.location.hash);
        }
      } catch (_) {}
      try {
        history.replaceState(null, '', '#/login');
      } catch (_) {
        window.location.hash = '#/login';
      }
    }
    initLoginPage();
    Loading.hidePage();
  }

  /**
   * Show the main application (sidebar + content)
   */
  async showApp() {
    this._show('app');

    // 1. Initialize and start SPA router immediately to mount active page
    if (!this.router) {
      this.initRouter();
    } else {
      this.router.start();
    }

    // 2. Render mobile bottom navigation bar immediately
    renderMobileBottomNav(store.user?.role || 'staff');

    // Wire up sidebar, header events only once
    if (!this._appEventsInit) {
      initAppEvents();
      document.getElementById('btn-pwa-header-install')?.addEventListener('click', () => promptPWAInstall());
      this._appEventsInit = true;
    }

    // Update user avatar image or initials
    this.updateUserAvatarHeader();
    window.updateProfileAvatar = (newAvatarUrl) => {
      if (store.user) {
        store.user.avatar = newAvatarUrl;
        store.user.photo = newAvatarUrl;
      }
      try {
        const u = JSON.parse(localStorage.getItem('sl_user') || '{}');
        u.avatar = newAvatarUrl;
        u.photo = newAvatarUrl;
        localStorage.setItem('sl_user', JSON.stringify(u));
      } catch(e) {}
      this.updateUserAvatarHeader(newAvatarUrl);
    };

    window.addEventListener('user-updated', (e) => {
      const avatarUrl = e?.detail?.avatar;
      this.updateUserAvatarHeader(avatarUrl);
    });

    // Adapt sidebar for role (Student vs Admin/Staff) & render database config
    try {
      await this.updateSidebarForRole();
    } catch (e) {
      console.warn('Sidebar role update error:', e);
    }

    // Enable sidebar drag-to-reorder (admin/staff only)
    if (store.user?.role !== 'student') {
      setTimeout(() => {
        try {
          SidebarSortable.init({
            mode: 'personal',
            userId: store.user?._id || store.user?.id || null
          });
        } catch (e) {}
      }, 300);
    }

    // Init search palette
    if (!this.searchPalette) {
      try {
        this.searchPalette = new SearchPalette();
      } catch (e) {}
    }

    // ── Phase B: Pull-to-Refresh (mobile only, init once) ─────────────────
    if (!this._ptrInit) {
      this._ptrInit = true;
      initPullToRefresh();
    }

    // ── Phase D: Virtual Keyboard Detection & Viewport Responsiveness ───────
    if (!this._keyboardInit) {
      this._keyboardInit = true;
      initVisualViewportKeyboardListener();
    }

    // ── Phase D: Mobile Keyboard Input Enhancement ─────────────────────────
    // Adds inputmode + enterkeyhint to inputs dynamically — works in modals too
    if (!this._inputEnhanceInit) {
      this._inputEnhanceInit = true;
      const enhanceInputs = (root = document) => {
        root.querySelectorAll('input:not([inputmode]), textarea:not([inputmode])').forEach(inp => {
          const id = (inp.id || '').toLowerCase();
          const name = (inp.name || '').toLowerCase();
          const placeholder = (inp.placeholder || '').toLowerCase();
          const type = inp.type || 'text';
          const key = `${id} ${name} ${placeholder}`;

          if (type === 'tel' || /phone|mobile|whatsapp|contact/.test(key)) {
            inp.setAttribute('inputmode', 'tel');
            inp.setAttribute('enterkeyhint', 'next');
          } else if (type === 'email' || /email|mail/.test(key)) {
            inp.setAttribute('inputmode', 'email');
            inp.setAttribute('enterkeyhint', 'next');
            inp.setAttribute('autocomplete', 'email');
          } else if (type === 'number' || /amount|fee|price|cost|balance|pincode|pin/.test(key)) {
            inp.setAttribute('inputmode', 'numeric');
            inp.setAttribute('enterkeyhint', 'next');
          } else if (/search|query|find|lookup/.test(key)) {
            inp.setAttribute('inputmode', 'search');
            inp.setAttribute('enterkeyhint', 'search');
          } else if (/url|link|website|avatar/.test(key)) {
            inp.setAttribute('inputmode', 'url');
          } else if (type === 'text') {
            inp.setAttribute('enterkeyhint', 'next');
          }

          if (/name|full.name/.test(key)) inp.setAttribute('autocomplete', 'name');
          if (/city|town/.test(key))      inp.setAttribute('autocomplete', 'address-level2');
          if (/state|province/.test(key)) inp.setAttribute('autocomplete', 'address-level1');
        });
      };

      // Run on boot + observe DOM mutations (modals, dynamic forms)
      enhanceInputs();
      const obs = new MutationObserver((muts) => {
        muts.forEach(m => m.addedNodes.forEach(n => {
          if (n.nodeType === 1) enhanceInputs(n.querySelectorAll ? n : document);
        }));
      });
      obs.observe(document.body, { childList: true, subtree: true });
    }

    const voiceBtn = document.getElementById('voice-search-btn');
    if (voiceBtn && !voiceBtn._voiceInit) {
      voiceBtn._voiceInit = true;
      voiceBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        VoiceSearch.start((transcript) => {
          if (this.searchPalette) {
            this.searchPalette.open();
            this.searchPalette.input.value = transcript;
            this.searchPalette.search(transcript);
          }
        });
      });
    }

    // ── Phase 3: Apply saved module colors on startup ─────────────────────
    try {
      const savedMC = JSON.parse(localStorage.getItem('sl_module_colors') || '{}');
      if (Object.keys(savedMC).length > 0) {
        const root = document.documentElement;
        const unified = savedMC.unified;
        const brand = savedMC.brandColor || '#6c5ce7';
        if (unified) {
          ['students','payments','seats','attendance','reports','settings'].forEach(m => {
            root.style.setProperty(`--module-color-${m}`, brand);
          });
          root.style.setProperty('--color-primary', brand);
        } else {
          Object.entries(savedMC).forEach(([k, v]) => {
            if (k !== 'unified' && k !== 'brandColor' && v && typeof v === 'string' && v.startsWith('#')) {
              root.style.setProperty(`--module-color-${k}`, v);
            }
          });
        }
      }
    } catch (e) {}

    // ── Phase 3: PWA Install Nudge for mobile students ────────────────────
    // Show once per session after 5s if on mobile and not already installed
    if (!this._pwaPrompted && store.user?.role === 'student') {
      this._pwaPrompted = true;
      const isStandalone = window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone;
      const isMobile = /Android|iPhone|iPad/i.test(navigator.userAgent);
      const dismissed = sessionStorage.getItem('sl_pwa_nudge_dismissed');
      if (!isStandalone && isMobile && !dismissed) {
        setTimeout(() => {
          Toast.info('📲 Install this app on your phone for offline access!', {
            duration: 8000,
            action: { label: '⬇️ Install', callback: () => promptPWAInstall() },
            onDismiss: () => sessionStorage.setItem('sl_pwa_nudge_dismissed', '1')
          });
        }, 5000);
      }
    }

    // ── Phase 7: Notification Center ──────────────────────────────────────
    if (store.user?.role !== 'student' && !this._notifInit) {
      this._notifInit = true;
      initNotificationCenter();
    }
  }

  updateUserAvatarHeader(overrideUrl = null) {
    const avatarEl = document.getElementById('user-avatar');
    if (!avatarEl) return;

    let user = store.user;
    try {
      if (!user) user = JSON.parse(localStorage.getItem('sl_user') || '{}');
    } catch(e) {}

    const imgUrl = overrideUrl || user?.avatar || user?.photo;
    const name = user?.name || 'User';
    const initials = name.split(' ').filter(Boolean).map(w => w[0]).join('').toUpperCase().slice(0, 2) || 'U';

    if (imgUrl) {
      avatarEl.style.overflow = 'hidden';
      avatarEl.style.padding = '0';
      const cleanUrl = imgUrl.startsWith('/') || imgUrl.startsWith('http') || imgUrl.startsWith('data:') ? imgUrl : `/${imgUrl}`;
      avatarEl.innerHTML = `<img src="${cleanUrl}" alt="Avatar" style="width: 100%; height: 100%; object-fit: cover; border-radius: 50%; display: block;" onerror="this.remove(); document.getElementById('user-avatar').textContent='${initials}';">`;
    } else {
      avatarEl.innerHTML = '';
      avatarEl.textContent = initials;
    }
  }

  /**
   * Filter and style sidebar according to user role and saved database navigation configuration
   */
  async updateSidebarForRole() {
    const role = store.user?.role || 'staff';
    const isStudent = role === 'student';
    const nav = document.querySelector('.sidebar-nav');
    if (!nav) return;

    if (isStudent) {
      nav.innerHTML = `
        <a href="#/portal" class="nav-item active">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 10v6M2 10l10-5 10 5-10 5z"></path><path d="M6 12v5c3 3 9 3 12 0v-5"></path></svg>
          <span data-i18n="nav.portal">Student Dashboard</span>
        </a>
        <a href="#/profile" class="nav-item">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path><circle cx="12" cy="7" r="4"></circle></svg>
          <span data-i18n="nav.profile">My Profile</span>
        </a>
      `;
      this.attachSidebarEvents();
      const currentRoute = (window.location.hash || '#/portal').replace('#/', '');
      this.updateActiveNav(currentRoute);
      return;
    }

    try {
      const res = await api.get('/api/settings/sidebar');
      if (res && res.success && Array.isArray(res.data) && res.data.length > 0) {
        const items = res.data;
        const currentHash = window.location.hash || '#/dashboard';
        
        const defaultIcons = {
          dashboard: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7"></rect><rect x="14" y="3" width="7" height="7"></rect><rect x="14" y="14" width="7" height="7"></rect><rect x="3" y="14" width="7" height="7"></rect></svg>`,
          students: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle><path d="M23 21v-2a4 4 0 0 0-3-3.87"></path><path d="M16 3.13a4 4 0 0 1 0 7.75"></path></svg>`,
          seats: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="2" width="16" height="20" rx="2" ry="2"></rect><path d="M9 22v-4h6v4"></path><path d="M5 16V4a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v12"></path></svg>`,
          lockers: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0 1 10 0v4"></path></svg>`,
          plans: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z"></path><line x1="7" y1="7" x2="7.01" y2="7"></line></svg>`,
          payments: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="1" y="4" width="22" height="16" rx="2" ry="2"></rect><line x1="1" y1="10" x2="23" y2="10"></line></svg>`,
          attendance: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"></path><rect x="8" y="2" width="8" height="4" rx="1" ry="1"></rect><path d="M9 14l2 2 4-4"></path></svg>`,
          shifts: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 16 14"></polyline></svg>`,
          branches: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 21h18M9 8h1M9 12h1M9 16h1M14 8h1M14 12h1M14 16h1M5 21V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v16"></path></svg>`,
          reports: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="20" x2="12" y2="10"></line><line x1="18" y1="20" x2="18" y2="4"></line><line x1="6" y1="20" x2="6" y2="16"></line></svg>`,
          expenses: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="1" x2="12" y2="23"></line><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"></path></svg>`,
          operations: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path></svg>`,
          settings: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"></circle><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path></svg>`,
          profile: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path><circle cx="12" cy="7" r="4"></circle></svg>`
        };

        nav.innerHTML = items.map(item => {
          const isActive = item.href === currentHash;
          const safeLabel = escapeHTML(item.label || '');
          let iconHtml = '';
          if (item.icon && item.icon.startsWith('<svg')) {
            iconHtml = item.icon; // SVG markup is safe (from our own code)
          } else if (item.icon && item.icon.trim()) {
            iconHtml = `<span class="nav-icon-emoji" style="font-size: 1.15rem; width: 22px; display: inline-flex; align-items: center; justify-content: center;">${escapeHTML(item.icon)}</span>`;
          } else {
            iconHtml = defaultIcons[item.key] || '<span class="nav-icon-emoji">📌</span>';
          }

          return `
            <a href="${escapeHTML(item.href || '#')}" class="nav-item ${isActive ? 'active' : ''}" data-key="${escapeHTML(item.key || '')}">
              ${iconHtml}
              <span ${item.i18nKey ? `data-i18n="${escapeHTML(item.i18nKey)}"` : ''}>${safeLabel}</span>
            </a>
          `;
        }).join('');

        this.attachSidebarEvents();
        const currentRoute = (window.location.hash || '#/dashboard').replace('#/', '');
        this.updateActiveNav(currentRoute);
      }
    } catch (err) {
      console.warn('Could not load dynamic sidebar config:', err);
    }
  }

  attachSidebarEvents() {
    document.querySelectorAll('.sidebar-nav .nav-item').forEach(link => {
      link.onclick = () => {
        document.getElementById('sidebar')?.classList.remove('mobile-open');
        document.getElementById('sidebar-overlay')?.classList.remove('visible');
      };
    });
  }

  /**
   * Log out the user
   */
  logout() {
    const isStudent = store.user?.role === 'student' || 
                      localStorage.getItem('sl_user_role') === 'student' || 
                      !!localStorage.getItem('student_token') ||
                      window.location.hash.includes('portal');
    localStorage.removeItem('sl_token');
    localStorage.removeItem('student_token');
    localStorage.removeItem('sl_student_user');
    localStorage.removeItem('sl_user_role');
    store.user = null;
    if (isStudent) {
      window.location.href = '/student-login';
      return;
    }
    this.showLogin();
  }

  /** Get current user from store */
  getUser() { return store.user; }
  setUser(u) { store.user = u; }

  /** Get JWT token from localStorage */
  getToken() { return localStorage.getItem('sl_token'); }

  /** Get global store */
  getStore() { return store; }

  /**
   * Transition to a page with animation and page-specific loading screen
   */
  showPage(pageId, renderFn) {
    const _perfStart = performance.now();
    const content = document.getElementById('page-content');
    if (!content) return;

    // Update active nav links immediately
    this.updateActiveNav(pageId);

    const pageMeta = {
      dashboard: { name: 'Dashboard', icon: '📊', skel: 'dashboard' },
      students: { name: 'Student Master & Admissions', icon: '🎓', skel: 'table' },
      seats: { name: 'Live Seating Grid & Hall Matrix', icon: '💺', skel: 'seats' },
      lockers: { name: 'Locker Allocation Matrix', icon: '🔐', skel: 'table' },
      plans: { name: 'Membership Study Plans', icon: '📦', skel: 'cards' },
      payments: { name: 'Fee Collection & Receipt Studio', icon: '💳', skel: 'table' },
      attendance: { name: 'Gate Kiosk Attendance Log', icon: '📅', skel: 'table' },
      shifts: { name: 'Study Shift Timings', icon: '⏰', skel: 'table' },
      branches: { name: 'Multi-Branch Study Centres', icon: '🏢', skel: 'cards' },
      reports: { name: 'Financial & Occupancy Analytics', icon: '📈', skel: 'table' },
      expenses: { name: 'Operational Expense Tracker', icon: '💸', skel: 'table' },
      operations: { name: 'Waiting List & Asset Log', icon: '📋', skel: 'table' },
      portal: { name: 'Student Self-Service Portal', icon: '🌟', skel: 'dashboard' },
      settings: { name: 'System Settings & Studio Controls', icon: '⚙️', skel: 'table' },
      profile: { name: 'Admin Account & Security', icon: '👤', skel: 'cards' }
    };

    const meta = pageMeta[pageId] || { name: pageId.charAt(0).toUpperCase() + pageId.slice(1), icon: '⚡', skel: 'table' };

    // Navigation race condition guard: track current request ID
    this._navSeq = (this._navSeq || 0) + 1;
    const currentSeq = this._navSeq;

    // 1. Instant top progress bar animation
    Loading.startProgress();

    // 2. Instant skeleton shimmer placeholder
    Loading.renderSkeleton(content, meta.skel);

    const doRender = async () => {
      try {
        const result = await renderFn(content);
        // Check if navigation moved on while this page was rendering
        if (this._navSeq !== currentSeq) {
          return; // Ignore stale render response
        }
        if (result instanceof HTMLElement && result !== content) {
          content.innerHTML = '';
          content.appendChild(result);
        }
      } catch (err) {
        if (this._navSeq !== currentSeq) return;
        console.error(`Render error on page ${pageId}:`, err);
        content.innerHTML = `
          <div class="card p-4 text-center" style="border-color: var(--color-danger); margin: 2rem; background: var(--color-surface); border-radius: var(--radius-lg);">
            <div style="font-size: 2.2rem; margin-bottom: 8px;">⚠️</div>
            <h4 style="color: var(--color-danger); margin-bottom: 6px; font-weight: 800;">Failed to load ${escapeHTML(meta.name)}</h4>
            <p class="text-muted small">${escapeHTML(err.message || 'An error occurred while rendering the page.')}</p>
            <div>
              <button class="btn btn-primary btn-sm mt-2" onclick="window.location.reload()">🔄 Reload Page</button>
            </div>
          </div>
        `;
      } finally {
        if (this._navSeq === currentSeq) {
          Loading.doneProgress();
          Loading.hidePage();
        }
      }
    };

    doRender();

    requestAnimationFrame(() => {
      if (window.PerformanceMonitor) {
        window.PerformanceMonitor.trackPageLoad(pageId, performance.now() - _perfStart);
      }
    });
  }

  /**
   * Update active class on sidebar and mobile nav links
   */
  updateActiveNav(pageId) {
    const hash = `#/${pageId}`;

    // Desktop sidebar
    document.querySelectorAll('.sidebar-nav .nav-item').forEach(link => {
      const href = (link.getAttribute('href') || '').split('?')[0];
      link.classList.toggle('active', href === hash);
    });

    // Mobile bottom nav
    document.querySelectorAll('.mobile-bottom-nav .mobile-tab-item, .mobile-nav .mobile-nav-item').forEach(link => {
      const href = (link.getAttribute('href') || link.getAttribute('data-href') || '').split('?')[0];
      if (href !== 'javascript:void(0);' && href !== 'action:menu') {
        link.classList.toggle('active', href === hash);
      }
    });
  }

  /**
   * Initialize the SPA router with all page routes
   */
  initRouter() {
    this.router = new Router();

    const pages = [
      'dashboard', 'students', 'seats', 'lockers', 'plans', 'payments',
      'attendance', 'shifts', 'branches', 'reports', 'expenses', 'operations', 'trash', 'portal', 'settings', 'profile'
    ];

    pages.forEach(page => {
      this.router.addRoute(`#/${page}`, async () => {
        const content = document.getElementById('page-content');
        // Show smart loading progress bar during page load
        if (window.SmartLoading) window.SmartLoading.startProgress();
        try {
          const module = await import(`./pages/${page}.js`);
          if (typeof module.render !== 'function') {
            throw new Error(`Page "${page}" has no render() function exported`);
          }
          this.showPage(page, module.render);
        } catch (err) {
          console.error(`Failed to load page: ${page}`, err);
          if (content) {
            content.innerHTML = `
              <div style="padding: 2rem; text-align: center;">
                <h2 style="color: var(--color-danger);">Failed to load ${page}</h2>
                <p style="color: var(--color-text-secondary); margin-top: 1rem;">${err.message || 'Unknown error'}</p>
                <pre style="text-align: left; background: var(--color-bg-secondary); padding: 1rem; border-radius: 8px; margin-top: 1rem; overflow-x: auto; font-size: 0.8rem; color: var(--color-danger);">${err.stack || err}</pre>
              </div>`;
          }
        } finally {
          // Always stop the progress bar
          if (window.SmartLoading) window.SmartLoading.stopProgress();
        }
      });
    });

    // High Performance: Pre-fetch page modules when hovering over sidebar links
    document.querySelectorAll('.sidebar-nav .nav-item, .mobile-bottom-nav .mobile-tab-item').forEach(link => {
      link.addEventListener('mouseenter', () => {
        const href = (link.getAttribute('href') || '').replace('#/', '').split('?')[0];
        if (href && pages.includes(href)) {
          import(`./pages/${href}.js`).catch(() => {});
        }
      }, { passive: true, once: true });
    });

    // Default route
    this.router.addRoute('', () => {
      if (store.user?.role === 'student') {
        this.router.navigate('#/portal');
      } else {
        this.router.navigate('#/dashboard');
      }
    });
    this.router.start();
  }

  /**
   * Helper to show one screen and hide others
   */
  _show(id) {
    ['app', 'login-page', 'setup-wizard'].forEach(elId => {
      const el = document.getElementById(elId);
      if (el) el.style.display = elId === id ? '' : 'none';
    });
  }
}

export const App = new Application();
window.App = App;
window.toggleTheme = () => App.toggleTheme();
window.reloadSidebar = () => App.updateSidebarForRole();

// Boot the application safely (handles deferred module loading)
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    App.init();
  });
} else {
  App.init();
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// PHASE 7 — Notification Center, Confetti, Swipe Row Actions
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// ── 1. Notification Center ────────────────────────────────────────────────
export function initNotificationCenter() {
  const btn   = document.getElementById('notif-btn');
  const badge = document.getElementById('notif-badge');
  if (!btn) return;

  btn.style.cursor = 'pointer';
  btn.style.touchAction = 'manipulation';
  btn.setAttribute('aria-label', 'Open Notifications');

  // Inject dropdown panel into header area once
  let panel = document.getElementById('notif-panel');
  if (!panel) {
    panel = document.createElement('div');
    panel.id = 'notif-panel';
    panel.style.cssText = `
      display:none; position:fixed; top:60px; right:12px; z-index:10000;
      width:340px; max-width:calc(100vw - 24px);
      background:#1e293b; border:1px solid rgba(255,255,255,0.12);
      border-radius:16px; box-shadow:0 16px 48px rgba(0,0,0,0.55);
      overflow:hidden; animation:fadeIn 0.18s ease;
      touch-action: manipulation;
    `;
    panel.innerHTML = `
      <div style="padding:12px 16px; border-bottom:1px solid rgba(255,255,255,0.08); display:flex; align-items:center; justify-content:space-between; background: rgba(15,23,42,0.7);">
        <span style="font-weight:700; font-size:0.95rem; color:#f8fafc; display:flex; align-items:center; gap:6px;">🔔 Notifications</span>
        <div style="display:flex;gap:6px;">
          <button type="button" id="notif-mark-all" style="font-size:0.72rem;padding:4px 8px;border-radius:8px;border:1px solid rgba(255,255,255,0.15);background:rgba(255,255,255,0.06);color:#cbd5e1;cursor:pointer;font-weight:600;touch-action:manipulation;">Mark all read</button>
          <button type="button" id="notif-clear-read" style="font-size:0.72rem;padding:4px 8px;border-radius:8px;border:1px solid rgba(255,255,255,0.15);background:rgba(255,255,255,0.06);color:#cbd5e1;cursor:pointer;font-weight:600;touch-action:manipulation;">Clear</button>
        </div>
      </div>
      <div id="notif-list" style="max-height:380px;overflow-y:auto;-webkit-overflow-scrolling:touch;"></div>
      <div style="padding:10px 16px;border-top:1px solid rgba(255,255,255,0.08);font-size:0.74rem;color:#94a3b8;text-align:center;background:rgba(15,23,42,0.4);">
        Showing latest library activity
      </div>
    `;
    document.body.appendChild(panel);
  }

  const list = document.getElementById('notif-list');

  // Type → emoji/color map
  const typeMap = {
    expiry:    { emoji: '⏰', color: '#e17055' },
    payment:   { emoji: '💳', color: '#00b894' },
    admission: { emoji: '🎓', color: '#6c5ce7' },
    seat:      { emoji: '🪑', color: '#fd79a8' },
    student:   { emoji: '👤', color: '#0984e3' },
    system:    { emoji: '⚙️', color: '#74b9ff' },
    general:   { emoji: '📢', color: '#a29bfe' },
  };

  function timeAgo(date) {
    const diff = Date.now() - new Date(date).getTime();
    const mins  = Math.floor(diff / 60000);
    const hours = Math.floor(diff / 3600000);
    const days  = Math.floor(diff / 86400000);
    if (mins < 1)   return 'just now';
    if (mins < 60)  return `${mins}m ago`;
    if (hours < 24) return `${hours}h ago`;
    return `${days}d ago`;
  }

  async function loadNotifications() {
    try {
      const res = await api.get('/api/notifications');
      if (!res.success) return;
      const { notifications, unreadCount } = res.data;

      // Update badge
      if (badge) {
        badge.textContent = unreadCount > 0 ? (unreadCount > 99 ? '99+' : unreadCount) : '';
        badge.style.display = unreadCount > 0 ? 'flex' : 'none';
      }

      // Render list
      if (!notifications || notifications.length === 0) {
        list.innerHTML = `<div style="padding:32px;text-align:center;color:#64748b;">
          <div style="font-size:2rem;margin-bottom:8px;">🔔</div>
          <div style="font-weight:600;">No notifications yet</div>
        </div>`;
        return;
      }

      list.innerHTML = notifications.map(n => {
        const t = typeMap[n.type] || typeMap.general;
        const bg = n.isRead ? 'transparent' : 'rgba(108,92,231,0.07)';
        const dot = n.isRead ? '' : `<span style="width:7px;height:7px;border-radius:50%;background:#6c5ce7;flex-shrink:0;margin-top:4px;"></span>`;
        return `
          <div class="notif-item" data-id="${n._id}" data-link="${n.link || ''}" style="
            display:flex;gap:12px;align-items:flex-start;
            padding:12px 16px;cursor:pointer;
            background:${bg};border-bottom:1px solid rgba(255,255,255,0.05);
            transition:background 0.15s ease;
          " onmouseenter="this.style.background='rgba(255,255,255,0.04)'" onmouseleave="this.style.background='${bg}'">
            <div style="font-size:1.3rem;flex-shrink:0;">${t.emoji}</div>
            <div style="flex:1;min-width:0;">
              <div style="font-weight:${n.isRead ? 500 : 700};font-size:0.85rem;color:#e2e8f0;line-height:1.3;">${n.title}</div>
              <div style="font-size:0.78rem;color:#94a3b8;margin-top:2px;line-height:1.4;">${n.message}</div>
              <div style="font-size:0.7rem;color:#64748b;margin-top:4px;">${timeAgo(n.createdAt)}</div>
            </div>
            ${dot}
          </div>`;
      }).join('');

      // Wire row clicks
      list.querySelectorAll('.notif-item').forEach(item => {
        item.addEventListener('click', async () => {
          const id = item.dataset.id;
          const link = item.dataset.link;
          // Mark as read
          await api.put(`/api/notifications/${id}/read`).catch(() => {});
          item.style.background = 'transparent';
          item.querySelector('span[style*="border-radius:50%"]')?.remove();
          // Update badge
          const cur = parseInt(badge?.textContent) || 0;
          if (cur > 0 && badge) {
            badge.textContent = cur - 1 || '';
            badge.style.display = cur - 1 > 0 ? 'flex' : 'none';
          }
          // Navigate
          if (link) { window.location.hash = link; closePanel(); }
        });
      });
    } catch (e) {}
  }

  function closePanel() {
    panel.style.display = 'none';
  }

  // Toggle on bell click (Supports mobile touch & desktop click)
  if (!btn._notifClickBound) {
    btn._notifClickBound = true;
    
    const handleToggle = (e) => {
      if (e) {
        e.preventDefault();
        e.stopPropagation();
      }
      const isOpen = panel.style.display === 'block';
      panel.style.display = isOpen ? 'none' : 'block';
      if (!isOpen) {
        loadNotifications();
      }
    };

    btn.addEventListener('click', handleToggle);
  }

  // Mark all read
  document.getElementById('notif-mark-all')?.addEventListener('click', async (e) => {
    e.stopPropagation();
    await api.put('/api/notifications/read-all').catch(() => {});
    if (badge) { badge.textContent = ''; badge.style.display = 'none'; }
    await loadNotifications();
  });

  // Clear read
  document.getElementById('notif-clear-read')?.addEventListener('click', async (e) => {
    e.stopPropagation();
    await api.delete('/api/notifications/clear-read').catch(() => {});
    await loadNotifications();
  });

  // Close on outside click (Checks button contains target so SVG/badge clicks don't close it!)
  if (!document._notifOutsideBound) {
    document._notifOutsideBound = true;
    document.addEventListener('click', (e) => {
      const p = document.getElementById('notif-panel');
      const b = document.getElementById('notif-btn');
      if (p && p.style.display === 'block') {
        if (!p.contains(e.target) && !b?.contains(e.target)) {
          p.style.display = 'none';
        }
      }
    });
  }

  // Initial load + poll every 60s
  loadNotifications();
  if (!window._notifPollInterval) {
    window._notifPollInterval = setInterval(loadNotifications, 60000);
  }

  // Expose for external callers (e.g. after creating new admission)
  window.refreshNotifications = loadNotifications;
}

// ── 2. Confetti Celebration ───────────────────────────────────────────────
export function confettiCelebrate(opts = {}) {
  const { duration = 2000, colors = ['#6c5ce7','#a29bfe','#00b894','#fdcb6e','#fd79a8','#e17055'] } = opts;
  const canvas = document.createElement('canvas');
  canvas.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;z-index:99999;pointer-events:none;';
  document.body.appendChild(canvas);
  const ctx = canvas.getContext('2d');
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;

  const pieces = Array.from({ length: 120 }, () => ({
    x: Math.random() * canvas.width,
    y: Math.random() * canvas.height - canvas.height,
    r: Math.random() * 7 + 3,
    d: Math.random() * 120 + 40,
    color: colors[Math.floor(Math.random() * colors.length)],
    tilt: Math.random() * 10 - 10,
    tiltAngle: 0,
    tiltSpeed: Math.random() * 0.1 + 0.05,
    vx: Math.random() * 2 - 1,
    vy: Math.random() * 3 + 2
  }));

  let start = null;
  function draw(ts) {
    if (!start) start = ts;
    const elapsed = ts - start;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    pieces.forEach(p => {
      p.tiltAngle += p.tiltSpeed;
      p.y += p.vy;
      p.x += p.vx;
      p.tilt = Math.sin(p.tiltAngle) * 15;
      if (p.y > canvas.height) { p.y = -10; p.x = Math.random() * canvas.width; }
      ctx.beginPath();
      ctx.lineWidth = p.r;
      ctx.strokeStyle = p.color;
      ctx.moveTo(p.x + p.tilt + p.r / 2, p.y);
      ctx.lineTo(p.x + p.tilt, p.y + p.tilt + p.r / 2);
      ctx.stroke();
    });
    if (elapsed < duration) requestAnimationFrame(draw);
    else canvas.remove();
  }
  requestAnimationFrame(draw);
}
window.confettiCelebrate = confettiCelebrate;

// ── 3. SwipeRow — Touch swipe-left to reveal action buttons on list rows ──
export class SwipeRow {
  /**
   * @param {HTMLElement} row      - The <tr> or <div> row element
   * @param {Array} actions        - [{ label, color, icon, onClick }]
   * @param {Object} opts          - { threshold: 72 }
   */
  constructor(row, actions = [], opts = {}) {
    this.row = row;
    this.actions = actions;
    this.threshold = opts.threshold || 72;
    this._startX = 0;
    this._currentX = 0;
    this._dragging = false;
    this._actionsEl = null;
    this._init();
  }

  _init() {
    this.row.style.position = 'relative';
    this.row.style.overflow = 'hidden';
    this.row.style.transition = 'transform 0.2s ease';
    this.row.style.touchAction = 'pan-y';

    // Build hidden actions panel
    const panel = document.createElement('div');
    panel.className = 'swipe-row-actions';
    panel.style.cssText = `
      position:absolute;right:0;top:0;height:100%;
      display:flex;align-items:stretch;
      transform:translateX(100%);transition:transform 0.2s ease;
      z-index:2;
    `;
    this.actions.forEach(action => {
      const btn = document.createElement('button');
      btn.style.cssText = `
        background:${action.color || '#e17055'};color:#fff;border:none;
        padding:0 18px;font-size:0.82rem;font-weight:700;cursor:pointer;
        display:flex;flex-direction:column;align-items:center;justify-content:center;gap:2px;
        min-width:64px;
      `;
      btn.innerHTML = `<span style="font-size:1.2rem;">${action.icon || '⚡'}</span><span>${action.label || ''}</span>`;
      btn.addEventListener('click', (e) => { e.stopPropagation(); this.close(); action.onClick?.(); });
      panel.appendChild(btn);
    });
    this.row.appendChild(panel);
    this._actionsEl = panel;

    // Touch events
    this.row.addEventListener('touchstart', this._onStart.bind(this), { passive: true });
    this.row.addEventListener('touchmove',  this._onMove.bind(this),  { passive: true });
    this.row.addEventListener('touchend',   this._onEnd.bind(this));
  }

  _onStart(e) {
    if (!e.touches || e.touches.length !== 1) return;
    this._startX = e.touches[0].clientX;
    this._startY = e.touches[0].clientY;
    this._dragging = true;
    this._isSwiping = false;
  }

  _onMove(e) {
    if (!this._dragging || !e.touches || e.touches.length !== 1) return;
    const touch = e.touches[0];
    const dx = touch.clientX - this._startX;
    const dy = Math.abs(touch.clientY - this._startY);

    // If vertical movement is greater than horizontal, it's a page scroll: cancel swipe immediately!
    if (!this._isSwiping && dy > Math.abs(dx)) {
      this._dragging = false;
      return;
    }

    // Only start horizontal swipe if user moved horizontally by at least 12px and dx < 0
    if (dx < -12 && Math.abs(dx) > dy * 1.5) {
      this._isSwiping = true;
      this._currentX = dx;
      if (e.cancelable) e.preventDefault();
      const offset = Math.max(this._currentX, -this._actionsEl.offsetWidth);
      this.row.style.transform = `translateX(${offset}px)`;
    }
  }

  _onEnd() {
    this._dragging = false;
    if (this._isSwiping && this._currentX < -this.threshold) {
      this.open();
    } else {
      this.close();
    }
    this._isSwiping = false;
    this._currentX = 0;
  }

  open() {
    const w = this._actionsEl.offsetWidth;
    this.row.style.transform = `translateX(-${w}px)`;
    this._actionsEl.style.transform = 'translateX(0)';
    // Close on outside click
    setTimeout(() => {
      document.addEventListener('click', () => this.close(), { once: true });
    }, 50);
  }

  close() {
    this.row.style.transform = 'translateX(0)';
    this._actionsEl.style.transform = 'translateX(100%)';
  }

  /** Convenience: attach to all rows in a tbody */
  static attachToTable(tbody, getActions) {
    if (!tbody) return;
    tbody.querySelectorAll('tr').forEach(row => {
      if (!row._swipeRow) {
        row._swipeRow = new SwipeRow(row, getActions(row));
      }
    });
    // Re-attach when tbody changes
    const obs = new MutationObserver(() => {
      tbody.querySelectorAll('tr').forEach(row => {
        if (!row._swipeRow) {
          row._swipeRow = new SwipeRow(row, getActions(row));
        }
      });
    });
    obs.observe(tbody, { childList: true });
    return obs;
  }
}
window.SwipeRow = SwipeRow;
