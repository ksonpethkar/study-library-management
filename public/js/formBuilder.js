import api from './api.js';
import { Toast, Modal, Loading, Confirm, escapeHTML } from './ui.js';
import { MediaFieldPicker } from './mediaStudio.js';

const FIELD_ICONS = {
  text: '📝', textarea: '📄', number: '🔢', phone: '📱', email: '📧',
  date: '📅', time: '⏰', select: '📋', multiselect: '☑️', radio: '🔘',
  checkbox: '✅', file: '📎', photo_upload: '📸', signature_pad: '✍️',
  exam_badge: '🎯', blood_group: '🩸', url: '🔗', color: '🎨',
  address_autocomplete: '📍', aadhaar_pan: '🪪', terms_checkbox: '📜',
  star_rating: '⭐'
};

const SECTION_ICONS = {
  personal: '👤', academic: '📚', plan: '💎', payment: '💳', seat: '💺', other: '📝'
};

export class FormBuilder {
  static currentPreviewStep = 0;
  static previewDeviceMode = 'desktop'; // 'desktop' | 'mobile'

  static async render(container) {
    this.container = container;
    this.sections = [];
    this.fields = [];
    this.branches = [];
    this.plans = [];
    this.seats = [];
    this.template = {
      branding: {
        showLogo: true,
        showBanner: false,
        bannerImage: '',
        headerText: 'Student Admission Wizard',
        tagline: 'Silence, Focus & Success',
        alignment: 'center',
        logoSize: '64'
      }
    };
    this.selectedBranchId = null;
    this.selectedPlanId = null;
    this.selectedSeatId = null;
    this.selectedPaymentMode = 'upi';
    this.currentPreviewStep = 0;

    this.container.innerHTML = `
      <div class="form-builder-studio" style="display: flex; flex-direction: column; gap: 16px;">
        
        <!-- Studio Toolbar Header -->
        <div style="display: flex; justify-content: space-between; align-items: center; padding: 14px 20px; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); flex-wrap: wrap; gap: 12px;">
          <div>
            <h3 style="margin: 0; font-size: 1.15rem; font-weight: 800; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
              🎨 Registration Form Customizer & Live Preview Studio
            </h3>
            <p style="margin: 2px 0 0 0; font-size: 0.82rem; color: var(--color-text-secondary);">
              Full control over student registration header branding, section cards, system fields, and custom questions.
            </p>
          </div>

          <div style="display: flex; align-items: center; gap: 10px; flex-wrap: wrap;">
            <div class="btn-group" style="background: var(--color-bg-secondary); padding: 3px; border-radius: 8px; border: 1px solid var(--color-border);">
              <button type="button" class="btn btn-sm ${this.previewDeviceMode === 'desktop' ? 'btn-primary' : 'btn-ghost'}" id="fb-view-desktop" style="font-weight: 600; font-size: 0.78rem;">
                💻 Desktop Preview
              </button>
              <button type="button" class="btn btn-sm ${this.previewDeviceMode === 'mobile' ? 'btn-primary' : 'btn-ghost'}" id="fb-view-mobile" style="font-weight: 600; font-size: 0.78rem;">
                📱 Mobile Preview
              </button>
            </div>

            <button type="button" class="btn btn-outline-secondary btn-sm" id="fb-toggle-branding-panel" style="font-weight: 600;">
              🖼️ Header Branding
            </button>

            <button type="button" class="btn btn-outline-primary btn-sm" id="fb-add-section-btn" style="font-weight: 600;">
              📁 + Add Custom Section
            </button>

            <button type="button" class="btn btn-primary btn-sm" id="fb-add-field-btn" style="font-weight: 700;">
              ✨ + Add Question Field
            </button>
          </div>
        </div>

        <!-- Collapsible Header Branding Panel -->
        <div id="fb-branding-panel" style="display: none; background: var(--color-surface); border: 1.5px solid var(--color-primary); border-radius: var(--radius-lg); padding: 18px; box-shadow: var(--shadow-md);">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px; border-bottom: 1px solid var(--color-border); padding-bottom: 8px;">
            <h4 style="margin: 0; font-size: 1rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 6px;">
              🖼️ Public Registration Header Branding & Logo Studio
            </h4>
            <button type="button" class="btn btn-primary btn-sm" id="fb-save-branding-btn" style="font-weight: 700;">
              💾 Save Header Branding
            </button>
          </div>

          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 14px;">
            <div>
              <label class="form-label text-xs" style="font-weight: 700;">Header Title Text</label>
              <input type="text" id="branding-headerText" class="form-control form-control-sm" value="${escapeHTML(this.template.branding?.headerText || 'Student Admission Wizard')}">
            </div>

            <div>
              <label class="form-label text-xs" style="font-weight: 700;">Tagline / Slogan</label>
              <input type="text" id="branding-tagline" class="form-control form-control-sm" value="${escapeHTML(this.template.branding?.tagline || 'Silence, Focus & Success')}">
            </div>

            <div>
              <label class="form-label text-xs" style="font-weight: 700;">Header Alignment</label>
              <select id="branding-alignment" class="form-select form-control-sm">
                <option value="center">Center Aligned</option>
                <option value="left">Left Aligned</option>
              </select>
            </div>

            <div>
              <label class="form-label text-xs" style="font-weight: 700;">Logo Size</label>
              <select id="branding-logoSize" class="form-select form-control-sm">
                <option value="48">Small (48px)</option>
                <option value="64" selected>Medium (64px)</option>
                <option value="96">Large (96px)</option>
              </select>
            </div>
          </div>
        </div>

        <!-- Split-Screen Studio Canvas -->
        <div class="fb-split-wrapper" style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px; align-items: start;">
          
          <!-- Left Pane: Form Structure & Question Controls -->
          <div class="fb-left-pane" style="display: flex; flex-direction: column; gap: 16px;">
            <div class="card p-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
              <div style="font-size: 0.85rem; font-weight: 700; color: var(--color-text-secondary); text-transform: uppercase; margin-bottom: 12px; display: flex; justify-content: space-between; align-items: center;">
                <span>📋 Registration Form Sections & Questions</span>
                <span style="color: var(--color-primary); font-size: 0.78rem;">Live Auto-Sync ⚡</span>
              </div>
              <div id="fb-sections-container" style="display: flex; flex-direction: column; gap: 14px;"></div>
            </div>
          </div>

          <!-- Right Pane: Live Interactive Student Preview Canvas -->
          <div class="fb-right-pane" style="position: sticky; top: 80px;">
            <div class="card p-0" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden; box-shadow: var(--shadow-md);">
              <div class="card-header" style="padding: 10px 16px; background: var(--color-surface-hover); border-bottom: 1px solid var(--color-border); display: flex; justify-content: space-between; align-items: center;">
                <span style="font-size: 0.85rem; font-weight: 700; color: var(--color-text-primary); display: flex; align-items: center; gap: 6px;">
                  👁️ Real-Time Student Registration Preview (/register)
                </span>
                <span class="badge badge-success" style="font-size: 0.7rem; font-weight: 700;">SYNCED LIVE</span>
              </div>

              <!-- Device Container -->
              <div id="fb-preview-device-wrap" style="padding: 16px; transition: all 0.3s ease; margin: 0 auto; width: 100%;">
                <div id="fb-live-preview" style="background: var(--color-bg-primary); border-radius: 12px; padding: 18px; border: 1px solid var(--color-border);"></div>
              </div>
            </div>
          </div>

        </div>
      </div>
    `;

    await this.loadData();
    this.bindEvents();
  }

