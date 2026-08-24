/**
 * Study Library Management System — Admin Master Control Hub (Settings)
 * Complete Modular Studio Suite with 12 Organized Control Centers,
 * Lazy-Mounted DOM (0ms lag), AI Insights, Granular Portal Toggles, and Live CMS Preview.
 */

import api from '../api.js';
import { Toast, Modal, Confirm, Loading, escapeHTML } from '../ui.js';
import { MediaStudio, MediaFieldPicker } from '../mediaStudio.js';
import { t } from '../i18n.js';
import { generateAdmissionFormPDF, previewAdmissionFormPDF } from '../pdfGenerator.js';
import { FormBuilder } from '../formBuilder.js';
import { PushNotifications } from '../utils/pushNotifications.js';

export async function render(container) {
  if (!container) {
    container = document.createElement('div');
    container.className = 'page-container';
  }

  container.innerHTML = `
    <div class="module-header" style="margin-bottom: 1.25rem;">
      <div class="module-title-area">
        <h2 style="font-size: 1.5rem; font-weight: 800; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
          <span>⚙️</span> Admin Master Control Hub
        </h2>
        <p style="color: var(--color-text-secondary); margin: 4px 0 0 0; font-size: 0.88rem;">
          Unified configuration center for library branding, membership policies, forms, billing, AI analytics, and mobile portals.
        </p>
      </div>
    </div>
    <div class="card" style="padding: 3rem; text-align: center;">
      <div class="loading-spinner" style="margin: 0 auto 1rem auto;"></div>
      <p style="color: var(--color-text-secondary); margin: 0; font-weight: 600;">Loading Master Control Hub...</p>
    </div>
  `;

  try {
    const [settingsRes, branchesRes, plansRes, shiftsRes, usersRes] = await Promise.allSettled([
      api.get('/api/settings'),
      api.get('/api/branches'),
      api.get('/api/plans'),
      api.get('/api/shifts'),
      api.get('/api/auth/users').catch(() => ({ data: [] }))
    ]);

    const data = settingsRes.status === 'fulfilled' && settingsRes.value?.data ? settingsRes.value.data : {};
    const businessProfile = data.businessProfile || {};
    const systemSettings = data.systemSettings || {};
    const branches = branchesRes.status === 'fulfilled' && Array.isArray(branchesRes.value?.data) ? branchesRes.value.data : [];
    const plans = plansRes.status === 'fulfilled' && Array.isArray(plansRes.value?.data) ? plansRes.value.data : [];
    const shifts = shiftsRes.status === 'fulfilled' && Array.isArray(shiftsRes.value?.data) ? shiftsRes.value.data : [];
    const staffUsers = usersRes.status === 'fulfilled' && Array.isArray(usersRes.value?.data) ? usersRes.value.data : [];

    const gen = systemSettings.general || {};
    const pay = systemSettings.payment || {};
    const adm = systemSettings.admission || {};
    const notif = systemSettings.notification || {};
    const portal = systemSettings.portal || {};
    const auto = systemSettings.automations || {};
    const billing = systemSettings.billing || {};
    const ops = systemSettings.operations || {};

    renderMasterHubUI(container, {
      profile: businessProfile,
      settings: { gen, pay, adm, notif, portal, auto, billing, ops },
      branches,
      plans,
      shifts,
      staffUsers
    });
  } catch (error) {
    console.error('Failed to load Master Settings Hub:', error);
    container.innerHTML = `
      <div class="card" style="padding: 2.5rem; border-color: var(--color-danger); text-align: center;">
        <div style="font-size: 2.5rem; margin-bottom: 0.5rem;">⚠️</div>
        <h3 style="color: var(--color-danger); margin-bottom: 0.5rem;">Failed to load Master Settings</h3>
        <p style="color: var(--color-text-secondary); margin-bottom: 1.5rem;">${escapeHTML(error.message || 'Could not connect to settings service.')}</p>
        <button id="btn-retry-settings" class="btn btn-primary">🔄 Retry Loading</button>
      </div>
    `;
    container.querySelector('#btn-retry-settings')?.addEventListener('click', () => render());
  }

  return container;
}

function renderMasterHubUI(container, store) {
  const { profile, settings, branches, plans, shifts, staffUsers } = store;
  const { gen, pay, adm, notif, portal, auto, billing, ops } = settings;

  container.innerHTML = `
    <!-- Top Action Bar -->
    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.25rem; flex-wrap: wrap; gap: 12px; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 14px 18px; box-shadow: var(--shadow-xs);">
      <div>
        <h2 style="margin: 0; font-size: 1.35rem; font-weight: 800; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
          <span>⚙️</span> Master Admin Control Hub
        </h2>
        <span style="font-size: 0.82rem; color: var(--color-text-secondary);">Single Source of Truth (SSOT) • Instant real-time synchronization</span>
      </div>
      <div style="display: flex; gap: 10px; flex-wrap: wrap; align-items: center;">
        <button id="btn-master-quick-backup" class="btn btn-outline-success" style="font-weight: 700; font-size: 0.85rem; padding: 8px 14px; display: inline-flex; align-items: center; gap: 6px;">
          <span>💾</span> Quick Database Backup
        </button>
        <button id="btn-master-save-all" class="btn btn-primary" style="font-weight: 800; font-size: 0.9rem; padding: 8px 18px; display: inline-flex; align-items: center; gap: 6px; box-shadow: var(--shadow-sm);">
          <span>💾</span> Save All Changes
        </button>
      </div>
    </div>

    <!-- Responsive Two-Column Studio Layout -->
    <div class="master-hub-layout" style="display: grid; grid-template-columns: 280px 1fr; gap: 20px; align-items: start;">
      
      <!-- Left Column: Master Studio Category Navigation Tree -->
      <div class="master-hub-sidebar" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 12px; position: sticky; top: 80px; box-shadow: var(--shadow-xs);">
        
        <div style="font-size: 0.72rem; font-weight: 800; text-transform: uppercase; color: var(--color-text-muted); padding: 8px 12px 4px 12px; letter-spacing: 0.5px;">
          Core Identity & Policies
        </div>
        <div class="studio-nav-group" style="display: flex; flex-direction: column; gap: 2px;">
          <button class="studio-nav-item active" data-studio="branding">
            <span>🏢</span> <span>Library Branding & Info</span>
          </button>
          <button class="studio-nav-item" data-studio="memberships">
            <span>💳</span> <span>Plans, Fees & Fines</span>
          </button>
          <button class="studio-nav-item" data-studio="formbuilder">
            <span>📝</span> <span>Registration Form Builder</span>
          </button>
          <button class="studio-nav-item" data-studio="centers_seats">
            <span>💺</span> <span>Centers, Seats & Shifts</span>
          </button>
        </div>

        <div style="font-size: 0.72rem; font-weight: 800; text-transform: uppercase; color: var(--color-text-muted); padding: 14px 12px 4px 12px; letter-spacing: 0.5px;">
          Financials & Operations
        </div>
        <div class="studio-nav-group" style="display: flex; flex-direction: column; gap: 2px;">
          <button class="studio-nav-item" data-studio="billing_receipt">
            <span>🧾</span> <span>Receipt Builder & Billing</span>
          </button>
          <button class="studio-nav-item" data-studio="modules_manager">
            <span>🧩</span> <span>App Modules & Feature Toggles</span>
          </button>
          <button class="studio-nav-item" data-studio="notifications">
            <span>💬</span> <span>WhatsApp & Notifications</span>
          </button>
          <button class="studio-nav-item" data-studio="operations">
            <span>🕒</span> <span>Hours, Holidays & Notices</span>
          </button>
          <button class="studio-nav-item" data-studio="staff_rbac">
            <span>👥</span> <span>Staff & Permissions (RBAC)</span>
          </button>
        </div>

        <div style="font-size: 0.72rem; font-weight: 800; text-transform: uppercase; color: var(--color-text-muted); padding: 14px 12px 4px 12px; letter-spacing: 0.5px;">
          Portals, CMS & Intelligence
        </div>
        <div class="studio-nav-group" style="display: flex; flex-direction: column; gap: 2px;">
          <button class="studio-nav-item" data-studio="website_cms">
            <span>🌐</span> <span>Website CMS & SEO Studio</span>
          </button>
          <button class="studio-nav-item" data-studio="student_portal">
            <span>📱</span> <span>Student Portal Controls</span>
          </button>
          <button class="studio-nav-item" data-studio="automations_ai">
            <span>🤖</span> <span>Automations & AI Insights</span>
          </button>
          <button class="studio-nav-item" data-studio="security_backup">
            <span>🔒</span> <span>Security & Data Backup</span>
          </button>
        </div>

      </div>

      <!-- Right Column: Active Studio Suite Viewport (Lazy Mounted) -->
      <div id="master-studio-viewport" style="min-width: 0; width: 100%;">
        <!-- Dynamic Studio Content is Mounted Here with 0ms Delay -->
      </div>

    </div>
  `;

  // Inject Hub Styling
  const styleEl = document.createElement('style');
  styleEl.textContent = `
    .studio-nav-item {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 10px 14px;
      width: 100%;
      text-align: left;
      border: none;
      background: transparent;
      color: var(--color-text-secondary);
      font-size: 0.88rem;
      font-weight: 600;
      border-radius: var(--radius-md);
      cursor: pointer;
      transition: all 0.15s ease;
    }
    .studio-nav-item:hover {
      background: var(--color-surface-hover);
      color: var(--color-text-primary);
    }
    .studio-nav-item.active {
      background: var(--color-primary-bg);
      color: var(--color-primary);
      font-weight: 700;
    }
    .settings-accordion-card {
      background: var(--color-bg-secondary);
      border: 1px solid var(--color-border);
      border-radius: var(--radius-md);
      margin-bottom: 14px;
      overflow: visible;
      transition: all 0.2s ease;
    }
    .settings-accordion-header {
      padding: 12px 16px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      cursor: pointer;
      user-select: none;
      background: var(--color-surface-hover);
      border-bottom: 1px solid var(--color-border);
      border-radius: var(--radius-md) var(--radius-md) 0 0;
    }
    .settings-accordion-header:hover {
      background: var(--color-bg-secondary);
    }
    .settings-accordion-header h5, .settings-accordion-header h4 {
      margin: 0;
      font-size: 0.95rem;
      font-weight: 800;
      color: var(--color-primary);
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .settings-accordion-toggle {
      font-size: 0.85rem;
      font-weight: bold;
      color: var(--color-text-muted);
      transition: transform 0.2s ease;
    }
    .settings-accordion-body {
      padding: 16px;
      display: block;
    }
    @media (max-width: 900px) {
      .master-hub-layout {
        grid-template-columns: 1fr !important;
      }
      .master-hub-sidebar {
        position: static !important;
        overflow-x: auto;
      }
    }
  `;
  container.appendChild(styleEl);

  const viewport = container.querySelector('#master-studio-viewport');
  let activeStudioId = 'branding';

  // Studio Render Registry
  const studios = {
    branding: () => renderBrandingStudio(profile, gen),
    memberships: () => renderMembershipsStudio(pay, adm, plans),
    formbuilder: () => renderFormBuilderStudio(container),
    centers_seats: () => renderCentersSeatsStudio(branches, shifts),
    billing_receipt: () => renderBillingReceiptStudio(profile, billing, pay),
    modules_manager: () => renderModulesManagerStudio(),
    notifications: () => renderNotificationsStudio(notif, profile),
    operations: () => renderOperationsStudio(ops),
    staff_rbac: () => renderStaffRbacStudio(staffUsers, branches),
    website_cms: () => renderWebsiteCmsStudio(),
    student_portal: () => renderStudentPortalStudio(portal, profile),
    automations_ai: () => renderAutomationsAiStudio(auto),
    security_backup: () => renderSecurityBackupStudio()
  };

  const mountStudio = (studioId) => {
    activeStudioId = studioId;
    container.querySelectorAll('.studio-nav-item').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.studio === studioId);
    });
    if (viewport && studios[studioId]) {
      viewport.innerHTML = '';
      const content = studios[studioId]();
      if (content instanceof HTMLElement) {
        viewport.appendChild(content);
      } else if (typeof content === 'string') {
        viewport.innerHTML = content;
      }
      bindStudioEvents(container, studioId, store);
      setTimeout(() => initStudioAccordions(viewport), 20);
    }
  };

  // Nav Click Handler
  container.querySelectorAll('.studio-nav-item').forEach(btn => {
    btn.addEventListener('click', () => {
      mountStudio(btn.dataset.studio);
    });
  });

  // Initial Mount
  mountStudio('branding');

  // Master Quick Backup
  container.querySelector('#btn-master-quick-backup')?.addEventListener('click', async () => {
    try {
      Loading.show('Generating full system database backup snapshot...');
      const token = localStorage.getItem('sl_token') || localStorage.getItem('token') || '';
      let res = await fetch('/api/backup/export', { headers: { Authorization: `Bearer ${token}` } });
      if (!res.ok) res = await fetch('/api/settings/backup', { headers: { Authorization: `Bearer ${token}` } });
      Loading.hide();
      if (!res.ok) throw new Error('Backup failed (HTTP ' + res.status + ')');
      const blob = await res.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `StudyLibrary_Backup_${new Date().toISOString().split('T')[0]}.json`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      Toast.success('Full database snapshot downloaded successfully!');
    } catch (err) {
      Loading.hide();
      Toast.error(err.message || 'Backup failed');
    }
  });

  // Master Save All Handler
  container.querySelector('#btn-master-save-all')?.addEventListener('click', async () => {
    await saveActiveStudioSettings(container, activeStudioId, store);
  });
}

// -------------------------------------------------------------
// 1. 🏢 Library Branding & Global Identity Studio
// -------------------------------------------------------------
function renderBrandingStudio(profile, gen) {
  const wrapper = document.createElement('div');
  wrapper.className = 'card';
  wrapper.style.cssText = 'padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);';
  
  wrapper.innerHTML = `
    <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
      <div>
        <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">🏢 Library Branding & Global Identity</h3>
        <p class="text-muted small mb-0">Configure your study centre's public name, official logos, contact information, and terms.</p>
      </div>
      <div class="d-flex gap-2 align-items-center">
        <button type="button" class="btn btn-xs btn-outline-secondary btn-expand-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">➕ Expand All</button>
        <button type="button" class="btn btn-xs btn-outline-secondary btn-collapse-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">➖ Collapse All</button>
      </div>
    </div>

    <!-- Section 1: 🏢 Basic Library Profile & Identification -->
    <div class="card settings-accordion-card">
      <div class="settings-accordion-header">
        <h5><span>🏢</span> Basic Business Details & Identity</h5>
        <span class="settings-accordion-toggle">▲</span>
      </div>
      <div class="settings-accordion-body">
        <div class="row g-3">
          <div class="col-md-6">
            <label class="form-label" style="font-weight: 700;">Library / Business Name *</label>
            <input type="text" id="setting-businessName" class="form-control" value="${escapeHTML(profile.businessName || 'Study Library')}" placeholder="e.g. Study Library & Reading Hall">
          </div>
          <div class="col-md-6">
            <label class="form-label" style="font-weight: 700;">Brand Tagline / Slogan</label>
            <input type="text" id="setting-tagline" class="form-control" value="${escapeHTML(profile.tagline || 'Premier Air-Conditioned Self-Study Space')}" placeholder="e.g. Premier Self-Study Space">
          </div>

          <div class="col-md-4">
            <label class="form-label" style="font-weight: 600;">Official Phone / WhatsApp</label>
            <input type="tel" id="setting-phone" class="form-control" value="${escapeHTML(profile.phone || '')}" placeholder="+91 9876543210">
          </div>
          <div class="col-md-4">
            <label class="form-label" style="font-weight: 600;">Official Support Email</label>
            <input type="email" id="setting-email" class="form-control" value="${escapeHTML(profile.email || '')}" placeholder="support@library.com">
          </div>
          <div class="col-md-4">
            <label class="form-label" style="font-weight: 600;">Website / Domain</label>
            <input type="url" id="setting-website" class="form-control" value="${escapeHTML(profile.website || '')}" placeholder="https://yourlibrary.com">
          </div>

          <div class="col-md-6">
            <label class="form-label" style="font-weight: 600;">Shop Act / Registration Number</label>
            <input type="text" id="setting-regNumber" class="form-control" value="${escapeHTML(profile.registrationNumber || '')}" placeholder="e.g. REG-MH-2026-9988">
          </div>
          <div class="col-md-6">
            <label class="form-label" style="font-weight: 600;">GSTIN Tax Number</label>
            <input type="text" id="setting-gstNumber" class="form-control font-monospace" value="${escapeHTML(profile.gstNumber || '')}" placeholder="e.g. 27AAAAA0000A1Z5">
          </div>
        </div>
      </div>
    </div>

    <!-- Section 2: 📍 Physical Campus Address & Location -->
    <div class="card settings-accordion-card">
      <div class="settings-accordion-header">
        <h5><span>📍</span> Physical Campus Address & Location</h5>
        <span class="settings-accordion-toggle">▲</span>
      </div>
      <div class="settings-accordion-body">
        <div class="row g-3">
          <div class="col-12">
            <label class="form-label" style="font-weight: 600;">Physical Campus Address</label>
            <textarea id="setting-address" class="form-control" rows="2" placeholder="Full street address, landmark, area...">${escapeHTML(profile.address || '')}</textarea>
          </div>

          <div class="col-md-4">
            <label class="form-label" style="font-weight: 600;">City</label>
            <input type="text" id="setting-city" class="form-control" value="${escapeHTML(profile.city || '')}" placeholder="e.g. Pune">
          </div>
          <div class="col-md-4">
            <label class="form-label" style="font-weight: 600;">State</label>
            <input type="text" id="setting-state" class="form-control" value="${escapeHTML(profile.state || '')}" placeholder="e.g. Maharashtra">
          </div>
          <div class="col-md-4">
            <label class="form-label" style="font-weight: 600;">Pincode</label>
            <input type="text" id="setting-pincode" class="form-control" value="${escapeHTML(profile.pincode || '')}" placeholder="e.g. 411001">
          </div>
        </div>
      </div>
    </div>

    <!-- Section 3: 🖼️ Brand Media & Visual Assets -->
    <div class="card settings-accordion-card">
      <div class="settings-accordion-header">
        <h5><span>🖼️</span> Brand Media & Visual Assets (Upload, Crop & Remove)</h5>
        <span class="settings-accordion-toggle">▲</span>
      </div>
      <div class="settings-accordion-body">
        <div class="row g-3">
          <div class="col-md-6 col-lg-3" id="mount-branding-logo"></div>
          <div class="col-md-6 col-lg-3" id="mount-branding-favicon"></div>
          <div class="col-md-6 col-lg-3" id="mount-branding-stamp"></div>
          <div class="col-md-6 col-lg-3" id="mount-branding-banner"></div>
        </div>
      </div>
    </div>

    <!-- Section 4: 🌐 Social Media Channels & Links -->
    <div class="card settings-accordion-card">
      <div class="settings-accordion-header">
        <h5><span>🌐</span> Social Media Channels & Groups</h5>
        <span class="settings-accordion-toggle">▲</span>
      </div>
      <div class="settings-accordion-body">
        <div class="row g-3">
          <div class="col-md-4">
            <label class="form-label small" style="font-weight: 600;">WhatsApp Channel / Group Link</label>
            <input type="url" id="setting-social-wa" class="form-control" value="${escapeHTML(profile.socialLinks?.whatsapp || '')}" placeholder="https://chat.whatsapp.com/...">
          </div>
          <div class="col-md-4">
            <label class="form-label small" style="font-weight: 600;">Instagram Profile URL</label>
            <input type="url" id="setting-social-insta" class="form-control" value="${escapeHTML(profile.socialLinks?.instagram || '')}" placeholder="https://instagram.com/...">
          </div>
          <div class="col-md-4">
            <label class="form-label small" style="font-weight: 600;">Facebook Page URL</label>
            <input type="url" id="setting-social-fb" class="form-control" value="${escapeHTML(profile.socialLinks?.facebook || '')}" placeholder="https://facebook.com/...">
          </div>
        </div>
      </div>
    </div>
  `;

  setTimeout(() => {
    // Mount Logo Picker
    const logoMount = wrapper.querySelector('#mount-branding-logo');
    if (logoMount && typeof MediaFieldPicker !== 'undefined') {
      const picker = MediaFieldPicker.create({
        name: 'logo',
        label: 'Official Library Logo',
        value: profile.logo || '',
        preset: 'stamp_logo',
        onChange: (url) => { profile.logo = url; }
      });
      picker.querySelector('.mfp-hidden-value')?.setAttribute('id', 'setting-logo');
      logoMount.appendChild(picker);
    }

    // Mount Favicon Picker
    const favMount = wrapper.querySelector('#mount-branding-favicon');
    if (favMount && typeof MediaFieldPicker !== 'undefined') {
      const picker = MediaFieldPicker.create({
        name: 'favicon',
        label: 'Browser Favicon / App Icon',
        value: profile.favicon || '',
        preset: 'stamp_logo',
        onChange: (url) => { profile.favicon = url; }
      });
      picker.querySelector('.mfp-hidden-value')?.setAttribute('id', 'setting-favicon');
      favMount.appendChild(picker);
    }

    // Mount Stamp Picker
    const stampMount = wrapper.querySelector('#mount-branding-stamp');
    if (stampMount && typeof MediaFieldPicker !== 'undefined') {
      const picker = MediaFieldPicker.create({
        name: 'stampImage',
        label: 'Official Digital Stamp / Seal',
        value: profile.stampImage || '',
        preset: 'stamp_logo',
        onChange: (url) => { profile.stampImage = url; }
      });
      picker.querySelector('.mfp-hidden-value')?.setAttribute('id', 'setting-stamp');
      stampMount.appendChild(picker);
    }

    // Mount Organisation Banner / Hero Cover Picker
    const bannerMount = wrapper.querySelector('#mount-branding-banner');
    if (bannerMount && typeof MediaFieldPicker !== 'undefined') {
      const picker = MediaFieldPicker.create({
        name: 'bannerImage',
        label: 'Organisation Banner / Hero Cover',
        value: profile.bannerImage || '',
        preset: 'cover_banner',
        onChange: (url) => { profile.bannerImage = url; }
      });
      picker.querySelector('.mfp-hidden-value')?.setAttribute('id', 'setting-banner');
      bannerMount.appendChild(picker);
    }
  }, 10);

  return wrapper;
}

