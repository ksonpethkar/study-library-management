import api from './api.js';
import { Toast, Modal, Loading, Confirm, escapeHTML } from './ui.js';

const FIELD_ICONS = {
  text: '📝', textarea: '📄', number: '🔢', phone: '📱', email: '📧',
  date: '📅', time: '⏰', select: '📋', multiselect: '☑️', radio: '🔘',
  checkbox: '✅', file: '📎', photo_upload: '📸', signature_pad: '✍️',
  exam_badge: '🎯', blood_group: '🩸', url: '🔗', color: '🎨',
  address_autocomplete: '📍', aadhaar_pan: '🪪', terms_checkbox: '📜',
  star_rating: '⭐'
};

const SECTION_ICONS = {
  personal: '👤', academic: '📚', contact: '📍', kyc: '🪪', plan: '💎', payment: '💳', seat: '💺', other: '📝'
};

export class FormBuilder {
  static currentPreviewStep = 0;
  static previewDeviceMode = 'desktop'; // 'desktop' | 'mobile'

  static async render(container) {
    this.container = container;
    this.sections = [];
    this.fields = [];
    this.currentPreviewStep = 0;

    this.container.innerHTML = `
      <div class="form-builder-studio" style="display: flex; flex-direction: column; gap: 16px;">
        
        <!-- Studio Toolbar Header -->
        <div style="display: flex; justify-content: space-between; align-items: center; padding: 14px 20px; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); flex-wrap: wrap; gap: 12px;">
          <div>
            <h3 style="margin: 0; font-size: 1.15rem; font-weight: 800; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
              🎨 Registration Form Builder & Live Preview Studio
            </h3>
            <p style="margin: 2px 0 0 0; font-size: 0.82rem; color: var(--color-text-secondary);">
              Customize student admission questions, mandatory rules, section steps, and preview changes live in real-time.
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

            <button type="button" class="btn btn-outline-secondary btn-sm" id="fb-add-section-btn" style="font-weight: 600;">
              📂 + Add Section
            </button>
            <button type="button" class="btn btn-primary btn-sm" id="fb-add-field-btn" style="font-weight: 700;">
              ✨ + Add Question Field
            </button>
          </div>
        </div>

        <!-- Split-Screen Studio Canvas -->
        <div class="fb-split-wrapper" style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px; align-items: start;">
          
          <!-- Left Pane: Form Structure & Question Controls -->
          <div class="fb-left-pane" style="display: flex; flex-direction: column; gap: 16px;">
            <div class="card p-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
              <div style="font-size: 0.85rem; font-weight: 700; color: var(--color-text-secondary); text-transform: uppercase; margin-bottom: 12px; display: flex; justify-content: space-between;">
                <span>📋 Form Sections & Question Order</span>
                <span style="color: var(--color-primary);">Auto-Sync Enabled ⚡</span>
              </div>
              <div id="fb-sections-container" style="display: flex; flex-direction: column; gap: 14px;"></div>
            </div>
          </div>

          <!-- Right Pane: Live Interactive Student Preview Canvas -->
          <div class="fb-right-pane" style="position: sticky; top: 80px;">
            <div class="card p-0" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden; box-shadow: var(--shadow-md);">
              <div class="card-header" style="padding: 10px 16px; background: var(--color-surface-hover); border-bottom: 1px solid var(--color-border); display: flex; justify-content: space-between; align-items: center;">
                <span style="font-size: 0.85rem; font-weight: 700; color: var(--color-text-primary); display: flex; align-items: center; gap: 6px;">
                  👁️ Real-Time Student Preview (/register)
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
      const res = await api.get('/api/custom-fields/all');
      this.fields = res?.data || [];

      // Extract sections
      const sectionsMap = new Map();
      const defaultSecs = [
        { name: 'personal', label: 'Step 1: Study Centre & Personal Info', icon: 'personal', order: 1 },
        { name: 'academic', label: 'Step 2: Academic Goals & KYC Proof', icon: 'academic', order: 2 },
        { name: 'plan', label: 'Step 3: Membership Plan & Fee Calculator', icon: 'plan', order: 3 },
        { name: 'payment', label: 'Step 4: Dynamic Payment Selection', icon: 'payment', order: 4 },
        { name: 'seat', label: 'Step 5: Seat Selection & Digital Signature', icon: 'seat', order: 5 }
      ];

      defaultSecs.forEach(s => sectionsMap.set(s.name, s));

      this.fields.forEach(f => {
        if (f.section && !sectionsMap.has(f.section)) {
          sectionsMap.set(f.section, {
            name: f.section,
            label: f.sectionLabel || `Section: ${f.section.toUpperCase()}`,
            icon: f.sectionIcon || 'other',
            order: sectionsMap.size + 1
          });
        }
      });

      this.sections = Array.from(sectionsMap.values()).sort((a, b) => a.order - b.order);

      this.renderSections();
      this.renderPreview();
    } catch (err) {
      console.error('Failed to load form builder data:', err);
      Toast.error('Failed to load form fields schema');
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

      return `
        <div class="fb-sec-card" data-section="${sec.name}" style="background: var(--color-surface-hover); border: 1px solid var(--color-border); border-radius: 10px; overflow: hidden;">
          <div style="padding: 12px 14px; background: var(--color-bg-secondary); border-bottom: 1px solid var(--color-border); display: flex; justify-content: space-between; align-items: center;">
            <div style="display: flex; align-items: center; gap: 8px; font-weight: 700; font-size: 0.92rem; color: var(--color-primary);">
              <span>${SECTION_ICONS[sec.icon] || '📁'}</span>
              <span>${escapeHTML(sec.label)}</span>
              <span class="badge badge-secondary" style="font-size: 0.7rem;">${secFields.length} Questions</span>
            </div>

            <div style="display: flex; align-items: center; gap: 4px;">
              ${secIdx > 0 ? `<button type="button" class="btn btn-sm btn-ghost fb-sec-up" data-sec="${sec.name}" title="Move Section Up">⬆️</button>` : ''}
              ${secIdx < this.sections.length - 1 ? `<button type="button" class="btn btn-sm btn-ghost fb-sec-down" data-sec="${sec.name}" title="Move Section Down">⬇️</button>` : ''}
            </div>
          </div>

          <div style="padding: 10px; display: flex; flex-direction: column; gap: 8px;">
            ${secFields.length ? secFields.map((field, fIdx) => this.renderFieldCard(field, fIdx, secFields.length)).join('') : '<div style="text-align: center; color: var(--color-text-secondary); font-size: 0.8rem; padding: 12px; border: 1px dashed var(--color-border); border-radius: 6px;">No custom questions in this section yet. Tap + Add Question Field above.</div>'}
          </div>
        </div>
      `;
    }).join('');

    // Attach Question Action Listeners
    container.querySelectorAll('.fb-field-edit').forEach(btn => {
      btn.addEventListener('click', () => this.openFieldEditor(btn.dataset.id));
    });

    container.querySelectorAll('.fb-field-toggle').forEach(btn => {
      btn.addEventListener('click', () => this.toggleFieldActive(btn.dataset.id));
    });

    container.querySelectorAll('.fb-field-up').forEach(btn => {
      btn.addEventListener('click', () => this.moveField(btn.dataset.id, -1));
    });

    container.querySelectorAll('.fb-field-down').forEach(btn => {
      btn.addEventListener('click', () => this.moveField(btn.dataset.id, 1));
    });
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

    let html = `
      <div style="margin-bottom: 14px; text-align: center;">
        <h3 style="margin: 0; font-size: 1.15rem; font-weight: 800; color: var(--color-text-primary);">Student Admission Wizard</h3>
        <p style="margin: 2px 0 0 0; font-size: 0.8rem; color: var(--color-text-secondary);">Step ${this.currentPreviewStep + 1} of ${totalSteps}</p>
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
        <h4 style="margin: 0 0 12px 0; font-size: 0.95rem; font-weight: 800; color: #6c5ce7; border-bottom: 2px solid #6c5ce7; padding-bottom: 6px; display: flex; align-items: center; gap: 6px;">
          <span>${SECTION_ICONS[currentSec.icon] || '📁'}</span> ${escapeHTML(currentSec.label)}
        </h4>

        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 12px;">
          ${secFields.length ? secFields.map(f => this.renderPreviewInput(f)).join('') : '<div class="text-muted small p-3 text-center">No questions in this section card.</div>'}
        </div>
      </div>

      <!-- Navigation Buttons -->
      <div style="display: flex; gap: 10px; margin-top: 14px;">
        ${this.currentPreviewStep > 0 ? `<button type="button" id="fb-prev-step" class="btn btn-outline-secondary btn-sm" style="flex: 1; font-weight: 700;">⬅️ Previous Section</button>` : ''}
        ${this.currentPreviewStep < totalSteps - 1 ? `<button type="button" id="fb-next-step" class="btn btn-primary btn-sm" style="flex: 1; font-weight: 700;">Next Section ➡️</button>` : ''}
        ${this.currentPreviewStep === totalSteps - 1 ? `<button type="button" class="btn btn-success btn-sm" style="flex: 1; font-weight: 700;">🚀 Submit Admission</button>` : ''}
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

    // Add Section
    document.getElementById('fb-add-section-btn')?.addEventListener('click', async () => {
      const name = prompt('Enter Section Key (e.g., guardian_info):');
      if (!name) return;
      const label = prompt('Enter Section Title (e.g., Step 6: Parent / Guardian Info):');
      if (!label) return;

      const cleanKey = name.toLowerCase().replace(/[^a-z0-9_]/g, '_');
      this.sections.push({ name: cleanKey, label, icon: 'other', order: this.sections.length + 1 });
      this.renderSections();
      this.renderPreview();
      Toast.success('Section created!');
    });

    // Add Field
    document.getElementById('fb-add-field-btn')?.addEventListener('click', () => {
      this.openFieldEditor(null);
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

  static openFieldEditor(fieldId) {
    const field = this.fields.find(f => f._id === fieldId) || {
      label: '',
      fieldName: '',
      type: 'text',
      section: 'personal',
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
              <option value="select" ${field.type === 'select' ? 'selected' : ''}>📋 Dropdown Select</option>
              <option value="radio" ${field.type === 'radio' ? 'selected' : ''}>🔘 Multiple Choice Radio</option>
              <option value="checkbox" ${field.type === 'checkbox' ? 'selected' : ''}>✅ Single Checkbox</option>
              <option value="date" ${field.type === 'date' ? 'selected' : ''}>📅 Date Picker</option>
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
          <label style="font-weight: 600; font-size: 0.85rem; display: flex; align-items: center; gap: 6px; margin: 0; cursor: pointer;">
            <input type="checkbox" id="fe-required" ${field.required ? 'checked' : ''}> 🔴 Mandatory / Required Field
          </label>
          <label style="font-weight: 600; font-size: 0.85rem; display: flex; align-items: center; gap: 6px; margin: 0; cursor: pointer;">
            <input type="checkbox" id="fe-halfwidth" ${field.colSpan === 6 ? 'checked' : ''}> 📐 50% Half Width Row
          </label>
        </div>

        <div id="fe-options-wrap" style="display: ${['select', 'radio', 'multiselect'].includes(field.type) ? 'block' : 'none'};">
          <label class="form-label text-xs" style="font-weight:700;">Options List (Comma-separated)</label>
          <input type="text" id="fe-options" class="form-control" value="${escapeHTML((field.options || []).join(', '))}" placeholder="Option 1, Option 2, Option 3">
        </div>

        <div style="display: flex; justify-content: flex-end; gap: 10px; margin-top: 10px;">
          <button type="button" class="btn btn-secondary btn-sm" onclick="Modal.closeAll()">Cancel</button>
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