  static async loadData() {
    try {
      const [fieldsRes, tplRes, branchRes, planRes, seatRes] = await Promise.all([
        api.get('/api/custom-fields/all').catch(() => ({ data: [] })),
        api.get('/api/custom-fields/templates/active').catch(() => ({ data: null })),
        api.get('/api/branches/public-list').catch(() => ({ data: [] })),
        api.get('/api/plans').catch(() => ({ data: [] })),
        api.get('/api/seats?status=available').catch(() => ({ data: [] }))
      ]);

      this.fields = (fieldsRes && Array.isArray(fieldsRes.data)) ? fieldsRes.data : [];
      if (tplRes && tplRes.data) {
        this.template = tplRes.data;
      }
      this.branches = (branchRes && Array.isArray(branchRes.data)) ? branchRes.data : [];
      this.plans = (planRes && Array.isArray(planRes.data)) ? planRes.data : [];
      this.seats = (seatRes && Array.isArray(seatRes.data)) ? seatRes.data : [];

      if (this.branches.length > 0) {
        this.selectedBranchId = this.branches[0]._id;
      }
      if (this.plans.length > 0) {
        this.selectedPlanId = this.plans[0]._id;
      }

      // Populate sections (Step 1 to Step 5)
      const defaultSecs = [
        { name: 'personal', label: 'Step 1: Study Centre & Personal Info', icon: 'personal', order: 1, isSystem: true },
        { name: 'academic', label: 'Step 2: Academic Goals & KYC Proof', icon: 'academic', order: 2, isSystem: false },
        { name: 'plan', label: 'Step 3: Membership Plan & Fee Calculator', icon: 'plan', order: 3, isSystem: true },
        { name: 'payment', label: 'Step 4: Dynamic Payment Selection', icon: 'payment', order: 4, isSystem: true },
        { name: 'seat', label: 'Step 5: Seat Selection & Digital Signature', icon: 'seat', order: 5, isSystem: true }
      ];

      const sectionsMap = new Map();
      defaultSecs.forEach(s => sectionsMap.set(s.name, s));

      this.fields.forEach(f => {
        if (f.section && !sectionsMap.has(f.section)) {
          sectionsMap.set(f.section, {
            name: f.section,
            label: f.sectionLabel || `Section: ${f.section.toUpperCase()}`,
            icon: f.sectionIcon || 'other',
            order: sectionsMap.size + 1,
            isSystem: false
          });
        }
      });

      this.sections = Array.from(sectionsMap.values()).sort((a, b) => a.order - b.order);

      this.renderSections();
      this.renderPreview();
    } catch (err) {
      console.error('Failed to load form builder data:', err);
      const defaultSecs = [
        { name: 'personal', label: 'Step 1: Study Centre & Personal Info', icon: 'personal', order: 1, isSystem: true },
        { name: 'academic', label: 'Step 2: Academic Goals & KYC Proof', icon: 'academic', order: 2, isSystem: false },
        { name: 'plan', label: 'Step 3: Membership Plan & Fee Calculator', icon: 'plan', order: 3, isSystem: true },
        { name: 'payment', label: 'Step 4: Dynamic Payment Selection', icon: 'payment', order: 4, isSystem: true },
        { name: 'seat', label: 'Step 5: Seat Selection & Digital Signature', icon: 'seat', order: 5, isSystem: true }
      ];
      this.sections = defaultSecs;
      this.renderSections();
      this.renderPreview();
    }
  }

  static renderSections() {
    const container = document.getElementById('fb-sections-container');
    if (!container) return;

    this.sections.sort((a, b) => a.order - b.order);

    container.innerHTML = this.sections.map((sec, secIdx) => {
      const secFields = this.fields
        .filter(f => (f.section || 'personal') === sec.name)
        .sort((a, b) => (a.order || 0) - (b.order || 0));

      const isCoreSec = ['personal', 'plan', 'payment', 'seat'].includes(sec.name);

      return `
        <div class="fb-sec-card" data-section="${sec.name}" style="background: var(--color-surface-hover); border: 1px solid var(--color-border); border-radius: 10px; overflow: hidden; margin-bottom: 12px;">
          <div style="padding: 10px 14px; background: var(--color-bg-secondary); border-bottom: 1px solid var(--color-border); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
            <div style="display: flex; align-items: center; gap: 8px; font-weight: 700; font-size: 0.92rem; color: var(--color-primary);">
              <span>${SECTION_ICONS[sec.icon] || '📁'}</span>
              <span>${escapeHTML(sec.label)}</span>
              <span class="badge badge-secondary" style="font-size: 0.7rem;">${sec.isSystem ? 'System Component' : secFields.length + ' Questions'}</span>
            </div>

            <div style="display: flex; align-items: center; gap: 4px;">
              ${secIdx > 0 ? `<button type="button" class="btn btn-sm btn-ghost fb-sec-up" data-sec="${sec.name}" title="Move Section Up">⬆️</button>` : ''}
              ${secIdx < this.sections.length - 1 ? `<button type="button" class="btn btn-sm btn-ghost fb-sec-down" data-sec="${sec.name}" title="Move Section Down">⬇️</button>` : ''}
              <button type="button" class="btn btn-sm btn-outline-primary fb-sec-add-field" data-sec="${sec.name}" title="Add Question to this Section" style="font-size: 0.75rem; padding: 2px 8px;">➕ Add Question</button>
              ${!isCoreSec ? `<button type="button" class="btn btn-sm btn-ghost text-danger fb-sec-delete" data-sec="${sec.name}" title="Delete Section" style="font-size: 0.75rem; padding: 2px 6px;">🗑️ Delete</button>` : ''}
            </div>
          </div>

          <div style="padding: 10px; display: flex; flex-direction: column; gap: 8px;">
            ${sec.isSystem && secFields.length === 0 ? this.renderSystemComponentCard(sec) : ''}

            ${secFields.map((field, fIdx) => this.renderFieldCard(field, fIdx, secFields.length)).join('')}
          </div>
        </div>
      `;
    }).join('');

    // Attach Section & Question Action Listeners
    container.querySelectorAll('.fb-sec-up').forEach(btn => {
      btn.addEventListener('click', () => this.moveSection(btn.dataset.sec, -1));
    });

    container.querySelectorAll('.fb-sec-down').forEach(btn => {
      btn.addEventListener('click', () => this.moveSection(btn.dataset.sec, 1));
    });

    container.querySelectorAll('.fb-sec-add-field').forEach(btn => {
      btn.addEventListener('click', () => this.openFieldEditor(null, btn.dataset.sec));
    });

    container.querySelectorAll('.fb-sec-delete').forEach(btn => {
      btn.addEventListener('click', () => this.deleteSection(btn.dataset.sec));
    });

    container.querySelectorAll('.fb-field-edit').forEach(btn => {
      btn.addEventListener('click', () => this.openFieldEditor(btn.dataset.id));
    });

    container.querySelectorAll('.fb-field-toggle').forEach(btn => {
      btn.addEventListener('click', () => this.toggleFieldActive(btn.dataset.id));
    });

    container.querySelectorAll('.fb-field-delete').forEach(btn => {
      btn.addEventListener('click', () => this.deleteField(btn.dataset.id));
    });

    container.querySelectorAll('.fb-field-up').forEach(btn => {
      btn.addEventListener('click', () => this.moveField(btn.dataset.id, -1));
    });

    container.querySelectorAll('.fb-field-down').forEach(btn => {
      btn.addEventListener('click', () => this.moveField(btn.dataset.id, 1));
    });
  }

