/**
 * Study Library Management System — Unified Theme Engine (themeManager.js)
 * Handles 1-click theme toggling, instant theme restoration, state sync & button icon updates across all pages.
 */
(function() {
  function getSystemTheme() {
    const saved = localStorage.getItem('sl_theme');
    if (saved === 'dark' || saved === 'light') return saved;
    return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }

  function updateThemeButton(btn, isDark) {
    if (!btn) return;
    
    // Check if button is SVG action button (like header #theme-toggle-btn)
    if (btn.id === 'theme-toggle-btn' || btn.classList.contains('action-btn')) {
      if (isDark) {
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
        btn.title = 'Switch to Light Theme (Ctrl+D)';
      } else {
        btn.innerHTML = `
          <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="color: #475569;">
            <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>
          </svg>`;
        btn.title = 'Switch to Dark Theme (Ctrl+D)';
      }
    } else {
      btn.textContent = isDark ? '☀️' : '🌙';
      btn.title = isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode';
    }
  }

  function applySystemTheme(theme) {
    const isDark = theme === 'dark';
    document.documentElement.setAttribute('data-theme', isDark ? 'dark' : 'light');
    if (document.body) document.body.setAttribute('data-theme', isDark ? 'dark' : 'light');
    
    document.documentElement.classList.toggle('dark-theme', isDark);
    if (document.body) document.body.classList.toggle('dark-theme', isDark);
    
    localStorage.setItem('sl_theme', isDark ? 'dark' : 'light');

    // Update all theme toggle buttons across the DOM
    document.querySelectorAll('#theme-btn, #theme-toggle-btn, #reg-theme-toggle, #portal-theme-btn, .theme-toggle-btn').forEach(btn => {
      updateThemeButton(btn, isDark);
    });

    // Dispatch global theme change event
    window.dispatchEvent(new CustomEvent('theme-change', { detail: { theme: isDark ? 'dark' : 'light' } }));
  }

  function toggleSystemTheme(showToast = true) {
    const current = document.documentElement.getAttribute('data-theme') || getSystemTheme();
    const next = current === 'dark' ? 'light' : 'dark';
    applySystemTheme(next);

    if (showToast) {
      if (window.Toast && typeof window.Toast.info === 'function') {
        window.Toast.info(next === 'dark' ? '🌙 Dark Mode Activated' : '☀️ Light Mode Activated');
      }
    }
    return next;
  }

  // Restore theme immediately on script evaluation
  const initialTheme = getSystemTheme();
  document.documentElement.setAttribute('data-theme', initialTheme);
  document.documentElement.classList.toggle('dark-theme', initialTheme === 'dark');

  document.addEventListener('DOMContentLoaded', () => {
    applySystemTheme(getSystemTheme());

    // Unified Event delegation for all theme toggle buttons
    document.addEventListener('click', (e) => {
      const btn = e.target.closest('#theme-btn, #theme-toggle-btn, #reg-theme-toggle, #portal-theme-btn, .theme-toggle-btn');
      if (btn) {
        e.preventDefault();
        e.stopPropagation();
        toggleSystemTheme(true);
      }
    });
  });

  function updateDynamicFaviconAndTitle(profile) {
    if (!profile) return;

    // 1. Update Favicon Icon across Browser Tab
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

    // 2. Update Browser Tab Title if businessName exists
    if (profile.businessName && document.title) {
      if (document.title.includes('Study Library') || document.title.includes('StudyLib')) {
        document.title = document.title.replace(/Study Library|StudyLib/g, profile.businessName);
      }
    }
  }

  // Auto-fetch branding profile on boot for dynamic favicon
  fetch('/api/landing')
    .then(r => r.json())
    .then(d => {
      if (d.data?.businessProfile) {
        updateDynamicFaviconAndTitle(d.data.businessProfile);
      }
    })
    .catch(() => {});

  window.getSystemTheme = getSystemTheme;
  window.applySystemTheme = applySystemTheme;
  window.toggleSystemTheme = toggleSystemTheme;
  window.toggleTheme = toggleSystemTheme;
  window.toggleStudentTheme = toggleSystemTheme;
  window.toggleRegisterTheme = toggleSystemTheme;
  window.updateDynamicFaviconAndTitle = updateDynamicFaviconAndTitle;
})();
