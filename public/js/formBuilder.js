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

      return `
        <div class="fb-sec-card" data-section="${sec.name}" style="background: var(--color-surface-hover); border: 1px solid var(--color-border); border-radius: 10px; overflow: hidden; margin-bottom: 12px;">
          <div class="fb-sec-header" style="padding: 10px 14px; background: var(--color-bg-secondary); border-bottom: 1px solid var(--color-border); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
            <div class="fb-sec-title-wrap" style="display: flex; align-items: center; gap: 8px; font-weight: 700; font-size: 0.92rem; color: var(--color-primary); cursor: pointer; user-select: none;">
              <div class="fb-sec-drag-handle" style="cursor: grab; font-size: 1.2rem; color: var(--color-text-secondary); padding: 2px 6px; user-select: none; touch-action: none;" title="Drag to reorder section">⠿</div>
              <span>${SECTION_ICONS[sec.icon] || '📁'}</span>
              <span>${escapeHTML(sec.label)}</span>
              <span class="badge badge-secondary" style="font-size: 0.7rem;">${sec.isSystem ? 'System Component' : secFields.length + ' Questions'}</span>
              <span class="fb-sec-toggle-caret" style="font-size: 0.8rem; font-weight: bold; color: var(--color-text-muted); margin-left: 4px;">▲</span>
            </div>

            <div style="display: flex; align-items: center; gap: 4px; flex-wrap: wrap;">
              ${secIdx > 0 ? `<button type="button" class="btn btn-sm btn-ghost fb-sec-up" data-sec="${sec.name}" title="Move Section Up">⬆️</button>` : ''}
              ${secIdx < this.sections.length - 1 ? `<button type="button" class="btn btn-sm btn-ghost fb-sec-down" data-sec="${sec.name}" title="Move Section Down">⬇️</button>` : ''}
              <button type="button" class="btn btn-sm btn-outline-secondary fb-sec-rename" data-sec="${sec.name}" title="Rename Section Title & Icon" style="font-size: 0.75rem; padding: 2px 7px;">✏️ Rename</button>
              <button type="button" class="btn btn-sm btn-outline-secondary fb-sec-copy" data-sec="${sec.name}" title="Copy Section & All Questions" style="font-size: 0.75rem; padding: 2px 7px;">📋 Copy Sec</button>
              <button type="button" class="btn btn-sm btn-outline-success fb-sec-paste-field" data-sec="${sec.name}" title="Paste Copied Question into this Section" style="font-size: 0.75rem; padding: 2px 7px;">📋 Paste Q</button>
              <button type="button" class="btn btn-sm btn-outline-primary fb-sec-add-field" data-sec="${sec.name}" title="Add Question to this Section" style="font-size: 0.75rem; padding: 2px 8px;">➕ Add Question</button>
              ${!isCoreSec ? `<button type="button" class="btn btn-sm btn-ghost text-danger fb-sec-delete" data-sec="${sec.name}" title="Delete Section" style="font-size: 0.75rem; padding: 2px 6px;">🗑️ Delete</button>` : ''}
            </div>
          </div>

          <div class="fb-sec-body" style="padding: 10px; display: flex; flex-direction: column; gap: 8px;">
            ${sec.isSystem && secFields.length === 0 ? this.renderSystemComponentCard(sec) : ''}

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
          this.sections.sort((a, b) => a.order - b.order);
          if (!this.template) this.template = {};
          this.template.sections = this.sections;
          try {
            await api.put('/api/custom-fields/templates/active', { sections: this.sections });
            if (window.Toast) window.Toast.success('Section order updated');
          } catch (err) {}
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
                const fieldObj = this.fields.find(item => String(item._id) === String(rowId));
                if (fieldObj) {
                  fieldObj.order = idx + 1;
                  fieldObj.section = secName;
                  ordersToSave.push({ id: fieldObj._id, order: fieldObj.order, section: secName });
                }
              });
            });

            try {
              await api.put('/api/custom-fields/reorder', { orders: ordersToSave });
              if (window.Toast) window.Toast.success('Question order updated');
            } catch (err) {
              console.error('Failed to save question reorder:', err);
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

    container.querySelectorAll('.fb-field-copy').forEach(btn => {
      btn.addEventListener('click', () => this.copyField(btn.dataset.id));
    });

    container.querySelectorAll('.fb-field-duplicate').forEach(btn => {
      btn.addEventListener('click', () => this.duplicateField(btn.dataset.id));
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

        <div style="display: flex; align-items: center; gap: 4px; flex-shrink: 0; flex-wrap: wrap;">
          ${index > 0 ? `<button type="button" class="btn btn-sm btn-ghost fb-field-up" data-id="${field._id}" title="Move Question Up">⬆️</button>` : ''}
          ${index < total - 1 ? `<button type="button" class="btn btn-sm btn-ghost fb-field-down" data-id="${field._id}" title="Move Question Down">⬇️</button>` : ''}
          
          <button type="button" class="btn btn-sm btn-outline-secondary fb-field-copy" data-id="${field._id}" title="Copy Question to Clipboard" style="font-size: 0.75rem; padding: 2px 6px;">
            📋 Copy
          </button>
          <button type="button" class="btn btn-sm btn-outline-secondary fb-field-duplicate" data-id="${field._id}" title="Instant Duplicate Question" style="font-size: 0.75rem; padding: 2px 6px;">
            📄 Duplicate
          </button>
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
            <select class="form-select form-control-sm" id="prev-branch-select">${branchOptions || '<option>Main Campus Central — 🟢 48/50 Available Seats</option>'}</select>
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
        { seatNumber: '01', zone: 'Zone A' }, { seatNumber: '02', zone: 'Zone A' },
        { seatNumber: '03', zone: 'Zone A' }, { seatNumber: '04', zone: 'Zone A' },
        { seatNumber: '05', zone: 'Zone A' }, { seatNumber: '06', zone: 'Zone A' }
      ];

      return `
        <div style="display: flex; flex-direction: column; gap: 14px;">
          <div>
            <label class="form-label text-xs" style="font-weight:700;">Choose Your Study Desk Seat *</label>
            <div style="display: flex; gap: 8px; overflow-x: auto; padding-bottom: 6px;">
              ${availSeats.slice(0, 6).map((s, idx) => `
                <div style="min-width: 60px; padding: 8px 6px; border: 1.5px solid ${idx === 0 ? '#6c5ce7' : 'var(--color-border)'}; border-radius: 8px; text-align: center; cursor: pointer; background: ${idx === 0 ? 'rgba(108, 92, 231, 0.12)' : 'var(--color-surface)'};">
                  <div style="font-weight: 800; font-size: 0.9rem; color: #6c5ce7;">${escapeHTML(s.seatNumber)}</div>
                  <div style="font-size: 0.65rem; color: var(--color-text-secondary);">${escapeHTML(s.zone || 'Zone A')}</div>
                </div>
              `).join('')}
            </div>
          </div>

          ${secFields.map(f => this.renderPreviewInput(f)).join('')}

          <div>
            <label class="form-label text-xs" style="font-weight:700;">Digital Signature Pad *</label>
            <div style="width: 100%; height: 85px; border: 1.5px dashed var(--color-border); border-radius: 8px; background: #ffffff; display: flex; flex-direction: column; align-items: center; justify-content: center; color: var(--color-text-secondary); font-size: 0.82rem;">
              <div style="color: #6c5ce7; font-weight: 600; display: flex; align-items: center; gap: 6px;">
                <span>✍️</span> <span>Draw student signature canvas</span>
              </div>
            </div>
          </div>

          <!-- Quiet Study Code Agreement & Terms Checkbox -->
          <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 12px;">
            <label style="display: flex; align-items: flex-start; gap: 10px; cursor: pointer; font-size: 0.83rem; color: var(--color-text-primary); margin: 0; line-height: 1.4;">
              <input type="checkbox" checked style="margin-top: 3px; accent-color: var(--color-primary); width: 16px; height: 16px;">
              <span>I hereby agree to adhere to the <strong>Quiet Study Code Agreement</strong>, discipline rules, and timings of the study hall. <span style="color: var(--color-danger);">*</span></span>
            </label>
          </div>
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
    const field = this.fields.find(f => String(f._id) === String(fieldId));
    if (!field) return;

    const secName = field.section || 'personal';
    const secFields = this.fields
      .filter(f => (f.section || 'personal') === secName)
      .sort((a, b) => (a.order || 0) - (b.order || 0));

    const curIdx = secFields.findIndex(f => String(f._id) === String(fieldId));
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
      await api.put('/api/custom-fields/reorder', {
        orders: this.fields.map(f => ({ id: f._id, order: f.order, section: f.section }))
      });
      Toast.success('Question order updated');
    } catch (e) {
      Toast.error('Failed to save field order');
    }
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