// -------------------------------------------------------------
// 2. 💳 Membership Plans & Late Fine Studio
// -------------------------------------------------------------
function renderMembershipsStudio(pay, adm, plans, locker) {
  const lockerConfig = locker || {};
  return `
    <div class="card" style="padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
      <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
        <div>
          <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">💳 Membership Plans, Fines & Fee Policies</h3>
          <p class="text-muted small mb-0">Configure admission fees, security deposit amounts, automated late fine formulas, and grace periods.</p>
        </div>
        <div class="d-flex gap-2 align-items-center flex-wrap">
          <button type="button" class="btn btn-xs btn-outline-secondary btn-expand-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">➕ Expand All</button>
          <button type="button" class="btn btn-xs btn-outline-secondary btn-collapse-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">➖ Collapse All</button>
          <a href="#/plans" class="btn btn-sm btn-outline-primary" style="font-weight: 700;">➕ Manage Plans Matrix ↗</a>
        </div>
      </div>

      <!-- Section 1: 💳 Late Fees, Grace Periods & Auto-Suspend -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <h5><span>💳</span> Fee Grace Periods, Late Fines &amp; Auto-Suspend</h5>
          <span class="settings-accordion-toggle">▲</span>
        </div>
        <div class="settings-accordion-body">
          <div class="row g-3">
            <div class="col-md-4">
              <label class="form-label" style="font-weight: 700;">Payment Grace Period (Days)</label>
              <input type="number" id="setting-pay-grace" class="form-control" value="${pay['payment.gracePeriod'] ?? pay.gracePeriod ?? 5}" min="0" max="30">
              <small class="text-muted">Days allowed after expiry before late fine begins</small>
            </div>

            <div class="col-md-4">
              <label class="form-label" style="font-weight: 700;">Daily Late Fine Amount (₹)</label>
              <input type="number" id="setting-pay-lateFee" class="form-control" value="${pay['payment.lateFeeAmount'] ?? pay.lateFeeAmount ?? 50}" min="0">
              <small class="text-muted">Penalty charged per day past grace period</small>
            </div>

            <div class="col-md-4">
              <label class="form-label" style="font-weight: 700;">Auto-Suspend Threshold (Days)</label>
              <input type="number" id="setting-pay-suspend" class="form-control" value="${pay['payment.autoSuspendDays'] ?? pay.autoSuspendDays ?? 15}" min="1">
              <small class="text-muted">Days overdue before student seat is auto-released</small>
            </div>

            <div class="col-md-6">
              <label class="form-label" style="font-weight: 700;">Student ID Prefix</label>
              <input type="text" id="setting-adm-idPrefix" class="form-control font-monospace" value="${escapeHTML(adm['admission.idPrefix'] || adm.idPrefix || 'STU')}">
              <small class="text-muted">Example: STU &rarr; STU-2026-001</small>
            </div>

            <div class="col-md-6">
              <label class="form-label" style="font-weight: 700;">Maximum Membership Pause Days</label>
              <input type="number" id="setting-adm-maxPause" class="form-control" value="15" min="0" max="60">
              <small class="text-muted">Days allowed for exam break membership freeze</small>
            </div>
          </div>
        </div>
      </div>

      <!-- Section 2: 🔒 Personal Study Locker Add-on Customization -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <div style="display: flex; align-items: center; gap: 8px;">
            <h5><span>🔒</span> Personal Study Locker Add-on Customization</h5>
          </div>
          <div style="display: flex; align-items: center; gap: 10px;">
            <div class="form-check form-switch" style="font-size: 1.1rem; margin: 0;">
              <input class="form-check-input" type="checkbox" id="setting-locker-enable" ${lockerConfig.enableAddon !== false && lockerConfig['locker.enableAddon'] !== false ? 'checked' : ''}>
              <label class="form-check-label" style="font-size: 0.82rem; font-weight: 700; margin-left: 4px;">Enable</label>
            </div>
            <span class="settings-accordion-toggle">▲</span>
          </div>
        </div>
        <div class="settings-accordion-body">
          <div class="row g-3 p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
            <div class="col-md-4">
              <label class="form-label" style="font-weight: 700;">Locker Monthly Fee (₹)</label>
              <input type="number" id="setting-locker-fee" class="form-control" value="${lockerConfig.monthlyFee ?? lockerConfig['locker.monthlyFee'] ?? 200}" min="0">
              <small class="text-muted">Added to admission total when selected by student</small>
            </div>
            <div class="col-md-4">
              <label class="form-label" style="font-weight: 700;">Locker Security Deposit (₹)</label>
              <input type="number" id="setting-locker-deposit" class="form-control" value="${lockerConfig.deposit ?? lockerConfig['locker.deposit'] ?? 0}" min="0">
              <small class="text-muted">Refundable locker key deposit</small>
            </div>
            <div class="col-md-4">
              <label class="form-label" style="font-weight: 700;">Add-on Option Title</label>
              <input type="text" id="setting-locker-title" class="form-control" value="${escapeHTML(lockerConfig.title || lockerConfig['locker.title'] || 'Add Personal Study Locker')}">
            </div>
            <div class="col-12">
              <label class="form-label" style="font-weight: 600;">Locker Add-on Description</label>
              <input type="text" id="setting-locker-desc" class="form-control" value="${escapeHTML(lockerConfig.description || lockerConfig['locker.description'] || 'Secure private key-allotted locker to safely keep heavy study books, notes & laptop.')}">
            </div>
          </div>
        </div>
      </div>

      <!-- Section 3: 📋 Active Membership Plans Overview -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <h5><span>📋</span> Active Membership Plans Overview (${plans.length} Plans)</h5>
          <span class="settings-accordion-toggle">▲</span>
        </div>
        <div class="settings-accordion-body">
          <div class="table-responsive">
            <table class="table" style="font-size: 0.88rem;">
              <thead>
                <tr style="background: var(--color-bg-secondary);">
                  <th>Plan Name</th>
                  <th>Duration</th>
                  <th>Shift</th>
                  <th>Base Price</th>
                  <th>Admission Fee</th>
                  <th>Deposit</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                ${plans.length > 0 ? plans.map(p => `
                  <tr>
                    <td><strong>${escapeHTML(p.name)}</strong></td>
                    <td>${p.duration} ${p.durationType || 'months'}</td>
                    <td><span class="badge" style="background: rgba(108,92,231,0.15); color: var(--color-primary); text-transform: uppercase;">${p.shift || 'Any'}</span></td>
                    <td><strong>₹${Number(p.price || 0).toLocaleString('en-IN')}</strong></td>
                    <td>₹${Number(p.admissionFee || 0).toLocaleString('en-IN')}</td>
                    <td>₹${Number(p.securityDeposit || 0).toLocaleString('en-IN')}</td>
                    <td><span class="badge" style="background: ${p.isActive !== false ? 'rgba(16,185,129,0.15)' : 'rgba(239,68,68,0.15)'}; color: ${p.isActive !== false ? '#10b981' : '#ef4444'};">${p.isActive !== false ? 'Active' : 'Inactive'}</span></td>
                  </tr>
                `).join('') : '<tr><td colspan="7" class="text-center p-3 text-muted">No plans created yet.</td></tr>'}
              </tbody>
            </table>
          </div>
        </div>
      </div>

    </div>
  `;
}

// -------------------------------------------------------------
// 3. 📝 Dynamic Student Registration Form Builder Studio
// -------------------------------------------------------------
function renderFormBuilderStudio(container) {
  const wrapper = document.createElement('div');
  wrapper.className = 'card';
  wrapper.style.cssText = 'padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);';
  
  wrapper.innerHTML = `
    <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
      <div>
        <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">📝 Student Admission Dynamic Form Builder</h3>
        <p class="text-muted small mb-0">Drag and drop fields, create custom admission questions, and toggle mandatory/optional status.</p>
      </div>
      <a href="/register" target="_blank" class="btn btn-sm btn-outline-primary" style="font-weight: 700;">👁️ Test Public Register Form ↗</a>
    </div>
    <div id="form-builder-mount-container" style="min-height: 400px;"></div>
  `;

  setTimeout(async () => {
    const mount = wrapper.querySelector('#form-builder-mount-container');
    if (mount && typeof FormBuilder !== 'undefined') {
      try {
        await FormBuilder.render(mount);
      } catch (err) {
        console.error('Form builder render error:', err);
        mount.innerHTML = `<div class="p-4 text-center text-muted">Error loading Form Builder studio: ${escapeHTML(err.message)}</div>`;
      }
    }
  }, 50);

  return wrapper;
}

// -------------------------------------------------------------
// 4. 💺 Centers, Seats & Shifts Studio
// -------------------------------------------------------------
function renderCentersSeatsStudio(branches, shifts) {
  return `
    <div class="card" style="padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
      <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
        <div>
          <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">💺 Multi-Branch, Seating Layouts & Shift Quotas</h3>
          <p class="text-muted small mb-0">Manage library branches, desk zones (AC, Silent, Cabins), and shift timings.</p>
        </div>
        <div class="d-flex gap-2 align-items-center flex-wrap">
          <button type="button" class="btn btn-xs btn-outline-secondary btn-expand-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">➕ Expand All</button>
          <button type="button" class="btn btn-xs btn-outline-secondary btn-collapse-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">➖ Collapse All</button>
          <a href="#/branches" class="btn btn-sm btn-outline-primary" style="font-weight: 700;">🏛️ Branches Matrix</a>
          <a href="#/seats" class="btn btn-sm btn-outline-primary" style="font-weight: 700;">💺 Seating Grid</a>
          <a href="#/shifts" class="btn btn-sm btn-outline-primary" style="font-weight: 700;">🕒 Shifts Studio</a>
        </div>
      </div>

      <!-- Section 1: 🏛️ Active Study Centre Branches -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <h5><span>🏛️</span> Active Study Centre Branches (${branches.length})</h5>
          <span class="settings-accordion-toggle">▲</span>
        </div>
        <div class="settings-accordion-body">
          <div class="table-responsive">
            <table class="table" style="font-size: 0.88rem;">
              <thead>
                <tr style="background: var(--color-bg-secondary);">
                  <th>Branch Name</th>
                  <th>Code</th>
                  <th>City</th>
                  <th>Capacity</th>
                  <th>Phone</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                ${branches.length > 0 ? branches.map(b => `
                  <tr>
                    <td><strong>${escapeHTML(b.name)}</strong></td>
                    <td><code>${escapeHTML(b.code || 'MAIN')}</code></td>
                    <td>${escapeHTML(b.city || 'Central')}</td>
                    <td><strong>${b.totalSeats || 50} Desks</strong></td>
                    <td>${escapeHTML(b.phone || '-')}</td>
                    <td><span class="badge badge-success">Active</span></td>
                  </tr>
                `).join('') : '<tr><td colspan="6" class="text-center p-3 text-muted">No branches configured yet.</td></tr>'}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <!-- Section 2: 🕒 Configured Study Shifts -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <h5><span>🕒</span> Configured Study Shifts &amp; Rate Multipliers (${shifts.length})</h5>
          <span class="settings-accordion-toggle">▲</span>
        </div>
        <div class="settings-accordion-body">
          <div class="table-responsive">
            <table class="table" style="font-size: 0.88rem;">
              <thead>
                <tr style="background: var(--color-bg-secondary);">
                  <th>Shift Name</th>
                  <th>Code</th>
                  <th>Timing</th>
                  <th>Rate Multiplier</th>
                  <th>Capacity Limit</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                ${shifts.length > 0 ? shifts.map(s => `
                  <tr>
                    <td><strong>${escapeHTML(s.name)}</strong></td>
                    <td><code>${escapeHTML(s.code || '-')}</code></td>
                    <td>${s.startTime || '06:00'} – ${s.endTime || '23:00'}</td>
                    <td><span class="badge" style="background: rgba(108,92,231,0.15); color: var(--color-primary);">${s.priceMultiplier || 1.0}x</span></td>
                    <td>${s.maxCapacity > 0 ? `${s.maxCapacity} seats` : 'Unlimited'}</td>
                    <td><span class="badge badge-success">Active</span></td>
                  </tr>
                `).join('') : '<tr><td colspan="6" class="text-center p-3 text-muted">No shifts configured yet.</td></tr>'}
              </tbody>
            </table>
          </div>
        </div>
      </div>

    </div>
  `;
}