  static renderSystemComponentCard(sec) {
    if (sec.name === 'plan') {
      const planCards = (this.plans && this.plans.length > 0)
        ? this.plans.map(p => `
            <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 6px; padding: 8px 10px; font-size: 0.8rem;">
              <div style="font-weight: 700; color: var(--color-text-primary);">${escapeHTML(p.name)}</div>
              <div style="color: var(--color-primary); font-weight: 800; font-size: 0.88rem; margin: 2px 0;">₹${p.price} <small style="font-weight: 400; color: var(--color-text-secondary);">/ ${p.duration || 1} ${p.durationType || 'month'}</small></div>
              <div style="font-size: 0.72rem; color: var(--color-text-secondary);">Shift: ${escapeHTML(p.shift || 'Any Shift')}</div>
            </div>
          `).join('')
        : `
            <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 6px; padding: 8px 10px; font-size: 0.8rem;">
              <div style="font-weight: 700; color: var(--color-text-primary);">💎 Full Day 24-Hour Plan</div>
              <div style="color: var(--color-primary); font-weight: 800; font-size: 0.88rem;">₹1,800 / Month</div>
              <div style="font-size: 0.72rem; color: var(--color-text-secondary);">Shift: All Day (24 Hours)</div>
            </div>
            <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 6px; padding: 8px 10px; font-size: 0.8rem;">
              <div style="font-weight: 700; color: var(--color-text-primary);">🌅 Morning Shift Plan</div>
              <div style="color: var(--color-primary); font-weight: 800; font-size: 0.88rem;">₹1,200 / Month</div>
              <div style="font-size: 0.72rem; color: var(--color-text-secondary);">Shift: Morning (7 AM - 5 PM)</div>
            </div>
          `;

      return `
        <div style="background: var(--color-surface); border: 1.5px dashed var(--color-primary); border-radius: 8px; padding: 12px; font-size: 0.83rem;">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
            <div style="font-weight: 700; color: var(--color-primary); font-size: 0.88rem;">
              💎 Live Membership Plans & Sub-Options Breakdown (${this.plans?.length || 2} Active Plans)
            </div>
            <span class="badge badge-primary" style="font-size: 0.68rem;">SYSTEM COMPONENT</span>
          </div>
          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 8px; margin-bottom: 10px;">
            ${planCards}
          </div>
          <div style="font-size: 0.73rem; color: var(--color-text-secondary); display: flex; flex-wrap: wrap; gap: 12px; background: var(--color-bg-secondary); padding: 6px 10px; border-radius: 6px;">
            <span>✅ Dynamic Shift Selection</span>
            <span>✅ Fee Breakdown & Tax Calculator</span>
            <span>✅ Referral Promo Code</span>
          </div>
        </div>
      `;
    }

    if (sec.name === 'payment') {
      return `
        <div style="background: var(--color-surface); border: 1.5px dashed var(--color-primary); border-radius: 8px; padding: 12px; font-size: 0.83rem;">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
            <div style="font-weight: 700; color: var(--color-primary); font-size: 0.88rem;">
              💳 Live Payment Methods & Sub-Option Gateway Breakdown
            </div>
            <span class="badge badge-primary" style="font-size: 0.68rem;">SYSTEM COMPONENT</span>
          </div>
          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); gap: 8px; margin-bottom: 10px;">
            <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 6px; padding: 8px 10px; font-size: 0.8rem;">
              <div style="font-weight: 700; color: var(--color-text-primary);">⚡ Dynamic UPI QR</div>
              <div style="font-size: 0.72rem; color: var(--color-text-secondary);">GPay / PhonePe / Paytm + 12-digit UTR Verification</div>
            </div>
            <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 6px; padding: 8px 10px; font-size: 0.8rem;">
              <div style="font-weight: 700; color: var(--color-text-primary);">💵 Pay Later at Desk</div>
              <div style="font-size: 0.72rem; color: var(--color-text-secondary);">Pre-reserves admission & seat; cash paid on arrival</div>
            </div>
            <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 6px; padding: 8px 10px; font-size: 0.8rem;">
              <div style="font-weight: 700; color: var(--color-text-primary);">🏦 NetBanking / Cards</div>
              <div style="font-size: 0.72rem; color: var(--color-text-secondary);">Bank reference logging & printable receipt generator</div>
            </div>
          </div>
          <div style="font-size: 0.73rem; color: var(--color-text-secondary); display: flex; flex-wrap: wrap; gap: 12px; background: var(--color-bg-secondary); padding: 6px 10px; border-radius: 6px;">
            <span>✅ Automated WhatsApp Receipt</span>
            <span>✅ Email Payment Confirmation</span>
            <span>✅ Tax Invoice Generation</span>
          </div>
        </div>
      `;
    }

    if (sec.name === 'seat') {
      return `
        <div style="background: var(--color-surface); border: 1.5px dashed var(--color-primary); border-radius: 8px; padding: 12px; font-size: 0.83rem;">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
            <div style="font-weight: 700; color: var(--color-primary); font-size: 0.88rem;">
              🪑 Live Seat Selection Map & Digital Signature Sub-Options
            </div>
            <span class="badge badge-primary" style="font-size: 0.68rem;">SYSTEM COMPONENT</span>
          </div>
          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); gap: 8px; margin-bottom: 10px;">
            <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 6px; padding: 8px 10px; font-size: 0.8rem;">
              <div style="font-weight: 700; color: var(--color-text-primary);">🔴/🟢 Circular Seat Badges</div>
              <div style="font-size: 0.72rem; color: var(--color-text-secondary);">22px round circular seat checkmarks with Indigo glow</div>
            </div>
            <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 6px; padding: 8px 10px; font-size: 0.8rem;">
              <div style="font-weight: 700; color: var(--color-text-primary);">✍️ Digital Signature Canvas</div>
              <div style="font-size: 0.72rem; color: var(--color-text-secondary);">Touch & stylus interactive drawing pad</div>
            </div>
            <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 6px; padding: 8px 10px; font-size: 0.8rem;">
              <div style="font-weight: 700; color: var(--color-text-primary);">📸 Passport Selfie Capture</div>
              <div style="font-size: 0.72rem; color: var(--color-text-secondary);">Webcam photo & document crop studio</div>
            </div>
          </div>
          <div style="font-size: 0.73rem; color: var(--color-text-secondary); display: flex; flex-wrap: wrap; gap: 12px; background: var(--color-bg-secondary); padding: 6px 10px; border-radius: 6px;">
            <span>✅ Quiet Study Code Agreement</span>
            <span>✅ Kiosk Entry Barcode</span>
          </div>
        </div>
      `;
    }

    return `
      <div style="background: var(--color-surface); border: 1px dashed var(--color-primary); border-radius: 8px; padding: 10px 12px; font-size: 0.82rem; color: var(--color-text-secondary); display: flex; justify-content: space-between; align-items: center;">
        <span>⚙️ Integrated System Component (${escapeHTML(sec.label)})</span>
        <span class="badge badge-primary">SYSTEM STEP</span>
      </div>
    `;
  }

