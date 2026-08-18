import api from './api.js';
import { Toast, Modal, Loading, escapeHTML } from './ui.js';

// We import App lazily to avoid circular dependency at module load time
let _App = null;
async function getApp() {
  if (!_App) {
    const mod = await import('./app.js');
    _App = mod.App;
  }
  return _App;
}

/**
 * Initialize the multi-step setup wizard
 */
export function initSetupWizard() {
  let currentStep = 1;

  const steps = [
    document.getElementById('wizard-step-1'),
    document.getElementById('wizard-step-2'),
    document.getElementById('wizard-step-3')
  ];
  const stepIndicators = document.querySelectorAll('.wizard-step');

  function showStep(num) {
    steps.forEach((s, i) => {
      if (s) s.style.display = i === num - 1 ? '' : 'none';
    });
    stepIndicators.forEach((el, i) => {
      el.classList.toggle('active', i < num);
    });
    currentStep = num;
  }

  // Step 1 -> Step 2
  document.getElementById('btn-wizard-next-1')?.addEventListener('click', () => {
    const name = document.getElementById('setup-business-name')?.value?.trim();
    if (!name) {
      Toast.warning('Please enter your business name');
      document.getElementById('setup-business-name')?.focus();
      return;
    }
    showStep(2);
  });

  // Step 2 -> Step 1 (back)
  document.getElementById('btn-wizard-back-2')?.addEventListener('click', () => {
    showStep(1);
  });

  // Step 2 -> Submit setup -> Step 3
  document.getElementById('btn-wizard-next-2')?.addEventListener('click', async () => {
    const businessName = document.getElementById('setup-business-name')?.value?.trim();
    const businessPhone = document.getElementById('setup-business-phone')?.value?.trim();
    const businessEmail = document.getElementById('setup-business-email')?.value?.trim();
    const adminName = document.getElementById('setup-admin-name')?.value?.trim();
    const adminEmail = document.getElementById('setup-admin-email')?.value?.trim();
    const password = document.getElementById('setup-admin-pwd')?.value;
    const confirmPassword = document.getElementById('setup-admin-pwd-confirm')?.value;

    // Validations
    if (!adminName) { Toast.warning('Please enter admin name'); return; }
    if (!adminEmail) { Toast.warning('Please enter admin email'); return; }
    if (!password || password.length < 6) { Toast.warning('Password must be at least 6 characters'); return; }
    if (password !== confirmPassword) { Toast.error('Passwords do not match'); return; }

    const btn = document.getElementById('btn-wizard-next-2');
    Loading.button(btn, true);

    try {
      const res = await api.post('/api/auth/setup', {
        name: adminName,
        email: adminEmail,
        password,
        businessName: businessName || 'Study Library',
        phone: businessPhone || ''
      });
      localStorage.setItem('sl_token', res.data.token);
      Toast.success('Setup completed successfully!');
      showStep(3);
    } catch (err) {
      Toast.error(err.message || 'Setup failed. Please try again.');
    } finally {
      Loading.button(btn, false);
    }
  });

  // Step 3 -> Go to Dashboard
  document.getElementById('btn-wizard-finish')?.addEventListener('click', async () => {
    const App = await getApp();
    App.init(); // Re-init with token now present
  });
}

/**
 * Initialize the login page
 */