// -------------------------------------------------------------
// -------------------------------------------------------------
// 5. 🧾 POS Receipt Builder & Billing Studio
// -------------------------------------------------------------
function renderBillingReceiptStudio(profile, billing, pay) {
  const wrapper = document.createElement('div');
  wrapper.className = 'card';
  wrapper.style.cssText = 'padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);';
  
  let currentFormat = billing['billing.defaultTemplate'] || 'thermal80';

  wrapper.innerHTML = `
    <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
      <div>
        <h3 style="margin: 0; font-size: 1.25rem; font-weight: 800; color: var(--color-primary);">🧾 POS Receipt Builder & GST Billing Studio</h3>
        <p class="text-muted small mb-0">Design, customize, and test-print thermal receipts (80mm/58mm), official A4 GST invoices, paid stamps, and UPI QR codes with real-time live preview.</p>
      </div>
      <div class="d-flex gap-2 align-items-center flex-wrap">
        <button type="button" class="btn btn-xs btn-outline-secondary btn-expand-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">➕ Expand All</button>
        <button type="button" class="btn btn-xs btn-outline-secondary btn-collapse-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">➖ Collapse All</button>
        <button type="button" id="btn-test-print-receipt" class="btn btn-sm btn-outline-primary" style="font-weight: 700;">🖨️ Test Print Sample</button>
        <button type="button" id="btn-save-receipt-builder" class="btn btn-sm btn-primary" style="font-weight: 800; padding: 6px 18px;">💾 Save Receipt Template</button>
      </div>
    </div>

    <!-- Template Format Selector Cards -->
    <div style="margin-bottom: 1.5rem;">
      <label class="form-label" style="font-weight: 800; font-size: 0.95rem; margin-bottom: 8px; display: flex; align-items: center; gap: 6px;">
        <span>🖨️</span> Select Receipt Output Format
      </label>
      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px;" id="receipt-format-grid">
        <div class="card p-3 receipt-format-card ${currentFormat === 'thermal80' ? 'active' : ''}" data-format="thermal80" style="border: ${currentFormat === 'thermal80' ? '2px solid var(--color-primary)' : '1px solid var(--color-border)'}; background: var(--color-surface); text-align: center; cursor: pointer; transition: all 0.2s; border-radius: var(--radius-md);">
          <span style="font-size: 1.6rem; margin-bottom: 2px;">🖨️</span>
          <h5 style="margin: 0; font-size: 0.92rem; font-weight: 800;">POS Thermal 80mm</h5>
          <small class="text-muted d-block">Standard 3-inch POS roll</small>
        </div>
        <div class="card p-3 receipt-format-card ${currentFormat === 'thermal58' ? 'active' : ''}" data-format="thermal58" style="border: ${currentFormat === 'thermal58' ? '2px solid var(--color-primary)' : '1px solid var(--color-border)'}; background: var(--color-surface); text-align: center; cursor: pointer; transition: all 0.2s; border-radius: var(--radius-md);">
          <span style="font-size: 1.6rem; margin-bottom: 2px;">📱</span>
          <h5 style="margin: 0; font-size: 0.92rem; font-weight: 800;">POS Thermal 58mm</h5>
          <small class="text-muted d-block">2-inch mobile Bluetooth roll</small>
        </div>
        <div class="card p-3 receipt-format-card ${currentFormat === 'standardA4' ? 'active' : ''}" data-format="standardA4" style="border: ${currentFormat === 'standardA4' ? '2px solid var(--color-primary)' : '1px solid var(--color-border)'}; background: var(--color-surface); text-align: center; cursor: pointer; transition: all 0.2s; border-radius: var(--radius-md);">
          <span style="font-size: 1.6rem; margin-bottom: 2px;">📄</span>
          <h5 style="margin: 0; font-size: 0.92rem; font-weight: 800;">Official A4 Invoice</h5>
          <small class="text-muted d-block">Printable GST tax invoice</small>
        </div>
        <div class="card p-3 receipt-format-card ${currentFormat === 'modern_minimal' ? 'active' : ''}" data-format="modern_minimal" style="border: ${currentFormat === 'modern_minimal' ? '2px solid var(--color-primary)' : '1px solid var(--color-border)'}; background: var(--color-surface); text-align: center; cursor: pointer; transition: all 0.2s; border-radius: var(--radius-md);">
          <span style="font-size: 1.6rem; margin-bottom: 2px;">✨</span>
          <h5 style="margin: 0; font-size: 0.92rem; font-weight: 800;">Modern Digital Pass</h5>
          <small class="text-muted d-block">Clean digital fee voucher</small>
        </div>
      </div>
    </div>

    <!-- Split-Screen Controls + Live Thermal Receipt Preview -->
    <div style="display: grid; grid-template-columns: 1fr 1.1fr; gap: 20px;" class="receipt-split-layout">
      
      <!-- Left Column: Customization Controls -->
      <div style="display: flex; flex-direction: column; gap: 14px; max-height: 750px; overflow-y: auto; padding-right: 4px;">
        
        <!-- Header & Branding -->
        <div class="card settings-accordion-card">
          <div class="settings-accordion-header">
            <h5><span>🏢</span> Header &amp; Library Branding</h5>
            <span class="settings-accordion-toggle">▲</span>
          </div>
          <div class="settings-accordion-body">
            <div class="row g-2">
              <div class="col-md-6">
                <label class="form-label small" style="font-weight: 700;">Receipt & Invoice Prefix</label>
                <input type="text" id="setting-bill-prefix" class="form-control form-control-sm font-monospace" value="${escapeHTML(billing['billing.receiptPrefix'] || billing.receiptPrefix || 'LIB-2026')}" placeholder="e.g. LIB-2026">
              </div>
              <div class="col-md-6">
                <label class="form-label small" style="font-weight: 700;">Receipt Subtitle / Tagline</label>
                <input type="text" id="rc-header-subtitle" class="form-control form-control-sm" value="Official Fee Payment Receipt">
              </div>
              <div class="col-md-6">
                <label class="form-label small" style="font-weight: 700;">Header Accent Color</label>
                <div style="display: flex; align-items: center; gap: 6px;">
                  <input type="color" id="rc-header-color" class="form-control form-control-color p-0" value="#4f46e5" style="width: 34px; height: 30px; cursor: pointer;">
                  <input type="text" id="rc-header-color-text" class="form-control form-control-sm font-monospace" value="#4f46e5" maxlength="7">
                </div>
              </div>
              <div class="col-md-6">
                <label class="form-label small" style="font-weight: 700;">GSTIN / Tax Number</label>
                <input type="text" id="rc-header-gstin" class="form-control form-control-sm font-monospace" value="${escapeHTML(profile.gstNumber || '')}" placeholder="e.g. 27AAAAA0000A1Z5">
              </div>
              <div class="col-12 mt-2">
                <div style="display: flex; gap: 14px; flex-wrap: wrap;">
                  <label class="form-check form-switch mb-0" style="font-size: 0.88rem; cursor: pointer;">
                    <input class="form-check-input" type="checkbox" id="rc-toggle-logo" checked>
                    <span>Show Library Logo</span>
                  </label>
                  <label class="form-check form-switch mb-0" style="font-size: 0.88rem; cursor: pointer;">
                    <input class="form-check-input" type="checkbox" id="rc-toggle-address" checked>
                    <span>Show Address</span>
                  </label>
                  <label class="form-check form-switch mb-0" style="font-size: 0.88rem; cursor: pointer;">
                    <input class="form-check-input" type="checkbox" id="rc-toggle-contact" checked>
                    <span>Show Phone & Email</span>
                  </label>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Student, Desk & Admission Details -->
        <div class="card settings-accordion-card">
          <div class="settings-accordion-header">
            <h5><span>📋</span> Student Details &amp; Line Items</h5>
            <span class="settings-accordion-toggle">▲</span>
          </div>
          <div class="settings-accordion-body">
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 10px;">
              <label class="form-check form-switch mb-0" style="font-size: 0.88rem; cursor: pointer;">
                <input class="form-check-input" type="checkbox" id="rc-toggle-stuId" checked>
                <span>Show Student ID</span>
              </label>
              <label class="form-check form-switch mb-0" style="font-size: 0.88rem; cursor: pointer;">
                <input class="form-check-input" type="checkbox" id="rc-toggle-stuPhone" checked>
                <span>Show Student Phone</span>
              </label>
              <label class="form-check form-switch mb-0" style="font-size: 0.88rem; cursor: pointer;">
                <input class="form-check-input" type="checkbox" id="rc-toggle-seat" checked>
                <span>Show Desk / Shift</span>
              </label>
              <label class="form-check form-switch mb-0" style="font-size: 0.88rem; cursor: pointer;">
                <input class="form-check-input" type="checkbox" id="rc-toggle-validity" checked>
                <span>Show Validity Dates</span>
              </label>
              <label class="form-check form-switch mb-0" style="font-size: 0.88rem; cursor: pointer;">
                <input class="form-check-input" type="checkbox" id="rc-toggle-breakdown" checked>
                <span>Itemized Fee Breakdown</span>
              </label>
              <label class="form-check form-switch mb-0" style="font-size: 0.88rem; cursor: pointer;">
                <input class="form-check-input" type="checkbox" id="rc-toggle-paymentMode" checked>
                <span>Payment Mode & Txn Ref</span>
              </label>
            </div>
          </div>
        </div>

        <!-- Official Stamp & Signature Block -->
        <div class="card settings-accordion-card">
          <div class="settings-accordion-header">
            <h5><span>🪪</span> Official Stamp &amp; Signature</h5>
            <span class="settings-accordion-toggle">▲</span>
          </div>
          <div class="settings-accordion-body">
            <div class="row g-2">
              <div class="col-md-7">
                <label class="form-label small" style="font-weight: 700;">Paid Stamp Text</label>
                <input type="text" id="rc-stamp-text" class="form-control form-control-sm font-monospace" value="PAID • OFFICIAL RECEIPT">
              </div>
              <div class="col-md-5">
                <label class="form-label small" style="font-weight: 700;">Stamp Color</label>
                <div style="display: flex; align-items: center; gap: 6px;">
                  <input type="color" id="rc-stamp-color" class="form-control form-control-color p-0" value="#059669" style="width: 34px; height: 30px; cursor: pointer;">
                  <input type="text" id="rc-stamp-color-text" class="form-control form-control-sm font-monospace" value="#059669" maxlength="7">
                </div>
              </div>
              <div class="col-md-7">
                <label class="form-label small" style="font-weight: 700;">Authorized Signatory Label</label>
                <input type="text" id="rc-signature-label" class="form-control form-control-sm" value="Authorized Signatory">
              </div>
              <div class="col-12 mt-2">
                <div style="display: flex; gap: 14px; flex-wrap: wrap;">
                  <label class="form-check form-switch mb-0" style="font-size: 0.88rem; cursor: pointer;">
                    <input class="form-check-input" type="checkbox" id="rc-toggle-stamp" checked>
                    <span>Show Paid Stamp Mark</span>
                  </label>
                  <label class="form-check form-switch mb-0" style="font-size: 0.88rem; cursor: pointer;">
                    <input class="form-check-input" type="checkbox" id="rc-toggle-signature" checked>
                    <span>Show Signature Line</span>
                  </label>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Dynamic UPI QR & Payment Link on Receipt -->
        <div class="card settings-accordion-card">
          <div class="settings-accordion-header">
            <h5><span>💳</span> Dynamic UPI QR Code on Receipt</h5>
            <span class="settings-accordion-toggle">▲</span>
          </div>
          <div class="settings-accordion-body">
            <div class="row g-2">
              <div class="col-md-8">
                <label class="form-label small" style="font-weight: 700;">Primary Library UPI ID (VPA)</label>
                <input type="text" id="setting-bill-upiId" class="form-control form-control-sm font-monospace" value="${escapeHTML(profile.upiId || '')}" placeholder="e.g. studylib@okhdfcbank">
              </div>
              <div class="col-md-4 d-flex align-items-end">
                <label class="form-check form-switch mb-2" style="font-size: 0.88rem; cursor: pointer;">
                  <input class="form-check-input" type="checkbox" id="rc-toggle-upiqr" checked>
                  <span>Print UPI QR Code</span>
                </label>
              </div>
            </div>
          </div>
        </div>

        <!-- Terms, Conditions & Custom Footer Notes -->
        <div class="card settings-accordion-card">
          <div class="settings-accordion-header">
            <h5><span>📝</span> Terms, Policies &amp; Footer Message</h5>
            <span class="settings-accordion-toggle">▲</span>
          </div>
          <div class="settings-accordion-body">
            <div class="form-group mb-2">
              <label class="form-label small" style="font-weight: 700;">Terms & Conditions</label>
              <textarea id="rc-terms-text" class="form-control form-control-sm" rows="2">1. Fees paid are non-refundable. 2. Seat allotment is strictly non-transferable. 3. Maintain pin-drop silence in the reading hall.</textarea>
            </div>
            <div class="form-group mb-2">
              <label class="form-label small" style="font-weight: 700;">Footer Greeting / Custom Note</label>
              <input type="text" id="rc-custom-note" class="form-control form-control-sm" value="Thank you for choosing our study library! Best wishes for your exams.">
            </div>
            <label class="form-check form-switch mb-0" style="font-size: 0.88rem; cursor: pointer;">
              <input class="form-check-input" type="checkbox" id="rc-toggle-timestamp" checked>
              <span>Print Date & Time Timestamp</span>
            </label>
          </div>
        </div>

        <!-- GST & Bank Wire Transfer Details -->
        <div class="card settings-accordion-card">
          <div class="settings-accordion-header">
            <h5><span>📊</span> GST Tax Engine &amp; Bank Wire Details</h5>
            <span class="settings-accordion-toggle">▲</span>
          </div>
          <div class="settings-accordion-body">
            <div class="row g-2">
              <div class="col-md-4">
                <label class="form-label small">GST Rate (%)</label>
                <input type="number" id="setting-bill-gstRate" class="form-control form-control-sm" value="${billing['billing.gstRate'] ?? billing.gstRate ?? 18}" min="0" max="28">
              </div>
              <div class="col-md-4">
                <label class="form-label small">HSN / SAC Code</label>
                <input type="text" id="setting-bill-hsn" class="form-control form-control-sm font-monospace" value="${escapeHTML(billing['billing.hsnSacCode'] || billing.hsnSacCode || '999293')}" placeholder="999293">
              </div>
              <div class="col-md-4">
                <label class="form-label small">Refund Window (Days)</label>
                <input type="number" id="setting-bill-refundDays" class="form-control form-control-sm" value="${billing['billing.refundPolicyDays'] ?? billing.refundPolicyDays ?? 3}" min="0">
              </div>
              <div class="col-md-6 mt-2">
                <label class="form-label small">Bank Account Holder</label>
                <input type="text" id="setting-bank-accName" class="form-control form-control-sm" value="${escapeHTML(profile.bankDetails?.accountName || '')}">
              </div>
              <div class="col-md-6 mt-2">
                <label class="form-label small">Account Number</label>
                <input type="text" id="setting-bank-accNo" class="form-control form-control-sm font-monospace" value="${escapeHTML(profile.bankDetails?.accountNumber || '')}">
              </div>
            </div>
          </div>
        </div>

      </div>

      <!-- Right Column: Live Simulated Receipt Preview -->
      <div style="display: flex; flex-direction: column; position: sticky; top: 10px;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
          <div class="d-flex align-items-center gap-2">
            <span style="font-weight: 800; font-size: 0.9rem; color: var(--color-text-primary);">📱 Live Visual Receipt Preview</span>
            <span id="preview-format-badge" class="badge badge-primary" style="font-size: 0.72rem; text-transform: uppercase;">POS Thermal 80mm</span>
          </div>
          <button type="button" id="btn-refresh-receipt-preview" class="btn btn-xs btn-outline-secondary" style="padding: 2px 6px;">🔄</button>
        </div>

        <div id="receipt-preview-wrapper" style="width: 100%; max-height: 730px; overflow-y: auto; background: #2d3748; padding: 20px; border-radius: var(--radius-lg); display: flex; justify-content: center; box-shadow: inset 0 2px 8px rgba(0,0,0,0.4);">
          <!-- Live Thermal Paper Simulation -->
          <div id="receipt-paper" style="width: 340px; background: #ffffff; color: #111827; padding: 20px 18px; border-radius: 4px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); font-family: 'Courier New', Courier, monospace; font-size: 13px; line-height: 1.4; transition: all 0.3s ease;">
            <!-- Rendered by liveUpdateReceipt() -->
          </div>
        </div>
      </div>

    </div>
  `;

  // Attach interactive preview logic
  setTimeout(async () => {
    // 1. Fetch saved ReceiptConfig from API if available
    try {
      const cfgRes = await api.get('/api/settings/receipt-config');
      if (cfgRes.success && cfgRes.data) {
        const rc = cfgRes.data;
        if (rc.activeTemplate) {
          currentFormat = rc.activeTemplate;
          wrapper.querySelectorAll('.receipt-format-card').forEach(c => {
            if (c.dataset.format === currentFormat) {
              c.classList.add('active');
              c.style.border = '2px solid var(--color-primary)';
            } else {
              c.classList.remove('active');
              c.style.border = '1px solid var(--color-border)';
            }
          });
        }
        if (rc.header?.subtitle) wrapper.querySelector('#rc-header-subtitle').value = rc.header.subtitle;
        if (rc.header?.headerColor) {
          wrapper.querySelector('#rc-header-color').value = rc.header.headerColor;
          wrapper.querySelector('#rc-header-color-text').value = rc.header.headerColor;
        }
        if (rc.header?.gstNumber) wrapper.querySelector('#rc-header-gstin').value = rc.header.gstNumber;
        if (rc.header?.showLogo !== undefined) wrapper.querySelector('#rc-toggle-logo').checked = rc.header.showLogo;
        if (rc.header?.showAddress !== undefined) wrapper.querySelector('#rc-toggle-address').checked = rc.header.showAddress;
        if (rc.header?.showPhone !== undefined) wrapper.querySelector('#rc-toggle-contact').checked = rc.header.showPhone;

        if (rc.body?.showStudentId !== undefined) wrapper.querySelector('#rc-toggle-stuId').checked = rc.body.showStudentId;
        if (rc.body?.showStudentPhone !== undefined) wrapper.querySelector('#rc-toggle-stuPhone').checked = rc.body.showStudentPhone;
        if (rc.body?.showSeatNumber !== undefined) wrapper.querySelector('#rc-toggle-seat').checked = rc.body.showSeatNumber;
        if (rc.body?.showPeriod !== undefined) wrapper.querySelector('#rc-toggle-validity').checked = rc.body.showPeriod;

        if (rc.stamp?.showStamp !== undefined) wrapper.querySelector('#rc-toggle-stamp').checked = rc.stamp.showStamp;
        if (rc.stamp?.stampText) wrapper.querySelector('#rc-stamp-text').value = rc.stamp.stampText;
        if (rc.stamp?.stampColor) {
          wrapper.querySelector('#rc-stamp-color').value = rc.stamp.stampColor;
          wrapper.querySelector('#rc-stamp-color-text').value = rc.stamp.stampColor;
        }

        if (rc.footer?.signatureLabel) wrapper.querySelector('#rc-signature-label').value = rc.footer.signatureLabel;
        if (rc.footer?.showSignature !== undefined) wrapper.querySelector('#rc-toggle-signature').checked = rc.footer.showSignature;
        if (rc.footer?.showUpiQr !== undefined) wrapper.querySelector('#rc-toggle-upiqr').checked = rc.footer.showUpiQr;
        if (rc.footer?.termsText) wrapper.querySelector('#rc-terms-text').value = rc.footer.termsText;
        if (rc.footer?.customNote) wrapper.querySelector('#rc-custom-note').value = rc.footer.customNote;
      }
    } catch (e) {
      console.warn('Could not load receipt-config:', e);
    }

    const paper = wrapper.querySelector('#receipt-paper');
    const formatBadge = wrapper.querySelector('#preview-format-badge');

    // 2. Render Live Simulated Receipt
    const liveUpdateReceipt = () => {
      if (!paper) return;

      const bizName = profile.businessName || 'The Cozy Corner Study Library';
      const address = profile.address || 'MG Road, Shivajinagar, Pune 411005';
      const phone = profile.phone || '+91 98765 43210';
      const email = profile.email || 'contact@cozystudylibrary.com';
      const gstin = wrapper.querySelector('#rc-header-gstin')?.value?.trim();
      const prefix = wrapper.querySelector('#setting-bill-prefix')?.value?.trim() || 'LIB-2026';
      const subtitle = wrapper.querySelector('#rc-header-subtitle')?.value?.trim() || 'Official Fee Receipt';
      const headerColor = wrapper.querySelector('#rc-header-color')?.value || '#4f46e5';

      const showLogo = wrapper.querySelector('#rc-toggle-logo')?.checked !== false;
      const showAddress = wrapper.querySelector('#rc-toggle-address')?.checked !== false;
      const showContact = wrapper.querySelector('#rc-toggle-contact')?.checked !== false;

      const showStuId = wrapper.querySelector('#rc-toggle-stuId')?.checked !== false;
      const showStuPhone = wrapper.querySelector('#rc-toggle-stuPhone')?.checked !== false;
      const showSeat = wrapper.querySelector('#rc-toggle-seat')?.checked !== false;
      const showValidity = wrapper.querySelector('#rc-toggle-validity')?.checked !== false;
      const showBreakdown = wrapper.querySelector('#rc-toggle-breakdown')?.checked !== false;
      const showPaymentMode = wrapper.querySelector('#rc-toggle-paymentMode')?.checked !== false;

      const showStamp = wrapper.querySelector('#rc-toggle-stamp')?.checked !== false;
      const stampText = wrapper.querySelector('#rc-stamp-text')?.value?.trim() || 'PAID • OFFICIAL RECEIPT';
      const stampColor = wrapper.querySelector('#rc-stamp-color')?.value || '#059669';

      const showSignature = wrapper.querySelector('#rc-toggle-signature')?.checked !== false;
      const signatureLabel = wrapper.querySelector('#rc-signature-label')?.value?.trim() || 'Authorized Signatory';

      const showUpiQr = wrapper.querySelector('#rc-toggle-upiqr')?.checked !== false;
      const upiId = wrapper.querySelector('#setting-bill-upiId')?.value?.trim() || profile.upiId || 'thecozycorner@okaxis';

      const termsText = wrapper.querySelector('#rc-terms-text')?.value?.trim();
      const customNote = wrapper.querySelector('#rc-custom-note')?.value?.trim();
      const showTimestamp = wrapper.querySelector('#rc-toggle-timestamp')?.checked !== false;

      // Adjust paper width according to format
      if (currentFormat === 'thermal58') {
        paper.style.width = '260px';
        paper.style.fontSize = '11px';
        paper.style.padding = '12px 10px';
        if (formatBadge) formatBadge.textContent = 'POS Thermal 58mm';
      } else if (currentFormat === 'standardA4') {
        paper.style.width = '480px';
        paper.style.fontSize = '12px';
        paper.style.padding = '28px 24px';
        paper.style.fontFamily = 'var(--font-family, sans-serif)';
        if (formatBadge) formatBadge.textContent = 'Standard A4 Invoice';
      } else {
        paper.style.width = '340px';
        paper.style.fontSize = '12.5px';
        paper.style.padding = '18px 16px';
        paper.style.fontFamily = "'Courier New', Courier, monospace";
        if (formatBadge) formatBadge.textContent = 'POS Thermal 80mm';
      }

      paper.innerHTML = `
        <!-- Receipt Header -->
        <div style="text-align: center; border-bottom: 1.5px dashed #333; padding-bottom: 10px; margin-bottom: 10px;">
          ${showLogo ? `
            <div style="margin-bottom: 4px; text-align: center;">
              ${(profile.logo || (container.querySelector('#setting-logo') || container.querySelector('input[name="logo"]'))?.value?.trim()) ? `
                <img src="${profile.logo || (container.querySelector('#setting-logo') || container.querySelector('input[name="logo"]'))?.value?.trim()}" alt="Logo" style="max-height: 48px; max-width: 120px; object-fit: contain; display: inline-block;">
              ` : `
                <div style="font-size: 1.75rem;">📚</div>
              `}
            </div>
          ` : ''}
          <div style="font-weight: 800; font-size: 1.05rem; text-transform: uppercase; color: ${headerColor}; letter-spacing: 0.5px;">${escapeHTML(bizName)}</div>
          <div style="font-size: 0.8rem; font-weight: 700; color: #555; text-transform: uppercase;">${escapeHTML(subtitle)}</div>
          ${showAddress ? `<div style="font-size: 0.72rem; color: #444; margin-top: 3px;">${escapeHTML(address)}</div>` : ''}
          ${showContact ? `<div style="font-size: 0.72rem; color: #444;">Tel: ${escapeHTML(phone)} • ${escapeHTML(email)}</div>` : ''}
          ${gstin ? `<div style="font-size: 0.72rem; font-weight: 700; color: #222; margin-top: 2px;">GSTIN: ${escapeHTML(gstin)}</div>` : ''}
        </div>

        <!-- Receipt Metadata -->
        <div style="border-bottom: 1px dashed #666; padding-bottom: 8px; margin-bottom: 8px; font-size: 0.82rem;">
          <div style="display: flex; justify-content: space-between;">
            <span>Receipt No:</span>
            <strong style="font-family: monospace;">${escapeHTML(prefix)}-0042</strong>
          </div>
          <div style="display: flex; justify-content: space-between;">
            <span>Date & Time:</span>
            <span>${new Date().toLocaleDateString('en-IN')} 10:45 AM</span>
          </div>
          <div style="display: flex; justify-content: space-between;">
            <span>Student Name:</span>
            <strong>Rahul S. Sharma</strong>
          </div>
          ${showStuId ? `
            <div style="display: flex; justify-content: space-between;">
              <span>Student ID:</span>
              <span style="font-family: monospace;">STU-2026-0042</span>
            </div>
          ` : ''}
          ${showStuPhone ? `
            <div style="display: flex; justify-content: space-between;">
              <span>Phone (WA):</span>
              <span>+91 98765 43210</span>
            </div>
          ` : ''}
          ${showSeat ? `
            <div style="display: flex; justify-content: space-between;">
              <span>Allocated Seat:</span>
              <strong>Desk #012 (Zone A)</strong>
            </div>
            <div style="display: flex; justify-content: space-between;">
              <span>Shift Timing:</span>
              <span>Full Day (7 AM – 11 PM)</span>
            </div>
          ` : ''}
          ${showValidity ? `
            <div style="display: flex; justify-content: space-between; margin-top: 2px;">
              <span>Validity Period:</span>
              <strong style="color: #059669;">01 Aug 2026 – 31 Aug 2026</strong>
            </div>
          ` : ''}
        </div>

        <!-- Itemized Table -->
        ${showBreakdown ? `
          <div style="border-bottom: 1.5px dashed #333; padding-bottom: 8px; margin-bottom: 8px; font-size: 0.82rem;">
            <div style="display: flex; justify-content: space-between; font-weight: 700; border-bottom: 1px solid #ddd; padding-bottom: 3px; margin-bottom: 4px;">
              <span>Description</span>
              <span>Amount (₹)</span>
            </div>
            <div style="display: flex; justify-content: space-between;">
              <span>Monthly Premium 24/7 (30 Days)</span>
              <span>1,200.00</span>
            </div>
            <div style="display: flex; justify-content: space-between;">
              <span>Personal Locker Storage Addon</span>
              <span>200.00</span>
            </div>
            <div style="display: flex; justify-content: space-between; color: #dc2626;">
              <span>Special Early Bird Discount</span>
              <span>- 100.00</span>
            </div>
            <div style="display: flex; justify-content: space-between; color: #666; font-size: 0.76rem;">
              <span>CGST (9%) + SGST (9%)</span>
              <span>234.00</span>
            </div>
          </div>
        ` : ''}

        <!-- Total Paid & Payment Method -->
        <div style="border-bottom: 1.5px dashed #333; padding-bottom: 8px; margin-bottom: 8px; font-size: 0.95rem;">
          <div style="display: flex; justify-content: space-between; font-weight: 800; font-size: 1.05rem;">
            <span>TOTAL AMOUNT PAID:</span>
            <span>₹ 1,534.00</span>
          </div>
          <div style="display: flex; justify-content: space-between; font-size: 0.8rem; color: #059669; font-weight: 700; margin-top: 2px;">
            <span>Balance Due:</span>
            <span>₹ 0.00 (PAID IN FULL)</span>
          </div>
          ${showPaymentMode ? `
            <div style="display: flex; justify-content: space-between; font-size: 0.78rem; color: #444; margin-top: 4px;">
              <span>Payment Mode:</span>
              <span>UPI / QR Scan</span>
            </div>
            <div style="display: flex; justify-content: space-between; font-size: 0.72rem; color: #666; font-family: monospace;">
              <span>Txn Ref / UTR:</span>
              <span>UPI/423981029381</span>
            </div>
          ` : ''}
        </div>

        <!-- PAID Official Stamp -->
        ${showStamp ? `
          <div style="text-align: center; margin: 12px 0;">
            ${(profile.stampImage || (container.querySelector('#setting-stamp') || container.querySelector('input[name="stampImage"]'))?.value?.trim()) ? `
              <img src="${profile.stampImage || (container.querySelector('#setting-stamp') || container.querySelector('input[name="stampImage"]'))?.value?.trim()}" style="max-height: 52px; max-width: 65px; object-fit: contain; margin-bottom: 4px;" alt="Official Stamp"><br>
            ` : ''}
            <div style="display: inline-block; border: 2.5px solid ${stampColor}; color: ${stampColor}; font-weight: 900; font-size: 0.95rem; padding: 4px 14px; border-radius: 6px; text-transform: uppercase; letter-spacing: 1px; transform: rotate(-3deg);">
              ✔ ${escapeHTML(stampText)}
            </div>
          </div>
        ` : ''}

        <!-- Dynamic UPI QR Code for instant verification -->
        ${showUpiQr ? `
          <div style="text-align: center; margin: 10px 0; padding: 8px; background: #f9fafb; border: 1px solid #e5e7eb; border-radius: 6px;">
            <img src="https://api.qrserver.com/v1/create-qr-code/?size=90x90&data=${encodeURIComponent('upi://pay?pa=' + upiId + '&pn=' + bizName + '&am=0&cu=INR')}" style="width: 80px; height: 80px; display: block; margin: 0 auto 4px;" alt="UPI QR">
            <div style="font-size: 0.68rem; font-weight: 700; color: #374151;">Scan to Verify / Pay Balance via UPI</div>
            <div style="font-size: 0.62rem; color: #6b7280; font-family: monospace;">${escapeHTML(upiId)}</div>
          </div>
        ` : ''}

        <!-- Terms, Footer Note & Signature -->
        <div style="font-size: 0.72rem; color: #4b5563; margin-top: 8px;">
          ${customNote ? `<div style="font-weight: 700; text-align: center; margin-bottom: 6px; color: #111827;">${escapeHTML(customNote)}</div>` : ''}
          ${termsText ? `<div style="line-height: 1.3; font-size: 0.68rem; color: #6b7280; margin-bottom: 8px;">${escapeHTML(termsText)}</div>` : ''}
          
          ${showSignature ? `
            <div style="display: flex; justify-content: space-between; align-items: flex-end; margin-top: 14px; padding-top: 8px; border-top: 1px solid #eee;">
              <div style="font-size: 0.65rem; color: #9ca3af;">
                ${showTimestamp ? `Generated on: ${new Date().toLocaleString('en-IN')}` : ''}
              </div>
              <div style="text-align: center; display: flex; flex-direction: column; align-items: center;">
                ${(profile.stampImage || (container.querySelector('#setting-stamp') || container.querySelector('input[name="stampImage"]'))?.value?.trim()) ? `
                  <img src="${profile.stampImage || (container.querySelector('#setting-stamp') || container.querySelector('input[name="stampImage"]'))?.value?.trim()}" style="max-height: 44px; max-width: 58px; object-fit: contain; margin-bottom: 2px;" alt="Seal Stamp">
                ` : ''}
                <div style="border-bottom: 1px solid #333; width: 100px; margin-bottom: 2px;"></div>
                <div style="font-size: 0.65rem; font-weight: 700;">${escapeHTML(signatureLabel)}</div>
              </div>
            </div>
          ` : ''}
        </div>
      `;
    };

    // 3. Format Switcher Handler
    wrapper.querySelectorAll('.receipt-format-card').forEach(card => {
      card.addEventListener('click', () => {
        wrapper.querySelectorAll('.receipt-format-card').forEach(c => {
          c.classList.remove('active');
          c.style.border = '1px solid var(--color-border)';
        });
        card.classList.add('active');
        card.style.border = '2px solid var(--color-primary)';
        currentFormat = card.dataset.format;
        if (billing) {
          billing.defaultTemplate = currentFormat;
          billing['billing.defaultTemplate'] = currentFormat;
        }
        if (store && store.settings && store.settings.billing) {
          store.settings.billing.defaultTemplate = currentFormat;
        }
        liveUpdateReceipt();
      });
    });

    // 4. Input & Color Sync Listeners
    wrapper.querySelectorAll('input, select, textarea').forEach(el => {
      el.addEventListener('input', liveUpdateReceipt);
      el.addEventListener('change', liveUpdateReceipt);
    });

    // Color pickers hex sync
    ['#rc-header-color', '#rc-stamp-color'].forEach(id => {
      const colInp = wrapper.querySelector(id);
      const txtInp = wrapper.querySelector(id + '-text');
      if (colInp && txtInp) {
        colInp.addEventListener('input', () => {
          txtInp.value = colInp.value;
          liveUpdateReceipt();
        });
        txtInp.addEventListener('input', () => {
          if (txtInp.value.startsWith('#') && txtInp.value.length === 7) {
            colInp.value = txtInp.value;
            liveUpdateReceipt();
          }
        });
      }
    });

    wrapper.querySelector('#btn-refresh-receipt-preview')?.addEventListener('click', liveUpdateReceipt);

    // 5. Test Print Handler
    wrapper.querySelector('#btn-test-print-receipt')?.addEventListener('click', () => {
      const printWindow = window.open('', '_blank');
      const content = paper.innerHTML;
      const widthCss = currentFormat === 'thermal58' ? '58mm' : (currentFormat === 'standardA4' ? '210mm' : '80mm');

      printWindow.document.write(`
        <!DOCTYPE html>
        <html>
        <head>
          <title>Test Print Receipt</title>
          <style>
            @page { size: ${widthCss} auto; margin: 0; }
            body { 
              margin: 0; 
              padding: 10px; 
              font-family: ${currentFormat === 'standardA4' ? 'sans-serif' : "'Courier New', Courier, monospace"}; 
              font-size: ${currentFormat === 'thermal58' ? '11px' : '13px'};
              color: #000;
              background: #fff;
              width: ${widthCss};
              box-sizing: border-box;
            }
            img { max-width: 100%; }
          </style>
        </head>
        <body>
          ${content}
          <script>
            window.onload = () => { window.print(); window.close(); };
          </script>
        </body>
        </html>
      `);
      printWindow.document.close();
    });

    // 6. Save Receipt Template Handler
    wrapper.querySelector('#btn-save-receipt-builder')?.addEventListener('click', async () => {
      const btnSave = wrapper.querySelector('#btn-save-receipt-builder');
      UI.buttonLoading(btnSave, true, 'Saving Template...');

      const prefix = wrapper.querySelector('#setting-bill-prefix')?.value?.trim() || 'LIB-2026';
      const subtitle = wrapper.querySelector('#rc-header-subtitle')?.value?.trim();
      const headerColor = wrapper.querySelector('#rc-header-color')?.value;
      const gstin = wrapper.querySelector('#rc-header-gstin')?.value?.trim();

      const showLogo = wrapper.querySelector('#rc-toggle-logo')?.checked;
      const showAddress = wrapper.querySelector('#rc-toggle-address')?.checked;
      const showContact = wrapper.querySelector('#rc-toggle-contact')?.checked;

      const showStuId = wrapper.querySelector('#rc-toggle-stuId')?.checked;
      const showStuPhone = wrapper.querySelector('#rc-toggle-stuPhone')?.checked;
      const showSeat = wrapper.querySelector('#rc-toggle-seat')?.checked;
      const showValidity = wrapper.querySelector('#rc-toggle-validity')?.checked;
      const showBreakdown = wrapper.querySelector('#rc-toggle-breakdown')?.checked;
      const showPaymentMode = wrapper.querySelector('#rc-toggle-paymentMode')?.checked;

      const showStamp = wrapper.querySelector('#rc-toggle-stamp')?.checked;
      const stampText = wrapper.querySelector('#rc-stamp-text')?.value?.trim();
      const stampColor = wrapper.querySelector('#rc-stamp-color')?.value;

      const showSignature = wrapper.querySelector('#rc-toggle-signature')?.checked;
      const signatureLabel = wrapper.querySelector('#rc-signature-label')?.value?.trim();
      const showUpiQr = wrapper.querySelector('#rc-toggle-upiqr')?.checked;
      const upiId = wrapper.querySelector('#setting-bill-upiId')?.value?.trim();

      const termsText = wrapper.querySelector('#rc-terms-text')?.value?.trim();
      const customNote = wrapper.querySelector('#rc-custom-note')?.value?.trim();
      const showTimestamp = wrapper.querySelector('#rc-toggle-timestamp')?.checked;

      const gstRate = Number(wrapper.querySelector('#setting-bill-gstRate')?.value || 18);
      const hsnCode = wrapper.querySelector('#setting-bill-hsn')?.value?.trim() || '999293';
      const refundDays = Number(wrapper.querySelector('#setting-bill-refundDays')?.value || 3);

      const accName = wrapper.querySelector('#setting-bank-accName')?.value?.trim();
      const accNo = wrapper.querySelector('#setting-bank-accNo')?.value?.trim();

      try {
        const payload = {
          activeTemplate: currentFormat,
          header: {
            showLogo,
            showBusinessName: true,
            subtitle,
            showAddress,
            showPhone: showContact,
            showEmail: showContact,
            showGst: Boolean(gstin),
            gstNumber: gstin,
            headerColor
          },
          body: {
            showStudentId: showStuId,
            showStudentPhone: showStuPhone,
            showSeatNumber: showSeat,
            showShift: showSeat,
            showPeriod: showValidity,
            showDiscount: showBreakdown,
            showPaymentMethod: showPaymentMode,
            showTransactionId: showPaymentMode
          },
          stamp: {
            showStamp,
            stampText,
            stampColor,
            showWatermark: currentFormat === 'standardA4'
          },
          footer: {
            showSignature,
            signatureLabel,
            showUpiQr,
            termsText,
            customNote,
            showTimestamp
          },
          gst: {
            enabled: gstRate > 0,
            gstRate,
            hsnCode
          }
        };

        const [rcRes, sysRes, profRes] = await Promise.all([
          api.put('/api/settings/receipt-config', payload),
          api.put('/api/settings/system-settings', {
            billing: {
              receiptPrefix: prefix,
              defaultTemplate: currentFormat,
              gstRate,
              hsnSacCode: hsnCode,
              refundPolicyDays: refundDays
            }
          }),
          api.put('/api/settings/profile', {
            upiId: upiId || profile.upiId,
            gstNumber: gstin,
            bankDetails: {
              accountName: accName || profile.bankDetails?.accountName,
              accountNumber: accNo || profile.bankDetails?.accountNumber
            }
          })
        ]);

        if (rcRes.success || sysRes.success) {
          Toast.success('Receipt Builder template & billing configuration saved successfully!');
        } else {
          Toast.error(rcRes.message || 'Failed to save template');
        }
      } catch (err) {
        Toast.error(err.message || 'Error saving receipt template');
      } finally {
        UI.buttonLoading(btnSave, false);
      }
    });

    // Initial render
    liveUpdateReceipt();
  }, 50);

  return wrapper;
}

