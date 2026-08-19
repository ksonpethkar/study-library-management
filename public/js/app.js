import api from './api.js';
import Router from './router.js';
import { initSetupWizard, initLoginPage, initAppEvents } from './auth.js';
import { t } from './i18n.js';
import ShortcutManager from './shortcuts.js';
import { Toast, Modal, Loading } from './ui.js';
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
  }

  /**
   * Main initialization — checks setup status, auth, and routes
   */
  async init() {
    // Apply saved theme
    const savedTheme = localStorage.getItem('sl_theme') ||
      (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    this.setTheme(savedTheme);

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
  showApp() {
    this._show('app');

    // Wire up sidebar, header events only once
    if (!this._appEventsInit) {
      initAppEvents();
      document.getElementById('btn-pwa-header-install')?.addEventListener('click', () => promptPWAInstall());
      this._appEventsInit = true;
    }

    // Update user avatar initials
    if (store.user?.name) {
      const initials = store.user.name.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2);
      const avatar = document.getElementById('user-avatar');
      if (avatar) avatar.textContent = initials;
    }

    // Adapt sidebar for role (Student vs Admin/Staff)
    this.updateSidebarForRole();

    // Init search palette
    if (!this.searchPalette) {
      this.searchPalette = new SearchPalette();
    }

    // Init router
    if (!this.router) {
      this.initRouter();
    } else {
      this.router.start();
    }
  }

  /**
   * Filter and style sidebar according to user role
   */
  updateSidebarForRole() {
    const role = store.user?.role || 'admin';
    const isStudent = role === 'student';

    document.querySelectorAll('.sidebar-nav .nav-item').forEach(link => {
      const href = link.getAttribute('href');
      if (isStudent) {
        if (href === '#/portal' || href === '#/profile') {
          link.style.display = 'flex';
        } else {
          link.style.display = 'none';
        }
      } else {
        link.style.display = 'flex';
      }
    });

    if (isStudent && !document.querySelector('.sidebar-nav a[href="#/portal"]')) {
      const portalItem = document.createElement('a');
      portalItem.href = '#/portal';
      portalItem.className = 'nav-item active';
      portalItem.innerHTML = `
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 10v6M2 10l10-5 10 5-10 5z"></path><path d="M6 12v5c3 3 9 3 12 0v-5"></path></svg>
        <span>Student Dashboard</span>
      `;
      const nav = document.querySelector('.sidebar-nav');
      if (nav) nav.insertBefore(portalItem, nav.firstChild);
    }
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
      link.classList.toggle('active', link.getAttribute('href') === hash);
    });

    // Mobile bottom nav
    document.querySelectorAll('.mobile-nav .mobile-nav-item').forEach(link => {
      link.classList.toggle('active', link.getAttribute('href') === hash);
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

// Boot the application
document.addEventListener('DOMContentLoaded', () => {
  App.init();
});