  static renderFieldCard(field, index, total) {
    const icon = FIELD_ICONS[field.type] || '📝';
    const isRequired = !!field.required;
    const isActive = field.isActive !== false;

    return `
      <div class="fb-field-row" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: 8px; padding: 10px 12px; display: flex; justify-content: space-between; align-items: center; opacity: ${isActive ? '1' : '0.55'};">
        <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
          <span style="font-size: 1.1rem; flex-shrink: 0;">${icon}</span>
          <div style="overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
            <div style="font-weight: 600; font-size: 0.88rem; color: var(--color-text-primary);">
              ${escapeHTML(field.label)}
              ${isRequired ? '<span style="color: var(--color-danger);">*</span>' : ''}
            </div>
            <div style="font-size: 0.72rem; color: var(--color-text-secondary); display: flex; gap: 6px; align-items: center;">
              <span class="badge" style="background: var(--color-bg-secondary); padding: 1px 5px; border-radius: 3px;">${escapeHTML(field.type)}</span>
              <code>${escapeHTML(field.fieldName || field.name || '')}</code>
              ${field.colSpan === 6 ? '<span style="color: var(--color-info);">[50% Width]</span>' : ''}
            </div>
          </div>
        </div>

        <div style="display: flex; align-items: center; gap: 4px; flex-shrink: 0;">
          ${index > 0 ? `<button type="button" class="btn btn-sm btn-ghost fb-field-up" data-id="${field._id}" title="Move Question Up">⬆️</button>` : ''}
          ${index < total - 1 ? `<button type="button" class="btn btn-sm btn-ghost fb-field-down" data-id="${field._id}" title="Move Question Down">⬇️</button>` : ''}
          
          <button type="button" class="btn btn-sm btn-ghost fb-field-toggle" data-id="${field._id}" title="${isActive ? 'Hide Question' : 'Show Question'}">
            ${isActive ? '🟢 Active' : '⚪ Hidden'}
          </button>
          
          <button type="button" class="btn btn-sm btn-outline-primary fb-field-edit" data-id="${field._id}" style="font-size: 0.75rem;">
            ✏️ Edit
          </button>

          <button type="button" class="btn btn-sm btn-ghost text-danger fb-field-delete" data-id="${field._id}" title="Delete Question" style="font-size: 0.75rem;">
            🗑️ Delete
          </button>
        </div>
      </div>
    `;
  }

  static renderPreview() {
    const container = document.getElementById('fb-live-preview');
    if (!container) return;

    if (this.sections.length === 0) {
      container.innerHTML = '<div class="text-center p-4 text-muted">No sections configured.</div>';
      return;
    }

    if (this.currentPreviewStep >= this.sections.length) {
      this.currentPreviewStep = 0;
    }

    const currentSec = this.sections[this.currentPreviewStep];
    const totalSteps = this.sections.length;

    const secFields = this.fields
      .filter(f => (f.section || 'personal') === currentSec.name && f.isActive !== false)
      .sort((a, b) => (a.order || 0) - (b.order || 0));

    const b = this.template.branding || {};
    const headerTitle = b.headerText || 'Student Admission Wizard';
    const tagline = b.tagline || 'Silence, Focus & Success';
    const align = b.alignment === 'left' ? 'left' : 'center';

    let html = `
      <!-- Form Header Branding Preview -->
      <div style="margin-bottom: 16px; text-align: ${align}; border-bottom: 1px solid var(--color-border); padding-bottom: 12px;">
        <div style="font-size: 2rem; margin-bottom: 4px;">🎓</div>
        <h3 style="margin: 0; font-size: 1.25rem; font-weight: 800; color: var(--color-text-primary);">${escapeHTML(headerTitle)}</h3>
        <p style="margin: 3px 0 0 0; font-size: 0.83rem; color: var(--color-text-secondary);">${escapeHTML(tagline)}</p>
      </div>

      <!-- Stepper Progress Dots -->
      <div style="display: flex; justify-content: space-between; margin-bottom: 16px; position: relative;">
        <div style="position: absolute; top: 12px; left: 10px; right: 10px; height: 2px; background: var(--color-border); z-index: 1;"></div>
        ${this.sections.map((sec, i) => `
          <div style="position: relative; z-index: 2; width: 26px; height: 26px; border-radius: 50%; background: ${i <= this.currentPreviewStep ? '#6c5ce7' : 'var(--color-surface)'}; border: 2px solid ${i <= this.currentPreviewStep ? '#6c5ce7' : 'var(--color-border)'}; color: ${i <= this.currentPreviewStep ? '#ffffff' : 'var(--color-text-secondary)'}; display: flex; align-items: center; justify-content: center; font-size: 0.75rem; font-weight: 800;">
            ${i + 1}
          </div>
        `).join('')}
      </div>

      <!-- Step Card -->
      <div class="card p-3 mb-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: 10px;">
        <h4 style="margin: 0 0 14px 0; font-size: 0.95rem; font-weight: 800; color: #6c5ce7; border-bottom: 2px solid #6c5ce7; padding-bottom: 6px; display: flex; align-items: center; gap: 6px;">
          <span>${SECTION_ICONS[currentSec.icon] || '📁'}</span> ${escapeHTML(currentSec.label)}
        </h4>

        ${this.renderSectionContent(currentSec, secFields)}
      </div>

      <!-- Navigation Buttons -->
      <div style="display: flex; gap: 10px; margin-top: 14px;">
        ${this.currentPreviewStep > 0 ? `<button type="button" id="fb-prev-step" class="btn btn-outline-secondary btn-sm" style="flex: 1; font-weight: 700;">⬅️ Previous Section</button>` : ''}
        ${this.currentPreviewStep < totalSteps - 1 ? `<button type="button" id="fb-next-step" class="btn btn-primary btn-sm" style="flex: 1; font-weight: 700;">Next Section ➡️</button>` : ''}
        ${this.currentPreviewStep === totalSteps - 1 ? `<button type="button" class="btn btn-success btn-sm" style="flex: 1; font-weight: 700;">🚀 Complete Admission & Payment</button>` : ''}
      </div>
    `;

    container.innerHTML = html;

    // Navigation events
    container.querySelector('#fb-prev-step')?.addEventListener('click', () => {
      this.currentPreviewStep--;
      this.renderPreview();
    });

    container.querySelector('#fb-next-step')?.addEventListener('click', () => {
      this.currentPreviewStep++;
      this.renderPreview();
    });

    // Branch selector event in Step 1
    container.querySelector('#prev-branch-select')?.addEventListener('change', (e) => {
      this.selectedBranchId = e.target.value;
      this.renderPreview();
    });

    // Plan selector event in Step 3
    container.querySelector('#prev-plan-select')?.addEventListener('change', (e) => {
      this.selectedPlanId = e.target.value;
      this.renderPreview();
    });

    // Payment mode selector event in Step 4
    container.querySelectorAll('input[name="prev-pm-mode"]').forEach(radio => {
      radio.addEventListener('change', (e) => {
        this.selectedPaymentMode = e.target.value;
        this.renderPreview();
      });
    });
  }