// -------------------------------------------------------------
// 5B. 🧩 App Modules & Granular Feature Toggles Studio
// -------------------------------------------------------------
function renderModulesManagerStudio() {
  const wrapper = document.createElement('div');
  wrapper.className = 'card';
  wrapper.style.cssText = 'padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);';

  wrapper.innerHTML = `
    <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
      <div>
        <h3 style="margin: 0; font-size: 1.25rem; font-weight: 800; color: var(--color-primary);">🧩 App Modules & Granular Feature Toggles</h3>
        <p class="text-muted small mb-0">Turn any system module ON or OFF with 1-click. Disabled modules are immediately hidden from navigation and deactivated system-wide.</p>
      </div>
      <div class="d-flex gap-2 align-items-center flex-wrap">
        <button type="button" class="btn btn-xs btn-outline-secondary btn-expand-all-sections" id="btn-modules-expand-all" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">➕ Expand All</button>
        <button type="button" class="btn btn-xs btn-outline-secondary btn-collapse-all-sections" id="btn-modules-collapse-all" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">➖ Collapse All</button>
        <button type="button" id="btn-modules-enable-all" class="btn btn-sm btn-outline-success" style="font-weight: 700;">🟢 Enable All</button>
        <button type="button" id="btn-modules-disable-optional" class="btn btn-sm btn-outline-secondary" style="font-weight: 700;">⚪ Minimal Mode</button>
        <button type="button" id="btn-save-modules-config" class="btn btn-sm btn-primary" style="font-weight: 800; padding: 6px 18px;">💾 Save Module Settings</button>
      </div>
    </div>

    <div id="modules-loading-spinner" class="text-center p-4">
      <div class="spinner-border text-primary" role="status" style="width: 2rem; height: 2rem;"></div>
      <p class="text-muted small mt-2">Loading system modules & permissions...</p>
    </div>

    <div id="modules-grid-container" style="display: none;">
      <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 14px;" id="modules-cards-grid">
        <!-- Dynamic Module Cards -->
      </div>
    </div>
  `;

  setTimeout(async () => {
    try {
      const res = await api.get('/api/settings/sidebar/all');
      const items = (res.success && Array.isArray(res.data)) ? res.data : [];
      
      const moduleDescriptions = {
        dashboard: 'Executive overview, real-time KPI cards, revenue metrics & occupancy charts.',
        students: 'Directory of registered members, 360° profiles, KYC documents & identity passes.',
        seats: 'Interactive visual desk layout grid, branch selector & live shift occupancy.',
        lockers: 'Private study locker allocation, security keys & monthly recurring locker fees.',
        plans: 'Membership study tiers, pricing rules, validity duration & discount coupons.',
        payments: 'Fee collection register, GST tax invoices, partial payments & refund tracking.',
        attendance: 'Student check-in / check-out scanner, Kiosk terminal & biometric sync.',
        shifts: 'Operating study shifts (Morning, Evening, Full Day, 24x7) with price multipliers.',
        reports: 'Financial P&L statements, GSTR-1 sales reports & Tally Prime XML accounting exports.',
        expenses: 'Operational library expense log, vendor payments, utility bills & category tracking.',
        operations: 'Library operating schedule, weekly off days, emergency notices & holiday calendar.',
        settings: 'Master administration hub, branding, receipt templates & security configurations.',
        profile: 'Current user profile settings, credentials & active session info.'
      };

      const spinner = wrapper.querySelector('#modules-loading-spinner');
      const container = wrapper.querySelector('#modules-grid-container');
      const grid = wrapper.querySelector('#modules-cards-grid');
      if (spinner) spinner.style.display = 'none';
      if (container) container.style.display = 'block';

      grid.innerHTML = items.map(m => {
        const isSystem = m.isSystem;
        const isEnabled = m.isEnabled !== false;
        const desc = moduleDescriptions[m.key] || 'Core feature module of the Study Library platform.';
        return `
          <div class="card p-3 module-item-card" data-key="${escapeHTML(m.key)}" style="background: var(--color-bg-secondary); border: 1.5px solid ${isEnabled ? 'rgba(0, 184, 148, 0.4)' : 'var(--color-border)'}; border-radius: var(--radius-md); transition: all 0.2s;">
            <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 8px;">
              <div class="module-card-header" style="display: flex; align-items: center; gap: 10px; cursor: pointer; flex: 1;">
                <span style="font-size: 1.6rem; width: 38px; height: 38px; display: flex; align-items: center; justify-content: center; background: var(--color-surface); border-radius: 8px; border: 1px solid var(--color-border);">${m.icon || '📦'}</span>
                <div>
                  <h5 style="margin: 0; font-size: 0.98rem; font-weight: 800; color: var(--color-text-primary); display: flex; align-items: center; gap: 6px;">
                    ${escapeHTML(m.label)}
                    <span class="module-toggle-caret" style="font-size: 0.75rem; color: var(--color-text-muted);">▲</span>
                  </h5>
                  <code style="font-size: 0.72rem; color: var(--color-text-muted);">${escapeHTML(m.href)}</code>
                </div>
              </div>
              <div class="form-check form-switch" style="padding-left: 2.5em; margin: 0;">
                <input class="form-check-input module-toggle-switch" type="checkbox" role="switch" data-key="${escapeHTML(m.key)}" ${isEnabled ? 'checked' : ''} ${isSystem ? 'disabled' : ''} style="width: 2.2em; height: 1.2em; cursor: ${isSystem ? 'not-allowed' : 'pointer'};">
              </div>
            </div>
            
            <div class="module-details-body">
              <p style="font-size: 0.82rem; color: var(--color-text-secondary); margin: 6px 0 10px 0; line-height: 1.35;">
                ${escapeHTML(desc)}
              </p>

              <div style="display: flex; justify-content: space-between; align-items: center; border-top: 1px solid var(--color-border); padding-top: 8px; font-size: 0.75rem;">
                <span class="module-status-badge badge" style="background: ${isEnabled ? 'rgba(0, 184, 148, 0.15)' : 'rgba(108, 117, 125, 0.15)'}; color: ${isEnabled ? 'var(--color-success)' : 'var(--color-text-muted)'}; font-weight: 700;">
                  ${isEnabled ? '🟢 Active & Visible' : '⚪ Disabled (Hidden)'}
                </span>
                ${isSystem ? '<span class="badge badge-secondary" style="font-size: 0.65rem;">System Core</span>' : '<span class="text-muted">Custom Module</span>'}
              </div>
            </div>
          </div>
        `;
      }).join('');

      // Header click to toggle module details
      grid.querySelectorAll('.module-card-header').forEach(header => {
        header.addEventListener('click', () => {
          const card = header.closest('.module-item-card');
          const body = card?.querySelector('.module-details-body');
          const caret = card?.querySelector('.module-toggle-caret');
          if (!body) return;
          if (body.style.display === 'none') {
            body.style.display = 'block';
            if (caret) caret.textContent = '▲';
          } else {
            body.style.display = 'none';
            if (caret) caret.textContent = '▼';
          }
        });
      });

      // Toggle switch change listener
      grid.querySelectorAll('.module-toggle-switch').forEach(sw => {
        sw.addEventListener('change', () => {
          const card = sw.closest('.module-item-card');
          const badge = card.querySelector('.module-status-badge');
          if (sw.checked) {
            card.style.border = '1.5px solid rgba(0, 184, 148, 0.4)';
            badge.style.background = 'rgba(0, 184, 148, 0.15)';
            badge.style.color = 'var(--color-success)';
            badge.textContent = '🟢 Active & Visible';
          } else {
            card.style.border = '1.5px solid var(--color-border)';
            badge.style.background = 'rgba(108, 117, 125, 0.15)';
            badge.style.color = 'var(--color-text-muted)';
            badge.textContent = '⚪ Disabled (Hidden)';
          }
        });
      });

      // Enable all
      wrapper.querySelector('#btn-modules-enable-all')?.addEventListener('click', () => {
        grid.querySelectorAll('.module-toggle-switch').forEach(sw => {
          sw.checked = true;
          sw.dispatchEvent(new Event('change'));
        });
      });

      // Minimal mode (disable non-system modules like Lockers, Expenses, Operations)
      wrapper.querySelector('#btn-modules-disable-optional')?.addEventListener('click', () => {
        grid.querySelectorAll('.module-toggle-switch').forEach(sw => {
          if (!sw.disabled) {
            const key = sw.dataset.key;
            if (['lockers', 'expenses', 'operations', 'reports', 'attendance', 'shifts'].includes(key)) {
              sw.checked = false;
              sw.dispatchEvent(new Event('change'));
            }
          }
        });
      });

      // Save Handler
      wrapper.querySelector('#btn-save-modules-config')?.addEventListener('click', async () => {
        const btnSave = wrapper.querySelector('#btn-save-modules-config');
        UI.buttonLoading(btnSave, true, 'Saving Modules...');

        const updatedItems = items.map(orig => {
          const sw = grid.querySelector(`.module-toggle-switch[data-key="${orig.key}"]`);
          return {
            ...orig,
            isEnabled: sw ? sw.checked : (orig.isEnabled !== false)
          };
        });

        try {
          const saveRes = await api.put('/api/settings/sidebar', { items: updatedItems });
          if (saveRes.success) {
            Toast.success('Module settings saved successfully! Navigation refreshed.');
            try {
              const navOrder = updatedItems.filter(i => i.isEnabled !== false).map(i => i.href);
              localStorage.setItem('sl_sidebar_order', JSON.stringify(navOrder));
              if (window.SidebarSortable && window.SidebarSortable.init) {
                window.SidebarSortable.init();
              }
              window.dispatchEvent(new CustomEvent('sidebar-config-changed', { detail: updatedItems }));
            } catch(e) {}
          } else {
            Toast.error(saveRes.message || 'Failed to update modules');
          }
        } catch(err) {
          Toast.error(err.message || 'Error updating module configuration');
        } finally {
          UI.buttonLoading(btnSave, false);
        }
      });

    } catch (err) {
      console.error('Error in modules studio:', err);
    }
  }, 50);

  return wrapper;
}

