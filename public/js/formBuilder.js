import api from './api.js';
import { Toast, Modal, Loading, Confirm, escapeHTML } from './ui.js';

const FIELD_ICONS = {
  text: '📝', textarea: '📄', number: '🔢', phone: '📱', email: '📧',
  date: '📅', time: '⏰', select: '📋', multiselect: '☑️', radio: '🔘',
  checkbox: '✅', file: '📎', photo_upload: '📸', signature_pad: '✍️',
  exam_badge: '🎯', blood_group: '🩸', url: '🔗', color: '🎨',
  address_autocomplete: '📍', aadhaar_pan: '🪪', terms_checkbox: '📜'
};

const SECTION_ICONS = {
  personal: '👤', academic: '📚', contact: '📍', kyc: '🪪', other: '📝'
};

export class FormBuilder {
  static async render(container) {
    this.container = container;
    this.sections = [];
    this.fields = [];
    this.templates = [];
    
    // Create base layout
    this.container.innerHTML = `
      <div class="form-builder-layout" style="display: flex; gap: 24px; height: 100%; min-height: 800px; padding: 20px;">
        
        <!-- Left: Builder Tools -->
        <div class="builder-tools" style="flex: 1; display: flex; flex-direction: column; gap: 20px; max-width: 65%;">
          
          <!-- Top: Templates -->
          <div class="card" style="padding: 16px;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
              <h3 style="margin: 0;">Registration Form Templates</h3>
            </div>
            <div id="fb-templates" style="display: flex; gap: 16px; overflow-x: auto; padding-bottom: 8px;">
              <!-- Templates injected here -->
            </div>
          </div>
          
          <!-- Main: Sections & Fields -->
          <div class="card" style="padding: 16px; flex: 1; overflow-y: auto;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
              <h3 style="margin: 0;">Form Sections & Fields</h3>
              <div>
                <button class="btn btn-secondary" id="fb-add-section-btn">+ Add Section</button>
                <button class="btn btn-primary" id="fb-add-field-btn">+ Add Field</button>
              </div>
            </div>
            <div id="fb-sections-container" style="display: flex; flex-direction: column; gap: 16px;">
              <!-- Sections injected here -->
            </div>
          </div>
          
        </div>
        
        <!-- Right: Live Preview -->
        <div class="builder-preview" style="width: 375px; flex-shrink: 0; background: #fff; border: 12px solid #333; border-radius: 40px; overflow: hidden; position: relative; box-shadow: 0 10px 25px rgba(0,0,0,0.1); height: 812px;">
          <div style="position: absolute; top: 0; left: 50%; transform: translateX(-50%); width: 120px; height: 25px; background: #333; border-bottom-left-radius: 16px; border-bottom-right-radius: 16px; z-index: 10;"></div>
          <div id="fb-live-preview" style="height: 100%; overflow-y: auto; background: var(--color-surface, #f8f9fa); padding: 40px 16px 20px 16px;">
            <!-- Live Preview content -->
          </div>
        </div>
      </div>
    `;

    // Load data
    await this.loadData();
    this.bindEvents();
  }

  static async loadData() {
    try {
      Loading.show();
      // Fetch sections, fields, templates
      // Mocking endpoints or using real ones if they exist
      const [sectionsRes, fieldsRes, templatesRes] = await Promise.all([
        api.get('/api/custom-fields/sections').catch(() => ({ data: [] })),
        api.get('/api/custom-fields/all').catch(() => ({ data: [] })),
        api.get('/api/custom-fields/templates').catch(() => ({ data: [] }))
      ]);

      this.sections = sectionsRes.data?.length ? sectionsRes.data : [
        { id: 'sec_1', name: 'personal', label: 'Personal Information', icon: 'personal', order: 1 },
        { id: 'sec_2', name: 'contact', label: 'Contact Details', icon: 'contact', order: 2 }
      ];
      this.fields = fieldsRes.data?.length ? fieldsRes.data : [];
      this.templates = templatesRes.data?.length ? templatesRes.data : [
        { id: 'tpl_1', name: 'Modern Light', color: '#4361ee' },
        { id: 'tpl_2', name: 'Dark Elegant', color: '#2b2d42' }
      ];

      this.renderTemplates();
      this.renderSections();
      this.renderPreview();
    } catch (e) {
      console.error('Error loading form builder data:', e);
      Toast.error('Failed to load form configuration');
    } finally {
      Loading.hide();
    }
  }

