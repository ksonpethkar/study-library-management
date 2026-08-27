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
      // 1. Highlight active dropdown items
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
        dark: '☀️',
        light: '🌙',
        system: isDark ? '☀️' : '🌙'
      };

      const titleMap = {
        dark: 'Switch to Light Mode (Ctrl+D)',
        light: 'Switch to Dark Mode (Ctrl+D)',
        system: isDark ? 'Switch to Light Mode (Ctrl+D)' : 'Switch to Dark Mode (Ctrl+D)'
      };

      document.querySelectorAll('#theme-btn, #theme-toggle-btn, #reg-theme-toggle, #portal-theme-btn, .theme-toggle-btn').forEach(btn => {
        if (!btn) return;

        if (btn.id === 'theme-toggle-btn' || btn.classList.contains('action-btn')) {
          if (isDark) {
            // In Dark Mode: Show Sun icon to switch to Light
            btn.innerHTML = `
              <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="color: #fbbf24; cursor: pointer; display: block; margin: auto;">
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
            btn.title = 'Switch to Light Mode (Ctrl+D)';
          } else {
            // In Light Mode: Show Moon icon to switch to Dark
            btn.innerHTML = `
              <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="color: #475569; cursor: pointer; display: block; margin: auto;">
                <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>
              </svg>`;
            btn.title = 'Switch to Dark Mode (Ctrl+D)';
          }
        } else {
          btn.textContent = isDark ? '☀️' : '🌙';
          btn.title = isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode';
        }
      });
    },

    toggleTheme(showToast = true) {
      const currentEff = this.getEffectiveTheme();
      const nextTheme = currentEff === 'dark' ? 'light' : 'dark';
      if (typeof navigator !== 'undefined' && navigator.vibrate) {
        try { navigator.vibrate(20); } catch(e) {}
      }
      return this.setThemeMode(nextTheme, showToast);
    },

    cycleTheme(showToast = true) {
      return this.toggleTheme(showToast);
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

    // Direct listener binding for maximum reliability
    document.querySelectorAll('#theme-btn, #theme-toggle-btn, #reg-theme-toggle, #portal-theme-btn, .theme-toggle-btn').forEach(btn => {
      btn.onclick = (e) => {
        e.preventDefault();
        e.stopPropagation();
        ThemeManager.toggleTheme(true);
      };
    });
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initThemeDOM);
  } else {
    initThemeDOM();
  }

  // Event delegation for theme choices & 1-click toggle triggers
  document.addEventListener('click', (e) => {
    // Handle click on dropdown item with [data-theme-mode]
    const optionBtn = e.target.closest('[data-theme-mode]');
    if (optionBtn) {
      e.preventDefault();
      e.stopPropagation();
      const selectedMode = optionBtn.getAttribute('data-theme-mode');
      ThemeManager.setThemeMode(selectedMode, true);
      document.querySelectorAll('.dropdown.open, .dropdown.active').forEach(d => {
        d.classList.remove('open', 'active');
      });
      return;
    }

    // Handle click on theme toggle trigger button -> Direct 1-Click Toggle
    const toggleBtn = e.target.closest('#theme-btn, #theme-toggle-btn, #reg-theme-toggle, #portal-theme-btn, .theme-toggle-btn');
    if (toggleBtn) {
      e.preventDefault();
      e.stopPropagation();
      ThemeManager.toggleTheme(true);
      return;
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
        
        const brandElements = ['lib-name', 'sidebar-org-name', 'nav-brand-name', 'drawer-brand-name', 'footer-org-name', 'kiosk-lib-name', 'footer-copy-name', 'sys-preloader-name', 'slip-business-name'];
        brandElements.forEach(id => {
          const el = document.getElementById(id);
          if (el) el.textContent = profile.businessName;
        });
      }

      if (profile.tagline) {
        const taglineElements = ['footer-tagline', 'footer-bottom-tagline', 'slip-business-tagline'];
        taglineElements.forEach(id => {
          const el = document.getElementById(id);
          if (el) el.textContent = profile.tagline;
        });
      }

      if (profile.address) {
        const addrElements = ['footer-address', 'map-card-address'];
        addrElements.forEach(id => {
          const el = document.getElementById(id);
          if (el) el.textContent = profile.address;
        });
      }

      if (profile.phone) {
        const phoneEl = document.getElementById('footer-phone');
        if (phoneEl) phoneEl.textContent = profile.phone;
      }

      try {
        window.dispatchEvent(new CustomEvent('sl:branding-applied', { detail: profile }));
      } catch(e) {}

      if (profile.logo) {
        // 1. Compact Navbar/Sidebar Icons
        const compactIcons = ['sidebar-logo', 'sys-preloader-icon', 'nav-logo-icon', 'drawer-logo', 'footer-logo'];
        compactIcons.forEach(id => {
          const el = document.getElementById(id);
          if (el) {
            const isSidebar = id === 'sidebar-logo';
            const isFooter = id === 'footer-logo';
            const size = isFooter ? '42px' : (isSidebar ? '40px' : '36px');
            el.style.width = size;
            el.style.height = size;
            el.style.maxWidth = size;
            el.style.maxHeight = size;
            el.style.display = 'inline-flex';
            el.style.alignItems = 'center';
            el.style.justifyContent = 'center';
            el.style.overflow = 'hidden';
            el.innerHTML = `<img src="${profile.logo}" alt="Logo" style="width: 100%; height: 100%; max-height: ${size}; max-width: ${size}; object-fit: contain; border-radius: inherit; display: block; margin: 0 auto;">`;
          }
        });

        // 2. Hero Logo Containers (Registration, Student Login, Kiosk, Student Portal) - NEVER crop!
        const heroContainers = ['lib-logo-icon', 'kiosk-logo-container', 'portal-brand-logo', 'login-logo-container'];
        heroContainers.forEach(id => {
          const el = document.getElementById(id);
          if (el) {
            el.style.width = 'auto';
            el.style.height = 'auto';
            el.style.maxWidth = '180px';
            el.style.maxHeight = '85px';
            el.style.display = 'inline-flex';
            el.style.alignItems = 'center';
            el.style.justifyContent = 'center';
            el.style.overflow = 'visible';
            el.innerHTML = `<img src="${profile.logo}" alt="Logo" class="reg-logo-img" style="max-height: 78px; max-width: 160px; width: auto; height: auto; object-fit: contain; border-radius: 12px; background: #ffffff; padding: 6px; box-shadow: 0 4px 14px rgba(0,0,0,0.15); display: block; margin: 0 auto;">`;
          }
        });
        document.querySelectorAll('.app-brand-logo, .dynamic-brand-logo, .business-logo-img').forEach(img => {
          if (img.tagName === 'IMG') {
            img.src = profile.logo;
            img.style.display = '';
          }
        });
      }

      if (profile.bannerImage) {
        const bannerElements = [
          'admission-main-header', 'portal-welcome-banner', 'landing-hero-backdrop', 'kiosk-header'
        ];
        bannerElements.forEach(id => {
          const el = document.getElementById(id) || document.querySelector(`.${id}`);
          if (el) {
            el.style.backgroundImage = `linear-gradient(135deg, rgba(108, 92, 231, 0.82), rgba(0, 184, 148, 0.82)), url("${profile.bannerImage}")`;
            el.style.backgroundSize = 'cover';
            el.style.backgroundPosition = 'center';
          }
        });
        document.querySelectorAll('.app-banner-bg, .dynamic-banner-img').forEach(el => {
          if (el.tagName === 'IMG') {
            el.src = profile.bannerImage;
          } else {
            el.style.backgroundImage = `linear-gradient(rgba(0,0,0,0.4), rgba(0,0,0,0.6)), url("${profile.bannerImage}")`;
            el.style.backgroundSize = 'cover';
            el.style.backgroundPosition = 'center';
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