// -------------------------------------------------------------
// 6. 🔔 WhatsApp & Notification Suite Studio
// -------------------------------------------------------------
function renderNotificationsStudio(notif, profile) {
const renderNotificationStudio = renderNotificationsStudio;
  return `
    <div class="card" style="padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
      <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
        <div>
          <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">🔔 WhatsApp Reminders, Bots & Automated Dispatch</h3>
          <p class="text-muted small mb-0">Automate payment reminder dispatch, seat expiry alerts, and interactive conversational bot.</p>
        </div>
        <div class="d-flex gap-2 align-items-center">
          <button type="button" class="btn btn-xs btn-outline-secondary btn-expand-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">➕ Expand All</button>
          <button type="button" class="btn btn-xs btn-outline-secondary btn-collapse-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">➖ Collapse All</button>
        </div>
      </div>

      <!-- Section 1: 🔔 WhatsApp Engine & Automated Reminders -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <h5><span>🔔</span> Automated WhatsApp Reminders Engine</h5>
          <span class="settings-accordion-toggle">▲</span>
        </div>
        <div class="settings-accordion-body">
          <div class="row g-3">
            <div class="col-md-6">
              <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <div class="form-check form-switch mb-2" style="font-size: 1.1rem;">
                  <input class="form-check-input" type="checkbox" id="setting-notif-wa" ${notif['notification.enableWhatsapp'] || notif.enableWhatsapp ? 'checked' : ''}>
                  <label class="form-check-label font-weight-bold" for="setting-notif-wa" style="font-size: 0.9rem; font-weight: 700;">Enable Automated WhatsApp Engine</label>
                </div>
                <p class="text-muted small mb-0">Dispatches 1-tap WhatsApp reminder links and gateway alerts to students.</p>
              </div>
            </div>

            <div class="col-md-6">
              <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <label class="form-label" style="font-weight: 700; font-size: 0.9rem;">Daily Automated Dispatch Schedule</label>
                <input type="time" id="setting-notif-time" class="form-control" value="${notif['notification.whatsappScheduleTime'] || notif.whatsappScheduleTime || '09:30'}">
                <small class="text-muted">Time when system checks and queues daily reminders</small>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Section 2: 🤖 Automated Bots Suite -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <h5><span>🤖</span> Automated AI Bots Suite (Expiry, Dues &amp; Conversational)</h5>
          <span class="settings-accordion-toggle">▲</span>
        </div>
        <div class="settings-accordion-body">
          <div class="row g-3">
            <div class="col-md-4">
              <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <div class="form-check form-switch mb-1">
                  <input class="form-check-input" type="checkbox" id="setting-notif-expiryBot" ${notif['notification.enableAutoExpiryBot'] !== false ? 'checked' : ''}>
                  <label class="form-check-label font-weight-bold" style="font-weight: 700; font-size: 0.88rem;">⏳ Expiry Alert Bot</label>
                </div>
                <small class="text-muted">Sends renewal alerts 3 days and 1 day before plan expires.</small>
              </div>
            </div>

            <div class="col-md-4">
              <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <div class="form-check form-switch mb-1">
                  <input class="form-check-input" type="checkbox" id="setting-notif-duesBot" ${notif['notification.enableAutoDuesBot'] !== false ? 'checked' : ''}>
                  <label class="form-check-label font-weight-bold" style="font-weight: 700; font-size: 0.88rem;">💳 Balance Due Bot</label>
                </div>
                <small class="text-muted">Notifies students with pending partial fee payments.</small>
              </div>
            </div>

            <div class="col-md-4">
              <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <div class="form-check form-switch mb-1">
                  <input class="form-check-input" type="checkbox" id="setting-notif-chatBot" ${notif['notification.enableConversationalBot'] !== false ? 'checked' : ''}>
                  <label class="form-check-label font-weight-bold" style="font-weight: 700; font-size: 0.88rem;">🤖 Conversational Bot</label>
                </div>
                <small class="text-muted">Replies to <code>!seat</code>, <code>!expiry</code>, and <code>!renew</code> commands.</small>
              </div>
            </div>
          </div>
        </div>
      </div>

    </div>
  `;
}

// -------------------------------------------------------------
// 7. ⏱️ Operations, Shifts & Attendance Rules Studio
// -------------------------------------------------------------
function renderOperationsStudio(ops) {
  return `
    <div class="card" style="padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
      <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
        <div>
          <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">⏱️ Library Operations, Schedule & Attendance Rules</h3>
          <p class="text-muted small mb-0">Configure operating hours, weekly off rules, and emergency notices.</p>
        </div>
        <div class="d-flex gap-2 align-items-center">
          <button type="button" class="btn btn-xs btn-outline-secondary btn-expand-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">➕ Expand All</button>
          <button type="button" class="btn btn-xs btn-outline-secondary btn-collapse-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">➖ Collapse All</button>
        </div>
      </div>

      <!-- Section 1: ⏱️ Opening Hours & Weekly Off Schedule -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <h5><span>⏱️</span> Campus Operating Hours &amp; Weekly Offs</h5>
          <span class="settings-accordion-toggle">▲</span>
        </div>
        <div class="settings-accordion-body">
          <div class="row g-3">
            <div class="col-md-4">
              <label class="form-label" style="font-weight: 700;">Opening Time</label>
              <input type="time" id="setting-ops-open" class="form-control" value="${ops['operations.openingTime'] || ops.openingTime || '06:00'}">
            </div>
            <div class="col-md-4">
              <label class="form-label" style="font-weight: 700;">Closing Time</label>
              <input type="time" id="setting-ops-close" class="form-control" value="${ops['operations.closingTime'] || ops.closingTime || '23:00'}">
            </div>
            <div class="col-md-4">
              <label class="form-label" style="font-weight: 700;">Weekly Off Day</label>
              <select id="setting-ops-weeklyOff" class="form-select">
                <option value="none" selected>None (Open All 7 Days)</option>
                <option value="sunday">Sunday Only</option>
                <option value="monday">Monday Only</option>
              </select>
            </div>
          </div>
        </div>
      </div>

      <!-- Section 2: 📢 Emergency Notice Board Banner -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <div style="display: flex; align-items: center; gap: 8px;">
            <h5><span>📢</span> Emergency Notice Board Banner</h5>
          </div>
          <div style="display: flex; align-items: center; gap: 10px;">
            <div class="form-check form-switch" style="margin: 0; font-size: 1.1rem;">
              <input class="form-check-input" type="checkbox" id="setting-ops-emergencyToggle" ${ops['operations.emergencyNoticeEnabled'] || ops.emergencyNoticeEnabled ? 'checked' : ''}>
              <label class="form-check-label small font-weight-bold" for="setting-ops-emergencyToggle" style="font-weight: 700;">Display Banner</label>
            </div>
            <span class="settings-accordion-toggle">▲</span>
          </div>
        </div>
        <div class="settings-accordion-body">
          <input type="text" id="setting-ops-emergencyNotice" class="form-control" value="${escapeHTML(ops['operations.emergencyNotice'] || ops.emergencyNotice || '')}" placeholder="e.g. Library will remain closed on 15th August for Independence Day.">
        </div>
      </div>

    </div>
  `;
}

// -------------------------------------------------------------
// 8. 👥 Staff Management, Roles & Granular Permissions Hub
// -------------------------------------------------------------
function renderStaffRbacStudio(staffUsers, branches) {
  const wrapper = document.createElement('div');
  wrapper.className = 'card';
  wrapper.style.cssText = 'padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);';

  wrapper.innerHTML = `
    <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
      <div>
        <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">👥 Staff Management, Roles & Granular Permissions</h3>
        <p class="text-muted small mb-0">Create staff accounts, assign branch access, and configure granular module permissions.</p>
      </div>
      <div class="d-flex gap-2 align-items-center flex-wrap">
        <button type="button" class="btn btn-xs btn-outline-secondary btn-expand-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">➕ Expand All</button>
        <button type="button" class="btn btn-xs btn-outline-secondary btn-collapse-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">➖ Collapse All</button>
        <button id="btn-add-staff-member" class="btn btn-sm btn-primary" style="font-weight: 700; display: inline-flex; align-items: center; gap: 6px;">
          <span>➕</span> Add Staff Member
        </button>
      </div>
    </div>

    <!-- Section 1: 👥 Staff Members Directory -->
    <div class="card settings-accordion-card">
      <div class="settings-accordion-header">
        <h5><span>👥</span> Staff Members &amp; Branch Access Directory (${staffUsers.length} Staff)</h5>
        <span class="settings-accordion-toggle">▲</span>
      </div>
      <div class="settings-accordion-body">
        <div class="table-responsive">
          <table class="table" style="font-size: 0.88rem;">
            <thead>
              <tr style="background: var(--color-bg-secondary);">
                <th>Staff Name</th>
                <th>Email</th>
                <th>Role</th>
                <th>Assigned Branch</th>
                <th>Status</th>
                <th style="text-align: right;">Actions</th>
              </tr>
            </thead>
            <tbody id="staff-table-body">
              ${staffUsers.length > 0 ? staffUsers.map(u => `
                <tr data-user-id="${escapeHTML(u._id || u.id)}">
                  <td><strong>${escapeHTML(u.name)}</strong></td>
                  <td>${escapeHTML(u.email)}</td>
                  <td><span class="badge" style="background: rgba(108,92,231,0.15); color: var(--color-primary); text-transform: uppercase;">${escapeHTML(u.role || 'staff')}</span></td>
                  <td>${escapeHTML(u.branch?.name || (branches.find(b => b._id === u.branch)?.name) || 'All Branches')}</td>
                  <td><span class="badge ${u.isActive !== false ? 'badge-success' : 'badge-danger'}">${u.isActive !== false ? 'Active' : 'Inactive'}</span></td>
                  <td style="text-align: right;">
                    <button class="btn btn-xs btn-outline-primary btn-edit-staff" data-id="${escapeHTML(u._id || u.id)}" style="padding: 2px 8px; font-size: 0.75rem;">✏️ Permissions</button>
                    <button class="btn btn-xs btn-outline-danger btn-del-staff" data-id="${escapeHTML(u._id || u.id)}" style="padding: 2px 8px; font-size: 0.75rem;">🗑️</button>
                  </td>
                </tr>
              `).join('') : `
                <tr>
                  <td><strong>Admin Superuser</strong></td>
                  <td>admin@studylibrary.com</td>
                  <td><span class="badge badge-primary">OWNER</span></td>
                  <td>All Branches</td>
                  <td><span class="badge badge-success">Active</span></td>
                  <td style="text-align: right;"><span class="text-muted small">Superadmin Account</span></td>
                </tr>
              `}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  `;

  // Add Staff Member Modal Handler
  setTimeout(() => {
    wrapper.querySelector('#btn-add-staff-member')?.addEventListener('click', () => {
      const modal = Modal.show({
        title: '➕ Add New Staff Team Member',
        content: `
          <form id="add-staff-form" class="row g-3">
            <div class="col-md-6">
              <label class="form-label" style="font-weight: 700;">Full Name *</label>
              <input type="text" id="staff-name" class="form-control" placeholder="e.g. Priya Sharma" required>
            </div>
            <div class="col-md-6">
              <label class="form-label" style="font-weight: 700;">Email Address *</label>
              <input type="email" id="staff-email" class="form-control" placeholder="staff@studylibrary.com" required>
            </div>
            <div class="col-md-6">
              <label class="form-label" style="font-weight: 700;">Phone Number</label>
              <input type="tel" id="staff-phone" class="form-control" placeholder="+91 9876543210">
            </div>
            <div class="col-md-6">
              <label class="form-label" style="font-weight: 700;">Login Password *</label>
              <input type="password" id="staff-pwd" class="form-control" placeholder="Minimum 6 characters" required>
            </div>
            <div class="col-md-6">
              <label class="form-label" style="font-weight: 700;">Assigned Role *</label>
              <select id="staff-role" class="form-select">
                <option value="branch_manager">Branch Manager (Full Branch Admin)</option>
                <option value="receptionist" selected>Receptionist (Admissions, Fees, Kiosk)</option>
                <option value="accountant">Accountant (Payments, Expenses, GST)</option>
                <option value="librarian">Librarian (Attendance, Seats, QR Scan)</option>
              </select>
            </div>
            <div class="col-md-6">
              <label class="form-label" style="font-weight: 700;">Assigned Branch</label>
              <select id="staff-branch" class="form-select">
                <option value="">All Branches / Main Complex</option>
                ${branches.map(b => `<option value="${b._id}">${escapeHTML(b.name)}</option>`).join('')}
              </select>
            </div>
          </form>
        `,
        actions: [
          { text: 'Cancel', class: 'btn-secondary', onClick: () => modal.close() },
          {
            text: 'Save Staff Member',
            class: 'btn-primary',
            onClick: async () => {
              const name = document.getElementById('staff-name')?.value?.trim();
              const email = document.getElementById('staff-email')?.value?.trim();
              const phone = document.getElementById('staff-phone')?.value?.trim();
              const password = document.getElementById('staff-pwd')?.value?.trim();
              const role = document.getElementById('staff-role')?.value;
              const branch = document.getElementById('staff-branch')?.value || null;

              if (!name || !email || !password) {
                Toast.error('Please enter name, email, and password');
                return;
              }

              try {
                const res = await api.post('/api/auth/register', { name, email, phone, password, role, branch });
                if (res.success) {
                  Toast.success(`Staff member ${name} created successfully!`);
                  modal.close();
                  render();
                } else {
                  Toast.error(res.message || 'Failed to create staff');
                }
              } catch (err) {
                Toast.error(err.message || 'Error creating staff');
              }
            }
          }
        ]
      });
    });

    // Edit Staff Permissions Modal
    wrapper.querySelectorAll('.btn-edit-staff').forEach(btn => {
      btn.addEventListener('click', () => {
        const uId = btn.dataset.id;
        const staff = staffUsers.find(u => (u._id || u.id) === uId);
        if (!staff) return;

        const modules = ['Students', 'Seats', 'Plans', 'Payments', 'Expenses', 'Reports', 'Operations', 'Settings'];
        const actions = ['View', 'Create', 'Edit', 'Delete', 'Export'];

        const permModal = Modal.show({
          title: `✏️ Staff Permissions — ${escapeHTML(staff.name)}`,
          content: `
            <div style="margin-bottom: 1rem;">
              <div class="row g-2 mb-3">
                <div class="col-md-6">
                  <label class="form-label small" style="font-weight: 700;">Staff Role</label>
                  <select id="edit-staff-role" class="form-select form-select-sm">
                    <option value="branch_manager" ${staff.role === 'branch_manager' ? 'selected' : ''}>Branch Manager</option>
                    <option value="receptionist" ${staff.role === 'receptionist' ? 'selected' : ''}>Receptionist</option>
                    <option value="accountant" ${staff.role === 'accountant' ? 'selected' : ''}>Accountant</option>
                    <option value="librarian" ${staff.role === 'librarian' ? 'selected' : ''}>Librarian</option>
                  </select>
                </div>
                <div class="col-md-6">
                  <label class="form-label small" style="font-weight: 700;">Account Status</label>
                  <select id="edit-staff-status" class="form-select form-select-sm">
                    <option value="true" ${staff.isActive !== false ? 'selected' : ''}>Active</option>
                    <option value="false" ${staff.isActive === false ? 'selected' : ''}>Inactive / Suspended</option>
                  </select>
                </div>
              </div>

              <h6 style="font-weight: 800; font-size: 0.9rem; color: var(--color-primary); margin-bottom: 8px;">Granular Module Permissions Matrix</h6>
              <div class="table-responsive">
                <table class="table table-bordered table-sm" style="font-size: 0.82rem; text-align: center;">
                  <thead>
                    <tr style="background: var(--color-bg-secondary);">
                      <th style="text-align: left;">Module</th>
                      ${actions.map(a => `<th>${a}</th>`).join('')}
                    </tr>
                  </thead>
                  <tbody>
                    ${modules.map(mod => `
                      <tr>
                        <td style="text-align: left; font-weight: 700;">${mod}</td>
                        ${actions.map(act => `
                          <td>
                            <input type="checkbox" class="perm-cb" data-mod="${mod.toLowerCase()}" data-act="${act.toLowerCase()}" checked>
                          </td>
                        `).join('')}
                      </tr>
                    `).join('')}
                  </tbody>
                </table>
              </div>
            </div>
          `,
          actions: [
            { text: 'Cancel', class: 'btn-secondary', onClick: () => permModal.close() },
            {
              text: 'Save Permissions',
              class: 'btn-primary',
              onClick: async () => {
                const newRole = document.getElementById('edit-staff-role')?.value;
                const newStatus = document.getElementById('edit-staff-status')?.value === 'true';
                try {
                  await api.put(`/api/auth/users/${uId}`, { role: newRole, isActive: newStatus });
                  Toast.success('Staff permissions updated successfully!');
                  permModal.close();
                  render();
                } catch (err) {
                  Toast.error(err.message || 'Failed to update staff');
                }
              }
            }
          ]
        });
      });
    });

    // Delete Staff Handler
    wrapper.querySelectorAll('.btn-del-staff').forEach(btn => {
      btn.addEventListener('click', async () => {
        const uId = btn.dataset.id;
        const confirmed = await Confirm.show('Are you sure you want to remove this staff account?');
        if (!confirmed) return;
        try {
          await api.delete(`/api/auth/users/${uId}`);
          Toast.success('Staff member removed successfully');
          render();
        } catch (err) {
          Toast.error(err.message || 'Failed to delete staff');
        }
      });
    });
  }, 50);

  return wrapper;
}

