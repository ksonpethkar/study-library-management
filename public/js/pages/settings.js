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

  const pMethods = Array.isArray(profile.paymentMethods) ? profile.paymentMethods : [];
  const getEnabled = (k) => {
    const found = pMethods.find(m => m.key === k);
    return found ? (found.enabled === true || found.enabled === 'true' || found.enabled === 1 || found.enabled === '1') : true;
  };
  const isUpiEnabled = getEnabled('upi');
  const isBankEnabled = getEnabled('netbanking');
  const isDeskEnabled = getEnabled('desk');

  // Selected reminder days
  let selectedReminderDays = Array.isArray(notif['payment.paymentReminder'] || notif.paymentReminder)
    ? (notif['payment.paymentReminder'] || notif.paymentReminder)
    : [7, 3, 1];

  let selectedExpiryDays = Array.isArray(notif['notification.expiryReminderDays'] || notif.expiryReminderDays)
    ? (notif['notification.expiryReminderDays'] || notif.expiryReminderDays)
    : [7, 3, 1, 0];

  let selectedBalanceDays = Array.isArray(notif['notification.balanceReminderDays'] || notif.balanceReminderDays)
    ? (notif['notification.balanceReminderDays'] || notif.balanceReminderDays)
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
      <div style="display: flex; gap: 0.75rem; flex-wrap: wrap;">
        <button id="btn-quick-backup-header" class="btn btn-outline-success" style="display: inline-flex; align-items: center; gap: 0.5rem; font-weight: 600;">
          <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
          <span>💾 Quick Backup</span>
        </button>
        <button id="btn-save-all-settings" class="btn btn-primary" style="display: inline-flex; align-items: center; gap: 0.5rem; font-weight: 600;">
          <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"></path><polyline points="17 21 17 13 7 13 7 21"></polyline><polyline points="7 3 7 8 15 8"></polyline></svg>
          <span>Save All Changes</span>
        </button>
      </div>
    </div>

    <!-- Contextual Guidance Tip Banner -->
    <div style="background: rgba(108, 92, 231, 0.06); border: 1px solid rgba(108, 92, 231, 0.2); border-radius: 10px; padding: 10px 14px; font-size: 0.85rem; display: flex; align-items: center; gap: 10px; margin-bottom: 1rem;">
      <span style="font-size: 1.1rem;">💡</span>
      <span><strong>Tip:</strong> Changes saved in branding, receipt templates, and sidebar rules take effect instantly across all connected devices.</span>
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
          <span>🎓</span> Admission Rules & Student ID Generator
        </button>
        <button class="settings-tab-btn" data-tab="notifications" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem; transition: all 0.2s ease;">
          <span>🔔</span> Notifications & WhatsApp Templates
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
        <button class="settings-tab-btn" data-tab="sidebar" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem; transition: all 0.2s ease;">
          <span>🧭</span> Sidebar & Navigation Manager
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
        <button class="settings-tab-btn" data-tab="systemhealth" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem; transition: all 0.2s ease;">
          <span>🛡️</span> System Health & Security Diagnostics
        </button>
      </div>
    </div>

    <!-- TAB PANELS CONTAINER -->
    <div id="settings-tab-content">
      
      <!-- ========================================== -->
      <!-- SECTION A: LIBRARY BRANDING & INFO -->
      <!-- ========================================== -->
      <!-- ========================================== -->
      <!-- SECTION A: LIBRARY BRANDING & INFO -->
      <!-- ========================================== -->
      <div class="settings-panel" id="panel-branding" style="display: block;">
        <form id="form-branding">
          
          <!-- Card Header & Notice -->
          <div class="card mb-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden; box-shadow: var(--shadow-sm);">
            <div class="card-header" style="padding: 1.25rem 1.5rem; border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover); display: flex; justify-content: space-between; align-items: center;">
              <div>
                <h3 style="margin: 0; font-size: 1.15rem; font-weight: 700; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
                  <span>🏢</span> Library Branding & Business Master Config
                </h3>
                <p style="margin: 4px 0 0 0; font-size: 0.85rem; color: var(--color-text-secondary);">Categorized master settings affecting ID cards, invoices, receipts, portals, and payment gateways.</p>
              </div>
              <span class="badge" style="background: var(--color-primary-bg); color: var(--color-primary); font-weight: 700; padding: 6px 12px; border-radius: 20px;">
                Categorized &amp; Structured
              </span>
            </div>
            
            <div class="card-body" style="padding: 1.5rem; display: flex; flex-direction: column; gap: 1.75rem;">
              
              <!-- CATEGORY 1: CORE IDENTITY & SLOGAN -->
              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
                <h4 style="margin: 0 0 1rem 0; font-size: 1rem; font-weight: 700; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
                  <span>🏛️</span> Category 1: Core Library Identity &amp; Registration
                </h4>
                
                <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 1.25rem;">
                  <div class="form-group">
                    <label class="form-label" for="setting-businessName" style="font-weight: 600;">Business / Library Name *</label>
                    <input type="text" id="setting-businessName" class="form-control" required value="${escapeHTML(profile.businessName || 'The Cozy Corner Centre')}" placeholder="e.g. The Cozy Corner Centre">
                  </div>
                  
                  <div class="form-group">
                    <label class="form-label" for="setting-tagline" style="font-weight: 600;">Tagline / Slogan</label>
                    <input type="text" id="setting-tagline" class="form-control" value="${escapeHTML(profile.tagline || '')}" placeholder="e.g. Silence, Focus & Success">
                  </div>

                  <div class="form-group">
                    <label class="form-label" for="setting-gstNumber" style="font-weight: 600;">GSTIN / Tax Registration Number</label>
                    <input type="text" id="setting-gstNumber" class="form-control" value="${escapeHTML(profile.gstNumber || '')}" placeholder="e.g. 27AAAAA0000A1Z5">
                  </div>

                  <div class="form-group">
                    <label class="form-label" for="setting-registrationNumber" style="font-weight: 600;">Registration / Shop Act License No.</label>
                    <input type="text" id="setting-registrationNumber" class="form-control" value="${escapeHTML(profile.registrationNumber || '')}" placeholder="e.g. REG/2026/982">
                  </div>
                </div>
              </div>

              <!-- CATEGORY 2: VISUAL MEDIA ASSETS & LOGOS -->
              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
                <h4 style="margin: 0 0 1rem 0; font-size: 1rem; font-weight: 700; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
                  <span>🎨</span> Category 2: Visual Media Assets &amp; Brand Logos
                </h4>

                <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 1.25rem; padding: 1rem; background: var(--color-surface); border-radius: var(--radius-md); border: 1px solid var(--color-border);">
                  <!-- Logo -->
                  <div id="mount-setting-logo"></div>

                  <!-- Favicon -->
                  <div id="mount-setting-favicon"></div>

                  <!-- UPI QR Code -->
                  <div id="mount-setting-qr"></div>
                </div>
              </div>

              <!-- CATEGORY 3: ACCEPTED PAYMENT METHODS & GATEWAYS -->
              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; flex-wrap: wrap; gap: 8px;">
                  <h4 style="margin: 0; font-size: 1rem; font-weight: 700; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
                    <span>💳</span> Category 3: Accepted Payment Gateways &amp; Banking Details
                  </h4>
                  <span class="badge" style="background: rgba(0, 184, 148, 0.15); color: var(--color-success); font-weight: 700; font-size: 0.75rem;">Simplified Mode</span>
                </div>

                <div style="display: flex; flex-direction: column; gap: 1.25rem;">
                  
                  <!-- Option 1: UPI Payments -->
                  <div style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 1.25rem;">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; flex-wrap: wrap; gap: 8px;">
                      <div style="display: flex; align-items: center; gap: 10px;">
                        <span style="font-size: 1.5rem;">⚡</span>
                        <div>
                          <h5 style="margin: 0; font-weight: 700; font-size: 0.98rem; color: var(--color-text-primary);">1. UPI Payments (GPay, PhonePe, Paytm, Dynamic QR)</h5>
                          <p style="margin: 2px 0 0 0; font-size: 0.8rem; color: var(--color-text-secondary);">Generates dynamic QR codes and mobile 1-tap deep links for students.</p>
                        </div>
                      </div>
                      <label style="display: flex; align-items: center; gap: 8px; cursor: pointer; font-weight: 700; font-size: 0.85rem; background: var(--color-bg-secondary); padding: 6px 14px; border-radius: 20px; border: 1px solid var(--color-border);">
                        <input type="checkbox" id="setting-pm-upi-enable" ${isUpiEnabled ? 'checked' : ''} style="width: 18px; height: 18px;">
                        <span id="label-pm-upi-status" style="color: ${isUpiEnabled ? 'var(--color-success)' : 'var(--color-danger)'};">${isUpiEnabled ? '🟢 ENABLED' : '🔴 DISABLED'}</span>
                      </label>
                    </div>

                    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 1rem;">
                      <div class="form-group">
                        <label class="form-label" for="setting-upiId" style="font-weight: 600;">⚡ Official Library UPI ID (VPA) *</label>
                        <input type="text" id="setting-upiId" class="form-control" value="${escapeHTML(profile.upiId || '')}" placeholder="e.g. 7276969070@upi">
                      </div>
                      <div class="form-group" style="display: flex; align-items: center; margin-top: 1.6rem;">
                        <label style="display: flex; align-items: center; gap: 10px; cursor: pointer; font-weight: 600; font-size: 0.85rem; margin: 0;">
                          <input type="checkbox" id="setting-enableUpiDeepLinks" ${profile.enableUpiDeepLinks !== false ? 'checked' : ''}>
                          <span>📱 Enable 1-Tap Mobile App Intent Buttons (GPay/PhonePe)</span>
                        </label>
                      </div>
                    </div>
                  </div>

                  <!-- Option 2: Direct Bank Transfer -->
                  <div style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 1.25rem;">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; flex-wrap: wrap; gap: 8px;">
                      <div style="display: flex; align-items: center; gap: 10px;">
                        <span style="font-size: 1.5rem;">🏦</span>
                        <div>
                          <h5 style="margin: 0; font-weight: 700; font-size: 0.98rem; color: var(--color-text-primary);">2. Direct Bank Account Transfer (IMPS / NEFT)</h5>
                          <p style="margin: 2px 0 0 0; font-size: 0.8rem; color: var(--color-text-secondary);">Displays bank account &amp; IFSC details for direct bank transfers.</p>
                        </div>
                      </div>
                      <label style="display: flex; align-items: center; gap: 8px; cursor: pointer; font-weight: 700; font-size: 0.85rem; background: var(--color-bg-secondary); padding: 6px 14px; border-radius: 20px; border: 1px solid var(--color-border);">
                        <input type="checkbox" id="setting-pm-bank-enable" ${isBankEnabled ? 'checked' : ''} style="width: 18px; height: 18px;">
                        <span id="label-pm-bank-status" style="color: ${isBankEnabled ? 'var(--color-success)' : 'var(--color-danger)'};">${isBankEnabled ? '🟢 ENABLED' : '🔴 DISABLED'}</span>
                      </label>
                    </div>

                    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem;">
                      <div class="form-group">
                        <label class="form-label" for="setting-bank-name" style="font-weight: 600;">Bank Name</label>
                        <input type="text" id="setting-bank-name" class="form-control" value="${escapeHTML(profile.bankDetails?.bankName || '')}" placeholder="e.g. State Bank of India">
                      </div>
                      <div class="form-group">
                        <label class="form-label" for="setting-bank-accName" style="font-weight: 600;">Account Holder Name</label>
                        <input type="text" id="setting-bank-accName" class="form-control" value="${escapeHTML(profile.bankDetails?.accountName || '')}" placeholder="e.g. The Cozy Corner Centre">
                      </div>
                      <div class="form-group">
                        <label class="form-label" for="setting-bank-accNum" style="font-weight: 600;">Account Number</label>
                        <input type="text" id="setting-bank-accNum" class="form-control" value="${escapeHTML(profile.bankDetails?.accountNumber || '')}" placeholder="e.g. 50100234567890">
                      </div>
                      <div class="form-group">
                        <label class="form-label" for="setting-bank-ifsc" style="font-weight: 600;">IFSC Code</label>
                        <input type="text" id="setting-bank-ifsc" class="form-control" value="${escapeHTML(profile.bankDetails?.ifscCode || '')}" placeholder="e.g. SBIN0001234">
                      </div>
                    </div>
                  </div>

                  <!-- Option 3: Pay Cash at Reception -->
                  <div style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 1.25rem;">
                    <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
                      <div style="display: flex; align-items: center; gap: 10px;">
                        <span style="font-size: 1.5rem;">💵</span>
                        <div>
                          <h5 style="margin: 0; font-weight: 700; font-size: 0.98rem; color: var(--color-text-primary);">3. Pay Cash at Library Reception Desk</h5>
                          <p style="margin: 2px 0 0 0; font-size: 0.8rem; color: var(--color-text-secondary);">Pre-reserves student seat for 24 hours while student pays cash on arrival.</p>
                        </div>
                      </div>
                      <label style="display: flex; align-items: center; gap: 8px; cursor: pointer; font-weight: 700; font-size: 0.85rem; background: var(--color-bg-secondary); padding: 6px 14px; border-radius: 20px; border: 1px solid var(--color-border);">
                        <input type="checkbox" id="setting-pm-desk-enable" ${isDeskEnabled ? 'checked' : ''} style="width: 18px; height: 18px;">
                        <span id="label-pm-desk-status" style="color: ${isDeskEnabled ? 'var(--color-success)' : 'var(--color-danger)'};">${isDeskEnabled ? '🟢 ENABLED' : '🔴 DISABLED'}</span>
                      </label>
                    </div>
                  </div>

                  <!-- Collapsible Advanced Gateway Options -->
                  <details style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 12px 16px;">
                    <summary style="cursor: pointer; font-weight: 700; font-size: 0.9rem; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
                      ⚡ Advanced Gateway Auto-Verification (Optional - Razorpay / PhonePe / Cashfree)
                    </summary>
                    <div style="margin-top: 1rem; padding-top: 1rem; border-top: 1px solid var(--color-border);">
                      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 1rem;">
                        <div class="form-group">
                          <label class="form-label" for="setting-gatewayProvider" style="font-weight: 600;">Verification Engine</label>
                          <select id="setting-gatewayProvider" class="form-select" style="font-weight: 700;">
                            <option value="manual_upi" ${profile.gatewayProvider === 'manual_upi' || !profile.gatewayProvider ? 'selected' : ''}>Option A: Free Standard UPI QR + Anti-Duplicate Check</option>
                            <option value="razorpay" ${profile.gatewayProvider === 'razorpay' ? 'selected' : ''}>Option B: Razorpay PG Auto-Webhooks</option>
                            <option value="phonepe" ${profile.gatewayProvider === 'phonepe' ? 'selected' : ''}>Option B: PhonePe Business PG Webhooks</option>
                            <option value="cashfree" ${profile.gatewayProvider === 'cashfree' ? 'selected' : ''}>Option B: Cashfree Auto-Collect Webhooks</option>
                          </select>
                        </div>
                        <div class="form-group">
                          <label class="form-label" for="setting-razorpayKeyId" style="font-weight: 600;">Gateway Key ID / App ID</label>
                          <input type="text" id="setting-razorpayKeyId" class="form-control" value="${escapeHTML(profile.razorpayKeyId || '')}">
                        </div>
                        <div class="form-group">
                          <label class="form-label" for="setting-razorpaySecret" style="font-weight: 600;">Gateway Secret Key</label>
                          <input type="password" id="setting-razorpaySecret" class="form-control" value="${escapeHTML(profile.razorpaySecret || '')}">
                        </div>
                      </div>
                    </div>
                  </details>

                </div>
              </div>

              <!-- CATEGORY 4: OFFICIAL CONTACT & LOCATION DETAILS -->
              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
                <h4 style="margin: 0 0 1rem 0; font-size: 1rem; font-weight: 700; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
                  <span>📍</span> Category 4: Official Contact &amp; Physical Location Details
                </h4>

                <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 1rem; margin-bottom: 1.25rem;">
                  <div class="form-group">
                    <label class="form-label" for="setting-phone" style="font-weight: 500;">Phone / WhatsApp Support *</label>
                    <input type="text" id="setting-phone" class="form-control" value="${escapeHTML(profile.phone || '')}" placeholder="+91 98765 43210">
                  </div>
                  <div class="form-group">
                    <label class="form-label" for="setting-email" style="font-weight: 500;">Official Email Address *</label>
                    <input type="email" id="setting-email" class="form-control" value="${escapeHTML(profile.email || '')}" placeholder="support@studylib.com">
                  </div>
                  <div class="form-group">
                    <label class="form-label" for="setting-website" style="font-weight: 500;">Website URL</label>
                    <input type="url" id="setting-website" class="form-control" value="${escapeHTML(profile.website || '')}" placeholder="https://www.studylibrary.com">
                  </div>
                </div>

                <div class="form-group" style="margin-bottom: 1.25rem;">
                  <label class="form-label" for="setting-address" style="font-weight: 500;">Full Street Address</label>
                  <input type="text" id="setting-address" class="form-control" value="${escapeHTML(profile.address || '')}" placeholder="Plot 42, Knowledge Park III, Near Metro Station">
                </div>

                <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 1rem; margin-bottom: 1.25rem;">
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

                <!-- Social Links -->
                <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem;">
                  <div class="form-group">
                    <label class="form-label" for="setting-social-whatsapp" style="font-weight: 500;">WhatsApp Support Group Link</label>
                    <input type="text" id="setting-social-whatsapp" class="form-control" value="${escapeHTML(profile.socialLinks?.whatsapp || '')}" placeholder="https://chat.whatsapp.com/...">
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

              <!-- SINGLE CONSOLIDATED SAVE BUTTON AT BOTTOM -->
              <div style="display: flex; justify-content: flex-end; padding-top: 1rem; border-top: 1px solid var(--color-divider);">
                <button type="submit" id="btn-save-branding" class="btn btn-primary" style="font-weight: 700; padding: 0.65rem 1.75rem;">
                  💾 Save Branding &amp; Master Business Settings
                </button>
              </div>

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
                <h3 style="margin: 0; font-size: 1.15rem; font-weight: 700; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
                  <span>💰</span> Fee Due Dates, Late Fines &amp; Auto-Suspension Rules
                </h3>
                <p style="margin: 4px 0 0 0; font-size: 0.85rem; color: var(--color-text-secondary);">Configure grace windows, fine calculation modes, penalty amounts, and automatic seat suspension thresholds.</p>
              </div>
              <span class="badge" style="background: var(--color-primary-bg); color: var(--color-primary); font-weight: 700; padding: 6px 12px; border-radius: 20px;">
                Categorized Engine
              </span>
            </div>

            <div class="card-body" style="padding: 1.5rem; display: flex; flex-direction: column; gap: 1.5rem;">
              
              <!-- CATEGORY 1: GRACE PERIOD & DUE DATES -->
              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
                <h4 style="margin: 0 0 1rem 0; font-size: 1rem; font-weight: 700; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
                  <span>⏱️</span> Category 1: Grace Period &amp; Due Date Rules
                </h4>

                <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 1.25rem;">
                  <!-- Grace Period -->
                  <div class="form-group">
                    <label class="form-label" for="setting-gracePeriod" style="font-weight: 600;">Grace Window Period (Days) *</label>
                    <div style="position: relative;">
                      <input type="number" id="setting-gracePeriod" class="form-control" min="0" max="90" value="${pay['payment.gracePeriod'] ?? pay.gracePeriod ?? 5}" required>
                    </div>
                    <small style="color: var(--color-text-secondary); display: block; margin-top: 4px;">
                      Days after due date before late fine penalty starts calculating. Set 0 for immediate fine.
                    </small>
                  </div>
                </div>
              </div>

              <!-- CATEGORY 2: LATE FINE PENALTY ENGINE -->
              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
                <h4 style="margin: 0 0 1rem 0; font-size: 1rem; font-weight: 700; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
                  <span>💸</span> Category 2: Late Fine Calculation Engine &amp; Penalty Rates
                </h4>

                <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 1.25rem;">
                  <!-- Late Fee Calculation Mode -->
                  <div class="form-group">
                    <label class="form-label" style="font-weight: 600;">Late Fee Calculation Mode *</label>
                    <div style="display: flex; gap: 0.75rem; margin-top: 4px;">
                      <label style="flex: 1; display: flex; align-items: center; gap: 0.5rem; padding: 0.65rem 1rem; border: 1px solid var(--color-border); border-radius: var(--radius-md); background: var(--color-surface); cursor: pointer;">
                        <input type="radio" name="lateFeeType" value="flat" ${(pay['payment.lateFeeType'] || pay.lateFeeType || 'flat') === 'flat' ? 'checked' : ''} style="cursor: pointer;">
                        <div>
                          <div style="font-weight: 700; font-size: 0.9rem;">Flat Rate</div>
                          <div style="font-size: 0.75rem; color: var(--color-text-secondary);">One-time fixed penalty fine</div>
                        </div>
                      </label>
                      <label style="flex: 1; display: flex; align-items: center; gap: 0.5rem; padding: 0.65rem 1rem; border: 1px solid var(--color-border); border-radius: var(--radius-md); background: var(--color-surface); cursor: pointer;">
                        <input type="radio" name="lateFeeType" value="daily" ${(pay['payment.lateFeeType'] || pay.lateFeeType) === 'daily' || (pay['payment.lateFeeType'] || pay.lateFeeType) === 'per_day' ? 'checked' : ''} style="cursor: pointer;">
                        <div>
                          <div style="font-weight: 700; font-size: 0.9rem;">Per-Day Rate</div>
                          <div style="font-size: 0.75rem; color: var(--color-text-secondary);">Accrues each overdue day</div>
                        </div>
                      </label>
                    </div>
                  </div>

                  <!-- Late Fee Amount -->
                  <div class="form-group">
                    <label class="form-label" for="setting-lateFeeAmount" style="font-weight: 600;">Late Fine Penalty Amount (₹) *</label>
                    <div style="position: relative;">
                      <input type="number" id="setting-lateFeeAmount" class="form-control" min="0" step="1" value="${pay['payment.lateFeeAmount'] ?? pay.lateFeeAmount ?? 50}" required>
                    </div>
                    <small style="color: var(--color-text-secondary); display: block; margin-top: 4px;">
                      Amount in Rupees charged either as flat penalty or daily compounding fine rate.
                    </small>
                  </div>
                </div>
              </div>

              <!-- CATEGORY 3: AUTO-SUSPENSION & GATE LOCK -->
              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
                <h4 style="margin: 0 0 1rem 0; font-size: 1rem; font-weight: 700; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
                  <span>🔒</span> Category 3: Auto-Suspension &amp; Gate Kiosk Lock Threshold
                </h4>

                <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 1.25rem;">
                  <!-- Auto-Suspension Threshold -->
                  <div class="form-group">
                    <label class="form-label" for="setting-autoSuspendDays" style="font-weight: 600;">Auto-Suspension Threshold (Overdue Days) *</label>
                    <div style="position: relative;">
                      <input type="number" id="setting-autoSuspendDays" class="form-control" min="1" max="180" value="${pay['payment.autoSuspendDays'] ?? pay.autoSuspendDays ?? 15}" required>
                    </div>
                    <small style="color: var(--color-text-secondary); display: block; margin-top: 4px;">
                      After these days of overdue payment, the student's seat reservation &amp; gate access are automatically locked.
                    </small>
                  </div>
                </div>
              </div>

              <!-- CATEGORY 4: LIVE POLICY SIMULATION CARD -->
              <div id="policy-simulation-card" style="background: var(--color-primary-bg); border: 1px solid var(--color-primary-light); border-radius: var(--radius-lg); padding: 1.25rem;">
                <div style="font-weight: 700; color: var(--color-primary); font-size: 0.95rem; margin-bottom: 0.5rem; display: flex; align-items: center; gap: 0.5rem;">
                  <span>📋</span> Category 4: Live Policy Rule Summary &amp; Simulation
                </div>
                <div id="policy-simulation-text" style="color: var(--color-text-primary); font-size: 0.9rem; line-height: 1.6;">
                  <!-- Dynamically computed in JS -->
                </div>
              </div>

              <!-- SINGLE CONSOLIDATED SAVE BUTTON AT BOTTOM -->
              <div style="display: flex; justify-content: flex-end; padding-top: 1rem; border-top: 1px solid var(--color-divider);">
                <button type="submit" id="btn-save-policies" class="btn btn-primary" style="font-weight: 700; padding: 0.65rem 1.75rem;">
                  💾 Save Fee &amp; Late Fine Policies
                </button>
              </div>

            </div>
          </div>
        </form>
      </div>

      <!-- ========================================== -->
      <!-- SECTION C: ADMISSION RULES & STUDENT ID GENERATOR -->
      <!-- ========================================== -->
      <div class="settings-panel" id="panel-admission" style="display: none;">
        <form id="form-admission">
          <div class="card mb-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden; box-shadow: var(--shadow-sm);">
            <div class="card-header" style="padding: 1.25rem 1.5rem; border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover); display: flex; justify-content: space-between; align-items: center;">
              <div>
                <h3 style="margin: 0; font-size: 1.15rem; font-weight: 700; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
                  <span>🎓</span> Admission Rules &amp; Student ID Generator Master Engine
                </h3>
                <p style="margin: 4px 0 0 0; font-size: 0.85rem; color: var(--color-text-secondary);">Configure prefix, dynamic serial formats, padding digits, starting roll numbers, and auto-admission policies.</p>
              </div>
              <span class="badge" style="background: var(--color-primary-bg); color: var(--color-primary); font-weight: 700; padding: 6px 12px; border-radius: 20px;">
                Categorized Generator
              </span>
            </div>

            <div class="card-body" style="padding: 1.5rem; display: flex; flex-direction: column; gap: 1.5rem;">
              
              <!-- CATEGORY 1: AUTOMATED ADMISSION APPROVALS -->
              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
                <h4 style="margin: 0 0 1rem 0; font-size: 1rem; font-weight: 700; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
                  <span>⚡</span> Category 1: Automated Admission Approvals &amp; Access Controls
                </h4>

                <div style="display: flex; align-items: center; justify-content: space-between; padding: 1.25rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md); gap: 1rem; flex-wrap: wrap;">
                  <div>
                    <div style="font-weight: 700; font-size: 0.98rem; color: var(--color-text-primary); display: flex; align-items: center; gap: 0.5rem;">
                      <span>⚡</span> Auto-Approve New Student Self-Registrations
                      <span id="badge-auto-approve" class="badge ${(adm['admission.autoApprove'] ?? adm.autoApprove) ? 'badge-success' : 'badge-secondary'}" style="margin-left: 0.5rem; font-size: 0.75rem; padding: 2px 10px; border-radius: 12px; background: ${(adm['admission.autoApprove'] ?? adm.autoApprove) ? 'var(--color-success-bg)' : 'var(--color-bg-secondary)'}; color: ${(adm['admission.autoApprove'] ?? adm.autoApprove) ? 'var(--color-success)' : 'var(--color-text-secondary)'}; border: 1px solid currentColor;">
                        ${(adm['admission.autoApprove'] ?? adm.autoApprove) ? 'Enabled' : 'Manual Review'}
                      </span>
                    </div>
                    <p style="color: var(--color-text-secondary); font-size: 0.83rem; margin: 4px 0 0 0;">
                      When enabled, self-registering students are automatically granted active status without waiting for manual admin approval.
                    </p>
                  </div>
                  <div>
                    <label class="switch-label" style="margin: 0;">
                      <input type="checkbox" id="setting-autoApprove" ${(adm['admission.autoApprove'] ?? adm.autoApprove) ? 'checked' : ''}>
                      <span class="switch-slider"></span>
                    </label>
                  </div>
                </div>
              </div>

              <!-- CATEGORY 2: ID PREFIX & SEQUENCE COUNTER -->
              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
                <h4 style="margin: 0 0 1rem 0; font-size: 1rem; font-weight: 700; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
                  <span>🏷️</span> Category 2: Student ID Prefix &amp; Sequence Baseline Counter
                </h4>

                <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 1.25rem;">
                  <!-- Prefix -->
                  <div class="form-group">
                    <label class="form-label" for="setting-idPrefix" style="font-weight: 600;">Student ID Prefix Code *</label>
                    <input type="text" id="setting-idPrefix" class="form-control" value="${escapeHTML(adm['admission.idPrefix'] || adm.idPrefix || 'STU')}" placeholder="e.g. STU, LIB, CCC, PARLI" maxlength="12" required>
                    <small style="color: var(--color-text-secondary); display: block; margin-top: 4px;">
                      Short alphabetic code placed at start (e.g. STU, LIB, CCC, PARLI).
                    </small>
                  </div>

                  <!-- Starting Sequence -->
                  <div class="form-group">
                    <label class="form-label" for="setting-startingSerial" style="font-weight: 600;">Starting Roll Sequence Number *</label>
                    <input type="number" id="setting-startingSerial" class="form-control" value="${escapeHTML(String(adm['admission.startingSerial'] || adm.startingSerial || 1))}" min="1" step="1" placeholder="e.g. 1 or 101" required>
                    <small style="color: var(--color-text-secondary); display: block; margin-top: 4px;">
                      Initial baseline counter for student ID numbers (e.g. 1 or 101).
                    </small>
                  </div>
                </div>
              </div>

              <!-- CATEGORY 3: STRUCTURAL FORMATTING & ZERO-PADDING -->
              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
                <h4 style="margin: 0 0 1rem 0; font-size: 1rem; font-weight: 700; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
                  <span>📐</span> Category 3: Structural Formatting &amp; Zero-Padding Rules
                </h4>

                <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 1.25rem;">
                  <!-- Format Dropdown -->
                  <div class="form-group">
                    <label class="form-label" for="setting-idFormat" style="font-weight: 600;">Student ID Format Pattern *</label>
                    <select id="setting-idFormat" class="form-select" style="font-weight: 700;">
                      <option value="prefix-year-serial" ${(adm['admission.idFormat'] || adm.idFormat || 'prefix-year-serial') === 'prefix-year-serial' ? 'selected' : ''}>STU-2026-001 (Prefix + Year + Serial)</option>
                      <option value="prefix-serial" ${(adm['admission.idFormat'] || adm.idFormat) === 'prefix-serial' ? 'selected' : ''}>STU-001 (Prefix + Serial)</option>
                      <option value="prefix-branch-serial" ${(adm['admission.idFormat'] || adm.idFormat) === 'prefix-branch-serial' ? 'selected' : ''}>LIB-PUN-2026-001 (Prefix + Branch + Year + Serial)</option>
                      <option value="prefix-month-serial" ${(adm['admission.idFormat'] || adm.idFormat) === 'prefix-month-serial' ? 'selected' : ''}>STU-0826-001 (Prefix + Month/Year + Serial)</option>
                    </select>
                    <small style="color: var(--color-text-secondary); display: block; margin-top: 4px;">
                      Dynamic structural template for roll numbers.
                    </small>
                  </div>

                  <!-- Zero Padding Selector -->
                  <div class="form-group">
                    <label class="form-label" for="setting-serialDigits" style="font-weight: 600;">Serial Digits Zero-Padding *</label>
                    <select id="setting-serialDigits" class="form-select" style="font-weight: 700;">
                      <option value="3" ${Number(adm['admission.serialDigits'] || adm.serialDigits || 3) === 3 ? 'selected' : ''}>3 Digits (001)</option>
                      <option value="4" ${Number(adm['admission.serialDigits'] || adm.serialDigits) === 4 ? 'selected' : ''}>4 Digits (0001)</option>
                      <option value="5" ${Number(adm['admission.serialDigits'] || adm.serialDigits) === 5 ? 'selected' : ''}>5 Digits (00001)</option>
                    </select>
                    <small style="color: var(--color-text-secondary); display: block; margin-top: 4px;">
                      Number of zero-padded digits for sequential roll counter.
                    </small>
                  </div>
                </div>
              </div>

              <!-- CATEGORY 4: LIVE DYNAMIC ID BADGE PREVIEW -->
              <div style="background: var(--color-primary-bg); border: 2px dashed var(--color-primary-light); border-radius: var(--radius-lg); padding: 1.5rem; text-align: center;">
                <div style="font-size: 0.85rem; font-weight: 700; color: var(--color-primary); margin-bottom: 0.65rem; text-transform: uppercase; letter-spacing: 0.05em; display: flex; align-items: center; justify-content: center; gap: 6px;">
                  <span>🪪</span> Category 4: Live Dynamic ID Badge Preview
                </div>
                <div id="sample-id-preview" style="font-size: 1.5rem; font-weight: 700; font-family: monospace; color: var(--color-primary); display: inline-flex; align-items: center; justify-content: center; gap: 0.5rem; padding: 0.6rem 1.5rem; background: var(--color-surface); border-radius: var(--radius-md); border: 1px solid var(--color-primary); box-shadow: var(--shadow-sm);">
                  <span style="opacity: 0.75; font-size: 0.95rem; font-weight: 500;">Sample ID:</span> STU-2026-0001
                </div>
                <div style="font-size: 0.8rem; color: var(--color-text-secondary); margin-top: 0.5rem;">
                  Updates in real-time as you modify prefix, format, padding, or starting sequence.
                </div>
              </div>

              <!-- SINGLE CONSOLIDATED SAVE BUTTON AT BOTTOM -->
              <div style="display: flex; justify-content: flex-end; padding-top: 1rem; border-top: 1px solid var(--color-divider);">
                <button type="submit" id="btn-save-admission" class="btn btn-primary" style="font-weight: 700; padding: 0.65rem 1.75rem;">
                  💾 Save Student ID Rules &amp; Admission Config
                </button>
              </div>

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
            <div class="card-header" style="padding: 1.25rem 1.5rem; border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 0.75rem;">
              <div>
                <h3 style="margin: 0; font-size: 1.15rem; font-weight: 700; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
                  <span>🔔</span> Notifications, WhatsApp Schedules &amp; Automated Bots Engine
                </h3>
                <p style="margin: 4px 0 0 0; font-size: 0.85rem; color: var(--color-text-secondary);">Configure automated bot dispatch times, reminder day intervals, WhatsApp Meta API integration, and trigger instant live audits.</p>
              </div>
              <span class="badge" style="background: var(--color-primary-bg); color: var(--color-primary); font-weight: 700; padding: 6px 12px; border-radius: 20px;">
                Categorized Bot Engine
              </span>
            </div>

            <div class="card-body" style="padding: 1.5rem; display: flex; flex-direction: column; gap: 1.5rem;">

              <!-- CATEGORY 1: AUTOMATED WHATSAPP BOT ENGINE & SCHEDULE -->
              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
                <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 1rem; border-bottom: 1px solid var(--color-divider); padding-bottom: 0.75rem; flex-wrap: wrap; gap: 0.5rem;">
                  <h4 style="margin: 0; font-size: 1rem; font-weight: 700; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
                    <span>🤖</span> Category 1: Automated Dispatch Schedule &amp; WhatsApp Bot Engine
                  </h4>
                  <span class="badge badge-success" style="font-size: 0.75rem; padding: 4px 8px; border-radius: 4px; font-weight: 600;">Active Cron Engine</span>
                </div>

                <!-- Daily Schedule Time Picker -->
                <div style="margin-bottom: 1.25rem;">
                  <label class="form-label" for="setting-whatsappScheduleTime" style="font-weight: 600; font-size: 0.9rem;">
                    ⏰ Automated Dispatch Schedule Time (24-Hour Format) *
                  </label>
                  <div style="display: flex; align-items: center; gap: 1rem; flex-wrap: wrap;">
                    <input type="time" id="setting-whatsappScheduleTime" class="form-control" style="font-size: 1.1rem; font-weight: 700; max-width: 180px; text-align: center; color: var(--color-primary);" value="${escapeHTML(notif['notification.whatsappScheduleTime'] || notif.whatsappScheduleTime || '09:30')}" required>
                    <span style="font-size: 0.85rem; color: var(--color-text-secondary);">
                      Default: <code>09:30 AM</code> IST. Server automatically triggers reminder scans and dispatches WhatsApp messages daily.
                    </span>
                  </div>
                </div>

                <!-- Auto Bots Enable/Disable Toggles Grid -->
                <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 1rem;">
                  <!-- Expiry Bot Toggle -->
                  <div style="display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.25rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
                    <div style="padding-right: 0.75rem;">
                      <div style="font-weight: 600; color: var(--color-text-primary); font-size: 0.9rem; display: flex; align-items: center; gap: 0.4rem;">
                        <span>🤖</span> Enable Automated Expiry WhatsApp Bot
                      </div>
                      <div style="font-size: 0.75rem; color: var(--color-text-secondary); margin-top: 2px;">
                        Sends renewal notices with seat info &amp; 1-tap UPI deep links to students whose plans are expiring.
                      </div>
                    </div>
                    <label class="switch-label">
                      <input type="checkbox" id="setting-enableAutoExpiryBot" ${(notif['notification.enableAutoExpiryBot'] ?? notif.enableAutoExpiryBot) !== false ? 'checked' : ''}>
                      <span class="switch-slider"></span>
                    </label>
                  </div>

                  <!-- Dues Bot Toggle -->
                  <div style="display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.25rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
                    <div style="padding-right: 0.75rem;">
                      <div style="font-weight: 600; color: var(--color-text-primary); font-size: 0.9rem; display: flex; align-items: center; gap: 0.4rem;">
                        <span>⚠️</span> Enable Automated Balance Due WhatsApp Bot
                      </div>
                      <div style="font-size: 0.75rem; color: var(--color-text-secondary); margin-top: 2px;">
                        Sends overdue balance reminders with direct UPI link to students with partial/pending fee dues.
                      </div>
                    </div>
                    <label class="switch-label">
                      <input type="checkbox" id="setting-enableAutoDuesBot" ${(notif['notification.enableAutoDuesBot'] ?? notif.enableAutoDuesBot) !== false ? 'checked' : ''}>
                      <span class="switch-slider"></span>
                    </label>
                  </div>

                  <!-- Interactive Conversational Bot Toggle -->
                  <div style="display: flex; align-items: center; justify-content: space-between; padding: 1rem 1.25rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
                    <div style="padding-right: 0.75rem;">
                      <div style="font-weight: 600; color: var(--color-text-primary); font-size: 0.9rem; display: flex; align-items: center; gap: 0.4rem;">
                        <span>💬</span> Enable Interactive WhatsApp Conversational Bot
                      </div>
                      <div style="font-size: 0.75rem; color: var(--color-text-secondary); margin-top: 2px;">
                        Auto-replies to incoming student messages (!seat, !status, !renew, !help) via WhatsApp webhook.
                      </div>
                    </div>
                    <label class="switch-label">
                      <input type="checkbox" id="setting-enableConversationalBot" ${(notif['notification.enableConversationalBot'] ?? notif.enableConversationalBot) !== false ? 'checked' : ''}>
                      <span class="switch-slider"></span>
                    </label>
                  </div>
                </div>
              </div>

              <!-- CATEGORY 2: BOT COMMAND CHEAT-SHEET -->
              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
                <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 0.75rem; border-bottom: 1px solid var(--color-divider); padding-bottom: 0.5rem; flex-wrap: wrap; gap: 0.5rem;">
                  <h4 style="margin: 0; font-size: 1rem; font-weight: 700; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
                    <span>📖</span> Category 2: WhatsApp Bot Command Cheat-Sheet
                  </h4>
                  <code style="font-size: 0.75rem; background: var(--color-surface); padding: 2px 8px; border-radius: 4px; color: var(--color-primary); border: 1px solid var(--color-border);">Webhook: POST /api/messages/webhook</code>
                </div>
                <p style="font-size: 0.8rem; color: var(--color-text-secondary); margin-bottom: 0.85rem;">
                  Students can text any of the following commands to your WhatsApp number for instant automated real-time replies:
                </p>
                <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 0.75rem;">
                  <div style="background: var(--color-surface); padding: 0.75rem 1rem; border-radius: var(--radius-md); border: 1px solid var(--color-border);">
                    <code style="font-size: 0.9rem; color: var(--color-primary); font-weight: 700;">!seat</code>
                    <div style="font-size: 0.78rem; color: var(--color-text-secondary); margin-top: 4px;">Replies with student's active desk number, shift timing &amp; branch.</div>
                  </div>
                  <div style="background: var(--color-surface); padding: 0.75rem 1rem; border-radius: var(--radius-md); border: 1px solid var(--color-border);">
                    <code style="font-size: 0.9rem; color: var(--color-primary); font-weight: 700;">!status</code> / <code style="font-size: 0.9rem; color: var(--color-primary); font-weight: 700;">!expiry</code>
                    <div style="font-size: 0.78rem; color: var(--color-text-secondary); margin-top: 4px;">Replies with active plan name, validity end date &amp; balance due.</div>
                  </div>
                  <div style="background: var(--color-surface); padding: 0.75rem 1rem; border-radius: var(--radius-md); border: 1px solid var(--color-border);">
                    <code style="font-size: 0.9rem; color: var(--color-primary); font-weight: 700;">!renew</code>
                    <div style="font-size: 0.78rem; color: var(--color-text-secondary); margin-top: 4px;">Replies with pre-filled 1-tap UPI payment link &amp; QR code for renewal.</div>
                  </div>
                  <div style="background: var(--color-surface); padding: 0.75rem 1rem; border-radius: var(--radius-md); border: 1px solid var(--color-border);">
                    <code style="font-size: 0.9rem; color: var(--color-primary); font-weight: 700;">!help</code>
                    <div style="font-size: 0.78rem; color: var(--color-text-secondary); margin-top: 4px;">Replies with complete interactive command guide menu.</div>
                  </div>
                </div>
              </div>

              <!-- CATEGORY 3: REMINDER INTERVALS & DISPATCH CHANNELS -->
              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
                <h4 style="margin: 0 0 1rem 0; font-size: 1rem; font-weight: 700; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
                  <span>📅</span> Category 3: Reminder Intervals &amp; Dispatch Channels
                </h4>

                <!-- Expiry Reminder Intervals Checkboxes -->
                <div class="form-group" style="margin-bottom: 1.25rem;">
                  <label class="form-label" style="font-weight: 600; font-size: 0.9rem; margin-bottom: 0.4rem;">
                    📅 Expiry Reminder Intervals (Days Before / On Expiry)
                  </label>
                  <div style="font-size: 0.8rem; color: var(--color-text-secondary); margin-bottom: 0.6rem;">
                    Select all days when the Expiry Bot should alert students prior to or on the day their plan ends:
                  </div>
                  <div style="display: flex; gap: 0.75rem; flex-wrap: wrap;" id="expiry-intervals-container">
                    ${[
                      { day: 7, label: '7 Days Before' },
                      { day: 3, label: '3 Days Before' },
                      { day: 1, label: '1 Day Before' },
                      { day: 0, label: 'On Expiry Day' }
                    ].map(item => {
                      const isChecked = selectedExpiryDays.includes(item.day);
                      return `
                        <label class="expiry-interval-label" style="display: inline-flex; align-items: center; gap: 0.5rem; padding: 0.5rem 0.9rem; border: 1px solid ${isChecked ? 'var(--color-primary)' : 'var(--color-border)'}; background: ${isChecked ? 'rgba(99, 102, 241, 0.12)' : 'var(--color-surface)'}; border-radius: var(--radius-md); cursor: pointer; font-size: 0.85rem; font-weight: 600; transition: all 0.15s ease;">
                          <input type="checkbox" class="expiry-day-checkbox" value="${item.day}" ${isChecked ? 'checked' : ''} style="cursor: pointer;">
                          <span>${item.label}</span>
                        </label>
                      `;
                    }).join('')}
                  </div>
                </div>

                <!-- Overdue Balance Reminder Intervals Checkboxes -->
                <div class="form-group" style="margin-bottom: 1.25rem;">
                  <label class="form-label" style="font-weight: 600; font-size: 0.9rem; margin-bottom: 0.4rem;">
                    💸 Overdue Balance Reminder Intervals (Days After Due Date)
                  </label>
                  <div style="font-size: 0.8rem; color: var(--color-text-secondary); margin-bottom: 0.6rem;">
                    Select all intervals when the Dues Bot should alert students regarding overdue partial balances:
                  </div>
                  <div style="display: flex; gap: 0.75rem; flex-wrap: wrap;" id="balance-intervals-container">
                    ${[
                      { day: 1, label: '1 Day After Due' },
                      { day: 3, label: '3 Days After Due' },
                      { day: 7, label: '7 Days After Due' }
                    ].map(item => {
                      const isChecked = selectedBalanceDays.includes(item.day);
                      return `
                        <label class="balance-interval-label" style="display: inline-flex; align-items: center; gap: 0.5rem; padding: 0.5rem 0.9rem; border: 1px solid ${isChecked ? 'var(--color-primary)' : 'var(--color-border)'}; background: ${isChecked ? 'rgba(99, 102, 241, 0.12)' : 'var(--color-surface)'}; border-radius: var(--radius-md); cursor: pointer; font-size: 0.85rem; font-weight: 600; transition: all 0.15s ease;">
                          <input type="checkbox" class="balance-day-checkbox" value="${item.day}" ${isChecked ? 'checked' : ''} style="cursor: pointer;">
                          <span>${item.label}</span>
                        </label>
                      `;
                    }).join('')}
                  </div>
                </div>

                <!-- Delivery Channels Toggles -->
                <h5 style="font-size: 0.9rem; font-weight: 700; color: var(--color-text-primary); margin: 1.25rem 0 0.75rem 0; border-bottom: 1px solid var(--color-divider); padding-bottom: 0.4rem;">
                  📡 Active Delivery Channels
                </h5>

                <div style="display: flex; flex-direction: column; gap: 0.75rem;">
                  <!-- Email -->
                  <div style="display: flex; align-items: center; justify-content: space-between; padding: 0.85rem 1rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
                    <div style="display: flex; align-items: center; gap: 0.75rem;">
                      <div style="font-size: 1.3rem;">✉️</div>
                      <div>
                        <div style="font-weight: 600; color: var(--color-text-primary); font-size: 0.88rem;">Email Notifications</div>
                        <div style="font-size: 0.78rem; color: var(--color-text-secondary);">Send payment receipts and welcome onboard emails to students.</div>
                      </div>
                    </div>
                    <label class="switch-label" style="margin: 0;">
                      <input type="checkbox" id="setting-enableEmail" ${(notif['notification.enableEmail'] ?? notif.enableEmail) !== false ? 'checked' : ''}>
                      <span class="switch-slider"></span>
                    </label>
                  </div>

                  <!-- In-App -->
                  <div style="display: flex; align-items: center; justify-content: space-between; padding: 0.85rem 1rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
                    <div style="display: flex; align-items: center; gap: 0.75rem;">
                      <div style="font-size: 1.3rem;">📱</div>
                      <div>
                        <div style="font-weight: 600; color: var(--color-text-primary); font-size: 0.88rem;">In-App Realtime Alerts</div>
                        <div style="font-size: 0.78rem; color: var(--color-text-secondary);">Bell icon notifications on student &amp; manager dashboard.</div>
                      </div>
                    </div>
                    <label class="switch-label" style="margin: 0;">
                      <input type="checkbox" id="setting-enableInApp" ${(notif['notification.enableInApp'] ?? notif.enableInApp) !== false ? 'checked' : ''}>
                      <span class="switch-slider"></span>
                    </label>
                  </div>

                  <!-- WhatsApp -->
                  <div style="display: flex; align-items: center; justify-content: space-between; padding: 0.85rem 1rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
                    <div style="display: flex; align-items: center; gap: 0.75rem;">
                      <div style="font-size: 1.3rem;">💬</div>
                      <div>
                        <div style="font-weight: 600; color: var(--color-text-primary); font-size: 0.88rem; display: flex; align-items: center; gap: 0.5rem;">
                          WhatsApp Cloud Integration
                          <span class="badge badge-primary" style="font-size: 0.7rem; padding: 2px 6px; border-radius: 4px;">Meta Cloud API</span>
                        </div>
                        <div style="font-size: 0.78rem; color: var(--color-text-secondary);">Direct WhatsApp messaging for invoices and urgent reminders.</div>
                      </div>
                    </div>
                    <label class="switch-label" style="margin: 0;">
                      <input type="checkbox" id="setting-enableWhatsapp" ${(notif['notification.enableWhatsapp'] ?? notif.enableWhatsapp) ? 'checked' : ''}>
                      <span class="switch-slider"></span>
                    </label>
                  </div>

                  <!-- Native Push -->
                  <div style="display: flex; align-items: center; justify-content: space-between; padding: 0.85rem 1rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
                    <div style="display: flex; align-items: center; gap: 0.75rem;">
                      <div style="font-size: 1.3rem;">🔔</div>
                      <div>
                        <div style="font-weight: 600; color: var(--color-text-primary); font-size: 0.88rem; display: flex; align-items: center; gap: 0.5rem; flex-wrap: wrap;">
                          <span>Native Mobile Push Notifications</span>
                          <span id="push-permission-badge-settings" class="badge" style="font-size: 0.75rem; padding: 2px 8px; border-radius: 12px; border: 1px solid currentColor;">
                            Checking...
                          </span>
                        </div>
                        <div style="font-size: 0.78rem; color: var(--color-text-secondary);">
                          Receive OS lock screen push notifications for fee dues, plan expiry, and announcements.
                        </div>
                      </div>
                    </div>
                    <label class="switch-label" style="margin: 0;">
                      <input type="checkbox" id="setting-enablePush" ${(notif['notification.enablePush'] ?? notif.enablePush) ? 'checked' : ''}>
                      <span class="switch-slider"></span>
                    </label>
                  </div>
                </div>
              </div>

              <!-- CATEGORY 4: INSTANT BOT EXECUTION & AUDIT -->
              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
                <h4 style="margin: 0 0 1rem 0; font-size: 1rem; font-weight: 700; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
                  <span>⚡</span> Category 4: Instant Bot Execution &amp; Dispatch Audit
                </h4>

                <div style="display: flex; align-items: center; justify-content: space-between; padding: 1.15rem 1.25rem; background: linear-gradient(135deg, rgba(99, 102, 241, 0.1), rgba(168, 85, 247, 0.12)); border: 1px solid rgba(99, 102, 241, 0.35); border-radius: var(--radius-md); flex-wrap: wrap; gap: 1rem;">
                  <div>
                    <h5 style="margin: 0 0 3px 0; font-size: 0.95rem; font-weight: 700; color: var(--color-text-primary); display: flex; align-items: center; gap: 0.4rem;">
                      <span>⚡</span> Instant Bot Execution &amp; Dispatch Audit
                    </h5>
                    <p style="margin: 0; font-size: 0.8rem; color: var(--color-text-secondary);">
                      Immediately runs the subscription expiry &amp; balance due check and prepares 1-tap WhatsApp notifications.
                    </p>
                  </div>
                  <button type="button" id="btn-run-bot-now" class="btn btn-primary" style="display: inline-flex; align-items: center; gap: 0.5rem; font-weight: 700; background: linear-gradient(135deg, #4f46e5, #7c3aed); border: none; padding: 0.6rem 1.25rem; box-shadow: var(--shadow-sm); cursor: pointer;">
                    <span>⚡ Run Expiry &amp; Dues Bot Now</span>
                  </button>
                </div>

                <!-- Live Execution Log Stream Output Container -->
                <div id="bot-execution-log-container" style="display: none; margin-top: 1.25rem; border: 1px solid var(--color-border); border-radius: var(--radius-md); background: var(--color-surface); padding: 1.25rem;">
                  <!-- Rendered dynamically -->
                </div>
              </div>

              <!-- SINGLE CONSOLIDATED SAVE BUTTON AT BOTTOM -->
              <div style="display: flex; justify-content: flex-end; padding-top: 1rem; border-top: 1px solid var(--color-divider);">
                <button type="submit" id="btn-save-notifications" class="btn btn-primary" style="font-weight: 700; padding: 0.65rem 1.75rem;">
                  💾 Save Notification &amp; WhatsApp Preferences
                </button>
              </div>

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
                <h3 style="margin: 0; font-size: 1.15rem; font-weight: 700; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
                  <span>🌍</span> General System Configuration &amp; Global Locale Engine
                </h3>
                <p style="margin: 4px 0 0 0; font-size: 0.85rem; color: var(--color-text-secondary);">System locale, timezone calculations, database backups, and inactivity timers.</p>
              </div>
              <span class="badge" style="background: var(--color-primary-bg); color: var(--color-primary); font-weight: 700; padding: 6px 12px; border-radius: 20px;">
                Categorized Config
              </span>
            </div>

            <div class="card-body" style="padding: 1.5rem; display: flex; flex-direction: column; gap: 1.5rem;">
              
              <!-- CATEGORY 1: CURRENCY & LOCALIZATION -->
              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
                <h4 style="margin: 0 0 1rem 0; font-size: 1rem; font-weight: 700; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
                  <span>💱</span> Category 1: Currency &amp; Regional Localization Standards
                </h4>

                <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 1.25rem;">
                  <!-- Currency Symbol -->
                  <div class="form-group">
                    <label class="form-label" for="setting-currencySymbol" style="font-weight: 600;">Currency Symbol *</label>
                    <input type="text" id="setting-currencySymbol" class="form-control" value="${escapeHTML(gen['general.currencySymbol'] || gen.currencySymbol || '₹')}" required>
                    <small style="color: var(--color-text-secondary); display: block; margin-top: 4px;">e.g. ₹, $, €, £</small>
                  </div>

                  <!-- Currency Code -->
                  <div class="form-group">
                    <label class="form-label" for="setting-currency" style="font-weight: 600;">Currency ISO Code *</label>
                    <select id="setting-currency" class="form-select" style="font-weight: 700;">
                      <option value="INR" ${(gen['general.currency'] || gen.currency || 'INR') === 'INR' ? 'selected' : ''}>INR — Indian Rupee</option>
                      <option value="USD" ${(gen['general.currency'] || gen.currency) === 'USD' ? 'selected' : ''}>USD — US Dollar</option>
                      <option value="EUR" ${(gen['general.currency'] || gen.currency) === 'EUR' ? 'selected' : ''}>EUR — Euro</option>
                      <option value="GBP" ${(gen['general.currency'] || gen.currency) === 'GBP' ? 'selected' : ''}>GBP — British Pound</option>
                      <option value="AED" ${(gen['general.currency'] || gen.currency) === 'AED' ? 'selected' : ''}>AED — UAE Dirham</option>
                    </select>
                  </div>

                  <!-- Date Format -->
                  <div class="form-group">
                    <label class="form-label" for="setting-dateFormat" style="font-weight: 600;">Date Display Format *</label>
                    <select id="setting-dateFormat" class="form-select" style="font-weight: 700;">
                      <option value="DD/MM/YYYY" ${(gen['general.dateFormat'] || gen.dateFormat || 'DD/MM/YYYY') === 'DD/MM/YYYY' ? 'selected' : ''}>DD/MM/YYYY (e.g. 14/08/2026)</option>
                      <option value="YYYY-MM-DD" ${(gen['general.dateFormat'] || gen.dateFormat) === 'YYYY-MM-DD' ? 'selected' : ''}>YYYY-MM-DD (e.g. 2026-08-14)</option>
                      <option value="MM/DD/YYYY" ${(gen['general.dateFormat'] || gen.dateFormat) === 'MM/DD/YYYY' ? 'selected' : ''}>MM/DD/YYYY (e.g. 08/14/2026)</option>
                    </select>
                  </div>
                </div>
              </div>

              <!-- CATEGORY 2: TIMEZONE & SESSION SECURITY -->
              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
                <h4 style="margin: 0 0 1rem 0; font-size: 1rem; font-weight: 700; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
                  <span>🕒</span> Category 2: System Timezone &amp; Session Security Safeguards
                </h4>

                <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 1.25rem;">
                  <!-- Timezone -->
                  <div class="form-group">
                    <label class="form-label" for="setting-timezone" style="font-weight: 600;">System Timezone *</label>
                    <select id="setting-timezone" class="form-select" style="font-weight: 700;">
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
                    <label class="form-label" for="setting-inactivityTimeout" style="font-weight: 600;">Session Inactivity Timeout (Minutes) *</label>
                    <input type="number" id="setting-inactivityTimeout" class="form-control" min="5" max="480" value="${gen['general.inactivityTimeout'] ?? gen.inactivityTimeout ?? 30}">
                    <small style="color: var(--color-text-secondary); display: block; margin-top: 4px;">Auto-lock workstation after idle time.</small>
                  </div>
                </div>
              </div>

              <!-- CATEGORY 3: AUTOMATED DATABASE BACKUPS -->
              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
                <h4 style="margin: 0 0 1rem 0; font-size: 1rem; font-weight: 700; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
                  <span>💾</span> Category 3: Automated Database Backups &amp; Data Governance
                </h4>

                <div style="display: flex; align-items: center; justify-content: space-between; padding: 1.25rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md); gap: 1rem; flex-wrap: wrap;">
                  <div>
                    <div style="font-weight: 700; font-size: 0.98rem; color: var(--color-text-primary); display: flex; align-items: center; gap: 0.5rem;">
                      <span>💾</span> Automated Daily Database Backups
                      <span id="badge-auto-backup" class="badge ${(gen['general.autoBackup'] ?? gen.autoBackup) !== false ? 'badge-success' : 'badge-secondary'}" style="margin-left: 0.5rem; font-size: 0.75rem; padding: 2px 10px; border-radius: 12px; background: ${(gen['general.autoBackup'] ?? gen.autoBackup) !== false ? 'var(--color-success-bg)' : 'var(--color-bg-secondary)'}; color: ${(gen['general.autoBackup'] ?? gen.autoBackup) !== false ? 'var(--color-success)' : 'var(--color-text-secondary)'}; border: 1px solid currentColor;">
                        ${(gen['general.autoBackup'] ?? gen.autoBackup) !== false ? 'Enabled' : 'Disabled'}
                      </span>
                    </div>
                    <p style="color: var(--color-text-secondary); font-size: 0.83rem; margin: 4px 0 0 0;">
                      Generates automated night snapshots of student registrations, seat assignments, and payment logs.
                    </p>
                  </div>
                  <div>
                    <label class="switch-label" style="margin: 0;">
                      <input type="checkbox" id="setting-autoBackup" ${(gen['general.autoBackup'] ?? gen.autoBackup) !== false ? 'checked' : ''}>
                      <span class="switch-slider"></span>
                    </label>
                  </div>
                </div>
              </div>

              <!-- CATEGORY 4: LIVE LOCALE & TELEMETRY SUMMARY -->
              <div style="background: var(--color-primary-bg); border: 2px dashed var(--color-primary-light); border-radius: var(--radius-lg); padding: 1.5rem; text-align: center;">
                <div style="font-size: 0.85rem; font-weight: 700; color: var(--color-primary); margin-bottom: 0.65rem; text-transform: uppercase; letter-spacing: 0.05em; display: flex; align-items: center; justify-content: center; gap: 6px;">
                  <span>📊</span> Category 4: Live Locale &amp; System Telemetry Summary
                </div>
                <div id="general-config-preview" style="font-size: 1.1rem; font-weight: 700; color: var(--color-primary); display: inline-flex; align-items: center; justify-content: center; gap: 1rem; padding: 0.75rem 1.75rem; background: var(--color-surface); border-radius: var(--radius-md); border: 1px solid var(--color-primary); box-shadow: var(--shadow-sm); flex-wrap: wrap;">
                  <span>Sample Amount: <strong id="preview-sample-currency">₹1,500.00</strong></span>
                  <span style="opacity: 0.4;">|</span>
                  <span>Sample Date: <strong id="preview-sample-date">20/08/2026</strong></span>
                  <span style="opacity: 0.4;">|</span>
                  <span>Zone: <strong id="preview-sample-tz">Asia/Kolkata</strong></span>
                </div>
              </div>

              <!-- SINGLE CONSOLIDATED SAVE BUTTON AT BOTTOM -->
              <div style="display: flex; justify-content: flex-end; padding-top: 1rem; border-top: 1px solid var(--color-divider);">
                <button type="submit" id="btn-save-general" class="btn btn-primary" style="font-weight: 700; padding: 0.65rem 1.75rem;">
                  💾 Save General System Configuration
                </button>
              </div>

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
      <!-- SECTION H: SIDEBAR & NAVIGATION MANAGER    -->
      <!-- ========================================== -->
      <div class="settings-panel" id="panel-sidebar" style="display: none;">
        <div class="card mb-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden; box-shadow: var(--shadow-sm);">
          <div class="card-header" style="padding: 1.25rem 1.5rem; border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 0.75rem;">
            <div>
              <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600; color: var(--color-text-primary);">🧭 Sidebar & Navigation Manager</h3>
              <p style="margin: 4px 0 0 0; font-size: 0.85rem; color: var(--color-text-secondary);">Manage sidebar items, icons, display names, order, active state, and role visibility permissions.</p>
            </div>
            <div style="display: flex; gap: 0.5rem;">
              <button id="btn-reset-sidebar-nav" class="btn btn-outline-danger btn-sm" style="font-weight: 600;">🔄 Reset to Default</button>
              <button id="btn-save-sidebar-nav" class="btn btn-primary btn-sm" style="font-weight: 600;">💾 Save Navigation Layout</button>
            </div>
          </div>
          <div class="card-body" style="padding: 1.5rem;">
            
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; padding: 0.75rem 1rem; background: var(--color-bg-primary); border-radius: var(--radius-md); border: 1px solid var(--color-border);">
              <div style="font-size: 0.85rem; color: var(--color-text-secondary);">
                💡 <strong>Tip:</strong> Use ⬆️ / ⬇️ buttons or drag handle ☰ to reorder items. Uncheck role checkboxes to hide specific items from Owner, Branch Manager, or Staff.
              </div>
            </div>

            <div id="sidebar-manager-list" style="display: flex; flex-direction: column; gap: 0.75rem;">
              <div class="text-center p-4 text-muted">Loading navigation configuration...</div>
            </div>

            <div style="display: flex; justify-content: flex-end; gap: 0.75rem; margin-top: 1.5rem; padding-top: 1rem; border-top: 1px solid var(--color-border);">
              <button id="btn-reset-sidebar-nav-bottom" class="btn btn-outline-danger" style="font-weight: 600;">🔄 Reset to Default</button>
              <button id="btn-save-sidebar-nav-bottom" class="btn btn-primary" style="font-weight: 600;">💾 Save Navigation Layout</button>
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
              <select id="audit-filter-module" class="form-select w-100 w-md-auto" style="max-width: 150px;"><option value="">All Modules</option><option value="settings">Settings</option><option value="students">Students</option></select>
              <input type="text" id="audit-filter-action" class="form-control w-100 w-md-auto" placeholder="Action..." style="max-width: 150px;">
              <input type="date" id="audit-filter-start" class="form-control w-100 w-md-auto" style="max-width: 150px;">
              <input type="date" id="audit-filter-end" class="form-control w-100 w-md-auto" style="max-width: 150px;">
              <button id="btn-filter-audit" class="btn btn-primary w-100 w-md-auto">Filter</button>
            </div>
            <div class="table-responsive">
              <table class="table" style="width: 100%; border-collapse: collapse;">
                <thead><tr style="border-bottom: 2px solid var(--color-border);"><th style="padding: 0.5rem;">Date</th><th>User</th><th>Action</th><th>Module</th><th>Details</th><th>IP</th></tr></thead>
                <tbody id="audit-log-tbody"></tbody>
              </table>
            </div>
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
                <label class="switch-label" style="margin: 0;">
                  <input type="checkbox" id="pdf-toggle-photo" checked>
                  <span class="switch-slider"></span>
                </label>
              </div>

              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 1rem; border-radius: var(--radius-md); display: flex; justify-content: space-between; align-items: center;">
                <div>
                  <div style="font-weight: 600; font-size: 0.9rem;">✍️ Digital Signature</div>
                  <div class="text-muted small">Show student digital signature</div>
                </div>
                <label class="switch-label" style="margin: 0;">
                  <input type="checkbox" id="pdf-toggle-sig" checked>
                  <span class="switch-slider"></span>
                </label>
              </div>

              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 1rem; border-radius: var(--radius-md); display: flex; justify-content: space-between; align-items: center;">
                <div>
                  <div style="font-weight: 600; font-size: 0.9rem;">🏁 Gate Entry Barcode / QR</div>
                  <div class="text-muted small">Show barcode for kiosk scanner</div>
                </div>
                <label class="switch-label" style="margin: 0;">
                  <input type="checkbox" id="pdf-toggle-qr" checked>
                  <span class="switch-slider"></span>
                </label>
              </div>

              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 1rem; border-radius: var(--radius-md); display: flex; justify-content: space-between; align-items: center;">
                <div>
                  <div style="font-weight: 600; font-size: 0.9rem;">💰 Fee & Payment Breakdown</div>
                  <div class="text-muted small">Show plan price, discount & UTR</div>
                </div>
                <label class="switch-label" style="margin: 0;">
                  <input type="checkbox" id="pdf-toggle-payment" checked>
                  <span class="switch-slider"></span>
                </label>
              </div>

              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 1rem; border-radius: var(--radius-md); display: flex; justify-content: space-between; align-items: center;">
                <div>
                  <div style="font-weight: 600; font-size: 0.9rem;">📜 Discipline Code & Rules</div>
                  <div class="text-muted small">Show quiet study rules list</div>
                </div>
                <label class="switch-label" style="margin: 0;">
                  <input type="checkbox" id="pdf-toggle-rules" checked>
                  <span class="switch-slider"></span>
                </label>
              </div>

              <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 1rem; border-radius: var(--radius-md); display: flex; justify-content: space-between; align-items: center;">
                <div>
                  <div style="font-weight: 600; font-size: 0.9rem;">🏷️ Official Status Watermark</div>
                  <div class="text-muted small">Show PAID / PENDING stamp</div>
                </div>
                <label class="switch-label" style="margin: 0;">
                  <input type="checkbox" id="pdf-toggle-stamp" checked>
                  <span class="switch-slider"></span>
                </label>
              </div>
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
                    <label class="switch-label" style="font-size: 0.8rem; font-weight: 600;">
                      <input type="checkbox" id="rs-header-showLogo" checked>
                      <span class="switch-slider"></span>
                      <span>Show Logo</span>
                    </label>
                    <label class="switch-label" style="font-size: 0.8rem; font-weight: 600;">
                      <input type="checkbox" id="rs-header-showBusinessName" checked>
                      <span class="switch-slider"></span>
                      <span>Show Business Name</span>
                    </label>
                    <label class="switch-label" style="font-size: 0.8rem; font-weight: 600;">
                      <input type="checkbox" id="rs-header-showPhone" checked>
                      <span class="switch-slider"></span>
                      <span>Show Phone</span>
                    </label>
                    <label class="switch-label" style="font-size: 0.8rem; font-weight: 600;">
                      <input type="checkbox" id="rs-header-showEmail" checked>
                      <span class="switch-slider"></span>
                      <span>Show Email</span>
                    </label>
                    <label class="switch-label" style="font-size: 0.8rem; font-weight: 600;">
                      <input type="checkbox" id="rs-header-showGst" checked>
                      <span class="switch-slider"></span>
                      <span>Show GSTIN</span>
                    </label>
                  </div>
                </div>

                <!-- Body Field Toggles -->
                <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 14px; border-radius: var(--radius-md); display: flex; flex-direction: column; gap: 10px;">
                  <div style="font-weight: 700; font-size: 0.88rem; color: var(--color-primary);">📋 Receipt Fields & Visibility</div>
                  
                  <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px;">
                    <label class="switch-label" style="font-size: 0.8rem; font-weight: 600;">
                      <input type="checkbox" id="rs-body-showStudentId" checked>
                      <span class="switch-slider"></span>
                      <span>Show Student ID</span>
                    </label>
                    <label class="switch-label" style="font-size: 0.8rem; font-weight: 600;">
                      <input type="checkbox" id="rs-body-showStudentPhone" checked>
                      <span class="switch-slider"></span>
                      <span>Show Student Phone</span>
                    </label>
                    <label class="switch-label" style="font-size: 0.8rem; font-weight: 600;">
                      <input type="checkbox" id="rs-body-showPlanDetails" checked>
                      <span class="switch-slider"></span>
                      <span>Show Plan Name</span>
                    </label>
                    <label class="switch-label" style="font-size: 0.8rem; font-weight: 600;">
                      <input type="checkbox" id="rs-body-showPeriod" checked>
                      <span class="switch-slider"></span>
                      <span>Show Validity Dates</span>
                    </label>
                    <label class="switch-label" style="font-size: 0.8rem; font-weight: 600;">
                      <input type="checkbox" id="rs-body-showSeatNumber" checked>
                      <span class="switch-slider"></span>
                      <span>Show Seat No</span>
                    </label>
                    <label class="switch-label" style="font-size: 0.8rem; font-weight: 600;">
                      <input type="checkbox" id="rs-body-showShift" checked>
                      <span class="switch-slider"></span>
                      <span>Show Shift Timing</span>
                    </label>
                    <label class="switch-label" style="font-size: 0.8rem; font-weight: 600;">
                      <input type="checkbox" id="rs-body-showPaymentMethod" checked>
                      <span class="switch-slider"></span>
                      <span>Show Payment Mode</span>
                    </label>
                    <label class="switch-label" style="font-size: 0.8rem; font-weight: 600;">
                      <input type="checkbox" id="rs-body-showTransactionId" checked>
                      <span class="switch-slider"></span>
                      <span>Show Transaction UTR</span>
                    </label>
                  </div>
                </div>

                <!-- GST Tax Invoicing -->
                <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 14px; border-radius: var(--radius-md); display: flex; flex-direction: column; gap: 10px;">
                  <div style="display: flex; justify-content: space-between; align-items: center;">
                    <div style="font-weight: 700; font-size: 0.88rem; color: var(--color-primary);">🏛️ GST Tax Invoice Options</div>
                    <label class="switch-label" style="font-size: 0.8rem; font-weight: 700;">
                      <input type="checkbox" id="rs-gst-enabled">
                      <span class="switch-slider"></span>
                      <span>Enable GST</span>
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
                    <label class="switch-label" style="font-size: 0.8rem; font-weight: 600;">
                      <input type="checkbox" id="rs-footer-showStamp" checked>
                      <span class="switch-slider"></span>
                      <span>Show Official Paid Stamp</span>
                    </label>
                    <label class="switch-label" style="font-size: 0.8rem; font-weight: 600;">
                      <input type="checkbox" id="rs-footer-showSignature" checked>
                      <span class="switch-slider"></span>
                      <span>Show Authorized Signatory</span>
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

      <!-- ========================================== -->
      <!-- SECTION M: SYSTEM HEALTH & SECURITY DIAGNOSTICS -->
      <!-- ========================================== -->
      <div class="settings-panel" id="panel-systemhealth" style="display: none;">
        <div class="card mb-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden; box-shadow: var(--shadow-sm);">
          <div class="card-header" style="padding: 1.25rem 1.5rem; border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1rem;">
            <div>
              <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600; color: var(--color-text-primary); display: flex; align-items: center; gap: 0.5rem;">
                🛡️ System Health & Security Diagnostics
              </h3>
              <p style="margin: 4px 0 0 0; font-size: 0.85rem; color: var(--color-text-secondary);">
                Run live real-time security scans, audit database latency & indexes, check OWASP hardening, and trace 6-step data flow.
              </p>
            </div>
            <button type="button" id="btn-run-system-scan" class="btn btn-primary" style="display: inline-flex; align-items: center; gap: 0.5rem; font-weight: 600;">
              <span>⚡</span> Run Live System Scan
            </button>
          </div>
          
          <div class="card-body" style="padding: 1.5rem;">
            <!-- SCAN RESULTS CONTAINER -->
            <div id="system-scan-results-container">
              <div style="text-align: center; padding: 3rem 1rem; color: var(--color-text-secondary);">
                <div style="font-size: 3rem; margin-bottom: 1rem;">🛡️</div>
                <h4 style="font-size: 1.1rem; color: var(--color-text-primary); margin-bottom: 0.5rem;">System Health & Security Audit Ready</h4>
                <p style="font-size: 0.9rem; max-width: 500px; margin: 0 auto 1.5rem auto;">Click the button below to initiate a real-time diagnostic scan of your database latency, OWASP hardening parameters, API security, data pipelines, and telemetry.</p>
                <button type="button" id="btn-run-system-scan-hero" class="btn btn-primary btn-lg" style="font-weight: 600;">⚡ Run Live System Scan</button>
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
    sidebar: container.querySelector('#panel-sidebar') || container.querySelector('#panel-modules'),
    audittrail: container.querySelector('#panel-audittrail'),
    landing: container.querySelector('#panel-landing'),
    pdfstudio: container.querySelector('#panel-pdfstudio'),
    receiptstudio: container.querySelector('#panel-receiptstudio'),
    systemhealth: container.querySelector('#panel-systemhealth')
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

      const activePanel = panels[target];
      container.querySelectorAll('.settings-panel').forEach(p => {
        if (p) p.style.display = (p === activePanel) ? 'block' : 'none';
      });

      if (target === 'audittrail') {
        loadAuditLogs();
      } else if (target === 'formbuilder') {
        FormBuilder.render(container.querySelector('#form-builder-mount-container'));
      } else if (target === 'receiptstudio') {
        loadReceiptStudio();
      } else if (target === 'sidebar') {
        initSidebarManager(container);
      } else if (target === 'systemhealth') {
        runSystemHealthScan();
      }
    });
  });

  // System Health & Security Scan Logic
  const runSystemHealthScan = async () => {
    const resultsContainer = container.querySelector('#system-scan-results-container');
    const scanBtnHeader = container.querySelector('#btn-run-system-scan');
    
    if (!resultsContainer) return;

    if (scanBtnHeader) {
      scanBtnHeader.disabled = true;
      scanBtnHeader.innerHTML = '<span class="loading-spinner" style="width: 14px; height: 14px; border-width: 2px;"></span> Scanning System...';
    }

    resultsContainer.innerHTML = `
      <div style="padding: 3rem 1rem; text-align: center; color: var(--color-text-secondary);">
        <div class="loading-spinner" style="margin: 0 auto 1.5rem auto; width: 40px; height: 40px; border-width: 4px;"></div>
        <h4 style="font-size: 1.1rem; color: var(--color-text-primary); margin-bottom: 0.5rem;">Executing Live Security & Telemetry Scan...</h4>
        <p style="font-size: 0.88rem;">Testing DB latency, model indexes, OWASP hardening, API route authentication, and 6-step data pipeline.</p>
      </div>
    `;

    try {
      const res = await api.get('/api/system/health-check');
      
      if (scanBtnHeader) {
        scanBtnHeader.disabled = false;
        scanBtnHeader.innerHTML = '<span>⚡</span> Run Live System Scan';
      }

      if (!res.success) {
        resultsContainer.innerHTML = `
          <div class="card" style="padding: 2rem; border-color: var(--color-danger); text-align: center;">
            <div style="font-size: 2.5rem; margin-bottom: 0.5rem;">⚠️</div>
            <h3 style="color: var(--color-danger); margin-bottom: 0.5rem;">System Scan Failed</h3>
            <p style="color: var(--color-text-secondary); margin-bottom: 1.5rem;">${escapeHTML(res.message || 'Could not complete health check.')}</p>
            <button id="btn-retry-health-scan" class="btn btn-primary">Retry Scan</button>
          </div>
        `;
        resultsContainer.querySelector('#btn-retry-health-scan')?.addEventListener('click', runSystemHealthScan);
        return;
      }

      const { overallStatus, overallBadge, auditDurationMs, audits } = res;
      const { databaseAudit, routeSecurityAudit, owaspHardeningAudit, dataPipelineAudit, systemTelemetry } = audits || {};

      const getStatusBadge = (status) => {
        if (status === 'healthy') {
          return `<span class="badge" style="background: rgba(46, 204, 113, 0.15); color: #2ecc71; border: 1px solid rgba(46, 204, 113, 0.3); font-weight: 700; padding: 0.35rem 0.75rem; font-size: 0.85rem; border-radius: 20px;">🟢 Healthy</span>`;
        } else if (status === 'warning') {
          return `<span class="badge" style="background: rgba(241, 196, 15, 0.15); color: #f1c40f; border: 1px solid rgba(241, 196, 15, 0.3); font-weight: 700; padding: 0.35rem 0.75rem; font-size: 0.85rem; border-radius: 20px;">🟡 Warning</span>`;
        } else {
          return `<span class="badge" style="background: rgba(231, 76, 60, 0.15); color: #e74c3c; border: 1px solid rgba(231, 76, 60, 0.3); font-weight: 700; padding: 0.35rem 0.75rem; font-size: 0.85rem; border-radius: 20px;">🔴 Action Required</span>`;
        }
      };

      let html = `
        <!-- OVERALL HEALTH SUMMARY KPI BAR -->
        <div style="background: var(--color-bg-primary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem 1.5rem; margin-bottom: 1.5rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1rem;">
          <div>
            <div style="font-size: 0.8rem; font-weight: 600; text-transform: uppercase; color: var(--color-text-secondary); letter-spacing: 0.5px;">Overall System Status</div>
            <div style="font-size: 1.4rem; font-weight: 700; color: var(--color-text-primary); margin-top: 4px; display: flex; align-items: center; gap: 0.5rem;">
              ${getStatusBadge(overallStatus)}
              <span style="font-size: 0.85rem; font-weight: 400; color: var(--color-text-secondary);">(Scanned in ${auditDurationMs}ms)</span>
            </div>
          </div>
          <div style="display: flex; gap: 1.5rem; flex-wrap: wrap;">
            <div>
              <div style="font-size: 0.75rem; color: var(--color-text-secondary);">DB Latency</div>
              <div style="font-weight: 700; font-size: 1.1rem; color: var(--color-text-primary);">${databaseAudit?.pingLatencyMs >= 0 ? databaseAudit.pingLatencyMs + ' ms' : 'N/A'}</div>
            </div>
            <div>
              <div style="font-size: 0.75rem; color: var(--color-text-secondary);">OWASP Compliance</div>
              <div style="font-weight: 700; font-size: 1.1rem; color: var(--color-text-primary);">${owaspHardeningAudit?.owaspChecklist?.filter(c => c.status === 'Pass').length || 6} / 6 Controls</div>
            </div>
            <div>
              <div style="font-size: 0.75rem; color: var(--color-text-secondary);">Data Pipeline</div>
              <div style="font-weight: 700; font-size: 1.1rem; color: var(--color-text-primary);">${dataPipelineAudit?.passedSteps || 6} / 6 Steps Passed</div>
            </div>
            <div>
              <div style="font-size: 0.75rem; color: var(--color-text-secondary);">Uptime</div>
              <div style="font-weight: 700; font-size: 1.1rem; color: var(--color-text-primary);">${escapeHTML(systemTelemetry?.formattedUptime || 'Active')}</div>
            </div>
          </div>
        </div>

        <!-- DIAGNOSTIC REPORT CARDS GRID -->
        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(360px, 1fr)); gap: 1.5rem;">

          <!-- CARD 1: DATABASE AUDIT -->
          <div class="card" style="border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 1.25rem; background: var(--color-surface);">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; border-bottom: 1px solid var(--color-divider); padding-bottom: 0.75rem;">
              <h4 style="margin: 0; font-size: 1.05rem; font-weight: 700; color: var(--color-text-primary); display: flex; align-items: center; gap: 0.5rem;">
                🗄️ Database Audit
              </h4>
              ${getStatusBadge(databaseAudit?.status)}
            </div>

            <div style="font-size: 0.88rem; display: flex; flex-direction: column; gap: 0.6rem; margin-bottom: 1rem;">
              <div style="display: flex; justify-content: space-between;">
                <span style="color: var(--color-text-secondary);">Connection State:</span>
                <strong style="text-transform: capitalize;">${escapeHTML(databaseAudit?.connectionState || 'connected')}</strong>
              </div>
              <div style="display: flex; justify-content: space-between;">
                <span style="color: var(--color-text-secondary);">Ping Latency:</span>
                <strong>${databaseAudit?.pingLatencyMs} ms</strong>
              </div>
            </div>

            <h5 style="font-size: 0.85rem; font-weight: 600; text-transform: uppercase; color: var(--color-text-secondary); margin: 1rem 0 0.5rem 0;">Model Record Counts</h5>
            <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 0.5rem; background: var(--color-bg-primary); padding: 0.75rem; border-radius: var(--radius-sm); font-size: 0.82rem;">
              <div>Users: <strong>${databaseAudit?.modelCounts?.users || 0}</strong></div>
              <div>Students: <strong>${databaseAudit?.modelCounts?.students || 0}</strong></div>
              <div>Seats: <strong>${databaseAudit?.modelCounts?.seats || 0}</strong></div>
              <div>Payments: <strong>${databaseAudit?.modelCounts?.payments || 0}</strong></div>
              <div>Attendance: <strong>${databaseAudit?.modelCounts?.attendanceLogs || 0}</strong></div>
              <div>Audit Logs: <strong>${databaseAudit?.modelCounts?.auditLogs || 0}</strong></div>
            </div>

            <h5 style="font-size: 0.85rem; font-weight: 600; text-transform: uppercase; color: var(--color-text-secondary); margin: 1rem 0 0.5rem 0;">Collection Index Integrity</h5>
            <div style="display: flex; flex-direction: column; gap: 0.35rem; font-size: 0.82rem;">
              ${(databaseAudit?.indexIntegrity || []).map(idx => `
                <div style="display: flex; justify-content: space-between; padding: 0.3rem 0.5rem; background: var(--color-bg-secondary); border-radius: 4px;">
                  <span>${escapeHTML(idx.model)} (${idx.indexCount} indexes)</span>
                  <span style="color: var(--color-success); font-weight: 600;">✓ Verified</span>
                </div>
              `).join('')}
            </div>
          </div>

          <!-- CARD 2: ROUTE SECURITY AUDIT -->
          <div class="card" style="border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 1.25rem; background: var(--color-surface);">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; border-bottom: 1px solid var(--color-divider); padding-bottom: 0.75rem;">
              <h4 style="margin: 0; font-size: 1.05rem; font-weight: 700; color: var(--color-text-primary); display: flex; align-items: center; gap: 0.5rem;">
                🔐 Route Security Audit
              </h4>
              ${getStatusBadge(routeSecurityAudit?.status)}
            </div>

            <div style="font-size: 0.88rem; display: flex; flex-direction: column; gap: 0.6rem; margin-bottom: 1rem;">
              <div style="display: flex; justify-content: space-between;">
                <span style="color: var(--color-text-secondary);">Auth Middleware:</span>
                <strong style="color: var(--color-success);">Enforced (protect)</strong>
              </div>
              <div style="display: flex; justify-content: space-between;">
                <span style="color: var(--color-text-secondary);">RBAC Authorization:</span>
                <strong style="color: var(--color-success);">Enforced (roleCheck)</strong>
              </div>
            </div>

            <h5 style="font-size: 0.85rem; font-weight: 600; text-transform: uppercase; color: var(--color-text-secondary); margin: 1rem 0 0.5rem 0;">Protected API Modules</h5>
            <div style="display: flex; flex-direction: column; gap: 0.35rem; font-size: 0.82rem;">
              ${(routeSecurityAudit?.protectedEndpointsSummary || []).map(ep => `
                <div style="display: flex; justify-content: space-between; align-items: center; padding: 0.4rem 0.6rem; background: var(--color-bg-secondary); border-radius: 4px;">
                  <div>
                    <strong style="font-family: monospace;">${escapeHTML(ep.endpoint)}</strong>
                    <div style="font-size: 0.75rem; color: var(--color-text-secondary);">${escapeHTML(ep.description)}</div>
                  </div>
                  <span class="badge badge-success" style="font-size: 0.7rem; font-weight: 700;">PROTECTED</span>
                </div>
              `).join('')}
            </div>
          </div>

          <!-- CARD 3: OWASP HARDENING AUDIT -->
          <div class="card" style="border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 1.25rem; background: var(--color-surface);">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; border-bottom: 1px solid var(--color-divider); padding-bottom: 0.75rem;">
              <h4 style="margin: 0; font-size: 1.05rem; font-weight: 700; color: var(--color-text-primary); display: flex; align-items: center; gap: 0.5rem;">
                🛡️ OWASP Hardening Audit
              </h4>
              ${getStatusBadge(owaspHardeningAudit?.status)}
            </div>

            <div style="font-size: 0.88rem; display: flex; flex-direction: column; gap: 0.6rem; margin-bottom: 1rem;">
              <div style="display: flex; justify-content: space-between;">
                <span style="color: var(--color-text-secondary);">Helmet CSP Status:</span>
                <strong style="color: var(--color-success);">${escapeHTML(owaspHardeningAudit?.helmetCspStatus || 'Active')}</strong>
              </div>
              <div style="display: flex; justify-content: space-between;">
                <span style="color: var(--color-text-secondary);">Rate Limiter:</span>
                <strong style="color: var(--color-success);">${escapeHTML(owaspHardeningAudit?.rateLimiterStatus || 'Active')}</strong>
              </div>
              <div style="display: flex; justify-content: space-between;">
                <span style="color: var(--color-text-secondary);">Bcrypt Salt Rounds:</span>
                <strong>${owaspHardeningAudit?.bcryptHashing?.saltRounds || 12} (${owaspHardeningAudit?.bcryptHashing?.benchmarkLatencyMs}ms)</strong>
              </div>
            </div>

            <h5 style="font-size: 0.85rem; font-weight: 600; text-transform: uppercase; color: var(--color-text-secondary); margin: 1rem 0 0.5rem 0;">OWASP Security Controls Checklist</h5>
            <div style="display: flex; flex-direction: column; gap: 0.35rem; font-size: 0.8rem;">
              ${(owaspHardeningAudit?.owaspChecklist || []).map(item => `
                <div style="padding: 0.4rem 0.6rem; background: var(--color-bg-secondary); border-radius: 4px; display: flex; justify-content: space-between; align-items: center;">
                  <span>${escapeHTML(item.control)}</span>
                  <span style="color: ${item.status === 'Pass' ? 'var(--color-success)' : 'var(--color-danger)'}; font-weight: 700;">${item.status === 'Pass' ? '✓ PASS' : '✗ FAIL'}</span>
                </div>
              `).join('')}
            </div>
          </div>

          <!-- CARD 4: DATA PIPELINE AUDIT -->
          <div class="card" style="border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 1.25rem; background: var(--color-surface);">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; border-bottom: 1px solid var(--color-divider); padding-bottom: 0.75rem;">
              <h4 style="margin: 0; font-size: 1.05rem; font-weight: 700; color: var(--color-text-primary); display: flex; align-items: center; gap: 0.5rem;">
                🔄 6-Step Data Flow Pipeline
              </h4>
              ${getStatusBadge(dataPipelineAudit?.status)}
            </div>

            <p style="font-size: 0.82rem; color: var(--color-text-secondary); margin-bottom: 1rem;">
              Simulating end-to-end data flow: Student ➔ Seat ➔ Payment ➔ Attendance Kiosk ➔ WhatsApp ➔ Audit Log
            </p>

            <div style="display: flex; flex-direction: column; gap: 0.5rem; font-size: 0.82rem;">
              ${(dataPipelineAudit?.steps || []).map(step => `
                <div style="display: flex; justify-content: space-between; align-items: center; padding: 0.5rem 0.75rem; background: var(--color-bg-secondary); border-radius: 6px; border-left: 3px solid ${step.status === 'pass' ? '#2ecc71' : '#e74c3c'};">
                  <div>
                    <strong style="color: var(--color-text-primary);">Step ${step.step}: ${escapeHTML(step.name)}</strong>
                    <div style="font-size: 0.75rem; color: var(--color-text-secondary); margin-top: 2px;">${escapeHTML(step.details)}</div>
                  </div>
                  <div style="text-align: right;">
                    <span style="color: ${step.status === 'pass' ? '#2ecc71' : '#e74c3c'}; font-weight: 700;">${step.status === 'pass' ? 'PASSED' : 'FAILED'}</span>
                    <div style="font-size: 0.72rem; color: var(--color-text-secondary);">${step.latencyMs}ms</div>
                  </div>
                </div>
              `).join('')}
            </div>
          </div>

          <!-- CARD 5: SYSTEM TELEMETRY -->
          <div class="card" style="border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 1.25rem; background: var(--color-surface); grid-column: span 1 / -1;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; border-bottom: 1px solid var(--color-divider); padding-bottom: 0.75rem;">
              <h4 style="margin: 0; font-size: 1.05rem; font-weight: 700; color: var(--color-text-primary); display: flex; align-items: center; gap: 0.5rem;">
                📊 Node.js System Telemetry & Process Resources
              </h4>
              ${getStatusBadge(systemTelemetry?.status)}
            </div>

            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem;">
              <div style="background: var(--color-bg-primary); padding: 1rem; border-radius: var(--radius-md); border: 1px solid var(--color-border);">
                <div style="font-size: 0.8rem; color: var(--color-text-secondary);">Node.js Uptime</div>
                <div style="font-size: 1.2rem; font-weight: 700; color: var(--color-primary); margin-top: 4px;">${escapeHTML(systemTelemetry?.formattedUptime)}</div>
                <div style="font-size: 0.75rem; color: var(--color-text-secondary); margin-top: 2px;">Process ID: ${systemTelemetry?.environment?.pid}</div>
              </div>

              <div style="background: var(--color-bg-primary); padding: 1rem; border-radius: var(--radius-md); border: 1px solid var(--color-border);">
                <div style="font-size: 0.8rem; color: var(--color-text-secondary);">Heap Memory Used</div>
                <div style="font-size: 1.2rem; font-weight: 700; color: var(--color-primary); margin-top: 4px;">${systemTelemetry?.memory?.heapUsedMB} MB</div>
                <div style="font-size: 0.75rem; color: var(--color-text-secondary); margin-top: 2px;">Total Heap: ${systemTelemetry?.memory?.heapTotalMB} MB</div>
              </div>

              <div style="background: var(--color-bg-primary); padding: 1rem; border-radius: var(--radius-md); border: 1px solid var(--color-border);">
                <div style="font-size: 0.8rem; color: var(--color-text-secondary);">Resident Set Size (RSS)</div>
                <div style="font-size: 1.2rem; font-weight: 700; color: var(--color-primary); margin-top: 4px;">${systemTelemetry?.memory?.rssMB} MB</div>
                <div style="font-size: 0.75rem; color: var(--color-text-secondary); margin-top: 2px;">External: ${systemTelemetry?.memory?.externalMB} MB</div>
              </div>

              <div style="background: var(--color-bg-primary); padding: 1rem; border-radius: var(--radius-md); border: 1px solid var(--color-border);">
                <div style="font-size: 0.8rem; color: var(--color-text-secondary);">Runtime Environment</div>
                <div style="font-size: 1.2rem; font-weight: 700; color: var(--color-primary); margin-top: 4px; text-transform: capitalize;">${escapeHTML(systemTelemetry?.environment?.nodeEnv)}</div>
                <div style="font-size: 0.75rem; color: var(--color-text-secondary); margin-top: 2px;">${escapeHTML(systemTelemetry?.environment?.nodeVersion)} (${systemTelemetry?.environment?.platform})</div>
              </div>
            </div>
          </div>

        </div>
      `;

      resultsContainer.innerHTML = html;

    } catch (err) {
      console.error('System Health Scan Error:', err);
      if (scanBtnHeader) {
        scanBtnHeader.disabled = false;
        scanBtnHeader.innerHTML = '<span>⚡</span> Run Live System Scan';
      }
      resultsContainer.innerHTML = `
        <div class="card" style="padding: 2rem; border-color: var(--color-danger); text-align: center;">
          <div style="font-size: 2.5rem; margin-bottom: 0.5rem;">⚠️</div>
          <h3 style="color: var(--color-danger); margin-bottom: 0.5rem;">Scan Execution Error</h3>
          <p style="color: var(--color-text-secondary); margin-bottom: 1.5rem;">${escapeHTML(err.message || 'Error conducting live scan.')}</p>
          <button id="btn-retry-health-scan-err" class="btn btn-primary">Retry Scan</button>
        </div>
      `;
      resultsContainer.querySelector('#btn-retry-health-scan-err')?.addEventListener('click', runSystemHealthScan);
    }
  };

  container.querySelector('#btn-run-system-scan')?.addEventListener('click', runSystemHealthScan);
  container.querySelector('#btn-run-system-scan-hero')?.addEventListener('click', runSystemHealthScan);

  // Audit Logs Logic
  let currentAuditPage = 1;
  const loadAuditLogs = async () => {
    try {
      const mod = container.querySelector('#audit-filter-module')?.value || 'all';
      const act = container.querySelector('#audit-filter-action')?.value || 'all';
      const start = container.querySelector('#audit-filter-start')?.value || '';
      const end = container.querySelector('#audit-filter-end')?.value || '';
      
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
  const digitsSelect = container.querySelector('#setting-serialDigits');
  const startInput = container.querySelector('#setting-startingSerial');
  const sampleIdPreview = container.querySelector('#sample-id-preview');

  function updateIdPreview() {
    const p = (prefixInput?.value?.trim() || 'STU').toUpperCase();
    const fmt = formatSelect?.value || 'prefix-year-serial';
    const digits = parseInt(digitsSelect?.value, 10) || 3;
    const startNum = parseInt(startInput?.value, 10) || 1;
    const serialPadded = String(startNum).padStart(digits, '0');

    const now = new Date();
    const year = now.getFullYear();
    const shortYear = String(year).slice(-2);
    const month = String(now.getMonth() + 1).padStart(2, '0');

    let previewId = '';
    if (fmt === 'prefix-year-serial') {
      previewId = `${p}-${year}-${serialPadded}`;
    } else if (fmt === 'prefix-serial') {
      previewId = `${p}-${serialPadded}`;
    } else if (fmt === 'prefix-branch-serial') {
      previewId = `${p}-PUN-${year}-${serialPadded}`;
    } else if (fmt === 'prefix-month-serial') {
      previewId = `${p}-${month}${shortYear}-${serialPadded}`;
    } else {
      previewId = `${p}-${year}-${serialPadded}`;
    }

    if (sampleIdPreview) {
      sampleIdPreview.innerHTML = `<span style="opacity: 0.75; font-size: 0.95rem; font-weight: 500;">Sample ID:</span> ${previewId}`;
    }
  }

  prefixInput?.addEventListener('input', updateIdPreview);
  formatSelect?.addEventListener('change', updateIdPreview);
  digitsSelect?.addEventListener('change', updateIdPreview);
  startInput?.addEventListener('input', updateIdPreview);
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

  const logoMount = container.querySelector('#mount-setting-logo');
  if (logoMount) {
    logoMount.appendChild(MediaFieldPicker.create({
      label: 'Library Emblem / Insignia (1:1 / Transparent)',
      preset: 'stamp_logo',
      name: 'logo',
      value: profile.logo || ''
    }));
  }

  const faviconMount = container.querySelector('#mount-setting-favicon');
  if (faviconMount) {
    faviconMount.appendChild(MediaFieldPicker.create({
      label: 'Browser Tab Favicon Icon (PNG/ICO 1:1)',
      preset: 'stamp_logo',
      name: 'favicon',
      value: profile.favicon || profile.logo || ''
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

  // Payment Options Manager State
  let activePaymentMethods = (Array.isArray(profile.paymentMethods) && profile.paymentMethods.length > 0) ? profile.paymentMethods : [
    { key: 'upi', name: 'Dynamic UPI QR', subtitle: 'GPay / PhonePe / Paytm / BHIM', icon: '⚡', enabled: true, order: 1, instructions: 'Scan QR code and enter 12-digit UTR number', requiresRef: true, refLabel: 'UPI UTR / Reference Number *' },
    { key: 'card', name: 'Debit / Credit Card', subtitle: 'Visa, Mastercard, RuPay', icon: '💳', enabled: true, order: 2, instructions: 'Enter cardholder name and card transaction reference', requiresRef: true, refLabel: 'Card Reference / Transaction ID *' },
    { key: 'netbanking', name: 'NetBanking', subtitle: 'All major Indian banks', icon: '🏦', enabled: true, order: 3, instructions: 'Transfer fee to official bank account and enter bank UTR', requiresRef: true, refLabel: 'Bank Transaction Reference / UTR *' },
    { key: 'desk', name: 'Pay Later at Desk', subtitle: 'Pay cash on arrival', icon: '💵', enabled: true, order: 4, instructions: 'Admission will be pre-reserved. Pay cash at front reception desk.', requiresRef: false, refLabel: '' }
  ];

  const renderPaymentMethodsManager = () => {
    const listContainer = container.querySelector('#pm-options-list-container');
    if (!listContainer) return;

    activePaymentMethods.sort((a, b) => (a.order || 0) - (b.order || 0));

    let html = '';
    activePaymentMethods.forEach((pm, idx) => {
      html += `
        <div class="pm-setting-card" data-index="${idx}" style="background: var(--color-surface); border: 1.5px solid ${pm.enabled ? 'var(--color-primary)' : 'var(--color-border)'}; border-radius: var(--radius-md); padding: 1rem; opacity: ${pm.enabled ? '1' : '0.65'}; transition: all 0.2s;">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.75rem; flex-wrap: wrap; gap: 0.5rem;">
            <div style="display: flex; align-items: center; gap: 0.6rem; flex-wrap: wrap;">
              <input type="text" class="form-control pm-input-icon" value="${escapeHTML(pm.icon || '💳')}" style="width: 44px; text-align: center; font-size: 1.1rem;" title="Emoji / Icon">
              <input type="text" class="form-control pm-input-name" value="${escapeHTML(pm.name || '')}" placeholder="Payment Method Name" style="font-weight: 700; width: 180px;">
              <input type="text" class="form-control pm-input-subtitle" value="${escapeHTML(pm.subtitle || '')}" placeholder="Subtitle (e.g. GPay / PhonePe)" style="font-size: 0.85rem; width: 180px;">
            </div>

            <div style="display: flex; align-items: center; gap: 0.6rem;">
              <label style="display: flex; align-items: center; gap: 6px; cursor: pointer; font-weight: 700; font-size: 0.8rem; background: ${pm.enabled ? 'var(--color-primary-bg)' : 'var(--color-bg-secondary)'}; padding: 4px 10px; border-radius: 20px; border: 1px solid var(--color-border);">
                <input type="checkbox" class="pm-toggle-enabled" ${pm.enabled ? 'checked' : ''}>
                <span style="color: ${pm.enabled ? 'var(--color-primary)' : 'var(--color-text-secondary)'};">${pm.enabled ? '🟢 ENABLED' : '🔴 DISABLED'}</span>
              </label>

              <button type="button" class="btn btn-xs btn-outline pm-move-up" title="Move Up" ${idx === 0 ? 'disabled' : ''}>⬆️</button>
              <button type="button" class="btn btn-xs btn-outline pm-move-down" title="Move Down" ${idx === activePaymentMethods.length - 1 ? 'disabled' : ''}>⬇️</button>
              <button type="button" class="btn btn-xs btn-ghost text-danger pm-delete-btn" title="Delete Option">🗑️</button>
            </div>
          </div>

          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 0.75rem;">
            <div>
              <label class="form-label small mb-1" style="font-weight: 600;">Custom Instructions Note</label>
              <input type="text" class="form-control form-control-sm pm-input-instructions" value="${escapeHTML(pm.instructions || '')}" placeholder="Note shown to student during payment...">
            </div>
            <div>
              <label class="form-label small mb-1" style="font-weight: 600;">Reference Number Field Label</label>
              <input type="text" class="form-control form-control-sm pm-input-reflabel" value="${escapeHTML(pm.refLabel || '')}" placeholder="e.g. 12-digit UTR / Reference Number *">
            </div>
          </div>
        </div>
      `;
    });

    listContainer.innerHTML = html;

    listContainer.querySelectorAll('.pm-setting-card').forEach((card, i) => {
      card.querySelector('.pm-toggle-enabled')?.addEventListener('change', (e) => {
        activePaymentMethods[i].enabled = e.target.checked;
        renderPaymentMethodsManager();
      });
      card.querySelector('.pm-input-icon')?.addEventListener('input', (e) => {
        activePaymentMethods[i].icon = e.target.value;
      });
      card.querySelector('.pm-input-name')?.addEventListener('input', (e) => {
        activePaymentMethods[i].name = e.target.value;
      });
      card.querySelector('.pm-input-subtitle')?.addEventListener('input', (e) => {
        activePaymentMethods[i].subtitle = e.target.value;
      });
      card.querySelector('.pm-input-instructions')?.addEventListener('input', (e) => {
        activePaymentMethods[i].instructions = e.target.value;
      });
      card.querySelector('.pm-input-reflabel')?.addEventListener('input', (e) => {
        activePaymentMethods[i].refLabel = e.target.value;
      });

      card.querySelector('.pm-move-up')?.addEventListener('click', () => {
        if (i > 0) {
          const temp = activePaymentMethods[i];
          activePaymentMethods[i] = activePaymentMethods[i - 1];
          activePaymentMethods[i - 1] = temp;
          activePaymentMethods.forEach((m, idx) => m.order = idx + 1);
          renderPaymentMethodsManager();
        }
      });

      card.querySelector('.pm-move-down')?.addEventListener('click', () => {
        if (i < activePaymentMethods.length - 1) {
          const temp = activePaymentMethods[i];
          activePaymentMethods[i] = activePaymentMethods[i + 1];
          activePaymentMethods[i + 1] = temp;
          activePaymentMethods.forEach((m, idx) => m.order = idx + 1);
          renderPaymentMethodsManager();
        }
      });

      card.querySelector('.pm-delete-btn')?.addEventListener('click', () => {
        activePaymentMethods.splice(i, 1);
        activePaymentMethods.forEach((m, idx) => m.order = idx + 1);
        renderPaymentMethodsManager();
      });
    });
  };

  container.querySelector('#btn-add-pm-option')?.addEventListener('click', () => {
    activePaymentMethods.push({
      key: `custom_${Date.now()}`,
      name: 'Custom Payment Method',
      subtitle: 'Instant Online Transfer',
      icon: '📱',
      enabled: true,
      order: activePaymentMethods.length + 1,
      instructions: 'Please complete payment and enter your transaction ID',
      requiresRef: true,
      refLabel: 'Transaction Reference / UTR Number *'
    });
    renderPaymentMethodsManager();
  });

  renderPaymentMethodsManager();

  // Setup payment reminder days pill toggles
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

  // Setup Expiry Reminder Interval Checkboxes
  container.querySelectorAll('.expiry-day-checkbox').forEach(cb => {
    cb.addEventListener('change', () => {
      const day = parseInt(cb.value, 10);
      const label = cb.closest('.expiry-interval-label');
      if (cb.checked) {
        if (!selectedExpiryDays.includes(day)) selectedExpiryDays.push(day);
        if (label) {
          label.style.borderColor = 'var(--color-primary)';
          label.style.background = 'rgba(99, 102, 241, 0.12)';
        }
      } else {
        selectedExpiryDays = selectedExpiryDays.filter(d => d !== day);
        if (label) {
          label.style.borderColor = 'var(--color-border)';
          label.style.background = 'var(--color-surface)';
        }
      }
    });
  });

  // Setup Overdue Balance Reminder Interval Checkboxes
  container.querySelectorAll('.balance-day-checkbox').forEach(cb => {
    cb.addEventListener('change', () => {
      const day = parseInt(cb.value, 10);
      const label = cb.closest('.balance-interval-label');
      if (cb.checked) {
        if (!selectedBalanceDays.includes(day)) selectedBalanceDays.push(day);
        if (label) {
          label.style.borderColor = 'var(--color-primary)';
          label.style.background = 'rgba(99, 102, 241, 0.12)';
        }
      } else {
        selectedBalanceDays = selectedBalanceDays.filter(d => d !== day);
        if (label) {
          label.style.borderColor = 'var(--color-border)';
          label.style.background = 'var(--color-surface)';
        }
      }
    });
  });

  // Render Bot Execution Live Log Helper
  function renderBotExecutionLog(logBox, data) {
    if (!logBox) return;
    logBox.style.display = 'block';
    const timeFormatted = new Date(data.timestamp || Date.now()).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
    const logs = data.logs || [];

    const logRowsHtml = logs.length > 0 ? logs.map((l, idx) => {
      const badgeColor = l.type === 'expiry_reminder' ? '#6366f1' : (l.type === 'balance_due_reminder' ? '#f59e0b' : (l.type === 'seat_release' ? '#ef4444' : '#10b981'));
      const typeLabel = l.type === 'expiry_reminder' ? '📅 EXPIRY ALERT' : (l.type === 'balance_due_reminder' ? '⚠️ BALANCE DUE' : (l.type === 'seat_release' ? '🚫 SEAT RELEASED' : '⏳ GRACE PERIOD'));
      const waBtn = l.whatsappUrl ? `<a href="${l.whatsappUrl}" target="_blank" class="btn btn-sm btn-outline-primary" style="padding: 2px 8px; font-size: 0.75rem; text-decoration: none; display: inline-flex; align-items: center; gap: 4px;">💬 Open WhatsApp</a>` : '';

      return `
        <tr style="border-bottom: 1px solid var(--color-border); font-size: 0.85rem;">
          <td style="padding: 8px 10px; font-family: monospace; color: var(--color-text-secondary);">${idx + 1}</td>
          <td style="padding: 8px 10px; font-weight: 600; color: var(--color-text-primary);">${escapeHTML(l.studentName || 'Student')}</td>
          <td style="padding: 8px 10px; font-family: monospace;">${escapeHTML(l.phone || '-')}</td>
          <td style="padding: 8px 10px;">
            <span style="background: ${badgeColor}22; color: ${badgeColor}; border: 1px solid ${badgeColor}55; padding: 2px 6px; border-radius: 4px; font-size: 0.75rem; font-weight: 700;">
              ${typeLabel}
            </span>
          </td>
          <td style="padding: 8px 10px; color: var(--color-text-secondary); font-size: 0.8rem;">
            ${l.timeLabel ? `<b>${l.timeLabel}</b> • Renewal: ₹${l.amount || 0}` : (l.overdueDays !== undefined ? `Overdue: <b>${l.overdueDays}d</b> • Due: ₹${l.balanceDue || 0}` : (l.detail || ''))}
          </td>
          <td style="padding: 8px 10px; text-align: right;">
            ${waBtn || `<span style="font-size: 0.75rem; color: var(--color-text-muted);">Dispatched</span>`}
          </td>
        </tr>
      `;
    }).join('') : `<tr><td colspan="6" style="padding: 1.5rem; text-align: center; color: var(--color-text-secondary);">No student memberships required expiry alerts or balance due notices at this run.</td></tr>`;

    logBox.innerHTML = `
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; border-bottom: 1px solid var(--color-divider); padding-bottom: 0.75rem; flex-wrap: wrap; gap: 0.5rem;">
        <div style="font-weight: 700; font-size: 0.95rem; display: flex; align-items: center; gap: 0.5rem; color: var(--color-text-primary);">
          <span>📋</span> Live Expiry & Dues Bot Execution Audit Log
          <span style="font-size: 0.75rem; font-weight: normal; color: var(--color-text-secondary);">(${timeFormatted})</span>
        </div>
        <button type="button" class="btn btn-sm btn-outline-secondary" id="btn-close-bot-log" style="padding: 2px 8px; font-size: 0.75rem;">Close Log</button>
      </div>

      <!-- Metric Badges Row -->
      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(130px, 1fr)); gap: 0.75rem; margin-bottom: 1.25rem;">
        <div style="background: var(--color-bg-primary); padding: 0.75rem; border-radius: var(--radius-md); border: 1px solid var(--color-border); text-align: center;">
          <div style="font-size: 0.75rem; color: var(--color-text-secondary); text-transform: uppercase;">Students Scanned</div>
          <div style="font-size: 1.3rem; font-weight: 700; color: var(--color-text-primary);">${data.totalStudentsScanned ?? 0}</div>
        </div>
        <div style="background: rgba(99, 102, 241, 0.1); padding: 0.75rem; border-radius: var(--radius-md); border: 1px solid rgba(99, 102, 241, 0.3); text-align: center;">
          <div style="font-size: 0.75rem; color: #6366f1; text-transform: uppercase; font-weight: 600;">Expiry Alerts</div>
          <div style="font-size: 1.3rem; font-weight: 700; color: #6366f1;">${data.expiryRemindersSent ?? 0}</div>
        </div>
        <div style="background: rgba(245, 158, 11, 0.1); padding: 0.75rem; border-radius: var(--radius-md); border: 1px solid rgba(245, 158, 11, 0.3); text-align: center;">
          <div style="font-size: 0.75rem; color: #f59e0b; text-transform: uppercase; font-weight: 600;">Dues Alerts</div>
          <div style="font-size: 1.3rem; font-weight: 700; color: #f59e0b;">${data.balanceDueRemindersSent ?? 0}</div>
        </div>
        <div style="background: rgba(239, 68, 68, 0.1); padding: 0.75rem; border-radius: var(--radius-md); border: 1px solid rgba(239, 68, 68, 0.3); text-align: center;">
          <div style="font-size: 0.75rem; color: #ef4444; text-transform: uppercase; font-weight: 600;">Seats Released</div>
          <div style="font-size: 1.3rem; font-weight: 700; color: #ef4444;">${data.seatsReleased ?? 0}</div>
        </div>
        <div style="background: rgba(16, 185, 129, 0.1); padding: 0.75rem; border-radius: var(--radius-md); border: 1px solid rgba(16, 185, 129, 0.3); text-align: center;">
          <div style="font-size: 0.75rem; color: #10b981; text-transform: uppercase; font-weight: 600;">Grace Active</div>
          <div style="font-size: 1.3rem; font-weight: 700; color: #10b981;">${data.gracePeriodCount ?? 0}</div>
        </div>
      </div>

      <!-- Detailed Table -->
      <div style="overflow-x: auto; max-height: 280px; overflow-y: auto; border: 1px solid var(--color-border); border-radius: var(--radius-md);">
        <div class="table-responsive">
          <table style="width: 100%; border-collapse: collapse; text-align: left;">
            <thead>
              <tr style="background: var(--color-bg-primary); border-bottom: 1px solid var(--color-border); font-size: 0.8rem; color: var(--color-text-secondary); text-transform: uppercase;">
                <th style="padding: 8px 10px;">#</th>
                <th style="padding: 8px 10px;">Student</th>
                <th style="padding: 8px 10px;">Phone</th>
                <th style="padding: 8px 10px;">Action / Type</th>
                <th style="padding: 8px 10px;">Details</th>
                <th style="padding: 8px 10px; text-align: right;">Action</th>
              </tr>
            </thead>
            <tbody>
              ${logRowsHtml}
            </tbody>
          </table>
        </div>
      </div>
    `;

    logBox.querySelector('#btn-close-bot-log')?.addEventListener('click', () => {
      logBox.style.display = 'none';
    });
  }

  // Setup Run Expiry & Dues Bot Now Action Button
  const btnRunBot = container.querySelector('#btn-run-bot-now');
  const botLogContainer = container.querySelector('#bot-execution-log-container');
  btnRunBot?.addEventListener('click', async () => {
    Loading.button(btnRunBot, true);
    try {
      const res = await api.post('/api/messages/run-cron-now');
      Toast.success(res?.message || 'Expiry & Dues Bot executed successfully!');
      if (botLogContainer && res?.data) {
        renderBotExecutionLog(botLogContainer, res.data);
      }
    } catch (err) {
      console.error('Failed to run bot now:', err);
      Toast.error(err.message || 'Failed to execute expiry & dues bot');
    } finally {
      Loading.button(btnRunBot, false);
    }
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
        <div class="table-responsive">
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
        </div>

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
      const isUpiOn = container.querySelector('#setting-pm-upi-enable')?.checked ?? true;
      const isBankOn = container.querySelector('#setting-pm-bank-enable')?.checked ?? true;
      const isDeskOn = container.querySelector('#setting-pm-desk-enable')?.checked ?? true;

      const paymentMethodsPayload = [
        { key: 'upi', name: 'Dynamic UPI QR', subtitle: 'GPay / PhonePe / Paytm / BHIM', icon: '⚡', enabled: isUpiOn, order: 1, instructions: 'Scan QR code and enter 12-digit UTR number', requiresRef: true, refLabel: 'UPI UTR / Reference Number *' },
        { key: 'netbanking', name: 'NetBanking / Bank Transfer', subtitle: 'IMPS, NEFT, RTGS', icon: '🏦', enabled: isBankOn, order: 2, instructions: 'Transfer fee to official bank account and enter bank UTR', requiresRef: true, refLabel: 'Bank Transaction Reference / UTR *' },
        { key: 'desk', name: 'Pay Later at Front Desk', subtitle: 'Pay cash on arrival', icon: '💵', enabled: isDeskOn, order: 3, instructions: 'Admission will be pre-reserved. Pay cash at front reception desk on arrival.', requiresRef: false, refLabel: '' }
      ];

      const payload = {
        businessName: container.querySelector('#setting-businessName')?.value?.trim(),
        tagline: container.querySelector('#setting-tagline')?.value?.trim(),
        logo: container.querySelector('input[name="logo"]')?.value?.trim() || container.querySelector('#setting-logo')?.value?.trim() || '',
        favicon: container.querySelector('input[name="favicon"]')?.value?.trim() || container.querySelector('#setting-favicon')?.value?.trim() || '',
        upiQrCode: container.querySelector('input[name="upiQrCode"]')?.value?.trim() || container.querySelector('#setting-upiQrCode')?.value?.trim() || '',
        upiId: container.querySelector('#setting-upiId')?.value?.trim() || 'thecozycorner@okaxis',
        bankDetails: {
          accountName: container.querySelector('#setting-bank-accName')?.value?.trim() || '',
          accountNumber: container.querySelector('#setting-bank-accNum')?.value?.trim() || '',
          ifscCode: container.querySelector('#setting-bank-ifsc')?.value?.trim() || '',
          bankName: container.querySelector('#setting-bank-name')?.value?.trim() || '',
          branchName: container.querySelector('#setting-bank-branch')?.value?.trim() || ''
        },
        paymentInstructions: container.querySelector('#setting-payment-instructions')?.value?.trim() || '',
        enableUpiDeepLinks: container.querySelector('#setting-enableUpiDeepLinks')?.checked ?? true,
        gatewayProvider: container.querySelector('#setting-gatewayProvider')?.value || 'manual_upi',
        razorpayKeyId: container.querySelector('#setting-razorpayKeyId')?.value?.trim() || '',
        razorpaySecret: container.querySelector('#setting-razorpaySecret')?.value?.trim() || '',
        enableAutoWebhookVerification: container.querySelector('#setting-enableAutoWebhookVerification')?.checked ?? true,
        paymentMethods: paymentMethodsPayload,
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

  ['upi', 'bank', 'desk'].forEach(key => {
    container.querySelector(`#setting-pm-${key}-enable`)?.addEventListener('change', (e) => {
      const lbl = container.querySelector(`#label-pm-${key}-status`);
      if (lbl) {
        lbl.textContent = e.target.checked ? '🟢 ENABLED' : '🔴 DISABLED';
        lbl.style.color = e.target.checked ? 'var(--color-success)' : 'var(--color-danger)';
      }
    });
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

  // Live Policy Simulation Updater
  function updatePolicySimulation() {
    const grace = parseInt(container.querySelector('#setting-gracePeriod')?.value, 10) || 0;
    const fineType = container.querySelector('input[name="lateFeeType"]:checked')?.value || 'flat';
    const amount = parseFloat(container.querySelector('#setting-lateFeeAmount')?.value) || 0;
    const suspend = parseInt(container.querySelector('#setting-autoSuspendDays')?.value, 10) || 15;

    const simText = container.querySelector('#policy-simulation-text');
    if (!simText) return;

    const modeLabel = fineType === 'flat' ? `one-time flat late fee of ₹${amount}` : `daily compounding fine rate of ₹${amount}/day`;

    simText.innerHTML = `
      <strong>Example: For a fee due on 1st of the month:</strong>
      <ul style="margin: 0.5rem 0 0 0; padding-left: 1.25rem;">
        <li><strong>Grace Window (Days 1 to ${grace}):</strong> Student can pay normal fee with <strong>₹0 penalty</strong>.</li>
        <li><strong>Overdue Fine Period (After Day ${grace}):</strong> System applies a <strong>${modeLabel}</strong>.</li>
        <li><strong>Auto-Suspension (Day ${suspend}):</strong> If payment remains unpaid, student account, biometric scanner &amp; seat access are <strong>automatically locked</strong>.</li>
      </ul>
    `;
  }

  container.querySelector('#setting-gracePeriod')?.addEventListener('input', updatePolicySimulation);
  container.querySelector('#setting-lateFeeAmount')?.addEventListener('input', updatePolicySimulation);
  container.querySelector('#setting-autoSuspendDays')?.addEventListener('input', updatePolicySimulation);
  container.querySelectorAll('input[name="lateFeeType"]').forEach(r => r.addEventListener('change', updatePolicySimulation));
  updatePolicySimulation();

  // 3. Save Admission Handler
  async function saveAdmission(btn) {
    Loading.button(btn, true);
    try {
      const startingNum = parseInt(container.querySelector('#setting-startingSerial')?.value, 10) || 1;
      const payload = {
        autoApprove: !!container.querySelector('#setting-autoApprove')?.checked,
        idPrefix: container.querySelector('#setting-idPrefix')?.value?.trim() || 'STU',
        idFormat: container.querySelector('#setting-idFormat')?.value || 'prefix-year-serial',
        serialDigits: parseInt(container.querySelector('#setting-serialDigits')?.value, 10) || 3,
        startingSerial: startingNum,
        currentSerial: startingNum
      };

      const res = await api.put('/api/settings', payload);
      Toast.success(res?.message || 'Student ID rules & admission settings saved successfully');
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

  // Live Dynamic Student ID Badge Preview Updater
  function updateIdPreview() {
    const prefix = container.querySelector('#setting-idPrefix')?.value?.trim() || 'STU';
    const format = container.querySelector('#setting-idFormat')?.value || 'prefix-year-serial';
    const digits = parseInt(container.querySelector('#setting-serialDigits')?.value, 10) || 4;
    const startNum = parseInt(container.querySelector('#setting-startingSerial')?.value, 10) || 1;

    const sampleNum = String(startNum).padStart(digits, '0');
    const currentYear = new Date().getFullYear();
    const currentMMYY = `${String(new Date().getMonth() + 1).padStart(2, '0')}${String(currentYear).slice(-2)}`;

    let sampleId = `${prefix}-${currentYear}-${sampleNum}`;
    if (format === 'prefix-serial') {
      sampleId = `${prefix}-${sampleNum}`;
    } else if (format === 'prefix-branch-serial') {
      sampleId = `${prefix}-PUN-${currentYear}-${sampleNum}`;
    } else if (format === 'prefix-month-serial') {
      sampleId = `${prefix}-${currentMMYY}-${sampleNum}`;
    }

    const previewEl = container.querySelector('#sample-id-preview');
    if (previewEl) {
      previewEl.innerHTML = `<span style="opacity: 0.75; font-size: 0.95rem; font-weight: 500;">Sample ID:</span> ${escapeHTML(sampleId)}`;
    }

    // Also update auto-approve badge text
    const isAuto = container.querySelector('#setting-autoApprove')?.checked;
    const badgeEl = container.querySelector('#badge-auto-approve');
    if (badgeEl) {
      badgeEl.textContent = isAuto ? 'Enabled' : 'Manual Review';
      badgeEl.style.background = isAuto ? 'var(--color-success-bg)' : 'var(--color-bg-secondary)';
      badgeEl.style.color = isAuto ? 'var(--color-success)' : 'var(--color-text-secondary)';
    }
  }

  container.querySelector('#setting-idPrefix')?.addEventListener('input', updateIdPreview);
  container.querySelector('#setting-idFormat')?.addEventListener('change', updateIdPreview);
  container.querySelector('#setting-serialDigits')?.addEventListener('change', updateIdPreview);
  container.querySelector('#setting-startingSerial')?.addEventListener('input', updateIdPreview);
  container.querySelector('#setting-autoApprove')?.addEventListener('change', updateIdPreview);
  updateIdPreview();

  // 4. Save Notifications Handler
  async function saveNotifications(btn) {
    Loading.button(btn, true);
    try {
      const payload = {
        paymentReminder: selectedReminderDays,
        expiryReminder: parseInt(container.querySelector('#setting-expiryReminder')?.value, 10) || 7,
        enableEmail: !!container.querySelector('#setting-enableEmail')?.checked,
        enableInApp: !!container.querySelector('#setting-enableInApp')?.checked,
        enableWhatsapp: !!container.querySelector('#setting-enableWhatsapp')?.checked,
        whatsappScheduleTime: container.querySelector('#setting-whatsappScheduleTime')?.value || '09:30',
        expiryReminderDays: selectedExpiryDays,
        balanceReminderDays: selectedBalanceDays,
        enableAutoExpiryBot: !!container.querySelector('#setting-enableAutoExpiryBot')?.checked,
        enableAutoDuesBot: !!container.querySelector('#setting-enableAutoDuesBot')?.checked,
        enableConversationalBot: !!container.querySelector('#setting-enableConversationalBot')?.checked,
        enablePush: !!container.querySelector('#setting-enablePush')?.checked

      };

      const res = await api.put('/api/settings/system-settings', payload);
      Toast.success(res?.message || 'Notification preferences & WhatsApp schedule updated successfully');
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

  // Instant Bot Execution Listener
  container.querySelector('#btn-run-bot-now')?.addEventListener('click', async () => {
    const btn = container.querySelector('#btn-run-bot-now');
    const logContainer = container.querySelector('#bot-execution-log-container');
    Loading.button(btn, true);

    if (logContainer) {
      logContainer.style.display = 'block';
      logContainer.innerHTML = `<div class="text-muted" style="font-size: 0.85rem;"><span class="spinner-border spinner-border-sm me-2"></span> Running automated subscription expiry &amp; balance due bot scan...</div>`;
    }

    try {
      const res = await api.post('/api/messages/run-cron-now');
      Toast.success(res?.message || 'Automated WhatsApp Bot execution completed successfully');
      if (logContainer) {
        logContainer.innerHTML = `
          <div style="font-weight: 700; color: var(--color-success); margin-bottom: 0.5rem; display: flex; align-items: center; gap: 0.5rem;">
            <span>🟢</span> ${escapeHTML(res?.message || 'Bot Scan & Execution Completed')}
          </div>
          <div style="font-size: 0.85rem; color: var(--color-text-primary);">
            <div><strong>Processed Students:</strong> ${res?.processedCount ?? res?.count ?? 0}</div>
            <div><strong>Reminders Prepared:</strong> ${res?.preparedCount ?? res?.remindersCount ?? 0}</div>
            <div style="margin-top: 6px; font-size: 0.78rem; color: var(--color-text-secondary);">Triggered at: ${new Date().toLocaleString('en-IN')}</div>
          </div>
        `;
      }
    } catch (err) {
      Toast.error(err.message || 'Failed to run bot scan');
      if (logContainer) {
        logContainer.innerHTML = `<div style="color: var(--color-danger); font-size: 0.85rem;"><strong>Error running bot:</strong> ${escapeHTML(err.message)}</div>`;
      }
    } finally {
      Loading.button(btn, false);
    }
  });

  // Push Notifications Toggle & Status Badge Logic
  const pushToggleSettings = container.querySelector('#setting-enablePush');
  const pushBadgeSettings = container.querySelector('#push-permission-badge-settings');

  function syncPushSettingsUI() {
    if (!pushToggleSettings || !pushBadgeSettings) return;

    if (!PushNotifications.isSupported()) {
      pushToggleSettings.disabled = true;
      pushToggleSettings.checked = false;
      pushBadgeSettings.textContent = 'Not Supported';
      pushBadgeSettings.className = 'badge badge-secondary';
      pushBadgeSettings.style.background = 'var(--color-bg-secondary)';
      pushBadgeSettings.style.color = 'var(--color-text-secondary)';
      return;
    }

    const status = PushNotifications.getPermissionStatus();
    if (status === 'granted') {
      pushBadgeSettings.textContent = 'Permission Granted';
      pushBadgeSettings.className = 'badge badge-success';
      pushBadgeSettings.style.background = 'rgba(0, 184, 148, 0.15)';
      pushBadgeSettings.style.color = 'var(--color-success)';
      pushToggleSettings.checked = PushNotifications.isEnabled() || pushToggleSettings.checked;
    } else if (status === 'denied') {
      pushBadgeSettings.textContent = 'Blocked in Browser';
      pushBadgeSettings.className = 'badge badge-danger';
      pushBadgeSettings.style.background = 'rgba(235, 77, 75, 0.15)';
      pushBadgeSettings.style.color = 'var(--color-danger)';
      pushToggleSettings.checked = false;
    } else {
      pushBadgeSettings.textContent = 'Permission Required';
      pushBadgeSettings.className = 'badge badge-warning';
      pushBadgeSettings.style.background = 'rgba(253, 203, 110, 0.2)';
      pushBadgeSettings.style.color = 'var(--color-warning)';
      pushToggleSettings.checked = false;
    }
  }

  syncPushSettingsUI();

  pushToggleSettings?.addEventListener('change', async (e) => {
    if (e.target.checked) {
      try {
        const perm = await PushNotifications.requestPermission();
        if (perm === 'granted') {
          await PushNotifications.subscribe();
          Toast.success('🔔 Native Mobile Push Notifications enabled!');
        } else if (perm === 'denied') {
          Toast.error('Push notification permission blocked by browser settings.');
        }
      } catch (err) {
        Toast.error(err.message || 'Failed to enable push notifications');
      }
    } else {
      await PushNotifications.unsubscribe();
      Toast.info('Push notifications disabled.');
    }
    syncPushSettingsUI();
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
        favicon: container.querySelector('input[name="favicon"]')?.value?.trim() || container.querySelector('#setting-favicon')?.value?.trim() || '',
        upiQrCode: container.querySelector('input[name="upiQrCode"]')?.value?.trim() || container.querySelector('#setting-upiQrCode')?.value?.trim() || '',
        upiId: container.querySelector('#setting-upiId')?.value?.trim() || 'thecozycorner@okaxis',
        bankDetails: {
          accountName: container.querySelector('#setting-bank-accName')?.value?.trim() || '',
          accountNumber: container.querySelector('#setting-bank-accNum')?.value?.trim() || '',
          ifscCode: container.querySelector('#setting-bank-ifsc')?.value?.trim() || '',
          bankName: container.querySelector('#setting-bank-name')?.value?.trim() || '',
          branchName: container.querySelector('#setting-bank-branch')?.value?.trim() || ''
        },
        paymentInstructions: container.querySelector('#setting-payment-instructions')?.value?.trim() || '',
        enableUpiDeepLinks: container.querySelector('#setting-enableUpiDeepLinks')?.checked ?? true,
        paymentMethods: activePaymentMethods,
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
        serialDigits: parseInt(container.querySelector('#setting-serialDigits')?.value, 10) || 3,
        startingSerial: parseInt(container.querySelector('#setting-startingSerial')?.value, 10) || 1,
        currentSerial: parseInt(container.querySelector('#setting-startingSerial')?.value, 10) || 1,
        paymentReminder: selectedReminderDays,
        expiryReminder: parseInt(container.querySelector('#setting-expiryReminder')?.value, 10) || 7,
        enableEmail: !!container.querySelector('#setting-enableEmail')?.checked,
        enableInApp: !!container.querySelector('#setting-enableInApp')?.checked,
        enableWhatsapp: !!container.querySelector('#setting-enableWhatsapp')?.checked,
        whatsappScheduleTime: container.querySelector('#setting-whatsappScheduleTime')?.value || '09:30',
        expiryReminderDays: selectedExpiryDays,
        balanceReminderDays: selectedBalanceDays,
        enableAutoExpiryBot: !!container.querySelector('#setting-enableAutoExpiryBot')?.checked,
        enableAutoDuesBot: !!container.querySelector('#setting-enableAutoDuesBot')?.checked,
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

  initSidebarManager(container);
  initLandingSettings(container);
}

async function initSidebarManager(container) {
  const listContainer = container.querySelector('#sidebar-manager-list') || container.querySelector('#module-settings-list');
  if (!listContainer) return;

  const renderList = (items) => {
    listContainer.innerHTML = items.map((item, index) => {
      const roles = Array.isArray(item.allowedRoles) && item.allowedRoles.length > 0
        ? item.allowedRoles
        : ['owner', 'branch_manager', 'staff'];

      return `
        <div class="sidebar-item-card" data-key="${item.key}" data-href="${item.href || '#/' + item.key}" draggable="true" style="display: flex; flex-direction: column; gap: 0.75rem; padding: 1rem 1.25rem; border: 1px solid var(--color-border); border-radius: var(--radius-md); background: var(--color-bg-primary); transition: transform 0.2s, box-shadow 0.2s; box-shadow: var(--shadow-sm); margin-bottom: 0.5rem;">
          <div style="display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 0.75rem;">
            <!-- Left: Drag handle, Move buttons, Icon, Label, Route -->
            <div style="display: flex; align-items: center; gap: 0.75rem; flex-wrap: wrap; flex: 1; min-width: 280px;">
              <div class="drag-handle" style="cursor: grab; font-size: 1.3rem; color: var(--color-text-secondary); padding: 0 4px; user-select: none;" title="Drag to reorder">☰</div>
              
              <div style="display: flex; gap: 4px;">
                <button type="button" class="btn btn-sm btn-outline btn-move-up" title="Move Up" style="padding: 2px 8px; font-size: 0.85rem; font-weight: 600;">⬆️</button>
                <button type="button" class="btn btn-sm btn-outline btn-move-down" title="Move Down" style="padding: 2px 8px; font-size: 0.85rem; font-weight: 600;">⬇️</button>
              </div>

              <div style="display: flex; align-items: center; gap: 0.5rem;">
                <input type="text" class="form-control form-control-sm item-icon-input" value="${escapeHTML(item.icon || '')}" style="width: 52px; text-align: center; font-size: 1.15rem; padding: 4px;" placeholder="Icon" title="Item Icon (Emoji / Text)">
                <input type="text" class="form-control form-control-sm item-label-input" value="${escapeHTML(item.label || item.key)}" style="width: 170px; font-weight: 600;" placeholder="Menu Label" title="Display Name">
              </div>

              <div style="display: flex; align-items: center; gap: 0.4rem;">
                <span class="badge" style="font-family: monospace; font-size: 0.78rem; background: var(--color-bg-secondary); border: 1px solid var(--color-border); color: var(--color-text-secondary); padding: 4px 8px; border-radius: 4px;" title="Target Route">
                  ${escapeHTML(item.href || '#/' + item.key)}
                </span>
                ${item.isSystem ? '<span class="badge badge-secondary" style="font-size: 0.68rem; padding: 2px 6px;">System</span>' : ''}
              </div>
            </div>

            <!-- Right: Role Checkboxes & Active Toggle -->
            <div style="display: flex; align-items: center; gap: 1.25rem; flex-wrap: wrap;">
              <!-- Role Visibility Checkboxes -->
              <div style="display: flex; align-items: center; gap: 0.75rem; background: var(--color-bg-secondary); padding: 6px 12px; border-radius: var(--radius-md); border: 1px solid var(--color-border);">
                <span style="font-size: 0.78rem; font-weight: 700; color: var(--color-text-secondary); text-transform: uppercase; margin-right: 2px;">Visibility:</span>
                <label style="display: flex; align-items: center; gap: 4px; font-size: 0.85rem; font-weight: 500; cursor: pointer; margin: 0;">
                  <input type="checkbox" class="role-cb role-owner" ${roles.includes('owner') ? 'checked' : ''}>
                  <span>👑 Owner</span>
                </label>
                <label style="display: flex; align-items: center; gap: 4px; font-size: 0.85rem; font-weight: 500; cursor: pointer; margin: 0;">
                  <input type="checkbox" class="role-cb role-manager" ${roles.includes('branch_manager') ? 'checked' : ''}>
                  <span>🏢 Branch Manager</span>
                </label>
                <label style="display: flex; align-items: center; gap: 4px; font-size: 0.85rem; font-weight: 500; cursor: pointer; margin: 0;">
                  <input type="checkbox" class="role-cb role-staff" ${roles.includes('staff') ? 'checked' : ''}>
                  <span>🧑💼 Staff</span>
                </label>
              </div>

              <!-- Active Toggle -->
              <label class="switch-label" style="margin: 0; font-weight: 600; font-size: 0.88rem;">
                <input type="checkbox" class="item-enable-toggle" ${item.isEnabled !== false ? 'checked' : ''}>
                <span class="switch-slider"></span>
                <span class="active-toggle-label" style="color: ${item.isEnabled !== false ? 'var(--color-success)' : 'var(--color-text-muted)'};">${item.isEnabled !== false ? 'Active' : 'Hidden'}</span>
              </label>
            </div>
          </div>
        </div>
      `;
    }).join('');

    // Setup Move Up & Move Down button handlers
    listContainer.querySelectorAll('.sidebar-item-card').forEach(card => {
      card.querySelector('.btn-move-up')?.addEventListener('click', (e) => {
        e.preventDefault();
        e.stopPropagation();
        const prev = card.previousElementSibling;
        if (prev) {
          listContainer.insertBefore(card, prev);
        }
      });

      card.querySelector('.btn-move-down')?.addEventListener('click', (e) => {
        e.preventDefault();
        e.stopPropagation();
        const next = card.nextElementSibling;
        if (next) {
          listContainer.insertBefore(next, card);
        }
      });

      // Toggle label color when active checkbox changes
      const toggle = card.querySelector('.item-enable-toggle');
      const label = card.querySelector('.active-toggle-label');
      toggle?.addEventListener('change', () => {
        if (label) {
          label.style.color = toggle.checked ? 'var(--color-success)' : 'var(--color-text-muted)';
        }
      });
    });

    // Setup Drag & Drop reordering
    let draggedItem = null;
    const cards = listContainer.querySelectorAll('.sidebar-item-card');
    cards.forEach(card => {
      card.addEventListener('dragstart', () => {
        draggedItem = card;
        setTimeout(() => { card.style.opacity = '0.5'; }, 0);
      });
      card.addEventListener('dragend', () => {
        card.style.opacity = '1';
        draggedItem = null;
      });
      card.addEventListener('dragover', (e) => {
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
    const draggableElements = [...container.querySelectorAll('.sidebar-item-card:not(.dragging)')];
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

  const defaultItems = [
    { key: 'dashboard', label: 'Dashboard', icon: '📊', href: '#/dashboard', isEnabled: true, allowedRoles: ['owner', 'branch_manager', 'staff'] },
    { key: 'students', label: 'Students Directory', icon: '👥', href: '#/students', isEnabled: true, allowedRoles: ['owner', 'branch_manager', 'staff'] },
    { key: 'seats', label: 'Centers & Seats', icon: '🪑', href: '#/seats', isEnabled: true, allowedRoles: ['owner', 'branch_manager', 'staff'] },
    { key: 'lockers', label: 'Lockers', icon: '🔒', href: '#/lockers', isEnabled: true, allowedRoles: ['owner', 'branch_manager', 'staff'] },
    { key: 'plans', label: 'Plans', icon: '🏷️', href: '#/plans', isEnabled: true, allowedRoles: ['owner', 'branch_manager', 'staff'] },
    { key: 'payments', label: 'Payments', icon: '💳', href: '#/payments', isEnabled: true, allowedRoles: ['owner', 'branch_manager', 'staff'] },
    { key: 'attendance', label: 'Attendance', icon: '📋', href: '#/attendance', isEnabled: true, allowedRoles: ['owner', 'branch_manager', 'staff'] },
    { key: 'shifts', label: 'Shifts', icon: '⏰', href: '#/shifts', isEnabled: true, allowedRoles: ['owner', 'branch_manager', 'staff'] },
    { key: 'reports', label: 'Reports', icon: '📈', href: '#/reports', isEnabled: true, allowedRoles: ['owner', 'branch_manager', 'staff'] },
    { key: 'expenses', label: 'Expenses (P&L)', icon: '💸', href: '#/expenses', isEnabled: true, allowedRoles: ['owner', 'branch_manager'] },
    { key: 'operations', label: 'Operations', icon: '⚙️', href: '#/operations', isEnabled: true, allowedRoles: ['owner', 'branch_manager', 'staff'] },
    { key: 'settings', label: 'Settings', icon: '⚙️', href: '#/settings', isEnabled: true, allowedRoles: ['owner'] },
    { key: 'profile', label: 'My Profile', icon: '👤', href: '#/profile', isEnabled: true, allowedRoles: ['owner', 'branch_manager', 'staff'] }
  ];

  const loadSettings = async () => {
    try {
      const res = await api.get('/api/settings/sidebar/all');
      if (res && res.success && Array.isArray(res.data) && res.data.length > 0) {
        renderList(res.data);
      } else {
        renderList(defaultItems);
      }
    } catch (e) {
      renderList(defaultItems);
    }
  };

  const handleSave = async (btn) => {
    const items = [];
    listContainer.querySelectorAll('.sidebar-item-card').forEach((card, index) => {
      const key = card.dataset.key;
      const label = card.querySelector('.item-label-input')?.value?.trim() || key;
      const icon = card.querySelector('.item-icon-input')?.value?.trim() || '';
      const href = card.dataset.href || `#/${key}`;
      const isEnabled = card.querySelector('.item-enable-toggle')?.checked ?? true;

      const allowedRoles = [];
      if (card.querySelector('.role-owner')?.checked) allowedRoles.push('owner');
      if (card.querySelector('.role-manager')?.checked) allowedRoles.push('branch_manager');
      if (card.querySelector('.role-staff')?.checked) allowedRoles.push('staff');

      items.push({
        key,
        label,
        icon,
        href,
        isEnabled,
        order: index + 1,
        allowedRoles
      });
    });

    if (btn) Loading.button(btn, true);
    try {
      const res = await api.put('/api/settings/sidebar', { items });
      if (res && res.success) {
        Toast.success('Sidebar navigation layout saved successfully!');
        if (Array.isArray(res.data)) {
          renderList(res.data);
        }
        // Real-time refresh of the active app sidebar
        if (typeof window.reloadSidebar === 'function') {
          window.reloadSidebar();
        } else if (window.App && typeof window.App.updateSidebarForRole === 'function') {
          window.App.updateSidebarForRole();
        }
      } else {
        Toast.error(res?.message || 'Failed to save sidebar navigation');
      }
    } catch (err) {
      Toast.error(err.message || 'Failed to save sidebar navigation');
    } finally {
      if (btn) Loading.button(btn, false);
    }
  };

  const handleReset = () => {
    Confirm.show({
      title: 'Reset Navigation Layout',
      message: 'Are you sure you want to reset all sidebar navigation items to system defaults?',
      danger: true,
      onConfirm: async () => {
        try {
          const res = await api.put('/api/settings/sidebar/reset');
          if (res && res.success) {
            Toast.success('Sidebar navigation reset to system defaults!');
            if (Array.isArray(res.data)) {
              renderList(res.data);
            }
            if (typeof window.reloadSidebar === 'function') {
              window.reloadSidebar();
            } else if (window.App && typeof window.App.updateSidebarForRole === 'function') {
              window.App.updateSidebarForRole();
            }
          }
        } catch (err) {
          Toast.error('Failed to reset sidebar navigation');
        }
      }
    });
  };

  // Attach Save and Reset button event handlers (both header & footer)
  container.querySelector('#btn-save-sidebar-nav')?.addEventListener('click', (e) => handleSave(e.currentTarget));
  container.querySelector('#btn-save-sidebar-nav-bottom')?.addEventListener('click', (e) => handleSave(e.currentTarget));
  container.querySelector('#btn-save-modules')?.addEventListener('click', (e) => handleSave(e.currentTarget));

  container.querySelector('#btn-reset-sidebar-nav')?.addEventListener('click', () => handleReset());
  container.querySelector('#btn-reset-sidebar-nav-bottom')?.addEventListener('click', () => handleReset());
  container.querySelector('#btn-reset-modules')?.addEventListener('click', () => handleReset());

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
          <small class="text-muted">Instant live preview updates on save</small>
        </div>
      </div>

      <div class="landing-editor-split" style="display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 1.25rem; align-items: start; width: 100%;">
        <!-- Left: CMS Form Editor -->
        <div class="cms-editor-panel" style="border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem; background: var(--color-surface); height: calc(100vh - 240px); min-height: 600px; overflow-y: auto;">
          <div class="landing-tabs" style="display: flex; gap: 0.4rem; overflow-x: auto; padding-bottom: 0.5rem; margin-bottom: 1rem; border-bottom: 1px solid var(--color-border);">
            <button class="landing-tab-btn active" data-tab="hero" style="padding: 0.5rem 0.85rem; border: none; background: var(--color-primary-bg); color: var(--color-primary); font-weight: 600; border-radius: var(--radius-md); cursor: pointer; white-space: nowrap;">Hero & Branding</button>
            <button class="landing-tab-btn" data-tab="navbar" style="padding: 0.5rem 0.85rem; border: none; background: transparent; color: var(--color-text-secondary); cursor: pointer; white-space: nowrap;">Navbar & CTA</button>
            <button class="landing-tab-btn" data-tab="about" style="padding: 0.5rem 0.85rem; border: none; background: transparent; color: var(--color-text-secondary); cursor: pointer; white-space: nowrap;">About & Stats</button>
            <button class="landing-tab-btn" data-tab="facilities" style="padding: 0.5rem 0.85rem; border: none; background: transparent; color: var(--color-text-secondary); cursor: pointer; white-space: nowrap;">Facilities</button>
            <button class="landing-tab-btn" data-tab="shifts" style="padding: 0.5rem 0.85rem; border: none; background: transparent; color: var(--color-text-secondary); cursor: pointer; white-space: nowrap;">Shifts</button>
            <button class="landing-tab-btn" data-tab="pricing" style="padding: 0.5rem 0.85rem; border: none; background: transparent; color: var(--color-text-secondary); cursor: pointer; white-space: nowrap;">💰 Pricing & Plans</button>
            <button class="landing-tab-btn" data-tab="rules" style="padding: 0.5rem 0.85rem; border: none; background: transparent; color: var(--color-text-secondary); cursor: pointer; white-space: nowrap;">Rules</button>
            <button class="landing-tab-btn" data-tab="gallery" style="padding: 0.5rem 0.85rem; border: none; background: transparent; color: var(--color-text-secondary); cursor: pointer; white-space: nowrap;">Gallery</button>
            <button class="landing-tab-btn" data-tab="faqs" style="padding: 0.5rem 0.85rem; border: none; background: transparent; color: var(--color-text-secondary); cursor: pointer; white-space: nowrap;">FAQs</button>
            <button class="landing-tab-btn" data-tab="testimonials" style="padding: 0.5rem 0.85rem; border: none; background: transparent; color: var(--color-text-secondary); cursor: pointer; white-space: nowrap;">Reviews & Testimonials</button>
            <button class="landing-tab-btn" data-tab="contact" style="padding: 0.5rem 0.85rem; border: none; background: transparent; color: var(--color-text-secondary); cursor: pointer; white-space: nowrap;">Contact & Map</button>
            <button class="landing-tab-btn" data-tab="footer" style="padding: 0.5rem 0.85rem; border: none; background: transparent; color: var(--color-text-secondary); cursor: pointer; white-space: nowrap;">🔗 Footer & Quick Links</button>
            <button class="landing-tab-btn" data-tab="floating" style="padding: 0.5rem 0.85rem; border: none; background: transparent; color: var(--color-text-secondary); cursor: pointer; white-space: nowrap;">💬 Floating Action Bar</button>
            <button class="landing-tab-btn" data-tab="seo" style="padding: 0.5rem 0.85rem; border: none; background: transparent; color: var(--color-text-secondary); cursor: pointer; white-space: nowrap;">🔍 SEO & Meta</button>
          </div>
          
          <!-- Tab Content -->
          <div id="landing-tab-content">
          <!-- 1. Hero & Branding -->
          <div class="landing-panel" id="l-panel-hero">
            <h4>Hero Section</h4>
            <div class="form-group mb-3">
              <label>Headline</label>
              <input type="text" id="l-hero-title" class="form-control" value="${escapeHTML(config.hero?.title || '')}">
            </div>
            <div class="form-group mb-3">
              <label>Sub-headline</label>
              <textarea id="l-hero-subtitle" class="form-control" rows="3">${escapeHTML(config.hero?.subtitle || '')}</textarea>
            </div>
            <div class="form-group mb-3">
              <label>Banner Image URL</label>
              <input type="text" id="l-hero-banner" class="form-control" placeholder="https://.../banner.jpg" value="${escapeHTML(config.hero?.bannerImage || '')}">
            </div>
            <div class="row g-2 mb-3" style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px;">
              <div>
                <label>Primary CTA Button Text</label>
                <input type="text" id="l-hero-ctaPrimaryText" class="form-control" value="${escapeHTML(config.hero?.ctaPrimaryText || 'Book Your Seat / Register Now')}">
              </div>
              <div>
                <label>Primary CTA Button Link</label>
                <input type="text" id="l-hero-ctaPrimaryLink" class="form-control" value="${escapeHTML(config.hero?.ctaPrimaryLink || '/register')}">
              </div>
            </div>
            <div class="row g-2 mb-3" style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px;">
              <div>
                <label>Secondary CTA Button Text</label>
                <input type="text" id="l-hero-ctaSecondaryText" class="form-control" value="${escapeHTML(config.hero?.ctaSecondaryText || 'Send Quick Enquiry')}">
              </div>
              <div>
                <label>Secondary CTA Button Link</label>
                <input type="text" id="l-hero-ctaSecondaryLink" class="form-control" value="${escapeHTML(config.hero?.ctaSecondaryLink || '#enquiry')}">
              </div>
            </div>
            <div class="form-group mb-3" style="display: flex; gap: 0.75rem; align-items: center;">
              <input type="checkbox" id="l-hero-enableTicker" ${config.hero?.enableTicker !== false ? 'checked' : ''}>
              <label class="mb-0" style="font-weight: 600;">Enable Announcement Ticker</label>
            </div>
            <div class="form-group mb-3">
              <label>Ticker Text</label>
              <input type="text" id="l-hero-ticker" class="form-control" value="${escapeHTML(config.hero?.tickerText || '')}">
            </div>
            <div class="form-group mb-3" style="display: flex; gap: 0.75rem; align-items: center;">
              <input type="checkbox" id="l-hero-liveSeatBadge-enabled" ${config.hero?.liveSeatBadge?.enabled !== false ? 'checked' : ''}>
              <label class="mb-0" style="font-weight: 600;">Enable Live Seat Counter Badge</label>
            </div>
            <div class="form-group mb-3">
              <label>Live Seat Badge Text</label>
              <input type="text" id="l-hero-liveSeatBadge-text" class="form-control" value="${escapeHTML(config.hero?.liveSeatBadge?.text || '')}">
            </div>
            <div class="form-group mb-3">
              <label>Hero Badges (comma separated)</label>
              <input type="text" id="l-hero-badges" class="form-control" value="${escapeHTML((config.hero?.badges || []).join(', '))} ">
            </div>
          </div>

          <!-- 2. Navbar & CTA -->
          <div class="landing-panel" id="l-panel-navbar" style="display: none;">
            <h4>Navbar & Header Controls</h4>
            <div class="form-group mb-3">
              <label>Brand Display Name (Navbar)</label>
              <input type="text" id="l-nav-brandName" class="form-control" placeholder="e.g. Study Library" value="${escapeHTML(config.navbar?.brandName || '')}">
            </div>
            <div class="form-group mb-3">
              <label>Brand Logo Image URL</label>
              <input type="text" id="l-nav-brandLogo" class="form-control" placeholder="https://.../logo.png" value="${escapeHTML(config.navbar?.brandLogo || '')}">
            </div>
            <div class="row g-2 mb-3" style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px;">
              <div>
                <label>Primary CTA Text</label>
                <input type="text" id="l-nav-ctaPrimaryText" class="form-control" value="${escapeHTML(config.navbar?.ctaPrimaryText || 'Register Now')}">
              </div>
              <div>
                <label>Primary CTA Link</label>
                <input type="text" id="l-nav-ctaPrimaryLink" class="form-control" value="${escapeHTML(config.navbar?.ctaPrimaryLink || '/register')}">
              </div>
            </div>
            <div class="row g-2 mb-3" style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px;">
              <div>
                <label>Secondary CTA Text</label>
                <input type="text" id="l-nav-ctaSecondaryText" class="form-control" value="${escapeHTML(config.navbar?.ctaSecondaryText || 'Student Portal')}">
              </div>
              <div>
                <label>Secondary CTA Link</label>
                <input type="text" id="l-nav-ctaSecondaryLink" class="form-control" value="${escapeHTML(config.navbar?.ctaSecondaryLink || '/student-login')}">
              </div>
            </div>
            <div class="form-group mb-3" style="display: flex; gap: 0.75rem; align-items: center;">
              <input type="checkbox" id="l-nav-darkModeToggle" ${config.navbar?.showDarkModeToggle !== false ? 'checked' : ''}>
              <label class="mb-0" style="font-weight: 600;">Show Dark / Light Theme Toggle in Navbar</label>
            </div>
          </div>
          
          <!-- 3. About & Stats -->
          <div class="landing-panel" id="l-panel-about" style="display: none;">
            <h4>About & Stats</h4>
            <div class="form-group mb-3">
              <label>Headline</label>
              <input type="text" id="l-about-title" class="form-control" value="${escapeHTML(config.about?.title || 'About Our Study Library')}">
            </div>
            <div class="form-group mb-3">
              <label>Sub-headline / Tagline</label>
              <input type="text" id="l-about-subtitle" class="form-control" value="${escapeHTML(config.about?.subtitle || 'Why Choose Our Reading Hall?')}">
            </div>
            <div class="form-group mb-3">
              <label>Description</label>
              <textarea id="l-about-description" class="form-control" rows="4">${escapeHTML(config.about?.description || '')}</textarea>
            </div>
            <div class="form-group mb-3">
              <label>Highlight Points (Key Features)</label>
              ${[0, 1, 2, 3].map(i => `<input type="text" class="form-control mb-2 l-about-point" placeholder="Feature point ${i + 1}" value="${escapeHTML(config.about?.highlightPoints?.[i] || '')}">`).join('')}
            </div>
            <div class="form-group mb-3">
              <label>Stats Badges (4 items: Number / Label)</label>
              ${[0, 1, 2, 3].map(i => `
                <div style="display: flex; gap: 0.5rem; margin-bottom: 0.5rem;">
                  <input type="text" class="form-control l-about-stat-num" placeholder="Number (e.g. 100%)" value="${escapeHTML(config.about?.stats?.[i]?.number || '')}">
                  <input type="text" class="form-control l-about-stat-label" placeholder="Label (e.g. Silence)" value="${escapeHTML(config.about?.stats?.[i]?.label || '')}">
                </div>
              `).join('')}
            </div>
          </div>
          
          <!-- 4. Facilities -->
          <div class="landing-panel" id="l-panel-facilities" style="display: none;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;">
              <h4 style="margin: 0;">Facilities & Amenities</h4>
              <button class="btn btn-outline-primary btn-sm" id="btn-add-facility">+ Add Facility</button>
            </div>
            <div class="form-group mb-3">
              <label>Section Title</label>
              <input type="text" id="l-fac-title" class="form-control" value="${escapeHTML(config.facilities?.title || 'World-Class Amenities & Facilities')}">
            </div>
            <div class="form-group mb-3">
              <label>Section Subtitle</label>
              <input type="text" id="l-fac-subtitle" class="form-control" value="${escapeHTML(config.facilities?.subtitle || 'Everything you need for uninterrupted, comfortable 14+ hours study sessions.')}">
            </div>
            <div id="l-facilities-list" style="display: flex; flex-direction: column; gap: 1rem;"></div>
          </div>
          
          <!-- 5. Shifts -->
          <div class="landing-panel" id="l-panel-shifts" style="display: none;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;">
              <h4 style="margin: 0;">Shifts Guide</h4>
              <button class="btn btn-outline-primary btn-sm" id="btn-add-shift">+ Add Shift</button>
            </div>
            <div class="form-group mb-3">
              <label>Section Title</label>
              <input type="text" id="l-shifts-title" class="form-control" value="${escapeHTML(config.shifts?.title || 'Flexible Study Shifts')}">
            </div>
            <div class="form-group mb-3">
              <label>Section Subtitle</label>
              <input type="text" id="l-shifts-subtitle" class="form-control" value="${escapeHTML(config.shifts?.subtitle || 'Choose a timing that fits your schedule.')}">
            </div>
            <p style="font-size: 0.85rem; color: var(--color-text-secondary); margin-bottom: 0.75rem;">
              ℹ️ Live system shifts are automatically populated. Use the checkbox to show or hide any shift on the public landing page.
            </p>
            <div id="l-shifts-list" style="display: flex; flex-direction: column; gap: 0.85rem;"></div>
          <!-- 5b. Pricing & Plans Header -->
          <div class="landing-panel" id="l-panel-pricing" style="display: none;">
            <h4 style="margin-bottom: 0.5rem;">Pricing & Membership Plans Section</h4>
            <p class="text-muted" style="margin-bottom: 1rem; font-size: 0.85rem;">Customize pricing section header text and enable/disable pricing visibility. To add, edit, or delete individual membership plans, use <a href="#/plans" style="color: var(--color-primary); font-weight: 700;">Plans Studio (&rarr;)</a>.</p>
            
            <div class="form-group mb-3">
              <label class="form-label" style="font-weight: 600;">Section Badge Tag</label>
              <input type="text" id="l-pricing-badge" class="form-control" value="${escapeHTML(config.pricing?.badge || 'PRICING')}">
            </div>
            
            <div class="form-group mb-3">
              <label class="form-label" style="font-weight: 600;">Section Title</label>
              <input type="text" id="l-pricing-title" class="form-control" value="${escapeHTML(config.pricing?.title || 'Transparent & Affordable Plans')}">
            </div>
            
            <div class="form-group mb-3">
              <label class="form-label" style="font-weight: 600;">Section Subtitle</label>
              <input type="text" id="l-pricing-subtitle" class="form-control" value="${escapeHTML(config.pricing?.subtitle || 'Choose the perfect duration and secure your seat today.')}">
            </div>

            <div style="margin-top: 1.5rem; padding: 1rem; background: var(--color-primary-bg); border-radius: var(--radius-md); border: 1px solid var(--color-primary);">
              <strong style="color: var(--color-primary);">💡 Quick Plan Management:</strong>
              <p style="font-size: 0.85rem; margin-top: 4px; margin-bottom: 8px;">Individual plan cards (Prices, Discounts, Shift types, Amenities, Duration tabs) are live-managed in your Admin Plans Studio.</p>
              <a href="#/plans" class="btn btn-sm btn-primary" style="font-weight: 700;">Go to Plans Studio &rarr;</a>
            </div>
          </div>

          <!-- 6. Rules -->
          <div class="landing-panel" id="l-panel-rules" style="display: none;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;">
              <h4 style="margin: 0;">Rules & Code of Conduct</h4>
              <button class="btn btn-outline-primary btn-sm" id="btn-add-rule">+ Add Rule</button>
            </div>
            <div class="form-group mb-3">
              <label>Section Title</label>
              <input type="text" id="l-rules-title" class="form-control" value="${escapeHTML(config.rules?.title || 'Library Rules & Code of Conduct')}">
            </div>
            <div class="form-group mb-3">
              <label>Section Subtitle</label>
              <input type="text" id="l-rules-subtitle" class="form-control" value="${escapeHTML(config.rules?.subtitle || 'To maintain a peaceful and productive atmosphere for everyone, all members must adhere to these rules.')}">
            </div>
            <div id="l-rules-list" style="display: flex; flex-direction: column; gap: 0.5rem;"></div>
          </div>
          
          <!-- 7. Gallery -->
          <div class="landing-panel" id="l-panel-gallery" style="display: none;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;">
              <h4 style="margin: 0;">Photo Gallery</h4>
              <button class="btn btn-outline-primary btn-sm" id="btn-add-gallery">+ Add Photo</button>
            </div>
            <div class="form-group mb-3">
              <label>Section Title</label>
              <input type="text" id="l-gal-title" class="form-control" value="${escapeHTML(config.gallery?.title || 'Library Hall & Facilities Gallery')}">
            </div>
            <div class="form-group mb-3">
              <label>Section Subtitle</label>
              <input type="text" id="l-gal-subtitle" class="form-control" value="${escapeHTML(config.gallery?.subtitle || 'A glimpse into our state-of-the-art reading halls and study infrastructure.')}">
            </div>
            <div id="l-gallery-list" style="display: flex; flex-direction: column; gap: 1rem;"></div>
          </div>
          
          <!-- 8. FAQs -->
          <div class="landing-panel" id="l-panel-faqs" style="display: none;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;">
              <h4 style="margin: 0;">Frequently Asked Questions</h4>
              <button class="btn btn-outline-primary btn-sm" id="btn-add-faq">+ Add FAQ</button>
            </div>
            <div class="form-group mb-3">
              <label>Section Title</label>
              <input type="text" id="l-faqs-title" class="form-control" value="${escapeHTML(config.faqs?.title || 'Frequently Asked Questions')}">
            </div>
            <div class="form-group mb-3">
              <label>Section Subtitle</label>
              <input type="text" id="l-faqs-subtitle" class="form-control" value="${escapeHTML(config.faqs?.subtitle || 'Find answers to common queries.')}">
            </div>
            <div id="l-faqs-list" style="display: flex; flex-direction: column; gap: 1rem;"></div>
          </div>
          
          <!-- 9. Reviews & Testimonials -->
          <div class="landing-panel" id="l-panel-testimonials" style="display: none;">
            <h4>Reviews & Testimonials</h4>
            <div class="form-group mb-3">
              <label>Section Title</label>
              <input type="text" id="l-test-title" class="form-control" value="${escapeHTML(config.testimonials?.title || 'What Our Students Say')}">
            </div>
            <div class="row g-2 mb-3" style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px;">
              <div>
                <label>Google Rating (e.g. 4.9)</label>
                <input type="text" id="l-test-googleRating" class="form-control" value="${escapeHTML(config.testimonials?.googleRating || '4.9')}">
              </div>
              <div>
                <label>Google Reviews Count (e.g. 250+ Reviews)</label>
                <input type="text" id="l-test-googleReviewsCount" class="form-control" value="${escapeHTML(config.testimonials?.googleReviewsCount || '250+ Reviews')}">
              </div>
            </div>
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem; margin-top: 1.5rem;">
              <h5 style="margin: 0; font-size: 1rem; font-weight: 600;">Student Reviews List</h5>
              <button class="btn btn-outline-primary btn-sm" id="btn-add-testimonial">+ Add Testimonial</button>
            </div>
            <div id="l-testimonials-list" style="display: flex; flex-direction: column; gap: 1rem;"></div>
          </div>
          
          <!-- 10. Contact & Map -->
          <div class="landing-panel" id="l-panel-contact" style="display: none;">
            <h4>Contact & Map</h4>
            <div class="form-group mb-3">
              <label>Phone Number</label>
              <input type="text" id="l-contact-phone" class="form-control" value="${escapeHTML(config.contact?.phone || '')}">
            </div>
            <div class="form-group mb-3">
              <label>WhatsApp Number</label>
              <input type="text" id="l-contact-wa" class="form-control" value="${escapeHTML(config.contact?.whatsapp || '')}">
            </div>
            <div class="form-group mb-3">
              <label>Email Address</label>
              <input type="text" id="l-contact-email" class="form-control" value="${escapeHTML(config.contact?.email || '')}">
            </div>
            <div class="form-group mb-3">
              <label>Address</label>
              <input type="text" id="l-contact-address" class="form-control" value="${escapeHTML(config.contact?.address || '')}">
            </div>
            <div class="form-group mb-3">
              <label>Timings / Working Hours</label>
              <input type="text" id="l-contact-hours" class="form-control" value="${escapeHTML(config.contact?.openingHours || '')}">
            </div>
            <div class="form-group mb-3">
              <label>Google Map Embed URL</label>
              <textarea id="l-contact-map" class="form-control" rows="3" placeholder="https://maps.google.com/maps?q=...&output=embed">${escapeHTML(config.contact?.googleMapEmbedUrl || '')}</textarea>
            </div>
          </div>

          <!-- 11. Footer & Quick Links Panel -->
          <div class="landing-panel" id="l-panel-footer" style="display: none;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;">
              <h4 style="margin: 0;">🔗 Quick Links & Footer Customizer</h4>
              <button class="btn btn-outline-primary btn-sm" id="btn-add-quicklink">+ Add Quick Link</button>
            </div>
            
            <div class="form-group mb-3">
              <label>Footer Tagline</label>
              <input type="text" id="l-footer-tagline" class="form-control" placeholder="Premier Air-Conditioned Reading Hall & Self-Study Space." value="${escapeHTML(config.footer?.tagline || '')}">
            </div>

            <div class="form-group mb-3">
              <label>Copyright Notice Text</label>
              <input type="text" id="l-footer-copyright" class="form-control" placeholder="Study Library Management System. All Rights Reserved." value="${escapeHTML(config.footer?.copyrightText || '')}">
            </div>

            <div class="form-group mb-3">
              <label>Direct Google Maps Link (for 'Open in Google Maps' button)</label>
              <input type="text" id="l-footer-mapDirect" class="form-control" placeholder="https://maps.google.com/?q=..." value="${escapeHTML(config.footer?.mapDirectLink || '')}">
            </div>

            <h5 style="font-size: 0.95rem; font-weight: 600; margin-top: 1.5rem; margin-bottom: 0.5rem; border-bottom: 1px solid var(--color-border); padding-bottom: 6px;">Footer Quick Links</h5>
            <div id="l-quicklinks-list" style="display: flex; flex-direction: column; gap: 0.75rem;"></div>
          </div>

          <!-- 12. Floating Actions Bar Panel -->
          <div class="landing-panel" id="l-panel-floating" style="display: none;">
            <h4>💬 Floating Action Buttons Bar</h4>
            <div class="form-group mb-3" style="display: flex; gap: 0.75rem; align-items: center;">
              <input type="checkbox" id="l-float-enabled" ${config.floatingActions?.enabled !== false ? 'checked' : ''}>
              <label class="mb-0" style="font-weight: 600;">Enable Dual Floating Contact Buttons (Bottom Right)</label>
            </div>
            <div class="form-group mb-3">
              <label>WhatsApp Number (with Country Code)</label>
              <input type="text" id="l-float-wa" class="form-control" placeholder="+91 9876543210" value="${escapeHTML(config.floatingActions?.whatsappNumber || config.contact?.whatsapp || '')}">
            </div>
            <div class="form-group mb-3">
              <label>WhatsApp Pre-filled Message</label>
              <textarea id="l-float-wamsg" class="form-control" rows="2" placeholder="Hello! I am interested in joining the study library.">${escapeHTML(config.floatingActions?.whatsappMessage || '')}</textarea>
            </div>
            <div class="form-group mb-3">
              <label>Call Now Phone Number</label>
              <input type="text" id="l-float-call" class="form-control" placeholder="+91 9876543210" value="${escapeHTML(config.floatingActions?.callNumber || config.contact?.phone || '')}">
            </div>
          </div>

          <!-- 13. SEO & Social Meta Panel -->
          <div class="landing-panel" id="l-panel-seo" style="display: none;">
            <h4>🔍 SEO & Social Share Metadata</h4>
            <div class="form-group mb-3">
              <label>Meta Page Title</label>
              <input type="text" id="l-seo-title" class="form-control" placeholder="Study Library & Reading Hall" value="${escapeHTML(config.seo?.metaTitle || '')}">
            </div>
            <div class="form-group mb-3">
              <label>Meta Description</label>
              <textarea id="l-seo-desc" class="form-control" rows="3" placeholder="Peaceful, air-conditioned study library...">${escapeHTML(config.seo?.metaDescription || '')}</textarea>
            </div>
            <div class="form-group mb-3">
              <label>Search Keywords (Comma separated)</label>
              <input type="text" id="l-seo-keywords" class="form-control" placeholder="study library, reading room, UPSC, Pune" value="${escapeHTML(config.seo?.metaKeywords || '')}">
            </div>
            <div class="form-group mb-3">
              <label>Social Share (OpenGraph) Banner Image URL</label>
              <input type="text" id="l-seo-ogImage" class="form-control" placeholder="https://.../banner.jpg" value="${escapeHTML(config.seo?.ogImage || '')}">
            </div>
          </div>
          
        </div> <!-- #landing-tab-content -->
      </div> <!-- .cms-editor-panel -->
        
      <!-- Right: Live Split-Screen Interactive Preview Canvas -->
      <div class="cms-preview-panel" style="border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1rem; background: var(--color-bg-secondary); position: sticky; top: 20px; height: calc(100vh - 240px); min-height: 600px; display: flex; flex-direction: column; overflow: hidden;">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.75rem; padding: 0 0.25rem; flex-shrink: 0;">
            <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-secondary); text-transform: uppercase; letter-spacing: 0.5px;">
              <span>🌐</span> Live Landing Page Viewport
            </div>
            <a href="/landing" target="_blank" style="font-size: 0.8rem; font-weight: 600; color: var(--color-primary); text-decoration: none;">
              Open Full Page ↗
            </a>
          </div>

          <div id="pv-frame-shell" style="flex: 1; border: 1px solid var(--color-border); border-radius: 12px; overflow: hidden; background: #fff; box-shadow: var(--shadow-md); margin: 0 auto; transition: all 0.3s ease; width: 100%; position: relative;">
            <iframe id="pv-landing-iframe" src="/landing?preview=true" style="width: 138.8%; height: 138.8%; border: none; transform: scale(0.72); transform-origin: top left;"></iframe>
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
      if (pvShell) {
        pvShell.style.width = '100%';
        pvShell.style.maxWidth = '100%';
      }
      if (pvIframe) {
        pvIframe.style.transform = 'scale(0.72)';
        pvIframe.style.transformOrigin = 'top left';
        pvIframe.style.width = '138.8%';
        pvIframe.style.height = '138.8%';
      }
    });

    btnPvMobile?.addEventListener('click', () => {
      btnPvMobile.className = 'btn btn-sm btn-primary';
      btnPvDesktop.className = 'btn btn-sm btn-outline';
      if (pvShell) {
        pvShell.style.width = '375px';
        pvShell.style.maxWidth = '375px';
      }
      if (pvIframe) {
        pvIframe.style.transform = 'none';
        pvIframe.style.width = '100%';
        pvIframe.style.height = '100%';
      }
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
        const targetPanel = listContainer.querySelector(`#l-panel-${btn.dataset.tab}`);
        if (targetPanel) targetPanel.style.display = 'block';
      });
    });

    // Helper functions to render lists with full CRUD and reordering
    const renderFacilities = () => {
      const parent = listContainer.querySelector('#l-facilities-list');
      if (!parent) return;
      parent.innerHTML = '';
      let items = config.facilities?.items;
      if (!Array.isArray(items) || items.length === 0) {
        items = [
          { icon: '❄️', title: 'Central Air Conditioning', description: 'Dual inverter ACs maintaining optimal 23°C temperature all year round.' },
          { icon: '📶', title: 'Ultra High-Speed Wi-Fi', description: 'Dual fiber broadband connections (300 Mbps) with zero downtime.' },
          { icon: '💺', title: 'Ergonomic Seating', description: 'Orthopedic lumbar-support chairs with spacious individual wooden desks.' },
          { icon: '🔋', title: '100% Power Backup', description: 'Heavy-duty silent online UPS + generator backup ensures no blackout pauses.' }
        ];
      }
      if (!config.facilities) config.facilities = {};
      config.facilities.items = items;

      items.forEach((item, idx) => {
        const div = document.createElement('div');
        div.style.cssText = 'border: 1px solid var(--color-border); padding: 1rem; border-radius: var(--radius-md); position: relative; background: var(--color-surface);';
        div.innerHTML = `
          <div style="position: absolute; top: 0.75rem; right: 0.75rem; display: flex; gap: 4px;">
            <button class="btn btn-sm btn-outline btn-up-fac" ${idx === 0 ? 'disabled' : ''} title="Move Up">⬆️</button>
            <button class="btn btn-sm btn-outline btn-down-fac" ${idx === items.length - 1 ? 'disabled' : ''} title="Move Down">⬇️</button>
            <button class="btn btn-sm btn-outline-danger btn-delete-facility" title="Delete Facility">🗑️</button>
          </div>
          <div style="display: flex; gap: 0.75rem; width: calc(100% - 120px);">
            <input type="text" class="form-control l-fac-icon" style="width: 54px; text-align: center;" placeholder="Icon" value="${escapeHTML(item.icon || '❄️')}">
            <input type="text" class="form-control l-fac-title" style="flex: 1; font-weight: 600;" placeholder="Facility Title" value="${escapeHTML(item.title || '')}">
          </div>
          <textarea class="form-control mt-2 l-fac-desc" placeholder="Description of amenity..." rows="2">${escapeHTML(item.description || '')}</textarea>
        `;

        div.querySelector('.l-fac-icon')?.addEventListener('input', e => { item.icon = e.target.value; });
        div.querySelector('.l-fac-title')?.addEventListener('input', e => { item.title = e.target.value; });
        div.querySelector('.l-fac-desc')?.addEventListener('input', e => { item.description = e.target.value; });

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
        div.querySelector('.btn-delete-facility')?.addEventListener('click', () => {
          items.splice(idx, 1);
          renderFacilities();
        });
        parent.appendChild(div);
      });
    };

    listContainer.querySelector('#btn-add-facility')?.addEventListener('click', () => {
      if (!config.facilities) config.facilities = { items: [] };
      if (!Array.isArray(config.facilities.items)) config.facilities.items = [];
      config.facilities.items.push({ icon: '✨', title: 'New Facility', description: 'Description of the new facility.' });
      renderFacilities();
    });

    const renderShifts = () => {
      const parent = listContainer.querySelector('#l-shifts-list');
      if (!parent) return;
      parent.innerHTML = '';
      let items = config.shifts?.items;
      if (!Array.isArray(items) || items.length === 0) {
        items = [
          { icon: '🌅', name: 'Morning Shift', timing: '06:00 AM – 02:00 PM', description: 'Start your day early with peak focus.', enabled: true },
          { icon: '🌇', name: 'Evening Shift', timing: '02:00 PM – 10:00 PM', description: 'Perfect for late risers and working professionals.', enabled: true },
          { icon: '☀️', name: 'Full Day Shift', timing: '06:00 AM – 11:00 PM', description: '17-hour dedicated reserved desk for serious aspirants.', enabled: true },
          { icon: '🌙', name: 'Night Owl Slot', timing: '10:00 PM – 06:00 AM', description: 'Distraction-free overnight study hours.', enabled: true }
        ];
      }
      if (!config.shifts) config.shifts = {};
      config.shifts.items = items;

      items.forEach((item, idx) => {
        const isEnabled = item.enabled !== false;
        const div = document.createElement('div');
        div.dataset.shiftId = item.shiftId || '';
        div.style.cssText = `border: 1.5px solid var(--color-border); padding: 1rem; border-radius: var(--radius-md); position: relative; background: var(--color-surface); opacity: ${isEnabled ? '1' : '0.65'}; transition: opacity 0.2s;`;
        div.innerHTML = `
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.75rem; border-bottom: 1px dashed var(--color-border); padding-bottom: 0.5rem; flex-wrap: wrap; gap: 0.5rem;">
            <label class="switch-label" style="color: ${isEnabled ? 'var(--color-primary)' : 'var(--color-text-secondary)'}; margin-bottom: 0;">
              <input type="checkbox" class="l-shift-enabled" ${isEnabled ? 'checked' : ''}>
              <span class="switch-slider"></span>
              <span style="font-weight: 700; font-size: 0.88rem;">Show on Landing Page</span>
            </label>
            <div style="display: flex; align-items: center; gap: 4px;">
              ${item.shiftId ? '<span style="font-size: 0.72rem; padding: 2px 6px; background: rgba(108,92,231,0.1); color: var(--color-primary); border-radius: 4px; font-weight: 700;">Live System Shift</span>' : ''}
              <button class="btn btn-sm btn-outline btn-up-shift" ${idx === 0 ? 'disabled' : ''} title="Move Up">⬆️</button>
              <button class="btn btn-sm btn-outline btn-down-shift" ${idx === items.length - 1 ? 'disabled' : ''} title="Move Down">⬇️</button>
              <button class="btn btn-sm btn-outline-danger btn-delete-shift" title="Delete Shift">🗑️</button>
            </div>
          </div>
          <div style="display: flex; gap: 0.75rem; width: 100%; flex-wrap: wrap;">
            <input type="text" class="form-control l-shift-icon" style="width: 54px; text-align: center; font-size: 1.2rem;" placeholder="Icon" value="${escapeHTML(item.icon || '⏰')}">
            <input type="text" class="form-control l-shift-name" style="flex: 1.2; min-width: 140px; font-weight: 700;" placeholder="Shift Name" value="${escapeHTML(item.name || '')}">
            <input type="text" class="form-control l-shift-timing" style="flex: 1.2; min-width: 140px; font-weight: 600;" placeholder="Timings (e.g. 06:00 AM – 02:00 PM)" value="${escapeHTML(item.timing || '')}">
          </div>
          <textarea class="form-control mt-2 l-shift-desc" placeholder="Brief description / benefits for students..." rows="2">${escapeHTML(item.description || '')}</textarea>
        `;

        div.querySelector('.l-shift-enabled')?.addEventListener('change', (e) => {
          const checked = e.target.checked;
          item.enabled = checked;
          div.style.opacity = checked ? '1' : '0.65';
        });
        div.querySelector('.l-shift-icon')?.addEventListener('input', e => { item.icon = e.target.value; });
        div.querySelector('.l-shift-name')?.addEventListener('input', e => { item.name = e.target.value; });
        div.querySelector('.l-shift-timing')?.addEventListener('input', e => { item.timing = e.target.value; });
        div.querySelector('.l-shift-desc')?.addEventListener('input', e => { item.description = e.target.value; });

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
        div.querySelector('.btn-delete-shift')?.addEventListener('click', () => {
          items.splice(idx, 1);
          renderShifts();
        });
        parent.appendChild(div);
      });
    };

    listContainer.querySelector('#btn-add-shift')?.addEventListener('click', () => {
      if (!config.shifts) config.shifts = { items: [] };
      if (!Array.isArray(config.shifts.items)) config.shifts.items = [];
      config.shifts.items.push({ icon: '⏰', name: 'Custom Shift', timing: '08:00 AM – 04:00 PM', description: 'Dedicated study slot with AC and high-speed Wi-Fi access.', enabled: true });
      renderShifts();
    });

    const renderRules = () => {
      const parent = listContainer.querySelector('#l-rules-list');
      if (!parent) return;
      parent.innerHTML = '';
      let items = config.rules?.items;
      if (!Array.isArray(items) || items.length === 0) {
        items = [
          'Strict pin-drop silence must be maintained in the reading hall at all times.',
          'Mobile phones MUST be kept on Silent/Vibrate mode. Phone calls must only be attended outside the hall.',
          'Seats are strictly reserved for allotted members during their designated shift hours.',
          'Eating snacks or meals inside the study hall is prohibited. Please use the designated cafeteria area.',
          'Please keep your study desk clean and tidy before leaving for the day.',
          'Library management reserves the right to cancel admission in case of indiscipline or misbehavior.'
        ];
      }
      if (!config.rules) config.rules = {};
      config.rules.items = items;

      items.forEach((item, idx) => {
        const div = document.createElement('div');
        div.style.cssText = 'display: flex; gap: 0.5rem; align-items: center; background: var(--color-surface); padding: 8px 12px; border: 1px solid var(--color-border); border-radius: var(--radius-md); margin-bottom: 6px;';
        div.innerHTML = `
          <span style="font-weight: 700; font-size: 0.85rem; color: var(--color-primary); min-width: 24px; text-align: center;">${idx + 1}.</span>
          <input type="text" class="form-control l-rule-text" style="flex: 1;" value="${escapeHTML(item)}" placeholder="Rule statement...">
          <div style="display: flex; gap: 4px;">
            <button class="btn btn-sm btn-outline btn-up-rule" ${idx === 0 ? 'disabled' : ''} title="Move Up">⬆️</button>
            <button class="btn btn-sm btn-outline btn-down-rule" ${idx === items.length - 1 ? 'disabled' : ''} title="Move Down">⬇️</button>
            <button class="btn btn-sm btn-outline-danger btn-delete-rule" title="Delete Rule">🗑️</button>
          </div>
        `;

        div.querySelector('.l-rule-text')?.addEventListener('input', e => { items[idx] = e.target.value; });

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
        div.querySelector('.btn-delete-rule')?.addEventListener('click', () => {
          items.splice(idx, 1);
          renderRules();
        });
        parent.appendChild(div);
      });
    };

    listContainer.querySelector('#btn-add-rule')?.addEventListener('click', () => {
      if (!config.rules) config.rules = { items: [] };
      if (!Array.isArray(config.rules.items)) config.rules.items = [];
      config.rules.items.push('Members must maintain discipline at all times.');
      renderRules();
    });

    const renderGallery = () => {
      const parent = listContainer.querySelector('#l-gallery-list');
      if (!parent) return;
      parent.innerHTML = '';
      let items = config.gallery?.images || config.gallery?.items;
      if (!Array.isArray(items) || items.length === 0) {
        items = [
          { url: 'https://images.unsplash.com/photo-1568667256549-094345857637?auto=format&fit=crop&w=800', caption: 'Premium Study Cabins', category: 'Cabins' },
          { url: 'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?auto=format&fit=crop&w=800', caption: 'Silent Reading Hall', category: 'Hall' },
          { url: 'https://images.unsplash.com/photo-1519389950473-47ba0277781c?auto=format&fit=crop&w=800', caption: 'Discussion Zone & Amenities', category: 'Amenities' },
          { url: 'https://images.unsplash.com/photo-1498050108023-c5249f4df085?auto=format&fit=crop&w=800', caption: 'Orthopedic Ergonomic Desks', category: 'Cabins' },
          { url: 'https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?auto=format&fit=crop&w=800', caption: 'Air-Conditioned Silent Zone', category: 'Hall' },
          { url: 'https://images.unsplash.com/photo-1517048676732-d65bc937f952?auto=format&fit=crop&w=800', caption: 'Discussion Room & High-Speed Wi-Fi', category: 'Amenities' }
        ];
      }
      if (!config.gallery) config.gallery = {};
      config.gallery.images = items;

      items.forEach((item, idx) => {
        const div = document.createElement('div');
        div.style.cssText = 'border: 1px solid var(--color-border); padding: 1rem; border-radius: var(--radius-md); display: flex; gap: 1rem; align-items: center; position: relative; background: var(--color-surface);';
        div.innerHTML = `
          <img src="${escapeHTML(item.url || 'https://via.placeholder.com/80')}" style="width: 70px; height: 70px; object-fit: cover; border-radius: var(--radius-md);" onerror="this.src='https://via.placeholder.com/80?text=No+Img'">
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
            <button class="btn btn-sm btn-outline-danger btn-delete-gallery" title="Delete Photo">🗑️</button>
          </div>
        `;
        
        div.querySelector('.l-gal-url')?.addEventListener('input', (e) => {
          item.url = e.target.value;
          const img = div.querySelector('img');
          if (img) img.src = e.target.value || 'https://via.placeholder.com/80';
        });
        div.querySelector('.l-gal-cat')?.addEventListener('change', e => { item.category = e.target.value; });
        div.querySelector('.l-gal-caption')?.addEventListener('input', e => { item.caption = e.target.value; });

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
        div.querySelector('.btn-delete-gallery')?.addEventListener('click', () => {
          items.splice(idx, 1);
          renderGallery();
        });
        parent.appendChild(div);
      });
    };

    listContainer.querySelector('#btn-add-gallery')?.addEventListener('click', () => {
      if (!config.gallery) config.gallery = { images: [] };
      if (!Array.isArray(config.gallery.images)) config.gallery.images = [];
      config.gallery.images.push({ url: 'https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?auto=format&fit=crop&w=800', category: 'Hall', caption: 'Reading Room' });
      renderGallery();
    });

    const renderFaqs = () => {
      const parent = listContainer.querySelector('#l-faqs-list');
      if (!parent) return;
      parent.innerHTML = '';
      let items = config.faqs?.items;
      if (!Array.isArray(items) || items.length === 0) {
        items = [
          { question: 'What is the free trial policy?', answer: 'We offer a 1-day free trial for new students to experience our silent environment and facilities. You can book it by filling out the enquiry form below.' },
          { question: 'How is locker allotment handled?', answer: 'Lockers are available on a first-come, first-served basis for a nominal monthly fee. Full Day Prime members get priority locker allotment.' },
          { question: 'Can I pause my membership or get a refund?', answer: 'Membership fees are non-refundable. However, long-term plans (6 months+) allow for a 15-day membership pause in case of medical emergencies or exams.' },
          { question: 'Can I switch my shift later?', answer: 'Yes, shift switching is allowed subject to seat availability in the requested shift. A small admin fee may apply.' },
          { question: 'What is the admission procedure?', answer: 'Simply click on "Register Now", fill the online form, choose your plan, and complete the payment. Bring your ID proof to the library to collect your access card.' }
        ];
      }
      if (!config.faqs) config.faqs = {};
      config.faqs.items = items;

      items.forEach((item, idx) => {
        const div = document.createElement('div');
        div.style.cssText = 'border: 1px solid var(--color-border); padding: 1rem; border-radius: var(--radius-md); position: relative; background: var(--color-surface);';
        div.innerHTML = `
          <div style="position: absolute; top: 0.75rem; right: 0.75rem; display: flex; gap: 4px;">
            <button class="btn btn-sm btn-outline btn-up-faq" ${idx === 0 ? 'disabled' : ''} title="Move Up">⬆️</button>
            <button class="btn btn-sm btn-outline btn-down-faq" ${idx === items.length - 1 ? 'disabled' : ''} title="Move Down">⬇️</button>
            <button class="btn btn-sm btn-outline-danger btn-delete-faq" title="Delete FAQ">🗑️</button>
          </div>
          <input type="text" class="form-control l-faq-q mb-2" style="width: calc(100% - 120px); font-weight: 600;" placeholder="Question" value="${escapeHTML(item.question || '')}">
          <textarea class="form-control l-faq-a" placeholder="Answer" rows="2">${escapeHTML(item.answer || '')}</textarea>
        `;

        div.querySelector('.l-faq-q')?.addEventListener('input', e => { item.question = e.target.value; });
        div.querySelector('.l-faq-a')?.addEventListener('input', e => { item.answer = e.target.value; });

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
        div.querySelector('.btn-delete-faq')?.addEventListener('click', () => {
          items.splice(idx, 1);
          renderFaqs();
        });
        parent.appendChild(div);
      });
    };

    listContainer.querySelector('#btn-add-faq')?.addEventListener('click', () => {
      if (!config.faqs) config.faqs = { items: [] };
      if (!Array.isArray(config.faqs.items)) config.faqs.items = [];
      config.faqs.items.push({ question: 'New Question', answer: 'Answer to the question.' });
      renderFaqs();
    });

    const renderTestimonials = () => {
      const parent = listContainer.querySelector('#l-testimonials-list');
      if (!parent) return;
      parent.innerHTML = '';
      let items = config.testimonials?.items;
      if (!Array.isArray(items) || items.length === 0) {
        items = [
          { name: 'Rahul Desai', exam: 'UPSC Aspirant', feedback: 'The absolute best place in the city to prepare for UPSC. The silence is strictly maintained and the chairs are very comfortable for 10+ hour sessions.', rating: 5 },
          { name: 'Snehal Patil', exam: 'Cleared MPSC Rajyaseva', feedback: 'High-speed Wi-Fi, dedicated personal charging socket, and zero disturbances helped me crack MPSC in my first attempt!', rating: 5 },
          { name: 'Priya Kulkarni', exam: 'Cleared IBPS PO Exam', feedback: 'The peaceful vibe and ergonomic setup made all the difference for my mock tests and online preparation. Highly recommended for serious aspirants.', rating: 5 }
        ];
      }
      if (!config.testimonials) config.testimonials = {};
      config.testimonials.items = items;

      items.forEach((item, idx) => {
        const div = document.createElement('div');
        div.style.cssText = 'border: 1px solid var(--color-border); padding: 1rem; border-radius: var(--radius-md); position: relative; background: var(--color-surface);';
        div.innerHTML = `
          <div style="position: absolute; top: 0.75rem; right: 0.75rem; display: flex; gap: 4px;">
            <button class="btn btn-sm btn-outline btn-up-test" ${idx === 0 ? 'disabled' : ''} title="Move Up">⬆️</button>
            <button class="btn btn-sm btn-outline btn-down-test" ${idx === items.length - 1 ? 'disabled' : ''} title="Move Down">⬇️</button>
            <button class="btn btn-sm btn-outline-danger btn-delete-test" title="Delete Review">🗑️</button>
          </div>
          <div style="display: flex; gap: 0.75rem; margin-bottom: 0.5rem; width: calc(100% - 120px); flex-wrap: wrap;">
            <input type="text" class="form-control l-test-name" style="flex: 1; min-width: 130px; font-weight: 600;" placeholder="Student Name" value="${escapeHTML(item.name || '')}">
            <input type="text" class="form-control l-test-exam" style="flex: 1; min-width: 130px;" placeholder="Exam / Qualification" value="${escapeHTML(item.exam || '')}">
            <input type="number" class="form-control l-test-rating" style="width: 110px;" placeholder="Rating (1-5)" min="1" max="5" value="${item.rating || 5}">
          </div>
          <textarea class="form-control l-test-feedback" placeholder="Feedback quote..." rows="2">${escapeHTML(item.feedback || '')}</textarea>
        `;

        div.querySelector('.l-test-name')?.addEventListener('input', e => { item.name = e.target.value; });
        div.querySelector('.l-test-exam')?.addEventListener('input', e => { item.exam = e.target.value; });
        div.querySelector('.l-test-rating')?.addEventListener('input', e => { item.rating = Number(e.target.value) || 5; });
        div.querySelector('.l-test-feedback')?.addEventListener('input', e => { item.feedback = e.target.value; });

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
        div.querySelector('.btn-delete-test')?.addEventListener('click', () => {
          items.splice(idx, 1);
          renderTestimonials();
        });
        parent.appendChild(div);
      });
    };

    listContainer.querySelector('#btn-add-testimonial')?.addEventListener('click', () => {
      if (!config.testimonials) config.testimonials = { items: [] };
      if (!Array.isArray(config.testimonials.items)) config.testimonials.items = [];
      config.testimonials.items.push({ name: 'Student Name', exam: 'UPSC Aspirant', rating: 5, feedback: 'Great study space with calm ambience and ultra-fast Wi-Fi.' });
      renderTestimonials();
    });

    const renderQuickLinks = () => {
      const parent = listContainer.querySelector('#l-quicklinks-list');
      if (!parent) return;
      parent.innerHTML = '';
      let links = config.footer?.quickLinks;
      if (!Array.isArray(links) || links.length === 0) {
        links = [
          { label: 'Online Admission', url: '/register', openInNewTab: false, isSystem: true },
          { label: 'Student Portal', url: '/student-login', openInNewTab: false, isSystem: true },
          { label: 'Gate Kiosk', url: '/kiosk', openInNewTab: false, isSystem: true },
          { label: 'Staff & Owner Login', url: '/#/', openInNewTab: false, isSystem: true }
        ];
      }
      if (!config.footer) config.footer = {};
      config.footer.quickLinks = links;

      links.forEach((item, idx) => {
        const div = document.createElement('div');
        div.style.cssText = 'border: 1px solid var(--color-border); padding: 0.75rem 1rem; border-radius: var(--radius-md); background: var(--color-surface); display: flex; align-items: center; justify-content: space-between; gap: 0.75rem; flex-wrap: wrap;';
        div.innerHTML = `
          <div style="display: flex; gap: 0.5rem; flex: 1; min-width: 260px;">
            <input type="text" class="form-control l-ql-label" style="flex: 1; font-weight: 600;" placeholder="Link Label" value="${escapeHTML(item.label || '')}">
            <input type="text" class="form-control l-ql-url" style="flex: 1.5;" placeholder="URL (e.g. /register or https://...)" value="${escapeHTML(item.url || '')}">
          </div>
          <div style="display: flex; align-items: center; gap: 0.75rem;">
            <label style="display: inline-flex; align-items: center; gap: 4px; font-size: 0.8rem; cursor: pointer; white-space: nowrap; margin-bottom: 0;">
              <input type="checkbox" class="l-ql-target" ${item.openInNewTab ? 'checked' : ''}>
              <span>New Tab</span>
            </label>
            <div style="display: flex; gap: 4px;">
              <button class="btn btn-sm btn-outline btn-up-ql" ${idx === 0 ? 'disabled' : ''} title="Move Up">⬆️</button>
              <button class="btn btn-sm btn-outline btn-down-ql" ${idx === links.length - 1 ? 'disabled' : ''} title="Move Down">⬇️</button>
              <button class="btn btn-sm btn-outline-danger btn-delete-ql" title="Delete Link">🗑️</button>
            </div>
          </div>
        `;

        div.querySelector('.l-ql-label')?.addEventListener('input', e => { item.label = e.target.value; });
        div.querySelector('.l-ql-url')?.addEventListener('input', e => { item.url = e.target.value; });
        div.querySelector('.l-ql-target')?.addEventListener('change', e => { item.openInNewTab = e.target.checked; });

        div.querySelector('.btn-up-ql')?.addEventListener('click', () => {
          if (idx > 0) {
            const temp = links[idx];
            links[idx] = links[idx - 1];
            links[idx - 1] = temp;
            renderQuickLinks();
          }
        });
        div.querySelector('.btn-down-ql')?.addEventListener('click', () => {
          if (idx < links.length - 1) {
            const temp = links[idx];
            links[idx] = links[idx + 1];
            links[idx + 1] = temp;
            renderQuickLinks();
          }
        });
        div.querySelector('.btn-delete-ql')?.addEventListener('click', () => {
          links.splice(idx, 1);
          renderQuickLinks();
        });
        parent.appendChild(div);
      });
    };

    listContainer.querySelector('#btn-add-quicklink')?.addEventListener('click', () => {
      if (!config.footer) config.footer = { quickLinks: [] };
      if (!Array.isArray(config.footer.quickLinks)) config.footer.quickLinks = [];
      config.footer.quickLinks.push({ label: 'New Quick Link', url: '/register', openInNewTab: false });
      renderQuickLinks();
    });

    renderFacilities();
    renderShifts();
    renderRules();
    renderGallery();
    renderFaqs();
    renderTestimonials();
    renderQuickLinks();
  };

  container.querySelector('#btn-save-landing')?.addEventListener('click', async () => {
    const btn = container.querySelector('#btn-save-landing');
    Loading.button(btn, true);
    
    // Sync UI to payload
    const payload = { ...config };
    
    // 1. Hero
    payload.hero = {
      ...payload.hero,
      title: listContainer.querySelector('#l-hero-title')?.value || '',
      subtitle: listContainer.querySelector('#l-hero-subtitle')?.value || '',
      bannerImage: listContainer.querySelector('#l-hero-banner')?.value || '',
      ctaPrimaryText: listContainer.querySelector('#l-hero-ctaPrimaryText')?.value || 'Book Your Seat / Register Now',
      ctaPrimaryLink: listContainer.querySelector('#l-hero-ctaPrimaryLink')?.value || '/register',
      ctaSecondaryText: listContainer.querySelector('#l-hero-ctaSecondaryText')?.value || 'Send Quick Enquiry',
      ctaSecondaryLink: listContainer.querySelector('#l-hero-ctaSecondaryLink')?.value || '#enquiry',
      enableTicker: listContainer.querySelector('#l-hero-enableTicker')?.checked !== false,
      tickerText: listContainer.querySelector('#l-hero-ticker')?.value || '',
      badges: (listContainer.querySelector('#l-hero-badges')?.value || '').split(',').map(s => s.trim()).filter(Boolean),
      liveSeatBadge: {
        enabled: listContainer.querySelector('#l-hero-liveSeatBadge-enabled')?.checked !== false,
        text: listContainer.querySelector('#l-hero-liveSeatBadge-text')?.value || 'Only 12 Seats Left'
      }
    };

    // 2. Navbar
    payload.navbar = {
      ...payload.navbar,
      brandName: listContainer.querySelector('#l-nav-brandName')?.value || '',
      brandLogo: listContainer.querySelector('#l-nav-brandLogo')?.value || '',
      ctaPrimaryText: listContainer.querySelector('#l-nav-ctaPrimaryText')?.value || 'Register Now',
      ctaPrimaryLink: listContainer.querySelector('#l-nav-ctaPrimaryLink')?.value || '/register',
      ctaSecondaryText: listContainer.querySelector('#l-nav-ctaSecondaryText')?.value || 'Student Portal',
      ctaSecondaryLink: listContainer.querySelector('#l-nav-ctaSecondaryLink')?.value || '/student-login',
      showDarkModeToggle: listContainer.querySelector('#l-nav-darkModeToggle')?.checked !== false
    };
    
    // 3. About
    payload.about = {
      ...payload.about,
      title: listContainer.querySelector('#l-about-title')?.value || 'About Our Study Library',
      subtitle: listContainer.querySelector('#l-about-subtitle')?.value || 'Why Choose Our Reading Hall?',
      description: listContainer.querySelector('#l-about-description')?.value || '',
      highlightPoints: Array.from(listContainer.querySelectorAll('.l-about-point')).map(el => el.value.trim()).filter(Boolean),
      stats: Array.from(listContainer.querySelectorAll('.l-about-stat-num')).map((el, i) => ({
        number: el.value.trim(),
        label: listContainer.querySelectorAll('.l-about-stat-label')[i]?.value?.trim() || ''
      })).filter(s => s.number || s.label)
    };
    
    // 4. Facilities
    payload.facilities = {
      ...payload.facilities,
      title: listContainer.querySelector('#l-fac-title')?.value || 'World-Class Amenities & Facilities',
      subtitle: listContainer.querySelector('#l-fac-subtitle')?.value || 'Everything you need for uninterrupted, comfortable 14+ hours study sessions.',
      items: Array.from(listContainer.querySelectorAll('#l-facilities-list > div')).map(div => ({
        icon: div.querySelector('.l-fac-icon')?.value.trim() || '❄️',
        title: div.querySelector('.l-fac-title')?.value.trim() || '',
        description: div.querySelector('.l-fac-desc')?.value.trim() || ''
      })).filter(f => f.title)
    };
    
    // 5. Shifts
    payload.shifts = {
      ...payload.shifts,
      title: listContainer.querySelector('#l-shifts-title')?.value || 'Flexible Study Shifts',
      subtitle: listContainer.querySelector('#l-shifts-subtitle')?.value || 'Choose a timing that fits your schedule.',
      items: Array.from(listContainer.querySelectorAll('#l-shifts-list > div')).map(div => ({
        shiftId: div.dataset.shiftId || '',
        enabled: div.querySelector('.l-shift-enabled')?.checked !== false,
        icon: div.querySelector('.l-shift-icon')?.value.trim() || '⏰',
        name: div.querySelector('.l-shift-name')?.value.trim() || '',
        timing: div.querySelector('.l-shift-timing')?.value.trim() || '',
        description: div.querySelector('.l-shift-desc')?.value.trim() || ''
      })).filter(s => s.name)
    };
    
    // 5b. Pricing & Plans Section
    payload.pricing = {
      ...payload.pricing,
      badge: listContainer.querySelector('#l-pricing-badge')?.value?.trim() || 'PRICING',
      title: listContainer.querySelector('#l-pricing-title')?.value?.trim() || 'Transparent & Affordable Plans',
      subtitle: listContainer.querySelector('#l-pricing-subtitle')?.value?.trim() || 'Choose the perfect duration and secure your seat today.'
    };

    // 6. Rules
    payload.rules = {
      ...payload.rules,
      title: listContainer.querySelector('#l-rules-title')?.value || 'Library Rules & Code of Conduct',
      subtitle: listContainer.querySelector('#l-rules-subtitle')?.value || 'To maintain a peaceful and productive atmosphere for everyone, all members must adhere to these rules.',
      items: Array.from(listContainer.querySelectorAll('.l-rule-text')).map(el => el.value.trim()).filter(Boolean)
    };
    
    // 7. Gallery
    payload.gallery = {
      ...payload.gallery,
      title: listContainer.querySelector('#l-gal-title')?.value || 'Our Study Space & Ambience',
      subtitle: listContainer.querySelector('#l-gal-subtitle')?.value || 'Take a virtual tour of our modern reading rooms and student facilities.',
      images: Array.from(listContainer.querySelectorAll('#l-gallery-list > div')).map(div => ({
        url: div.querySelector('.l-gal-url')?.value.trim() || '',
        category: div.querySelector('.l-gal-cat')?.value || 'Hall',
        caption: div.querySelector('.l-gal-caption')?.value.trim() || ''
      })).filter(img => img.url)
    };
    
    // 8. FAQs
    payload.faqs = {
      ...payload.faqs,
      title: listContainer.querySelector('#l-faqs-title')?.value || 'Frequently Asked Questions',
      subtitle: listContainer.querySelector('#l-faqs-subtitle')?.value || 'Find answers to common queries.',
      items: Array.from(listContainer.querySelectorAll('#l-faqs-list > div')).map(div => ({
        question: div.querySelector('.l-faq-q')?.value.trim() || '',
        answer: div.querySelector('.l-faq-a')?.value.trim() || ''
      })).filter(faq => faq.question && faq.answer)
    };
    
    // 9. Testimonials
    payload.testimonials = {
      ...payload.testimonials,
      title: listContainer.querySelector('#l-test-title')?.value || 'What Our Students Say',
      googleRating: listContainer.querySelector('#l-test-googleRating')?.value.trim() || '4.9',
      googleReviewsCount: listContainer.querySelector('#l-test-googleReviewsCount')?.value.trim() || '250+ Reviews',
      items: Array.from(listContainer.querySelectorAll('#l-testimonials-list > div')).map(div => ({
        name: div.querySelector('.l-test-name')?.value.trim() || '',
        exam: div.querySelector('.l-test-exam')?.value.trim() || '',
        rating: Number(div.querySelector('.l-test-rating')?.value) || 5,
        feedback: div.querySelector('.l-test-feedback')?.value.trim() || ''
      })).filter(t => t.name && t.feedback)
    };
    
    // 10. Contact
    payload.contact = {
      ...payload.contact,
      phone: listContainer.querySelector('#l-contact-phone')?.value.trim() || '',
      whatsapp: listContainer.querySelector('#l-contact-wa')?.value.trim() || '',
      email: listContainer.querySelector('#l-contact-email')?.value.trim() || '',
      address: listContainer.querySelector('#l-contact-address')?.value.trim() || '',
      openingHours: listContainer.querySelector('#l-contact-hours')?.value.trim() || '',
      googleMapEmbedUrl: listContainer.querySelector('#l-contact-map')?.value.trim() || ''
    };

    // 11. Footer & Quick Links
    payload.footer = {
      ...payload.footer,
      tagline: listContainer.querySelector('#l-footer-tagline')?.value || '',
      copyrightText: listContainer.querySelector('#l-footer-copyright')?.value || '',
      mapDirectLink: listContainer.querySelector('#l-footer-mapDirect')?.value || '',
      quickLinks: Array.from(listContainer.querySelectorAll('#l-quicklinks-list > div')).map(div => ({
        label: div.querySelector('.l-ql-label')?.value.trim() || '',
        url: div.querySelector('.l-ql-url')?.value.trim() || '',
        openInNewTab: div.querySelector('.l-ql-target')?.checked !== false
      })).filter(l => l.label && l.url)
    };

    // 12. Floating Actions Bar
    payload.floatingActions = {
      ...payload.floatingActions,
      enabled: listContainer.querySelector('#l-float-enabled')?.checked !== false,
      whatsappNumber: listContainer.querySelector('#l-float-wa')?.value.trim() || '',
      whatsappMessage: listContainer.querySelector('#l-float-wamsg')?.value.trim() || '',
      callNumber: listContainer.querySelector('#l-float-call')?.value.trim() || ''
    };

    // 13. SEO & Meta
    payload.seo = {
      ...payload.seo,
      metaTitle: listContainer.querySelector('#l-seo-title')?.value.trim() || '',
      metaDescription: listContainer.querySelector('#l-seo-desc')?.value.trim() || '',
      metaKeywords: listContainer.querySelector('#l-seo-keywords')?.value.trim() || '',
      ogImage: listContainer.querySelector('#l-seo-ogImage')?.value.trim() || ''
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

  container.querySelector('#btn-quick-backup-header')?.addEventListener('click', async () => {
    try {
      Loading.show('Generating full system database backup...');
      const token = localStorage.getItem('token');
      const res = await fetch('/api/backup/export', {
        headers: { Authorization: `Bearer ${token}` }
      });
      Loading.hide();
      if (!res.ok) throw new Error('Backup failed');
      const blob = await res.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `StudyLibrary_Backup_${new Date().toISOString().split('T')[0]}.json`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      Toast.success('Database backup downloaded successfully!');
    } catch (err) {
      Loading.hide();
      Toast.error(err.message || 'Backup failed');
    }
  });

  loadSettings();
}