  static renderSectionContent(currentSec, secFields) {
    const secName = currentSec.name;

    // STEP 1: Personal & Centre Info
    if (secName === 'personal') {
      const branchOptions = this.branches.map(b => `<option value="${b._id}" ${this.selectedBranchId === b._id ? 'selected' : ''}>${escapeHTML(b.name)} — 🟢 ${b.availableSeats || 42}/${b.totalSeats || 100} Available Seats</option>`).join('');

      return `
        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 12px;">
          <div style="grid-column: 1 / -1;">
            <label class="form-label text-xs" style="font-weight:700;">Preferred Study Centre / Branch *</label>
            <select class="form-select form-control-sm" id="prev-branch-select">${branchOptions || '<option>Main Centre (Default)</option>'}</select>
          </div>

          <div>
            <label class="form-label text-xs" style="font-weight:600;">Full Name *</label>
            <input type="text" class="form-control form-control-sm" placeholder="e.g. Rahul Sharma">
          </div>

          <div>
            <label class="form-label text-xs" style="font-weight:600;">Mobile / WhatsApp Number *</label>
            <input type="text" class="form-control form-control-sm" placeholder="10-digit mobile number">
          </div>

          <div>
            <label class="form-label text-xs" style="font-weight:600;">Email Address</label>
            <input type="email" class="form-control form-control-sm" placeholder="student@example.com">
          </div>

          <div>
            <label class="form-label text-xs" style="font-weight:600;">Gender</label>
            <select class="form-select form-control-sm">
              <option>Male</option>
              <option>Female</option>
              <option>Other</option>
            </select>
          </div>

          <div>
            <label class="form-label text-xs" style="font-weight:600;">Date of Birth</label>
            <input type="date" class="form-control form-control-sm">
          </div>

          <div>
            <label class="form-label text-xs" style="font-weight:600;">Pincode (Auto-Fill)</label>
            <input type="text" class="form-control form-control-sm" placeholder="6-digit pincode e.g. 413512">
          </div>

          <div>
            <label class="form-label text-xs" style="font-weight:600;">City</label>
            <input type="text" class="form-control form-control-sm" placeholder="Auto-filled city">
          </div>

          <div>
            <label class="form-label text-xs" style="font-weight:600;">State</label>
            <input type="text" class="form-control form-control-sm" placeholder="Auto-filled state">
          </div>

          ${secFields.map(f => this.renderPreviewInput(f)).join('')}
        </div>
      `;
    }

    // STEP 3: Membership Plan & Fee Calculator
    if (secName === 'plan') {
      const planOptions = this.plans.map(p => `<option value="${p._id}" ${this.selectedPlanId === p._id ? 'selected' : ''}>${escapeHTML(p.name)} — ₹${p.price} / ${p.duration} ${p.durationType} (${p.shift ? p.shift.toUpperCase() : 'ANY SHIFT'})</option>`).join('');
      const selectedPlan = this.plans.find(p => p._id === this.selectedPlanId) || this.plans[0] || { name: 'Standard Full Day Plan', price: 1500, shift: 'All Day (24 Hours)' };

      return `
        <div style="display: flex; flex-direction: column; gap: 12px;">
          <div>
            <label class="form-label text-xs" style="font-weight:700;">Select Membership Plan *</label>
            <select class="form-select form-control-sm" id="prev-plan-select">${planOptions || '<option>Standard 12-Hour Study Plan (₹1,500/mo)</option>'}</select>
          </div>

          <div style="display: flex; gap: 8px;">
            <input type="text" class="form-control form-control-sm" placeholder="Referral / Discount Code (Optional)">
            <button type="button" class="btn btn-outline-primary btn-sm" style="font-weight:700;">Apply</button>
          </div>

          <!-- Fee Summary Card -->
          <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 12px; font-size: 0.85rem;">
            <div style="font-weight: 700; color: var(--color-primary); margin-bottom: 6px;">💰 Live Fee Breakdown</div>
            <div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
              <span>Base Plan Fee (${escapeHTML(selectedPlan.name)})</span>
              <span style="font-weight:700;">₹${selectedPlan.price || 1500}</span>
            </div>
            <div style="display: flex; justify-content: space-between; margin-bottom: 4px; color: var(--color-success);">
              <span>Referral Discount</span>
              <span style="font-weight:700;">-₹0</span>
            </div>
            <div style="display: flex; justify-content: space-between; border-top: 1px solid var(--color-border); padding-top: 6px; font-weight: 800; font-size: 0.95rem;">
              <span>Net Payable Amount</span>
              <span style="color: var(--color-primary);">₹${selectedPlan.price || 1500}</span>
            </div>
          </div>

          ${secFields.map(f => this.renderPreviewInput(f)).join('')}
        </div>
      `;
    }

    // STEP 4: Dynamic Payment Selection
    if (secName === 'payment') {
      return `
        <div style="display: flex; flex-direction: column; gap: 12px;">
          <label class="form-label text-xs" style="font-weight:700;">Select Payment Mode *</label>
          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(130px, 1fr)); gap: 8px;">
            <label style="border: 1px solid var(--color-border); border-radius: 8px; padding: 10px; font-size: 0.8rem; font-weight: 600; cursor: pointer; display: flex; align-items: center; gap: 6px; background: ${this.selectedPaymentMode === 'upi' ? 'var(--color-surface-hover)' : 'transparent'};">
              <input type="radio" name="prev-pm-mode" value="upi" ${this.selectedPaymentMode === 'upi' ? 'checked' : ''}> 📱 Dynamic UPI QR
            </label>
            <label style="border: 1px solid var(--color-border); border-radius: 8px; padding: 10px; font-size: 0.8rem; font-weight: 600; cursor: pointer; display: flex; align-items: center; gap: 6px; background: ${this.selectedPaymentMode === 'card' ? 'var(--color-surface-hover)' : 'transparent'};">
              <input type="radio" name="prev-pm-mode" value="card" ${this.selectedPaymentMode === 'card' ? 'checked' : ''}> 💳 Card / NetBank
            </label>
            <label style="border: 1px solid var(--color-border); border-radius: 8px; padding: 10px; font-size: 0.8rem; font-weight: 600; cursor: pointer; display: flex; align-items: center; gap: 6px; background: ${this.selectedPaymentMode === 'desk' ? 'var(--color-surface-hover)' : 'transparent'};">
              <input type="radio" name="prev-pm-mode" value="desk" ${this.selectedPaymentMode === 'desk' ? 'checked' : ''}> 💵 Pay at Desk
            </label>
          </div>

          ${this.selectedPaymentMode === 'upi' ? `
            <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 12px; text-align: center;">
              <div style="font-weight: 700; font-size: 0.85rem; margin-bottom: 6px;">⚡ Scan QR Code or Pay via Mobile UPI App</div>
              <div style="width: 130px; height: 130px; background: #fff; border: 1px solid var(--color-border); border-radius: 8px; margin: 0 auto 10px auto; display: flex; align-items: center; justify-content: center; padding: 4px;">
                <img src="https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=upi://pay?pa=thecozycorner@okaxis" style="width:100%;height:100%;object-fit:contain;">
              </div>
              <div style="display: flex; justify-content: center; gap: 4px; flex-wrap: wrap; margin-bottom: 8px;">
                <span class="badge badge-primary" style="font-size:0.68rem;">🔵 GPay</span>
                <span class="badge badge-primary" style="font-size:0.68rem;">🟣 PhonePe</span>
                <span class="badge badge-primary" style="font-size:0.68rem;">💙 Paytm</span>
              </div>
              <input type="text" class="form-control form-control-sm" placeholder="Enter 12-digit UPI UTR / Transaction No. *" required style="max-width: 320px; margin: 0 auto;">
            </div>
          ` : ''}

          ${secFields.map(f => this.renderPreviewInput(f)).join('')}
        </div>
      `;
    }

    // STEP 5: Seat Selection & Digital Signature
    if (secName === 'seat') {
      const availSeats = this.seats.length > 0 ? this.seats : [
        { seatNumber: 'A-01', zone: 'Quiet Zone' }, { seatNumber: 'A-02', zone: 'Quiet Zone' },
        { seatNumber: 'A-03', zone: 'Quiet Zone' }, { seatNumber: 'B-01', zone: 'General Desk' }
      ];

      return `
        <div style="display: flex; flex-direction: column; gap: 12px;">
          <label class="form-label text-xs" style="font-weight:700;">Choose Your Study Desk Seat *</label>
          <div style="display: flex; gap: 8px; overflow-x: auto; padding-bottom: 6px;">
            ${availSeats.slice(0, 6).map((s, idx) => `
              <div style="min-width: 65px; padding: 8px; border: 2px solid ${idx === 0 ? '#6c5ce7' : 'var(--color-border)'}; border-radius: 8px; text-align: center; cursor: pointer; background: ${idx === 0 ? 'rgba(108, 92, 231, 0.1)' : 'var(--color-surface)'};">
                <div style="font-weight: 800; font-size: 0.9rem; color: #6c5ce7;">${escapeHTML(s.seatNumber)}</div>
                <div style="font-size: 0.65rem; color: var(--color-text-secondary);">${escapeHTML(s.zone || 'General')}</div>
              </div>
            `).join('')}
          </div>

          <label class="form-label text-xs" style="font-weight:700;">Digital Signature Pad *</label>
          <div style="width: 100%; height: 80px; border: 1.5px dashed var(--color-border); border-radius: 8px; background: #ffffff; display: flex; align-items: center; justify-content: center; color: var(--color-text-secondary); font-size: 0.8rem;">
            ✍️ Draw student signature canvas
          </div>

          ${secFields.map(f => this.renderPreviewInput(f)).join('')}
        </div>
      `;
    }

    // Default Section Fields
    return `
      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 12px;">
        ${secFields.length ? secFields.map(f => this.renderPreviewInput(f)).join('') : '<div class="text-muted small p-3 text-center">No questions in this section card.</div>'}
      </div>
    `;
  }