// -------------------------------------------------------------
// 9. 🌐 Website CMS, 4 Theme Presets & Live Split-Screen Studio
// -------------------------------------------------------------
function renderWebsiteCmsStudio() {
  const wrapper = document.createElement('div');
  wrapper.className = 'card';
  wrapper.style.cssText = 'padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);';

  const presetDefaults = {
    modern_glass: {
      primary: '#6c5ce7',
      accent: '#00b894',
      secondary: '#3b82f6',
      font: 'Outfit, sans-serif'
    },
    academic_clean: {
      primary: '#1e293b',
      accent: '#0284c7',
      secondary: '#64748b',
      font: 'Inter, sans-serif'
    },
    dark_cyber: {
      primary: '#06b6d4',
      accent: '#10b981',
      secondary: '#8b5cf6',
      font: 'Plus Jakarta Sans, sans-serif'
    },
    warm_cozy: {
      primary: '#b45309',
      accent: '#d97706',
      secondary: '#78350f',
      font: 'Playfair Display, serif'
    }
  };

  let currentPreset = 'modern_glass';
  let isMobilePreview = false;

  wrapper.innerHTML = `
    <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
      <div>
        <h3 style="margin: 0; font-size: 1.25rem; font-weight: 800; color: var(--color-primary);">🌐 Public Website CMS, 4 Theme Presets & Live Split-Screen Studio</h3>
        <p class="text-muted small mb-0">Select theme presets, customize color palettes, typography, hero banners, facilities, floating WhatsApp widgets, and SEO tags with instant live split-screen preview.</p>
      </div>
      <div class="d-flex gap-2 align-items-center">
        <a href="/landing" target="_blank" class="btn btn-sm btn-outline-primary" style="font-weight: 700;">👁️ Open Live Website (/landing) ↗</a>
        <button id="btn-save-website-cms" class="btn btn-sm btn-primary" style="font-weight: 800; padding: 6px 18px;">🚀 Publish Live Website</button>
      </div>
    </div>

    <!-- 4 Selectable Theme Presets -->
    <div style="margin-bottom: 1.5rem;">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
        <label class="form-label mb-0" style="font-weight: 800; font-size: 0.95rem; display: flex; align-items: center; gap: 6px;">
          <span>🎨</span> Select Visual Theme Preset
        </label>
        <span class="badge" style="background: rgba(108,92,231,0.12); color: var(--color-primary); font-size: 0.75rem;">1-Tap Instant Theme Apply</span>
      </div>
      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 12px;" id="theme-presets-grid">
        <div class="card p-3 theme-preset-card active" data-preset="modern_glass" style="border: 2px solid var(--color-primary); background: var(--color-surface); text-align: center; cursor: pointer; transition: all 0.2s; border-radius: var(--radius-md);">
          <span style="font-size: 1.8rem; margin-bottom: 4px;">✨</span>
          <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800; color: var(--color-text-primary);">Modern Glass</h5>
          <small class="text-muted d-block">Frosted glass & neon emerald glow</small>
          <div style="margin-top: 6px; display: flex; justify-content: center; gap: 4px;">
            <span style="width: 12px; height: 12px; border-radius: 50%; background: #6c5ce7; display: inline-block;"></span>
            <span style="width: 12px; height: 12px; border-radius: 50%; background: #00b894; display: inline-block;"></span>
            <span style="width: 12px; height: 12px; border-radius: 50%; background: #3b82f6; display: inline-block;"></span>
          </div>
        </div>

        <div class="card p-3 theme-preset-card" data-preset="academic_clean" style="border: 1px solid var(--color-border); background: var(--color-surface); text-align: center; cursor: pointer; transition: all 0.2s; border-radius: var(--radius-md);">
          <span style="font-size: 1.8rem; margin-bottom: 4px;">📖</span>
          <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800; color: var(--color-text-primary);">Academic Clean</h5>
          <small class="text-muted d-block">High contrast slate & ocean teal</small>
          <div style="margin-top: 6px; display: flex; justify-content: center; gap: 4px;">
            <span style="width: 12px; height: 12px; border-radius: 50%; background: #1e293b; display: inline-block;"></span>
            <span style="width: 12px; height: 12px; border-radius: 50%; background: #0284c7; display: inline-block;"></span>
            <span style="width: 12px; height: 12px; border-radius: 50%; background: #64748b; display: inline-block;"></span>
          </div>
        </div>

        <div class="card p-3 theme-preset-card" data-preset="dark_cyber" style="border: 1px solid var(--color-border); background: var(--color-surface); text-align: center; cursor: pointer; transition: all 0.2s; border-radius: var(--radius-md);">
          <span style="font-size: 1.8rem; margin-bottom: 4px;">⚡</span>
          <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800; color: var(--color-text-primary);">Dark Cyber</h5>
          <small class="text-muted d-block">Deep obsidian & bright cyan glow</small>
          <div style="margin-top: 6px; display: flex; justify-content: center; gap: 4px;">
            <span style="width: 12px; height: 12px; border-radius: 50%; background: #06b6d4; display: inline-block;"></span>
            <span style="width: 12px; height: 12px; border-radius: 50%; background: #10b981; display: inline-block;"></span>
            <span style="width: 12px; height: 12px; border-radius: 50%; background: #0b0f19; border: 1px solid #333; display: inline-block;"></span>
          </div>
        </div>

        <div class="card p-3 theme-preset-card" data-preset="warm_cozy" style="border: 1px solid var(--color-border); background: var(--color-surface); text-align: center; cursor: pointer; transition: all 0.2s; border-radius: var(--radius-md);">
          <span style="font-size: 1.8rem; margin-bottom: 4px;">🏛️</span>
          <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800; color: var(--color-text-primary);">Warm Cozy</h5>
          <small class="text-muted d-block">Parchment background & amber wood</small>
          <div style="margin-top: 6px; display: flex; justify-content: center; gap: 4px;">
            <span style="width: 12px; height: 12px; border-radius: 50%; background: #b45309; display: inline-block;"></span>
            <span style="width: 12px; height: 12px; border-radius: 50%; background: #d97706; display: inline-block;"></span>
            <span style="width: 12px; height: 12px; border-radius: 50%; background: #faf5ee; border: 1px solid #ccc; display: inline-block;"></span>
          </div>
        </div>
      </div>
    </div>

    <!-- Split-Screen Controls + Live Preview Layout -->
    <div style="display: grid; grid-template-columns: 1.05fr 1.15fr; gap: 20px;" class="cms-split-layout">
      
      <!-- Left Column: Collapsible Interactive Accordions -->
      <div style="display: flex; flex-direction: column; gap: 12px; max-height: 820px; overflow-y: auto; padding-right: 6px;" id="cms-accordions-col">
        
        <!-- Accordion Controls Toolbar -->
        <div style="display: flex; justify-content: space-between; align-items: center; padding-bottom: 4px;">
          <span style="font-size: 0.82rem; font-weight: 700; color: var(--color-text-secondary);">⚙️ Customization Sections</span>
          <div class="d-flex gap-2">
            <button type="button" id="btn-cms-expand-all" class="btn btn-xs btn-outline-secondary" style="font-size: 0.72rem; padding: 2px 8px;">➕ Expand All</button>
            <button type="button" id="btn-cms-collapse-all" class="btn btn-xs btn-outline-secondary" style="font-size: 0.72rem; padding: 2px 8px;">➖ Collapse All</button>
          </div>
        </div>

        <!-- Section 1: 🎨 Palette & Typography Overrides -->
        <div class="card cms-accordion-card" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md); overflow: visible;">
          <div class="cms-accordion-header p-3 d-flex justify-content-between align-items-center" style="cursor: pointer; user-select: none;">
            <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 6px;">
              <span>🎨</span> Color Palette & Typography Styling
            </h5>
            <span class="cms-accordion-toggle" style="font-size: 0.85rem; font-weight: bold; color: var(--color-text-muted); transition: transform 0.2s;">▲</span>
          </div>
          <div class="cms-accordion-body p-3 pt-0" style="display: block;">
            <div class="row g-2">
              <div class="col-md-4">
                <label class="form-label small" style="font-weight: 700;">Primary Color</label>
                <div style="display: flex; align-items: center; gap: 6px;">
                  <input type="color" id="cms-color-primary" class="form-control form-control-color p-0" value="#6c5ce7" style="width: 36px; height: 32px; cursor: pointer;">
                  <input type="text" id="cms-color-primary-text" class="form-control form-control-sm font-monospace" value="#6c5ce7" maxlength="7">
                </div>
              </div>
              <div class="col-md-4">
                <label class="form-label small" style="font-weight: 700;">Accent Color</label>
                <div style="display: flex; align-items: center; gap: 6px;">
                  <input type="color" id="cms-color-accent" class="form-control form-control-color p-0" value="#00b894" style="width: 36px; height: 32px; cursor: pointer;">
                  <input type="text" id="cms-color-accent-text" class="form-control form-control-sm font-monospace" value="#00b894" maxlength="7">
                </div>
              </div>
              <div class="col-md-4">
                <label class="form-label small" style="font-weight: 700;">Secondary Tint</label>
                <div style="display: flex; align-items: center; gap: 6px;">
                  <input type="color" id="cms-color-secondary" class="form-control form-control-color p-0" value="#3b82f6" style="width: 36px; height: 32px; cursor: pointer;">
                  <input type="text" id="cms-color-secondary-text" class="form-control form-control-sm font-monospace" value="#3b82f6" maxlength="7">
                </div>
              </div>
              <div class="col-12 mt-2">
                <label class="form-label small" style="font-weight: 700;">Typography Font Family</label>
                <select id="cms-font-family" class="form-select form-select-sm">
                  <option value="Outfit, sans-serif">Outfit (Modern, Clean & Geometric)</option>
                  <option value="Inter, sans-serif">Inter (High Legibility & Academic)</option>
                  <option value="Poppins, sans-serif">Poppins (Friendly & Rounded)</option>
                  <option value="Plus Jakarta Sans, sans-serif">Plus Jakarta Sans (Tech & Sleek)</option>
                  <option value="Playfair Display, serif">Playfair Display (Warm & Classic Serif)</option>
                  <option value="Roboto, sans-serif">Roboto (Standard Sans)</option>
                </select>
              </div>
            </div>
          </div>
        </div>

        <!-- Section 2: 🌟 Hero Banner & Headline -->
        <div class="card cms-accordion-card" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md); overflow: visible;">
          <div class="cms-accordion-header p-3 d-flex justify-content-between align-items-center" style="cursor: pointer; user-select: none;">
            <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 6px;">
              <span>🌟</span> Hero Section Headline & Action CTAs
            </h5>
            <span class="cms-accordion-toggle" style="font-size: 0.85rem; font-weight: bold; color: var(--color-text-muted); transition: transform 0.2s;">▲</span>
          </div>
          <div class="cms-accordion-body p-3 pt-0" style="display: block;">
            <div class="form-group mb-2">
              <label class="form-label small" style="font-weight: 700;">Hero Headline Title</label>
              <input type="text" id="cms-hero-title" class="form-control form-control-sm" value="Premier Air-Conditioned Study Library & Reading Hall">
              <small class="text-muted">Use <code>{library_name}</code> to dynamically display your business name</small>
            </div>
            <div class="form-group mb-2">
              <label class="form-label small" style="font-weight: 700;">Hero Subtitle</label>
              <input type="text" id="cms-hero-subtitle" class="form-control form-control-sm" value="Peaceful, Disciplined & Distraction-Free Study Environment for Competitive Exam Aspirants.">
            </div>
            <div class="form-group mb-2">
              <label class="form-label small" style="font-weight: 700;">Announcement Marquee Alert Ticker</label>
              <input type="text" id="cms-hero-ticker" class="form-control form-control-sm" value="⚡ Limited Seats Available for Morning & Full Day Shifts! Reserve Yours Today.">
            </div>
            <div class="row g-2">
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Primary CTA Button</label>
                <input type="text" id="cms-hero-cta-text" class="form-control form-control-sm" value="Book Your Seat / Register Now">
              </div>
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Secondary CTA Button</label>
                <input type="text" id="cms-hero-sec-text" class="form-control form-control-sm" value="Send Quick Enquiry">
              </div>
            </div>
          </div>
        </div>

        <!-- Section 3: ⚡ Key Facility Badges (6 Amenities) -->
        <div class="card cms-accordion-card" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md); overflow: visible;">
          <div class="cms-accordion-header p-3 d-flex justify-content-between align-items-center" style="cursor: pointer; user-select: none;">
            <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 6px;">
              <span>⚡</span> Key Facility & Amenities Badges
            </h5>
            <span class="cms-accordion-toggle" style="font-size: 0.85rem; font-weight: bold; color: var(--color-text-muted); transition: transform 0.2s;">▲</span>
          </div>
          <div class="cms-accordion-body p-3 pt-0" style="display: block;">
            <p class="text-muted small mb-2">Customize the 6 feature badges displayed on your landing page:</p>
            <div class="row g-2">
              <div class="col-6"><input type="text" id="cms-fac-1" class="form-control form-control-sm" value="❄️ 100% Inverter AC Hall"></div>
              <div class="col-6"><input type="text" id="cms-fac-2" class="form-control form-control-sm" value="🚀 300 Mbps Optical Fiber Wi-Fi"></div>
              <div class="col-6"><input type="text" id="cms-fac-3" class="form-control form-control-sm" value="🔋 Zero-Interruption Power Backup"></div>
              <div class="col-6"><input type="text" id="cms-fac-4" class="form-control form-control-sm" value="📹 24x7 HD CCTV Surveillance"></div>
              <div class="col-6"><input type="text" id="cms-fac-5" class="form-control form-control-sm" value="💧 Chilled & Hot RO Drinking Water"></div>
              <div class="col-6"><input type="text" id="cms-fac-6" class="form-control form-control-sm" value="🔐 Personal Storage Lockers"></div>
            </div>
          </div>
        </div>

        <!-- Section 4: 📖 About & Library Information -->
        <div class="card cms-accordion-card" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md); overflow: visible;">
          <div class="cms-accordion-header p-3 d-flex justify-content-between align-items-center" style="cursor: pointer; user-select: none;">
            <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 6px;">
              <span>📖</span> About Section & Library Atmosphere
            </h5>
            <span class="cms-accordion-toggle" style="font-size: 0.85rem; font-weight: bold; color: var(--color-text-muted); transition: transform 0.2s;">▲</span>
          </div>
          <div class="cms-accordion-body p-3 pt-0" style="display: block;">
            <div class="form-group mb-2">
              <label class="form-label small" style="font-weight: 700;">About Headline Title</label>
              <input type="text" id="cms-about-title" class="form-control form-control-sm" value="Why Choose Our Reading Hall?">
            </div>
            <div class="form-group mb-2">
              <label class="form-label small" style="font-weight: 700;">About Narrative / Mission</label>
              <textarea id="cms-about-desc" class="form-control form-control-sm" rows="3">Designed specifically for UPSC, MPSC, Banking, SSC, NEET/JEE, CA, and other exam aspirants. We provide ergonomic seating, high-speed Wi-Fi, pin-drop silence, and premium amenities to supercharge your study focus.</textarea>
            </div>
            <div class="form-group">
              <label class="form-label small" style="font-weight: 700;">Daily Operating Hours Notice</label>
              <input type="text" id="cms-opening-hours" class="form-control form-control-sm" value="Open Daily: 06:00 AM – 11:00 PM (365 Days)">
            </div>
          </div>
        </div>

        <!-- Section 5: 📱 Floating Quick Actions (WhatsApp & Direct Call) -->
        <div class="card cms-accordion-card" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md); overflow: visible;">
          <div class="cms-accordion-header p-3 d-flex justify-content-between align-items-center" style="cursor: pointer; user-select: none;">
            <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 6px;">
              <span>📱</span> Floating Quick Action Widgets (WhatsApp & Call)
            </h5>
            <span class="cms-accordion-toggle" style="font-size: 0.85rem; font-weight: bold; color: var(--color-text-muted); transition: transform 0.2s;">▲</span>
          </div>
          <div class="cms-accordion-body p-3 pt-0" style="display: block;">
            <div class="row g-2">
              <div class="col-md-6">
                <label class="form-label small" style="font-weight: 700;">Floating WhatsApp Support Number</label>
                <input type="tel" id="cms-floating-whatsapp" class="form-control form-control-sm" placeholder="+91 98765 43210">
              </div>
              <div class="col-md-6">
                <label class="form-label small" style="font-weight: 700;">Floating Direct Call Number</label>
                <input type="tel" id="cms-floating-call" class="form-control form-control-sm" placeholder="+91 98765 43210">
              </div>
            </div>
          </div>
        </div>

        <!-- Section 6: 🔍 SEO, Social Graph & Google Maps -->
        <div class="card cms-accordion-card" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md); overflow: visible;">
          <div class="cms-accordion-header p-3 d-flex justify-content-between align-items-center" style="cursor: pointer; user-select: none;">
            <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 6px;">
              <span>🔍</span> SEO, Social Share & Google Maps
            </h5>
            <span class="cms-accordion-toggle" style="font-size: 0.85rem; font-weight: bold; color: var(--color-text-muted); transition: transform 0.2s;">▲</span>
          </div>
          <div class="cms-accordion-body p-3 pt-0" style="display: block;">
            <div class="form-group mb-2">
              <label class="form-label small" style="font-weight: 700;">Google Search Page Title</label>
              <input type="text" id="cms-seo-title" class="form-control form-control-sm" value="Study Library & Reading Hall — Premium Self-Study Space">
            </div>
            <div class="form-group mb-2">
              <label class="form-label small" style="font-weight: 700;">Meta Description</label>
              <textarea id="cms-seo-desc" class="form-control form-control-sm" rows="2">Peaceful, air-conditioned study library with high-speed Wi-Fi, ergonomic seating, and 24x7 power backup.</textarea>
            </div>
            <div class="form-group">
              <label class="form-label small" style="font-weight: 700;">Google Maps Location Embed URL</label>
              <input type="url" id="cms-map-embed" class="form-control form-control-sm" placeholder="https://www.google.com/maps/embed?...">
            </div>
          </div>
        </div>

      </div>

      <!-- Right Column: Live Responsive Split-Screen Preview -->
      <div style="display: flex; flex-direction: column; position: sticky; top: 10px;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; flex-wrap: wrap; gap: 6px;">
          <div class="d-flex align-items-center gap-2">
            <span style="font-weight: 800; font-size: 0.9rem; color: var(--color-text-primary);">📱 Live Split-Screen Preview</span>
            <span class="badge badge-success" style="font-size: 0.7rem; font-weight: 700;">⚡ Instant Sync</span>
          </div>
          <div class="d-flex gap-1 align-items-center">
            <button type="button" id="btn-preview-mode-desktop" class="btn btn-xs btn-primary" style="padding: 2px 8px; font-weight: 700;">🖥️ Desktop</button>
            <button type="button" id="btn-preview-mode-mobile" class="btn btn-xs btn-outline-secondary" style="padding: 2px 8px; font-weight: 700;">📱 Mobile</button>
            <button type="button" id="btn-preview-reload" class="btn btn-xs btn-outline-secondary" style="padding: 2px 6px;" title="Hard Reload Preview">🔄</button>
          </div>
        </div>

        <div id="cms-preview-container" style="width: 100%; height: 720px; border: 2px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden; background: #0f121d; display: flex; justify-content: center; align-items: center; transition: all 0.3s;">
          <iframe id="cms-preview-frame" src="/landing?preview=true&theme=modern_glass" style="width: 100%; height: 100%; border: none; transition: width 0.3s ease;"></iframe>
        </div>
      </div>

    </div>
  `;

  // Attach interactive live preview listeners and fetch database config
  setTimeout(async () => {
    const iframe = wrapper.querySelector('#cms-preview-frame');
    const previewContainer = wrapper.querySelector('#cms-preview-container');

    // 0. Interactive Accordion Expand/Collapse Logic
    wrapper.querySelectorAll('.cms-accordion-header').forEach(header => {
      header.addEventListener('click', () => {
        const body = header.nextElementSibling;
        const icon = header.querySelector('.cms-accordion-toggle');
        if (body.style.display === 'none') {
          body.style.display = 'block';
          if (icon) icon.textContent = '▲';
        } else {
          body.style.display = 'none';
          if (icon) icon.textContent = '▼';
        }
      });
    });

    wrapper.querySelector('#btn-cms-expand-all')?.addEventListener('click', () => {
      wrapper.querySelectorAll('.cms-accordion-body').forEach(b => b.style.display = 'block');
      wrapper.querySelectorAll('.cms-accordion-toggle').forEach(t => t.textContent = '▲');
    });

    wrapper.querySelector('#btn-cms-collapse-all')?.addEventListener('click', () => {
      wrapper.querySelectorAll('.cms-accordion-body').forEach(b => b.style.display = 'none');
      wrapper.querySelectorAll('.cms-accordion-toggle').forEach(t => t.textContent = '▼');
    });

    // Helper to send live updates to preview iframe
    const dispatchLiveUpdate = () => {
      if (!iframe || !iframe.contentWindow) return;
      const primary = wrapper.querySelector('#cms-color-primary')?.value;
      const accent = wrapper.querySelector('#cms-color-accent')?.value;
      const secondary = wrapper.querySelector('#cms-color-secondary')?.value;
      const font = wrapper.querySelector('#cms-font-family')?.value;
      const heroTitle = wrapper.querySelector('#cms-hero-title')?.value;
      const heroSubtitle = wrapper.querySelector('#cms-hero-subtitle')?.value;
      const heroTicker = wrapper.querySelector('#cms-hero-ticker')?.value;

      iframe.contentWindow.postMessage({
        type: 'LIVE_CMS_UPDATE',
        preset: currentPreset,
        primaryColor: primary,
        accentColor: accent,
        secondaryColor: secondary,
        fontFamily: font,
        heroTitle: heroTitle,
        heroSubtitle: heroSubtitle,
        announcementTicker: heroTicker
      }, '*');
    };

    // 1. Fetch active Landing Page config from MongoDB and populate fields
    try {
      const res = await api.get('/api/landing');
      if (res.success && res.data) {
        const { landing = {}, businessProfile = {} } = res.data;
        if (landing.theme?.preset) {
          currentPreset = landing.theme.preset;
          wrapper.querySelectorAll('.theme-preset-card').forEach(c => {
            if (c.dataset.preset === currentPreset) {
              c.classList.add('active');
              c.style.border = '2px solid var(--color-primary)';
            } else {
              c.classList.remove('active');
              c.style.border = '1px solid var(--color-border)';
            }
          });
        }
        if (landing.theme?.primaryColor) {
          wrapper.querySelector('#cms-color-primary').value = landing.theme.primaryColor;
          wrapper.querySelector('#cms-color-primary-text').value = landing.theme.primaryColor;
        }
        if (landing.theme?.accentColor) {
          wrapper.querySelector('#cms-color-accent').value = landing.theme.accentColor;
          wrapper.querySelector('#cms-color-accent-text').value = landing.theme.accentColor;
        }
        if (landing.theme?.secondaryColor) {
          wrapper.querySelector('#cms-color-secondary').value = landing.theme.secondaryColor;
          wrapper.querySelector('#cms-color-secondary-text').value = landing.theme.secondaryColor;
        }
        if (landing.theme?.fontFamily) {
          wrapper.querySelector('#cms-font-family').value = landing.theme.fontFamily;
        }

        if (landing.hero?.title) wrapper.querySelector('#cms-hero-title').value = landing.hero.title;
        if (landing.hero?.subtitle) wrapper.querySelector('#cms-hero-subtitle').value = landing.hero.subtitle;
        if (landing.hero?.tickerText) wrapper.querySelector('#cms-hero-ticker').value = landing.hero.tickerText;
        if (landing.hero?.ctaPrimaryText) wrapper.querySelector('#cms-hero-cta-text').value = landing.hero.ctaPrimaryText;
        if (landing.hero?.ctaSecondaryText) wrapper.querySelector('#cms-hero-sec-text').value = landing.hero.ctaSecondaryText;

        if (landing.about?.title) wrapper.querySelector('#cms-about-title').value = landing.about.title;
        if (landing.about?.description) wrapper.querySelector('#cms-about-desc').value = landing.about.description;
        if (landing.contact?.openingHours) wrapper.querySelector('#cms-opening-hours').value = landing.contact.openingHours;

        if (landing.floatingActions?.whatsappNumber || businessProfile.phone) {
          wrapper.querySelector('#cms-floating-whatsapp').value = landing.floatingActions?.whatsappNumber || businessProfile.phone || '';
        }
        if (landing.floatingActions?.callNumber || businessProfile.phone) {
          wrapper.querySelector('#cms-floating-call').value = landing.floatingActions?.callNumber || businessProfile.phone || '';
        }

        if (landing.seo?.metaTitle) wrapper.querySelector('#cms-seo-title').value = landing.seo.metaTitle;
        if (landing.seo?.metaDescription) wrapper.querySelector('#cms-seo-desc').value = landing.seo.metaDescription;
        if (businessProfile.mapEmbedUrl || landing.footer?.mapEmbedUrl) {
          wrapper.querySelector('#cms-map-embed').value = businessProfile.mapEmbedUrl || landing.footer?.mapEmbedUrl || '';
        }

        if (Array.isArray(landing.facilities?.items)) {
          landing.facilities.items.forEach((fac, idx) => {
            const facInput = wrapper.querySelector(`#cms-fac-${idx + 1}`);
            if (facInput && fac.title) facInput.value = `${fac.icon || '⚡'} ${fac.title}`;
          });
        }

        // Set initial iframe preset
        if (iframe) iframe.src = `/landing?preview=true&theme=${currentPreset}&t=${Date.now()}`;
      }
    } catch (err) {
      console.warn('Failed to load landing config:', err);
    }

    // 2. Preset Selection Click Handlers
    wrapper.querySelectorAll('.theme-preset-card').forEach(card => {
      card.addEventListener('click', () => {
        wrapper.querySelectorAll('.theme-preset-card').forEach(c => {
          c.classList.remove('active');
          c.style.border = '1px solid var(--color-border)';
        });
        card.classList.add('active');
        card.style.border = '2px solid var(--color-primary)';
        currentPreset = card.dataset.preset;

        // Auto-update color pickers and typography to preset defaults
        const defaults = presetDefaults[currentPreset] || presetDefaults.modern_glass;
        wrapper.querySelector('#cms-color-primary').value = defaults.primary;
        wrapper.querySelector('#cms-color-primary-text').value = defaults.primary;
        wrapper.querySelector('#cms-color-accent').value = defaults.accent;
        wrapper.querySelector('#cms-color-accent-text').value = defaults.accent;
        wrapper.querySelector('#cms-color-secondary').value = defaults.secondary;
        wrapper.querySelector('#cms-color-secondary-text').value = defaults.secondary;
        wrapper.querySelector('#cms-font-family').value = defaults.font;

        if (iframe) {
          iframe.src = `/landing?preview=true&theme=${currentPreset}&t=${Date.now()}`;
        }
        if (iframe && iframe.contentWindow) {
          iframe.contentWindow.postMessage({
            type: 'PRESET_CHANGE',
            preset: currentPreset
          }, '*');
        }
        setTimeout(dispatchLiveUpdate, 150);
      });
    });

    // 3. Color Picker & Hex Sync
    ['primary', 'accent', 'secondary'].forEach(type => {
      const colorInput = wrapper.querySelector(`#cms-color-${type}`);
      const textInput = wrapper.querySelector(`#cms-color-${type}-text`);
      if (colorInput && textInput) {
        colorInput.addEventListener('input', () => {
          textInput.value = colorInput.value;
          dispatchLiveUpdate();
        });
        textInput.addEventListener('input', () => {
          if (textInput.value.startsWith('#') && textInput.value.length === 7) {
            colorInput.value = textInput.value;
            dispatchLiveUpdate();
          }
        });
      }
    });

    // 4. Live Text Inputs Sync
    ['#cms-font-family', '#cms-hero-title', '#cms-hero-subtitle', '#cms-hero-ticker'].forEach(sel => {
      wrapper.querySelector(sel)?.addEventListener('input', dispatchLiveUpdate);
    });

    // 5. Desktop vs Mobile Preview Toggle
    const btnDesktop = wrapper.querySelector('#btn-preview-mode-desktop');
    const btnMobile = wrapper.querySelector('#btn-preview-mode-mobile');

    btnDesktop?.addEventListener('click', () => {
      isMobilePreview = false;
      btnDesktop.classList.replace('btn-outline-secondary', 'btn-primary');
      btnMobile.classList.replace('btn-primary', 'btn-outline-secondary');
      if (iframe) {
        iframe.style.width = '100%';
        iframe.style.maxWidth = '100%';
      }
    });

    btnMobile?.addEventListener('click', () => {
      isMobilePreview = true;
      btnMobile.classList.replace('btn-outline-secondary', 'btn-primary');
      btnDesktop.classList.replace('btn-primary', 'btn-outline-secondary');
      if (iframe) {
        iframe.style.width = '375px';
        iframe.style.maxWidth = '375px';
        iframe.style.boxShadow = '0 0 20px rgba(0,0,0,0.5)';
        iframe.style.borderRadius = '16px';
      }
    });

    wrapper.querySelector('#btn-preview-reload')?.addEventListener('click', () => {
      if (iframe) iframe.src = `/landing?preview=true&theme=${currentPreset}&t=${Date.now()}`;
    });

    // 6. Save & Publish Website CMS Handler
    wrapper.querySelector('#btn-save-website-cms')?.addEventListener('click', async () => {
      const btnSave = wrapper.querySelector('#btn-save-website-cms');
      UI.buttonLoading(btnSave, true, 'Publishing...');

      const heroTitle = wrapper.querySelector('#cms-hero-title')?.value?.trim();
      const heroSubtitle = wrapper.querySelector('#cms-hero-subtitle')?.value?.trim();
      const heroTicker = wrapper.querySelector('#cms-hero-ticker')?.value?.trim();
      const heroCtaText = wrapper.querySelector('#cms-hero-cta-text')?.value?.trim();
      const heroSecText = wrapper.querySelector('#cms-hero-sec-text')?.value?.trim();

      const primaryColor = wrapper.querySelector('#cms-color-primary')?.value;
      const accentColor = wrapper.querySelector('#cms-color-accent')?.value;
      const secondaryColor = wrapper.querySelector('#cms-color-secondary')?.value;
      const fontFamily = wrapper.querySelector('#cms-font-family')?.value;

      const aboutTitle = wrapper.querySelector('#cms-about-title')?.value?.trim();
      const aboutDesc = wrapper.querySelector('#cms-about-desc')?.value?.trim();
      const openingHours = wrapper.querySelector('#cms-opening-hours')?.value?.trim();

      const whatsappNumber = wrapper.querySelector('#cms-floating-whatsapp')?.value?.trim();
      const callNumber = wrapper.querySelector('#cms-floating-call')?.value?.trim();

      const seoTitle = wrapper.querySelector('#cms-seo-title')?.value?.trim();
      const seoDesc = wrapper.querySelector('#cms-seo-desc')?.value?.trim();
      const mapEmbed = wrapper.querySelector('#cms-map-embed')?.value?.trim();

      // Collect Facility items
      const facilityItems = [];
      for (let i = 1; i <= 6; i++) {
        const val = wrapper.querySelector(`#cms-fac-${i}`)?.value?.trim();
        if (val) {
          const parts = val.split(' ');
          const icon = parts[0] || '⚡';
          const title = parts.slice(1).join(' ') || val;
          facilityItems.push({ icon, title, description: 'Premium study facility with uninterrupted comfort' });
        }
      }

      try {
        const payload = {
          theme: {
            preset: currentPreset,
            primaryColor,
            accentColor,
            secondaryColor,
            fontFamily
          },
          hero: {
            title: heroTitle,
            subtitle: heroSubtitle,
            tickerText: heroTicker,
            ctaPrimaryText: heroCtaText || 'Book Your Seat / Register Now',
            ctaSecondaryText: heroSecText || 'Send Quick Enquiry'
          },
          facilities: {
            enabled: true,
            items: facilityItems
          },
          about: {
            enabled: true,
            title: aboutTitle,
            description: aboutDesc
          },
          contact: {
            enabled: true,
            openingHours: openingHours || 'Open Daily: 06:00 AM – 11:00 PM (365 Days)'
          },
          floatingActions: {
            enabled: true,
            whatsappNumber: whatsappNumber || '',
            callNumber: callNumber || ''
          },
          seo: {
            metaTitle: seoTitle,
            metaDescription: seoDesc
          },
          businessProfile: {
            mapEmbedUrl: mapEmbed || ''
          }
        };

        const res = await api.put('/api/landing', payload);
        if (res.success) {
          Toast.success('Public Website published live with your customized theme preset!');
          if (iframe) iframe.src = `/landing?preview=true&theme=${currentPreset}&t=${Date.now()}`;
        } else {
          Toast.error(res.message || 'Failed to publish website');
        }
      } catch (err) {
        Toast.error(err.message || 'Error publishing website');
      } finally {
        UI.buttonLoading(btnSave, false);
      }
    });
  }, 50);

  return wrapper;
}

