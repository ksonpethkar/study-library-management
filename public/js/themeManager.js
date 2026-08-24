/**
 * Study Library Management System — Unified Theme Engine (themeManager.js)
 * Handles System Auto / Dark / Light theme mode switching, system color scheme listeners,
 * instant theme restoration, state sync & dropdown/button UI updates across all pages.
 */
(function() {
  const ThemeManager = {
    getMode() {
      const savedMode = localStorage.getItem('sl_theme_mode');
      if (savedMode === 'system' || savedMode === 'dark' || savedMode === 'light' || savedMode === 'auto') {
        return savedMode === 'auto' ? 'system' : savedMode;
      }
      const legacyTheme = localStorage.getItem('sl_theme');
      if (legacyTheme === 'dark' || legacyTheme === 'light') {
        return legacyTheme;
      }
      return 'system';
    },

    getEffectiveTheme(mode = this.getMode()) {
      const norm = mode === 'auto' ? 'system' : mode;
      if (norm === 'dark') return 'dark';
      if (norm === 'light') return 'light';
      return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    },

    setThemeMode(mode, showToast = false) {
      let normMode = mode === 'auto' ? 'system' : mode;
      if (normMode !== 'system' && normMode !== 'dark' && normMode !== 'light') {
        normMode = 'system';
      }

      localStorage.setItem('sl_theme_mode', normMode);

      const effectiveTheme = this.getEffectiveTheme(normMode);
      localStorage.setItem('sl_theme', effectiveTheme);

      this.applyTheme(effectiveTheme, normMode);

      if (showToast && window.Toast && typeof window.Toast.info === 'function') {
        const toastMessages = {
          system: '💻 System Auto Theme Activated',
          dark: '🌙 Dark Mode Activated',
          light: '☀️ Light Mode Activated'
        };
        window.Toast.info(toastMessages[normMode] || 'Theme Mode Updated');
      }

      return effectiveTheme;
    },

    applyTheme(effectiveTheme, mode = this.getMode()) {
      const normMode = mode === 'auto' ? 'system' : mode;
      const isDark = effectiveTheme === 'dark';

      document.documentElement.setAttribute('data-theme', isDark ? 'dark' : 'light');
      if (document.body) {
        document.body.setAttribute('data-theme', isDark ? 'dark' : 'light');
      }

      document.documentElement.classList.toggle('dark-theme', isDark);
      if (document.body) {
        document.body.classList.toggle('dark-theme', isDark);
      }

      this.updateUI(normMode, isDark);

      window.dispatchEvent(new CustomEvent('theme-change', {
        detail: { theme: effectiveTheme, mode: normMode }
      }));
    },

    updateUI(mode, isDark) {
      // 1. Highlight active dropdown item
      document.querySelectorAll('.theme-option, [data-theme-mode]').forEach(opt => {
        const optMode = opt.getAttribute('data-theme-mode');
        if (optMode) {
          const isActive = optMode === mode;
          opt.classList.toggle('active', isActive);
          opt.setAttribute('aria-selected', isActive ? 'true' : 'false');
        }
      });

      // 2. Update theme toggle buttons icon and title
      const iconMap = {
        system: '💻',
        dark: '🌙',
        light: '☀️'
      };

      const titleMap = {
        system: 'Theme: System Auto',
        dark: 'Theme: Dark Mode',
        light: 'Theme: Light Mode'
      };

      document.querySelectorAll('#theme-btn, #theme-toggle-btn, #reg-theme-toggle, #portal-theme-btn, .theme-toggle-btn').forEach(btn => {
        if (!btn) return;

        if (btn.id === 'theme-toggle-btn' || btn.classList.contains('action-btn')) {
          if (mode === 'system') {
            btn.innerHTML = `
              <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="color: var(--color-primary, #6c5ce7);">
                <rect x="2" y="3" width="20" height="14" rx="2" ry="2"></rect>
                <line x1="8" y1="21" x2="16" y2="21"></line>
                <line x1="12" y1="17" x2="12" y2="21"></line>
              </svg>`;
          } else if (isDark) {
            btn.innerHTML = `
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
              </svg>`;
          } else {
            btn.innerHTML = `
              <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="color: #475569;">
                <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>
              </svg>`;
          }
          btn.title = titleMap[mode] || 'Theme Options';
        } else {
          btn.textContent = iconMap[mode] || (isDark ? '🌙' : '☀️');
          btn.title = titleMap[mode] || 'Theme Options';
        }
      });
    },

    cycleTheme(showToast = true) {
      const currentMode = this.getMode();
      let nextMode = 'dark';
      if (currentMode === 'system') nextMode = 'dark';
      else if (currentMode === 'dark') nextMode = 'light';
      else if (currentMode === 'light') nextMode = 'system';
      return this.setThemeMode(nextMode, showToast);
    },

    initSystemListener() {
      if (!window.matchMedia) return;
      const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
      const handleSystemChange = () => {
        if (this.getMode() === 'system') {
          const effectiveTheme = this.getEffectiveTheme('system');
          localStorage.setItem('sl_theme', effectiveTheme);
          this.applyTheme(effectiveTheme, 'system');
        }
      };

      if (mediaQuery.addEventListener) {
        mediaQuery.addEventListener('change', handleSystemChange);
      } else if (mediaQuery.addListener) {
        mediaQuery.addListener(handleSystemChange);
      }
    }
  };

  // 1. Immediate initialization on script load to prevent dark/light flash
  const initialMode = ThemeManager.getMode();
  const initialEffective = ThemeManager.getEffectiveTheme(initialMode);
  document.documentElement.setAttribute('data-theme', initialEffective);
  document.documentElement.classList.toggle('dark-theme', initialEffective === 'dark');

  // Listen to OS system theme changes
  ThemeManager.initSystemListener();

  // 2. DOM initialization & event delegation
  const initThemeDOM = () => {
    const mode = ThemeManager.getMode();
    ThemeManager.setThemeMode(mode, false);
  };
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initThemeDOM);
  } else {
    initThemeDOM();
  }

  // Event delegation for theme choices & dropdown triggers
  document.addEventListener('click', (e) => {
    // Handle click on dropdown item with [data-theme-mode]
    const optionBtn = e.target.closest('[data-theme-mode]');
      if (optionBtn) {
        e.preventDefault();
        e.stopPropagation();
        const selectedMode = optionBtn.getAttribute('data-theme-mode');
        ThemeManager.setThemeMode(selectedMode, true);
        document.querySelectorAll('.dropdown.open, .dropdown.active').forEach(d => {
          if (d.id === 'theme-dropdown' || d.id === 'landing-theme-dropdown' || d.querySelector('[data-theme-mode]')) {
            d.classList.remove('open', 'active');
          }
        });
        return;
      }

      // Handle click on theme toggle trigger button
      const toggleBtn = e.target.closest('#theme-btn, #theme-toggle-btn, #reg-theme-toggle, #portal-theme-btn, .theme-toggle-btn');
      if (toggleBtn) {
        const parentDropdown = toggleBtn.closest('.dropdown');
        if (parentDropdown) {
          e.preventDefault();
          e.stopPropagation();
          document.querySelectorAll('.dropdown.open, .dropdown.active').forEach(d => {
            if (d !== parentDropdown) d.classList.remove('open', 'active');
          });
          parentDropdown.classList.toggle('open');
          parentDropdown.classList.toggle('active');
        } else {
          e.preventDefault();
          e.stopPropagation();
          ThemeManager.cycleTheme(true);
        }
      } else {
        // Click outside closes theme dropdowns
        document.querySelectorAll('.dropdown.open, .dropdown.active').forEach(d => {
          if (d.id === 'theme-dropdown' || d.id === 'landing-theme-dropdown' || d.querySelector('[data-theme-mode]')) {
            d.classList.remove('open', 'active');
          }
        });
      }
    });

  function updateDynamicFaviconAndTitle(profile) {
    if (!profile) return;

    const iconUrl = profile.favicon || profile.logo;
    if (iconUrl) {
      let favEl = document.getElementById('dynamic-favicon');
      if (!favEl) {
        favEl = document.createElement('link');
        favEl.id = 'dynamic-favicon';
        favEl.rel = 'icon';
        document.head.appendChild(favEl);
      }
      favEl.href = iconUrl;

      let appleEl = document.getElementById('dynamic-apple-icon');
      if (!appleEl) {
        appleEl = document.createElement('link');
        appleEl.id = 'dynamic-apple-icon';
        appleEl.rel = 'apple-touch-icon';
        document.head.appendChild(appleEl);
      }
      appleEl.href = iconUrl;
    }

    if (profile) {
      try {
        localStorage.setItem('sl_public_profile_cache', JSON.stringify(profile));
      } catch(e) {}

      if (window.store) {
        if (!window.store.settings) window.store.settings = {};
        if (!window.store.settings.businessProfile) window.store.settings.businessProfile = {};
        Object.assign(window.store.settings.businessProfile, profile);
        if (!window.store.profile) window.store.profile = {};
        Object.assign(window.store.profile, profile);
      }

      if (profile.businessName) {
        if (document.title) {
          document.title = document.title.replace(/Study Library|StudyLib|The Cozy Corner Centre/g, profile.businessName);
        }
        
        const brandElements = ['lib-title', 'lib-name', 'sidebar-org-name', 'nav-brand-name', 'drawer-brand-name', 'footer-org-name', 'kiosk-lib-name', 'footer-copy-name'];
        brandElements.forEach(id => {
          const el = document.getElementById(id);
          if (el) el.textContent = profile.businessName;
        });
      }

      if (profile.logo) {
        const logoContainers = [
          'sidebar-logo', 'sys-preloader-icon', 'nav-logo-icon', 'drawer-logo',
          'lib-logo-icon', 'kiosk-logo-container', 'portal-brand-logo', 'login-logo-container', 'footer-logo'
        ];
        logoContainers.forEach(id => {
          const el = document.getElementById(id);
          if (el) {
            el.innerHTML = `<img src="${profile.logo}" alt="Logo" style="max-height: 100%; max-width: 100%; object-fit: contain; border-radius: inherit; display: block; margin: 0 auto;">`;
            if (id === 'sidebar-logo') {
              el.style.display = 'flex';
              el.style.alignItems = 'center';
              el.style.justifyContent = 'center';
            }
          }
        });
        document.querySelectorAll('.app-brand-logo, .dynamic-brand-logo, .business-logo-img').forEach(img => {
          if (img.tagName === 'IMG') {
            img.src = profile.logo;
            img.style.display = '';
          }
        });
      }
    }
  }

  fetch('/api/landing')
    .then(r => r.json())
    .then(d => {
      if (d.data?.businessProfile) {
        updateDynamicFaviconAndTitle(d.data.businessProfile);
      }
    })
    .catch(() => {});

  window.dismissSystemPreloader = function() {
    const p = document.getElementById('system-preloader') || document.getElementById('landing-preloader') || document.getElementById('app-loading');
    if (p) {
      p.style.pointerEvents = 'none';
      p.style.opacity = '0';
      p.style.visibility = 'hidden';
      p.style.display = 'none';
      try { p.remove(); } catch(e) {}
    }
  };

  // Immediate and fail-safe auto-dismiss
  if (document.readyState === 'complete') {
    window.dismissSystemPreloader();
  } else {
    window.addEventListener('DOMContentLoaded', window.dismissSystemPreloader);
    window.addEventListener('load', window.dismissSystemPreloader);
  }

  window.ThemeManager = ThemeManager;
  window.getSystemTheme = () => ThemeManager.getEffectiveTheme();
  window.applySystemTheme = (theme) => ThemeManager.setThemeMode(theme);
  window.toggleSystemTheme = (showToast = true) => ThemeManager.cycleTheme(showToast);
  window.toggleTheme = (showToast = true) => ThemeManager.cycleTheme(showToast);
  window.toggleStudentTheme = (showToast = true) => ThemeManager.cycleTheme(showToast);
  window.toggleRegisterTheme = (showToast = true) => ThemeManager.cycleTheme(showToast);
  window.updateDynamicFaviconAndTitle = updateDynamicFaviconAndTitle;
})();