  static renderPreviewInput(field) {
    const isReq = !!field.required;
    const reqBadge = isReq ? ' <span style="color: var(--color-danger);">*</span>' : '';
    const colStyle = field.colSpan === 6 ? 'grid-column: span 1;' : 'grid-column: 1 / -1;';
    const label = `${escapeHTML(field.label)}${reqBadge}`;
    const help = field.helpText ? `<small class="text-muted" style="display:block; font-size:0.7rem; margin-top:3px;">${escapeHTML(field.helpText)}</small>` : '';

    if (field.type === 'select') {
      const opts = (field.options || []).map(o => `<option>${escapeHTML(o)}</option>`).join('');
      return `
        <div style="${colStyle}">
          <label class="form-label text-xs" style="font-weight:600;">${label}</label>
          <select class="form-select form-control-sm"><option value="">-- Select --</option>${opts}</select>
          ${help}
        </div>
      `;
    }

    if (field.type === 'radio') {
      const opts = (field.options || []).map((o, idx) => `
        <label style="font-size:0.8rem; margin-right:8px; display:inline-flex; align-items:center; gap:4px;">
          <input type="radio" name="prev_${field._id}" ${idx === 0 ? 'checked' : ''}> ${escapeHTML(o)}
        </label>
      `).join('');
      return `
        <div style="${colStyle}">
          <label class="form-label text-xs" style="font-weight:600;">${label}</label>
          <div>${opts}</div>
          ${help}
        </div>
      `;
    }

    if (field.type === 'textarea') {
      return `
        <div style="${colStyle}">
          <label class="form-label text-xs" style="font-weight:600;">${label}</label>
          <textarea class="form-control form-control-sm" rows="2" placeholder="${escapeHTML(field.placeholder || '')}"></textarea>
          ${help}
        </div>
      `;
    }

    return `
      <div style="${colStyle}">
        <label class="form-label text-xs" style="font-weight:600;">${label}</label>
        <input type="${field.type === 'number' ? 'number' : field.type === 'date' ? 'date' : 'text'}" class="form-control form-control-sm" placeholder="${escapeHTML(field.placeholder || '')}">
        ${help}
      </div>
    `;
  }

  static bindEvents() {
    // Device toggle
    document.getElementById('fb-view-desktop')?.addEventListener('click', () => {
      this.previewDeviceMode = 'desktop';
      const wrap = document.getElementById('fb-preview-device-wrap');
      if (wrap) { wrap.style.maxWidth = '100%'; wrap.style.padding = '16px'; }
      document.getElementById('fb-view-desktop').classList.replace('btn-ghost', 'btn-primary');
      document.getElementById('fb-view-mobile').classList.replace('btn-primary', 'btn-ghost');
    });

    document.getElementById('fb-view-mobile')?.addEventListener('click', () => {
      this.previewDeviceMode = 'mobile';
      const wrap = document.getElementById('fb-preview-device-wrap');
      if (wrap) { wrap.style.maxWidth = '375px'; wrap.style.padding = '8px'; }
      document.getElementById('fb-view-mobile').classList.replace('btn-ghost', 'btn-primary');
      document.getElementById('fb-view-desktop').classList.replace('btn-primary', 'btn-ghost');
    });

    // Toggle Branding Panel
    document.getElementById('fb-toggle-branding-panel')?.addEventListener('click', () => {
      const panel = document.getElementById('fb-branding-panel');
      if (panel) {
        panel.style.display = panel.style.display === 'none' ? 'block' : 'none';
      }
    });

    // Branding Live Preview Inputs
    ['headerText', 'tagline', 'alignment', 'logoSize'].forEach(key => {
      document.getElementById(`branding-${key}`)?.addEventListener('input', (e) => {
        if (!this.template.branding) this.template.branding = {};
        this.template.branding[key] = e.target.value;
        this.renderPreview();
      });
    });

    // Save Branding Button
    document.getElementById('fb-save-branding-btn')?.addEventListener('click', async () => {
      try {
        await api.put('/api/custom-fields/templates/active', {
          branding: this.template.branding
        });
        Toast.success('Header branding updated & synced to /register successfully!');
      } catch (err) {
        Toast.error(err.message || 'Failed to save header branding');
      }
    });

    // Add Section
    document.getElementById('fb-add-section-btn')?.addEventListener('click', () => {
      this.openAddSectionModal();
    });

    // Add Field
    document.getElementById('fb-add-field-btn')?.addEventListener('click', () => {
      this.openFieldEditor(null);
    });
  }