// -------------------------------------------------------------
// 10. 📱 Student Portal & Mobile App Feature Matrix Studio
// -------------------------------------------------------------
function renderStudentPortalStudio(portal, profile) {
  const isEnabled = (k) => portal[`portal.${k}`] !== false && portal[k] !== false;

  const toggles = [
    { key: 'enableOnlineRenewal', title: '💳 Online UPI Fee Renewal', desc: 'Allows students to pay fees online via QR code & UPI intent apps' },
    { key: 'enableSeatTransfer', title: '🔄 Seat / Desk Transfer Requests', desc: 'Allows students to submit self-service seat transfer requests' },
    { key: 'enableShiftSwitch', title: '🕒 Shift Switch Requests', desc: 'Allows students to request shift timing changes' },
    { key: 'enableIdPassDownload', title: '🪪 Digital Mobile ID Pass Download', desc: 'Generates 1080x1920px 9:16 mobile wallpaper ID passes' },
    { key: 'enableReceiptDownload', title: '🧾 Fee Receipt PDF Download', desc: 'Allows students to download official fee payment invoices' },
    { key: 'enableProfileEdit', title: '👤 Profile & KYC Self-Edit', desc: 'Permits students to update phone, emergency contacts, and photo' },
    { key: 'enableWebAuthn', title: '🔐 One-Touch Biometric FaceID Login', desc: 'Enables passkey and fingerprint authentication' },
    { key: 'enableGamifiedBadges', title: '🏆 Gamified Badges & Study Streak', desc: 'Displays study streak milestones and achievement trophies' },
    { key: 'enableReferralProgram', title: '🎁 Referral Program & Cashback Wallet', desc: 'Enables referral sharing links and cashback balances' },
    { key: 'enableAttendanceLogs', title: '📊 30-Day AI Study Heatmap', desc: 'Displays attendance heatmap logs and study duration graph' },
    { key: 'enableAnnouncements', title: '📢 Notice Board & Announcements', desc: 'Displays library alerts and emergency closure banners' },
    { key: 'enableLockerRequests', title: '🔒 Locker Allotment Requests', desc: 'Allows students to request personal locker storage' }
  ];

  return `
    <div class="card" style="padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
      <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
        <div>
          <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">📱 Student Portal & Mobile App Master Feature Matrix</h3>
          <p class="text-muted small mb-0">Granularly turn ON or OFF every button, self-service request, and card inside the Student Portal (/student-login).</p>
        </div>
        <div class="d-flex gap-2 align-items-center flex-wrap">
          <button type="button" class="btn btn-xs btn-outline-secondary btn-expand-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">➕ Expand All</button>
          <button type="button" class="btn btn-xs btn-outline-secondary btn-collapse-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">➖ Collapse All</button>
          <a href="/student-login" target="_blank" class="btn btn-sm btn-outline-primary" style="font-weight: 700;">👁️ Test Student Portal ↗</a>
        </div>
      </div>

      <!-- Section 1: 📱 Student Self-Service Feature Matrix -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <h5><span>📱</span> Active Student Portal Features &amp; Modules (${toggles.length} Modules)</h5>
          <span class="settings-accordion-toggle">▲</span>
        </div>
        <div class="settings-accordion-body">
          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 14px;">
            ${toggles.map(t => `
              <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md); display: flex; justify-content: space-between; align-items: center; gap: 12px;">
                <div>
                  <div style="font-weight: 700; font-size: 0.92rem; color: var(--color-text-primary); margin-bottom: 2px;">${t.title}</div>
                  <div style="font-size: 0.78rem; color: var(--color-text-secondary); line-height: 1.4;">${t.desc}</div>
                </div>
                <div class="form-check form-switch" style="margin: 0; font-size: 1.2rem;">
                  <input class="form-check-input student-portal-toggle" type="checkbox" data-key="${t.key}" ${isEnabled(t.key) ? 'checked' : ''}>
                </div>
              </div>
            `).join('')}
          </div>
        </div>
      </div>

    </div>
  `;
}

// -------------------------------------------------------------
// 11. 🤖 Automations & AI Business Insights Studio
// -------------------------------------------------------------
function renderAutomationsAiStudio(auto) {
  const wrapper = document.createElement('div');
  wrapper.className = 'card';
  wrapper.style.cssText = 'padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);';

  wrapper.innerHTML = `
    <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
      <div>
        <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">🤖 Automation Engine & AI Business Insights Studio</h3>
        <p class="text-muted small mb-0">Autonomous background tasks, AI revenue summaries, occupancy forecasts, and smart retention risk detection.</p>
      </div>
      <div class="d-flex gap-2 align-items-center">
        <button type="button" class="btn btn-xs btn-outline-secondary btn-expand-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">➕ Expand All</button>
        <button type="button" class="btn btn-xs btn-outline-secondary btn-collapse-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">➖ Collapse All</button>
      </div>
    </div>

    <!-- Section 1: ⚡ Autonomous System Daemons -->
    <div class="card settings-accordion-card">
      <div class="settings-accordion-header">
        <h5><span>⚡</span> Autonomous System Daemons &amp; Auto-Releases</h5>
        <span class="settings-accordion-toggle">▲</span>
      </div>
      <div class="settings-accordion-body">
        <div class="row g-3">
          <div class="col-md-6">
            <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
              <div class="form-check form-switch">
                <input class="form-check-input" type="checkbox" id="setting-auto-seatExpiry" ${auto['automations.autoSeatExpiry'] !== false ? 'checked' : ''}>
                <label class="form-check-label" style="font-weight: 700;">Auto-Release Expired Seats</label>
              </div>
              <small class="text-muted d-block mt-1">Automatically marks desk as vacant when plan expires + grace days</small>
            </div>
          </div>
          <div class="col-md-6">
            <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
              <div class="form-check form-switch">
                <input class="form-check-input" type="checkbox" id="setting-auto-dueReminders" ${auto['automations.autoDueReminders'] !== false ? 'checked' : ''}>
                <label class="form-check-label" style="font-weight: 700;">Auto-Dispatch Balance Due Reminders</label>
              </div>
              <small class="text-muted d-block mt-1">Schedules automated WhatsApp balance notifications</small>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Section 2: ✨ AI Business Intelligence & Analytics -->
    <div class="card settings-accordion-card">
      <div class="settings-accordion-header">
        <h5><span>✨</span> AI Business Intelligence &amp; Retention Analytics</h5>
        <div class="d-flex align-items-center gap-2">
          <button id="btn-refresh-ai-insights" class="btn btn-xs btn-outline-primary" style="font-weight: 700;">🔄 Refresh</button>
          <span class="settings-accordion-toggle">▲</span>
        </div>
      </div>
      <div class="settings-accordion-body">
        <div id="ai-insights-mount-container">
          <div style="padding: 2rem; text-align: center; color: var(--color-text-secondary);">
            <div class="loading-spinner" style="margin: 0 auto 8px auto;"></div>
            <p style="margin: 0; font-size: 0.88rem;">Generating AI insights from real-time database...</p>
          </div>
        </div>
      </div>
    </div>
  `;

  // Fetch AI Insights
  setTimeout(async () => {
    const mount = wrapper.querySelector('#ai-insights-mount-container');
    if (!mount) return;
    try {
      const res = await api.get('/api/ai/insights');
      const data = res?.data || {};
      const fin = data.financialSummary || {};
      const occ = data.occupancySummary || {};
      const risks = data.retentionRisks || [];

      mount.innerHTML = `
        <div class="row g-3">
          
          <!-- Financial Card -->
          <div class="col-md-6">
            <div class="card p-3" style="background: linear-gradient(135deg, rgba(108,92,231,0.08), rgba(0,184,148,0.08)); border: 1px solid var(--color-border);">
              <div style="font-size: 0.8rem; font-weight: 700; color: var(--color-primary); text-transform: uppercase;">💰 AI Revenue Growth Summary</div>
              <div style="font-size: 1.6rem; font-weight: 800; margin: 4px 0;">₹${Number(fin.thisMonthRevenue || 0).toLocaleString('en-IN')}</div>
              <div style="font-size: 0.82rem; color: ${fin.growthPercent >= 0 ? 'var(--color-success)' : 'var(--color-danger)'}; font-weight: 700;">
                ${fin.growthPercent >= 0 ? '▲ +' : '▼ '}${fin.growthPercent}% vs previous month
              </div>
              <div style="font-size: 0.78rem; color: var(--color-text-secondary); margin-top: 6px;">
                Average revenue per active student: <strong>₹${fin.avgRevenuePerMember || 0}</strong>
              </div>
            </div>
          </div>

          <!-- Occupancy Card -->
          <div class="col-md-6">
            <div class="card p-3" style="background: linear-gradient(135deg, rgba(59,130,246,0.08), rgba(16,185,129,0.08)); border: 1px solid var(--color-border);">
              <div style="font-size: 0.8rem; font-weight: 700; color: var(--color-primary); text-transform: uppercase;">💺 AI Capacity & Occupancy Forecast</div>
              <div style="font-size: 1.6rem; font-weight: 800; margin: 4px 0;">${occ.occupancyRate || 0}% Occupied</div>
              <div style="font-size: 0.82rem; color: var(--color-text-primary); font-weight: 600;">
                ${occ.occupiedSeats || 0} occupied / ${occ.totalSeats || 0} total desks (${occ.availableSeats || 0} vacant)
              </div>
              <div style="font-size: 0.78rem; color: var(--color-text-secondary); margin-top: 6px;">
                💡 <em>${escapeHTML(occ.insight || 'Capacity optimal.')}</em>
              </div>
            </div>
          </div>

          <!-- Retention Risks Table -->
          <div class="col-12 mt-2">
            <div class="card p-3" style="border: 1px solid var(--color-border);">
              <div style="font-weight: 700; font-size: 0.92rem; margin-bottom: 8px; display: flex; align-items: center; gap: 6px;">
                <span>🛡️</span> <span>AI Student Retention Watchlist (Expiring in 5 Days)</span>
              </div>
              <div class="table-responsive">
                <table class="table" style="font-size: 0.85rem;">
                  <thead>
                    <tr style="background: var(--color-bg-secondary);">
                      <th>Student Name</th>
                      <th>Phone</th>
                      <th>Days Left</th>
                      <th>Urgency</th>
                      <th>AI Suggested Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    ${risks.length > 0 ? risks.map(r => `
                      <tr>
                        <td><strong>${escapeHTML(r.name)}</strong></td>
                        <td>${escapeHTML(r.phone)}</td>
                        <td><strong>${r.daysLeft} days</strong></td>
                        <td><span class="badge" style="background: ${r.urgency === 'high' ? 'rgba(239,68,68,0.15)' : 'rgba(245,158,11,0.15)'}; color: ${r.urgency === 'high' ? '#ef4444' : '#f59e0b'}; text-transform: uppercase;">${r.urgency}</span></td>
                        <td><span class="text-muted small">${r.suggestedAction}</span></td>
                      </tr>
                    `).join('') : '<tr><td colspan="5" class="text-center p-3 text-muted">No students at immediate retention risk.</td></tr>'}
                  </tbody>
                </table>
              </div>
            </div>
          </div>

        </div>
      `;
    } catch (err) {
      mount.innerHTML = `<p class="text-muted p-3 text-center">AI insights calculation active.</p>`;
    }
  }, 50);

  return wrapper;
}