  static renderTemplates() {
    const container = document.getElementById('fb-templates');
    if (!container) return;

    container.innerHTML = this.templates.map(tpl => `
      <div class="template-card" style="min-width: 150px; padding: 12px; border: 2px solid #eee; border-radius: 8px; cursor: pointer; text-align: center;">
        <div style="width: 40px; height: 40px; border-radius: 50%; background: ${escapeHTML(tpl.color)}; margin: 0 auto 8px auto;"></div>
        <div style="font-weight: 600; font-size: 14px;">${escapeHTML(tpl.name)}</div>
      </div>
    `).join('');
  }

  static renderSections() {
    const container = document.getElementById('fb-sections-container');
    if (!container) return;

    this.sections.sort((a, b) => a.order - b.order);

    container.innerHTML = this.sections.map(section => {
      const sectionFields = this.fields.filter(f => f.section === section.name).sort((a, b) => a.order - b.order);
      
      return `
        <div class="section-panel" data-section-id="${escapeHTML(section.id)}" style="border: 1px solid var(--color-border, #e0e0e0); border-radius: 8px; background: var(--color-surface, #fff); overflow: hidden;">
          <div class="section-header" style="padding: 12px 16px; background: rgba(0,0,0,0.02); display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid var(--color-border, #e0e0e0); cursor: pointer;">
            <div style="display: flex; align-items: center; gap: 8px;">
              <span style="cursor: grab;" title="Drag to reorder">☰</span>
              <span>${SECTION_ICONS[section.icon] || '📁'}</span>
              <h4 style="margin: 0; font-size: 16px;">${escapeHTML(section.label)}</h4>
            </div>
            <button class="btn-icon edit-section-btn" style="background: none; border: none; cursor: pointer;">✏️</button>
          </div>
          <div class="section-body" style="padding: 16px; background: #fafafa; min-height: 50px;">
            <div class="fields-container" data-section="${escapeHTML(section.name)}" style="display: flex; flex-direction: column; gap: 8px;">
              ${sectionFields.length ? sectionFields.map(field => this.renderFieldCard(field)).join('') : '<div style="color: #888; text-align: center; padding: 10px; border: 1px dashed #ccc; border-radius: 4px;">Drag fields here or Add Field</div>'}
            </div>
          </div>
        </div>
      `;
    }).join('');

    // Attach edit buttons
    container.querySelectorAll('.edit-section-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const sectionId = e.target.closest('.section-panel').dataset.sectionId;
        this.openSectionEditor(sectionId);
      });
    });

    // Attach field edit buttons
    container.querySelectorAll('.edit-field-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const fieldId = e.target.closest('.field-card').dataset.fieldId;
        this.openFieldEditor(fieldId);
      });
    });
  }

  static renderFieldCard(field) {
    const icon = FIELD_ICONS[field.type] || '📝';
    return `
      <div class="field-card" data-field-id="${escapeHTML(field._id || field.id)}" style="background: #fff; border: 1px solid #ddd; border-radius: 6px; padding: 12px; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 1px 3px rgba(0,0,0,0.05); cursor: grab;">
        <div style="display: flex; align-items: center; gap: 12px;">
          <span style="color: #888;">☰</span>
          <span style="font-size: 18px;">${icon}</span>
          <div>
            <div style="font-weight: 500; font-size: 14px;">
              ${escapeHTML(field.label)}
              ${field.required ? '<span style="color: #e53935;">*</span>' : ''}
            </div>
            <div style="font-size: 12px; color: #666; margin-top: 2px;">
              <span class="badge" style="background: #eef2f6; color: #4361ee; padding: 2px 6px; border-radius: 4px; font-size: 10px;">${escapeHTML(field.type)}</span>
              ${field.name ? `<code style="background: #f5f5f5; padding: 2px 4px; border-radius: 3px;">${escapeHTML(field.name)}</code>` : ''}
            </div>
          </div>
        </div>
        <button class="btn-icon edit-field-btn" style="background: none; border: none; cursor: pointer; padding: 4px;">✏️</button>
      </div>
    `;
  }

  static renderPreview() {
    const container = document.getElementById('fb-live-preview');
    if (!container) return;

    // Build the wizard UI
    let html = `
      <div style="margin-bottom: 24px; text-align: center;">
        <h3 style="margin: 0; color: #333;">Student Registration</h3>
        <p style="margin: 4px 0 0 0; color: #666; font-size: 14px;">Library Management System</p>
      </div>
    `;

    this.sections.sort((a, b) => a.order - b.order);
    
    // Render progress bar (simplified)
    html += `
      <div style="display: flex; justify-content: space-between; margin-bottom: 24px; position: relative;">
        <div style="position: absolute; top: 12px; left: 0; right: 0; height: 2px; background: #e0e0e0; z-index: 1;"></div>
        ${this.sections.map((sec, i) => `
          <div style="position: relative; z-index: 2; display: flex; flex-direction: column; align-items: center; gap: 4px;">
            <div style="width: 24px; height: 24px; border-radius: 50%; background: ${i === 0 ? '#4361ee' : '#e0e0e0'}; color: ${i === 0 ? '#fff' : '#888'}; display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: bold;">${i + 1}</div>
          </div>
        `).join('')}
      </div>
    `;

    // Render first section for preview
    const firstSec = this.sections[0];
    if (firstSec) {
      const secFields = this.fields.filter(f => f.section === firstSec.name).sort((a, b) => a.order - b.order);
      html += `
        <div style="background: #fff; border-radius: 12px; padding: 16px; box-shadow: 0 2px 8px rgba(0,0,0,0.05); margin-bottom: 20px;">
          <h4 style="margin: 0 0 16px 0; display: flex; align-items: center; gap: 8px;">
            <span>${SECTION_ICONS[firstSec.icon] || ''}</span> ${escapeHTML(firstSec.label)}
          </h4>
          <div style="display: flex; flex-direction: column; gap: 16px;">
            ${secFields.map(f => this.renderPreviewField(f)).join('')}
          </div>
        </div>
        <button style="width: 100%; padding: 12px; background: #4361ee; color: white; border: none; border-radius: 8px; font-weight: 600; cursor: pointer;">Next Step</button>
      `;
    } else {
      html += `<div style="text-align: center; color: #888; padding: 40px 0;">No sections available</div>`;
    }

    container.innerHTML = html;
  }

  static renderPreviewField(field) {
    let inputHtml = '';
    const placeholder = field.placeholder ? `placeholder="${escapeHTML(field.placeholder)}"` : '';
    const style = 'width: 100%; padding: 10px 12px; border: 1px solid #ddd; border-radius: 6px; box-sizing: border-box; font-size: 14px;';
    
    switch (field.type) {
      case 'textarea':
        inputHtml = `<textarea ${placeholder} style="${style} min-height: 80px; resize: vertical;"></textarea>`;
        break;
      case 'select':
        inputHtml = `
          <select style="${style}">
            <option value="">Select option</option>
            ${(field.options || []).map(o => `<option>${escapeHTML(o.label || o)}</option>`).join('')}
          </select>
        `;
        break;
      case 'radio':
        inputHtml = `<div style="display: flex; gap: 12px; flex-wrap: wrap;">
          ${(field.options || ['Option 1', 'Option 2']).map(o => `
            <label style="display: flex; align-items: center; gap: 4px; font-size: 14px;">
              <input type="radio" name="${field.name}"> ${escapeHTML(o.label || o)}
            </label>
          `).join('')}
        </div>`;
        break;
      case 'checkbox':
      case 'terms_checkbox':
        inputHtml = `
          <label style="display: flex; align-items: flex-start; gap: 8px; font-size: 14px;">
            <input type="checkbox" style="margin-top: 3px;">
            <span>${escapeHTML(field.label)}</span>
          </label>
        `;
        break;
      default:
        inputHtml = `<input type="text" ${placeholder} style="${style}">`;
    }

    if (field.type === 'checkbox' || field.type === 'terms_checkbox') {
      return `<div>${inputHtml}</div>`;
    }

    return `
      <div style="display: flex; flex-direction: column; gap: 4px;">
        <label style="font-size: 13px; font-weight: 500; color: #444;">
          ${escapeHTML(field.label)} ${field.required ? '<span style="color: red;">*</span>' : ''}
        </label>
        ${inputHtml}
        ${field.helpText ? `<div style="font-size: 11px; color: #888;">${escapeHTML(field.helpText)}</div>` : ''}
      </div>
    `;
  }

  static bindEvents() {
    const addSectionBtn = document.getElementById('fb-add-section-btn');
    if (addSectionBtn) {
      addSectionBtn.addEventListener('click', () => this.openSectionEditor());
    }

    const addFieldBtn = document.getElementById('fb-add-field-btn');
    if (addFieldBtn) {
      addFieldBtn.addEventListener('click', () => this.openFieldEditor());
    }
  }

  static openSectionEditor(sectionId = null) {
    const section = sectionId ? this.sections.find(s => s.id === sectionId) : {
      name: '', label: '', icon: 'other', order: this.sections.length + 1
    };

    const isNew = !sectionId;

    const html = `
      <div class="form-group">
        <label>Section Label</label>
        <input type="text" id="sec-label" class="form-input" value="${escapeHTML(section.label)}" required>
      </div>
      <div class="form-group">
        <label>Section Key Name (internal)</label>
        <input type="text" id="sec-name" class="form-input" value="${escapeHTML(section.name)}" ${!isNew ? 'readonly' : ''} required>
      </div>
      <div class="form-group">
        <label>Icon</label>
        <select id="sec-icon" class="form-input">
          ${Object.keys(SECTION_ICONS).map(k => `<option value="${k}" ${section.icon === k ? 'selected' : ''}>${SECTION_ICONS[k]} ${k}</option>`).join('')}
        </select>
      </div>
    `;

    Modal.show({
      title: isNew ? 'Add Section' : 'Edit Section',
      content: html,
      buttons: [
        { text: 'Cancel', type: 'secondary', onClick: () => Modal.hide() },
        { text: 'Save', type: 'primary', onClick: () => {
          const newLabel = document.getElementById('sec-label').value.trim();
          const newName = document.getElementById('sec-name').value.trim();
          const newIcon = document.getElementById('sec-icon').value;
          
          if (!newLabel || !newName) return Toast.warning('Label and Name required');

          if (isNew) {
            this.sections.push({ id: 'sec_' + Date.now(), name: newName, label: newLabel, icon: newIcon, order: this.sections.length + 1 });
          } else {
            section.label = newLabel;
            section.icon = newIcon;
          }

          this.renderSections();
          this.renderPreview();
          Modal.hide();
          Toast.success('Section saved');
        }}
      ]
    });
  }

  static openFieldEditor(fieldId = null) {
    const field = fieldId ? this.fields.find(f => (f._id || f.id) === fieldId) : {
      label: '', name: '', type: 'text', section: this.sections[0]?.name || '', required: false, placeholder: '', helpText: '', options: []
    };

    const isNew = !fieldId;

    const html = `
      <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px;">
        <div class="form-group">
          <label>Field Label</label>
          <input type="text" id="fld-label" class="form-input" value="${escapeHTML(field.label)}" required>
        </div>
        <div class="form-group">
          <label>Internal Name</label>
          <input type="text" id="fld-name" class="form-input" value="${escapeHTML(field.name)}" ${!isNew ? 'readonly' : ''} required>
        </div>
        <div class="form-group">
          <label>Field Type</label>
          <select id="fld-type" class="form-input">
            ${Object.keys(FIELD_ICONS).map(k => `<option value="${k}" ${field.type === k ? 'selected' : ''}>${FIELD_ICONS[k]} ${k}</option>`).join('')}
          </select>
        </div>
        <div class="form-group">
          <label>Section</label>
          <select id="fld-section" class="form-input">
            ${this.sections.map(s => `<option value="${s.name}" ${field.section === s.name ? 'selected' : ''}>${escapeHTML(s.label)}</option>`).join('')}
          </select>
        </div>
      </div>
      <div class="form-group">
        <label>Placeholder Text</label>
        <input type="text" id="fld-placeholder" class="form-input" value="${escapeHTML(field.placeholder || '')}">
      </div>
      <div class="form-group">
        <label>Help Text</label>
        <input type="text" id="fld-help" class="form-input" value="${escapeHTML(field.helpText || '')}">
      </div>
      <div class="form-group" style="display: flex; align-items: center; gap: 8px;">
        <input type="checkbox" id="fld-required" ${field.required ? 'checked' : ''}>
        <label for="fld-required" style="margin: 0;">Required Field</label>
      </div>
      <div id="fld-options-container" class="form-group" style="display: ${['select','radio','multiselect'].includes(field.type) ? 'block' : 'none'};">
        <label>Options (comma separated)</label>
        <input type="text" id="fld-options" class="form-input" value="${(field.options || []).map(o => o.label || o).join(', ')}">
      </div>
    `;

    Modal.show({
      title: isNew ? 'Add Field' : 'Edit Field',
      content: html,
      width: '600px',
      buttons: [
        { text: 'Cancel', type: 'secondary', onClick: () => Modal.hide() },
        ...(!isNew ? [{ text: 'Delete', type: 'danger', onClick: () => this.deleteField(fieldId) }] : []),
        { text: 'Save', type: 'primary', onClick: () => {
          const newLabel = document.getElementById('fld-label').value.trim();
          const newName = document.getElementById('fld-name').value.trim();
          const newType = document.getElementById('fld-type').value;
          const newSection = document.getElementById('fld-section').value;
          const newPlaceholder = document.getElementById('fld-placeholder').value.trim();
          const newHelpText = document.getElementById('fld-help').value.trim();
          const newRequired = document.getElementById('fld-required').checked;
          
          let newOptions = [];
          if (['select','radio','multiselect'].includes(newType)) {
            const optsStr = document.getElementById('fld-options').value.trim();
            if (optsStr) {
              newOptions = optsStr.split(',').map(s => s.trim()).filter(Boolean);
            }
          }

          if (!newLabel || !newName) return Toast.warning('Label and Name required');

          if (isNew) {
            this.fields.push({
              id: 'fld_' + Date.now(),
              name: newName,
              label: newLabel,
              type: newType,
              section: newSection,
              placeholder: newPlaceholder,
              helpText: newHelpText,
              required: newRequired,
              options: newOptions,
              order: this.fields.length + 1
            });
          } else {
            Object.assign(field, {
              label: newLabel,
              type: newType,
              section: newSection,
              placeholder: newPlaceholder,
              helpText: newHelpText,
              required: newRequired,
              options: newOptions
            });
          }

          this.renderSections();
          this.renderPreview();
          Modal.hide();
          Toast.success('Field saved');
        }}
      ]
    });

    // Auto-generate name from label for new fields
    if (isNew) {
      document.getElementById('fld-label').addEventListener('input', (e) => {
        const val = e.target.value;
        document.getElementById('fld-name').value = val.toLowerCase().replace(/[^a-z0-9]/g, '_').replace(/_+/g, '_').replace(/^_|_$/g, '');
      });
    }

    // Toggle options field visibility
    document.getElementById('fld-type').addEventListener('change', (e) => {
      const type = e.target.value;
      const optsContainer = document.getElementById('fld-options-container');
      if (['select','radio','multiselect'].includes(type)) {
        optsContainer.style.display = 'block';
      } else {
        optsContainer.style.display = 'none';
      }
    });
  }

  static deleteField(fieldId) {
    Confirm.show({
      title: 'Delete Field',
      message: 'Are you sure you want to delete this field? This action cannot be undone.',
      onConfirm: () => {
        this.fields = this.fields.filter(f => (f._id || f.id) !== fieldId);
        this.renderSections();
        this.renderPreview();
        Modal.hide();
        Toast.success('Field deleted');
      }
    });
  }
}