export function initLoginPage() {
  // If URL has #/portal or is student portal route, redirect unauthenticated users to /student-login
  if (window.location.hash.includes('portal') || window.location.search.includes('portal')) {
    const token = localStorage.getItem('sl_token');
    if (!token) {
      window.location.href = '/student-login';
      return;
    }
  }

  // Password toggle
  const pwdToggle = document.getElementById('toggle-pwd-btn');
  if (pwdToggle && !pwdToggle.dataset.bound) {
    pwdToggle.dataset.bound = 'true';
    pwdToggle.addEventListener('click', () => {
      const pwdInput = document.getElementById('login-password');
      if (pwdInput) pwdInput.type = pwdInput.type === 'password' ? 'text' : 'password';
    });
  }

  // Admin Login Submit
  const loginForm = document.getElementById('login-form');
  if (loginForm && !loginForm.dataset.bound) {
    loginForm.dataset.bound = 'true';
    loginForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      const email = document.getElementById('login-email')?.value?.trim();
      const password = document.getElementById('login-password')?.value;

      if (!email || !password) {
        Toast.warning('Please enter email and password');
        return;
      }

      const btn = document.getElementById('login-submit-btn');
      Loading.button(btn, true);

      try {
        const res = await api.post('/api/auth/login', { email, password });
        localStorage.setItem('sl_token', res.data.token);
        Toast.success('Logged in successfully');
        const App = await getApp();
        App.init(); // Re-init with token now present
      } catch (err) {
        Toast.error(err.message || 'Login failed. Check your credentials.');
      } finally {
        Loading.button(btn, false);
      }
    });
  }

  // Admin Google SSO Button Handler
  document.getElementById('admin-google-sso-btn')?.addEventListener('click', async () => {
    const email = prompt('Enter your authorized Staff / Owner Google Email:');
    if (!email || !email.includes('@')) return;

    try {
      const res = await api.post('/api/auth/google-login', { email, portalType: 'admin' });
      if (res.success && res.data?.token) {
        localStorage.setItem('sl_token', res.data.token);
        Toast.success(`Welcome back via Google Admin SSO, ${res.data.user?.name || 'Staff'}!`);
        const App = await getApp();
        App.init();
      } else {
        Toast.error(res.message || 'Google Admin SSO failed.');
      }
    } catch (err) {
      Toast.error(err.message || 'Google SSO verification failed.');
    }
  });

  // Admin Passkey Button Handler
  document.getElementById('admin-passkey-btn')?.addEventListener('click', async () => {
    const email = document.getElementById('login-email')?.value?.trim() || prompt('Enter your Staff Email / Phone for Security Key verification:');
    if (!email) return;

    try {
      const res = await api.post('/api/auth/passkey-login', { identifier: email, portalType: 'admin' });
      if (res.success && res.data?.token) {
        localStorage.setItem('sl_token', res.data.token);
        Toast.success(`Hardware Passkey Verified! Welcome, ${res.data.user?.name || 'Staff'}.`);
        const App = await getApp();
        App.init();
      } else {
        Toast.error(res.message || 'Passkey verification failed.');
      }
    } catch (err) {
      Toast.error(err.message || 'Passkey failed.');
    }
  });

  // Admin Credentials Recovery Helper
  window.requestAdminCredentialsRecovery = async function(e) {
    if (e) e.preventDefault();
    const existingEmail = document.getElementById('login-email')?.value?.trim();
    const identifier = prompt('Enter your Staff / Owner Email or Phone for account recovery:', existingEmail || '');
    if (!identifier) return;

    try {
      const res = await api.post('/api/auth/forgot-password', { identifier, portalType: 'admin' });
      if (res.success && res.data?.whatsappUrl) {
        Toast.success(res.message || 'Recovery request prepared!');
        setTimeout(() => {
          window.open(res.data.whatsappUrl, '_blank');
        }, 600);
      } else {
        Toast.error(res.message || 'Staff recovery failed.');
      }
    } catch (err) {
      Toast.error(err.message || 'Network error during recovery.');
    }
  };
}

/**
 * Initialize app-level event listeners (sidebar, header, theme, logout, etc.)
 */
