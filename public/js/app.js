import api from './api.js';
import Router from './router.js';
import { initSetupWizard, initLoginPage, initAppEvents } from './auth.js';
import { t } from './i18n.js';
import ShortcutManager from './shortcuts.js';
import { Toast, Modal, Loading } from './ui.js';
import { SearchPalette } from './search.js';
import { AudioFeedback } from './utils/audioFeedback.js';

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

        AudioFeedback.play('click');

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
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('sl_theme', theme);

    // Update header toggle icon and tooltip
    const themeBtn = document.getElementById('theme-toggle-btn');
    if (themeBtn) {
      if (theme === 'dark') {
        themeBtn.innerHTML = `
          <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="color: #fbbf24;">
            <circle cx="12" cy="12" r="5"></circle>
            <line x1="12" y1="1" x2="12" y2="3"></line>
            <line x1="12" y1="21" x2="12" y2="23"></line>
            <line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line>
            <line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line>
            <line x1="1" y1="12" x2="3" y2="12"></line>
            <line x1="21" y1="12" x2="23" y2="12"></line>
            <line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line>
            <line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line>
          </svg>
        `;
        themeBtn.title = 'Switch to Light Theme (Ctrl+D)';
      } else {
        themeBtn.innerHTML = `
          <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="color: #475569;">
            <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>
          </svg>
        `;
        themeBtn.title = 'Switch to Dark Theme (Ctrl+D)';
      }
    }
  }

  /**
   * Toggle between light and dark theme
   */
  toggleTheme() {
    this.setTheme(store.theme === 'light' ? 'dark' : 'light');
    Toast.info(store.theme === 'dark' ? '🌙 Dark Mode Activated' : '☀️ Light Mode Activated');
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
      this._appEventsInit = true;
    }

    // Update user avatar initials
    if (store.user?.name) {
      const initials = store.user.name.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2);
      const avatar = document.getElementById('user-avatar');
      if (avatar) avatar.textContent = initials;
    }

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

// Boot the application
document.addEventListener('DOMContentLoaded', () => {
  App.init();
});
