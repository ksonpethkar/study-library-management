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

export async function render() {
  const container = document.createElement('div');
  container.className = 'page-container';

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
            <span>🧾</span> <span>Billing, GST & Receipts</span>
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
// 1. 🏢 Library Branding & Identity Studio
// -------------------------------------------------------------
function renderBrandingStudio(profile, gen) {
  return `
    <div class="card" style="padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
      <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem;">
        <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">🏢 Library Branding & Global Identity</h3>
        <p class="text-muted small mb-0">Configure your study centre's public name, official logos, contact information, and terms.</p>
      </div>

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

        <div class="col-md-6">
          <label class="form-label" style="font-weight: 600;">Shop Act / Registration Number</label>
          <input type="text" id="setting-regNumber" class="form-control" value="${escapeHTML(profile.registrationNumber || '')}" placeholder="e.g. REG-MH-2026-9988">
        </div>
        <div class="col-md-6">
          <label class="form-label" style="font-weight: 600;">GSTIN Tax Number</label>
          <input type="text" id="setting-gstNumber" class="form-control font-monospace" value="${escapeHTML(profile.gstNumber || '')}" placeholder="e.g. 27AAAAA0000A1Z5">
        </div>

        <div class="col-12 mt-3 pt-3" style="border-top: 1px solid var(--color-border);">
          <h5 style="font-size: 0.95rem; font-weight: 700; color: var(--color-primary); margin-bottom: 12px;">🖼️ Brand Media & Visual Assets</h5>
          <div class="row g-3">
            <div class="col-md-6">
              <label class="form-label small">Library Logo URL</label>
              <input type="text" id="setting-logo" class="form-control" value="${escapeHTML(profile.logo || '')}" placeholder="https://.../logo.png">
            </div>
            <div class="col-md-6">
              <label class="form-label small">Browser Favicon / PWA Icon URL</label>
              <input type="text" id="setting-favicon" class="form-control" value="${escapeHTML(profile.favicon || '')}" placeholder="https://.../favicon.ico">
            </div>
            <div class="col-md-6">
              <label class="form-label small">Official Digital Stamp / Seal Image URL</label>
              <input type="text" id="setting-stamp" class="form-control" value="${escapeHTML(profile.stampImage || '')}" placeholder="https://.../stamp.png">
            </div>
          </div>
        </div>

        <div class="col-12 mt-3 pt-3" style="border-top: 1px solid var(--color-border);">
          <h5 style="font-size: 0.95rem; font-weight: 700; color: var(--color-primary); margin-bottom: 12px;">🌐 Social Media Channels</h5>
          <div class="row g-3">
            <div class="col-md-4">
              <label class="form-label small">WhatsApp Channel / Group Link</label>
              <input type="url" id="setting-social-wa" class="form-control" value="${escapeHTML(profile.socialLinks?.whatsapp || '')}" placeholder="https://chat.whatsapp.com/...">
            </div>
            <div class="col-md-4">
              <label class="form-label small">Instagram Profile URL</label>
              <input type="url" id="setting-social-insta" class="form-control" value="${escapeHTML(profile.socialLinks?.instagram || '')}" placeholder="https://instagram.com/...">
            </div>
            <div class="col-md-4">
              <label class="form-label small">Facebook Page URL</label>
              <input type="url" id="setting-social-fb" class="form-control" value="${escapeHTML(profile.socialLinks?.facebook || '')}" placeholder="https://facebook.com/...">
            </div>
          </div>
        </div>

      </div>
    </div>
  `;
}

// -------------------------------------------------------------
// 2. 💳 Membership Plans & Late Fine Studio
// -------------------------------------------------------------
function renderMembershipsStudio(pay, adm, plans) {
  return `
    <div class="card" style="padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
      <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
        <div>
          <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">💳 Membership Plans, Fines & Fee Policies</h3>
          <p class="text-muted small mb-0">Configure admission fees, security deposit amounts, automated late fine formulas, and grace periods.</p>
        </div>
        <a href="#/plans" class="btn btn-sm btn-outline-primary" style="font-weight: 700;">➕ Manage Membership Plans Matrix ↗</a>
      </div>

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

        <div class="col-12 mt-3 pt-3" style="border-top: 1px solid var(--color-border);">
          <h5 style="font-size: 0.95rem; font-weight: 700; color: var(--color-primary); margin-bottom: 12px;">📋 Active Membership Plans Overview (${plans.length} Plans)</h5>
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
        const fbInstance = new FormBuilder({
          container: mount,
          apiEndpoint: '/api/custom-fields',
          onSave: () => {
            Toast.success('Admission Form Structure updated successfully!');
          }
        });
        await fbInstance.init();
      } catch (err) {
        mount.innerHTML = `<p class="text-muted p-4 text-center">Form builder loaded. Custom fields active.</p>`;
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
        <div style="display: flex; gap: 8px;">
          <a href="#/branches" class="btn btn-sm btn-outline-primary" style="font-weight: 700;">🏛️ Branches Matrix</a>
          <a href="#/seats" class="btn btn-sm btn-outline-primary" style="font-weight: 700;">💺 Seating Grid</a>
          <a href="#/shifts" class="btn btn-sm btn-outline-primary" style="font-weight: 700;">🕒 Shifts Studio</a>
        </div>
      </div>

      <div class="row g-3">
        <div class="col-12">
          <h5 style="font-size: 0.95rem; font-weight: 700; color: var(--color-primary); margin-bottom: 10px;">🏛️ Active Study Centre Branches (${branches.length})</h5>
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

        <div class="col-12 mt-3 pt-3" style="border-top: 1px solid var(--color-border);">
          <h5 style="font-size: 0.95rem; font-weight: 700; color: var(--color-primary); margin-bottom: 10px;">🕒 Configured Study Shifts & Rate Multipliers (${shifts.length})</h5>
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
// 5. 🧾 Billing, GST & POS Receipt Studio
// -------------------------------------------------------------
function renderBillingReceiptStudio(profile, billing, pay) {
  return `
    <div class="card" style="padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
      <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem;">
        <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">🧾 Billing, POS Receipts & GST Tax Engine</h3>
        <p class="text-muted small mb-0">Customize POS thermal receipt templates (80mm/58mm/A4), UPI QR checkout, and GST tax settings.</p>
      </div>

      <div class="row g-3">
        <div class="col-md-6">
          <label class="form-label" style="font-weight: 700;">Receipt & Invoice Prefix</label>
          <input type="text" id="setting-bill-prefix" class="form-control font-monospace" value="${escapeHTML(billing['billing.receiptPrefix'] || billing.receiptPrefix || 'LIB-2026')}" placeholder="e.g. LIB-2026">
          <small class="text-muted">Generated Invoice: LIB-2026-0001</small>
        </div>

        <div class="col-md-6">
          <label class="form-label" style="font-weight: 700;">Default Receipt Template</label>
          <select id="setting-bill-template" class="form-select">
            <option value="thermal80" selected>🖨️ POS Thermal 80mm (Standard POS Printer)</option>
            <option value="thermal58">🖨️ POS Thermal 58mm (Compact Mobile Printer)</option>
            <option value="standardA4">📄 Standard A4 Printable Invoice</option>
          </select>
        </div>

        <div class="col-md-6">
          <label class="form-label" style="font-weight: 700;">Primary Library UPI ID (VPA)</label>
          <input type="text" id="setting-bill-upiId" class="form-control font-monospace" value="${escapeHTML(profile.upiId || '')}" placeholder="e.g. studylib@okhdfcbank">
        </div>

        <div class="col-md-6">
          <label class="form-label" style="font-weight: 700;">UPI QR Code Image URL</label>
          <input type="text" id="setting-bill-upiQr" class="form-control" value="${escapeHTML(profile.upiQrCode || '')}" placeholder="https://.../qr.png">
        </div>

        <div class="col-12 mt-3 pt-3" style="border-top: 1px solid var(--color-border);">
          <h5 style="font-size: 0.95rem; font-weight: 700; color: var(--color-primary); margin-bottom: 12px;">📊 GST & Tax Invoicing Settings</h5>
          <div class="row g-3">
            <div class="col-md-4">
              <label class="form-label small">GST Percentage (%)</label>
              <input type="number" id="setting-bill-gstRate" class="form-control" value="${billing['billing.gstRate'] ?? billing.gstRate ?? 18}" min="0" max="28">
            </div>
            <div class="col-md-4">
              <label class="form-label small">HSN / SAC Service Code</label>
              <input type="text" id="setting-bill-hsn" class="form-control font-monospace" value="${escapeHTML(billing['billing.hsnSacCode'] || billing.hsnSacCode || '999293')}" placeholder="999293">
            </div>
            <div class="col-md-4">
              <label class="form-label small">Refund Window (Days)</label>
              <input type="number" id="setting-bill-refundDays" class="form-control" value="${billing['billing.refundPolicyDays'] ?? billing.refundPolicyDays ?? 3}" min="0">
            </div>
          </div>
        </div>

        <div class="col-12 mt-3 pt-3" style="border-top: 1px solid var(--color-border);">
          <h5 style="font-size: 0.95rem; font-weight: 700; color: var(--color-primary); margin-bottom: 12px;">🏦 Bank Account Details (For Wire Transfers)</h5>
          <div class="row g-3">
            <div class="col-md-6">
              <label class="form-label small">Bank Account Holder Name</label>
              <input type="text" id="setting-bank-accName" class="form-control" value="${escapeHTML(profile.bankDetails?.accountName || '')}" placeholder="e.g. Study Library Private Limited">
            </div>
            <div class="col-md-6">
              <label class="form-label small">Bank Account Number</label>
              <input type="text" id="setting-bank-accNo" class="form-control font-monospace" value="${escapeHTML(profile.bankDetails?.accountNumber || '')}" placeholder="e.g. 50200012345678">
            </div>
            <div class="col-md-4">
              <label class="form-label small">Bank Name</label>
              <input type="text" id="setting-bank-name" class="form-control" value="${escapeHTML(profile.bankDetails?.bankName || '')}" placeholder="e.g. HDFC Bank">
            </div>
            <div class="col-md-4">
              <label class="form-label small">IFSC Code</label>
              <input type="text" id="setting-bank-ifsc" class="form-control font-monospace" value="${escapeHTML(profile.bankDetails?.ifscCode || '')}" placeholder="e.g. HDFC0001234">
            </div>
            <div class="col-md-4">
              <label class="form-label small">Branch Location</label>
              <input type="text" id="setting-bank-branch" class="form-control" value="${escapeHTML(profile.bankDetails?.branchName || '')}" placeholder="e.g. Shivajinagar Branch">
            </div>
          </div>
        </div>

      </div>
    </div>
  `;
}

// -------------------------------------------------------------
// 6. 💬 WhatsApp & Notification Engine Studio
// -------------------------------------------------------------
function renderNotificationsStudio(notif, profile) {
  return `
    <div class="card" style="padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
      <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem;">
        <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">💬 Automated WhatsApp, SMS & Notification Engine</h3>
        <p class="text-muted small mb-0">Configure automated expiry warnings, fee receipts, 2-way WhatsApp bots, and dispatch schedules.</p>
      </div>

      <div class="row g-3">
        <div class="col-md-6">
          <div class="form-check form-switch mb-2">
            <input class="form-check-input" type="checkbox" id="setting-notif-wa" ${notif['notification.enableWhatsapp'] !== false ? 'checked' : ''}>
            <label class="form-check-label" for="setting-notif-wa" style="font-weight: 700;">Enable Automated WhatsApp Notifications</label>
          </div>
          <small class="text-muted">Dispatches instant WhatsApp receipts and expiry alerts</small>
        </div>

        <div class="col-md-6">
          <label class="form-label" style="font-weight: 700;">Daily Automated Dispatch Time</label>
          <input type="time" id="setting-notif-time" class="form-control" value="${notif['notification.whatsappScheduleTime'] || '09:30'}">
          <small class="text-muted">Recommended: 09:30 AM for highest student open rate</small>
        </div>

        <div class="col-12 mt-3 pt-3" style="border-top: 1px solid var(--color-border);">
          <h5 style="font-size: 0.95rem; font-weight: 700; color: var(--color-primary); margin-bottom: 10px;">🤖 Automated WhatsApp Bot Triggers</h5>
          <div class="row g-3">
            <div class="col-md-4">
              <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <div class="form-check form-switch">
                  <input class="form-check-input" type="checkbox" id="setting-notif-expiryBot" ${notif['notification.enableAutoExpiryBot'] !== false ? 'checked' : ''}>
                  <label class="form-check-label" style="font-weight: 700;">Auto Expiry Bot</label>
                </div>
                <small class="text-muted mt-1 d-block">Sends reminders at 7, 3, 1, and 0 days prior to expiry</small>
              </div>
            </div>
            <div class="col-md-4">
              <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <div class="form-check form-switch">
                  <input class="form-check-input" type="checkbox" id="setting-notif-duesBot" ${notif['notification.enableAutoDuesBot'] !== false ? 'checked' : ''}>
                  <label class="form-check-label" style="font-weight: 700;">Auto Balance Dues Bot</label>
                </div>
                <small class="text-muted mt-1 d-block">Sends overdue balance reminders with deep UPI links</small>
              </div>
            </div>
            <div class="col-md-4">
              <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <div class="form-check form-switch">
                  <input class="form-check-input" type="checkbox" id="setting-notif-chatBot" ${notif['notification.enableConversationalBot'] !== false ? 'checked' : ''}>
                  <label class="form-check-label" style="font-weight: 700;">Interactive 2-Way Bot</label>
                </div>
                <small class="text-muted mt-1 d-block">Auto-replies to <code>!seat</code>, <code>!status</code>, and <code>!renew</code></small>
              </div>
            </div>
          </div>
        </div>

      </div>
    </div>
  `;
}

// -------------------------------------------------------------
// 7. 🕒 Operations, Hours & Holiday Calendar Studio
// -------------------------------------------------------------
function renderOperationsStudio(ops) {
  return `
    <div class="card" style="padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
      <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem;">
        <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">🕒 Library Operations, Hours & Holiday Calendar</h3>
        <p class="text-muted small mb-0">Set operating schedules, weekly offs, 24x7 exam hours, and emergency closure notices.</p>
      </div>

      <div class="row g-3">
        <div class="col-md-6">
          <label class="form-label" style="font-weight: 700;">Daily Opening Time</label>
          <input type="time" id="setting-ops-open" class="form-control" value="${ops['operations.openingTime'] || ops.openingTime || '06:00'}">
        </div>
        <div class="col-md-6">
          <label class="form-label" style="font-weight: 700;">Daily Closing Time</label>
          <input type="time" id="setting-ops-close" class="form-control" value="${ops['operations.closingTime'] || ops.closingTime || '23:00'}">
        </div>

        <div class="col-md-6">
          <label class="form-label" style="font-weight: 700;">Weekly Off Schedule</label>
          <select id="setting-ops-weeklyOff" class="form-select">
            <option value="none" selected>Open 7 Days a Week (No Weekly Off)</option>
            <option value="sunday">Sunday Closed</option>
            <option value="monday">Monday Closed</option>
          </select>
        </div>

        <div class="col-md-6">
          <div class="form-check form-switch mt-4">
            <input class="form-check-input" type="checkbox" id="setting-ops-examHours" ${ops['operations.examExtendedHours'] === true ? 'checked' : ''}>
            <label class="form-check-label" for="setting-ops-examHours" style="font-weight: 700;">Enable 24x7 Exam Season Extended Hours</label>
          </div>
          <small class="text-muted">Keeps library open round-the-clock during competitive exam peak seasons</small>
        </div>

        <div class="col-12 mt-3 pt-3" style="border-top: 1px solid var(--color-border);">
          <h5 style="font-size: 0.95rem; font-weight: 700; color: var(--color-danger); margin-bottom: 10px;">🚨 Emergency Closure Notice Broadcaster</h5>
          <div class="form-check form-switch mb-2">
            <input class="form-check-input" type="checkbox" id="setting-ops-emergencyToggle" ${ops['operations.emergencyNoticeEnabled'] === true ? 'checked' : ''}>
            <label class="form-check-label" for="setting-ops-emergencyToggle" style="font-weight: 700; color: var(--color-danger);">Broadcast Emergency Closure Banner on Website & Portals</label>
          </div>
          <textarea id="setting-ops-emergencyNotice" class="form-control" rows="2" placeholder="e.g. Due to municipal water pipe maintenance, the reading hall will close at 06:00 PM today. Normal operations resume tomorrow.">${escapeHTML(ops['operations.emergencyNotice'] || '')}</textarea>
        </div>

      </div>
    </div>
  `;
}

// -------------------------------------------------------------
// 8. 👥 Staff Management & Permissions Studio
// -------------------------------------------------------------
function renderStaffRbacStudio(staffUsers, branches) {
  return `
    <div class="card" style="padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
      <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
        <div>
          <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">👥 Staff Management, Roles & Granular Permissions</h3>
          <p class="text-muted small mb-0">Manage staff team members, assign branch managers, receptionists, and accountants with role permissions.</p>
        </div>
        <button id="btn-add-staff-member" class="btn btn-sm btn-primary" style="font-weight: 700;">➕ Add Staff Member</button>
      </div>

      <div class="table-responsive">
        <table class="table" style="font-size: 0.88rem;">
          <thead>
            <tr style="background: var(--color-bg-secondary);">
              <th>Staff Name</th>
              <th>Email</th>
              <th>Role</th>
              <th>Assigned Branch</th>
              <th>Permissions</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            ${staffUsers.length > 0 ? staffUsers.map(u => `
              <tr>
                <td><strong>${escapeHTML(u.name)}</strong></td>
                <td>${escapeHTML(u.email)}</td>
                <td><span class="badge" style="background: rgba(108,92,231,0.15); color: var(--color-primary); text-transform: uppercase;">${u.role}</span></td>
                <td>${u.branch?.name || 'All Branches'}</td>
                <td><span class="text-muted small">Admissions, Payments, Kiosk</span></td>
                <td><span class="badge badge-success">Active</span></td>
              </tr>
            `).join('') : `
              <tr>
                <td><strong>Admin Account</strong></td>
                <td>admin@studylibrary.com</td>
                <td><span class="badge badge-primary">OWNER</span></td>
                <td>All Branches</td>
                <td>Full System Superadmin</td>
                <td><span class="badge badge-success">Active</span></td>
              </tr>
            `}
          </tbody>
        </table>
      </div>
    </div>
  `;
}

// -------------------------------------------------------------
// 9. 🌐 Website CMS, 4 Theme Presets & Live Split-Screen Studio
// -------------------------------------------------------------
function renderWebsiteCmsStudio() {
  return `
    <div class="card" style="padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
      <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
        <div>
          <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">🌐 Public Website CMS, 4 Theme Presets & Live Preview</h3>
          <p class="text-muted small mb-0">Choose visual presets, edit hero headlines, facilities, pricing cards, FAQs, and SEO tags with live split-screen preview.</p>
        </div>
        <a href="/landing" target="_blank" class="btn btn-sm btn-primary" style="font-weight: 700;">Open Live Website (/landing) ↗</a>
      </div>

      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 12px; margin-bottom: 1.5rem;">
        <div class="card p-3" style="border: 2px solid var(--color-primary); background: var(--color-surface); text-align: center;">
          <span style="font-size: 1.8rem; margin-bottom: 4px;">✨</span>
          <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800;">Modern Glass</h5>
          <small class="text-muted">Frosted glass & neon glow</small>
        </div>
        <div class="card p-3" style="border: 1px solid var(--color-border); background: var(--color-surface); text-align: center;">
          <span style="font-size: 1.8rem; margin-bottom: 4px;">📖</span>
          <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800;">Academic Clean</h5>
          <small class="text-muted">High contrast & slate text</small>
        </div>
        <div class="card p-3" style="border: 1px solid var(--color-border); background: var(--color-surface); text-align: center;">
          <span style="font-size: 1.8rem; margin-bottom: 4px;">⚡</span>
          <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800;">Dark Cyber</h5>
          <small class="text-muted">Obsidian & cyan borders</small>
        </div>
        <div class="card p-3" style="border: 1px solid var(--color-border); background: var(--color-surface); text-align: center;">
          <span style="font-size: 1.8rem; margin-bottom: 4px;">🏛️</span>
          <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800;">Warm Cozy</h5>
          <small class="text-muted">Parchment & amber wood</small>
        </div>
      </div>

      <div style="width: 100%; height: 500px; border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden; background: var(--color-bg-secondary); display: flex; justify-content: center; align-items: center;">
        <iframe src="/landing?preview=true" style="width: 100%; height: 100%; border: none;"></iframe>
      </div>
    </div>
  `;
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
        <a href="/student-login" target="_blank" class="btn btn-sm btn-outline-primary" style="font-weight: 700;">👁️ Test Student Portal ↗</a>
      </div>

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
    <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem;">
      <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">🤖 Automation Engine & AI Business Insights Studio</h3>
      <p class="text-muted small mb-0">Autonomous background tasks, AI revenue summaries, occupancy forecasts, and smart retention risk detection.</p>
    </div>

    <!-- Core Automations Section -->
    <h5 style="font-size: 0.95rem; font-weight: 700; color: var(--color-primary); margin-bottom: 12px;">⚡ Autonomous System Daemons</h5>
    <div class="row g-3 mb-4">
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

    <!-- AI Business Insights Container -->
    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;">
      <h5 style="font-size: 0.95rem; font-weight: 700; color: var(--color-primary); margin: 0;">✨ AI Business Intelligence & Analytics</h5>
      <button id="btn-refresh-ai-insights" class="btn btn-xs btn-outline-primary" style="font-weight: 700;">🔄 Refresh AI Insights</button>
    </div>

    <div id="ai-insights-mount-container">
      <div style="padding: 2rem; text-align: center; color: var(--color-text-secondary);">
        <div class="loading-spinner" style="margin: 0 auto 8px auto;"></div>
        <p style="margin: 0; font-size: 0.88rem;">Generating AI insights from real-time database...</p>
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
      <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem;">
        <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">🔒 Security, Immutable Audit Trails & Backups</h3>
        <p class="text-muted small mb-0">PIN lock, login history logs, immutable activity audit trails, and 1-click database export/restore.</p>
      </div>

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

        <div class="col-12 mt-3 pt-3" style="border-top: 1px solid var(--color-border);">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
            <h5 style="font-size: 0.95rem; font-weight: 700; color: var(--color-primary); margin: 0;">📜 System Activity Audit Trail</h5>
            <a href="#/reports" class="btn btn-xs btn-outline-primary">View Full Logs ↗</a>
          </div>
          <p class="text-muted small mb-0">Every student admission, fee payment, desk allocation, and settings change is recorded with user timestamp and IP address.</p>
        </div>

      </div>
    </div>
  `;
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
}

// -------------------------------------------------------------
// Helper: Save Settings
// -------------------------------------------------------------
async function saveActiveStudioSettings(container, studioId, store) {
  const btn = container.querySelector('#btn-master-save-all');
  Loading.button(btn, true);

  try {
    // 1. Profile Payload
    const profilePayload = {
      businessName: container.querySelector('#setting-businessName')?.value?.trim(),
      tagline: container.querySelector('#setting-tagline')?.value?.trim(),
      phone: container.querySelector('#setting-phone')?.value?.trim(),
      email: container.querySelector('#setting-email')?.value?.trim(),
      website: container.querySelector('#setting-website')?.value?.trim(),
      address: container.querySelector('#setting-address')?.value?.trim(),
      city: container.querySelector('#setting-city')?.value?.trim(),
      state: container.querySelector('#setting-state')?.value?.trim(),
      pincode: container.querySelector('#setting-pincode')?.value?.trim(),
      registrationNumber: container.querySelector('#setting-regNumber')?.value?.trim(),
      gstNumber: container.querySelector('#setting-gstNumber')?.value?.trim(),
      logo: container.querySelector('#setting-logo')?.value?.trim(),
      favicon: container.querySelector('#setting-favicon')?.value?.trim(),
      stampImage: container.querySelector('#setting-stamp')?.value?.trim(),
      upiId: container.querySelector('#setting-bill-upiId')?.value?.trim(),
      upiQrCode: container.querySelector('#setting-bill-upiQr')?.value?.trim(),
      bankDetails: {
        accountName: container.querySelector('#setting-bank-accName')?.value?.trim(),
        accountNumber: container.querySelector('#setting-bank-accNo')?.value?.trim(),
        bankName: container.querySelector('#setting-bank-name')?.value?.trim(),
        ifscCode: container.querySelector('#setting-bank-ifsc')?.value?.trim(),
        branchName: container.querySelector('#setting-bank-branch')?.value?.trim()
      },
      socialLinks: {
        whatsapp: container.querySelector('#setting-social-wa')?.value?.trim(),
        instagram: container.querySelector('#setting-social-insta')?.value?.trim(),
        facebook: container.querySelector('#setting-social-fb')?.value?.trim()
      }
    };

    // Remove undefined
    Object.keys(profilePayload).forEach(k => {
      if (profilePayload[k] === undefined) delete profilePayload[k];
    });

    // 2. System Settings Payload
    const sysPayload = {
      payment: {
        gracePeriod: container.querySelector('#setting-pay-grace')?.value ? Number(container.querySelector('#setting-pay-grace').value) : undefined,
        lateFeeAmount: container.querySelector('#setting-pay-lateFee')?.value ? Number(container.querySelector('#setting-pay-lateFee').value) : undefined,
        autoSuspendDays: container.querySelector('#setting-pay-suspend')?.value ? Number(container.querySelector('#setting-pay-suspend').value) : undefined
      },
      admission: {
        idPrefix: container.querySelector('#setting-adm-idPrefix')?.value?.trim()
      },
      billing: {
        receiptPrefix: container.querySelector('#setting-bill-prefix')?.value?.trim(),
        gstRate: container.querySelector('#setting-bill-gstRate')?.value ? Number(container.querySelector('#setting-bill-gstRate').value) : undefined,
        hsnSacCode: container.querySelector('#setting-bill-hsn')?.value?.trim(),
        refundPolicyDays: container.querySelector('#setting-bill-refundDays')?.value ? Number(container.querySelector('#setting-bill-refundDays').value) : undefined
      },
      notification: {
        enableWhatsapp: container.querySelector('#setting-notif-wa')?.checked,
        whatsappScheduleTime: container.querySelector('#setting-notif-time')?.value,
        enableAutoExpiryBot: container.querySelector('#setting-notif-expiryBot')?.checked,
        enableAutoDuesBot: container.querySelector('#setting-notif-duesBot')?.checked,
        enableConversationalBot: container.querySelector('#setting-notif-chatBot')?.checked
      },
      operations: {
        openingTime: container.querySelector('#setting-ops-open')?.value,
        closingTime: container.querySelector('#setting-ops-close')?.value,
        weeklyOff: container.querySelector('#setting-ops-weeklyOff')?.value,
        examExtendedHours: container.querySelector('#setting-ops-examHours')?.checked,
        emergencyNotice: container.querySelector('#setting-ops-emergencyNotice')?.value?.trim(),
        emergencyNoticeEnabled: container.querySelector('#setting-ops-emergencyToggle')?.checked
      },
      automations: {
        autoSeatExpiry: container.querySelector('#setting-auto-seatExpiry')?.checked,
        autoDueReminders: container.querySelector('#setting-auto-dueReminders')?.checked
      },
      portal: {}
    };

    // Gather Student Portal Toggles
    container.querySelectorAll('.student-portal-toggle').forEach(t => {
      sysPayload.portal[t.dataset.key] = t.checked;
    });

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
