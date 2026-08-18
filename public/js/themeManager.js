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

  function applySystemTheme(theme) {
    const isDark = theme === 'dark';
    document.documentElement.setAttribute('data-theme', isDark ? 'dark' : 'light');
    if (document.body) document.body.setAttribute('data-theme', isDark ? 'dark' : 'light');
    
    document.documentElement.classList.toggle('dark-theme', isDark);
    if (document.body) document.body.classList.toggle('dark-theme', isDark);
    
    localStorage.setItem('sl_theme', isDark ? 'dark' : 'light');

    // Update all theme toggle buttons across the DOM
    document.querySelectorAll('#theme-btn, #theme-toggle-btn, #reg-theme-toggle, #portal-theme-btn, .theme-toggle-btn').forEach(btn => {
      const sunIcon = btn.querySelector('.sun-icon');
      const moonIcon = btn.querySelector('.moon-icon');
      
      if (sunIcon && moonIcon) {
        sunIcon.style.display = isDark ? 'inline-block' : 'none';
        moonIcon.style.display = isDark ? 'none' : 'inline-block';
      } else {
        btn.textContent = isDark ? '☀️' : '🌙';
      }
      btn.title = isDark ? 'Switch to Light Theme (Ctrl+D)' : 'Switch to Dark Theme (Ctrl+D)';
    });

    // Dispatch global theme change event
    window.dispatchEvent(new CustomEvent('theme-change', { detail: { theme: isDark ? 'dark' : 'light' } }));
  }

  function toggleSystemTheme() {
    const current = document.documentElement.getAttribute('data-theme') || getSystemTheme();
    const next = current === 'dark' ? 'light' : 'dark';
    applySystemTheme(next);
    return next;
  }

  // Restore theme immediately on script evaluation
  const initialTheme = getSystemTheme();
  document.documentElement.setAttribute('data-theme', initialTheme);
  document.documentElement.classList.toggle('dark-theme', initialTheme === 'dark');

  document.addEventListener('DOMContentLoaded', () => {
    applySystemTheme(getSystemTheme());

    // Event delegation for all theme toggle buttons
    document.addEventListener('click', (e) => {
      const btn = e.target.closest('#theme-btn, #theme-toggle-btn, #reg-theme-toggle, #portal-theme-btn, .theme-toggle-btn');
      if (btn) {
        e.preventDefault();
        e.stopPropagation();
        toggleSystemTheme();
      }
    });
  });

  window.getSystemTheme = getSystemTheme;
  window.applySystemTheme = applySystemTheme;
  window.toggleSystemTheme = toggleSystemTheme;
  window.toggleTheme = toggleSystemTheme;
  window.toggleStudentTheme = toggleSystemTheme;
  window.toggleRegisterTheme = toggleSystemTheme;
})();