  static moveSection(secName, delta) {
    const curIdx = this.sections.findIndex(s => s.name === secName);
    if (curIdx === -1) return;

    const targetIdx = curIdx + delta;
    if (targetIdx < 0 || targetIdx >= this.sections.length) return;

    // Swap section orders
    const targetSec = this.sections[targetIdx];
    const tempOrder = this.sections[curIdx].order || (curIdx + 1);
    this.sections[curIdx].order = targetSec.order || (targetIdx + 1);
    targetSec.order = tempOrder;

    this.renderSections();
    this.renderPreview();
    Toast.success('Section order rearranged!');
  }

  static async deleteField(fieldId) {
    const field = this.fields.find(f => f._id === fieldId);
    if (!field) return;

    if (!confirm(`Are you sure you want to delete question "${field.label}"?`)) return;

    try {
      await api.delete(`/api/custom-fields/${fieldId}`);
      Toast.success(`Question "${field.label}" deleted successfully`);
      this.fields = this.fields.filter(f => f._id !== fieldId);
      this.renderSections();
      this.renderPreview();
    } catch (err) {
      Toast.error(err.message || 'Failed to delete question field');
    }
  }

  static async deleteSection(secName) {
    const sec = this.sections.find(s => s.name === secName);
    if (!sec) return;

    if (!confirm(`Are you sure you want to delete section "${sec.label}"? Any questions inside will be moved to Personal Information.`)) return;

    try {
      await api.delete(`/api/custom-fields/sections/${secName}`);
      Toast.success(`Section "${sec.label}" deleted`);
      this.sections = this.sections.filter(s => s.name !== secName);
      this.fields.forEach(f => {
        if (f.section === secName) f.section = 'personal';
      });
      this.renderSections();
      this.renderPreview();
    } catch (err) {
      Toast.error(err.message || 'Failed to delete section');
    }
  }

  static openAddSectionModal() {
    const modalContent = document.createElement('div');
    modalContent.innerHTML = `
      <form id="fb-add-section-form" style="display: flex; flex-direction: column; gap: 14px;">
        <div class="form-group">
          <label class="form-label text-xs" style="font-weight:700;">Section Title *</label>
          <input type="text" id="as-label" class="form-control" placeholder="e.g. Step 6: Parent Consent & KYC" required>
        </div>
        
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
          <div class="form-group">
            <label class="form-label text-xs" style="font-weight:700;">Section Key/Slug *</label>
            <input type="text" id="as-key" class="form-control" placeholder="e.g. parent_kyc" required>
          </div>
          <div class="form-group">
            <label class="form-label text-xs" style="font-weight:700;">Section Icon Emoji</label>
            <input type="text" id="as-icon" class="form-control" value="📁" placeholder="e.g. 📄">
          </div>
        </div>

        <div style="display: flex; justify-content: flex-end; gap: 10px; margin-top: 10px;">
          <button type="button" class="btn btn-secondary btn-sm fb-cancel-modal-btn" data-modal-close="true">Cancel</button>
          <button type="submit" class="btn btn-primary btn-sm" style="font-weight: 700;">➕ Create Section</button>
        </div>
      </form>
    `;

    const modal = new Modal({
      title: '📁 Add Custom Form Section',
      content: modalContent,
      size: 'sm'
    });
    modal.show();

    modalContent.querySelector('.fb-cancel-modal-btn')?.addEventListener('click', () => {
      modal.close();
      Modal.closeAll();
    });

    modalContent.querySelector('#as-label')?.addEventListener('input', (e) => {
      const slug = e.target.value.toLowerCase().replace(/[^a-z0-9_]/g, '_');
      modalContent.querySelector('#as-key').value = slug;
    });

    modalContent.querySelector('#fb-add-section-form')?.addEventListener('submit', (e) => {
      e.preventDefault();
      const label = modalContent.querySelector('#as-label').value.trim();
      const key = modalContent.querySelector('#as-key').value.trim().toLowerCase().replace(/[^a-z0-9_]/g, '_');
      const icon = modalContent.querySelector('#as-icon').value.trim() || '📁';

      if (this.sections.some(s => s.name === key)) {
        Toast.error('A section with this key already exists');
        return;
      }

      this.sections.push({
        name: key,
        label,
        icon,
        order: this.sections.length + 1,
        isSystem: false
      });

      modal.close();
      this.renderSections();
      this.renderPreview();
      Toast.success(`Custom Section "${label}" created successfully!`);
    });
  }

  static async toggleFieldActive(fieldId) {
    const field = this.fields.find(f => f._id === fieldId);
    if (!field) return;

    field.isActive = field.isActive === false ? true : false;
    this.renderSections();
    this.renderPreview();

    try {
      await api.put(`/api/custom-fields/${fieldId}`, { isActive: field.isActive });
      Toast.success(`Question ${field.isActive ? 'activated' : 'hidden'}`);
    } catch (e) {
      Toast.error('Failed to update question status');
    }
  }

  static async moveField(fieldId, delta) {
    const field = this.fields.find(f => f._id === fieldId);
    if (!field) return;

    const secFields = this.fields
      .filter(f => (f.section || 'personal') === (field.section || 'personal'))
      .sort((a, b) => (a.order || 0) - (b.order || 0));

    const curIdx = secFields.findIndex(f => f._id === fieldId);
    if (curIdx === -1) return;

    const targetIdx = curIdx + delta;
    if (targetIdx < 0 || targetIdx >= secFields.length) return;

    // Swap orders
    const targetField = secFields[targetIdx];
    const tempOrder = field.order || 0;
    field.order = targetField.order || 0;
    targetField.order = tempOrder;

    this.renderSections();
    this.renderPreview();

    try {
      await api.put('/api/custom-fields/reorder/bulk', {
        items: this.fields.map(f => ({ id: f._id, order: f.order, section: f.section }))
      });
      Toast.success('Question order updated!');
    } catch (e) {}
  }

