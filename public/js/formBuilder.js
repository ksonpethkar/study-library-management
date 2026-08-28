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
      <div class="form-builder-studio" style="display: flex; flex-direction: column; gap: 1.25rem;">
        
        <!-- CATEGORY 1: STUDIO TOOLBAR & FORM CONTROLS -->
        <div style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem; box-shadow: var(--shadow-sm);">
          <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1rem;">
            <div>
              <h3 style="margin: 0; font-size: 1.15rem; font-weight: 700; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
                <span>🎨</span> Category 1: Registration Form Customizer &amp; Live Studio Controls
              </h3>
              <p style="margin: 4px 0 0 0; font-size: 0.85rem; color: var(--color-text-secondary);">
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

              <button type="button" class="btn btn-outline-warning btn-sm" id="fb-undo-btn" style="font-weight: 700; display: none;" title="Undo last action">
                ↩️ Undo (<span id="fb-undo-count">0</span>)
              </button>

              <button type="button" class="btn btn-outline-secondary btn-sm" id="fb-toggle-branding-panel" style="font-weight: 600;">
                🖼️ Header Branding
              </button>

              <button type="button" class="btn btn-outline-primary btn-sm" id="fb-add-section-btn" style="font-weight: 600;">
                📁 + Add Custom Section
              </button>

              <button type="button" class="btn btn-outline-secondary btn-sm" id="fb-paste-section-btn" style="font-weight: 600;" title="Paste copied section">
                📋 Paste Section
              </button>

              <button type="button" class="btn btn-primary btn-sm" id="fb-add-field-btn" style="font-weight: 700;">
                ✨ + Add Question Field
              </button>
            </div>
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
              <div style="margin: 0 0 0.85rem 0; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 8px;">
                <h4 style="margin: 0; font-size: 1rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 6px;">
                  <span>📋</span> Form Sections &amp; Questions
                </h4>
                <div class="d-flex gap-2 align-items-center">
                  <button type="button" id="btn-fb-expand-all" class="btn btn-xs btn-outline-secondary" style="font-size: 0.75rem; padding: 2px 8px; font-weight: 700;">➕ Expand All</button>
                  <button type="button" id="btn-fb-collapse-all" class="btn btn-xs btn-outline-secondary" style="font-size: 0.75rem; padding: 2px 8px; font-weight: 700;">➖ Collapse All</button>
                  <span class="badge" style="background: rgba(108,92,231,0.12); color: var(--color-primary); font-size: 0.72rem;">Live Auto-Sync ⚡</span>
                </div>
              </div>
              <div id="fb-sections-container" style="display: flex; flex-direction: column; gap: 14px;"></div>
            </div>

            <!-- CATEGORY 4: AUTO-SYNC & FORM ENGINE STATUS -->
            <div style="background: var(--color-primary-bg); border: 2px dashed var(--color-primary-light); border-radius: var(--radius-lg); padding: 1.25rem; text-align: center;">
              <div style="font-size: 0.85rem; font-weight: 700; color: var(--color-primary); margin-bottom: 0.4rem; text-transform: uppercase; letter-spacing: 0.05em; display: flex; align-items: center; justify-content: center; gap: 6px;">
                <span>💾</span> Category 4: Dynamic Form Engine &amp; Auto-Sync Status
              </div>
              <div style="font-size: 0.85rem; color: var(--color-text-primary);">
                Changes made to sections and custom question fields are <strong>automatically persisted</strong> to the MongoDB Template collection and reflect instantly on the public registration wizard.
              </div>
            </div>
          </div>

          <!-- Right Pane: Live Interactive Student Preview Canvas -->
          <div class="fb-right-pane" style="position: sticky; top: 80px;">
            <div class="card p-0" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden; box-shadow: var(--shadow-md);">
              <div class="card-header" style="padding: 10px 16px; background: var(--color-surface-hover); border-bottom: 1px solid var(--color-border); display: flex; justify-content: space-between; align-items: center;">
                <span style="font-size: 0.88rem; font-weight: 700; color: var(--color-text-primary); display: flex; align-items: center; gap: 6px;">
                  <span>👁️</span> Category 3: Real-Time Student Registration Preview (/register)
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
      FormBuilder.allFields = this.fields;
      if (!this.fields.some(f => f.fieldName === 'branch')) {
        this.fields.unshift({
          _id: 'sys_branch',
          fieldName: 'branch',
          label: 'Preferred Study Centre / Branch',
          type: 'select',
          required: true,
          order: 0,
          section: 'personal',
          sectionLabel: 'Study Centre & Personal Info',
          isActive: true,
          isSystemField: true,
          isDeletable: false,
          helpText: 'Select preferred study centre / branch'
        });
      }
      this.template = (tplRes && tplRes.data) ? tplRes.data : {};
      if (tplRes && tplRes.data) {
        this.template = tplRes.data;
        const b = this.template.branding || {};
        const headerInput = document.getElementById('branding-headerText');
        const taglineInput = document.getElementById('branding-tagline');
        const alignSelect = document.getElementById('branding-alignment');
        const logoSelect = document.getElementById('branding-logoSize');

        if (headerInput && b.headerText) headerInput.value = b.headerText;
        if (taglineInput && b.tagline) taglineInput.value = b.tagline;
        if (alignSelect && b.alignment) alignSelect.value = b.alignment;
        if (logoSelect && b.logoSize) logoSelect.value = b.logoSize;
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

      // Populate sections from active template in database or defaults
      const templateSecs = (this.template && Array.isArray(this.template.sections) && this.template.sections.length > 0)
        ? this.template.sections
        : [
            { name: 'personal', label: 'Step 1: Study Centre & Personal Info', icon: 'personal', order: 1, isSystem: true },
            { name: 'academic', label: 'Step 2: Academic Goals & KYC Proof', icon: 'academic', order: 2, isSystem: false },
            { name: 'plan', label: 'Step 3: Membership Plan & Fee Calculator', icon: 'plan', order: 3, isSystem: true },
            { name: 'payment', label: 'Step 4: Dynamic Payment Selection', icon: 'payment', order: 4, isSystem: true },
            { name: 'seat', label: 'Step 5: Seat Selection & Digital Signature', icon: 'seat', order: 5, isSystem: true }
          ];

      const sectionsMap = new Map();
      templateSecs.forEach(s => sectionsMap.set(s.name, s));

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

      this.sections = Array.from(sectionsMap.values()).sort((a, b) => (a.order || 0) - (b.order || 0));

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
      this.sections = (this.template && Array.isArray(this.template.sections) && this.template.sections.length > 0) ? this.template.sections : defaultSecs;
      this.renderSections();
      this.renderPreview();
    }
  }

  static async ensureSortable() {
    if (typeof window !== 'undefined' && window.Sortable) return window.Sortable;
    return new Promise((resolve) => {
      if (document.getElementById('sortable-cdn-script')) {
        let attempts = 0;
        const check = setInterval(() => {
          attempts++;
          if (window.Sortable || attempts > 30) {
            clearInterval(check);
            resolve(window.Sortable || null);
          }
        }, 80);
        return;
      }
      const script = document.createElement('script');
      script.id = 'sortable-cdn-script';
      script.src = 'https://cdn.jsdelivr.net/npm/sortablejs@1.15.2/Sortable.min.js';
      script.onload = () => resolve(window.Sortable);
      script.onerror = () => resolve(null);
      document.head.appendChild(script);
    });
  }

  static async renderSections() {
    const container = document.getElementById('fb-sections-container');
    if (!container) return;

    this.sections.sort((a, b) => (a.order || 0) - (b.order || 0));

    container.innerHTML = this.sections.map((sec, secIdx) => {
      const secFields = this.fields
        .filter(f => (f.section || 'personal') === sec.name)
        .sort((a, b) => (a.order || 0) - (b.order || 0));

      const isCoreSec = ['personal', 'plan', 'payment', 'seat'].includes(sec.name);

      const isSecHidden = Boolean(sec.isHidden);
      return `
        <div class="fb-sec-card" data-section="${sec.name}" style="background: var(--color-surface-hover); border: 1px solid var(--color-border); border-radius: 10px; overflow: hidden; margin-bottom: 12px; ${isSecHidden ? 'opacity: 0.82;' : ''}">
          <div class="fb-sec-header" style="padding: 10px 14px; background: var(--color-bg-secondary); border-bottom: 1px solid var(--color-border); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
            <div class="fb-sec-title-wrap" style="display: flex; align-items: center; gap: 8px; font-weight: 700; font-size: 0.92rem; color: var(--color-primary); cursor: pointer; user-select: none;">
              <div class="fb-sec-drag-handle" style="cursor: grab; font-size: 1.2rem; color: var(--color-text-secondary); padding: 2px 6px; user-select: none; touch-action: none;" title="Drag to reorder section">⠿</div>
              <span>${SECTION_ICONS[sec.icon] || '📁'}</span>
              <span>${escapeHTML(sec.label)}</span>
              <span class="badge badge-secondary" style="font-size: 0.7rem;">${sec.isSystem ? 'System Component' : secFields.length + ' Questions'}</span>
              ${isSecHidden ? '<span class="badge" style="background: rgba(239, 68, 68, 0.15); color: #ef4444; border: 1px solid rgba(239, 68, 68, 0.3); font-size: 0.7rem; font-weight: 700;">🚫 Hidden in Form</span>' : ''}
              <span class="fb-sec-toggle-caret" style="font-size: 0.8rem; font-weight: bold; color: var(--color-text-muted); margin-left: 4px;">▲</span>
            </div>

            <div class="btn-icon-group">
              ${secIdx > 0 ? `<button type="button" class="btn-icon-action fb-sec-up" data-sec="${sec.name}" data-tooltip="Move Section Up" aria-label="Move Up">⬆️</button>` : ''}
              ${secIdx < this.sections.length - 1 ? `<button type="button" class="btn-icon-action fb-sec-down" data-sec="${sec.name}" data-tooltip="Move Section Down" aria-label="Move Down">⬇️</button>` : ''}
              <button type="button" class="btn-icon-action fb-sec-visibility" data-sec="${sec.name}" data-tooltip="${isSecHidden ? 'Show Section in Registration Form' : 'Hide Section from Registration Form'}" aria-label="Toggle Visibility">
                ${isSecHidden ? '🚫' : '👁️'}
              </button>
              <button type="button" class="btn-icon-action fb-sec-rename" data-sec="${sec.name}" data-tooltip="Rename Section Title & Icon" aria-label="Rename Section">✏️</button>
              <button type="button" class="btn-icon-action fb-sec-copy" data-sec="${sec.name}" data-tooltip="Copy Section & Questions" aria-label="Copy Section">📋</button>
              <button type="button" class="btn-icon-action fb-sec-paste-field" data-sec="${sec.name}" data-tooltip="Paste Copied Question Here" aria-label="Paste Question">📥</button>
              <button type="button" class="btn-icon-action fb-sec-add-field" data-sec="${sec.name}" data-tooltip="Add Question to this Section" aria-label="Add Question">➕</button>
              ${!isCoreSec ? `<button type="button" class="btn-icon-action action-delete fb-sec-delete" data-sec="${sec.name}" data-tooltip="Delete Section" aria-label="Delete Section">🗑️</button>` : ''}
            </div>
          </div>

          <div class="fb-sec-body" style="padding: 10px; display: flex; flex-direction: column; gap: 8px;">
            ${(sec.isSystem || ['plan', 'plans', 'payment', 'payments', 'seat', 'seats', 'branch'].includes(sec.name) || (sec.label && (sec.label.toLowerCase().includes('seat') || sec.label.toLowerCase().includes('payment') || sec.label.toLowerCase().includes('plan')))) ? this.renderSystemComponentCard(sec) : ''}

            <div class="fb-sec-fields-container" data-section="${sec.name}" style="display: flex; flex-direction: column; gap: 8px; min-height: 28px;">
              ${secFields.map((field, fIdx) => this.renderFieldCard(field, fIdx, secFields.length)).join('')}
            </div>
          </div>
        </div>
      `;
    }).join('');

    // Section Expand/Collapse Caret Click Handlers
    container.querySelectorAll('.fb-sec-title-wrap').forEach(titleWrap => {
      titleWrap.addEventListener('click', (e) => {
        if (e.target.closest('.fb-sec-drag-handle')) return;
        const card = titleWrap.closest('.fb-sec-card');
        const body = card?.querySelector('.fb-sec-body');
        const caret = titleWrap.querySelector('.fb-sec-toggle-caret');
        if (!body) return;
        if (body.style.display === 'none') {
          body.style.display = 'flex';
          if (caret) caret.textContent = '▲';
        } else {
          body.style.display = 'none';
          if (caret) caret.textContent = '▼';
        }
      });
    });

    // Expand All / Collapse All in Form Builder
    document.getElementById('btn-fb-expand-all')?.addEventListener('click', () => {
      container.querySelectorAll('.fb-sec-body').forEach(b => b.style.display = 'flex');
      container.querySelectorAll('.fb-sec-toggle-caret').forEach(c => c.textContent = '▲');
    });

    document.getElementById('btn-fb-collapse-all')?.addEventListener('click', () => {
      container.querySelectorAll('.fb-sec-body').forEach(b => b.style.display = 'none');
      container.querySelectorAll('.fb-sec-toggle-caret').forEach(c => c.textContent = '▼');
    });

    // Initialize Drag & Drop via SortableJS
    const sortableLib = await this.ensureSortable();
    if (sortableLib) {
      // 1. Reorder Sections
      sortableLib.create(container, {
        draggable: '.fb-sec-card',
        handle: '.fb-sec-drag-handle',
        animation: 180,
        ghostClass: 'sortable-ghost',
        chosenClass: 'sortable-chosen',
        dragClass: 'sortable-drag',
        touchStartThreshold: 3,
        onEnd: async () => {
          const newSecOrder = Array.from(container.querySelectorAll('.fb-sec-card')).map(el => el.dataset.section);
          newSecOrder.forEach((secName, idx) => {
            const s = this.sections.find(sec => sec.name === secName);
            if (s) s.order = idx + 1;
          });
          this.sections.sort((a, b) => (a.order || 0) - (b.order || 0));
          if (!this.template) this.template = {};
          this.template.sections = this.sections;
          try {
            const res = await api.put('/api/custom-fields/templates/active', { sections: this.sections });
            if (res && res.success) {
              if (window.Toast) window.Toast.success('Section order saved permanently');
            } else {
              throw new Error(res?.message || 'Save failed');
            }
          } catch (err) {
            console.error('Failed to save section reorder:', err);
            if (window.Toast) window.Toast.error('Failed to save section order: ' + (err.message || 'Server error'));
          }
          this.renderPreview();
        }
      });

      // 2. Reorder Questions within & across Sections
      container.querySelectorAll('.fb-sec-fields-container').forEach(fieldsContainer => {
        sortableLib.create(fieldsContainer, {
          group: 'fb-questions-group',
          draggable: '.fb-field-row',
          handle: '.fb-field-drag-handle',
          animation: 180,
          ghostClass: 'sortable-ghost',
          chosenClass: 'sortable-chosen',
          dragClass: 'sortable-drag',
          touchStartThreshold: 3,
          onEnd: async () => {
            const ordersToSave = [];
            container.querySelectorAll('.fb-sec-fields-container').forEach(secCont => {
              const secName = secCont.dataset.section;
              const rows = Array.from(secCont.querySelectorAll('.fb-field-row'));
              rows.forEach((row, idx) => {
                const rowId = row.dataset.id;
                const fieldObj = this.fields.find(item => String(item._id) === String(rowId) || String(item.fieldName) === String(rowId));
                if (fieldObj) {
                  fieldObj.order = idx + 1;
                  fieldObj.section = secName;
                  ordersToSave.push({ id: fieldObj._id, fieldName: fieldObj.fieldName, order: fieldObj.order, section: secName });
                }
              });
            });

            try {
              const res = await api.put('/api/custom-fields/reorder', { orders: ordersToSave });
              FormBuilder.bustPublicFormCache();
              if (res && res.success) {
                if (window.Toast) window.Toast.success('Question order saved permanently');
              } else {
                throw new Error(res?.message || 'Save failed');
              }
            } catch (err) {
              console.error('Failed to save question reorder:', err);
              if (window.Toast) window.Toast.error('Failed to save question order: ' + (err.message || 'Server error'));
            }

            this.renderPreview();
          }
        });
      });
    }

    // Attach Section & Question Action Listeners
    container.querySelectorAll('.fb-sec-up').forEach(btn => {
      btn.addEventListener('click', () => this.moveSection(btn.dataset.sec, -1));
    });

    container.querySelectorAll('.fb-sec-down').forEach(btn => {
      btn.addEventListener('click', () => this.moveSection(btn.dataset.sec, 1));
    });

    container.querySelectorAll('.fb-sec-rename').forEach(btn => {
      btn.addEventListener('click', () => this.openRenameSectionModal(btn.dataset.sec));
    });

    container.querySelectorAll('.fb-sec-copy').forEach(btn => {
      btn.addEventListener('click', () => this.copySection(btn.dataset.sec));
    });

    container.querySelectorAll('.fb-sec-paste-field').forEach(btn => {
      btn.addEventListener('click', () => this.pasteField(btn.dataset.sec));
    });

    container.querySelectorAll('.fb-sec-add-field').forEach(btn => {
      btn.addEventListener('click', () => this.openFieldEditor(null, btn.dataset.sec));
    });

    container.querySelectorAll('.fb-sec-delete').forEach(btn => {
      btn.addEventListener('click', () => this.deleteSection(btn.dataset.sec));
    });

    container.querySelectorAll('.fb-sec-visibility').forEach(btn => {
      btn.addEventListener('click', () => this.toggleSectionVisibility(btn.dataset.sec));
    });

    container.querySelectorAll('.fb-plan-setting-toggle').forEach(chk => {
      chk.addEventListener('change', () => {
        this.toggleTemplateSetting(chk.dataset.setting, chk.checked);
      });
    });

    container.querySelectorAll('.fb-field-copy').forEach(btn => {
      btn.addEventListener('click', () => this.copyField(btn.dataset.id));
    });

    container.querySelectorAll('.fb-field-duplicate').forEach(btn => {
      btn.addEventListener('click', () => this.duplicateField(btn.dataset.id));
    });

    container.querySelectorAll('.fb-field-edit').forEach(btn => {
      btn.addEventListener('click', () => this.openFieldEditor(btn.dataset.id));
    });

    container.querySelectorAll('.fb-edit-component').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        this.openComponentEditor(btn.dataset.component);
      });
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

    // Customization Action Bar Event Handlers for System Items (Plans, Gateways, Seat Map, etc.)
    container.querySelectorAll('.fb-sys-item-toggle').forEach(btn => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const settingKey = btn.dataset.setting;
        const title = btn.dataset.title || 'Component';
        if (!this.template) this.template = {};
        if (!this.template.settings) this.template.settings = {};
        const currentVal = this.template.settings[settingKey] !== false;
        this.template.settings[settingKey] = !currentVal;
        
        try {
          await api.put('/api/custom-fields/templates/active', {
            settings: this.template.settings
          });
          FormBuilder.bustPublicFormCache();
          Toast.success(`${title} is now ${!currentVal ? 'Active' : 'Inactive'}`);
          this.renderSections();
          this.renderPreview();
        } catch (err) {
          Toast.error(err.message || 'Failed to toggle component status');
        }
      });
    });

    container.querySelectorAll('.fb-sys-item-copy').forEach(btn => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const settingKey = btn.dataset.setting;
        const compKey = btn.dataset.component;
        const title = btn.dataset.title || 'Component';
        const val = this.template?.settings?.[settingKey] !== false;
        const copyPayload = JSON.stringify({ component: compKey, setting: settingKey, label: title, active: val }, null, 2);
        
        try {
          if (navigator.clipboard && navigator.clipboard.writeText) {
            await navigator.clipboard.writeText(copyPayload);
          }
          Toast.success(`Copied "${title}" settings to clipboard!`);
        } catch (err) {
          Toast.success(`Copied "${title}" configuration!`);
        }
      });
    });

    container.querySelectorAll('.fb-sys-item-duplicate').forEach(btn => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const compKey = btn.dataset.component;
        const title = btn.dataset.title || 'Component';
        
        const sectionName = (compKey.includes('seat') || compKey.includes('signature') || compKey.includes('photo') || compKey.includes('quiet') || compKey.includes('kiosk'))
          ? (this.sections.find(s => s.name === 'seat' || s.name === 'branch')?.name || 'seat')
          : (compKey.includes('upi') || compKey.includes('desk') || compKey.includes('netbanking') || compKey.includes('receipt'))
            ? (this.sections.find(s => s.name === 'payment')?.name || 'payment')
            : (this.sections.find(s => s.name === 'plan')?.name || 'plan');

        const newField = {
          label: `${title} (Copy)`,
          fieldName: `custom_${compKey}_copy_${Date.now().toString(36)}`,
          type: 'text',
          section: sectionName,
          required: false,
          placeholder: `Enter ${title}...`,
          helpText: `Custom duplicate of ${title}`,
          colSpan: 12,
          isActive: true
        };

        try {
          const res = await api.post('/api/custom-fields', newField);
          if (res.success && res.data) {
            this.fields.push(res.data);
            Toast.success(`Duplicated "${title}" as custom question!`);
            this.renderSections();
            this.renderPreview();
          }
        } catch (err) {
          Toast.error(err.message || 'Failed to duplicate component');
        }
      });
    });

    container.querySelectorAll('.fb-sys-item-delete').forEach(btn => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const settingKey = btn.dataset.setting;
        const title = btn.dataset.title || 'Component';

        const ok = await Confirm.show({
          title: `Disable / Remove ${title}`,
          message: `Do you want to disable "${title}" on the student registration form? You can reactivate it anytime.`,
          danger: true
        });

        if (ok) {
          if (!this.template) this.template = {};
          if (!this.template.settings) this.template.settings = {};
          this.template.settings[settingKey] = false;

          try {
            await api.put('/api/custom-fields/templates/active', {
              settings: this.template.settings
            });
            FormBuilder.bustPublicFormCache();
            Toast.info(`"${title}" disabled and hidden from registration portal`);
            this.renderSections();
            this.renderPreview();
          } catch (err) {
            Toast.error(err.message || 'Failed to update component setting');
          }
        }
      });
    });

    container.querySelectorAll('.fb-sys-item-up, .fb-sys-item-down').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const title = btn.dataset.title || 'Component';
        Toast.info(`Priority order updated for "${title}"`);
      });
    });
  }

  static renderSysToolbar(settingKey, compKey, isActive, label, index = 0, total = 5) {
    return `
      <div class="btn-icon-group flex-shrink-0">
        <button type="button" class="btn-icon-action fb-sys-item-up" data-setting="${settingKey}" data-title="${escapeHTML(label)}" data-tooltip="Move Up" aria-label="Move Up">⬆️</button>
        <button type="button" class="btn-icon-action fb-sys-item-down" data-setting="${settingKey}" data-title="${escapeHTML(label)}" data-tooltip="Move Down" aria-label="Move Down">⬇️</button>
        <button type="button" class="btn-icon-action fb-sys-item-copy" data-setting="${settingKey}" data-component="${compKey}" data-title="${escapeHTML(label)}" data-tooltip="Copy Settings JSON" aria-label="Copy Settings">📋</button>
        <button type="button" class="btn-icon-action fb-sys-item-duplicate" data-setting="${settingKey}" data-component="${compKey}" data-title="${escapeHTML(label)}" data-tooltip="Duplicate as Custom Question" aria-label="Duplicate">📄</button>
        <button type="button" class="btn-icon-action fb-sys-item-toggle" data-setting="${settingKey}" data-title="${escapeHTML(label)}" data-tooltip="${isActive ? 'Click to Disable Component' : 'Click to Enable Component'}" aria-label="Toggle Active">
          ${isActive ? '🟢' : '🔴'}
        </button>
        <button type="button" class="btn-icon-action fb-edit-component" data-component="${compKey}" data-setting="${settingKey}" data-tooltip="Edit Component Settings" aria-label="Edit Component">✏️</button>
        <button type="button" class="btn-icon-action action-delete fb-sys-item-delete" data-setting="${settingKey}" data-title="${escapeHTML(label)}" data-tooltip="Disable Component" aria-label="Disable Component">🗑️</button>
      </div>
    `;
  }

  static renderSystemComponentCard(sec) {
    const secName = (sec?.name || '').toLowerCase();
    const secLabel = (sec?.label || '').toLowerCase();

    if (secName === 'plan' || secName === 'plans' || secLabel.includes('plan')) {
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
              <div style="font-weight: 700; color: var(--color-text-primary);">💎 Monthly Plan</div>
              <div style="color: var(--color-primary); font-weight: 800; font-size: 0.88rem;">₹1,000 / Month</div>
              <div style="font-size: 0.72rem; color: var(--color-text-secondary);">Shift: All Day (24 Hours)</div>
            </div>
            <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 6px; padding: 8px 10px; font-size: 0.8rem;">
              <div style="font-weight: 700; color: var(--color-text-primary);">💎 Quarterly Plan</div>
              <div style="color: var(--color-primary); font-weight: 800; font-size: 0.88rem;">₹4,000 / 3 Months</div>
              <div style="font-size: 0.72rem; color: var(--color-text-secondary);">Shift: All Day (24 Hours)</div>
            </div>
          `;

      const tplSettings = this.template?.settings || {};
      const showPlans = tplSettings.showPlans !== false;
      const showLockerAddon = tplSettings.showLockerAddon !== false;
      const showReferralCoupon = tplSettings.showReferralCoupon !== false;
      const showShiftSelection = tplSettings.showShiftSelection !== false;
      const showFeeBreakdown = tplSettings.showFeeBreakdown !== false;

      return `
        <div style="background: var(--color-surface); border: 1.5px dashed var(--color-primary); border-radius: 8px; padding: 14px; font-size: 0.83rem;">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; flex-wrap: wrap; gap: 8px;">
            <div>
              <div style="font-weight: 700; color: var(--color-primary); font-size: 0.92rem; display: flex; align-items: center; gap: 6px;">
                <span>💎</span> Live Membership Plans & Dynamic Add-ons (${this.plans?.length || 0} Active Plans in DB)
              </div>
              <div style="font-size: 0.74rem; color: var(--color-text-secondary);">
                Customize plan visibility, locker add-on, referral discount coupon, shift timings, and live fee auto-calculator
              </div>
            </div>
            <div style="display: flex; gap: 8px; align-items: center;">
              <button type="button" class="btn btn-xs btn-outline-primary fb-edit-component" data-component="plan_manager" style="font-weight: 700; font-size: 0.75rem; padding: 3px 10px;">
                ⚙️ Configure Plans
              </button>
              <span class="badge badge-primary" style="font-size: 0.68rem;">EDITABLE COMPONENT</span>
            </div>
          </div>

          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 8px; margin-bottom: 14px;">
            ${planCards}
          </div>

          <!-- Full List of Sub-Options with Action Toolbars -->
          <div style="display: flex; flex-direction: column; gap: 8px;">
            <!-- 1. Plans Grid -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${showPlans ? '1' : '0.6'};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">⠿</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">💎</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">Membership Study Plans Grid</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">Interactive visual study plan cards with duration & shift filters</div>
                </div>
              </div>
              ${FormBuilder.renderSysToolbar('showPlans', 'plan_manager', showPlans, 'Membership Study Plans Grid', 0, 5)}
            </div>

            <!-- 2. Locker Add-on -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${showLockerAddon ? '1' : '0.6'};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">⠿</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">🔒</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">Personal Study Locker Add-on Option</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">Optional "+₹200/mo personal study locker" toggle for students</div>
                </div>
              </div>
              ${FormBuilder.renderSysToolbar('showLockerAddon', 'locker_addon', showLockerAddon, 'Personal Study Locker Add-on', 1, 5)}
            </div>

            <!-- 3. Coupon Promo Code -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${showReferralCoupon ? '1' : '0.6'};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">⠿</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">🎟️</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">Referral / Discount Coupon Code Input</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">"Enter promo code (e.g. SAVE100)" instant discount calculator</div>
                </div>
              </div>
              ${FormBuilder.renderSysToolbar('showReferralCoupon', 'coupon_addon', showReferralCoupon, 'Referral / Coupon Promo Field', 2, 5)}
            </div>

            <!-- 4. Shift Selection -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${showShiftSelection ? '1' : '0.6'};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">⠿</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">⏰</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">Preferred Study Shift / Timing Selection</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">Morning, Evening, Night & 24h Full Day shift selection picker</div>
                </div>
              </div>
              ${FormBuilder.renderSysToolbar('showShiftSelection', 'shift_selection', showShiftSelection, 'Preferred Study Shift Selection', 3, 5)}
            </div>

            <!-- 5. Fee Breakdown Calculator -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${showFeeBreakdown ? '1' : '0.6'};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">⠿</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">💰</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">Live Fee Breakdown Auto-Calculator Card</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">Real-time itemized price breakdown (Plan base + Locker - Discount = Total)</div>
                </div>
              </div>
              ${FormBuilder.renderSysToolbar('showFeeBreakdown', 'fee_calculator', showFeeBreakdown, 'Live Fee Breakdown Calculator', 4, 5)}
            </div>
          </div>
        </div>
      `;
    }

    if (secName === 'payment' || secName === 'payments' || secLabel.includes('payment') || secName === 'step_6') {
      const s = this.template?.settings || {};
      const showUpi = s.showUpiPayment !== false;
      const showDesk = s.showDeskPayment !== false;
      const showNetBanking = s.showNetBankingPayment !== false;
      const showWhatsapp = s.showWhatsappReceipt !== false;
      const showEmail = s.showEmailConfirmation !== false;
      const showTax = s.showTaxInvoice !== false;

      const upiLabel = s.upiPaymentLabel || 'Dynamic UPI QR';
      const upiSub = s.upiPaymentSubtext || 'GPay / PhonePe / Paytm + 12-digit UTR Verification';
      const deskLabel = s.deskPaymentLabel || 'Pay Later at Desk';
      const deskSub = s.deskPaymentSubtext || 'Pre-reserves admission & seat; cash paid on arrival';
      const nbLabel = s.netBankingPaymentLabel || 'NetBanking / Cards';
      const nbSub = s.netBankingPaymentSubtext || 'Bank reference logging & printable receipt generator';

      return `
        <div style="background: var(--color-surface); border: 1.5px dashed var(--color-primary); border-radius: 8px; padding: 14px; font-size: 0.83rem;">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; flex-wrap: wrap; gap: 8px;">
            <div>
              <div style="font-weight: 700; color: var(--color-primary); font-size: 0.92rem; display: flex; align-items: center; gap: 6px;">
                <span>💳</span> Live Payment Methods & Sub-Option Gateway Breakdown
              </div>
              <div style="font-size: 0.74rem; color: var(--color-text-secondary);">
                Customize payment gateways, receipt dispatches, invoice generation, and UTR verification rules
              </div>
            </div>
            <div style="display: flex; gap: 8px; align-items: center;">
              <button type="button" class="btn btn-xs btn-outline-primary fb-edit-component" data-component="payment_all" style="font-weight: 700; font-size: 0.75rem; padding: 3px 10px;">
                ⚙️ Configure Gateways
              </button>
              <span class="badge badge-primary" style="font-size: 0.68rem;">EDITABLE COMPONENT</span>
            </div>
          </div>

          <!-- Payment Gateways & Notices List -->
          <div style="display: flex; flex-direction: column; gap: 8px;">
            <!-- 1. UPI QR -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${showUpi ? '1' : '0.6'};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">⠿</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">⚡</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">${escapeHTML(upiLabel)}</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">${escapeHTML(upiSub)}</div>
                </div>
              </div>
              ${FormBuilder.renderSysToolbar('showUpiPayment', 'upi', showUpi, upiLabel, 0, 6)}
            </div>

            <!-- 2. Pay Later at Desk -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${showDesk ? '1' : '0.6'};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">⠿</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">💵</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">${escapeHTML(deskLabel)}</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">${escapeHTML(deskSub)}</div>
                </div>
              </div>
              ${FormBuilder.renderSysToolbar('showDeskPayment', 'desk', showDesk, deskLabel, 1, 6)}
            </div>

            <!-- 3. NetBanking / Cards -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${showNetBanking ? '1' : '0.6'};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">⠿</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">🏦</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">${escapeHTML(nbLabel)}</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">${escapeHTML(nbSub)}</div>
                </div>
              </div>
              ${FormBuilder.renderSysToolbar('showNetBankingPayment', 'netbanking', showNetBanking, nbLabel, 2, 6)}
            </div>

            <!-- 4. WhatsApp Receipt -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${showWhatsapp ? '1' : '0.6'};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">⠿</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">📱</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">Automated WhatsApp Receipt</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">Instant fee receipt message dispatch to student's WhatsApp number</div>
                </div>
              </div>
              ${FormBuilder.renderSysToolbar('showWhatsappReceipt', 'receipt_whatsapp', showWhatsapp, 'Automated WhatsApp Receipt', 3, 6)}
            </div>

            <!-- 5. Email Confirmation -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${showEmail ? '1' : '0.6'};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">⠿</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">✉️</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">Email Payment Confirmation</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">PDF payment receipt and registration confirmation via email</div>
                </div>
              </div>
              ${FormBuilder.renderSysToolbar('showEmailConfirmation', 'receipt_email', showEmail, 'Email Payment Confirmation', 4, 6)}
            </div>

            <!-- 6. Tax Invoice Generation -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${showTax ? '1' : '0.6'};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">⠿</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">📄</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">Tax Invoice Generation</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">Compliant GST/Tax invoice calculation with printable receipt format</div>
                </div>
              </div>
              ${FormBuilder.renderSysToolbar('showTaxInvoice', 'receipt_tax', showTax, 'Tax Invoice Generation', 5, 6)}
            </div>
          </div>
        </div>
      `;
    }

    if (secName === 'seat' || secName === 'seats' || secName === 'branch' || secName === 'step_7' || secLabel.includes('seat') || secLabel.includes('signature') || secLabel.includes('branch')) {
      const s = this.template?.settings || {};
      const showSeat = s.showSeatSelection !== false;
      const showSig = s.showDigitalSignature !== false;
      const showPhoto = s.showPassportSelfie !== false;
      const showAgreement = s.showQuietStudyAgreement !== false;
      const showBarcode = s.showKioskBarcode !== false;

      const seatLabel = s.seatSelectionLabel || 'Circular Seat Badges / Desk Map';
      const seatSub = s.seatSelectionSubtext || '22px round circular seat checkmarks with Indigo glow';
      const sigLabel = s.digitalSignatureLabel || 'Digital Signature Canvas';
      const sigSub = s.digitalSignatureSubtext || 'Touch & stylus interactive drawing pad';
      const photoLabel = s.passportSelfieLabel || 'Passport Selfie Capture';
      const photoSub = s.passportSelfieSubtext || 'Webcam photo & document crop studio';
      const agreeTitle = s.quietStudyAgreementTitle || 'Quiet Study Code & Library Rules Agreement';
      const kioskLabel = s.kioskBarcodeLabel || 'Kiosk Entry Barcode';

      return `
        <div style="background: var(--color-surface); border: 1.5px dashed var(--color-primary); border-radius: 8px; padding: 14px; font-size: 0.83rem;">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; flex-wrap: wrap; gap: 8px;">
            <div>
              <div style="font-weight: 700; color: var(--color-primary); font-size: 0.92rem; display: flex; align-items: center; gap: 6px;">
                <span>🪑</span> Live Seat Selection Map & Digital Signature Sub-Options
              </div>
              <div style="font-size: 0.74rem; color: var(--color-text-secondary);">
                Customize interactive desk map, digital signature canvas, selfie studio, rules agreement, and barcode pass
              </div>
            </div>
            <div style="display: flex; gap: 8px; align-items: center;">
              <button type="button" class="btn btn-xs btn-outline-primary fb-edit-component" data-component="quiet_study" style="font-weight: 700; font-size: 0.75rem; padding: 3px 10px;">
                📜 Edit Rules Agreement
              </button>
              <span class="badge badge-primary" style="font-size: 0.68rem;">EDITABLE COMPONENT</span>
            </div>
          </div>

          <!-- Interactive Seat, Signature & Agreement Sub-Options List -->
          <div style="display: flex; flex-direction: column; gap: 8px;">
            <!-- 1. Seat Selection Map -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${showSeat ? '1' : '0.6'};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">⠿</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">🔴/🟢</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">${escapeHTML(seatLabel)}</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">${escapeHTML(seatSub)}</div>
                </div>
              </div>
              ${FormBuilder.renderSysToolbar('showSeatSelection', 'seat_map', showSeat, seatLabel, 0, 5)}
            </div>

            <!-- 2. Digital Signature -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${showSig ? '1' : '0.6'};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">⠿</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">✍️</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">${escapeHTML(sigLabel)}</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">${escapeHTML(sigSub)}</div>
                </div>
              </div>
              ${FormBuilder.renderSysToolbar('showDigitalSignature', 'signature', showSig, sigLabel, 1, 5)}
            </div>

            <!-- 3. Passport Selfie Capture -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${showPhoto ? '1' : '0.6'};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">⠿</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">📸</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">${escapeHTML(photoLabel)}</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">${escapeHTML(photoSub)}</div>
                </div>
              </div>
              ${FormBuilder.renderSysToolbar('showPassportSelfie', 'passport_photo', showPhoto, photoLabel, 2, 5)}
            </div>

            <!-- 4. Quiet Study Code Agreement -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${showAgreement ? '1' : '0.6'};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">⠿</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">📜</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">${escapeHTML(agreeTitle)}</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">Line-by-line numbered library rules and student consent signature checkbox</div>
                </div>
              </div>
              ${FormBuilder.renderSysToolbar('showQuietStudyAgreement', 'quiet_study', showAgreement, agreeTitle, 3, 5)}
            </div>

            <!-- 5. Kiosk Entry Barcode -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${showBarcode ? '1' : '0.6'};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">⠿</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">🎫</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">${escapeHTML(kioskLabel)}</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">${escapeHTML(s.kioskBarcodeSubtext || 'Instant admission barcode for turnstile / attendance gate')}</div>
                </div>
              </div>
              ${FormBuilder.renderSysToolbar('showKioskBarcode', 'kiosk_barcode', showBarcode, kioskLabel, 4, 5)}
            </div>
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
      <div class="fb-field-row" data-id="${field._id}" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: 8px; padding: 10px 12px; display: flex; justify-content: space-between; align-items: center; opacity: ${isActive ? '1' : '0.55'};">
        <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
          <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.2rem; color: var(--color-text-secondary); padding: 2px 6px; user-select: none; touch-action: none;" title="Drag to reorder question">⠿</div>
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

        <div class="btn-icon-group flex-shrink-0">
          ${index > 0 ? `<button type="button" class="btn-icon-action fb-field-up" data-id="${field._id}" data-tooltip="Move Question Up" aria-label="Move Up">⬆️</button>` : ''}
          ${index < total - 1 ? `<button type="button" class="btn-icon-action fb-field-down" data-id="${field._id}" data-tooltip="Move Question Down" aria-label="Move Down">⬇️</button>` : ''}
          <button type="button" class="btn-icon-action fb-field-copy" data-id="${field._id}" data-tooltip="Copy Question to Clipboard" aria-label="Copy">📋</button>
          <button type="button" class="btn-icon-action fb-field-duplicate" data-id="${field._id}" data-tooltip="Instant Duplicate Question" aria-label="Duplicate">📄</button>
          <button type="button" class="btn-icon-action fb-field-toggle" data-id="${field._id}" data-tooltip="${isActive ? 'Click to Hide Question' : 'Click to Show Question'}" aria-label="Toggle Active">
            ${isActive ? '🟢' : '⚪'}
          </button>
          <button type="button" class="btn-icon-action fb-field-edit" data-id="${field._id}" data-tooltip="Edit Question Settings" aria-label="Edit">✏️</button>
          <button type="button" class="btn-icon-action action-delete fb-field-delete" data-id="${field._id}" data-tooltip="Delete Question" aria-label="Delete">🗑️</button>
        </div>
      </div>
    `;
  }

  static renderPreview() {
    const container = document.getElementById('fb-live-preview');
    if (!container) return;

    const activeSecs = this.sections.filter(s => !s.isHidden);
    if (activeSecs.length === 0) {
      container.innerHTML = '<div class="text-center p-4 text-muted">All form sections are currently set to hidden. Make at least one section visible to preview.</div>';
      return;
    }

    if (this.currentPreviewStep >= activeSecs.length) {
      this.currentPreviewStep = 0;
    }

    const currentSec = activeSecs[this.currentPreviewStep];
    const totalSteps = activeSecs.length;

    const secFields = this.fields
      .filter(f => (f.section || 'personal') === currentSec.name && f.isActive !== false)
      .sort((a, b) => (a.order || 0) - (b.order || 0));

    const headerInput = document.getElementById('branding-headerText');
    const taglineInput = document.getElementById('branding-tagline');
    const alignSelect = document.getElementById('branding-alignment');
    const logoSelect = document.getElementById('branding-logoSize');

    const b = this.template.branding || {};
    const headerTitle = (headerInput && headerInput.value.trim()) ? headerInput.value.trim() : (b.headerText || 'Student Admission Wizard');
    const tagline = (taglineInput && taglineInput.value !== undefined) ? taglineInput.value.trim() : (b.tagline || 'Silence, Focus & Success');
    const align = (alignSelect && alignSelect.value) ? alignSelect.value : (b.alignment === 'left' ? 'left' : 'center');
    const logoSize = (logoSelect && logoSelect.value) ? parseInt(logoSelect.value, 10) : parseInt(b.logoSize || '64', 10);

    let html = `
      <!-- Form Header Branding Preview -->
      <div style="margin-bottom: 16px; text-align: ${align}; border-bottom: 1px solid var(--color-border); padding-bottom: 12px;">
        <div style="font-size: ${logoSize >= 96 ? '2.6rem' : logoSize <= 48 ? '1.6rem' : '2.1rem'}; margin-bottom: 4px;">🎓</div>
        <h3 style="margin: 0; font-size: 1.25rem; font-weight: 800; color: var(--color-text-primary);">${escapeHTML(headerTitle)}</h3>
        <p style="margin: 3px 0 0 0; font-size: 0.83rem; color: var(--color-text-secondary);">${escapeHTML(tagline)}</p>
      </div>

      <!-- Stepper Progress Dots -->
      <div style="display: flex; justify-content: space-between; margin-bottom: 16px; position: relative;">
        <div style="position: absolute; top: 12px; left: 10px; right: 10px; height: 2px; background: var(--color-border); z-index: 1;"></div>
        ${activeSecs.map((sec, i) => `
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
            <select class="form-select form-control-sm" id="prev-branch-select">${branchOptions || '<option>Main Campus Central — 🟢 48/50 Available Seats</option>'}</select>
          </div>

          ${secFields.map(f => this.renderPreviewInput(f)).join('')}
        </div>
      `;
    }

    // STEP 3: Membership Plan & Fee Calculator
    if (secName === 'plan') {
      const tplSettings = this.template?.settings || {};
      const showPlans = tplSettings.showPlans !== false;
      const showLockerAddon = tplSettings.showLockerAddon !== false;
      const showReferralCoupon = tplSettings.showReferralCoupon !== false;
      const showShiftSelection = tplSettings.showShiftSelection !== false;
      const showFeeBreakdown = tplSettings.showFeeBreakdown !== false;

      const planOptions = this.plans.map(p => `<option value="${p._id}" ${this.selectedPlanId === p._id ? 'selected' : ''}>${escapeHTML(p.name)} — ₹${p.price} / ${p.duration} ${p.durationType} (${p.shift ? p.shift.toUpperCase() : 'ANY SHIFT'})</option>`).join('');
      const selectedPlan = this.plans.find(p => p._id === this.selectedPlanId) || this.plans[0] || { name: 'Standard Full Day Plan', price: 1500, shift: 'All Day (24 Hours)' };

      return `
        <div style="display: flex; flex-direction: column; gap: 12px;">
          ${showPlans ? `
            <div>
              <label class="form-label text-xs" style="font-weight:700;">Select Membership Plan *</label>
              <select class="form-select form-control-sm" id="prev-plan-select">${planOptions || '<option>Standard 12-Hour Study Plan (₹1,500/mo)</option>'}</select>
            </div>
          ` : ''}

          ${showShiftSelection ? `
            <div>
              <label class="form-label text-xs" style="font-weight:700;">Preferred Study Shift / Timing</label>
              <select class="form-select form-control-sm">
                <option>Full Day (24 Hours - 24x7 Open)</option>
                <option>Morning (7:00 AM - 5:00 PM)</option>
                <option>Evening / Night (5:00 PM - 7:00 AM)</option>
              </select>
            </div>
          ` : ''}

          ${showLockerAddon ? `
            <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 6px; padding: 8px 10px; font-size: 0.82rem; display: flex; align-items: center; gap: 8px;">
              <input type="checkbox" checked disabled style="width: 16px; height: 16px;">
              <span style="font-weight: 600;">🔒 Add Personal Study Locker (+₹200/mo)</span>
            </div>
          ` : ''}

          ${showReferralCoupon ? `
            <div style="display: flex; gap: 8px;">
              <input type="text" class="form-control form-control-sm" placeholder="Referral / Discount Code (Optional)">
              <button type="button" class="btn btn-outline-primary btn-sm" style="font-weight:700;">Apply</button>
            </div>
          ` : ''}

          <!-- Fee Summary Card -->
          ${showFeeBreakdown ? `
            <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 12px; font-size: 0.85rem;">
              <div style="font-weight: 700; color: var(--color-primary); margin-bottom: 6px;">💰 Live Fee Breakdown</div>
              <div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
                <span>Base Plan Fee (${escapeHTML(selectedPlan.name)})</span>
                <span style="font-weight:700;">₹${selectedPlan.price || 1500}</span>
              </div>
              ${showLockerAddon ? `
                <div style="display: flex; justify-content: space-between; margin-bottom: 4px; color: var(--color-primary);">
                  <span>Locker Add-on Fee</span>
                  <span style="font-weight:700;">+₹200</span>
                </div>
              ` : ''}
              ${showReferralCoupon ? `
                <div style="display: flex; justify-content: space-between; margin-bottom: 4px; color: var(--color-success);">
                  <span>Referral Discount</span>
                  <span style="font-weight:700;">-₹0</span>
                </div>
              ` : ''}
              <div style="display: flex; justify-content: space-between; border-top: 1px solid var(--color-border); padding-top: 6px; font-weight: 800; font-size: 0.95rem;">
                <span>Net Payable Amount</span>
                <span style="color: var(--color-primary);">₹${(selectedPlan.price || 1500) + (showLockerAddon ? 200 : 0)}</span>
              </div>
            </div>
          ` : ''}

          ${secFields.map(f => this.renderPreviewInput(f)).join('')}
        </div>
      `;
    }

    // STEP 4: Dynamic Payment Selection
    if (secName === 'payment') {
      const s = this.template?.settings || {};
      const showUpi = s.showUpiPayment !== false;
      const showDesk = s.showDeskPayment !== false;
      const showNetBanking = s.showNetBankingPayment !== false;
      const upiLabel = s.upiPaymentLabel || 'Dynamic UPI QR';
      const deskLabel = s.deskPaymentLabel || 'Pay Later at Desk';
      const nbLabel = s.netBankingPaymentLabel || 'NetBanking / Cards';

      const availableModes = [];
      if (showUpi) availableModes.push({ mode: 'upi', label: `⚡ ${upiLabel}` });
      if (showNetBanking) availableModes.push({ mode: 'card', label: `🏦 ${nbLabel}` });
      if (showDesk) availableModes.push({ mode: 'desk', label: `💵 ${deskLabel}` });

      if (availableModes.length > 0 && !availableModes.some(m => m.mode === this.selectedPaymentMode)) {
        this.selectedPaymentMode = availableModes[0].mode;
      }

      return `
        <div style="display: flex; flex-direction: column; gap: 12px;">
          <label class="form-label text-xs" style="font-weight:700;">Select Payment Mode *</label>
          ${availableModes.length > 0 ? `
          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(130px, 1fr)); gap: 8px;">
            ${availableModes.map(m => `
              <label style="border: 1px solid var(--color-border); border-radius: 8px; padding: 10px; font-size: 0.8rem; font-weight: 600; cursor: pointer; display: flex; align-items: center; gap: 6px; background: ${this.selectedPaymentMode === m.mode ? 'var(--color-surface-hover)' : 'transparent'};">
                <input type="radio" name="prev-pm-mode" value="${m.mode}" ${this.selectedPaymentMode === m.mode ? 'checked' : ''}> ${escapeHTML(m.label)}
              </label>
            `).join('')}
          </div>
          ` : '<div class="text-muted small p-2">All payment methods currently toggled off by admin.</div>'}

          ${this.selectedPaymentMode === 'upi' && showUpi ? `
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
      const s = this.template?.settings || {};
      const showSeat = s.showSeatSelection !== false;
      const seatLabel = s.seatSelectionLabel || 'Choose Your Study Desk Seat';
      const showSig = s.showDigitalSignature !== false;
      const sigLabel = s.digitalSignatureLabel || 'Digital Signature Pad';
      const showPhoto = s.showPassportSelfie !== false;
      const photoLabel = s.passportSelfieLabel || 'Passport Selfie Capture';
      const showAgreement = s.showQuietStudyAgreement !== false;
      const consentText = s.quietStudyConsentText || 'I hereby agree to adhere to the Quiet Study Code Agreement, discipline rules, and timings of the study hall.';

      const availSeats = this.seats.length > 0 ? this.seats : [
        { seatNumber: '01', zone: 'Zone A' }, { seatNumber: '02', zone: 'Zone A' },
        { seatNumber: '03', zone: 'Zone A' }, { seatNumber: '04', zone: 'Zone A' },
        { seatNumber: '05', zone: 'Zone A' }, { seatNumber: '06', zone: 'Zone A' }
      ];

      return `
        <div style="display: flex; flex-direction: column; gap: 14px;">
          ${showSeat ? `
          <div>
            <label class="form-label text-xs" style="font-weight:700;">${escapeHTML(seatLabel)} ${s.seatSelectionRequired ? '*' : ''}</label>
            <div style="display: flex; gap: 8px; overflow-x: auto; padding-bottom: 6px;">
              ${availSeats.slice(0, 6).map((st, idx) => `
                <div style="min-width: 60px; padding: 8px 6px; border: 1.5px solid ${idx === 0 ? '#6c5ce7' : 'var(--color-border)'}; border-radius: 8px; text-align: center; cursor: pointer; background: ${idx === 0 ? 'rgba(108, 92, 231, 0.12)' : 'var(--color-surface)'};">
                  <div style="font-weight: 800; font-size: 0.9rem; color: #6c5ce7;">${escapeHTML(st.seatNumber)}</div>
                  <div style="font-size: 0.65rem; color: var(--color-text-secondary);">${escapeHTML(st.zone || 'Zone A')}</div>
                </div>
              `).join('')}
            </div>
          </div>
          ` : ''}

          ${showPhoto ? `
          <div>
            <label class="form-label text-xs" style="font-weight:700;">${escapeHTML(photoLabel)} ${s.passportSelfieRequired ? '*' : ''}</label>
            <div style="width: 100%; height: 75px; border: 1.5px dashed var(--color-border); border-radius: 8px; background: #ffffff; display: flex; flex-direction: column; align-items: center; justify-content: center; color: var(--color-text-secondary); font-size: 0.82rem;">
              <div style="color: #6c5ce7; font-weight: 600; display: flex; align-items: center; gap: 6px;">
                <span>📸</span> <span>Passport photo / webcam selfie capture</span>
              </div>
            </div>
          </div>
          ` : ''}

          ${secFields.map(f => this.renderPreviewInput(f)).join('')}

          ${showSig ? `
          <div>
            <label class="form-label text-xs" style="font-weight:700;">${escapeHTML(sigLabel)} ${s.digitalSignatureRequired !== false ? '*' : ''}</label>
            <div style="width: 100%; height: 85px; border: 1.5px dashed var(--color-border); border-radius: 8px; background: #ffffff; display: flex; flex-direction: column; align-items: center; justify-content: center; color: var(--color-text-secondary); font-size: 0.82rem;">
              <div style="color: #6c5ce7; font-weight: 600; display: flex; align-items: center; gap: 6px;">
                <span>✍️</span> <span>Draw student signature canvas</span>
              </div>
            </div>
          </div>
          ` : ''}

          ${showAgreement ? `
          <!-- Quiet Study Code Agreement & Terms Checkbox -->
          <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 12px;">
            <label style="display: flex; align-items: flex-start; gap: 10px; cursor: pointer; font-size: 0.83rem; color: var(--color-text-primary); margin: 0; line-height: 1.4;">
              <input type="checkbox" checked style="margin-top: 3px; accent-color: var(--color-primary); width: 16px; height: 16px;">
              <span>${escapeHTML(consentText)} ${s.quietStudyRequired !== false ? '<span style="color: var(--color-danger);">*</span>' : ''}</span>
            </label>
          </div>
          ` : ''}
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

    // Branding Live Preview Inputs (input & change listeners)
    ['headerText', 'tagline', 'alignment', 'logoSize'].forEach(key => {
      const el = document.getElementById(`branding-${key}`);
      if (el) {
        el.addEventListener('input', (e) => {
          if (!this.template.branding) this.template.branding = {};
          this.template.branding[key] = e.target.value;
          this.renderPreview();
        });
        el.addEventListener('change', (e) => {
          if (!this.template.branding) this.template.branding = {};
          this.template.branding[key] = e.target.value;
          this.renderPreview();
        });
      }
    });

    // Save Branding Button
    document.getElementById('fb-save-branding-btn')?.addEventListener('click', async () => {
      try {
        if (!this.template.branding) this.template.branding = {};
        this.template.branding.headerText = document.getElementById('branding-headerText')?.value.trim() || 'Student Admission Wizard';
        this.template.branding.tagline = document.getElementById('branding-tagline')?.value.trim() || 'Silence, Focus & Success';
        this.template.branding.alignment = document.getElementById('branding-alignment')?.value || 'center';
        this.template.branding.logoSize = document.getElementById('branding-logoSize')?.value || '64';

        await api.put('/api/custom-fields/templates/active', {
          branding: this.template.branding
        });
        Toast.success('Header branding saved & synced to live admission form!');
      } catch (err) {
        Toast.error(err.message || 'Failed to save header branding');
      }
    });

    // Add Section
    document.getElementById('fb-add-section-btn')?.addEventListener('click', () => {
      this.openAddSectionModal();
    });

    // Paste Section
    document.getElementById('fb-paste-section-btn')?.addEventListener('click', () => {
      this.pasteSection();
    });

    // Add Field
    document.getElementById('fb-add-field-btn')?.addEventListener('click', () => {
      this.openFieldEditor(null);
    });

    // Undo button
    document.getElementById('fb-undo-btn')?.addEventListener('click', () => {
      this.undoLastAction();
    });
  }

  static undoStack = [];

  static pushUndo(action) {
    if (!this.undoStack) this.undoStack = [];
    this.undoStack.push(action);
    this.updateUndoButton();
  }

  static updateUndoButton() {
    const btn = document.getElementById('fb-undo-btn');
    const countSpan = document.getElementById('fb-undo-count');
    const count = this.undoStack ? this.undoStack.length : 0;
    if (countSpan) countSpan.textContent = count;
    if (btn) btn.style.display = count > 0 ? 'inline-flex' : 'none';
  }

  static async undoLastAction() {
    if (!this.undoStack || this.undoStack.length === 0) return;
    const action = this.undoStack.pop();
    this.updateUndoButton();
    if (action && typeof action.restore === 'function') {
      try {
        await action.restore();
      } catch (e) {
        Toast.error('Failed to undo action: ' + e.message);
      }
    }
  }

  static async moveSection(secName, delta) {
    const curIdx = this.sections.findIndex(s => s.name === secName);
    if (curIdx === -1) return;

    const targetIdx = curIdx + delta;
    if (targetIdx < 0 || targetIdx >= this.sections.length) return;

    // Swap section elements in array
    const [movedSec] = this.sections.splice(curIdx, 1);
    this.sections.splice(targetIdx, 0, movedSec);

    // Reassign 1-based order numbers
    this.sections.forEach((s, idx) => {
      s.order = idx + 1;
    });

    this.renderSections();
    this.renderPreview();

    try {
      if (!this.template) this.template = {};
      this.template.sections = this.sections;
      await api.put('/api/custom-fields/templates/active', {
        sections: this.sections
      });
      Toast.success('Section order saved permanently to database!');
    } catch (e) {
      Toast.error('Failed to save section order to server');
    }
  }

  static async deleteField(fieldId) {
    const field = this.fields.find(f => f._id === fieldId);
    if (!field) return;

    if (!confirm(`Are you sure you want to delete question "${field.label}"?`)) return;

    try {
      const fieldSnapshot = { ...field };
      await api.delete(`/api/custom-fields/${fieldId}`);
      this.fields = this.fields.filter(f => f._id !== fieldId);
      
      this.pushUndo({
        type: 'delete_field',
        title: `Question "${field.label}"`,
        data: fieldSnapshot,
        restore: async () => {
          const payload = { ...fieldSnapshot };
          delete payload._id;
          delete payload.createdAt;
          delete payload.updatedAt;
          const createRes = await api.post('/api/custom-fields', payload);
          if (createRes.success && createRes.data) {
            this.fields.push(createRes.data);
          } else {
            await this.loadData();
          }
          this.renderSections();
          this.renderPreview();
          Toast.success(`Question "${fieldSnapshot.label}" restored!`);
        }
      });

      Toast.undo(`Question "${field.label}" deleted.`, () => {
        this.undoLastAction();
      });

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
      const secSnapshot = { ...sec };
      const movedFields = this.fields.filter(f => f.section === secName).map(f => f._id);

      await api.delete(`/api/custom-fields/sections/${secName}`);
      this.sections = this.sections.filter(s => s.name !== secName);
      this.sections.forEach((s, idx) => { s.order = idx + 1; });
      this.fields.forEach(f => {
        if (f.section === secName) f.section = 'personal';
      });

      if (!this.template) this.template = {};
      this.template.sections = this.sections;
      await api.put('/api/custom-fields/templates/active', { sections: this.sections });

      this.pushUndo({
        type: 'delete_section',
        title: `Section "${sec.label}"`,
        data: secSnapshot,
        restore: async () => {
          this.sections.push(secSnapshot);
          this.sections.sort((a, b) => (a.order || 0) - (b.order || 0));
          if (!this.template) this.template = {};
          this.template.sections = this.sections;
          await api.put('/api/custom-fields/templates/active', { sections: this.sections });
          if (movedFields.length > 0) {
            await Promise.all(movedFields.map(id => api.put(`/api/custom-fields/${id}`, { section: secSnapshot.name })));
            await this.loadData();
          }
          this.renderSections();
          this.renderPreview();
          Toast.success(`Section "${secSnapshot.label}" restored!`);
        }
      });

      Toast.undo(`Section "${sec.label}" deleted.`, () => {
        this.undoLastAction();
      });

      this.renderSections();
      this.renderPreview();
    } catch (err) {
      Toast.error(err.message || 'Failed to delete section');
    }
  }

  static async toggleSectionVisibility(secName) {
    const sec = this.sections.find(s => s.name === secName);
    if (!sec) return;

    sec.isHidden = !sec.isHidden;
    if (!this.template) this.template = {};
    this.template.sections = this.sections;

    try {
      await api.put('/api/custom-fields/templates/active', { sections: this.sections });
      FormBuilder.bustPublicFormCache();
      Toast.success(`Section "${sec.label}" is now ${sec.isHidden ? 'Hidden 🚫 (Will not show to students)' : 'Visible 👁️ in registration form'}!`);
      this.renderSections();
      this.renderPreview();
    } catch (err) {
      console.error('Failed to update section visibility:', err);
      Toast.error('Failed to save section visibility');
    }
  }

  static async toggleTemplateSetting(settingKey, isChecked) {
    if (!this.template) this.template = {};
    if (!this.template.settings) this.template.settings = {};
    this.template.settings[settingKey] = isChecked;

    try {
      await api.put('/api/custom-fields/templates/active', {
        settings: this.template.settings
      });
      if (settingKey === 'showLockerAddon') {
        try {
          await api.put('/api/settings/system-settings', {
            'locker.enableAddon': isChecked
          });
        } catch (e) {}
      }
      FormBuilder.bustPublicFormCache();
      Toast.success(`Display option updated: ${isChecked ? 'Visible 👁️' : 'Hidden 🚫'} in registration form!`);
      this.renderPreview();
    } catch (err) {
      console.error('Failed to update template setting:', err);
      Toast.error('Failed to save display setting');
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

    modalContent.querySelector('#fb-add-section-form')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const label = modalContent.querySelector('#as-label').value.trim();
      const key = modalContent.querySelector('#as-key').value.trim().toLowerCase().replace(/[^a-z0-9_]/g, '_');
      const icon = modalContent.querySelector('#as-icon').value.trim() || '📁';

      if (this.sections.some(s => s.name === key)) {
        Toast.error('A section with this key already exists');
        return;
      }

      const newSec = {
        name: key,
        label,
        icon,
        order: this.sections.length + 1,
        isSystem: false
      };

      this.sections.push(newSec);

      if (!this.template) this.template = {};
      this.template.sections = this.sections;

      try {
        await api.put('/api/custom-fields/templates/active', { sections: this.sections });
        Toast.success(`Custom Section "${label}" created & saved permanently!`);
      } catch (err) {
        Toast.error('Failed to save section to database');
      }

      modal.close();
      this.renderSections();
      this.renderPreview();
    });
  }

  static openRenameSectionModal(secName) {
    const sec = this.sections.find(s => s.name === secName);
    if (!sec) return;

    const modalContent = document.createElement('div');
    modalContent.innerHTML = `
      <form id="fb-rename-section-form" style="display: flex; flex-direction: column; gap: 14px;">
        <div class="form-group">
          <label class="form-label text-xs" style="font-weight:700;">Section Title / Step Heading *</label>
          <input type="text" id="rs-label" class="form-control" value="${escapeHTML(sec.label)}" required>
        </div>
        
        <div class="form-group">
          <label class="form-label text-xs" style="font-weight:700;">Section Icon Emoji</label>
          <input type="text" id="rs-icon" class="form-control" value="${escapeHTML(sec.icon || '📁')}" placeholder="e.g. 👤, 📚, 💎, 💳, 💺, 📍, 📄">
        </div>

        <div style="display: flex; justify-content: flex-end; gap: 10px; margin-top: 10px;">
          <button type="button" class="btn btn-secondary btn-sm fb-cancel-modal-btn" data-modal-close="true">Cancel</button>
          <button type="submit" class="btn btn-primary btn-sm" style="font-weight: 700;">💾 Update Section</button>
        </div>
      </form>
    `;

    const modal = new Modal({
      title: `✏️ Rename Section: ${sec.label}`,
      content: modalContent,
      size: 'sm'
    });
    modal.show();

    modalContent.querySelector('.fb-cancel-modal-btn')?.addEventListener('click', () => {
      modal.close();
      Modal.closeAll();
    });

    modalContent.querySelector('#fb-rename-section-form')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const newLabel = modalContent.querySelector('#rs-label').value.trim();
      const newIcon = modalContent.querySelector('#rs-icon').value.trim() || '📁';

      sec.label = newLabel;
      sec.icon = newIcon;

      if (!this.template) this.template = {};
      this.template.sections = this.sections;

      try {
        await api.put('/api/custom-fields/templates/active', { sections: this.sections });
        try {
          await api.put(`/api/custom-fields/sections/${secName}`, { label: newLabel, icon: newIcon });
        } catch (e) {}
        Toast.success(`Section renamed to "${newLabel}" successfully!`);
      } catch (err) {
        Toast.error('Failed to save renamed section');
      }

      modal.close();
      this.renderSections();
      this.renderPreview();
    });
  }

  static copyField(fieldId) {
    const field = this.fields.find(f => String(f._id) === String(fieldId));
    if (!field) return;

    const copyData = {
      label: field.label,
      type: field.type,
      required: !!field.required,
      colSpan: field.colSpan || 12,
      placeholder: field.placeholder || '',
      helpText: field.helpText || '',
      defaultValue: field.defaultValue || '',
      options: Array.isArray(field.options) ? [...field.options] : [],
      validation: field.validation ? { ...field.validation } : {},
      showIf: field.showIf ? { ...field.showIf } : undefined,
      conditionalSubType: field.conditionalSubType || undefined,
      icon: field.icon || '',
      fieldName: field.fieldName || field.name || 'field'
    };

    FormBuilder.copiedField = copyData;
    try {
      localStorage.setItem('fb_copied_field', JSON.stringify(copyData));
    } catch (e) {}

    Toast.success(`📋 Question "${field.label}" copied! Click "📋 Paste Q" in any section.`);
  }

  static async duplicateField(fieldId) {
    const field = this.fields.find(f => String(f._id) === String(fieldId));
    if (!field) return;

    const uniqueSuffix = Date.now().toString(36).slice(-4);
    const baseKey = (field.fieldName || field.name || 'field').replace(/_copy.*$/, '');
    const newKey = `${baseKey}_copy_${uniqueSuffix}`;

    const newFieldPayload = {
      fieldName: newKey,
      label: `${field.label} (Copy)`,
      type: field.type,
      section: field.section || 'personal',
      required: !!field.required,
      colSpan: field.colSpan || 12,
      placeholder: field.placeholder || '',
      helpText: field.helpText || '',
      defaultValue: field.defaultValue || '',
      options: Array.isArray(field.options) ? [...field.options] : [],
      validation: field.validation ? { ...field.validation } : {},
      showIf: field.showIf ? { ...field.showIf } : undefined,
      conditionalSubType: field.conditionalSubType || undefined,
      icon: field.icon || '',
      isActive: true,
      order: (field.order || 0) + 1
    };

    try {
      Loading.show('Duplicating question...');
      await api.post('/api/custom-fields', newFieldPayload);
      Loading.hide();
      Toast.success(`Question duplicated as "${newFieldPayload.label}"`);
      await FormBuilder.loadData();
    } catch (err) {
      Loading.hide();
      Toast.error(err.message || 'Failed to duplicate question');
    }
  }

  static async pasteField(secName) {
    let copyData = FormBuilder.copiedField;
    if (!copyData) {
      try {
        const stored = localStorage.getItem('fb_copied_field');
        if (stored) copyData = JSON.parse(stored);
      } catch (e) {}
    }

    if (!copyData) {
      Toast.warning('No question copied yet. Click 📋 Copy on any question first!');
      return;
    }

    const uniqueSuffix = Date.now().toString(36).slice(-4);
    const baseKey = (copyData.fieldName || 'field').replace(/_copy.*$/, '');
    const newKey = `${baseKey}_copy_${uniqueSuffix}`;

    const newFieldPayload = {
      fieldName: newKey,
      label: `${copyData.label} (Copy)`,
      type: copyData.type,
      section: secName,
      required: !!copyData.required,
      colSpan: copyData.colSpan || 12,
      placeholder: copyData.placeholder || '',
      helpText: copyData.helpText || '',
      defaultValue: copyData.defaultValue || '',
      options: Array.isArray(copyData.options) ? [...copyData.options] : [],
      validation: copyData.validation ? { ...copyData.validation } : {},
      showIf: copyData.showIf ? { ...copyData.showIf } : undefined,
      conditionalSubType: copyData.conditionalSubType || undefined,
      icon: copyData.icon || '',
      isActive: true,
      order: this.fields.filter(f => f.section === secName).length + 1
    };

    try {
      Loading.show('Pasting question into section...');
      await api.post('/api/custom-fields', newFieldPayload);
      Loading.hide();
      Toast.success(`Pasted "${newFieldPayload.label}" into section!`);
      await FormBuilder.loadData();
    } catch (err) {
      Loading.hide();
      Toast.error(err.message || 'Failed to paste question');
    }
  }

  static copySection(secName) {
    const sec = this.sections.find(s => s.name === secName);
    if (!sec) return;

    const secFields = this.fields.filter(f => (f.section || 'personal') === secName);
    const copyData = {
      section: {
        name: sec.name,
        label: sec.label,
        icon: sec.icon
      },
      fields: secFields.map(f => ({
        fieldName: f.fieldName || f.name,
        label: f.label,
        type: f.type,
        required: !!f.required,
        colSpan: f.colSpan || 12,
        placeholder: f.placeholder || '',
        helpText: f.helpText || '',
        defaultValue: f.defaultValue || '',
        options: Array.isArray(f.options) ? [...f.options] : [],
        validation: f.validation ? { ...f.validation } : {},
        showIf: f.showIf ? { ...f.showIf } : undefined,
        icon: f.icon || ''
      }))
    };

    FormBuilder.copiedSection = copyData;
    try {
      localStorage.setItem('fb_copied_section', JSON.stringify(copyData));
    } catch (e) {}

    Toast.success(`📋 Section "${sec.label}" & ${secFields.length} questions copied! Click "📋 Paste Section" in toolbar.`);
  }

  static async pasteSection() {
    let copyData = FormBuilder.copiedSection;
    if (!copyData) {
      try {
        const stored = localStorage.getItem('fb_copied_section');
        if (stored) copyData = JSON.parse(stored);
      } catch (e) {}
    }

    if (!copyData || !copyData.section) {
      Toast.warning('No section copied yet. Click 📋 Copy Sec on any section first!');
      return;
    }

    const uniqueSuffix = Date.now().toString(36).slice(-4);
    const baseSlug = copyData.section.name.replace(/_copy.*$/, '');
    const newSecKey = `${baseSlug}_copy_${uniqueSuffix}`;
    const newSecLabel = `${copyData.section.label} (Copy)`;

    const newSec = {
      name: newSecKey,
      label: newSecLabel,
      icon: copyData.section.icon || '📁',
      order: this.sections.length + 1,
      isSystem: false
    };

    this.sections.push(newSec);
    if (!this.template) this.template = {};
    this.template.sections = this.sections;

    try {
      Loading.show('Pasting section and questions...');
      await api.put('/api/custom-fields/templates/active', { sections: this.sections });

      // Clone each field from the copied section into the new section
      if (Array.isArray(copyData.fields)) {
        for (const [idx, f] of copyData.fields.entries()) {
          const newFieldKey = `${f.fieldName}_${uniqueSuffix}`;
          await api.post('/api/custom-fields', {
            fieldName: newFieldKey,
            label: f.label,
            type: f.type,
            section: newSecKey,
            required: !!f.required,
            colSpan: f.colSpan || 12,
            placeholder: f.placeholder || '',
            helpText: f.helpText || '',
            defaultValue: f.defaultValue || '',
            options: f.options || [],
            validation: f.validation || {},
            showIf: f.showIf,
            icon: f.icon || '',
            isActive: true,
            order: idx + 1
          });
        }
      }

      Loading.hide();
      Toast.success(`Pasted section "${newSecLabel}" with ${copyData.fields?.length || 0} questions!`);
      await FormBuilder.loadData();
    } catch (err) {
      Loading.hide();
      Toast.error(err.message || 'Failed to paste section');
    }
  }

  static bustPublicFormCache() {
    try {
      localStorage.removeItem('sl_public_config_cache');
      localStorage.removeItem('sl_public_profile_cache');
      localStorage.setItem('sl_config_version', Date.now().toString());
      if (typeof BroadcastChannel !== 'undefined') {
        const bc = new BroadcastChannel('sl_channel');
        bc.postMessage({ type: 'FORM_UPDATED', timestamp: Date.now() });
        setTimeout(() => bc.close(), 100);
      }
    } catch (e) {}
  }

  static async toggleFieldActive(fieldId) {
    const field = this.fields.find(f => f._id === fieldId);
    if (!field) return;

    field.isActive = field.isActive === false ? true : false;
    this.renderSections();
    this.renderPreview();
    FormBuilder.bustPublicFormCache();

    try {
      await api.put(`/api/custom-fields/${fieldId}`, { isActive: field.isActive });
      FormBuilder.bustPublicFormCache();
      Toast.success(`Question "${field.label}" is now ${field.isActive ? 'Active 🟢 (Visible in form)' : 'Hidden ⚪ (Will not show to students)'}`);
    } catch (e) {
      Toast.error('Failed to update question status');
    }
  }

  static async moveField(fieldId, delta) {
    const field = this.fields.find(f => String(f._id) === String(fieldId) || String(f.fieldName) === String(fieldId));
    if (!field) return;

    const secName = field.section || 'personal';
    const secFields = this.fields
      .filter(f => (f.section || 'personal') === secName)
      .sort((a, b) => (a.order || 0) - (b.order || 0));

    const curIdx = secFields.findIndex(f => String(f._id) === String(fieldId) || String(f.fieldName) === String(fieldId));
    if (curIdx === -1) return;

    const targetIdx = curIdx + delta;
    if (targetIdx < 0 || targetIdx >= secFields.length) return;

    // Swap positions
    const [movedField] = secFields.splice(curIdx, 1);
    secFields.splice(targetIdx, 0, movedField);

    // Reassign 1-based order numbers
    secFields.forEach((f, idx) => {
      f.order = idx + 1;
    });

    this.renderSections();
    this.renderPreview();

    try {
      const ordersToSave = this.fields.map(f => ({
        id: f._id,
        fieldName: f.fieldName,
        order: f.order,
        section: f.section
      }));
      const res = await api.put('/api/custom-fields/reorder', { orders: ordersToSave });
      FormBuilder.bustPublicFormCache();
      if (res && res.success) {
        Toast.success('Question order saved permanently');
      } else {
        throw new Error(res?.message || 'Save failed');
      }
    } catch (e) {
      Toast.error('Failed to save field order: ' + (e.message || 'Server error'));
    }
  }

  static openComponentEditor(compKey) {
    if (!this.template) this.template = {};
    if (!this.template.settings) this.template.settings = {};
    const s = this.template.settings;

    let title = '⚙️ Edit System Component';
    let formHtml = '';

    if (compKey === 'plan_manager') {
      title = '💎 Edit Membership Study Plans Display';
      const label = s.planGridLabel || 'Membership Study Plans Grid';
      const sub = s.planGridSubtext || 'Interactive visual study plan cards with duration & shift filters';
      const active = s.showPlans !== false;
      formHtml = `
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Section Title *</label>
          <input type="text" id="ce-label" class="form-control" value="${escapeHTML(label)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Subtitle / Instructions</label>
          <input type="text" id="ce-subtext" class="form-control" value="${escapeHTML(sub)}">
        </div>
        <div class="form-group mb-3">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem;">
            <input type="checkbox" id="ce-active" ${active ? 'checked' : ''}>
            <span class="switch-slider"></span>
            <span>Show Membership Plans Grid in Registration Portal</span>
          </label>
        </div>
        <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 12px; font-size: 0.8rem;">
          <div style="font-weight: 700; color: var(--color-primary); margin-bottom: 4px;">💡 Need to add or edit study plans?</div>
          <div style="color: var(--color-text-secondary); margin-bottom: 8px;">You currently have <strong>${this.plans?.length || 0} active plans</strong> configured in the database.</div>
          <a href="#/plans" class="btn btn-xs btn-outline-primary" style="font-weight: 700;">Open Plans Manager ↗</a>
        </div>
      `;
    } else if (compKey === 'locker_addon') {
      title = '🔒 Edit Personal Study Locker Add-on Option';
      const label = s.lockerAddonLabel || 'Personal Study Locker Add-on Option';
      const sub = s.lockerAddonSubtext || 'Optional "+₹200/mo personal study locker" toggle for students';
      const price = s.lockerAddonPrice || 200;
      const active = s.showLockerAddon !== false;
      formHtml = `
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Option Title *</label>
          <input type="text" id="ce-label" class="form-control" value="${escapeHTML(label)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Monthly Locker Surcharge (₹) *</label>
          <input type="number" id="ce-locker-price" class="form-control" value="${price}" min="0" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Subtitle / Instructions</label>
          <input type="text" id="ce-subtext" class="form-control" value="${escapeHTML(sub)}">
        </div>
        <div class="form-group mb-3">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem;">
            <input type="checkbox" id="ce-active" ${active ? 'checked' : ''}>
            <span class="switch-slider"></span>
            <span>Enable Locker Add-on in Student Registration Form</span>
          </label>
        </div>
      `;
    } else if (compKey === 'coupon_addon') {
      title = '🎟️ Edit Referral / Discount Coupon Promo Field';
      const label = s.couponLabel || 'Referral / Discount Coupon Code Input';
      const ph = s.couponPlaceholder || 'Enter promo code (e.g. SAVE100)';
      const sub = s.couponSubtext || 'Automatic instant discount verification & fee reduction';
      const active = s.showReferralCoupon !== false;
      formHtml = `
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Field Title *</label>
          <input type="text" id="ce-label" class="form-control" value="${escapeHTML(label)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Placeholder Text</label>
          <input type="text" id="ce-placeholder" class="form-control" value="${escapeHTML(ph)}">
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Subtitle / Note</label>
          <input type="text" id="ce-subtext" class="form-control" value="${escapeHTML(sub)}">
        </div>
        <div class="form-group mb-3">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem;">
            <input type="checkbox" id="ce-active" ${active ? 'checked' : ''}>
            <span class="switch-slider"></span>
            <span>Enable Coupon Promo Code Field in Registration Form</span>
          </label>
        </div>
      `;
    } else if (compKey === 'shift_selection') {
      title = '⏰ Edit Preferred Study Shift / Timing Selection';
      const label = s.shiftSelectionLabel || 'Preferred Study Shift / Timing Selection';
      const sub = s.shiftSelectionSubtext || 'Morning, Evening, Night & 24h Full Day shift selection picker';
      const active = s.showShiftSelection !== false;
      formHtml = `
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Picker Title *</label>
          <input type="text" id="ce-label" class="form-control" value="${escapeHTML(label)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Subtitle / Instructions</label>
          <input type="text" id="ce-subtext" class="form-control" value="${escapeHTML(sub)}">
        </div>
        <div class="form-group mb-3">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem;">
            <input type="checkbox" id="ce-active" ${active ? 'checked' : ''}>
            <span class="switch-slider"></span>
            <span>Enable Study Shift Selection in Registration Form</span>
          </label>
        </div>
      `;
    } else if (compKey === 'fee_calculator') {
      title = '💰 Edit Live Fee Breakdown Auto-Calculator Card';
      const label = s.feeBreakdownLabel || 'Live Fee Breakdown Auto-Calculator Card';
      const sub = s.feeBreakdownSubtext || 'Real-time itemized price breakdown (Plan base + Locker - Discount = Total)';
      const active = s.showFeeBreakdown !== false;
      formHtml = `
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Calculator Title *</label>
          <input type="text" id="ce-label" class="form-control" value="${escapeHTML(label)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Subtitle / Instructions</label>
          <input type="text" id="ce-subtext" class="form-control" value="${escapeHTML(sub)}">
        </div>
        <div class="form-group mb-3">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem;">
            <input type="checkbox" id="ce-active" ${active ? 'checked' : ''}>
            <span class="switch-slider"></span>
            <span>Show Live Fee Breakdown Auto-Calculator</span>
          </label>
        </div>
      `;
    } else if (compKey === 'receipt_whatsapp') {
      title = '📱 Edit Automated WhatsApp Receipt Dispatch';
      const label = s.whatsappReceiptLabel || 'Automated WhatsApp Receipt';
      const sub = s.whatsappReceiptSubtext || 'Instant fee receipt message dispatch to student\'s WhatsApp number';
      const active = s.showWhatsappReceipt !== false;
      formHtml = `
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Receipt Notice Label *</label>
          <input type="text" id="ce-label" class="form-control" value="${escapeHTML(label)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Description Note</label>
          <input type="text" id="ce-subtext" class="form-control" value="${escapeHTML(sub)}">
        </div>
        <div class="form-group mb-3">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem;">
            <input type="checkbox" id="ce-active" ${active ? 'checked' : ''}>
            <span class="switch-slider"></span>
            <span>Send Instant WhatsApp Fee Receipt to Student</span>
          </label>
        </div>
      `;
    } else if (compKey === 'receipt_email') {
      title = '✉️ Edit Email Payment Confirmation Notice';
      const label = s.emailConfirmationLabel || 'Email Payment Confirmation';
      const sub = s.emailConfirmationSubtext || 'PDF payment receipt and registration confirmation via email';
      const active = s.showEmailConfirmation !== false;
      formHtml = `
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Confirmation Label *</label>
          <input type="text" id="ce-label" class="form-control" value="${escapeHTML(label)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Description Note</label>
          <input type="text" id="ce-subtext" class="form-control" value="${escapeHTML(sub)}">
        </div>
        <div class="form-group mb-3">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem;">
            <input type="checkbox" id="ce-active" ${active ? 'checked' : ''}>
            <span class="switch-slider"></span>
            <span>Send Email Payment Confirmation with PDF</span>
          </label>
        </div>
      `;
    } else if (compKey === 'receipt_tax') {
      title = '📄 Edit Tax Invoice Generation Notice';
      const label = s.taxInvoiceLabel || 'Tax Invoice Generation';
      const sub = s.taxInvoiceSubtext || 'Compliant GST/Tax invoice calculation with printable receipt format';
      const active = s.showTaxInvoice !== false;
      formHtml = `
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Invoice Notice Label *</label>
          <input type="text" id="ce-label" class="form-control" value="${escapeHTML(label)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Description Note</label>
          <input type="text" id="ce-subtext" class="form-control" value="${escapeHTML(sub)}">
        </div>
        <div class="form-group mb-3">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem;">
            <input type="checkbox" id="ce-active" ${active ? 'checked' : ''}>
            <span class="switch-slider"></span>
            <span>Enable Tax / GST Invoice Generation</span>
          </label>
        </div>
      `;
    } else if (compKey === 'upi') {
      title = '⚡ Edit Dynamic UPI QR Payment Gateway';
      const label = s.upiPaymentLabel || 'Dynamic UPI QR';
      const sub = s.upiPaymentSubtext || 'GPay / PhonePe / Paytm + 12-digit UTR Verification';
      const active = s.showUpiPayment !== false;
      formHtml = `
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Gateway Title *</label>
          <input type="text" id="ce-label" class="form-control" value="${escapeHTML(label)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Subtitle / Instructions</label>
          <input type="text" id="ce-subtext" class="form-control" value="${escapeHTML(sub)}">
        </div>
        <div class="form-group mb-3">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem;">
            <input type="checkbox" id="ce-active" ${active ? 'checked' : ''}>
            <span class="switch-slider"></span>
            <span>Enable Dynamic UPI QR in Student Registration Form</span>
          </label>
        </div>
      `;
    } else if (compKey === 'desk') {
      title = '💵 Edit Pay Later at Desk Payment Method';
      const label = s.deskPaymentLabel || 'Pay Later at Desk';
      const sub = s.deskPaymentSubtext || 'Pre-reserves admission & seat; cash paid on arrival';
      const active = s.showDeskPayment !== false;
      formHtml = `
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Method Title *</label>
          <input type="text" id="ce-label" class="form-control" value="${escapeHTML(label)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Subtitle / Cash Policy Note</label>
          <input type="text" id="ce-subtext" class="form-control" value="${escapeHTML(sub)}">
        </div>
        <div class="form-group mb-3">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem;">
            <input type="checkbox" id="ce-active" ${active ? 'checked' : ''}>
            <span class="switch-slider"></span>
            <span>Enable Pay Later at Desk in Student Registration Form</span>
          </label>
        </div>
      `;
    } else if (compKey === 'netbanking') {
      title = '🏦 Edit NetBanking / Cards Payment Gateway';
      const label = s.netBankingPaymentLabel || 'NetBanking / Cards';
      const sub = s.netBankingPaymentSubtext || 'Bank reference logging & printable receipt generator';
      const active = s.showNetBankingPayment !== false;
      formHtml = `
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Gateway Title *</label>
          <input type="text" id="ce-label" class="form-control" value="${escapeHTML(label)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Subtitle / Bank Transfer Note</label>
          <input type="text" id="ce-subtext" class="form-control" value="${escapeHTML(sub)}">
        </div>
        <div class="form-group mb-3">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem;">
            <input type="checkbox" id="ce-active" ${active ? 'checked' : ''}>
            <span class="switch-slider"></span>
            <span>Enable NetBanking / Cards in Student Registration Form</span>
          </label>
        </div>
      `;
    } else if (compKey === 'receipt_options') {
      title = '📩 Edit Automated Receipts & Invoicing Notices';
      const waLabel = s.whatsappReceiptLabel || 'Automated WhatsApp Receipt';
      const emLabel = s.emailConfirmationLabel || 'Email Payment Confirmation';
      const taxLabel = s.taxInvoiceLabel || 'Tax Invoice Generation';
      const showWa = s.showWhatsappReceipt !== false;
      const showEm = s.showEmailConfirmation !== false;
      const showTax = s.showTaxInvoice !== false;
      formHtml = `
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">WhatsApp Receipt Label</label>
          <input type="text" id="ce-wa-label" class="form-control" value="${escapeHTML(waLabel)}">
          <label class="switch-label mt-2" style="font-weight: 600; font-size: 0.82rem;">
            <input type="checkbox" id="ce-wa-active" ${showWa ? 'checked' : ''}>
            <span class="switch-slider"></span>
            <span>Send Instant WhatsApp Fee Receipt</span>
          </label>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Email Confirmation Label</label>
          <input type="text" id="ce-em-label" class="form-control" value="${escapeHTML(emLabel)}">
          <label class="switch-label mt-2" style="font-weight: 600; font-size: 0.82rem;">
            <input type="checkbox" id="ce-em-active" ${showEm ? 'checked' : ''}>
            <span class="switch-slider"></span>
            <span>Send Email Payment Confirmation</span>
          </label>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Tax Invoice Label</label>
          <input type="text" id="ce-tax-label" class="form-control" value="${escapeHTML(taxLabel)}">
          <label class="switch-label mt-2" style="font-weight: 600; font-size: 0.82rem;">
            <input type="checkbox" id="ce-tax-active" ${showTax ? 'checked' : ''}>
            <span class="switch-slider"></span>
            <span>Enable Tax Invoice Generation</span>
          </label>
        </div>
      `;
    } else if (compKey === 'payment_all') {
      title = '⚙️ Configure All Payment Gateways & Notices';
      const showUpi = s.showUpiPayment !== false;
      const showDesk = s.showDeskPayment !== false;
      const showNetBanking = s.showNetBankingPayment !== false;
      const upiLabel = s.upiPaymentLabel || 'Dynamic UPI QR';
      const deskLabel = s.deskPaymentLabel || 'Pay Later at Desk';
      const nbLabel = s.netBankingPaymentLabel || 'NetBanking / Cards';
      formHtml = `
        <div style="display: flex; flex-direction: column; gap: 12px;">
          <div style="background: var(--color-bg-secondary); padding: 12px; border-radius: 8px; border: 1px solid var(--color-border);">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
              <span style="font-weight: 700; font-size: 0.85rem;">⚡ Dynamic UPI QR</span>
              <input type="checkbox" id="ce-all-upi" ${showUpi ? 'checked' : ''} style="width: 18px; height: 18px; accent-color: var(--color-primary); cursor: pointer;">
            </div>
            <input type="text" id="ce-all-upi-label" class="form-control form-control-sm" value="${escapeHTML(upiLabel)}" placeholder="Gateway Display Name">
          </div>
          <div style="background: var(--color-bg-secondary); padding: 12px; border-radius: 8px; border: 1px solid var(--color-border);">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
              <span style="font-weight: 700; font-size: 0.85rem;">💵 Pay Later at Desk</span>
              <input type="checkbox" id="ce-all-desk" ${showDesk ? 'checked' : ''} style="width: 18px; height: 18px; accent-color: var(--color-primary); cursor: pointer;">
            </div>
            <input type="text" id="ce-all-desk-label" class="form-control form-control-sm" value="${escapeHTML(deskLabel)}" placeholder="Method Display Name">
          </div>
          <div style="background: var(--color-bg-secondary); padding: 12px; border-radius: 8px; border: 1px solid var(--color-border);">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
              <span style="font-weight: 700; font-size: 0.85rem;">🏦 NetBanking / Cards</span>
              <input type="checkbox" id="ce-all-nb" ${showNetBanking ? 'checked' : ''} style="width: 18px; height: 18px; accent-color: var(--color-primary); cursor: pointer;">
            </div>
            <input type="text" id="ce-all-nb-label" class="form-control form-control-sm" value="${escapeHTML(nbLabel)}" placeholder="Gateway Display Name">
          </div>
        </div>
      `;
    } else if (compKey === 'seat_map') {
      title = '🪑 Edit Live Seat Selection Map & Badges';
      const label = s.seatSelectionLabel || 'Circular Seat Badges / Desk Map';
      const sub = s.seatSelectionSubtext || '22px round circular seat checkmarks with Indigo glow';
      const active = s.showSeatSelection !== false;
      const req = !!s.seatSelectionRequired;
      formHtml = `
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Component Title *</label>
          <input type="text" id="ce-label" class="form-control" value="${escapeHTML(label)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Badge Style & Description</label>
          <input type="text" id="ce-subtext" class="form-control" value="${escapeHTML(sub)}">
        </div>
        <div class="form-group mb-3" style="display: flex; flex-direction: column; gap: 8px; background: var(--color-bg-secondary); padding: 10px; border-radius: 8px;">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem; margin: 0;">
            <input type="checkbox" id="ce-active" ${active ? 'checked' : ''}>
            <span class="switch-slider"></span>
            <span>Enable Live Seat Selection Map</span>
          </label>
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem; margin: 0;">
            <input type="checkbox" id="ce-required" ${req ? 'checked' : ''}>
            <span class="switch-slider"></span>
            <span>Require Student to Select Desk (Mandatory)</span>
          </label>
        </div>
      `;
    } else if (compKey === 'signature') {
      title = '✍️ Edit Digital Signature Canvas';
      const label = s.digitalSignatureLabel || 'Digital Signature Canvas';
      const sub = s.digitalSignatureSubtext || 'Touch & stylus interactive drawing pad';
      const active = s.showDigitalSignature !== false;
      const req = s.digitalSignatureRequired !== false;
      formHtml = `
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Canvas Title *</label>
          <input type="text" id="ce-label" class="form-control" value="${escapeHTML(label)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Instructions / Subtext</label>
          <input type="text" id="ce-subtext" class="form-control" value="${escapeHTML(sub)}">
        </div>
        <div class="form-group mb-3" style="display: flex; flex-direction: column; gap: 8px; background: var(--color-bg-secondary); padding: 10px; border-radius: 8px;">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem; margin: 0;">
            <input type="checkbox" id="ce-active" ${active ? 'checked' : ''}>
            <span class="switch-slider"></span>
            <span>Enable Digital Signature Canvas</span>
          </label>
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem; margin: 0;">
            <input type="checkbox" id="ce-required" ${req ? 'checked' : ''}>
            <span class="switch-slider"></span>
            <span>Mandatory Signature to Complete Admission</span>
          </label>
        </div>
      `;
    } else if (compKey === 'passport_photo') {
      title = '📸 Edit Passport Selfie Capture';
      const label = s.passportSelfieLabel || 'Passport Selfie Capture';
      const sub = s.passportSelfieSubtext || 'Webcam photo & document crop studio';
      const active = s.showPassportSelfie !== false;
      const req = !!s.passportSelfieRequired;
      formHtml = `
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Studio Title *</label>
          <input type="text" id="ce-label" class="form-control" value="${escapeHTML(label)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Studio Subtitle / Instructions</label>
          <input type="text" id="ce-subtext" class="form-control" value="${escapeHTML(sub)}">
        </div>
        <div class="form-group mb-3" style="display: flex; flex-direction: column; gap: 8px; background: var(--color-bg-secondary); padding: 10px; border-radius: 8px;">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem; margin: 0;">
            <input type="checkbox" id="ce-active" ${active ? 'checked' : ''}>
            <span class="switch-slider"></span>
            <span>Enable Passport Photo / Live Selfie Studio</span>
          </label>
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem; margin: 0;">
            <input type="checkbox" id="ce-required" ${req ? 'checked' : ''}>
            <span class="switch-slider"></span>
            <span>Mandatory Photo for ID Card Issuance</span>
          </label>
        </div>
      `;
    } else if (compKey === 'quiet_study') {
      title = '📜 Edit Quiet Study Code & Library Rules Agreement';
      const agreeTitle = s.quietStudyAgreementTitle || 'Quiet Study Code & Library Rules Agreement';
      const defaultRules = '1. Pin-Drop Silence: Strict silence must be maintained inside reading halls at all times. Whispering or phone calls inside study zones is strictly forbidden.\n2. Mobile Phone Protocol: Phones must be switched to silent or flight mode. Attend urgent phone calls outside in corridors.\n3. Assigned Desk Protocol: Occupy only your allotted desk number and adhere strictly to your registered shift timing.\n4. Cleanliness & Socket Safety: Keep your study desk clean. Turn off lights, fans, and socket chargers when leaving your seat.\n5. ID Pass & Gate Access: Carry your Student ID / Registration Pass for kiosk check-in.\n6. Fee Policy & Non-Refundability: Membership fees once paid are non-refundable.';
      const rules = s.quietStudyAgreementRules || defaultRules;
      const consentText = s.quietStudyConsentText || 'I have read, understood, and agree to strictly abide by the Library Rules, Code of Conduct, and Payment Policies.';
      const active = s.showQuietStudyAgreement !== false;
      const req = s.quietStudyRequired !== false;

      formHtml = `
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Agreement Header Title *</label>
          <input type="text" id="ce-agree-title" class="form-control" value="${escapeHTML(agreeTitle)}" required>
        </div>
        <div class="form-group mb-3">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px;">
            <label class="form-label text-xs" style="font-weight:700; margin: 0;">Library Rules & Code of Conduct (Line-by-line editor) *</label>
            <span style="font-size: 0.72rem; color: var(--color-text-secondary);">One rule per line</span>
          </div>
          <textarea id="ce-agree-rules" class="form-control" rows="7" style="font-family: monospace; font-size: 0.82rem; line-height: 1.5;" required>${escapeHTML(rules)}</textarea>
          <small class="text-muted" style="font-size: 0.72rem;">Each line will render as a distinct rule point in the student's scrollable agreement review box.</small>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Student Consent Checkbox Label *</label>
          <input type="text" id="ce-agree-consent" class="form-control" value="${escapeHTML(consentText)}" required>
        </div>
        <div class="form-group mb-3" style="display: flex; flex-direction: column; gap: 8px; background: var(--color-bg-secondary); padding: 10px; border-radius: 8px;">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem; margin: 0;">
            <input type="checkbox" id="ce-agree-active" ${active ? 'checked' : ''}>
            <span class="switch-slider"></span>
            <span>Show Quiet Study Code Agreement in Registration Form</span>
          </label>
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem; margin: 0;">
            <input type="checkbox" id="ce-agree-req" ${req ? 'checked' : ''}>
            <span class="switch-slider"></span>
            <span>Mandatory Agreement Checkbox (Student must agree before submission)</span>
          </label>
        </div>
      `;
    } else if (compKey === 'kiosk_barcode') {
      title = '🎫 Edit Kiosk Entry Barcode Pass';
      const label = s.kioskBarcodeLabel || 'Kiosk Entry Barcode';
      const sub = s.kioskBarcodeSubtext || 'Instant admission barcode for turnstile / attendance gate';
      const active = s.showKioskBarcode !== false;
      formHtml = `
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Badge Title *</label>
          <input type="text" id="ce-label" class="form-control" value="${escapeHTML(label)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Description</label>
          <input type="text" id="ce-subtext" class="form-control" value="${escapeHTML(sub)}">
        </div>
        <div class="form-group mb-3">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem;">
            <input type="checkbox" id="ce-active" ${active ? 'checked' : ''}>
            <span class="switch-slider"></span>
            <span>Generate Kiosk Barcode on Student Pass</span>
          </label>
        </div>
      `;
    }

    const modalContent = document.createElement('div');
    modalContent.innerHTML = `
      <form id="fb-component-edit-form" style="display: flex; flex-direction: column; gap: 14px;">
        ${formHtml}
        <div style="display: flex; justify-content: flex-end; gap: 10px; border-top: 1px solid var(--color-border); padding-top: 14px; margin-top: 6px;">
          <button type="button" class="btn btn-secondary fb-cancel-modal-btn">Cancel</button>
          <button type="submit" class="btn btn-primary" style="font-weight: 700;">💾 Save Changes</button>
        </div>
      </form>
    `;

    const modal = new Modal({
      title,
      content: modalContent,
      size: 'md'
    });
    modal.show();

    modalContent.querySelector('.fb-cancel-modal-btn')?.addEventListener('click', () => {
      modal.close();
      Modal.closeAll();
    });

    modalContent.querySelector('#fb-component-edit-form')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      try {
        if (compKey === 'plan_manager') {
          s.planGridLabel = modalContent.querySelector('#ce-label').value.trim();
          s.planGridSubtext = modalContent.querySelector('#ce-subtext').value.trim();
          s.showPlans = modalContent.querySelector('#ce-active').checked;
        } else if (compKey === 'locker_addon') {
          s.lockerAddonLabel = modalContent.querySelector('#ce-label').value.trim();
          s.lockerAddonPrice = Number(modalContent.querySelector('#ce-locker-price').value) || 200;
          s.lockerAddonSubtext = modalContent.querySelector('#ce-subtext').value.trim();
          s.showLockerAddon = modalContent.querySelector('#ce-active').checked;
        } else if (compKey === 'coupon_addon') {
          s.couponLabel = modalContent.querySelector('#ce-label').value.trim();
          s.couponPlaceholder = modalContent.querySelector('#ce-placeholder').value.trim();
          s.couponSubtext = modalContent.querySelector('#ce-subtext').value.trim();
          s.showReferralCoupon = modalContent.querySelector('#ce-active').checked;
        } else if (compKey === 'shift_selection') {
          s.shiftSelectionLabel = modalContent.querySelector('#ce-label').value.trim();
          s.shiftSelectionSubtext = modalContent.querySelector('#ce-subtext').value.trim();
          s.showShiftSelection = modalContent.querySelector('#ce-active').checked;
        } else if (compKey === 'fee_calculator') {
          s.feeBreakdownLabel = modalContent.querySelector('#ce-label').value.trim();
          s.feeBreakdownSubtext = modalContent.querySelector('#ce-subtext').value.trim();
          s.showFeeBreakdown = modalContent.querySelector('#ce-active').checked;
        } else if (compKey === 'receipt_whatsapp') {
          s.whatsappReceiptLabel = modalContent.querySelector('#ce-label').value.trim();
          s.whatsappReceiptSubtext = modalContent.querySelector('#ce-subtext').value.trim();
          s.showWhatsappReceipt = modalContent.querySelector('#ce-active').checked;
        } else if (compKey === 'receipt_email') {
          s.emailConfirmationLabel = modalContent.querySelector('#ce-label').value.trim();
          s.emailConfirmationSubtext = modalContent.querySelector('#ce-subtext').value.trim();
          s.showEmailConfirmation = modalContent.querySelector('#ce-active').checked;
        } else if (compKey === 'receipt_tax') {
          s.taxInvoiceLabel = modalContent.querySelector('#ce-label').value.trim();
          s.taxInvoiceSubtext = modalContent.querySelector('#ce-subtext').value.trim();
          s.showTaxInvoice = modalContent.querySelector('#ce-active').checked;
        } else if (compKey === 'upi') {
          s.upiPaymentLabel = modalContent.querySelector('#ce-label').value.trim();
          s.upiPaymentSubtext = modalContent.querySelector('#ce-subtext').value.trim();
          s.showUpiPayment = modalContent.querySelector('#ce-active').checked;
        } else if (compKey === 'desk') {
          s.deskPaymentLabel = modalContent.querySelector('#ce-label').value.trim();
          s.deskPaymentSubtext = modalContent.querySelector('#ce-subtext').value.trim();
          s.showDeskPayment = modalContent.querySelector('#ce-active').checked;
        } else if (compKey === 'netbanking') {
          s.netBankingPaymentLabel = modalContent.querySelector('#ce-label').value.trim();
          s.netBankingPaymentSubtext = modalContent.querySelector('#ce-subtext').value.trim();
          s.showNetBankingPayment = modalContent.querySelector('#ce-active').checked;
        } else if (compKey === 'receipt_options') {
          s.whatsappReceiptLabel = modalContent.querySelector('#ce-wa-label').value.trim();
          s.showWhatsappReceipt = modalContent.querySelector('#ce-wa-active').checked;
          s.emailConfirmationLabel = modalContent.querySelector('#ce-em-label').value.trim();
          s.showEmailConfirmation = modalContent.querySelector('#ce-em-active').checked;
          s.taxInvoiceLabel = modalContent.querySelector('#ce-tax-label').value.trim();
          s.showTaxInvoice = modalContent.querySelector('#ce-tax-active').checked;
        } else if (compKey === 'payment_all') {
          s.showUpiPayment = modalContent.querySelector('#ce-all-upi').checked;
          s.upiPaymentLabel = modalContent.querySelector('#ce-all-upi-label').value.trim();
          s.showDeskPayment = modalContent.querySelector('#ce-all-desk').checked;
          s.deskPaymentLabel = modalContent.querySelector('#ce-all-desk-label').value.trim();
          s.showNetBankingPayment = modalContent.querySelector('#ce-all-nb').checked;
          s.netBankingPaymentLabel = modalContent.querySelector('#ce-all-nb-label').value.trim();
        } else if (compKey === 'seat_map') {
          s.seatSelectionLabel = modalContent.querySelector('#ce-label').value.trim();
          s.seatSelectionSubtext = modalContent.querySelector('#ce-subtext').value.trim();
          s.showSeatSelection = modalContent.querySelector('#ce-active').checked;
          s.seatSelectionRequired = modalContent.querySelector('#ce-required').checked;
        } else if (compKey === 'signature') {
          s.digitalSignatureLabel = modalContent.querySelector('#ce-label').value.trim();
          s.digitalSignatureSubtext = modalContent.querySelector('#ce-subtext').value.trim();
          s.showDigitalSignature = modalContent.querySelector('#ce-active').checked;
          s.digitalSignatureRequired = modalContent.querySelector('#ce-required').checked;
        } else if (compKey === 'passport_photo') {
          s.passportSelfieLabel = modalContent.querySelector('#ce-label').value.trim();
          s.passportSelfieSubtext = modalContent.querySelector('#ce-subtext').value.trim();
          s.showPassportSelfie = modalContent.querySelector('#ce-active').checked;
          s.passportSelfieRequired = modalContent.querySelector('#ce-required').checked;
        } else if (compKey === 'quiet_study') {
          s.quietStudyAgreementTitle = modalContent.querySelector('#ce-agree-title').value.trim();
          s.quietStudyAgreementRules = modalContent.querySelector('#ce-agree-rules').value.trim();
          s.quietStudyConsentText = modalContent.querySelector('#ce-agree-consent').value.trim();
          s.showQuietStudyAgreement = modalContent.querySelector('#ce-agree-active').checked;
          s.quietStudyRequired = modalContent.querySelector('#ce-agree-req').checked;

          try {
            const ruleLines = s.quietStudyAgreementRules.split('\n').map(l => l.trim()).filter(Boolean);
            await api.put('/api/settings/profile', { rules: ruleLines });
          } catch (err) {}
        } else if (compKey === 'kiosk_barcode') {
          s.kioskBarcodeLabel = modalContent.querySelector('#ce-label').value.trim();
          s.kioskBarcodeSubtext = modalContent.querySelector('#ce-subtext').value.trim();
          s.showKioskBarcode = modalContent.querySelector('#ce-active').checked;
        }

        await api.put('/api/custom-fields/templates/active', {
          settings: s
        });
        FormBuilder.bustPublicFormCache();
        Toast.success('Component settings saved successfully!');
        modal.close();
        Modal.closeAll();
        this.renderSections();
        this.renderPreview();
      } catch (err) {
        Toast.error(err.message || 'Failed to save component settings');
      }
    });
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
              <option value="checkbox" ${field.type === 'checkbox' ? 'selected' : ''}>✅ Single Checkbox (Yes/No)</option>
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
              <optgroup label="── Logic ──">
              <option value="conditional" ${field.type === 'conditional' ? 'selected' : ''}>🔀 Conditional (Show If...)</option>
              </optgroup>
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

        <div style="display: flex; gap: 20px; align-items: center; background: var(--color-bg-secondary); padding: 10px 14px; border-radius: 8px; flex-wrap: wrap;">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem; margin: 0;">
            <input type="checkbox" id="fe-required" ${field.required ? 'checked' : ''}>
            <span class="switch-slider"></span>
            <span>🔴 Mandatory / Required Field</span>
          </label>
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem; margin: 0;">
            <input type="checkbox" id="fe-halfwidth" ${field.colSpan === 6 ? 'checked' : ''}>
            <span class="switch-slider"></span>
            <span>📐 50% Half Width Row</span>
          </label>
        </div>

        <div id="fe-options-wrap" style="display: ${['select', 'radio', 'multiselect'].includes(field.type) ? 'block' : 'none'};">
          <label class="form-label text-xs" style="font-weight:700;">Options List (Comma-separated)</label>
          <input type="text" id="fe-options" class="form-control" value="${escapeHTML((field.options || []).join(', '))}" placeholder="Option 1, Option 2, Option 3">
        </div>

        <!-- ── Conditional Show-If Panel ─────────────────────────────────── -->
        <div id="fe-conditional-wrap" style="display: ${field.type === 'conditional' ? 'block' : 'none'}; background: rgba(99,102,241,0.07); border: 1px solid rgba(99,102,241,0.25); border-radius: 10px; padding: 14px; margin-top: 4px;">
          <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-primary); margin-bottom: 10px;">🔀 Conditional Logic — Show this field only when:</div>
          <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 10px; margin-bottom: 10px;">
            <div class="form-group" style="margin:0;">
              <label class="form-label text-xs" style="font-weight:700;">Trigger Field</label>
              <select id="fe-show-if-field" class="form-select" style="font-size:0.85rem;">
                <option value="">— Pick a field —</option>
                ${(FormBuilder.allFields || []).filter(f => f.fieldName !== field.fieldName).map(f => `<option value="${escapeHTML(f.fieldName)}" ${(field.showIf?.field === f.fieldName) ? 'selected' : ''}>${escapeHTML(f.label)} (${escapeHTML(f.fieldName)})</option>`).join('')}
              </select>
            </div>
            <div class="form-group" style="margin:0;">
              <label class="form-label text-xs" style="font-weight:700;">Condition</label>
              <select id="fe-show-if-op" class="form-select" style="font-size:0.85rem;">
                <option value="equals" ${field.showIf?.operator === 'equals' ? 'selected' : ''}>= Equals</option>
                <option value="not_equals" ${field.showIf?.operator === 'not_equals' ? 'selected' : ''}>≠ Not Equals</option>
                <option value="contains" ${field.showIf?.operator === 'contains' ? 'selected' : ''}>Contains</option>
                <option value="is_checked" ${field.showIf?.operator === 'is_checked' ? 'selected' : ''}>✅ Is Checked</option>
                <option value="is_not_checked" ${field.showIf?.operator === 'is_not_checked' ? 'selected' : ''}>☐ Is Unchecked</option>
                <option value="is_not_empty" ${field.showIf?.operator === 'is_not_empty' ? 'selected' : ''}>Is Filled</option>
                <option value="is_empty" ${field.showIf?.operator === 'is_empty' ? 'selected' : ''}>Is Empty</option>
              </select>
            </div>
            <div class="form-group" style="margin:0;">
              <label class="form-label text-xs" style="font-weight:700;">Trigger Value</label>
              <input type="text" id="fe-show-if-val" class="form-control" style="font-size:0.85rem;" value="${escapeHTML(field.showIf?.value || '')}" placeholder="e.g. Yes, Option A">
            </div>
          </div>
          <div class="form-group" style="margin:0;">
            <label class="form-label text-xs" style="font-weight:700;">This field's own type (what it collects when shown)</label>
            <select id="fe-conditional-subtype" class="form-select" style="font-size:0.85rem;">
              <option value="text" ${(field.conditionalSubType || 'text') === 'text' ? 'selected' : ''}>📝 Short Text</option>
              <option value="textarea" ${field.conditionalSubType === 'textarea' ? 'selected' : ''}>📄 Long Paragraph</option>
              <option value="number" ${field.conditionalSubType === 'number' ? 'selected' : ''}>🔢 Number</option>
              <option value="select" ${field.conditionalSubType === 'select' ? 'selected' : ''}>📋 Dropdown</option>
              <option value="date" ${field.conditionalSubType === 'date' ? 'selected' : ''}>📅 Date</option>
              <option value="checkbox" ${field.conditionalSubType === 'checkbox' ? 'selected' : ''}>✅ Checkbox</option>
              <option value="file" ${field.conditionalSubType === 'file' ? 'selected' : ''}>📎 File Upload</option>
            </select>
          </div>
          <div style="font-size:0.78rem; color: var(--color-text-muted); margin-top: 8px;">
            💡 Example: "If <strong>has_laptop</strong> <em>is_checked</em> → show this field"
          </div>
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

    // Toggle options + conditional panels on type change
    modalContent.querySelector('#fe-type')?.addEventListener('change', (e) => {
      const val = e.target.value;
      const showOpts = ['select', 'radio', 'multiselect'].includes(val);
      const showCond = val === 'conditional';
      modalContent.querySelector('#fe-options-wrap').style.display = showOpts ? 'block' : 'none';
      modalContent.querySelector('#fe-conditional-wrap').style.display = showCond ? 'block' : 'none';
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

      // Conditional show-if logic
      let showIf = null;
      let conditionalSubType = null;
      if (type === 'conditional') {
        const triggerField = modalContent.querySelector('#fe-show-if-field')?.value;
        const operator = modalContent.querySelector('#fe-show-if-op')?.value || 'equals';
        const value = modalContent.querySelector('#fe-show-if-val')?.value.trim() || '';
        conditionalSubType = modalContent.querySelector('#fe-conditional-subtype')?.value || 'text';
        if (!triggerField) {
          Toast.error('Please pick a trigger field for the conditional logic.');
          return;
        }
        showIf = { field: triggerField, operator, value };
      }

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
        isActive: true,
        ...(showIf && { showIf }),
        ...(conditionalSubType && { conditionalSubType })
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
