import api from '../api.js';
import { Toast, Modal, Confirm, Loading, escapeHTML } from '../ui.js';
import { MediaStudio, MediaFieldPicker } from '../mediaStudio.js';
import { t } from '../i18n.js';
import { generateAdmissionFormPDF, previewAdmissionFormPDF } from '../pdfGenerator.js';
import { FormBuilder } from '../formBuilder.js';

export async function render() {
  const container = document.createElement('div');
  container.className = 'page-container';

  // Initial skeleton / loading state
  container.innerHTML = `
    <!-- Standard Module Header -->
    <div class="module-header">
      <div class="module-title-area">
        <h2>⚙️ System & Business Settings</h2>
        <p>Configure library branding, payment fines, admission rules, and automated alerts.</p>
      </div>
    </div>
    <div class="card" style="padding: 2.5rem; text-align: center;">
      <div class="loading-spinner" style="margin: 0 auto 1rem auto;"></div>
      <p style="color: var(--color-text-secondary); margin: 0;">Loading system configuration...</p>
    </div>
  `;

  try {
    const res = await api.get('/api/settings');
    const data = res?.data || {};
    const businessProfile = data.businessProfile || {};
    const systemSettings = data.systemSettings || {};

    const gen = systemSettings.general || {};
    const pay = systemSettings.payment || {};
    const adm = systemSettings.admission || {};
    const notif = systemSettings.notification || {};

    renderSettingsUI(container, businessProfile, { gen, pay, adm, notif });
  } catch (error) {
    console.error('Failed to load settings:', error);
    container.innerHTML = `
      <div class="page-header mb-4">
        <h2 style="margin: 0; font-size: 1.6rem; font-weight: 700; color: var(--color-text-primary);">System & Business Settings</h2>
      </div>
      <div class="card" style="padding: 2rem; border-color: var(--color-danger); text-align: center;">
        <div style="font-size: 2.5rem; margin-bottom: 0.5rem;">⚠️</div>
        <h3 style="color: var(--color-danger); margin-bottom: 0.5rem;">Failed to load settings</h3>
        <p style="color: var(--color-text-secondary); margin-bottom: 1.5rem;">${escapeHTML(error.message || 'Could not connect to the settings service.')}</p>
        <button id="btn-retry-settings" class="btn btn-primary">Retry</button>
      </div>
    `;
    container.querySelector('#btn-retry-settings')?.addEventListener('click', () => render());
  }

  return container;
}