  static openFieldEditor(fieldId, targetSection = null) {
    const field = this.fields.find(f => f._id === fieldId) || {
      label: '',
      fieldName: '',
      type: 'text',
      section: targetSection || 'personal',
      required: false,
      placeholder: '',
      helpText: '',
      colSpan: 12,
      options: ['Option 1', 'Option 2']
    };

    const isEdit = !!fieldId;
    const secOptions = this.sections.map(s => `<option value="${s.name}" ${field.section === s.name ? 'selected' : ''}>${escapeHTML(s.label)}</option>`).join('');

    const modalContent = document.createElement('div');
    modalContent.innerHTML = `
      <form id="fb-field-edit-form" style="display: flex; flex-direction: column; gap: 14px;">
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
          <div class="form-group">
            <label class="form-label text-xs" style="font-weight:700;">Question Label *</label>
            <input type="text" id="fe-label" class="form-control" value="${escapeHTML(field.label)}" placeholder="e.g. Target Exam" required>
          </div>
          <div class="form-group">
            <label class="form-label text-xs" style="font-weight:700;">Field Slug/Key *</label>
            <input type="text" id="fe-key" class="form-control" value="${escapeHTML(field.fieldName || field.name || '')}" placeholder="e.g. target_exam" ${isEdit ? 'readonly' : 'required'}>
          </div>
        </div>

        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
          <div class="form-group">
            <label class="form-label text-xs" style="font-weight:700;">Question Type *</label>
            <select id="fe-type" class="form-select">
              <option value="text" ${field.type === 'text' ? 'selected' : ''}>📝 Short Text</option>
              <option value="textarea" ${field.type === 'textarea' ? 'selected' : ''}>📄 Long Paragraph Text</option>
              <option value="number" ${field.type === 'number' ? 'selected' : ''}>🔢 Number</option>
              <option value="phone" ${field.type === 'phone' ? 'selected' : ''}>📱 Phone Number</option>
              <option value="email" ${field.type === 'email' ? 'selected' : ''}>📧 Email Address</option>
              <option value="select" ${field.type === 'select' ? 'selected' : ''}>📋 Dropdown Select</option>
              <option value="radio" ${field.type === 'radio' ? 'selected' : ''}>🔘 Multiple Choice Radio</option>
              <option value="checkbox" ${field.type === 'checkbox' ? 'selected' : ''}>✅ Single Checkbox</option>
              <option value="multiselect" ${field.type === 'multiselect' ? 'selected' : ''}>☑️ Multi-Select Checkboxes</option>
              <option value="date" ${field.type === 'date' ? 'selected' : ''}>📅 Date Picker</option>
              <option value="time" ${field.type === 'time' ? 'selected' : ''}>⏰ Time Picker</option>
              <option value="file" ${field.type === 'file' ? 'selected' : ''}>📎 File / Document Upload</option>
              <option value="photo_upload" ${field.type === 'photo_upload' ? 'selected' : ''}>📸 Passport Photo / Selfie</option>
              <option value="signature_pad" ${field.type === 'signature_pad' ? 'selected' : ''}>✍️ Digital Signature Canvas</option>
              <option value="exam_badge" ${field.type === 'exam_badge' ? 'selected' : ''}>🎯 Target Competitive Exam</option>
              <option value="blood_group" ${field.type === 'blood_group' ? 'selected' : ''}>🩸 Blood Group Selector</option>
              <option value="url" ${field.type === 'url' ? 'selected' : ''}>🔗 Website / Portfolio Link</option>
              <option value="address_autocomplete" ${field.type === 'address_autocomplete' ? 'selected' : ''}>📍 Address & Pincode Auto-Fill</option>
              <option value="aadhaar_pan" ${field.type === 'aadhaar_pan' ? 'selected' : ''}>🪪 Aadhaar / PAN Proof Number</option>
              <option value="terms_checkbox" ${field.type === 'terms_checkbox' ? 'selected' : ''}>📜 Quiet Study Code Consent</option>
              <option value="star_rating" ${field.type === 'star_rating' ? 'selected' : ''}>⭐ Star Rating</option>
            </select>
          </div>

          <div class="form-group">
            <label class="form-label text-xs" style="font-weight:700;">Assigned Step / Section *</label>
            <select id="fe-section" class="form-select">${secOptions}</select>
          </div>
        </div>

        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
          <div class="form-group">
            <label class="form-label text-xs" style="font-weight:700;">Placeholder Text</label>
            <input type="text" id="fe-placeholder" class="form-control" value="${escapeHTML(field.placeholder || '')}" placeholder="e.g. Enter your exam name">
          </div>
          <div class="form-group">
            <label class="form-label text-xs" style="font-weight:700;">Help Tooltip Text</label>
            <input type="text" id="fe-help" class="form-control" value="${escapeHTML(field.helpText || '')}" placeholder="e.g. Used for seat recommendations">
          </div>
        </div>

        <div style="display: flex; gap: 20px; align-items: center; background: var(--color-bg-secondary); padding: 10px 14px; border-radius: 8px;">
          <label style="font-weight: 600; font-size: 0.85rem; display: flex; align-items: center; gap: 8px; margin: 0; cursor: pointer;">
            <input type="checkbox" id="fe-required" class="form-toggle" ${field.required ? 'checked' : ''}> 🔴 Mandatory / Required Field
          </label>
          <label style="font-weight: 600; font-size: 0.85rem; display: flex; align-items: center; gap: 8px; margin: 0; cursor: pointer;">
            <input type="checkbox" id="fe-halfwidth" class="form-toggle" ${field.colSpan === 6 ? 'checked' : ''}> 📐 50% Half Width Row
          </label>
        </div>

        <div id="fe-options-wrap" style="display: ${['select', 'radio', 'multiselect'].includes(field.type) ? 'block' : 'none'};">
          <label class="form-label text-xs" style="font-weight:700;">Options List (Comma-separated)</label>
          <input type="text" id="fe-options" class="form-control" value="${escapeHTML((field.options || []).join(', '))}" placeholder="Option 1, Option 2, Option 3">
        </div>

        <div style="display: flex; justify-content: flex-end; gap: 10px; margin-top: 10px;">
          <button type="button" class="btn btn-secondary btn-sm fb-cancel-modal-btn" data-modal-close="true">Cancel</button>
          <button type="submit" class="btn btn-primary btn-sm" style="font-weight: 700;">💾 Save Question Field</button>
        </div>
      </form>
    `;

    const modal = new Modal({
      title: isEdit ? `✏️ Edit Question: ${field.label}` : '✨ Create New Question Field',
      content: modalContent,
      size: 'md'
    });
    modal.show();

    modalContent.querySelector('.fb-cancel-modal-btn')?.addEventListener('click', () => {
      modal.close();
      Modal.closeAll();
    });

    // Auto slugify field key on label input for new fields
    if (!isEdit) {
      modalContent.querySelector('#fe-label')?.addEventListener('input', (e) => {
        const slug = e.target.value.toLowerCase().replace(/[^a-z0-9_]/g, '_');
        modalContent.querySelector('#fe-key').value = slug;
      });
    }

    // Toggle options field
    modalContent.querySelector('#fe-type')?.addEventListener('change', (e) => {
      const showOpts = ['select', 'radio', 'multiselect'].includes(e.target.value);
      modalContent.querySelector('#fe-options-wrap').style.display = showOpts ? 'block' : 'none';
    });

    // Form submit
    modalContent.querySelector('#fb-field-edit-form')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const label = modalContent.querySelector('#fe-label').value.trim();
      const key = modalContent.querySelector('#fe-key').value.trim().toLowerCase().replace(/[^a-z0-9_]/g, '_');
      const type = modalContent.querySelector('#fe-type').value;
      const section = modalContent.querySelector('#fe-section').value;
      const placeholder = modalContent.querySelector('#fe-placeholder').value.trim();
      const helpText = modalContent.querySelector('#fe-help').value.trim();
      const required = modalContent.querySelector('#fe-required').checked;
      const colSpan = modalContent.querySelector('#fe-halfwidth').checked ? 6 : 12;
      const rawOpts = modalContent.querySelector('#fe-options').value;
      const options = rawOpts ? rawOpts.split(',').map(s => s.trim()).filter(Boolean) : [];

      const payload = {
        fieldName: key,
        label,
        type,
        section,
        placeholder,
        helpText,
        required,
        colSpan,
        options,
        isActive: true
      };

      try {
        if (isEdit) {
          await api.put(`/api/custom-fields/${fieldId}`, payload);
          Toast.success('Question field updated successfully!');
        } else {
          await api.post('/api/custom-fields', payload);
          Toast.success('New question field added successfully!');
        }
        modal.close();
        await FormBuilder.loadData();
      } catch (err) {
        Toast.error(err.message || 'Failed to save question field');
      }
    });
  }
}