export async function initAppEvents() {
  // Sidebar collapse toggle
  document.getElementById('sidebar-collapse-btn')?.addEventListener('click', () => {
    document.getElementById('sidebar')?.classList.toggle('collapsed');
  });

  // Sidebar logout button
  document.getElementById('sidebar-logout-btn')?.addEventListener('click', async () => {
    const App = (await import('./app.js')).default || await getApp();
    App.logout();
  });
  
  // Load org branding into sidebar
  try {
    const token = localStorage.getItem('sl_token');
    if (token) {
      const res = await fetch('/api/settings', { headers: { 'Authorization': `Bearer ${token}` } });
      const data = await res.json();
      if (data.success && data.data?.businessProfile) {
        const bp = data.data.businessProfile;
        const nameEl = document.getElementById('sidebar-org-name');
        const logoEl = document.getElementById('sidebar-logo');
        if (nameEl && bp.businessName) {
          nameEl.textContent = bp.businessName;
          nameEl.title = bp.businessName;
        }
        if (logoEl && bp.logo) {
          logoEl.innerHTML = `<img src="${bp.logo}" alt="Logo" style="width: 38px; height: 38px; border-radius: 8px; object-fit: cover;">`;
        }
      }
    }
  } catch(e) { console.warn('Could not load sidebar branding', e); }

  loadSidebarConfig();

  // Mobile menu toggle
  document.getElementById('mobile-menu-btn')?.addEventListener('click', () => {
    document.getElementById('sidebar')?.classList.toggle('mobile-open');
    document.getElementById('sidebar-overlay')?.classList.toggle('visible');
  });

  // Sidebar overlay click (close mobile sidebar)
  document.getElementById('sidebar-overlay')?.addEventListener('click', () => {
    document.getElementById('sidebar')?.classList.remove('mobile-open');
    document.getElementById('sidebar-overlay')?.classList.remove('visible');
  });

  // Logout button
  document.getElementById('logout-btn')?.addEventListener('click', async () => {
    const App = await getApp();
    App.logout();
  });

  // User avatar dropdown toggle
  const profileDropdown = document.getElementById('profile-dropdown');
  const langDropdown = document.getElementById('lang-dropdown');

  document.getElementById('user-avatar')?.addEventListener('click', (e) => {
    e.stopPropagation();
    langDropdown?.classList.remove('open', 'active');
    profileDropdown?.classList.toggle('open');
    profileDropdown?.classList.toggle('active');
  });

  // Language dropdown toggle & switch
  document.getElementById('lang-toggle-btn')?.addEventListener('click', (e) => {
    e.stopPropagation();
    profileDropdown?.classList.remove('open', 'active');
    langDropdown?.classList.toggle('open');
    langDropdown?.classList.toggle('active');
  });

  document.querySelectorAll('.lang-option').forEach(btn => {
    btn.addEventListener('click', async (e) => {
      e.stopPropagation();
      const lang = btn.getAttribute('data-lang');
      const { setLanguage } = await import('./i18n.js');
      setLanguage(lang);
      langDropdown?.classList.remove('open', 'active');
      Toast.success(lang === 'hi' ? 'भाषा बदलकर हिन्दी कर दी गई' : lang === 'mr' ? 'भाषा मराठी मध्ये बदलली' : lang === 'ta' ? 'மொழி தமிழுக்கு மாற்றப்பட்டது' : 'Language switched to English');
    });
  });

  document.addEventListener('click', () => {
    profileDropdown?.classList.remove('open', 'active');
    langDropdown?.classList.remove('open', 'active');
  });

  // Apply initial translations to DOM on boot
  import('./i18n.js').then(m => m.applyTranslationsToDOM());

  // Notification Bell Click & Dropdown
  const notifBtn = document.getElementById('notif-btn') || document.getElementById('notification-btn');
  if (notifBtn) {
    notifBtn.addEventListener('click', async (e) => {
      e.stopPropagation();
      showNotificationsModal();
    });
    // Poll unread count on startup and every 60 seconds
    updateNotificationBadge();
    setInterval(updateNotificationBadge, 60000);
  }

  // Sidebar nav - update active state & close mobile sidebar on click
  document.querySelectorAll('.sidebar-nav .nav-item').forEach(link => {
    link.addEventListener('click', () => {
      document.getElementById('sidebar')?.classList.remove('mobile-open');
      document.getElementById('sidebar-overlay')?.classList.remove('visible');
    });
  });

  // Mobile bottom nav - update active state
  document.querySelectorAll('.mobile-nav .mobile-nav-item').forEach(link => {
    link.addEventListener('click', () => {
      // Active state updated by router
    });
  });
}

/**
 * Update the notification bell red badge counter
 */
export async function updateNotificationBadge() {
  const badge = document.getElementById('notif-badge');
  if (!badge) return;
  const token = localStorage.getItem('sl_token');
  if (!token) return;

  try {
    const res = await api.get('/api/notifications');
    if (res.success && res.data) {
      const count = res.data.unreadCount || 0;
      if (count > 0) {
        badge.textContent = count > 99 ? '99+' : count;
        badge.style.display = 'inline-block';
      } else {
        badge.style.display = 'none';
      }
    }
  } catch (err) {}
}

/**
 * Show Notifications list dialog with live actions
 */