function renderSettingsUI(container, profile, settings) {
  const { gen, pay, adm, notif } = settings;

  // Selected reminder days
  let selectedReminderDays = Array.isArray(notif['payment.paymentReminder'] || notif.paymentReminder)
    ? (notif['payment.paymentReminder'] || notif.paymentReminder)
    : [7, 3, 1];

  container.innerHTML = `
    <!-- Header -->
    <div class="page-header d-flex justify-content-between align-items-center mb-4 flex-wrap gap-3" style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem; flex-wrap: wrap; gap: 1rem;">
      <div>
        <h2 style="margin: 0; font-size: 1.6rem; font-weight: 700; color: var(--color-text-primary); display: flex; align-items: center; gap: 0.5rem;">
          <svg viewBox="0 0 24 24" width="26" height="26" fill="none" stroke="currentColor" stroke-width="2" style="color: var(--color-primary);"><circle cx="12" cy="12" r="3"></circle><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path></svg>
          System & Business Settings
        </h2>
        <p class="text-muted small mb-0" style="margin-top: 4px; color: var(--color-text-secondary); font-size: 0.9rem;">
          Manage library profile, late fine formulas, auto-admission toggles, reminders, and currency.
        </p>
      </div>
      <div style="display: flex; gap: 0.75rem;">
        <button id="btn-save-all-settings" class="btn btn-primary" style="display: inline-flex; align-items: center; gap: 0.5rem; font-weight: 600;">
          <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"></path><polyline points="17 21 17 13 7 13 7 21"></polyline><polyline points="7 3 7 8 15 8"></polyline></svg>
          Save All Changes
        </button>
      </div>
    </div>

    <!-- Navigation Tabs -->
    <div class="settings-tabs-wrapper" style="border-bottom: 1px solid var(--color-border); margin-bottom: 1.5rem; overflow-x: auto; -webkit-overflow-scrolling: touch;">
      <div class="settings-tab-list" style="display: flex; gap: 0.5rem; min-width: max-content;">
        <button class="settings-tab-btn active" data-tab="branding" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 600; background: none; border: none; border-bottom: 3px solid var(--color-primary); color: var(--color-primary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem; transition: all 0.2s ease;">
          <span>🏢</span> Library Branding & Info
        </button>
        <button class="settings-tab-btn" data-tab="policies" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem; transition: all 0.2s ease;">
          <span>💰</span> Fee & Late Fine Policies
        </button>
        <button class="settings-tab-btn" data-tab="admission" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem; transition: all 0.2s ease;">
          <span>🎓</span> Admission & ID Formatting
        </button>
        <button class="settings-tab-btn" data-tab="notifications" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem; transition: all 0.2s ease;">
          <span>🔔</span> Notification Preferences
        </button>
        <button class="settings-tab-btn" data-tab="general" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem; transition: all 0.2s ease;">
          <span>🌍</span> General System Config
        </button>
        <button class="settings-tab-btn" data-tab="backup" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem; transition: all 0.2s ease;">
          <span>💾</span> Backup & Data Restore
        </button>
        <button class="settings-tab-btn" data-tab="formbuilder" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem; transition: all 0.2s ease;">
          <span>📝</span> Dynamic Form Builder
        </button>
        <button class="settings-tab-btn" data-tab="modules" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem; transition: all 0.2s ease;">
          <span>🧩</span> Module Settings
        </button>
        <button class="settings-tab-btn" data-tab="audittrail" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem; transition: all 0.2s ease;">
          <span>📋</span> Activity Audit Trail
        </button>
        <button class="settings-tab-btn" data-tab="landing" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem; transition: all 0.2s ease;">
          <span>🌐</span> Public Landing Page & SEO
        </button>
        <button class="settings-tab-btn" data-tab="pdfstudio" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem; transition: all 0.2s ease;">
          <span>📄</span> PDF Admission Form Studio
        </button>
        <button class="settings-tab-btn" data-tab="receiptstudio" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem; transition: all 0.2s ease;">
          <span>🧾</span> Smart Receipt Builder Studio
        </button>
      </div>
    </div>

    <!-- TAB PANELS CONTAINER -->
    <div id="settings-tab-content">
      
      <!-- ========================================== -->
      <!-- SECTION A: LIBRARY BRANDING & INFO -->
      <!-- ========================================== -->
      <div class="settings-panel" id="panel-branding" style="display: block;">
        <form id="form-branding">
          <div class="card mb-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden; box-shadow: var(--shadow-sm);">
            <div class="card-header" style="padding: 1.25rem 1.5rem; border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover); display: flex; justify-content: space-between; align-items: center;">
              <div>
                <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600; color: var(--color-text-primary);">🏢 Library Branding & Contact Details</h3>
                <p style="margin: 4px 0 0 0; font-size: 0.85rem; color: var(--color-text-secondary);">This branding appears on student ID cards, invoices, receipts, and portal header.</p>
              </div>
              <button type="submit" id="btn-save-branding" class="btn btn-primary btn-sm" style="font-weight: 600;">Save Branding</button>
            </div>
            
            <div class="card-body" style="padding: 1.5rem;">
              
              <!-- Basic Info -->
              <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 1.25rem; margin-bottom: 1.5rem;">
                <div class="form-group">
                  <label class="form-label" for="setting-businessName" style="font-weight: 600;">Business / Library Name *</label>
                  <input type="text" id="setting-businessName" class="form-control" required value="${escapeHTML(profile.businessName || 'Study Library')}" placeholder="e.g. Gyan Sagar Study Space">
                </div>
                
                <div class="form-group">
                  <label class="form-label" for="setting-tagline" style="font-weight: 600;">Tagline / Slogan</label>
                  <input type="text" id="setting-tagline" class="form-control" value="${escapeHTML(profile.tagline || '')}" placeholder="e.g. Silence, Focus & Success">
                </div>
              </div>

              <!-- Media Previews: Logo & UPI QR -->
              <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 1.5rem; margin-bottom: 1.5rem; padding: 1.25rem; background: var(--color-bg-primary); border-radius: var(--radius-md); border: 1px solid var(--color-border);">
                <!-- Logo -->
                <div>
                  <label class="form-label" style="font-weight: 600;">Library Emblem / Logo</label>
                  <div id="mount-setting-logo"></div>
                </div>

                <!-- UPI QR Code -->
                <div>
                  <label class="form-label" style="font-weight: 600;">UPI Payment QR Code</label>
                  <div id="mount-setting-qr"></div>
                </div>
              </div>

              <!-- Contact & Address -->
              <h4 style="font-size: 0.95rem; font-weight: 600; color: var(--color-text-primary); margin: 1.5rem 0 1rem 0; border-bottom: 1px solid var(--color-divider); padding-bottom: 0.5rem;">
                📍 Contact & Physical Location
              </h4>
              <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 1rem; margin-bottom: 1.25rem;">
                <div class="form-group">
                  <label class="form-label" for="setting-phone" style="font-weight: 500;">Phone / WhatsApp Support</label>
                  <input type="text" id="setting-phone" class="form-control" value="${escapeHTML(profile.phone || '')}" placeholder="+91 98765 43210">
                </div>
                <div class="form-group">
                  <label class="form-label" for="setting-email" style="font-weight: 500;">Official Email Address</label>
                  <input type="email" id="setting-email" class="form-control" value="${escapeHTML(profile.email || '')}" placeholder="support@studylib.com">
                </div>
                <div class="form-group">
                  <label class="form-label" for="setting-website" style="font-weight: 500;">Website URL</label>
                  <input type="url" id="setting-website" class="form-control" value="${escapeHTML(profile.website || '')}" placeholder="https://www.studylibrary.com">
                </div>
              </div>

              <div class="form-group" style="margin-bottom: 1rem;">
                <label class="form-label" for="setting-address" style="font-weight: 500;">Full Street Address</label>
                <input type="text" id="setting-address" class="form-control" value="${escapeHTML(profile.address || '')}" placeholder="Plot 42, Knowledge Park III, Near Metro Station">
              </div>

              <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 1rem; margin-bottom: 1.5rem;">
                <div class="form-group">
                  <label class="form-label" for="setting-city" style="font-weight: 500;">City</label>
                  <input type="text" id="setting-city" class="form-control" value="${escapeHTML(profile.city || '')}" placeholder="e.g. Pune / Delhi">
                </div>
                <div class="form-group">
                  <label class="form-label" for="setting-state" style="font-weight: 500;">State</label>
                  <input type="text" id="setting-state" class="form-control" value="${escapeHTML(profile.state || '')}" placeholder="e.g. Maharashtra">
                </div>
                <div class="form-group">
                  <label class="form-label" for="setting-pincode" style="font-weight: 500;">Pincode</label>
                  <input type="text" id="setting-pincode" class="form-control" value="${escapeHTML(profile.pincode || '')}" placeholder="e.g. 411001">
                </div>
              </div>

              <!-- Legal & Registration -->
              <h4 style="font-size: 0.95rem; font-weight: 600; color: var(--color-text-primary); margin: 1.5rem 0 1rem 0; border-bottom: 1px solid var(--color-divider); padding-bottom: 0.5rem;">
                ⚖️ Legal, Tax & Social
              </h4>
              <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 1rem; margin-bottom: 1rem;">
                <div class="form-group">
                  <label class="form-label" for="setting-gstNumber" style="font-weight: 500;">GSTIN / Tax Number</label>
                  <input type="text" id="setting-gstNumber" class="form-control" value="${escapeHTML(profile.gstNumber || '')}" placeholder="e.g. 27AAAAA0000A1Z5">
                </div>
                <div class="form-group">
                  <label class="form-label" for="setting-registrationNumber" style="font-weight: 500;">Registration / Shop Act No.</label>
                  <input type="text" id="setting-registrationNumber" class="form-control" value="${escapeHTML(profile.registrationNumber || '')}" placeholder="e.g. REG/2026/982">
                </div>
              </div>

              <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem;">
                <div class="form-group">
                  <label class="form-label" for="setting-social-whatsapp" style="font-weight: 500;">WhatsApp Group / Link</label>
                  <input type="text" id="setting-social-whatsapp" class="form-control" value="${escapeHTML(profile.socialLinks?.whatsapp || '')}" placeholder="https://wa.me/...">
                </div>
                <div class="form-group">
                  <label class="form-label" for="setting-social-instagram" style="font-weight: 500;">Instagram Handle</label>
                  <input type="text" id="setting-social-instagram" class="form-control" value="${escapeHTML(profile.socialLinks?.instagram || '')}" placeholder="@studylibrary">
                </div>
                <div class="form-group">
                  <label class="form-label" for="setting-social-facebook" style="font-weight: 500;">Facebook Page</label>
                  <input type="text" id="setting-social-facebook" class="form-control" value="${escapeHTML(profile.socialLinks?.facebook || '')}" placeholder="facebook.com/...">
                </div>
              </div>

            </div>

            <div class="card-footer" style="padding: 1rem 1.5rem; display: flex; justify-content: flex-end; background: var(--color-surface-hover);">
              <button type="submit" id="btn-save-branding-bottom" class="btn btn-primary" style="font-weight: 600;">Save Branding Changes</button>
            </div>
          </div>
        </form>
      </div>

      <!-- ========================================== -->
      <!-- SECTION B: FEE & LATE FINE POLICIES -->
      <!-- ========================================== -->
      <div class="settings-panel" id="panel-policies" style="display: none;">
        <form id="form-policies">
          <div class="card mb-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden; box-shadow: var(--shadow-sm);">
            <div class="card-header" style="padding: 1.25rem 1.5rem; border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover); display: flex; justify-content: space-between; align-items: center;">
              <div>
                <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600; color: var(--color-text-primary);">💰 Fee Due Dates, Late Fines & Auto-Suspension</h3>
                <p style="margin: 4px 0 0 0; font-size: 0.85rem; color: var(--color-text-secondary);">Configure grace periods, calculation models, fine rates, and automatic student deactivations.</p>
              </div>
              <button type="submit" id="btn-save-policies" class="btn btn-primary btn-sm" style="font-weight: 600;">Save Policies</button>
            </div>

            <div class="card-body" style="padding: 1.5rem;">
              
              <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 1.5rem; margin-bottom: 1.5rem;">
                
                <!-- Grace Period -->
                <div class="form-group">
                  <label class="form-label" for="setting-gracePeriod" style="font-weight: 600;">Grace Period (Days)</label>
                  <div style="position: relative;">
                    <input type="number" id="setting-gracePeriod" class="form-control" min="0" max="90" value="${pay['payment.gracePeriod'] ?? pay.gracePeriod ?? 5}" required>
                  </div>
                  <small style="color: var(--color-text-secondary); display: block; margin-top: 4px;">
                    Days after due date before late fees start calculating. Set 0 for immediate fines.
                  </small>
                </div>

                <!-- Late Fee Calculation Type -->
                <div class="form-group">
                  <label class="form-label" style="font-weight: 600;">Late Fee Calculation Mode</label>
                  <div style="display: flex; gap: 0.75rem; margin-top: 6px;">
                    <label style="flex: 1; display: flex; align-items: center; gap: 0.5rem; padding: 0.65rem 1rem; border: 1px solid var(--color-border); border-radius: var(--radius-md); background: var(--color-bg-primary); cursor: pointer;">
                      <input type="radio" name="lateFeeType" value="flat" ${(pay['payment.lateFeeType'] || pay.lateFeeType || 'flat') === 'flat' ? 'checked' : ''} style="cursor: pointer;">
                      <div>
                        <div style="font-weight: 600; font-size: 0.9rem;">Flat Rate</div>
                        <div style="font-size: 0.75rem; color: var(--color-text-secondary);">One-time fixed fine</div>
                      </div>
                    </label>
                    <label style="flex: 1; display: flex; align-items: center; gap: 0.5rem; padding: 0.65rem 1rem; border: 1px solid var(--color-border); border-radius: var(--radius-md); background: var(--color-bg-primary); cursor: pointer;">
                      <input type="radio" name="lateFeeType" value="daily" ${(pay['payment.lateFeeType'] || pay.lateFeeType) === 'daily' || (pay['payment.lateFeeType'] || pay.lateFeeType) === 'per_day' ? 'checked' : ''} style="cursor: pointer;">
                      <div>
                        <div style="font-weight: 600; font-size: 0.9rem;">Per-Day Rate</div>
                        <div style="font-size: 0.75rem; color: var(--color-text-secondary);">Accrues each overdue day</div>
                      </div>
                    </label>
                  </div>
                </div>

              </div>

              <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 1.5rem; margin-bottom: 1.5rem;">
                
                <!-- Late Fee Amount -->
                <div class="form-group">
                  <label class="form-label" for="setting-lateFeeAmount" style="font-weight: 600;">Late Fee Amount (₹)</label>
                  <div style="position: relative;">
                    <input type="number" id="setting-lateFeeAmount" class="form-control" min="0" step="1" value="${pay['payment.lateFeeAmount'] ?? pay.lateFeeAmount ?? 50}" required>
                  </div>
                  <small style="color: var(--color-text-secondary); display: block; margin-top: 4px;">
                    Amount in currency charged either as flat penalty or daily rate.
                  </small>
                </div>

                <!-- Auto-Suspension Threshold -->
                <div class="form-group">
                  <label class="form-label" for="setting-autoSuspendDays" style="font-weight: 600;">Auto-Suspension Threshold (Days Overdue)</label>
                  <div style="position: relative;">
                    <input type="number" id="setting-autoSuspendDays" class="form-control" min="1" max="180" value="${pay['payment.autoSuspendDays'] ?? pay.autoSuspendDays ?? 15}" required>
                  </div>
                  <small style="color: var(--color-text-secondary); display: block; margin-top: 4px;">
                    After these days of overdue payment, the student's seat access is auto-suspended.
                  </small>
                </div>

              </div>

              <!-- Interactive Policy Live Simulation Box -->
              <div id="policy-simulation-card" style="background: var(--color-primary-bg); border: 1px solid var(--color-primary-light); border-radius: var(--radius-md); padding: 1.25rem; margin-top: 1rem;">
                <div style="font-weight: 700; color: var(--color-primary); font-size: 0.95rem; margin-bottom: 0.5rem; display: flex; align-items: center; gap: 0.5rem;">
                  <span>📋</span> Live Policy Rule Summary
                </div>
                <div id="policy-simulation-text" style="color: var(--color-text-primary); font-size: 0.9rem; line-height: 1.6;">
                  <!-- Dynamically computed -->
                </div>
              </div>

            </div>

            <div class="card-footer" style="padding: 1rem 1.5rem; display: flex; justify-content: flex-end; background: var(--color-surface-hover);">
              <button type="submit" id="btn-save-policies-bottom" class="btn btn-primary" style="font-weight: 600;">Save Policy Changes</button>
            </div>
          </div>
        </form>
      </div>

      <!-- ========================================== -->
      <!-- SECTION C: ADMISSION & ID FORMATTING -->
      <!-- ========================================== -->
      <div class="settings-panel" id="panel-admission" style="display: none;">
        <form id="form-admission">
          <div class="card mb-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden; box-shadow: var(--shadow-sm);">
            <div class="card-header" style="padding: 1.25rem 1.5rem; border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover); display: flex; justify-content: space-between; align-items: center;">
              <div>
                <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600; color: var(--color-text-primary);">🎓 Admission Approval & Student ID Generation</h3>
                <p style="margin: 4px 0 0 0; font-size: 0.85rem; color: var(--color-text-secondary);">Set identifier schemas for new students and auto-activation rules.</p>
              </div>
              <button type="submit" id="btn-save-admission" class="btn btn-primary btn-sm" style="font-weight: 600;">Save Admission Rules</button>
            </div>

            <div class="card-body" style="padding: 1.5rem;">
              
              <!-- Auto-Approve Switch Card -->
              <div style="display: flex; align-items: center; justify-content: space-between; padding: 1.25rem; background: var(--color-bg-primary); border: 1px solid var(--color-border); border-radius: var(--radius-md); margin-bottom: 1.5rem; gap: 1rem; flex-wrap: wrap;">
                <div>
                  <div style="font-weight: 600; font-size: 1rem; color: var(--color-text-primary); display: flex; align-items: center; gap: 0.5rem;">
                    <span>⚡</span> Auto-Approve New Student Admissions
                    <span id="badge-auto-approve" class="badge ${(adm['admission.autoApprove'] ?? adm.autoApprove) ? 'badge-success' : 'badge-secondary'}" style="margin-left: 0.5rem; font-size: 0.75rem; padding: 2px 8px; border-radius: 12px; background: ${(adm['admission.autoApprove'] ?? adm.autoApprove) ? 'var(--color-success-bg)' : 'var(--color-bg-secondary)'}; color: ${(adm['admission.autoApprove'] ?? adm.autoApprove) ? 'var(--color-success)' : 'var(--color-text-secondary)'}; border: 1px solid currentColor;">
                      ${(adm['admission.autoApprove'] ?? adm.autoApprove) ? 'Enabled' : 'Manual Review'}
                    </span>
                  </div>
                  <p style="color: var(--color-text-secondary); font-size: 0.85rem; margin: 4px 0 0 0;">
                    When enabled, self-registering students are automatically granted active status without waiting for manual admin approval.
                  </p>
                </div>
                <div>
                  <input type="checkbox" id="setting-autoApprove" class="form-toggle" ${(adm['admission.autoApprove'] ?? adm.autoApprove) ? 'checked' : ''}>
                </div>
              </div>

              <!-- ID Formatting Configuration -->
              <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 1.5rem; margin-bottom: 1.5rem;">
                
                <div class="form-group">
                  <label class="form-label" for="setting-idPrefix" style="font-weight: 600;">Student ID Prefix</label>
                  <input type="text" id="setting-idPrefix" class="form-control" value="${escapeHTML(adm['admission.idPrefix'] || adm.idPrefix || 'STU')}" placeholder="e.g. STU, LIB, RR" maxlength="8" required>
                  <small style="color: var(--color-text-secondary); display: block; margin-top: 4px;">
                    Short alphabetic code placed at start of unique student ID.
                  </small>
                </div>

                <div class="form-group">
                  <label class="form-label" for="setting-idFormat" style="font-weight: 600;">Identifier Pattern</label>
                  <select id="setting-idFormat" class="form-select">
                    <option value="prefix-year-serial" ${(adm['admission.idFormat'] || adm.idFormat || 'prefix-year-serial') === 'prefix-year-serial' ? 'selected' : ''}>Prefix-Year-Serial (e.g. STU-2026-001)</option>
                    <option value="prefix-serial" ${(adm['admission.idFormat'] || adm.idFormat) === 'prefix-serial' ? 'selected' : ''}>Prefix-Serial (e.g. STU-0001)</option>
                    <option value="year-prefix-serial" ${(adm['admission.idFormat'] || adm.idFormat) === 'year-prefix-serial' ? 'selected' : ''}>Year-Prefix-Serial (e.g. 26-STU-001)</option>
                  </select>
                  <small style="color: var(--color-text-secondary); display: block; margin-top: 4px;">
                    Format applied when allocating serial roll numbers.
                  </small>
                </div>

              </div>

              <!-- Live ID Badge Preview -->
              <div style="background: var(--color-surface); border: 2px dashed var(--color-border); border-radius: var(--radius-md); padding: 1.5rem; text-align: center;">
                <div style="font-size: 0.85rem; font-weight: 600; color: var(--color-text-secondary); margin-bottom: 0.5rem; text-transform: uppercase; letter-spacing: 0.05em;">
                  Sample Generated Student Roll Number
                </div>
                <div id="sample-id-preview" style="font-size: 1.6rem; font-weight: 700; font-family: monospace; color: var(--color-primary); display: inline-block; padding: 0.4rem 1.25rem; background: var(--color-primary-bg); border-radius: var(--radius-md); border: 1px solid var(--color-primary-light);">
                  STU-2026-001
                </div>
              </div>

            </div>

            <div class="card-footer" style="padding: 1rem 1.5rem; display: flex; justify-content: flex-end; background: var(--color-surface-hover);">
              <button type="submit" id="btn-save-admission-bottom" class="btn btn-primary" style="font-weight: 600;">Save Admission Rules</button>
            </div>
          </div>
        </form>
      </div>

      <!-- ========================================== -->
      <!-- SECTION D: NOTIFICATION PREFERENCES -->
      <!-- ========================================== -->
      <div class="settings-panel" id="panel-notifications" style="display: none;">
        <form id="form-notifications">
          <div class="card mb-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden; box-shadow: var(--shadow-sm);">
            <div class="card-header" style="padding: 1.25rem 1.5rem; border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover); display: flex; justify-content: space-between; align-items: center;">
              <div>
                <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600; color: var(--color-text-primary);">🔔 Automated Alerts & Communication Channels</h3>
                <p style="margin: 4px 0 0 0; font-size: 0.85rem; color: var(--color-text-secondary);">Manage fee reminder intervals, membership expiry notices, and notification delivery options.</p>
              </div>
              <button type="submit" id="btn-save-notifications" class="btn btn-primary btn-sm" style="font-weight: 600;">Save Alerts</button>
            </div>

            <div class="card-body" style="padding: 1.5rem;">
              
              <!-- Payment Reminder Schedule Pills -->
              <div class="form-group" style="margin-bottom: 2rem;">
                <label class="form-label" style="font-weight: 600;">
                  Payment Reminder Schedule (Days Before Due Date)
                </label>
                <div style="font-size: 0.85rem; color: var(--color-text-secondary); margin-bottom: 0.75rem;">
                  Click to toggle reminder days. Students receive reminder notifications before their monthly fee is due.
                </div>
                
                <div id="reminder-days-container" style="display: flex; gap: 0.5rem; flex-wrap: wrap; align-items: center;">
                  ${[15, 7, 5, 3, 2, 1, 0].map(d => {
                    const isSelected = selectedReminderDays.includes(d);
                    return `
                      <button type="button" class="reminder-day-chip ${isSelected ? 'active' : ''}" data-day="${d}" style="padding: 0.5rem 1rem; border-radius: var(--radius-md); font-weight: 600; font-size: 0.9rem; cursor: pointer; border: 1px solid ${isSelected ? 'var(--color-primary)' : 'var(--color-border)'}; background: ${isSelected ? 'var(--color-primary)' : 'var(--color-bg-primary)'}; color: ${isSelected ? '#fff' : 'var(--color-text-primary)'}; transition: all 0.15s ease;">
                        ${d === 0 ? 'Due Day (0d)' : `${d} Days Before`}
                      </button>
                    `;
                  }).join('')}
                </div>
              </div>

              <!-- Expiry Alert -->
              <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 1.5rem; margin-bottom: 2rem;">
                <div class="form-group">
                  <label class="form-label" for="setting-expiryReminder" style="font-weight: 600;">
                    Plan Expiry Reminder (Days Before)
                  </label>
                  <input type="number" id="setting-expiryReminder" class="form-control" min="1" max="30" value="${notif['notification.expiryReminder'] ?? notif.expiryReminder ?? 7}" required>
                  <small style="color: var(--color-text-secondary); display: block; margin-top: 4px;">
                    Send student an alert to renew their seat booking before their plan finishes.
                  </small>
                </div>
              </div>

              <!-- Delivery Channels Toggles -->
              <h4 style="font-size: 0.95rem; font-weight: 600; color: var(--color-text-primary); margin: 1.5rem 0 1rem 0; border-bottom: 1px solid var(--color-divider); padding-bottom: 0.5rem;">
                📡 Active Dispatch Channels
              </h4>

              <div style="display: flex; flex-direction: column; gap: 1rem;">
                
                <!-- Email -->
                <div style="display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.25rem; background: var(--color-bg-primary); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
                  <div style="display: flex; align-items: center; gap: 0.75rem;">
                    <div style="font-size: 1.5rem;">✉️</div>
                    <div>
                      <div style="font-weight: 600; color: var(--color-text-primary);">Email Notifications</div>
                      <div style="font-size: 0.8rem; color: var(--color-text-secondary);">Send payment receipts and welcome onboard emails to students.</div>
                    </div>
                  </div>
                  <input type="checkbox" id="setting-enableEmail" class="form-toggle" ${(notif['notification.enableEmail'] ?? notif.enableEmail) !== false ? 'checked' : ''}>
                </div>

                <!-- In-App -->
                <div style="display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.25rem; background: var(--color-bg-primary); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
                  <div style="display: flex; align-items: center; gap: 0.75rem;">
                    <div style="font-size: 1.5rem;">📱</div>
                    <div>
                      <div style="font-weight: 600; color: var(--color-text-primary);">In-App Realtime Alerts</div>
                      <div style="font-size: 0.8rem; color: var(--color-text-secondary);">Bell icon notifications on student & manager dashboard.</div>
                    </div>
                  </div>
                  <input type="checkbox" id="setting-enableInApp" class="form-toggle" ${(notif['notification.enableInApp'] ?? notif.enableInApp) !== false ? 'checked' : ''}>
                </div>

                <!-- WhatsApp -->
                <div style="display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.25rem; background: var(--color-bg-primary); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
                  <div style="display: flex; align-items: center; gap: 0.75rem;">
                    <div style="font-size: 1.5rem;">💬</div>
                    <div>
                      <div style="font-weight: 600; color: var(--color-text-primary); display: flex; align-items: center; gap: 0.5rem;">
                        WhatsApp Cloud Integration
                        <span class="badge badge-primary" style="font-size: 0.7rem; padding: 2px 6px; border-radius: 4px;">Meta Cloud API</span>
                      </div>
                      <div style="font-size: 0.8rem; color: var(--color-text-secondary);">Direct WhatsApp messaging for invoices and urgent reminders.</div>
                    </div>
                  </div>
                  <input type="checkbox" id="setting-enableWhatsapp" class="form-toggle" ${(notif['notification.enableWhatsapp'] ?? notif.enableWhatsapp) ? 'checked' : ''}>
                </div>

              </div>

            </div>

            <div class="card-footer" style="padding: 1rem 1.5rem; display: flex; justify-content: flex-end; background: var(--color-surface-hover);">
              <button type="submit" id="btn-save-notifications-bottom" class="btn btn-primary" style="font-weight: 600;">Save Alert Preferences</button>
            </div>
          </div>
        </form>
      </div>

      <!-- ========================================== -->
      <!-- SECTION E: GENERAL SYSTEM CONFIG -->
      <!-- ========================================== -->
      <div class="settings-panel" id="panel-general" style="display: none;">
        <form id="form-general">
          <div class="card mb-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden; box-shadow: var(--shadow-sm);">
            <div class="card-header" style="padding: 1.25rem 1.5rem; border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover); display: flex; justify-content: space-between; align-items: center;">
              <div>
                <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600; color: var(--color-text-primary);">🌍 Regional, Currency & Backup Configuration</h3>
                <p style="margin: 4px 0 0 0; font-size: 0.85rem; color: var(--color-text-secondary);">System locale, timezone calculations, database backups, and inactivity timers.</p>
              </div>
              <button type="submit" id="btn-save-general" class="btn btn-primary btn-sm" style="font-weight: 600;">Save Configuration</button>
            </div>

            <div class="card-body" style="padding: 1.5rem;">
              
              <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 1.5rem; margin-bottom: 1.5rem;">
                
                <!-- Currency Symbol -->
                <div class="form-group">
                  <label class="form-label" for="setting-currencySymbol" style="font-weight: 600;">Currency Symbol</label>
                  <input type="text" id="setting-currencySymbol" class="form-control" value="${escapeHTML(gen['general.currencySymbol'] || gen.currencySymbol || '₹')}" required>
                  <small style="color: var(--color-text-secondary); display: block; margin-top: 4px;">e.g. ₹, $, €, £</small>
                </div>

                <!-- Currency Code -->
                <div class="form-group">
                  <label class="form-label" for="setting-currency" style="font-weight: 600;">Currency ISO Code</label>
                  <select id="setting-currency" class="form-select">
                    <option value="INR" ${(gen['general.currency'] || gen.currency || 'INR') === 'INR' ? 'selected' : ''}>INR — Indian Rupee</option>
                    <option value="USD" ${(gen['general.currency'] || gen.currency) === 'USD' ? 'selected' : ''}>USD — US Dollar</option>
                    <option value="EUR" ${(gen['general.currency'] || gen.currency) === 'EUR' ? 'selected' : ''}>EUR — Euro</option>
                    <option value="GBP" ${(gen['general.currency'] || gen.currency) === 'GBP' ? 'selected' : ''}>GBP — British Pound</option>
                    <option value="AED" ${(gen['general.currency'] || gen.currency) === 'AED' ? 'selected' : ''}>AED — UAE Dirham</option>
                  </select>
                </div>

                <!-- Date Format -->
                <div class="form-group">
                  <label class="form-label" for="setting-dateFormat" style="font-weight: 600;">Date Display Format</label>
                  <select id="setting-dateFormat" class="form-select">
                    <option value="DD/MM/YYYY" ${(gen['general.dateFormat'] || gen.dateFormat || 'DD/MM/YYYY') === 'DD/MM/YYYY' ? 'selected' : ''}>DD/MM/YYYY (e.g. 14/08/2026)</option>
                    <option value="YYYY-MM-DD" ${(gen['general.dateFormat'] || gen.dateFormat) === 'YYYY-MM-DD' ? 'selected' : ''}>YYYY-MM-DD (e.g. 2026-08-14)</option>
                    <option value="MM/DD/YYYY" ${(gen['general.dateFormat'] || gen.dateFormat) === 'MM/DD/YYYY' ? 'selected' : ''}>MM/DD/YYYY (e.g. 08/14/2026)</option>
                  </select>
                </div>

              </div>

              <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 1.5rem; margin-bottom: 1.5rem;">
                
                <!-- Timezone -->
                <div class="form-group">
                  <label class="form-label" for="setting-timezone" style="font-weight: 600;">Timezone</label>
                  <select id="setting-timezone" class="form-select">
                    <option value="Asia/Kolkata" ${(gen['general.timezone'] || gen.timezone || 'Asia/Kolkata') === 'Asia/Kolkata' ? 'selected' : ''}>Asia/Kolkata (IST +5:30)</option>
                    <option value="UTC" ${(gen['general.timezone'] || gen.timezone) === 'UTC' ? 'selected' : ''}>UTC (Coordinated Universal Time)</option>
                    <option value="America/New_York" ${(gen['general.timezone'] || gen.timezone) === 'America/New_York' ? 'selected' : ''}>America/New_York (EST -5:00)</option>
                    <option value="Europe/London" ${(gen['general.timezone'] || gen.timezone) === 'Europe/London' ? 'selected' : ''}>Europe/London (GMT/BST)</option>
                    <option value="Asia/Dubai" ${(gen['general.timezone'] || gen.timezone) === 'Asia/Dubai' ? 'selected' : ''}>Asia/Dubai (GST +4:00)</option>
                    <option value="Asia/Singapore" ${(gen['general.timezone'] || gen.timezone) === 'Asia/Singapore' ? 'selected' : ''}>Asia/Singapore (SGT +8:00)</option>
                  </select>
                </div>

                <!-- Inactivity Timeout -->
                <div class="form-group">
                  <label class="form-label" for="setting-inactivityTimeout" style="font-weight: 600;">Session Inactivity Timeout (Minutes)</label>
                  <input type="number" id="setting-inactivityTimeout" class="form-control" min="5" max="480" value="${gen['general.inactivityTimeout'] ?? gen.inactivityTimeout ?? 30}">
                  <small style="color: var(--color-text-secondary); display: block; margin-top: 4px;">Auto-lock workstation after idle time.</small>
                </div>

              </div>

              <!-- Automated Backups Toggle -->
              <div style="display: flex; align-items: center; justify-content: space-between; padding: 1.25rem; background: var(--color-bg-primary); border: 1px solid var(--color-border); border-radius: var(--radius-md); gap: 1rem; flex-wrap: wrap;">
                <div>
                  <div style="font-weight: 600; font-size: 1rem; color: var(--color-text-primary); display: flex; align-items: center; gap: 0.5rem;">
                    <span>💾</span> Automated Daily Database Backups
                  </div>
                  <p style="color: var(--color-text-secondary); font-size: 0.85rem; margin: 4px 0 0 0;">
                    Generates automated night snapshots of student registrations, seat assignments, and payment logs.
                  </p>
                </div>
                <div>
                  <input type="checkbox" id="setting-autoBackup" class="form-toggle" ${(gen['general.autoBackup'] ?? gen.autoBackup) !== false ? 'checked' : ''}>
                </div>
              </div>

            </div>

            <div class="card-footer" style="padding: 1rem 1.5rem; display: flex; justify-content: flex-end; background: var(--color-surface-hover);">
              <button type="submit" id="btn-save-general-bottom" class="btn btn-primary" style="font-weight: 600;">Save General Settings</button>
            </div>
          </div>
        </form>
      </div>

      <!-- ========================================== -->
      <!-- SECTION F: BACKUP & DATA RESTORE -->
      <!-- ========================================== -->
      <div class="settings-panel" id="panel-backup" style="display: none;">
        <div class="card mb-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden; box-shadow: var(--shadow-sm);">
          <div class="card-header" style="padding: 1.25rem 1.5rem; border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover);">
            <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600; color: var(--color-text-primary);">💾 1-Click Database Backup & Disaster Recovery</h3>
            <p style="margin: 4px 0 0 0; font-size: 0.85rem; color: var(--color-text-secondary);">Download an offline copy of your entire library database or restore from a previous JSON backup.</p>
          </div>

          <div class="card-body" style="padding: 1.5rem;">
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 1.5rem;">
              
              <!-- Download Backup Card -->
              <div style="padding: 1.5rem; border: 1px solid var(--color-border); border-radius: var(--radius-md); background: var(--color-bg-primary); display: flex; flex-direction: column; justify-content: space-between;">
                <div>
                  <div style="font-size: 2rem; margin-bottom: 0.5rem;">📥</div>
                  <h4 style="margin: 0 0 0.5rem 0; font-size: 1.1rem; font-weight: 600; color: var(--color-text-primary);">Download Full System Backup</h4>
                  <p style="font-size: 0.85rem; color: var(--color-text-secondary); line-height: 1.5; margin-bottom: 1.25rem;">
                    Generates a timestamped JSON snapshot containing all students, seat assignments, plans, payment receipts, attendance logs, shifts, branches, and system settings.
                  </p>
                </div>
                <button id="btn-download-db-backup" class="btn btn-primary" style="font-weight: 600; width: 100%;">
                  ⬇️ Download JSON Backup
                </button>
              </div>

              <!-- Restore Backup Card -->
              <div style="padding: 1.5rem; border: 1px solid var(--color-border); border-radius: var(--radius-md); background: var(--color-bg-primary); display: flex; flex-direction: column; justify-content: space-between;">
                <div>
                  <div style="font-size: 2rem; margin-bottom: 0.5rem;">📤</div>
                  <h4 style="margin: 0 0 0.5rem 0; font-size: 1.1rem; font-weight: 600; color: var(--color-text-primary);">Restore Database from JSON</h4>
                  <p style="font-size: 0.85rem; color: var(--color-text-secondary); line-height: 1.5; margin-bottom: 1.25rem;">
                    Select a valid <code style="background: rgba(255,255,255,0.08); padding: 2px 4px; border-radius: 4px;">.json</code> backup file to import and merge records back into MongoDB.
                  </p>
                  <input type="file" id="db-restore-file-input" accept=".json" style="display: none;">
                </div>
                <button id="btn-trigger-restore-file" class="btn btn-outline-danger" style="font-weight: 600; width: 100%;">
                  ⚠️ Select JSON Backup to Restore
                </button>
              </div>

            </div>
          </div>
        </div>
      </div>

      <!-- ========================================== -->
      <!-- SECTION G: REGISTRATION FORM BUILDER -->
      <!-- ========================================== -->
      <div class="settings-panel" id="panel-formbuilder" style="display: none;">
        <div id="form-builder-mount-container"></div>
      </div>

      <!-- ========================================== -->
      <!-- SECTION H: MODULE SETTINGS                 -->
      <!-- ========================================== -->
      <div class="settings-panel" id="panel-modules" style="display: none;">
        <div class="card mb-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden; box-shadow: var(--shadow-sm);">
          <div class="card-header" style="padding: 1.25rem 1.5rem; border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 0.75rem;">
            <div>
              <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600; color: var(--color-text-primary);">🧩 Module Configuration</h3>
              <p style="margin: 4px 0 0 0; font-size: 0.85rem; color: var(--color-text-secondary);">Enable, disable, rename, and reorder sidebar modules.</p>
            </div>
            <div style="display: flex; gap: 0.5rem;">
              <button id="btn-reset-modules" class="btn btn-outline-danger btn-sm" style="font-weight: 600;">Reset Defaults</button>
              <button id="btn-save-modules" class="btn btn-primary btn-sm" style="font-weight: 600;">Save Modules</button>
            </div>
          </div>
          <div class="card-body" style="padding: 1.5rem;">
            <div id="module-settings-list" style="display: flex; flex-direction: column; gap: 0.75rem;">
              <div class="text-center p-4 text-muted">Loading module configuration...</div>
            </div>

            <!-- Student 360 Self-Service Portal Feature Switches -->
            <div style="margin-top: 2rem; border-top: 1px solid var(--color-border); padding-top: 1.5rem;">
              <h4 style="margin: 0 0 4px 0; font-size: 1.05rem; font-weight: 700; color: var(--color-text-primary);">🎓 Student 360° Portal Feature Controls</h4>
              <p style="margin: 0 0 1rem 0; font-size: 0.82rem; color: var(--color-text-secondary);">Toggle which self-service actions are available to enrolled students in their portal.</p>
              
              <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 1rem;">
                <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 1rem; border-radius: var(--radius-md); display: flex; justify-content: space-between; align-items: center;">
                  <div>
                    <div style="font-weight: 600; font-size: 0.9rem;">🪑 Seat Transfer Requests</div>
                    <div class="text-muted small">Allow student seat change requests</div>
                  </div>
                  <input type="checkbox" id="sp-toggle-seat-transfer" checked class="form-toggle">
                </div>

                <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 1rem; border-radius: var(--radius-md); display: flex; justify-content: space-between; align-items: center;">
                  <div>
                    <div style="font-weight: 600; font-size: 0.9rem;">🏖️ Leave Applications</div>
                    <div class="text-muted small">Allow online study leave submission</div>
                  </div>
                  <input type="checkbox" id="sp-toggle-leave-app" checked class="form-toggle">
                </div>

                <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 1rem; border-radius: var(--radius-md); display: flex; justify-content: space-between; align-items: center;">
                  <div>
                    <div style="font-weight: 600; font-size: 0.9rem;">💳 Online UPI Renewals</div>
                    <div class="text-muted small">Allow online plan renewals via QR</div>
                  </div>
                  <input type="checkbox" id="sp-toggle-upi-renewal" checked class="form-toggle">
                </div>

                <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 1rem; border-radius: var(--radius-md); display: flex; justify-content: space-between; align-items: center;">
                  <div>
                    <div style="font-weight: 600; font-size: 0.9rem;">🪪 Digital ID Card Studio</div>
                    <div class="text-muted small">Allow view & download ID card</div>
                  </div>
                  <input type="checkbox" id="sp-toggle-id-card" checked class="form-toggle">
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- ========================================== -->
      <!-- SECTION I: ACTIVITY AUDIT TRAIL            -->
      <!-- ========================================== -->
      <div class="settings-panel" id="panel-audittrail" style="display: none;">
        <div class="card mb-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden; box-shadow: var(--shadow-sm);">
          <div class="card-header" style="padding: 1.25rem 1.5rem; border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover);">
            <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600; color: var(--color-text-primary);">📋 Activity Audit Trail</h3>
            <p style="margin: 4px 0 0 0; font-size: 0.85rem; color: var(--color-text-secondary);">Review all administrative actions taken in the system.</p>
          </div>
          <div class="card-body" style="padding: 1.5rem;">
            <div style="display: flex; gap: 0.5rem; margin-bottom: 1rem; flex-wrap: wrap;">
              <select id="audit-filter-module" class="form-select" style="max-width: 150px;"><option value="">All Modules</option><option value="settings">Settings</option><option value="students">Students</option></select>
              <input type="text" id="audit-filter-action" class="form-control" placeholder="Action..." style="max-width: 150px;">
              <input type="date" id="audit-filter-start" class="form-control" style="max-width: 150px;">
              <input type="date" id="audit-filter-end" class="form-control" style="max-width: 150px;">
              <button id="btn-filter-audit" class="btn btn-primary">Filter</button>
            </div>
            <table class="table" style="width: 100%; border-collapse: collapse;">
              <thead><tr style="border-bottom: 2px solid var(--color-border);"><th style="padding: 0.5rem;">Date</th><th>User</th><th>Action</th><th>Module</th><th>Details</th><th>IP</th></tr></thead>
              <tbody id="audit-log-tbody"></tbody>
            </table>
            <div id="audit-pagination" style="margin-top: 1rem; text-align: center;"></div>
          </div>
        </div>
      </div>

      <!-- ========================================== -->
      <!-- SECTION J: PUBLIC LANDING PAGE & SEO       -->
      <!-- ========================================== -->
      <div class="settings-panel" id="panel-landing" style="display: none;">
        <div class="card mb-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden; box-shadow: var(--shadow-sm);">
          <div class="card-header" style="padding: 1.25rem 1.5rem; border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 0.75rem;">
            <div>
              <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600; color: var(--color-text-primary);">🌐 Public Landing Page & SEO</h3>
              <p style="margin: 4px 0 0 0; font-size: 0.85rem; color: var(--color-text-secondary);">Manage your public-facing website, hero banners, facilities, testimonials, and maps.</p>
            </div>
            <div style="display: flex; gap: 0.5rem;">
              <a href="/landing" target="_blank" class="btn btn-outline btn-sm" style="font-weight: 600; display: inline-flex; align-items: center; gap: 0.4rem; text-decoration: none;">
                <span>👁️</span> View Public Landing Page
              </a>
              <button id="btn-save-landing" class="btn btn-primary btn-sm" style="font-weight: 600;">💾 Save Landing Page</button>
            </div>
          </div>
          <div class="card-body" style="padding: 1.5rem;">
            <div id="landing-settings-container">
              <div class="text-center p-4 text-muted">Loading landing page configuration...</div>
            </div>
          </div>
      <!-- ========================================== -->
      <!-- SECTION K: PDF ADMISSION FORM STUDIO       -->
      <!-- ========================================== -->
      <div class="settings-panel" id="panel-pdfstudio" style="display: none;">
        <div class="card mb-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden; box-shadow: var(--shadow-sm);">
          <div class="card-header" style="padding: 1.25rem 1.5rem; border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 0.75rem;">
            <div>
              <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600; color: var(--color-text-primary);">📄 PDF Admission Form Studio & Field Controls</h3>
              <p style="margin: 4px 0 0 0; font-size: 0.85rem; color: var(--color-text-secondary);">Customize printable preset templates and choose what details appear on student & admin PDF downloads.</p>
            </div>
            <button id="btn-preview-pdf" class="btn btn-outline-primary btn-sm" style="font-weight: 600;">👁️ Test Sample PDF Form</button>
          </div>
          <div class="card-body" style="padding: 1.5rem;">
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 1.25rem; margin-bottom: 1.5rem;">
              
              <div class="form-group">
                <label class="form-label" style="font-weight: 600;">Active Printable PDF Preset Template</label>
                <select id="setting-pdf-template" class="form-select" style="font-weight: 600;">
                  <option value="modern_glass">💎 Modern Glassmorphic Slate (Recommended)</option>
                  <option value="classic_formal">🏛️ Classic Formal Indian Govt / University Style</option>
                  <option value="compact_card">🪪 Compact 1-Page Gate Pass Slip</option>
                </select>
              </div>

              <div class="form-group">
                <label class="form-label" style="font-weight: 600;">Official Stamp Watermark Text</label>
                <input type="text" id="setting-pdf-stamp" class="form-control" value="PAID • ACTIVE STUDENT" placeholder="Watermark text">
              </div>
            </div>

            <h4 style="margin: 0 0 0.75rem 0; font-size: 1rem; font-weight: 700;">👁️ PDF Field Visibility Controls (Choose What Students & Admins Can View)</h4>
            
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 1rem;">
              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 1rem; border-radius: var(--radius-md); display: flex; justify-content: space-between; align-items: center;">
                <div>
                  <div style="font-weight: 600; font-size: 0.9rem;">📷 Passport Selfie Photo</div>
                  <div class="text-muted small">Show student webcam photo</div>
                </div>
                <input type="checkbox" id="pdf-toggle-photo" checked class="form-toggle">
              </div>

              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 1rem; border-radius: var(--radius-md); display: flex; justify-content: space-between; align-items: center;">
                <div>
                  <div style="font-weight: 600; font-size: 0.9rem;">✍️ Digital Signature</div>
                  <div class="text-muted small">Show student digital signature</div>
                </div>
                <input type="checkbox" id="pdf-toggle-sig" checked class="form-toggle">
              </div>

              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 1rem; border-radius: var(--radius-md); display: flex; justify-content: space-between; align-items: center;">
                <div>
                  <div style="font-weight: 600; font-size: 0.9rem;">🏁 Gate Entry Barcode / QR</div>
                  <div class="text-muted small">Show barcode for kiosk scanner</div>
                </div>
                <input type="checkbox" id="pdf-toggle-qr" checked class="form-toggle">
              </div>

              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 1rem; border-radius: var(--radius-md); display: flex; justify-content: space-between; align-items: center;">
                <div>
                  <div style="font-weight: 600; font-size: 0.9rem;">💰 Fee & Payment Breakdown</div>
                  <div class="text-muted small">Show plan price, discount & UTR</div>
                </div>
                <input type="checkbox" id="pdf-toggle-payment" checked class="form-toggle">
              </div>

              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 1rem; border-radius: var(--radius-md); display: flex; justify-content: space-between; align-items: center;">
                <div>
                  <div style="font-weight: 600; font-size: 0.9rem;">📜 Discipline Code & Rules</div>
                  <div class="text-muted small">Show quiet study rules list</div>
                </div>
                <input type="checkbox" id="pdf-toggle-rules" checked class="form-toggle">
              </div>

              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 1rem; border-radius: var(--radius-md); display: flex; justify-content: space-between; align-items: center;">
                <div>
                  <div style="font-weight: 600; font-size: 0.9rem;">🏷️ Official Status Watermark</div>
                  <div class="text-muted small">Show PAID / PENDING stamp</div>
                </div>
                <input type="checkbox" id="pdf-toggle-stamp" checked class="form-toggle">
              </div>
            </div>
          </div>
        </div>
      <!-- ========================================== -->
      <!-- SECTION J: SMART RECEIPT BUILDER STUDIO     -->
      <!-- ========================================== -->
      <div class="settings-panel" id="panel-receiptstudio" style="display: none;">
        <div class="card mb-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden; box-shadow: var(--shadow-sm);">
          <div class="card-header" style="padding: 1.25rem 1.5rem; border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 0.75rem;">
            <div>
              <h3 style="margin: 0; font-size: 1.15rem; font-weight: 700; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
                🧾 Smart Payment Receipt Builder Studio & Presets
              </h3>
              <p style="margin: 4px 0 0 0; font-size: 0.85rem; color: var(--color-text-secondary);">
                Full customization over printable receipts, GST tax invoices, official paid stamps, branding, and thermal POS slips.
              </p>
            </div>
            <button id="btn-save-receipt-config" class="btn btn-primary btn-sm" style="font-weight: 700;">
              💾 Save Receipt Studio Config
            </button>
          </div>

          <div class="card-body" style="padding: 1.5rem;">
            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 24px; align-items: start;">
              
              <!-- Left Pane: Controls -->
              <div style="display: flex; flex-direction: column; gap: 16px;">
                
                <!-- Presets -->
                <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 14px; border-radius: var(--radius-md);">
                  <label class="form-label text-xs" style="font-weight: 700;">Active Receipt Preset Template *</label>
                  <select id="rs-activeTemplate" class="form-select form-control-sm" style="font-weight: 600;">
                    <option value="standard_a4">📄 Standard A4 / A5 Official Fee Receipt</option>
                    <option value="thermal_80">🧾 80mm Thermal POS Receipt (Standard Counter Printer)</option>
                    <option value="thermal_58">🧾 58mm Thermal Mini Slip (Compact Mobile Bluetooth Printer)</option>
                    <option value="modern_minimal">💎 Modern Glass Slate (Minimalist Invoice)</option>
                    <option value="gst_invoice">🏛️ Official Tax / GST Invoice (Double Border with HSN/GSTIN)</option>
                  </select>
                </div>

                <!-- Header Options -->
                <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 14px; border-radius: var(--radius-md); display: flex; flex-direction: column; gap: 10px;">
                  <div style="font-weight: 700; font-size: 0.88rem; color: var(--color-primary);">🖼️ Header & Logo Branding</div>
                  
                  <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px;">
                    <div>
                      <label class="form-label text-xs" style="font-weight: 600;">Header Subtitle</label>
                      <input type="text" id="rs-header-subtitle" class="form-control form-control-sm" value="Official Fee Receipt">
                    </div>
                    <div>
                      <label class="form-label text-xs" style="font-weight: 600;">Header Accent Color</label>
                      <input type="color" id="rs-header-color" class="form-control form-control-sm" value="#4f46e5" style="height: 34px; padding: 2px;">
                    </div>
                  </div>

                  <div style="display: flex; gap: 12px; flex-wrap: wrap;">
                    <label style="font-size: 0.8rem; font-weight: 600; display: flex; align-items: center; gap: 6px; cursor: pointer;">
                      <input type="checkbox" id="rs-header-showLogo" class="form-toggle" checked> Show Logo
                    </label>
                    <label style="font-size: 0.8rem; font-weight: 600; display: flex; align-items: center; gap: 6px; cursor: pointer;">
                      <input type="checkbox" id="rs-header-showBusinessName" class="form-toggle" checked> Show Business Name
                    </label>
                    <label style="font-size: 0.8rem; font-weight: 600; display: flex; align-items: center; gap: 6px; cursor: pointer;">
                      <input type="checkbox" id="rs-header-showPhone" class="form-toggle" checked> Show Phone
                    </label>
                    <label style="font-size: 0.8rem; font-weight: 600; display: flex; align-items: center; gap: 6px; cursor: pointer;">
                      <input type="checkbox" id="rs-header-showEmail" class="form-toggle" checked> Show Email
                    </label>
                    <label style="font-size: 0.8rem; font-weight: 600; display: flex; align-items: center; gap: 6px; cursor: pointer;">
                      <input type="checkbox" id="rs-header-showGst" class="form-toggle" checked> Show GSTIN
                    </label>
                  </div>
                </div>

                <!-- Body Field Toggles -->
                <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 14px; border-radius: var(--radius-md); display: flex; flex-direction: column; gap: 10px;">
                  <div style="font-weight: 700; font-size: 0.88rem; color: var(--color-primary);">📋 Receipt Fields & Visibility</div>
                  
                  <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px;">
                    <label style="font-size: 0.8rem; font-weight: 600; display: flex; align-items: center; gap: 6px; cursor: pointer;">
                      <input type="checkbox" id="rs-body-showStudentId" class="form-toggle" checked> Show Student ID
                    </label>
                    <label style="font-size: 0.8rem; font-weight: 600; display: flex; align-items: center; gap: 6px; cursor: pointer;">
                      <input type="checkbox" id="rs-body-showStudentPhone" class="form-toggle" checked> Show Student Phone
                    </label>
                    <label style="font-size: 0.8rem; font-weight: 600; display: flex; align-items: center; gap: 6px; cursor: pointer;">
                      <input type="checkbox" id="rs-body-showPlanDetails" class="form-toggle" checked> Show Plan Name
                    </label>
                    <label style="font-size: 0.8rem; font-weight: 600; display: flex; align-items: center; gap: 6px; cursor: pointer;">
                      <input type="checkbox" id="rs-body-showPeriod" class="form-toggle" checked> Show Validity Dates
                    </label>
                    <label style="font-size: 0.8rem; font-weight: 600; display: flex; align-items: center; gap: 6px; cursor: pointer;">
                      <input type="checkbox" id="rs-body-showSeatNumber" class="form-toggle" checked> Show Seat No
                    </label>
                    <label style="font-size: 0.8rem; font-weight: 600; display: flex; align-items: center; gap: 6px; cursor: pointer;">
                      <input type="checkbox" id="rs-body-showShift" class="form-toggle" checked> Show Shift Timing
                    </label>
                    <label style="font-size: 0.8rem; font-weight: 600; display: flex; align-items: center; gap: 6px; cursor: pointer;">
                      <input type="checkbox" id="rs-body-showPaymentMethod" class="form-toggle" checked> Show Payment Mode
                    </label>
                    <label style="font-size: 0.8rem; font-weight: 600; display: flex; align-items: center; gap: 6px; cursor: pointer;">
                      <input type="checkbox" id="rs-body-showTransactionId" class="form-toggle" checked> Show Transaction UTR
                    </label>
                  </div>
                </div>

                <!-- GST Tax Invoicing -->
                <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 14px; border-radius: var(--radius-md); display: flex; flex-direction: column; gap: 10px;">
                  <div style="display: flex; justify-content: space-between; align-items: center;">
                    <div style="font-weight: 700; font-size: 0.88rem; color: var(--color-primary);">🏛️ GST Tax Invoice Options</div>
                    <label style="font-size: 0.8rem; font-weight: 700; cursor: pointer; display: flex; align-items: center; gap: 6px;">
                      <input type="checkbox" id="rs-gst-enabled" class="form-toggle"> Enable GST
                    </label>
                  </div>
                  
                  <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px;">
                    <div>
                      <label class="form-label text-xs" style="font-weight: 600;">GST Rate %</label>
                      <input type="number" id="rs-gst-gstRate" class="form-control form-control-sm" value="18">
                    </div>
                    <div>
                      <label class="form-label text-xs" style="font-weight: 600;">HSN / SAC Code</label>
                      <input type="text" id="rs-gst-hsnCode" class="form-control form-control-sm" value="9992">
                    </div>
                  </div>
                </div>

                <!-- Footer, Stamps & Signatures -->
                <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 14px; border-radius: var(--radius-md); display: flex; flex-direction: column; gap: 10px;">
                  <div style="font-weight: 700; font-size: 0.88rem; color: var(--color-primary);">✍️ Footer, Stamps & Legal Terms</div>
                  
                  <div style="display: flex; gap: 12px; flex-wrap: wrap;">
                    <label style="font-size: 0.8rem; font-weight: 600; display: flex; align-items: center; gap: 6px; cursor: pointer;">
                      <input type="checkbox" id="rs-footer-showStamp" class="form-toggle" checked> Show Official Paid Stamp
                    </label>
                    <label style="font-size: 0.8rem; font-weight: 600; display: flex; align-items: center; gap: 6px; cursor: pointer;">
                      <input type="checkbox" id="rs-footer-showSignature" class="form-toggle" checked> Show Authorized Signatory
                    </label>
                  </div>

                  <div>
                    <label class="form-label text-xs" style="font-weight: 600;">Custom Note / Tagline</label>
                    <input type="text" id="rs-footer-customNote" class="form-control form-control-sm" value="Thank you for choosing our study library!">
                  </div>

                  <div>
                    <label class="form-label text-xs" style="font-weight: 600;">Terms & Conditions</label>
                    <textarea id="rs-footer-termsText" class="form-control form-control-sm" rows="2">1. Fees paid are non-refundable. 2. Seat assignment is strictly non-transferable.</textarea>
                  </div>
                </div>

              </div>

              <!-- Right Pane: Real-Time Live Printable Receipt Preview -->
              <div style="position: sticky; top: 80px;">
                <div style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md); overflow: hidden; box-shadow: var(--shadow-sm);">
                  <div style="padding: 10px 14px; background: var(--color-surface-hover); border-bottom: 1px solid var(--color-border); display: flex; justify-content: space-between; align-items: center;">
                    <span style="font-size: 0.85rem; font-weight: 700; color: var(--color-text-primary);">
                      👁️ Real-Time Receipt Preview
                    </span>
                    <span class="badge badge-success" style="font-size: 0.7rem; font-weight: 700;">LIVE PREVIEW</span>
                  </div>

                  <div id="rs-live-preview-box" style="padding: 20px; background: #ffffff; color: #000000; min-height: 400px; max-height: 600px; overflow-y: auto;">
                    <!-- Rendered live preview -->
                  </div>
                </div>
              </div>

            </div>
          </div>
        </div>
      </div>
    </div>
  `;

  // Setup tab navigation switching
  const tabBtns = container.querySelectorAll('.settings-tab-btn');
  const panels = {
    branding: container.querySelector('#panel-branding'),
    policies: container.querySelector('#panel-policies'),
    admission: container.querySelector('#panel-admission'),
    notifications: container.querySelector('#panel-notifications'),
    general: container.querySelector('#panel-general'),
    backup: container.querySelector('#panel-backup'),
    formbuilder: container.querySelector('#panel-formbuilder'),
    modules: container.querySelector('#panel-modules'),
    audittrail: container.querySelector('#panel-audittrail'),
    landing: container.querySelector('#panel-landing'),
    pdfstudio: container.querySelector('#panel-pdfstudio'),
    receiptstudio: container.querySelector('#panel-receiptstudio')
  };

  container.querySelector('#btn-preview-pdf')?.addEventListener('click', () => {
    const template = container.querySelector('#setting-pdf-template')?.value || 'modern_glass';
    const showPhoto = container.querySelector('#pdf-toggle-photo')?.checked;
    const showSignature = container.querySelector('#pdf-toggle-sig')?.checked;
    const showQrCode = container.querySelector('#pdf-toggle-qr')?.checked;
    const showPaymentDetails = container.querySelector('#pdf-toggle-payment')?.checked;
    const showRules = container.querySelector('#pdf-toggle-rules')?.checked;
    const showWatermarkStamp = container.querySelector('#pdf-toggle-stamp')?.checked;

    previewAdmissionFormPDF({
      studentId: 'STU-2026-DEMO',
      name: 'Rahul Sharma (Sample Student)',
      phone: '9876543210',
      email: 'rahul.sharma@example.com',
      gender: 'Male',
      dateOfBirth: '2001-05-15',
      pincode: '411001',
      city: 'Pune',
      state: 'Maharashtra',
      branch: { name: 'Central Campus Branch' },
      plan: { name: 'Super Achiever 10-Hour Plan', shift: 'Morning Shift (7 AM - 5 PM)' },
      seat: { seatNumber: 'Seat #18', zone: 'Premium Quiet Cabin' },
      status: 'active',
      targetExams: ['UPSC Civil Services', 'MPSC State Services'],
      paymentMethod: 'UPI (GPay / PhonePe)',
      transactionId: '423456789012'
    }, {
      template,
      showPhoto,
      showSignature,
      showQrCode,
      showPaymentDetails,
      showRules,
      showWatermarkStamp,
      business: {
        businessName: profile?.businessName || 'Study Library Management',
        tagline: profile?.tagline || 'Silent Study Environment & Reading Hall',
        address: profile?.address || 'Central Library Building',
        phone: profile?.phone || '+91 9876543210'
      }
    });
  });

  tabBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      const target = btn.dataset.tab;
      tabBtns.forEach(b => {
        const isCurrent = b === btn;
        b.classList.toggle('active', isCurrent);
        b.style.borderBottomColor = isCurrent ? 'var(--color-primary)' : 'transparent';
        b.style.color = isCurrent ? 'var(--color-primary)' : 'var(--color-text-secondary)';
        b.style.fontWeight = isCurrent ? '600' : '500';
      });

      Object.entries(panels).forEach(([key, panel]) => {
        if (panel) panel.style.display = key === target ? 'block' : 'none';
      });

      if (target === 'audittrail') {
        loadAuditLogs();
      } else if (target === 'formbuilder') {
        FormBuilder.render(container.querySelector('#form-builder-mount-container'));
      } else if (target === 'receiptstudio') {
        loadReceiptStudio();
      }
    });
  });

  // Audit Logs Logic
  let currentAuditPage = 1;
  const loadAuditLogs = async () => {
    try {
      const mod = container.querySelector('#audit-filter-module').value;
      const act = container.querySelector('#audit-filter-action').value;
      const start = container.querySelector('#audit-filter-start').value;
      const end = container.querySelector('#audit-filter-end').value;
      
      const res = await api.get('/api/audit-logs', { 
        module: mod, 
        action: act, 
        startDate: start, 
        endDate: end, 
        page: currentAuditPage 
      });
      
      const tbody = container.querySelector('#audit-log-tbody');
      const pag = container.querySelector('#audit-pagination');
      
      if (!res.success || !res.data || res.data.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" class="text-center text-muted">No logs found.</td></tr>';
        pag.innerHTML = '';
        return;
      }
      
      tbody.innerHTML = res.data.map(log => `
        <tr>
          <td>${new Date(log.createdAt).toLocaleString()}</td>
          <td>${escapeHTML(log.userName)} (${escapeHTML(log.userRole)})</td>
          <td><span class="badge badge-secondary">${escapeHTML(log.action)}</span></td>
          <td><span class="badge badge-info">${escapeHTML(log.module)}</span></td>
          <td style="max-width: 250px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;" title="${escapeHTML(log.details)}">${escapeHTML(log.details)}</td>
          <td>${escapeHTML(log.ipAddress || '')}</td>
        </tr>
      `).join('');
      
      // Pagination
      let pagHtml = '';
      if (res.pagination.pages > 1) {
        if (currentAuditPage > 1) pagHtml += `<button class="btn btn-sm btn-outline" data-page="${currentAuditPage - 1}">Prev</button>`;
        pagHtml += `<span style="padding: 0.25rem 0.5rem;">Page ${res.pagination.page} of ${res.pagination.pages}</span>`;
        if (currentAuditPage < res.pagination.pages) pagHtml += `<button class="btn btn-sm btn-outline" data-page="${currentAuditPage + 1}">Next</button>`;
      }
      pag.innerHTML = pagHtml;
      
      pag.querySelectorAll('button').forEach(btn => {
        btn.addEventListener('click', () => {
          currentAuditPage = parseInt(btn.dataset.page);
          loadAuditLogs();
        });
      });
      
    } catch (err) {
      console.error(err);
      container.querySelector('#audit-log-tbody').innerHTML = '<tr><td colspan="6" class="text-center text-danger">Failed to load logs.</td></tr>';
    }
  };

  container.querySelector('#btn-filter-audit')?.addEventListener('click', () => {
    currentAuditPage = 1;
    loadAuditLogs();
  });

  // Backup Download Event
  container.querySelector('#btn-download-db-backup')?.addEventListener('click', async () => {
    const btn = container.querySelector('#btn-download-db-backup');
    Loading.button(btn, true);
    try {
      const token = localStorage.getItem('sl_token');
      const response = await fetch('/api/settings/backup', {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (!response.ok) throw new Error('Backup failed to generate');
      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `studylib_backup_${new Date().toISOString().split('T')[0]}.json`;
      document.body.appendChild(a);
      a.click();
      a.remove();
      window.URL.revokeObjectURL(url);
      Toast.success('Database backup downloaded successfully!');
    } catch (err) {
      Toast.error(err.message || 'Error downloading database backup');
    } finally {
      Loading.button(btn, false);
    }
  });

  // Restore Database Events
  const fileInput = container.querySelector('#db-restore-file-input');
  container.querySelector('#btn-trigger-restore-file')?.addEventListener('click', () => {
    fileInput?.click();
  });

  fileInput?.addEventListener('change', (e) => {
    const file = e.target.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = async (event) => {
      try {
        const parsed = JSON.parse(event.target.result);
        if (!parsed.data) throw new Error('Invalid StudyLib backup format');

        Confirm.show({
          title: '⚠️ Confirm Database Restore',
          message: `Are you sure you want to restore records from backup dated ${parsed.exportedAt || 'earlier'}? Existing records will be updated.`,
          danger: true,
          onConfirm: async () => {
            const btn = container.querySelector('#btn-trigger-restore-file');
            Loading.button(btn, true);
            try {
              const res = await api.post('/api/settings/restore', { data: parsed.data });
              if (res.success) {
                Toast.success('Database restored successfully!');
                setTimeout(() => location.reload(), 1200);
              } else {
                Toast.error(res.message);
              }
            } catch (err) {
              Toast.error(err.message || 'Restore failed');
            } finally {
              Loading.button(btn, false);
            }
          }
        });
      } catch (err) {
        Toast.error('Failed to parse JSON file: ' + err.message);
      }
    };
    reader.readAsText(file);
  });

  // Setup dynamic ID preview
  const prefixInput = container.querySelector('#setting-idPrefix');
  const formatSelect = container.querySelector('#setting-idFormat');
  const sampleIdPreview = container.querySelector('#sample-id-preview');

  function updateIdPreview() {
    const p = (prefixInput?.value?.trim() || 'STU').toUpperCase();
    const fmt = formatSelect?.value || 'prefix-year-serial';
    const year = new Date().getFullYear();
    const shortYear = String(year).slice(-2);

    if (fmt === 'prefix-year-serial') {
      sampleIdPreview.textContent = `${p}-${year}-001`;
    } else if (fmt === 'prefix-serial') {
      sampleIdPreview.textContent = `${p}-0001`;
    } else if (fmt === 'year-prefix-serial') {
      sampleIdPreview.textContent = `${shortYear}-${p}-001`;
    }
  }

  prefixInput?.addEventListener('input', updateIdPreview);
  formatSelect?.addEventListener('change', updateIdPreview);
  updateIdPreview();

  // Setup auto-approve badge text sync
  const autoApproveToggle = container.querySelector('#setting-autoApprove');
  const autoApproveBadge = container.querySelector('#badge-auto-approve');
  autoApproveToggle?.addEventListener('change', () => {
    if (autoApproveToggle.checked) {
      autoApproveBadge.textContent = 'Enabled';
      autoApproveBadge.style.color = 'var(--color-success)';
      autoApproveBadge.style.background = 'var(--color-success-bg)';
    } else {
      autoApproveBadge.textContent = 'Manual Review';
      autoApproveBadge.style.color = 'var(--color-text-secondary)';
      autoApproveBadge.style.background = 'var(--color-bg-secondary)';
    }
  });

  // Setup policy live simulation calculation
  const graceInput = container.querySelector('#setting-gracePeriod');
  const fineInput = container.querySelector('#setting-lateFeeAmount');
  const suspendInput = container.querySelector('#setting-autoSuspendDays');
  const simText = container.querySelector('#policy-simulation-text');

  function updatePolicySim() {
    const grace = parseInt(graceInput?.value, 10) || 0;
    const fine = parseFloat(fineInput?.value) || 0;
    const suspend = parseInt(suspendInput?.value, 10) || 15;
    const mode = container.querySelector('input[name="lateFeeType"]:checked')?.value || 'flat';

    const modeDesc = mode === 'flat' ? `a one-time flat late fee of ₹${fine}` : `a daily late fee of ₹${fine} per day`;
    
    simText.innerHTML = `
      <strong>Example:</strong> For a fee due on 1st of the month:
      <ul style="margin: 6px 0 0 1.25rem; padding: 0;">
        <li><strong>Grace Window (Days 1 to ${grace}):</strong> Student can pay normal fee with ₹0 penalty.</li>
        <li><strong>Overdue Period (After Day ${grace}):</strong> System applies ${modeDesc}.</li>
        <li><strong>Auto-Suspension (Day ${suspend}):</strong> If payment remains unpaid, student account and biometric/seat access are automatically locked.</li>
      </ul>
    `;
  }

  graceInput?.addEventListener('input', updatePolicySim);
  fineInput?.addEventListener('input', updatePolicySim);
  suspendInput?.addEventListener('input', updatePolicySim);
  container.querySelectorAll('input[name="lateFeeType"]').forEach(r => r.addEventListener('change', updatePolicySim));
  updatePolicySim();

  // Mount Smart Media Pickers for Logo and UPI QR Code
  const logoMount = container.querySelector('#mount-setting-logo');
  if (logoMount) {
    logoMount.appendChild(MediaFieldPicker.create({
      label: 'Library Emblem / Insignia (1:1 / Transparent)',
      preset: 'stamp_logo',
      name: 'logo',
      value: profile.logo || ''
    }));
  }

  const qrMount = container.querySelector('#mount-setting-qr');
  if (qrMount) {
    qrMount.appendChild(MediaFieldPicker.create({
      label: 'UPI QR Code / Payment Slip QR',
      preset: 'qr_code',
      name: 'upiQrCode',
      value: profile.upiQrCode || ''
    }));
  }

  // Setup reminder days pill toggles
  const reminderContainer = container.querySelector('#reminder-days-container');
  reminderContainer?.querySelectorAll('.reminder-day-chip').forEach(btn => {
    btn.addEventListener('click', () => {
      const day = parseInt(btn.dataset.day, 10);
      if (selectedReminderDays.includes(day)) {
        selectedReminderDays = selectedReminderDays.filter(d => d !== day);
        btn.classList.remove('active');
        btn.style.background = 'var(--color-bg-primary)';
        btn.style.color = 'var(--color-text-primary)';
        btn.style.borderColor = 'var(--color-border)';
      } else {
        selectedReminderDays.push(day);
        selectedReminderDays.sort((a, b) => b - a);
        btn.classList.add('active');
        btn.style.background = 'var(--color-primary)';
        btn.style.color = '#fff';
        btn.style.borderColor = 'var(--color-primary)';
      }
    });
  });

  // Smart Receipt Studio Logic
  const renderReceiptLivePreview = () => {
    const box = container.querySelector('#rs-live-preview-box');
    if (!box) return;

    const sub = container.querySelector('#rs-header-subtitle')?.value || 'Official Fee Receipt';
    const color = container.querySelector('#rs-header-color')?.value || '#4f46e5';
    const showLogo = container.querySelector('#rs-header-showLogo')?.checked;
    const showBiz = container.querySelector('#rs-header-showBusinessName')?.checked;
    const showPhone = container.querySelector('#rs-header-showPhone')?.checked;
    const showEmail = container.querySelector('#rs-header-showEmail')?.checked;
    const showGst = container.querySelector('#rs-header-showGst')?.checked;

    const showStuId = container.querySelector('#rs-body-showStudentId')?.checked;
    const showPlan = container.querySelector('#rs-body-showPlanDetails')?.checked;
    const showSeat = container.querySelector('#rs-body-showSeatNumber')?.checked;
    const showShift = container.querySelector('#rs-body-showShift')?.checked;
    const showMode = container.querySelector('#rs-body-showPaymentMethod')?.checked;

    const showStamp = container.querySelector('#rs-footer-showStamp')?.checked;
    const showSig = container.querySelector('#rs-footer-showSignature')?.checked;
    const customNote = container.querySelector('#rs-footer-customNote')?.value || '';
    const terms = container.querySelector('#rs-footer-termsText')?.value || '';

    box.innerHTML = `
      <div style="border: 2px solid ${color}; border-radius: 8px; padding: 20px; font-family: sans-serif; position: relative;">
        ${showStamp ? `
          <div style="position: absolute; top: 20px; right: 20px; border: 3px double #059669; color: #059669; font-weight: 800; font-size: 0.82rem; padding: 5px 12px; border-radius: 6px; transform: rotate(-10deg); letter-spacing: 1px;">
            PAID • OFFICIAL RECEIPT
          </div>
        ` : ''}

        <div style="text-align: center; border-bottom: 2px solid ${color}; padding-bottom: 12px; margin-bottom: 16px;">
          ${showLogo && profile.logo ? `<img src="${profile.logo}" style="height: 48px; margin-bottom: 6px;">` : ''}
          ${showBiz ? `<h2 style="margin: 0; color: ${color}; font-weight: 800; font-size: 1.3rem;">${escapeHTML(profile.businessName || 'Study Library Management')}</h2>` : ''}
          <div style="font-weight: 700; color: #555; margin-top: 2px; font-size: 0.9rem;">${escapeHTML(sub)}</div>
          <div style="font-size: 0.8rem; color: #666; margin-top: 4px;">
            ${showPhone ? `📞 ${escapeHTML(profile.phone || '+91 98765 43210')} ` : ''}
            ${showEmail ? `✉️ ${escapeHTML(profile.email || 'info@studylib.com')}` : ''}
            ${showGst ? `<br>GSTIN: 27AAAAA0000A1Z5` : ''}
          </div>
        </div>

        <!-- Receipt Details Grid -->
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px; font-size: 0.83rem; margin-bottom: 16px; background: #f8fafc; padding: 10px 12px; border-radius: 6px; border: 1px solid #e2e8f0;">
          <div><strong>Receipt No:</strong> RCP-2026-0892</div>
          <div><strong>Date:</strong> ${new Date().toLocaleDateString('en-IN')}</div>
          <div><strong>Student Name:</strong> Rahul Sharma</div>
          ${showStuId ? `<div><strong>Student ID:</strong> STU-2026-018</div>` : ''}
          ${showPlan ? `<div><strong>Plan Name:</strong> Super Achiever 10-Hour Plan</div>` : ''}
          ${showSeat ? `<div><strong>Seat No:</strong> Desk #18 (Quiet Zone)</div>` : ''}
          ${showShift ? `<div><strong>Shift:</strong> Morning Shift (7 AM - 5 PM)</div>` : ''}
          ${showMode ? `<div><strong>Payment Mode:</strong> UPI (GPay / PhonePe)</div>` : ''}
        </div>

        <!-- Fee Summary -->
        <table style="width: 100%; border-collapse: collapse; font-size: 0.83rem; margin-bottom: 16px;">
          <thead>
            <tr style="background: ${color}; color: #ffffff;">
              <th style="padding: 8px; text-align: left;">Description</th>
              <th style="padding: 8px; text-align: right;">Amount (₹)</th>
            </tr>
          </thead>
          <tbody>
            <tr style="border-bottom: 1px solid #e2e8f0;">
              <td style="padding: 8px;">Library Membership Fee (1 Month)</td>
              <td style="padding: 8px; text-align: right; font-weight: 700;">₹1,500.00</td>
            </tr>
            <tr style="font-weight: 800; font-size: 0.92rem; background: #f1f5f9;">
              <td style="padding: 8px;">Total Net Amount Paid</td>
              <td style="padding: 8px; text-align: right; color: ${color};">₹1,500.00</td>
            </tr>
          </tbody>
        </table>

        <!-- Footer -->
        <div style="font-size: 0.78rem; color: #64748b; border-top: 1px solid #e2e8f0; padding-top: 10px; display: flex; justify-content: space-between; align-items: flex-end;">
          <div>
            ${customNote ? `<div style="font-weight: 700; color: #334155;">${escapeHTML(customNote)}</div>` : ''}
            ${terms ? `<div style="margin-top: 4px; font-size: 0.72rem; white-space: pre-line;">${escapeHTML(terms)}</div>` : ''}
          </div>
          ${showSig ? `
            <div style="text-align: center; margin-left: 20px; flex-shrink: 0;">
              <div style="border-bottom: 1px solid #94a3b8; width: 120px; margin-bottom: 4px;"></div>
              <div style="font-size: 0.75rem; font-weight: 700;">Authorized Signatory</div>
            </div>
          ` : ''}
        </div>
      </div>
    `;
  };

  const loadReceiptStudio = async () => {
    try {
      const res = await api.get('/api/settings/receipt-config');
      if (res.success && res.data) {
        const config = res.data;
        const setVal = (id, val) => {
          const el = container.querySelector('#' + id);
          if (el) {
            if (el.type === 'checkbox') el.checked = !!val;
            else el.value = val !== undefined ? val : '';
          }
        };

        setVal('rs-activeTemplate', config.activeTemplate || 'standard_a4');
        const h = config.header || {};
        setVal('rs-header-subtitle', h.subtitle || 'Official Fee Receipt');
        setVal('rs-header-color', h.headerColor || '#4f46e5');
        setVal('rs-header-showLogo', h.showLogo !== false);
        setVal('rs-header-showBusinessName', h.showBusinessName !== false);
        setVal('rs-header-showPhone', h.showPhone !== false);
        setVal('rs-header-showEmail', h.showEmail !== false);
        setVal('rs-header-showGst', h.showGst !== false);

        const b = config.body || {};
        setVal('rs-body-showStudentId', b.showStudentId !== false);
        setVal('rs-body-showStudentPhone', b.showStudentPhone !== false);
        setVal('rs-body-showPlanDetails', b.showPlanDetails !== false);
        setVal('rs-body-showPeriod', b.showPeriod !== false);
        setVal('rs-body-showSeatNumber', b.showSeatNumber !== false);
        setVal('rs-body-showShift', b.showShift !== false);
        setVal('rs-body-showPaymentMethod', b.showPaymentMethod !== false);
        setVal('rs-body-showTransactionId', b.showTransactionId !== false);

        const g = config.gst || {};
        setVal('rs-gst-enabled', !!g.enabled);
        setVal('rs-gst-gstRate', g.gstRate || 18);
        setVal('rs-gst-hsnCode', g.hsnCode || '9992');

        const f = config.footer || {};
        setVal('rs-footer-showStamp', f.showStamp !== false);
        setVal('rs-footer-showSignature', f.showSignature !== false);
        setVal('rs-footer-customNote', f.customNote || 'Thank you for choosing our study library!');
        setVal('rs-footer-termsText', f.termsText || '1. Fees paid are non-refundable. 2. Seat assignment is strictly non-transferable.');

        renderReceiptLivePreview();
      }
    } catch (err) {
      console.error('Error loading receipt studio config:', err);
    }
  };

  // Bind Receipt Studio Inputs to Live Preview
  container.querySelectorAll('#panel-receiptstudio input, #panel-receiptstudio select, #panel-receiptstudio textarea').forEach(el => {
    el.addEventListener('input', renderReceiptLivePreview);
    el.addEventListener('change', renderReceiptLivePreview);
  });

  // Save Receipt Studio Config Handler
  container.querySelector('#btn-save-receipt-config')?.addEventListener('click', async () => {
    const btn = container.querySelector('#btn-save-receipt-config');
    Loading.button(btn, true);
    try {
      const payload = {
        activeTemplate: container.querySelector('#rs-activeTemplate')?.value,
        header: {
          subtitle: container.querySelector('#rs-header-subtitle')?.value?.trim(),
          headerColor: container.querySelector('#rs-header-color')?.value,
          showLogo: container.querySelector('#rs-header-showLogo')?.checked,
          showBusinessName: container.querySelector('#rs-header-showBusinessName')?.checked,
          showPhone: container.querySelector('#rs-header-showPhone')?.checked,
          showEmail: container.querySelector('#rs-header-showEmail')?.checked,
          showGst: container.querySelector('#rs-header-showGst')?.checked
        },
        body: {
          showStudentId: container.querySelector('#rs-body-showStudentId')?.checked,
          showStudentPhone: container.querySelector('#rs-body-showStudentPhone')?.checked,
          showPlanDetails: container.querySelector('#rs-body-showPlanDetails')?.checked,
          showPeriod: container.querySelector('#rs-body-showPeriod')?.checked,
          showSeatNumber: container.querySelector('#rs-body-showSeatNumber')?.checked,
          showShift: container.querySelector('#rs-body-showShift')?.checked,
          showPaymentMethod: container.querySelector('#rs-body-showPaymentMethod')?.checked,
          showTransactionId: container.querySelector('#rs-body-showTransactionId')?.checked
        },
        gst: {
          enabled: container.querySelector('#rs-gst-enabled')?.checked,
          gstRate: parseFloat(container.querySelector('#rs-gst-gstRate')?.value) || 18,
          hsnCode: container.querySelector('#rs-gst-hsnCode')?.value?.trim() || '9992'
        },
        footer: {
          showStamp: container.querySelector('#rs-footer-showStamp')?.checked,
          showSignature: container.querySelector('#rs-footer-showSignature')?.checked,
          customNote: container.querySelector('#rs-footer-customNote')?.value?.trim(),
          termsText: container.querySelector('#rs-footer-termsText')?.value?.trim()
        }
      };

      const res = await api.put('/api/settings/receipt-config', payload);
      Toast.success(res?.message || 'Receipt Studio configuration saved successfully!');
    } catch (err) {
      Toast.error(err.message || 'Failed to save receipt configuration');
    } finally {
      Loading.button(btn, false);
    }
  });

  // ==========================================
  // SECTION SAVE HANDLERS
  // ==========================================

  // 1. Save Branding Handler
  async function saveBranding(btn) {
    Loading.button(btn, true);
    try {
      const payload = {
        businessName: container.querySelector('#setting-businessName')?.value?.trim(),
        tagline: container.querySelector('#setting-tagline')?.value?.trim(),
        logo: container.querySelector('input[name="logo"]')?.value?.trim() || container.querySelector('#setting-logo')?.value?.trim() || '',
        upiQrCode: container.querySelector('input[name="upiQrCode"]')?.value?.trim() || container.querySelector('#setting-upiQrCode')?.value?.trim() || '',
        phone: container.querySelector('#setting-phone')?.value?.trim(),
        email: container.querySelector('#setting-email')?.value?.trim(),
        website: container.querySelector('#setting-website')?.value?.trim(),
        address: container.querySelector('#setting-address')?.value?.trim(),
        city: container.querySelector('#setting-city')?.value?.trim(),
        state: container.querySelector('#setting-state')?.value?.trim(),
        pincode: container.querySelector('#setting-pincode')?.value?.trim(),
        gstNumber: container.querySelector('#setting-gstNumber')?.value?.trim(),
        registrationNumber: container.querySelector('#setting-registrationNumber')?.value?.trim(),
        socialLinks: {
          whatsapp: container.querySelector('#setting-social-whatsapp')?.value?.trim(),
          instagram: container.querySelector('#setting-social-instagram')?.value?.trim(),
          facebook: container.querySelector('#setting-social-facebook')?.value?.trim()
        }
      };

      const res = await api.put('/api/settings/business-profile', payload);
      Toast.success(res?.message || 'Library branding and profile updated successfully');
    } catch (err) {
      Toast.error(err.message || 'Failed to update branding');
    } finally {
      Loading.button(btn, false);
    }
  }

  container.querySelector('#form-branding')?.addEventListener('submit', (e) => {
    e.preventDefault();
    saveBranding(container.querySelector('#btn-save-branding'));
  });

  // 2. Save Policies Handler
  async function savePolicies(btn) {
    Loading.button(btn, true);
    try {
      const payload = {
        gracePeriod: parseInt(container.querySelector('#setting-gracePeriod')?.value, 10) || 0,
        lateFeeType: container.querySelector('input[name="lateFeeType"]:checked')?.value || 'flat',
        lateFeeAmount: parseFloat(container.querySelector('#setting-lateFeeAmount')?.value) || 0,
        autoSuspendDays: parseInt(container.querySelector('#setting-autoSuspendDays')?.value, 10) || 15
      };

      const res = await api.put('/api/settings/system-settings', payload);
      Toast.success(res?.message || 'Fee & late fine policies updated successfully');
    } catch (err) {
      Toast.error(err.message || 'Failed to update policies');
    } finally {
      Loading.button(btn, false);
    }
  }

  container.querySelector('#form-policies')?.addEventListener('submit', (e) => {
    e.preventDefault();
    savePolicies(container.querySelector('#btn-save-policies'));
  });

  // 3. Save Admission Handler
  async function saveAdmission(btn) {
    Loading.button(btn, true);
    try {
      const payload = {
        autoApprove: !!container.querySelector('#setting-autoApprove')?.checked,
        idPrefix: container.querySelector('#setting-idPrefix')?.value?.trim() || 'STU',
        idFormat: container.querySelector('#setting-idFormat')?.value || 'prefix-year-serial'
      };

      const res = await api.put('/api/settings/system-settings', payload);
      Toast.success(res?.message || 'Admission & ID rules updated successfully');
    } catch (err) {
      Toast.error(err.message || 'Failed to update admission rules');
    } finally {
      Loading.button(btn, false);
    }
  }

  container.querySelector('#form-admission')?.addEventListener('submit', (e) => {
    e.preventDefault();
    saveAdmission(container.querySelector('#btn-save-admission'));
  });

  // 4. Save Notifications Handler
  async function saveNotifications(btn) {
    Loading.button(btn, true);
    try {
      const payload = {
        paymentReminder: selectedReminderDays,
        expiryReminder: parseInt(container.querySelector('#setting-expiryReminder')?.value, 10) || 7,
        enableEmail: !!container.querySelector('#setting-enableEmail')?.checked,
        enableInApp: !!container.querySelector('#setting-enableInApp')?.checked,
        enableWhatsapp: !!container.querySelector('#setting-enableWhatsapp')?.checked
      };

      const res = await api.put('/api/settings/system-settings', payload);
      Toast.success(res?.message || 'Notification preferences updated successfully');
    } catch (err) {
      Toast.error(err.message || 'Failed to update notifications');
    } finally {
      Loading.button(btn, false);
    }
  }

  container.querySelector('#form-notifications')?.addEventListener('submit', (e) => {
    e.preventDefault();
    saveNotifications(container.querySelector('#btn-save-notifications'));
  });

  // 5. Save General Handler
  async function saveGeneral(btn) {
    Loading.button(btn, true);
    try {
      const payload = {
        currencySymbol: container.querySelector('#setting-currencySymbol')?.value?.trim() || '₹',
        currency: container.querySelector('#setting-currency')?.value || 'INR',
        dateFormat: container.querySelector('#setting-dateFormat')?.value || 'DD/MM/YYYY',
        timezone: container.querySelector('#setting-timezone')?.value || 'Asia/Kolkata',
        inactivityTimeout: parseInt(container.querySelector('#setting-inactivityTimeout')?.value, 10) || 30,
        autoBackup: !!container.querySelector('#setting-autoBackup')?.checked
      };

      const res = await api.put('/api/settings/system-settings', payload);
      Toast.success(res?.message || 'General configuration saved successfully');
    } catch (err) {
      Toast.error(err.message || 'Failed to update general configuration');
    } finally {
      Loading.button(btn, false);
    }
  }

  container.querySelector('#form-general')?.addEventListener('submit', (e) => {
    e.preventDefault();
    saveGeneral(container.querySelector('#btn-save-general'));
  });

  // Save All Changes (Header Button)
  container.querySelector('#btn-save-all-settings')?.addEventListener('click', async () => {
    const saveAllBtn = container.querySelector('#btn-save-all-settings');
    Loading.button(saveAllBtn, true);

    try {
      // 1. Business profile
      const bpPayload = {
        businessName: container.querySelector('#setting-businessName')?.value?.trim(),
        tagline: container.querySelector('#setting-tagline')?.value?.trim(),
        logo: container.querySelector('input[name="logo"]')?.value?.trim() || container.querySelector('#setting-logo')?.value?.trim() || '',
        upiQrCode: container.querySelector('input[name="upiQrCode"]')?.value?.trim() || container.querySelector('#setting-upiQrCode')?.value?.trim() || '',
        phone: container.querySelector('#setting-phone')?.value?.trim(),
        email: container.querySelector('#setting-email')?.value?.trim(),
        website: container.querySelector('#setting-website')?.value?.trim(),
        address: container.querySelector('#setting-address')?.value?.trim(),
        city: container.querySelector('#setting-city')?.value?.trim(),
        state: container.querySelector('#setting-state')?.value?.trim(),
        pincode: container.querySelector('#setting-pincode')?.value?.trim(),
        gstNumber: container.querySelector('#setting-gstNumber')?.value?.trim(),
        registrationNumber: container.querySelector('#setting-registrationNumber')?.value?.trim(),
        socialLinks: {
          whatsapp: container.querySelector('#setting-social-whatsapp')?.value?.trim(),
          instagram: container.querySelector('#setting-social-instagram')?.value?.trim(),
          facebook: container.querySelector('#setting-social-facebook')?.value?.trim()
        }
      };

      // 2. All operational system settings combined
      const sysPayload = {
        gracePeriod: parseInt(container.querySelector('#setting-gracePeriod')?.value, 10) || 0,
        lateFeeType: container.querySelector('input[name="lateFeeType"]:checked')?.value || 'flat',
        lateFeeAmount: parseFloat(container.querySelector('#setting-lateFeeAmount')?.value) || 0,
        autoSuspendDays: parseInt(container.querySelector('#setting-autoSuspendDays')?.value, 10) || 15,
        autoApprove: !!container.querySelector('#setting-autoApprove')?.checked,
        idPrefix: container.querySelector('#setting-idPrefix')?.value?.trim() || 'STU',
        idFormat: container.querySelector('#setting-idFormat')?.value || 'prefix-year-serial',
        paymentReminder: selectedReminderDays,
        expiryReminder: parseInt(container.querySelector('#setting-expiryReminder')?.value, 10) || 7,
        enableEmail: !!container.querySelector('#setting-enableEmail')?.checked,
        enableInApp: !!container.querySelector('#setting-enableInApp')?.checked,
        enableWhatsapp: !!container.querySelector('#setting-enableWhatsapp')?.checked,
        currencySymbol: container.querySelector('#setting-currencySymbol')?.value?.trim() || '₹',
        currency: container.querySelector('#setting-currency')?.value || 'INR',
        dateFormat: container.querySelector('#setting-dateFormat')?.value || 'DD/MM/YYYY',
        timezone: container.querySelector('#setting-timezone')?.value || 'Asia/Kolkata',
        inactivityTimeout: parseInt(container.querySelector('#setting-inactivityTimeout')?.value, 10) || 30,
        autoBackup: !!container.querySelector('#setting-autoBackup')?.checked
      };

      await Promise.all([
        api.put('/api/settings/business-profile', bpPayload),
        api.put('/api/settings/system-settings', sysPayload)
      ]);

      Toast.success('All system & business settings saved successfully!');
    } catch (err) {
      Toast.error(err.message || 'Failed to save all settings');
    } finally {
      Loading.button(saveAllBtn, false);
    }
  });

  // ==========================================
  // Comprehensive Dynamic Form Builder Logic
  // ==========================================
  let customFields = [];

  const INPUT_TYPE_LABELS = {
    text: '🔤 Text Single Line',
    textarea: '📝 Text Multi Line (Textarea)',
    number: '🔢 Number',
    phone: '📞 Phone / WhatsApp (10-Digit)',
    email: '✉️ Email Address',
    date: '📅 Date Picker',
    time: '⏰ Time Picker',
    select: '🔽 Single Select Dropdown',
    multiselect: '☑️ Multi-Select Checkboxes',
    radio: '🔘 Radio Buttons (Single Choice)',
    checkbox: '🔲 Single Checkbox (Yes/No)',
    file: '📎 Document / File Upload',
    photo_upload: '📷 Student Photo Upload',
    signature_pad: '✍️ Digital Signature Pad',
    exam_badge: '🏷️ Exam Multi-Badge Pills',
    blood_group: '🩸 Blood Group Selector',
    url: '🌐 Website / Profile URL',
    color: '🎨 Color Picker'
  };

  async function loadCustomFields() {
    const listContainer = container.querySelector('#custom-fields-list-container');
    if (!listContainer) return;

    try {
      const res = await api.get('/api/custom-fields/all');
      customFields = res.data || [];

      if (customFields.length === 0) {
        listContainer.innerHTML = `
          <div style="padding: 2.5rem; text-align: center; border: 2px dashed var(--color-border); border-radius: var(--radius-md);" class="text-muted">
            <div style="font-size: 2.5rem; margin-bottom: 0.5rem;">📝</div>
            <h4 style="margin: 0; font-weight: 600;">No admission form questions loaded</h4>
            <p style="font-size: 0.85rem; margin-top: 4px;">Click the button below to initialize all standard admission questions.</p>
            <button id="btn-reset-cf-init" class="btn btn-outline btn-sm mt-3">🔄 Reset to Standard Admission Fields</button>
          </div>
        `;
        listContainer.querySelector('#btn-reset-cf-init')?.addEventListener('click', resetDefaultFields);
        return;
      }

      listContainer.innerHTML = `
        <div class="flex-between mb-3">
          <div class="text-sm text-muted">
            Total Admission Questions: <strong>${customFields.length}</strong> (Active: <strong>${customFields.filter(f => f.isActive).length}</strong>)
          </div>
          <div class="d-flex gap-2">
            <button id="btn-reset-cf" class="btn btn-sm btn-outline text-muted" title="Restore all 18 standard admission questions">
              🔄 Reset Standard Questions
            </button>
          </div>
        </div>

        <div class="table-responsive">
          <table class="table data-table mb-0" style="width: 100%; font-size: 0.9rem;">
            <thead>
              <tr>
                <th style="width: 50px;">#</th>
                <th>Field Question / Label</th>
                <th>Input Type Category</th>
                <th>Form Section</th>
                <th>Mandatory?</th>
                <th>Visibility Status</th>
                <th class="text-center" style="width: 120px;">Actions</th>
              </tr>
            </thead>
            <tbody>
              ${customFields.map((f, idx) => `
                <tr style="${!f.isActive ? 'opacity: 0.6; background: var(--color-bg-secondary);' : ''}">
                  <td class="text-muted small">${idx + 1}</td>
                  <td>
                    <div style="font-weight: 600; color: var(--color-text-primary);">${escapeHTML(f.label)}</div>
                    <span class="text-muted small" style="font-size: 0.75rem; font-family: monospace;">code: ${escapeHTML(f.fieldName)}</span>
                  </td>
                  <td>
                    <span class="badge" style="background: rgba(108, 92, 231, 0.12); color: var(--color-primary); font-size: 0.75rem; font-weight: 500;">
                      ${INPUT_TYPE_LABELS[f.type] || escapeHTML(f.type)}
                    </span>
                  </td>
                  <td>
                    <span class="badge" style="background: var(--color-bg-secondary); color: var(--color-text-secondary); text-transform: capitalize; font-size: 0.75rem;">
                      ${escapeHTML(f.sectionLabel || f.section)}
                    </span>
                  </td>
                  <td>
                    ${f.required ? '<span class="badge badge-danger" style="font-size: 0.7rem;">Required</span>' : '<span class="badge badge-ghost" style="font-size: 0.7rem;">Optional</span>'}
                  </td>
                  <td>
                    <button class="btn btn-sm btn-toggle-active" data-id="${f._id}" style="padding: 2px 8px; font-size: 0.75rem; border-radius: 99px; background: ${f.isActive ? 'rgba(0, 184, 148, 0.15)' : 'rgba(214, 48, 49, 0.15)'}; color: ${f.isActive ? 'var(--color-success)' : 'var(--color-danger)'}; border: none; cursor: pointer;">
                      ${f.isActive ? '🟢 Active (Shown)' : '⚪ Inactive (Hidden)'}
                    </button>
                  </td>
                  <td class="text-center">
                    <div class="d-flex justify-content-center gap-1">
                      <button class="btn btn-sm btn-ghost btn-edit-field" data-id="${f._id}" title="Edit Question" style="padding: 4px 8px;">✏️</button>
                      ${f.isDeletable !== false ? `
                        <button class="btn btn-sm btn-ghost text-danger btn-delete-field" data-id="${f._id}" title="Delete Question" style="padding: 4px 8px;">🗑️</button>
                      ` : `
                        <span class="text-muted small" title="Core system field (toggle inactive instead)" style="padding: 4px 8px; opacity: 0.5;">🔒</span>
                      `}
                    </div>
                  </td>
                </tr>
              `).join('')}
            </tbody>
          </table>
        </div>
      `;

      listContainer.querySelector('#btn-reset-cf')?.addEventListener('click', resetDefaultFields);

      // Toggle active/inactive
      listContainer.querySelectorAll('.btn-toggle-active').forEach(btn => {
        btn.addEventListener('click', async () => {
          try {
            const res = await api.put(`/api/custom-fields/${btn.dataset.id}/toggle`, {});
            Toast.success(res?.message || 'Field visibility updated');
            loadCustomFields();
          } catch (err) {
            Toast.error('Failed to update visibility');
          }
        });
      });

      // Edit field
      listContainer.querySelectorAll('.btn-edit-field').forEach(btn => {
        btn.addEventListener('click', () => {
          const field = customFields.find(f => f._id === btn.dataset.id);
          if (field) showFieldModal(field);
        });
      });

      // Delete field
      listContainer.querySelectorAll('.btn-delete-field').forEach(btn => {
        btn.addEventListener('click', async () => {
          const ok = await Confirm.show({
            title: 'Delete Admission Form Question',
            message: 'Are you sure you want to remove this question from the registration form?',
            danger: true
          });
          if (ok) {
            try {
              await api.delete(`/api/custom-fields/${btn.dataset.id}`);
              Toast.success('Field deleted');
              loadCustomFields();
            } catch (err) {
              Toast.error(err.message || 'Failed to delete field');
            }
          }
        });
      });

    } catch (err) {
      listContainer.innerHTML = `<div class="p-3 text-center text-danger">Failed to load custom fields: ${err.message || ''}</div>`;
    }
  }

  async function resetDefaultFields() {
    const ok = await Confirm.show({
      title: 'Reset Standard Admission Questions',
      message: 'This will restore all 18 standard admission questions (Name, Phone, DOB, Gender, Exams, Photo, Signature, KYC, Blood Group, Address, etc.) to default settings. Proceed?',
      danger: false
    });
    if (ok) {
      try {
        const res = await api.post('/api/custom-fields/reset-defaults', {});
        Toast.success(res?.message || 'Standard admission questions restored');
        loadCustomFields();
      } catch (err) {
        Toast.error(err.message || 'Failed to reset questions');
      }
    }
  }

  function showFieldModal(field = null) {
    const isEdit = !!field;
    const modalContent = document.createElement('div');
    modalContent.innerHTML = `
      <form id="custom-field-form" class="p-1">
        <div class="form-group mb-3">
          <label class="form-label" style="font-weight: 600;">Question / Field Label *</label>
          <input type="text" id="cf-label" class="form-control" placeholder="e.g. Father's Occupation, College Name, Target Exam" value="${escapeHTML(field?.label || '')}" required>
        </div>

        <div class="row g-2 mb-3" style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem;">
          <div>
            <label class="form-label" style="font-weight: 600;">Input Type Category *</label>
            <select id="cf-type" class="form-select">
              <option value="text" ${field?.type === 'text' ? 'selected' : ''}>🔤 Text Single Line</option>
              <option value="textarea" ${field?.type === 'textarea' ? 'selected' : ''}>📝 Text Multi Line (Textarea)</option>
              <option value="number" ${field?.type === 'number' ? 'selected' : ''}>🔢 Number</option>
              <option value="phone" ${field?.type === 'phone' ? 'selected' : ''}>📞 Phone / WhatsApp (10-Digit)</option>
              <option value="email" ${field?.type === 'email' ? 'selected' : ''}>✉️ Email Address</option>
              <option value="date" ${field?.type === 'date' ? 'selected' : ''}>📅 Date Picker</option>
              <option value="time" ${field?.type === 'time' ? 'selected' : ''}>⏰ Time Picker</option>
              <option value="select" ${field?.type === 'select' ? 'selected' : ''}>🔽 Single Select Dropdown</option>
              <option value="multiselect" ${field?.type === 'multiselect' ? 'selected' : ''}>☑️ Multi-Select Checkboxes</option>
              <option value="radio" ${field?.type === 'radio' ? 'selected' : ''}>🔘 Radio Buttons (Single Choice)</option>
              <option value="checkbox" ${field?.type === 'checkbox' ? 'selected' : ''}>🔲 Single Checkbox (Yes/No)</option>
              <option value="file" ${field?.type === 'file' ? 'selected' : ''}>📎 Document / File Upload</option>
              <option value="photo_upload" ${field?.type === 'photo_upload' ? 'selected' : ''}>📷 Student Photo Upload</option>
              <option value="signature_pad" ${field?.type === 'signature_pad' ? 'selected' : ''}>✍️ Digital Signature Pad</option>
              <option value="exam_badge" ${field?.type === 'exam_badge' ? 'selected' : ''}>🏷️ Exam Multi-Badge Pills</option>
              <option value="blood_group" ${field?.type === 'blood_group' ? 'selected' : ''}>🩸 Blood Group Selector</option>
              <option value="url" ${field?.type === 'url' ? 'selected' : ''}>🌐 Website / URL Link</option>
              <option value="color" ${field?.type === 'color' ? 'selected' : ''}>🎨 Color Picker</option>
            </select>
          </div>
          <div>
            <label class="form-label" style="font-weight: 600;">Form Section</label>
            <select id="cf-section" class="form-select">
              <option value="personal" ${field?.section === 'personal' ? 'selected' : ''}>👤 Personal Information</option>
              <option value="academic" ${field?.section === 'academic' ? 'selected' : ''}>🎓 Academic & Exam Details</option>
              <option value="contact" ${field?.section === 'contact' ? 'selected' : ''}>📍 Contact & Address</option>
              <option value="kyc" ${field?.section === 'kyc' ? 'selected' : ''}>📑 KYC & Verification</option>
              <option value="other" ${field?.section === 'other' ? 'selected' : ''}>📌 Additional Information</option>
            </select>
          </div>
        </div>

        <div class="form-group mb-3" id="cf-options-group">
          <label class="form-label" style="font-weight: 600;">Dropdown / Checkbox Options (Comma-separated)</label>
          <input type="text" id="cf-options" class="form-control" placeholder="e.g. UPSC, MPSC, Banking, SSC, CA, NEET" value="${escapeHTML(field?.options ? field.options.join(', ') : '')}">
          <small class="text-muted">Used when input type is Dropdown, Radio, Multi-Select, or Exam Badges.</small>
        </div>

        <div class="form-group mb-3">
          <label class="form-label" style="font-weight: 600;">Placeholder / Help Text</label>
          <input type="text" id="cf-placeholder" class="form-control" placeholder="Optional helper text shown inside input box" value="${escapeHTML(field?.placeholder || '')}">
        </div>

        <div class="row g-2 mb-3" style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem;">
          <div>
            <label class="form-label" style="font-weight: 600;">Custom Section Header Label</label>
            <input type="text" id="cf-section-label" class="form-control" placeholder="e.g. Hostel Details" value="${escapeHTML(field?.sectionLabel || '')}">
          </div>
          <div>
            <label class="form-label" style="font-weight: 600;">Display Order #</label>
            <input type="number" id="cf-order" class="form-control" value="${field?.order || 1}" min="1">
          </div>
        </div>

        <div class="form-group mb-3 d-flex gap-4">
          <label style="display: flex; align-items: center; gap: 0.5rem; cursor: pointer;">
            <input type="checkbox" id="cf-required" class="form-checkbox" ${field?.required ? 'checked' : ''}>
            <span style="font-weight: 600;">Mandatory (Required)?</span>
          </label>
          <label style="display: flex; align-items: center; gap: 0.5rem; cursor: pointer;">
            <input type="checkbox" id="cf-active" class="form-checkbox" ${field ? field.isActive : true ? 'checked' : ''}>
            <span style="font-weight: 600;">Active on Registration Form?</span>
          </label>
        </div>

        <div class="d-flex justify-content-end gap-2 mt-4">
          <button type="button" class="btn btn-secondary" id="btn-cancel-cf">Cancel</button>
          <button type="submit" class="btn btn-primary" id="btn-save-cf">${isEdit ? 'Update Question' : 'Add Question'}</button>
        </div>
      </form>
    `;

    const modal = new Modal({
      title: isEdit ? '✏️ Edit Admission Form Question' : '➕ Add Custom Form Question',
      content: modalContent,
      size: 'md'
    });
    modal.show();

    modalContent.querySelector('#btn-cancel-cf').onclick = () => modal.close();

    modalContent.querySelector('#custom-field-form').onsubmit = async (e) => {
      e.preventDefault();
      const label = modalContent.querySelector('#cf-label').value.trim();
      const type = modalContent.querySelector('#cf-type').value;
      const section = modalContent.querySelector('#cf-section').value;
      const sectionLabel = modalContent.querySelector('#cf-section-label').value.trim();
      const options = modalContent.querySelector('#cf-options').value;
      const placeholder = modalContent.querySelector('#cf-placeholder').value.trim();
      const order = parseInt(modalContent.querySelector('#cf-order').value, 10) || 1;
      const required = modalContent.querySelector('#cf-required').checked;
      const isActive = modalContent.querySelector('#cf-active').checked;

      if (!label) {
        Toast.error('Please enter a field label');
        return;
      }

      try {
        const payload = {
          label, type, section, sectionLabel, options, placeholder, order, required, isActive
        };

        if (isEdit) {
          await api.put(`/api/custom-fields/${field._id}`, payload);
          Toast.success('Question updated successfully');
        } else {
          await api.post('/api/custom-fields', payload);
          Toast.success('Form question created successfully');
        }
        modal.close();
        loadCustomFields();
      } catch (err) {
        Toast.error(err.message || 'Failed to save question');
      }
    };
  }

  container.querySelector('#btn-add-custom-field')?.addEventListener('click', () => {
    showFieldModal();
  });

  // Load custom fields initially
  loadCustomFields();

  initModuleSettings(container);
  initLandingSettings(container);
}

async function initModuleSettings(container) {
  const listContainer = container.querySelector('#module-settings-list');
  if (!listContainer) return;

  const renderList = (items) => {
    listContainer.innerHTML = items.map((item, index) => `
      <div class="module-item" data-key="${item.key}" style="display: flex; align-items: center; justify-content: space-between; padding: 1rem; border: 1px solid var(--color-border); border-radius: var(--radius-md); background: var(--color-bg-primary); margin-bottom: 0.5rem; transition: transform 0.2s;">
        <div style="display: flex; align-items: center; gap: 1rem;">
          <div class="drag-handle" style="cursor: grab; font-size: 1.2rem; color: var(--color-text-secondary);">☰</div>
          <div style="font-weight: 600; color: var(--color-text-primary); display: flex; align-items: center; gap: 0.5rem;">
            <span>${item.label}</span>
            ${item.isSystem ? '<span class="badge badge-secondary" style="font-size: 0.7rem;">System</span>' : ''}
          </div>
        </div>
        <div style="display: flex; align-items: center; gap: 1rem;">
          <input type="text" class="form-control form-control-sm module-label-input" value="${escapeHTML(item.label)}" style="width: 150px;" placeholder="Rename...">
          <label style="display: flex; align-items: center; cursor: pointer; gap: 0.5rem; margin: 0;">
            <input type="checkbox" class="form-toggle module-enable-toggle" ${item.isEnabled ? 'checked' : ''} ${item.isSystem ? 'disabled' : ''}>
          </label>
        </div>
      </div>
    `).join('');

    // Setup drag and drop for .module-item inside listContainer
    let draggedItem = null;
    const moduleItems = listContainer.querySelectorAll('.module-item');
    moduleItems.forEach(item => {
      item.draggable = true;
      item.addEventListener('dragstart', (e) => {
        draggedItem = item;
        setTimeout(() => item.style.opacity = '0.5', 0);
      });
      item.addEventListener('dragend', () => {
        draggedItem.style.opacity = '1';
        draggedItem = null;
      });
      item.addEventListener('dragover', (e) => {
        e.preventDefault();
        const afterElement = getDragAfterElement(listContainer, e.clientY);
        if (afterElement == null) {
          listContainer.appendChild(draggedItem);
        } else {
          listContainer.insertBefore(draggedItem, afterElement);
        }
      });
    });
  };

  function getDragAfterElement(container, y) {
    const draggableElements = [...container.querySelectorAll('.module-item:not(.dragging)')];
    return draggableElements.reduce((closest, child) => {
      const box = child.getBoundingClientRect();
      const offset = y - box.top - box.height / 2;
      if (offset < 0 && offset > closest.offset) {
        return { offset: offset, element: child };
      } else {
        return closest;
      }
    }, { offset: Number.NEGATIVE_INFINITY }).element;
  }

  const loadSettings = async () => {
    try {
      const res = await api.get('/api/settings/sidebar/all');
      if (res.success && res.data) {
        renderList(res.data);
      }
    } catch (e) {
      listContainer.innerHTML = '<div class="text-danger">Failed to load module settings</div>';
    }
  };

  container.querySelector('#btn-save-modules')?.addEventListener('click', async () => {
    const items = [];
    listContainer.querySelectorAll('.module-item').forEach((itemEl, index) => {
      items.push({
        key: itemEl.dataset.key,
        label: itemEl.querySelector('.module-label-input').value.trim(),
        isEnabled: itemEl.querySelector('.module-enable-toggle').checked,
        order: index + 1
      });
    });

    const btn = container.querySelector('#btn-save-modules');
    Loading.button(btn, true);
    try {
      const res = await api.put('/api/settings/sidebar', { items });
      if (res.success) {
        Toast.success('Module settings saved. Please refresh the page to see sidebar changes.');
        renderList(res.data);
      } else {
        Toast.error(res.message);
      }
    } catch (err) {
      Toast.error(err.message || 'Failed to save module settings');
    } finally {
      Loading.button(btn, false);
    }
  });

  container.querySelector('#btn-reset-modules')?.addEventListener('click', () => {
    Confirm.show({
      title: 'Reset Modules',
      message: 'Are you sure you want to reset sidebar modules to defaults?',
      danger: true,
      onConfirm: async () => {
        try {
          const res = await api.put('/api/settings/sidebar/reset');
          if (res.success) {
            Toast.success('Modules reset. Please refresh.');
            renderList(res.data);
          }
        } catch (err) {
          Toast.error('Failed to reset modules');
        }
      }
    });
  });

  loadSettings();
}

async function initLandingSettings(container) {
  const listContainer = container.querySelector('#landing-settings-container');
  if (!listContainer) return;
  
  let config = {};
  
  const loadSettings = async () => {
    try {
      const res = await api.get('/api/landing');
      if (res.success && res.data) {
        config = res.data.landing || {};
        renderForm();
      }
    } catch (e) {
      listContainer.innerHTML = '<div class="text-danger">Failed to load landing settings</div>';
    }
  };

  const renderForm = () => {
    listContainer.innerHTML = `
      <!-- Split-Screen Controls Header -->
      <div style="display: flex; justify-content: space-between; align-items: center; background: var(--color-surface); padding: 0.75rem 1rem; border: 1px solid var(--color-border); border-radius: var(--radius-md); margin-bottom: 1rem; flex-wrap: wrap; gap: 0.5rem;">
        <div style="display: flex; align-items: center; gap: 0.5rem;">
          <span style="font-weight: 700; font-size: 0.9rem;">👁️ Live Preview Mode:</span>
          <button id="btn-pv-desktop" class="btn btn-sm btn-primary" style="font-weight: 600;">💻 Desktop</button>
          <button id="btn-pv-mobile" class="btn btn-sm btn-outline" style="font-weight: 600;">📱 Smartphone</button>
          <button id="btn-pv-refresh" class="btn btn-sm btn-outline" title="Refresh Live Canvas">🔄 Refresh</button>
        </div>
        <div style="display: flex; align-items: center; gap: 0.5rem;">
          <small class="text-muted">Instant live preview updates as you type</small>
        </div>
      </div>

      <div class="landing-editor-split" style="display: grid; grid-template-columns: minmax(320px, 1fr) minmax(320px, 1fr); gap: 1.25rem; align-items: start;">
        <!-- Left: CMS Form Editor -->
        <div class="cms-editor-panel" style="border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem; background: var(--color-surface); max-height: 800px; overflow-y: auto;">
          <div class="landing-tabs" style="display: flex; gap: 0.4rem; overflow-x: auto; padding-bottom: 0.5rem; margin-bottom: 1rem; border-bottom: 1px solid var(--color-border);">
            <button class="landing-tab-btn active" data-tab="hero" style="padding: 0.5rem 0.85rem; border: none; background: var(--color-primary-bg); color: var(--color-primary); font-weight: 600; border-radius: var(--radius-md); cursor: pointer; white-space: nowrap;">Hero & Branding</button>
            <button class="landing-tab-btn" data-tab="about" style="padding: 0.5rem 0.85rem; border: none; background: transparent; color: var(--color-text-secondary); cursor: pointer; white-space: nowrap;">About & Stats</button>
            <button class="landing-tab-btn" data-tab="facilities" style="padding: 0.5rem 0.85rem; border: none; background: transparent; color: var(--color-text-secondary); cursor: pointer; white-space: nowrap;">Facilities</button>
            <button class="landing-tab-btn" data-tab="shifts" style="padding: 0.5rem 0.85rem; border: none; background: transparent; color: var(--color-text-secondary); cursor: pointer; white-space: nowrap;">Shifts</button>
            <button class="landing-tab-btn" data-tab="rules" style="padding: 0.5rem 0.85rem; border: none; background: transparent; color: var(--color-text-secondary); cursor: pointer; white-space: nowrap;">Rules</button>
            <button class="landing-tab-btn" data-tab="gallery" style="padding: 0.5rem 0.85rem; border: none; background: transparent; color: var(--color-text-secondary); cursor: pointer; white-space: nowrap;">Gallery</button>
            <button class="landing-tab-btn" data-tab="faqs" style="padding: 0.5rem 0.85rem; border: none; background: transparent; color: var(--color-text-secondary); cursor: pointer; white-space: nowrap;">FAQs</button>
            <button class="landing-tab-btn" data-tab="testimonials" style="padding: 0.5rem 0.85rem; border: none; background: transparent; color: var(--color-text-secondary); cursor: pointer; white-space: nowrap;">Reviews</button>
            <button class="landing-tab-btn" data-tab="contact" style="padding: 0.5rem 0.85rem; border: none; background: transparent; color: var(--color-text-secondary); cursor: pointer; white-space: nowrap;">Contact & Map</button>
          </div>
          
          <!-- Tab Content -->
          <div id="landing-tab-content">
          <!-- Hero -->
          <div class="landing-panel" id="l-panel-hero">
            <h4>Hero Section</h4>
            <div class="form-group mb-3">
              <label>Headline</label>
              <input type="text" id="l-hero-title" class="form-control" value="${escapeHTML(config.hero?.title || '')}">
            </div>
            <div class="form-group mb-3">
              <label>Sub-headline</label>
              <textarea id="l-hero-subtitle" class="form-control">${escapeHTML(config.hero?.subtitle || '')}</textarea>
            </div>
            <div class="form-group mb-3">
              <label>Banner Image URL</label>
              <input type="text" id="l-hero-banner" class="form-control" value="${escapeHTML(config.hero?.bannerImage || '')}">
            </div>
            <div class="form-group mb-3" style="display: flex; gap: 1rem; align-items: center;">
              <input type="checkbox" id="l-hero-enableTicker" ${config.hero?.enableTicker ? 'checked' : ''}>
              <label class="mb-0">Enable Ticker</label>
            </div>
            <div class="form-group mb-3">
              <label>Ticker Text</label>
              <input type="text" id="l-hero-ticker" class="form-control" value="${escapeHTML(config.hero?.tickerText || '')}">
            </div>
            <div class="form-group mb-3" style="display: flex; gap: 1rem; align-items: center;">
              <input type="checkbox" id="l-hero-liveSeatBadge-enabled" ${config.hero?.liveSeatBadge?.enabled ? 'checked' : ''}>
              <label class="mb-0">Enable Live Seat Counter Badge</label>
            </div>
            <div class="form-group mb-3">
              <label>Live Seat Badge Text</label>
              <input type="text" id="l-hero-liveSeatBadge-text" class="form-control" value="${escapeHTML(config.hero?.liveSeatBadge?.text || '')}">
            </div>
            <div class="form-group mb-3">
              <label>Badges (comma separated)</label>
              <input type="text" id="l-hero-badges" class="form-control" value="${escapeHTML((config.hero?.badges || []).join(', '))} ">
            </div>
          </div>
          
          <!-- About -->
          <div class="landing-panel" id="l-panel-about" style="display: none;">
            <h4>About & Stats</h4>
            <div class="form-group mb-3">
              <label>Headline</label>
              <input type="text" id="l-about-title" class="form-control" value="${escapeHTML(config.about?.title || '')}">
            </div>
            <div class="form-group mb-3">
              <label>Description</label>
              <textarea id="l-about-description" class="form-control" rows="4">${escapeHTML(config.about?.description || '')}</textarea>
            </div>
            <div class="form-group mb-3">
              <label>Highlight Points (4 items)</label>
              ${[0, 1, 2, 3].map(i => `<input type="text" class="form-control mb-2 l-about-point" value="${escapeHTML(config.about?.highlightPoints?.[i] || '')}">`).join('')}
            </div>
            <div class="form-group mb-3">
              <label>Stats (4 items: Number / Label)</label>
              ${[0, 1, 2, 3].map(i => `
                <div style="display: flex; gap: 0.5rem; margin-bottom: 0.5rem;">
                  <input type="text" class="form-control l-about-stat-num" placeholder="Number (e.g. 100%)" value="${escapeHTML(config.about?.stats?.[i]?.number || '')}">
                  <input type="text" class="form-control l-about-stat-label" placeholder="Label (e.g. Silence)" value="${escapeHTML(config.about?.stats?.[i]?.label || '')}">
                </div>
              `).join('')}
            </div>
          </div>
          
          <!-- Facilities -->
          <div class="landing-panel" id="l-panel-facilities" style="display: none;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;">
              <h4 style="margin: 0;">Facilities</h4>
              <button class="btn btn-outline-primary btn-sm" id="btn-add-facility">+ Add Facility</button>
            </div>
            <div id="l-facilities-list" style="display: flex; flex-direction: column; gap: 1rem;"></div>
          </div>
          
          <!-- Shifts -->
          <div class="landing-panel" id="l-panel-shifts" style="display: none;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;">
              <h4 style="margin: 0;">Shifts Guide</h4>
              <button class="btn btn-outline-primary btn-sm" id="btn-add-shift">+ Add Shift</button>
            </div>
            <div id="l-shifts-list" style="display: flex; flex-direction: column; gap: 1rem;"></div>
          </div>
          
          <!-- Rules -->
          <div class="landing-panel" id="l-panel-rules" style="display: none;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;">
              <h4 style="margin: 0;">Rules</h4>
              <button class="btn btn-outline-primary btn-sm" id="btn-add-rule">+ Add Rule</button>
            </div>
            <div id="l-rules-list" style="display: flex; flex-direction: column; gap: 0.5rem;"></div>
          </div>
          
          <!-- Gallery -->
          <div class="landing-panel" id="l-panel-gallery" style="display: none;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;">
              <h4 style="margin: 0;">Photo Gallery</h4>
              <button class="btn btn-outline-primary btn-sm" id="btn-add-gallery">+ Add Photo</button>
            </div>
            <div id="l-gallery-list" style="display: flex; flex-direction: column; gap: 1rem;"></div>
          </div>
          
          <!-- FAQs -->
          <div class="landing-panel" id="l-panel-faqs" style="display: none;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;">
              <h4 style="margin: 0;">FAQs</h4>
              <button class="btn btn-outline-primary btn-sm" id="btn-add-faq">+ Add FAQ</button>
            </div>
            <div id="l-faqs-list" style="display: flex; flex-direction: column; gap: 1rem;"></div>
          </div>
          
          <!-- Testimonials -->
          <div class="landing-panel" id="l-panel-testimonials" style="display: none;">
            <div class="form-group mb-3">
              <label>Google Rating</label>
              <input type="text" id="l-test-googleRating" class="form-control" value="${escapeHTML(config.testimonials?.googleRating || '')}">
            </div>
            <div class="form-group mb-3">
              <label>Google Reviews Count</label>
              <input type="text" id="l-test-googleReviewsCount" class="form-control" value="${escapeHTML(config.testimonials?.googleReviewsCount || '')}">
            </div>
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; margin-top: 2rem;">
              <h4 style="margin: 0;">Student Reviews</h4>
              <button class="btn btn-outline-primary btn-sm" id="btn-add-testimonial">+ Add Testimonial</button>
            </div>
            <div id="l-testimonials-list" style="display: flex; flex-direction: column; gap: 1rem;"></div>
          </div>
          
          <!-- Contact -->
          <div class="landing-panel" id="l-panel-contact" style="display: none;">
            <h4>Contact & Map</h4>
            <div class="form-group mb-3">
              <label>Phone</label>
              <input type="text" id="l-contact-phone" class="form-control" value="${escapeHTML(config.contact?.phone || '')}">
            </div>
            <div class="form-group mb-3">
              <label>WhatsApp</label>
              <input type="text" id="l-contact-wa" class="form-control" value="${escapeHTML(config.contact?.whatsapp || '')}">
            </div>
            <div class="form-group mb-3">
              <label>Address</label>
              <input type="text" id="l-contact-address" class="form-control" value="${escapeHTML(config.contact?.address || '')}">
            </div>
            <div class="form-group mb-3">
              <label>Timings</label>
              <input type="text" id="l-contact-hours" class="form-control" value="${escapeHTML(config.contact?.openingHours || '')}">
            </div>
            <div class="form-group mb-3">
              <label>Google Map Embed URL</label>
              <textarea id="l-contact-map" class="form-control" rows="3">${escapeHTML(config.contact?.googleMapEmbedUrl || '')}</textarea>
            </div>
          </div>
          
        </div>
        
        <!-- Right: Live Split-Screen Interactive Preview Canvas -->
        <div class="cms-preview-panel" style="border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1rem; background: var(--color-bg-secondary); position: sticky; top: 80px; height: 800px; display: flex; flex-direction: column;">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.75rem; padding: 0 0.25rem;">
            <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-secondary); text-transform: uppercase; letter-spacing: 0.5px;">
              <span>🌐</span> Live Landing Page Viewport
            </div>
            <a href="/landing" target="_blank" style="font-size: 0.8rem; font-weight: 600; color: var(--color-primary); text-decoration: none;">
              Open Full Page ↗
            </a>
          </div>

          <div id="pv-frame-shell" style="flex: 1; border: 1px solid var(--color-border); border-radius: 12px; overflow: hidden; background: #fff; box-shadow: var(--shadow-md); margin: 0 auto; transition: width 0.3s ease; width: 100%;">
            <iframe id="pv-landing-iframe" src="/landing?preview=true" style="width: 100%; height: 100%; border: none;"></iframe>
          </div>
        </div>
      </div>
    `;

    // Viewport Mode Switching Logic
    const btnPvDesktop = listContainer.querySelector('#btn-pv-desktop');
    const btnPvMobile = listContainer.querySelector('#btn-pv-mobile');
    const btnPvRefresh = listContainer.querySelector('#btn-pv-refresh');
    const pvShell = listContainer.querySelector('#pv-frame-shell');
    const pvIframe = listContainer.querySelector('#pv-landing-iframe');

    btnPvDesktop?.addEventListener('click', () => {
      btnPvDesktop.className = 'btn btn-sm btn-primary';
      btnPvMobile.className = 'btn btn-sm btn-outline';
      if (pvShell) pvShell.style.width = '100%';
    });

    btnPvMobile?.addEventListener('click', () => {
      btnPvMobile.className = 'btn btn-sm btn-primary';
      btnPvDesktop.className = 'btn btn-sm btn-outline';
      if (pvShell) pvShell.style.width = '375px';
    });

    btnPvRefresh?.addEventListener('click', () => {
      if (pvIframe) pvIframe.src = '/landing?preview=' + Date.now();
    });

    // Tab Logic
    const tabBtns = listContainer.querySelectorAll('.landing-tab-btn');
    const panels = listContainer.querySelectorAll('.landing-panel');
    tabBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        tabBtns.forEach(b => {
          b.classList.remove('active');
          b.style.background = 'transparent';
          b.style.color = 'var(--color-text-secondary)';
          b.style.fontWeight = 'normal';
        });
        btn.classList.add('active');
        btn.style.background = 'var(--color-primary-bg)';
        btn.style.color = 'var(--color-primary)';
        btn.style.fontWeight = '600';
        
        panels.forEach(p => p.style.display = 'none');
        listContainer.querySelector(`#l-panel-${btn.dataset.tab}`).style.display = 'block';
      });
    });

    // Helper functions to render lists with reordering controls
    const renderFacilities = () => {
      const parent = listContainer.querySelector('#l-facilities-list');
      if (!parent) return;
      parent.innerHTML = '';
      const items = config.facilities?.items || [];
      items.forEach((item, idx) => {
        const div = document.createElement('div');
        div.style.cssText = 'border: 1px solid var(--color-border); padding: 1rem; border-radius: var(--radius-md); position: relative; background: var(--color-surface);';
        div.innerHTML = `
          <div style="position: absolute; top: 0.75rem; right: 0.75rem; display: flex; gap: 4px;">
            <button class="btn btn-sm btn-outline btn-up-fac" ${idx === 0 ? 'disabled' : ''} title="Move Up">⬆️</button>
            <button class="btn btn-sm btn-outline btn-down-fac" ${idx === items.length - 1 ? 'disabled' : ''} title="Move Down">⬇️</button>
            <button class="btn btn-sm btn-outline-danger btn-delete-facility">🗑️</button>
          </div>
          <div style="display: flex; gap: 0.75rem; width: calc(100% - 120px);">
            <input type="text" class="form-control l-fac-icon" style="width: 54px; text-align: center;" placeholder="Icon" value="${escapeHTML(item.icon || '')}">
            <input type="text" class="form-control l-fac-title" style="flex: 1;" placeholder="Title" value="${escapeHTML(item.title || '')}">
          </div>
          <textarea class="form-control mt-2 l-fac-desc" placeholder="Description" rows="2">${escapeHTML(item.description || '')}</textarea>
        `;
        div.querySelector('.btn-up-fac')?.addEventListener('click', () => {
          if (idx > 0) {
            const temp = items[idx];
            items[idx] = items[idx - 1];
            items[idx - 1] = temp;
            renderFacilities();
          }
        });
        div.querySelector('.btn-down-fac')?.addEventListener('click', () => {
          if (idx < items.length - 1) {
            const temp = items[idx];
            items[idx] = items[idx + 1];
            items[idx + 1] = temp;
            renderFacilities();
          }
        });
        div.querySelector('.btn-delete-facility').addEventListener('click', () => {
          items.splice(idx, 1);
          renderFacilities();
        });
        parent.appendChild(div);
      });
    };
    listContainer.querySelector('#btn-add-facility')?.addEventListener('click', () => {
      if (!config.facilities) config.facilities = { items: [] };
      config.facilities.items.push({ icon: '✨', title: 'New Facility', description: '' });
      renderFacilities();
    });

    const renderShifts = () => {
      const parent = listContainer.querySelector('#l-shifts-list');
      if (!parent) return;
      parent.innerHTML = '';
      const items = config.shifts?.items || [];
      items.forEach((item, idx) => {
        const div = document.createElement('div');
        div.style.cssText = 'border: 1px solid var(--color-border); padding: 1rem; border-radius: var(--radius-md); position: relative; background: var(--color-surface);';
        div.innerHTML = `
          <div style="position: absolute; top: 0.75rem; right: 0.75rem; display: flex; gap: 4px;">
            <button class="btn btn-sm btn-outline btn-up-shift" ${idx === 0 ? 'disabled' : ''} title="Move Up">⬆️</button>
            <button class="btn btn-sm btn-outline btn-down-shift" ${idx === items.length - 1 ? 'disabled' : ''} title="Move Down">⬇️</button>
            <button class="btn btn-sm btn-outline-danger btn-delete-shift">🗑️</button>
          </div>
          <div style="display: flex; gap: 0.75rem; width: calc(100% - 120px); flex-wrap: wrap;">
            <input type="text" class="form-control l-shift-icon" style="width: 54px; text-align: center;" placeholder="Icon" value="${escapeHTML(item.icon || '')}">
            <input type="text" class="form-control l-shift-name" style="flex: 1;" placeholder="Name" value="${escapeHTML(item.name || '')}">
            <input type="text" class="form-control l-shift-timing" style="flex: 1;" placeholder="Timings" value="${escapeHTML(item.timing || '')}">
          </div>
          <textarea class="form-control mt-2 l-shift-desc" placeholder="Description" rows="2">${escapeHTML(item.description || '')}</textarea>
        `;
        div.querySelector('.btn-up-shift')?.addEventListener('click', () => {
          if (idx > 0) {
            const temp = items[idx];
            items[idx] = items[idx - 1];
            items[idx - 1] = temp;
            renderShifts();
          }
        });
        div.querySelector('.btn-down-shift')?.addEventListener('click', () => {
          if (idx < items.length - 1) {
            const temp = items[idx];
            items[idx] = items[idx + 1];
            items[idx + 1] = temp;
            renderShifts();
          }
        });
        div.querySelector('.btn-delete-shift').addEventListener('click', () => {
          items.splice(idx, 1);
          renderShifts();
        });
        parent.appendChild(div);
      });
    };
    listContainer.querySelector('#btn-add-shift')?.addEventListener('click', () => {
      if (!config.shifts) config.shifts = { items: [] };
      config.shifts.items.push({ icon: '🕒', name: 'New Shift', timing: '', description: '' });
      renderShifts();
    });

    const renderRules = () => {
      const parent = listContainer.querySelector('#l-rules-list');
      if (!parent) return;
      parent.innerHTML = '';
      const items = config.rules?.items || [];
      items.forEach((item, idx) => {
        const div = document.createElement('div');
        div.style.cssText = 'display: flex; gap: 0.5rem; align-items: center; background: var(--color-surface); padding: 8px 12px; border: 1px solid var(--color-border); border-radius: var(--radius-md); margin-bottom: 6px;';
        div.innerHTML = `
          <span style="font-weight: 700; font-size: 0.85rem; color: var(--color-primary); min-width: 24px; text-align: center;">${idx + 1}.</span>
          <input type="text" class="form-control l-rule-text" style="flex: 1;" value="${escapeHTML(item)}" placeholder="Rule statement...">
          <div style="display: flex; gap: 4px;">
            <button class="btn btn-sm btn-outline btn-up-rule" ${idx === 0 ? 'disabled' : ''} title="Move Up">⬆️</button>
            <button class="btn btn-sm btn-outline btn-down-rule" ${idx === items.length - 1 ? 'disabled' : ''} title="Move Down">⬇️</button>
            <button class="btn btn-sm btn-outline-danger btn-delete-rule">🗑️</button>
          </div>
        `;
        div.querySelector('.btn-up-rule')?.addEventListener('click', () => {
          if (idx > 0) {
            const temp = items[idx];
            items[idx] = items[idx - 1];
            items[idx - 1] = temp;
            renderRules();
          }
        });
        div.querySelector('.btn-down-rule')?.addEventListener('click', () => {
          if (idx < items.length - 1) {
            const temp = items[idx];
            items[idx] = items[idx + 1];
            items[idx + 1] = temp;
            renderRules();
          }
        });
        div.querySelector('.btn-delete-rule').addEventListener('click', () => {
          items.splice(idx, 1);
          renderRules();
        });
        parent.appendChild(div);
      });
    };
    listContainer.querySelector('#btn-add-rule')?.addEventListener('click', () => {
      if (!config.rules) config.rules = { items: [] };
      config.rules.items.push('');
      renderRules();
    });

    const renderGallery = () => {
      const parent = listContainer.querySelector('#l-gallery-list');
      if (!parent) return;
      parent.innerHTML = '';
      const items = config.gallery?.images || [];
      items.forEach((item, idx) => {
        const div = document.createElement('div');
        div.style.cssText = 'border: 1px solid var(--color-border); padding: 1rem; border-radius: var(--radius-md); display: flex; gap: 1rem; align-items: center; position: relative; background: var(--color-surface);';
        div.innerHTML = `
          <img src="${escapeHTML(item.url || 'https://via.placeholder.com/80')}" style="width: 70px; height: 70px; object-fit: cover; border-radius: var(--radius-md);">
          <div style="flex: 1; display: flex; flex-direction: column; gap: 0.4rem;">
            <input type="text" class="form-control l-gal-url" placeholder="Image URL" value="${escapeHTML(item.url || '')}">
            <div style="display: flex; gap: 0.5rem;">
              <select class="form-select l-gal-cat" style="width: 130px;">
                <option value="Cabins" ${item.category === 'Cabins' ? 'selected' : ''}>Cabins</option>
                <option value="Hall" ${item.category === 'Hall' ? 'selected' : ''}>Hall</option>
                <option value="Amenities" ${item.category === 'Amenities' ? 'selected' : ''}>Amenities</option>
                <option value="Entrance" ${item.category === 'Entrance' ? 'selected' : ''}>Entrance</option>
              </select>
              <input type="text" class="form-control l-gal-caption" style="flex: 1;" placeholder="Caption" value="${escapeHTML(item.caption || '')}">
            </div>
          </div>
          <div style="display: flex; flex-direction: column; gap: 4px;">
            <button class="btn btn-sm btn-outline btn-up-gal" ${idx === 0 ? 'disabled' : ''} title="Move Up">⬆️</button>
            <button class="btn btn-sm btn-outline btn-down-gal" ${idx === items.length - 1 ? 'disabled' : ''} title="Move Down">⬇️</button>
            <button class="btn btn-sm btn-outline-danger btn-delete-gallery">🗑️</button>
          </div>
        `;
        
        div.querySelector('.l-gal-url').addEventListener('input', (e) => {
          div.querySelector('img').src = e.target.value || 'https://via.placeholder.com/80';
        });

        div.querySelector('.btn-up-gal')?.addEventListener('click', () => {
          if (idx > 0) {
            const temp = items[idx];
            items[idx] = items[idx - 1];
            items[idx - 1] = temp;
            renderGallery();
          }
        });
        div.querySelector('.btn-down-gal')?.addEventListener('click', () => {
          if (idx < items.length - 1) {
            const temp = items[idx];
            items[idx] = items[idx + 1];
            items[idx + 1] = temp;
            renderGallery();
          }
        });
        div.querySelector('.btn-delete-gallery').addEventListener('click', () => {
          items.splice(idx, 1);
          renderGallery();
        });
        parent.appendChild(div);
      });
    };
    listContainer.querySelector('#btn-add-gallery')?.addEventListener('click', () => {
      if (!config.gallery) config.gallery = { images: [] };
      config.gallery.images.push({ url: '', category: 'Hall', caption: '' });
      renderGallery();
    });

    const renderFaqs = () => {
      const parent = listContainer.querySelector('#l-faqs-list');
      if (!parent) return;
      parent.innerHTML = '';
      const items = config.faqs?.items || [];
      items.forEach((item, idx) => {
        const div = document.createElement('div');
        div.style.cssText = 'border: 1px solid var(--color-border); padding: 1rem; border-radius: var(--radius-md); position: relative; background: var(--color-surface);';
        div.innerHTML = `
          <div style="position: absolute; top: 0.75rem; right: 0.75rem; display: flex; gap: 4px;">
            <button class="btn btn-sm btn-outline btn-up-faq" ${idx === 0 ? 'disabled' : ''} title="Move Up">⬆️</button>
            <button class="btn btn-sm btn-outline btn-down-faq" ${idx === items.length - 1 ? 'disabled' : ''} title="Move Down">⬇️</button>
            <button class="btn btn-sm btn-outline-danger btn-delete-faq">🗑️</button>
          </div>
          <input type="text" class="form-control l-faq-q mb-2" style="width: calc(100% - 120px);" placeholder="Question" value="${escapeHTML(item.question || '')}">
          <textarea class="form-control l-faq-a" placeholder="Answer" rows="2">${escapeHTML(item.answer || '')}</textarea>
        `;
        div.querySelector('.btn-up-faq')?.addEventListener('click', () => {
          if (idx > 0) {
            const temp = items[idx];
            items[idx] = items[idx - 1];
            items[idx - 1] = temp;
            renderFaqs();
          }
        });
        div.querySelector('.btn-down-faq')?.addEventListener('click', () => {
          if (idx < items.length - 1) {
            const temp = items[idx];
            items[idx] = items[idx + 1];
            items[idx + 1] = temp;
            renderFaqs();
          }
        });
        div.querySelector('.btn-delete-faq').addEventListener('click', () => {
          items.splice(idx, 1);
          renderFaqs();
        });
        parent.appendChild(div);
      });
    };
    listContainer.querySelector('#btn-add-faq')?.addEventListener('click', () => {
      if (!config.faqs) config.faqs = { items: [] };
      config.faqs.items.push({ question: '', answer: '' });
      renderFaqs();
    });

    const renderTestimonials = () => {
      const parent = listContainer.querySelector('#l-testimonials-list');
      if (!parent) return;
      parent.innerHTML = '';
      const items = config.testimonials?.items || [];
      items.forEach((item, idx) => {
        const div = document.createElement('div');
        div.style.cssText = 'border: 1px solid var(--color-border); padding: 1rem; border-radius: var(--radius-md); position: relative; background: var(--color-surface);';
        div.innerHTML = `
          <div style="position: absolute; top: 0.75rem; right: 0.75rem; display: flex; gap: 4px;">
            <button class="btn btn-sm btn-outline btn-up-test" ${idx === 0 ? 'disabled' : ''} title="Move Up">⬆️</button>
            <button class="btn btn-sm btn-outline btn-down-test" ${idx === items.length - 1 ? 'disabled' : ''} title="Move Down">⬇️</button>
            <button class="btn btn-sm btn-outline-danger btn-delete-test">🗑️</button>
          </div>
          <div style="display: flex; gap: 0.75rem; margin-bottom: 0.5rem; width: calc(100% - 120px); flex-wrap: wrap;">
            <input type="text" class="form-control l-test-name" style="flex: 1;" placeholder="Student Name" value="${escapeHTML(item.name || '')}">
            <input type="text" class="form-control l-test-exam" style="flex: 1;" placeholder="Exam / Badge" value="${escapeHTML(item.exam || '')}">
            <input type="number" class="form-control l-test-rating" style="width: 110px;" placeholder="Rating (1-5)" min="1" max="5" value="${item.rating || 5}">
          </div>
          <textarea class="form-control l-test-feedback" placeholder="Feedback Quote" rows="2">${escapeHTML(item.feedback || '')}</textarea>
        `;
        div.querySelector('.btn-up-test')?.addEventListener('click', () => {
          if (idx > 0) {
            const temp = items[idx];
            items[idx] = items[idx - 1];
            items[idx - 1] = temp;
            renderTestimonials();
          }
        });
        div.querySelector('.btn-down-test')?.addEventListener('click', () => {
          if (idx < items.length - 1) {
            const temp = items[idx];
            items[idx] = items[idx + 1];
            items[idx + 1] = temp;
            renderTestimonials();
          }
        });
        div.querySelector('.btn-delete-test').addEventListener('click', () => {
          items.splice(idx, 1);
          renderTestimonials();
        });
        parent.appendChild(div);
      });
    };
    listContainer.querySelector('#btn-add-testimonial')?.addEventListener('click', () => {
      if (!config.testimonials) config.testimonials = { items: [] };
      config.testimonials.items.push({ name: '', exam: '', rating: 5, feedback: '' });
      renderTestimonials();
    });

    renderFacilities();
    renderShifts();
    renderRules();
    renderGallery();
    renderFaqs();
    renderTestimonials();
  };

  container.querySelector('#btn-save-landing')?.addEventListener('click', async () => {
    const btn = container.querySelector('#btn-save-landing');
    Loading.button(btn, true);
    
    // Sync UI to payload
    const payload = { ...config };
    
    // Hero
    payload.hero = {
      ...payload.hero,
      title: listContainer.querySelector('#l-hero-title').value,
      subtitle: listContainer.querySelector('#l-hero-subtitle').value,
      bannerImage: listContainer.querySelector('#l-hero-banner').value,
      enableTicker: listContainer.querySelector('#l-hero-enableTicker').checked,
      tickerText: listContainer.querySelector('#l-hero-ticker').value,
      badges: listContainer.querySelector('#l-hero-badges').value.split(',').map(s => s.trim()).filter(Boolean),
      liveSeatBadge: {
        enabled: listContainer.querySelector('#l-hero-liveSeatBadge-enabled').checked,
        text: listContainer.querySelector('#l-hero-liveSeatBadge-text').value
      }
    };
    
    // About
    payload.about = {
      ...payload.about,
      title: listContainer.querySelector('#l-about-title').value,
      description: listContainer.querySelector('#l-about-description').value,
      highlightPoints: Array.from(listContainer.querySelectorAll('.l-about-point')).map(el => el.value),
      stats: Array.from(listContainer.querySelectorAll('.l-about-stat-num')).map((el, i) => ({
        number: el.value,
        label: listContainer.querySelectorAll('.l-about-stat-label')[i].value
      }))
    };
    
    // Facilities
    payload.facilities = {
      ...payload.facilities,
      items: Array.from(listContainer.querySelectorAll('#l-facilities-list > div')).map(div => ({
        icon: div.querySelector('.l-fac-icon').value,
        title: div.querySelector('.l-fac-title').value,
        description: div.querySelector('.l-fac-desc').value
      }))
    };
    
    // Shifts
    payload.shifts = {
      ...payload.shifts,
      items: Array.from(listContainer.querySelectorAll('#l-shifts-list > div')).map(div => ({
        icon: div.querySelector('.l-shift-icon').value,
        name: div.querySelector('.l-shift-name').value,
        timing: div.querySelector('.l-shift-timing').value,
        description: div.querySelector('.l-shift-desc').value
      }))
    };
    
    // Rules
    payload.rules = {
      ...payload.rules,
      items: Array.from(listContainer.querySelectorAll('.l-rule-text')).map(el => el.value)
    };
    
    // Gallery
    payload.gallery = {
      ...payload.gallery,
      images: Array.from(listContainer.querySelectorAll('#l-gallery-list > div')).map(div => ({
        url: div.querySelector('.l-gal-url').value,
        category: div.querySelector('.l-gal-cat').value,
        caption: div.querySelector('.l-gal-caption').value
      }))
    };
    
    // FAQs
    payload.faqs = {
      ...payload.faqs,
      items: Array.from(listContainer.querySelectorAll('#l-faqs-list > div')).map(div => ({
        question: div.querySelector('.l-faq-q').value,
        answer: div.querySelector('.l-faq-a').value
      }))
    };
    
    // Testimonials
    payload.testimonials = {
      ...payload.testimonials,
      googleRating: listContainer.querySelector('#l-test-googleRating').value,
      googleReviewsCount: listContainer.querySelector('#l-test-googleReviewsCount').value,
      items: Array.from(listContainer.querySelectorAll('#l-testimonials-list > div')).map(div => ({
        name: div.querySelector('.l-test-name').value,
        exam: div.querySelector('.l-test-exam').value,
        rating: Number(div.querySelector('.l-test-rating').value),
        feedback: div.querySelector('.l-test-feedback').value
      }))
    };
    
    // Contact
    payload.contact = {
      ...payload.contact,
      phone: listContainer.querySelector('#l-contact-phone').value,
      whatsapp: listContainer.querySelector('#l-contact-wa').value,
      address: listContainer.querySelector('#l-contact-address').value,
      openingHours: listContainer.querySelector('#l-contact-hours').value,
      googleMapEmbedUrl: listContainer.querySelector('#l-contact-map').value
    };

    try {
      const res = await api.put('/api/landing', payload);
      if (res.success) {
        Toast.success('Landing page updated successfully');
        const pvIframe = listContainer.querySelector('#pv-landing-iframe');
        if (pvIframe) pvIframe.src = '/landing?preview=' + Date.now();
      } else {
        Toast.error(res.message || 'Error updating landing page');
      }
    } catch (err) {
      Toast.error(err.message || 'Network error');
    } finally {
      Loading.button(btn, false);
    }
  });

  loadSettings();
}
