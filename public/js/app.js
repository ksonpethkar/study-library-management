import api from './api.js';
import Router from './router.js';
import { initSetupWizard, initLoginPage, initAppEvents } from './auth.js';
import { t } from './i18n.js';
import ShortcutManager from './shortcuts.js';
import { Toast, Modal, Loading, renderMobileBottomNav, VoiceSearch } from './ui.js';
import { SearchPalette } from './search.js';
import { AudioFeedback } from './utils/audioFeedback.js';
import { promptPWAInstall } from './pwaManager.js';

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
    // Apply saved theme
    const savedTheme = localStorage.getItem('sl_theme') ||
      (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    this.setTheme(savedTheme);

    // Init offline/online sync banner listeners
    this.initOfflineBanner();

    // Init keyboard shortcuts
    if (!this.shortcuts) {
      this.shortcuts = new ShortcutManager();
      this.shortcuts.register('Ctrl+D', () => this.toggleTheme(), 'Toggle Dark Mode');
      this.shortcuts.register('Ctrl+K', () => {
        if (this.searchPalette) this.searchPalette.open();
      }, 'Open Search');
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
            store.user = userData.data || userData;
            this.showApp();
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

    // Hide initial loading spinner
    const loadingEl = document.getElementById('app-loading');
    if (loadingEl) loadingEl.style.display = 'none';
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
  }

  /**
   * Show the login screen
   */
  showLogin() {
    this._show('login-page');
    initLoginPage();
  }

  /**
   * Show the main application (sidebar + content)
   */
  async showApp() {
    this._show('app');

    // Wire up sidebar, header events only once
    if (!this._appEventsInit) {
      initAppEvents();
      document.getElementById('btn-pwa-header-install')?.addEventListener('click', () => promptPWAInstall());
      this._appEventsInit = true;
    }

    // Update user avatar image or initials
    this.updateUserAvatarHeader();
    window.updateProfileAvatar = (newAvatarUrl) => {
      if (store.user) store.user.avatar = newAvatarUrl;
      this.updateUserAvatarHeader();
    };

    // Adapt sidebar for role (Student vs Admin/Staff) & render database config
    await this.updateSidebarForRole();

    // Render mobile bottom navigation bar based on user role
    renderMobileBottomNav(store.user?.role || 'staff');

    // Init search palette
    if (!this.searchPalette) {
      this.searchPalette = new SearchPalette();
    }

    // Wire up voice search button
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

    // Init router
    if (!this.router) {
      this.initRouter();
    } else {
      this.router.start();
    }
  }

  updateUserAvatarHeader() {
    const avatarEl = document.getElementById('user-avatar');
    if (!avatarEl) return;

    const imgUrl = store.user?.avatar || store.user?.photo;
    const name = store.user?.name || 'User';
    const initials = name.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2);

    if (imgUrl) {
      avatarEl.style.overflow = 'hidden';
      avatarEl.style.padding = '0';
      avatarEl.innerHTML = `<img src="${imgUrl}" alt="Avatar" style="width: 100%; height: 100%; object-fit: cover; border-radius: 50%; display: block;" onerror="this.remove(); document.getElementById('user-avatar').textContent='${initials}';">`;
    } else {
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
          let iconHtml = '';
          if (item.icon && item.icon.startsWith('<svg')) {
            iconHtml = item.icon;
          } else if (item.icon && item.icon.trim()) {
            iconHtml = `<span class="nav-icon-emoji" style="font-size: 1.15rem; width: 22px; display: inline-flex; align-items: center; justify-content: center;">${item.icon}</span>`;
          } else {
            iconHtml = defaultIcons[item.key] || '<span class="nav-icon-emoji">📌</span>';
          }

          return `
            <a href="${item.href}" class="nav-item ${isActive ? 'active' : ''}" data-key="${item.key}">
              ${iconHtml}
              <span ${item.i18nKey ? `data-i18n="${item.i18nKey}"` : ''}>${item.label}</span>
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
    localStorage.removeItem('sl_token');
    store.user = null;
    this.showLogin();
  }

  /** Get current user from store */
  getUser() { return store.user; }

  /** Get JWT token from localStorage */
  getToken() { return localStorage.getItem('sl_token'); }

  /** Get global store */
  getStore() { return store; }

  /**
   * Transition to a page with animation
   */
  showPage(pageId, renderFn) {
    const content = document.getElementById('page-content');
    if (!content) return;

    // Update active nav links
    this.updateActiveNav(pageId);

    const doRender = async () => {
      const result = await renderFn(content);
      // If render returns a DOM element different from content, append it
      if (result instanceof HTMLElement && result !== content) {
        content.innerHTML = '';
        content.appendChild(result);
      }
    };

    if (document.startViewTransition) {
      document.startViewTransition(() => doRender());
    } else {
      content.style.opacity = '0';
      content.style.transform = 'translateY(8px)';
      setTimeout(async () => {
        await doRender();
        content.style.opacity = '1';
        content.style.transform = 'translateY(0)';
      }, 150);
    }
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
      'attendance', 'shifts', 'branches', 'reports', 'expenses', 'operations', 'portal', 'settings', 'profile'
    ];

    pages.forEach(page => {
      this.router.addRoute(`#/${page}`, async () => {
        const content = document.getElementById('page-content');
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
        }
      });
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

// Boot the application
document.addEventListener('DOMContentLoaded', () => {
  App.init();
});