export async function showNotificationsModal() {
  const modalContent = document.createElement('div');
  modalContent.innerHTML = `
    <div style="padding: 1rem; text-align: center;" class="text-muted">
      Loading notifications...
    </div>
  `;

  const notifModal = new Modal({
    title: '🔔 Notifications & Alerts',
    content: modalContent,
    size: 'md'
  });
  notifModal.show();

  try {
    const res = await api.get('/api/notifications');
    if (!res.success || !res.data) throw new Error(res.message);

    const { notifications, unreadCount } = res.data;

    if (notifications.length === 0) {
      modalContent.innerHTML = `
        <div style="padding: 2.5rem 1rem; text-align: center;" class="text-muted">
          <div style="font-size: 2.5rem; margin-bottom: 0.5rem;">🎉</div>
          <h4 style="margin: 0; font-weight: 600;">All caught up!</h4>
          <p style="font-size: 0.85rem; margin-top: 4px;">No new alerts or membership expiries.</p>
        </div>
      `;
      return;
    }

    const itemsHtml = notifications.map(n => {
      const isUnread = !n.isRead;
      const unreadBadge = isUnread ? `<span style="width: 8px; height: 8px; border-radius: 50%; background: var(--color-primary, #6c5ce7); display: inline-block; margin-right: 6px;"></span>` : '';
      const icon = n.type === 'expiry' ? '⏰' : n.type === 'payment' ? '💰' : n.type === 'seat' ? '💺' : 'ℹ️';
      const timeStr = new Date(n.createdAt).toLocaleDateString('en-IN', { hour: '2-digit', minute: '2-digit' });

      return `
        <div class="notif-item p-3 mb-2" data-id="${n._id}" data-link="${escapeHTML(n.link || '')}" style="
          background: ${isUnread ? 'var(--color-bg-secondary, rgba(108,92,231,0.08))' : 'var(--color-surface, #1e2230)'};
          border: 1px solid var(--color-border, #333);
          border-radius: 8px;
          cursor: pointer;
          transition: transform 0.15s;
        ">
          <div class="d-flex justify-content-between align-items-center mb-1">
            <div style="font-weight: 700; font-size: 0.95rem; display: flex; align-items: center;">
              ${unreadBadge} <span style="margin-right: 6px;">${icon}</span> ${escapeHTML(n.title)}
            </div>
            <span style="font-size: 0.72rem; color: var(--color-text-muted);">${timeStr}</span>
          </div>
          <p style="margin: 0; font-size: 0.85rem; color: var(--color-text-secondary); line-height: 1.4;">${escapeHTML(n.message)}</p>
        </div>
      `;
    }).join('');

    modalContent.innerHTML = `
      <div class="d-flex justify-content-between align-items-center mb-3">
        <span class="text-muted small">${unreadCount} unread notification(s)</span>
        <div class="d-flex gap-2">
          <button class="btn btn-sm btn-outline-secondary" id="btn-mark-all-read" style="font-size: 0.75rem; padding: 2px 8px;">✓ Mark all read</button>
          <button class="btn btn-sm btn-outline-danger" id="btn-clear-read" style="font-size: 0.75rem; padding: 2px 8px;">Clear read</button>
        </div>
      </div>
      <div style="max-height: 380px; overflow-y: auto;">
        ${itemsHtml}
      </div>
    `;

    modalContent.querySelectorAll('.notif-item').forEach(item => {
      item.addEventListener('click', async () => {
        const id = item.dataset.id;
        const link = item.dataset.link;
        try {
          await api.put(`/api/notifications/${id}/read`);
          updateNotificationBadge();
        } catch (e) {}
        notifModal.close();
        if (link) window.location.hash = link;
      });
    });

    modalContent.querySelector('#btn-mark-all-read')?.addEventListener('click', async () => {
      await api.put('/api/notifications/read-all');
      Toast.success('All notifications marked as read');
      updateNotificationBadge();
      notifModal.close();
    });

    modalContent.querySelector('#btn-clear-read')?.addEventListener('click', async () => {
      await api.delete('/api/notifications/clear-read');
      Toast.success('Read notifications cleared');
      updateNotificationBadge();
      notifModal.close();
    });

  } catch (err) {
    modalContent.innerHTML = `<div class="p-3 text-center text-danger">Failed to load alerts</div>`;
  }
}

// Dynamic sidebar rendering from API config
async function loadSidebarConfig() {
  try {
    const res = await fetch('/api/settings/sidebar', {
      headers: { 'Authorization': `Bearer ${localStorage.getItem('sl_token')}` }
    });
    const data = await res.json();
    if (!data.success || !data.data) return;
    
    const nav = document.querySelector('.sidebar-nav');
    if (!nav) return;
    
    const enabledKeys = new Set(data.data.map(i => i.key));
    const orderedItems = data.data;
    
    // Hide disabled items
    nav.querySelectorAll('.nav-item').forEach(item => {
      const href = item.getAttribute('href');
      const key = href?.replace('#/', '');
      if (key && !enabledKeys.has(key)) {
        item.style.display = 'none';
      } else {
        item.style.display = '';
      }
    });
    
    // Reorder items
    const fragment = document.createDocumentFragment();
    orderedItems.forEach(item => {
      const navLink = nav.querySelector(`a[href="${item.href}"]`);
      if (navLink) {
        // Update label if renamed
        const span = navLink.querySelector('span');
        if (span && item.label) span.textContent = item.label;
        fragment.appendChild(navLink);
      }
    });
    // Append remaining hidden items
    nav.querySelectorAll('.nav-item').forEach(item => {
      if (!fragment.contains(item)) fragment.appendChild(item);
    });
    nav.appendChild(fragment);
    
  } catch(e) { console.warn('Could not load sidebar config', e); }
}