// -------------------------------------------------------------
// 12. 🔒 Security, Audit Trails & Backup Studio
// -------------------------------------------------------------
function renderSecurityBackupStudio() {
  return `
    <div class="card" style="padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
      <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
        <div>
          <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">🔒 Security, Immutable Audit Trails & Backups</h3>
          <p class="text-muted small mb-0">PIN lock, login history logs, immutable activity audit trails, and 1-click database export/restore.</p>
        </div>
        <div class="d-flex gap-2 align-items-center">
          <button type="button" class="btn btn-xs btn-outline-secondary btn-expand-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">➕ Expand All</button>
          <button type="button" class="btn btn-xs btn-outline-secondary btn-collapse-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">➖ Collapse All</button>
        </div>
      </div>

      <!-- Section 1: 🔐 PIN Lock & Database Snapshot -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <h5><span>🔐</span> Terminal Lock &amp; Database Backups</h5>
          <span class="settings-accordion-toggle">▲</span>
        </div>
        <div class="settings-accordion-body">
          <div class="row g-3">
            <div class="col-md-6">
              <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <h5 style="font-size: 0.95rem; font-weight: 700; margin-bottom: 6px;">🔐 Quick Admin PIN Lock</h5>
                <p class="text-muted small mb-3">Set a 4-digit PIN for instant terminal lock when stepping away from the front reception desk.</p>
                <div style="display: flex; gap: 8px;">
                  <input type="password" id="setting-sec-pin" maxlength="4" class="form-control font-monospace" placeholder="4-digit PIN" style="width: 140px; text-align: center; letter-spacing: 4px; font-size: 1.1rem;">
                  <button id="btn-save-pin" class="btn btn-sm btn-primary">Save PIN</button>
                </div>
              </div>
            </div>

            <div class="col-md-6">
              <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <h5 style="font-size: 0.95rem; font-weight: 700; margin-bottom: 6px;">💾 Database Snapshot & Export</h5>
                <p class="text-muted small mb-3">Download complete JSON or CSV data archives of all students, payments, and seats.</p>
                <div style="display: flex; gap: 8px; flex-wrap: wrap;">
                  <button id="btn-sec-export-json" class="btn btn-sm btn-outline-primary">📥 Export JSON Backup</button>
                  <a href="#/reports" class="btn btn-sm btn-outline-secondary">📊 Accounting Exports</a>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Section 2: 📜 System Activity Audit Trail -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <h5><span>📜</span> System Activity Audit Trail</h5>
          <div class="d-flex align-items-center gap-2">
            <a href="#/reports" class="btn btn-xs btn-outline-primary" style="font-weight: 700;">View Logs ↗</a>
            <span class="settings-accordion-toggle">▲</span>
          </div>
        </div>
        <div class="settings-accordion-body">
          <p class="text-muted small mb-0">Every student admission, fee payment, desk allocation, and settings change is recorded with user timestamp and IP address.</p>
        </div>
      </div>

    </div>
  `;
}

// -------------------------------------------------------------
// Universal Accordion & Expand/Collapse Controller
// -------------------------------------------------------------
function initStudioAccordions(scope) {
  if (!scope) return;

  // 1. Individual accordion headers toggle
  scope.querySelectorAll('.settings-accordion-header, .cms-accordion-header').forEach(header => {
    if (header.dataset.accordionBound) return;
    header.dataset.accordionBound = 'true';

    header.addEventListener('click', (e) => {
      // Ignore click if user clicked directly on form controls inside header
      if (e.target.closest('button, input, select, a, .form-switch, .form-check, label.form-check-label')) return;
      const body = header.nextElementSibling;
      const caret = header.querySelector('.settings-accordion-toggle, .cms-accordion-toggle');
      if (!body) return;

      if (body.style.display === 'none') {
        body.style.display = 'block';
        if (caret) caret.textContent = '▲';
      } else {
        body.style.display = 'none';
        if (caret) caret.textContent = '▼';
      }
    });
  });

  // 2. Expand All buttons across any studio
  scope.querySelectorAll('.btn-expand-all-sections, #btn-cms-expand-all, #btn-modules-expand-all').forEach(btn => {
    if (btn.dataset.bound) return;
    btn.dataset.bound = 'true';
    btn.addEventListener('click', () => {
      scope.querySelectorAll('.settings-accordion-body, .cms-accordion-body, .module-details-body').forEach(b => b.style.display = 'block');
      scope.querySelectorAll('.settings-accordion-toggle, .cms-accordion-toggle, .module-toggle-caret').forEach(c => c.textContent = '▲');
    });
  });

  // 3. Collapse All buttons across any studio
  scope.querySelectorAll('.btn-collapse-all-sections, #btn-cms-collapse-all, #btn-modules-collapse-all').forEach(btn => {
    if (btn.dataset.bound) return;
    btn.dataset.bound = 'true';
    btn.addEventListener('click', () => {
      scope.querySelectorAll('.settings-accordion-body, .cms-accordion-body, .module-details-body').forEach(b => b.style.display = 'none');
      scope.querySelectorAll('.settings-accordion-toggle, .cms-accordion-toggle, .module-toggle-caret').forEach(c => c.textContent = '▼');
    });
  });
}

// -------------------------------------------------------------
// Helper: Bind Studio Events
// -------------------------------------------------------------
function bindStudioEvents(container, studioId, store) {
  // Bind PIN lock save
  container.querySelector('#btn-save-pin')?.addEventListener('click', () => {
    const pin = container.querySelector('#setting-sec-pin')?.value;
    if (pin && pin.length === 4) {
      localStorage.setItem('sl_admin_pin', pin);
      Toast.success('Admin 4-digit PIN lock saved successfully!');
    } else {
      Toast.error('Please enter a valid 4-digit PIN.');
    }
  });

  // Export JSON Backup
  container.querySelector('#btn-sec-export-json')?.addEventListener('click', () => {
    container.querySelector('#btn-master-quick-backup')?.click();
  });

  // Add Staff Member Trigger
  container.querySelector('#btn-add-staff-member')?.addEventListener('click', () => {
    showAddStaffModal(container, store.branches || []);
  });

  // Refresh AI Insights Trigger
  container.querySelector('#btn-refresh-ai-insights')?.addEventListener('click', () => {
    Toast.info('Refreshing retention and revenue intelligence...');
    const viewport = container.querySelector('#master-studio-viewport');
    if (viewport) {
      viewport.innerHTML = '';
      viewport.appendChild(renderAutomationsAiStudio(store.settings.auto));
      bindStudioEvents(container, 'automations_ai', store);
    }
  });
}

function showAddStaffModal(container, branches) {
  const content = document.createElement('div');
  const branchOpts = branches.map(b => `<option value="${b._id}">${escapeHTML(b.name)}</option>`).join('');

  content.innerHTML = `
    <form id="form-add-staff" class="p-2">
      <div class="form-group mb-2">
        <label class="form-label" style="font-weight: 600;">Full Name *</label>
        <input type="text" id="staff-name" class="form-control" placeholder="e.g. Ramesh Kumar" required>
      </div>
      <div class="form-group mb-2">
        <label class="form-label" style="font-weight: 600;">Email Address (Login ID) *</label>
        <input type="email" id="staff-email" class="form-control" placeholder="e.g. ramesh@library.com" required>
      </div>
      <div class="form-group mb-2">
        <label class="form-label" style="font-weight: 600;">Password *</label>
        <input type="password" id="staff-password" class="form-control" placeholder="Create temporary password" required>
      </div>
      <div class="form-group mb-2">
        <label class="form-label" style="font-weight: 600;">Phone Number</label>
        <input type="tel" id="staff-phone" class="form-control" placeholder="10-digit mobile">
      </div>
      <div class="row g-2 mb-3">
        <div class="col-6">
          <label class="form-label" style="font-weight: 600;">Role *</label>
          <select id="staff-role" class="form-select form-control">
            <option value="staff">Staff / Receptionist</option>
            <option value="branch_manager">Branch Manager</option>
            <option value="owner">Admin / Co-Owner</option>
          </select>
        </div>
        <div class="col-6">
          <label class="form-label" style="font-weight: 600;">Assigned Centre</label>
          <select id="staff-branch" class="form-select form-control">
            <option value="">All Branches</option>
            ${branchOpts}
          </select>
        </div>
      </div>
      <div class="d-flex justify-content-end gap-2 pt-2 border-top">
        <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
        <button type="submit" class="btn btn-primary" id="btn-save-staff">Create Staff Account</button>
      </div>
    </form>
  `;

  const m = new Modal({
    title: '👥 Add Staff Team Member',
    content,
    size: 'md'
  });
  m.show();

  content.querySelector('#form-add-staff')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const name = content.querySelector('#staff-name').value.trim();
    const email = content.querySelector('#staff-email').value.trim();
    const password = content.querySelector('#staff-password').value;
    const phone = content.querySelector('#staff-phone').value.trim();
    const role = content.querySelector('#staff-role').value;
    const branch = content.querySelector('#staff-branch').value || null;

    try {
      await api.post('/api/auth/users', { name, email, password, phone, role, branch });
      Toast.success('Staff account created successfully!');
      m.close();
      render(container);
    } catch (err) {
      Toast.error(err.message || 'Failed to create staff account');
    }
  });
}

// -------------------------------------------------------------
// Helper: Save Settings
// -------------------------------------------------------------
async function saveActiveStudioSettings(container, studioId, store) {
  const btn = container.querySelector('#btn-master-save-all');
  Loading.button(btn, true);

  try {
    // 1. Merge and build Profile Payload (Preserves store.profile state across tabs)
    const profilePayload = {
      ...store.profile,
      businessName: container.querySelector('#setting-businessName')?.value?.trim() || store.profile.businessName,
      tagline: container.querySelector('#setting-tagline')?.value?.trim() || store.profile.tagline,
      phone: container.querySelector('#setting-phone')?.value?.trim() || store.profile.phone,
      email: container.querySelector('#setting-email')?.value?.trim() || store.profile.email,
      website: container.querySelector('#setting-website')?.value?.trim() || store.profile.website,
      address: container.querySelector('#setting-address')?.value?.trim() || store.profile.address,
      city: container.querySelector('#setting-city')?.value?.trim() || store.profile.city,
      state: container.querySelector('#setting-state')?.value?.trim() || store.profile.state,
      pincode: container.querySelector('#setting-pincode')?.value?.trim() || store.profile.pincode,
      registrationNumber: container.querySelector('#setting-regNumber')?.value?.trim() || store.profile.registrationNumber,
      gstNumber: container.querySelector('#setting-gstNumber')?.value?.trim() || store.profile.gstNumber,
      logo: (container.querySelector('#setting-logo') || container.querySelector('input[name="logo"]'))?.value?.trim() || store.profile.logo,
      favicon: (container.querySelector('#setting-favicon') || container.querySelector('input[name="favicon"]'))?.value?.trim() || store.profile.favicon,
      stampImage: (container.querySelector('#setting-stamp') || container.querySelector('input[name="stampImage"]'))?.value?.trim() || store.profile.stampImage,
      bannerImage: (container.querySelector('#setting-banner') || container.querySelector('input[name="bannerImage"]'))?.value?.trim() || store.profile.bannerImage,
      upiId: container.querySelector('#setting-bill-upiId')?.value?.trim() || store.profile.upiId,
      upiQrCode: (container.querySelector('#setting-bill-upiQr') || container.querySelector('input[name="upiQrCode"]'))?.value?.trim() || store.profile.upiQrCode,
      bankDetails: {
        ...(store.profile.bankDetails || {}),
        accountName: container.querySelector('#setting-bank-accName')?.value?.trim() || store.profile.bankDetails?.accountName,
        accountNumber: container.querySelector('#setting-bank-accNo')?.value?.trim() || store.profile.bankDetails?.accountNumber,
        bankName: container.querySelector('#setting-bank-name')?.value?.trim() || store.profile.bankDetails?.bankName,
        ifscCode: container.querySelector('#setting-bank-ifsc')?.value?.trim() || store.profile.bankDetails?.ifscCode,
        branchName: container.querySelector('#setting-bank-branch')?.value?.trim() || store.profile.bankDetails?.branchName
      },
      socialLinks: {
        ...(store.profile.socialLinks || {}),
        whatsapp: container.querySelector('#setting-social-wa')?.value?.trim() || store.profile.socialLinks?.whatsapp,
        instagram: container.querySelector('#setting-social-insta')?.value?.trim() || store.profile.socialLinks?.instagram,
        facebook: container.querySelector('#setting-social-fb')?.value?.trim() || store.profile.socialLinks?.facebook
      }
    };

    // 2. Merge and build System Settings Payload
    const sysPayload = {
      payment: {
        gracePeriod: container.querySelector('#setting-pay-grace')?.value ? Number(container.querySelector('#setting-pay-grace').value) : (store.settings.pay?.gracePeriod ?? 5),
        lateFeeAmount: container.querySelector('#setting-pay-lateFee')?.value ? Number(container.querySelector('#setting-pay-lateFee').value) : (store.settings.pay?.lateFeeAmount ?? 50),
        autoSuspendDays: container.querySelector('#setting-pay-suspend')?.value ? Number(container.querySelector('#setting-pay-suspend').value) : (store.settings.pay?.autoSuspendDays ?? 15)
      },
      locker: {
        enableAddon: container.querySelector('#setting-locker-enable') ? container.querySelector('#setting-locker-enable').checked : (store.settings.locker?.enableAddon !== false),
        monthlyFee: container.querySelector('#setting-locker-fee')?.value ? Number(container.querySelector('#setting-locker-fee').value) : (store.settings.locker?.monthlyFee ?? 200),
        deposit: container.querySelector('#setting-locker-deposit')?.value ? Number(container.querySelector('#setting-locker-deposit').value) : (store.settings.locker?.deposit ?? 0),
        title: container.querySelector('#setting-locker-title')?.value?.trim() || store.settings.locker?.title || 'Add Personal Study Locker',
        description: container.querySelector('#setting-locker-desc')?.value?.trim() || store.settings.locker?.description || 'Secure private key-allotted locker to safely keep heavy study books, notes & laptop.'
      },
      admission: {
        idPrefix: container.querySelector('#setting-adm-idPrefix')?.value?.trim() || store.settings.adm?.idPrefix || 'STU'
      },
      billing: {
        receiptPrefix: container.querySelector('#setting-bill-prefix')?.value?.trim() || store.settings.billing?.receiptPrefix || 'LIB-2026',
        defaultTemplate: container.querySelector('.receipt-format-card.active')?.dataset.format || store.settings.billing?.defaultTemplate || 'thermal80',
        gstRate: container.querySelector('#setting-bill-gstRate')?.value ? Number(container.querySelector('#setting-bill-gstRate').value) : (store.settings.billing?.gstRate ?? 18),
        hsnSacCode: container.querySelector('#setting-bill-hsn')?.value?.trim() || store.settings.billing?.hsnSacCode || '999293',
        refundPolicyDays: container.querySelector('#setting-bill-refundDays')?.value ? Number(container.querySelector('#setting-bill-refundDays').value) : (store.settings.billing?.refundPolicyDays ?? 3)
      },
      notification: {
        enableWhatsapp: container.querySelector('#setting-notif-wa') ? container.querySelector('#setting-notif-wa').checked : (store.settings.notif?.enableWhatsapp ?? true),
        whatsappScheduleTime: container.querySelector('#setting-notif-time')?.value || store.settings.notif?.whatsappScheduleTime || '09:30',
        enableAutoExpiryBot: container.querySelector('#setting-notif-expiryBot') ? container.querySelector('#setting-notif-expiryBot').checked : (store.settings.notif?.enableAutoExpiryBot !== false),
        enableAutoDuesBot: container.querySelector('#setting-notif-duesBot') ? container.querySelector('#setting-notif-duesBot').checked : (store.settings.notif?.enableAutoDuesBot !== false),
        enableConversationalBot: container.querySelector('#setting-notif-chatBot') ? container.querySelector('#setting-notif-chatBot').checked : (store.settings.notif?.enableConversationalBot !== false)
      },
      operations: {
        openingTime: container.querySelector('#setting-ops-open')?.value || store.settings.ops?.openingTime || '06:00',
        closingTime: container.querySelector('#setting-ops-close')?.value || store.settings.ops?.closingTime || '23:00',
        weeklyOff: container.querySelector('#setting-ops-weeklyOff')?.value || store.settings.ops?.weeklyOff || 'none',
        emergencyNotice: container.querySelector('#setting-ops-emergencyNotice')?.value?.trim() || store.settings.ops?.emergencyNotice || '',
        emergencyNoticeEnabled: container.querySelector('#setting-ops-emergencyToggle') ? container.querySelector('#setting-ops-emergencyToggle').checked : Boolean(store.settings.ops?.emergencyNoticeEnabled)
      },
      automations: {
        autoSeatExpiry: container.querySelector('#setting-auto-seatExpiry') ? container.querySelector('#setting-auto-seatExpiry').checked : (store.settings.auto?.autoSeatExpiry !== false),
        autoDueReminders: container.querySelector('#setting-auto-dueReminders') ? container.querySelector('#setting-auto-dueReminders').checked : (store.settings.auto?.autoDueReminders !== false)
      },
      portal: {
        ...(store.settings.portal || {})
      }
    };

    // Gather Student Portal Toggles
    container.querySelectorAll('.student-portal-toggle').forEach(t => {
      sysPayload.portal[t.dataset.key] = t.checked;
    });

    // Update in-memory store so subsequent operations have fresh state
    Object.assign(store.profile, profilePayload);
    Object.assign(store.settings, sysPayload);

    const [pRes, sRes] = await Promise.all([
      api.put('/api/settings/business-profile', profilePayload),
      api.put('/api/settings/system-settings', sysPayload)
    ]);

    if (pRes.success || sRes.success) {
      Toast.success('Master Settings updated successfully across all modules!');
      if (typeof window.updateDynamicFaviconAndTitle === 'function' && pRes.data) {
        window.updateDynamicFaviconAndTitle(pRes.data);
      }
    } else {
      Toast.error('Settings updated with warnings.');
    }
  } catch (err) {
    Toast.error(err.message || 'Failed to save settings.');
  } finally {
    Loading.button(btn, false);
  }
}
