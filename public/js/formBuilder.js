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
  personal: '👤', academic: '📚', contact: '📍', kyc: '🪪', other: '📝'
};

export class FormBuilder {
  static currentPreviewStep = 0;
  static draggedElement = null;

  static async render(container) {
    this.container = container;
    this.sections = [];
    this.fields = [];
    this.templates = [];
    this.currentPreviewStep = 0;

    this.container.innerHTML = `
      <div class="form-builder-layout" style="display: flex; gap: 24px; height: 100%; min-height: 800px; padding: 20px;">
        <div class="builder-tools" style="flex: 1; display: flex; flex-direction: column; gap: 20px; max-width: 65%;">
          <div class="card" style="padding: 16px;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
              <h3 style="margin: 0;">Registration Form Templates</h3>
            </div>
            <div id="fb-templates" style="display: flex; gap: 16px; overflow-x: auto; padding-bottom: 8px;"></div>
          </div>
          <div class="card" style="padding: 16px; flex: 1; overflow-y: auto;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
              <h3 style="margin: 0;">Form Sections & Fields</h3>
              <div>
                <button class="btn btn-secondary" id="fb-add-section-btn">+ Add Section</button>
                <button class="btn btn-primary" id="fb-add-field-btn">+ Add Field</button>
              </div>
            </div>
            <div id="fb-sections-container" style="display: flex; flex-direction: column; gap: 16px;"></div>
          </div>
        </div>
        <div class="builder-preview" style="width: 375px; flex-shrink: 0; background: #fff; border: 12px solid #333; border-radius: 40px; overflow: hidden; position: relative; box-shadow: 0 10px 25px rgba(0,0,0,0.1); height: 812px;">
          <div style="position: absolute; top: 0; left: 50%; transform: translateX(-50%); width: 120px; height: 25px; background: #333; border-bottom-left-radius: 16px; border-bottom-right-radius: 16px; z-index: 10;"></div>
          <div id="fb-live-preview" style="height: 100%; overflow-y: auto; background: var(--color-surface, #f8f9fa); padding: 40px 16px 20px 16px;"></div>
        </div>
      </div>
    `;

    await this.loadData();
    this.bindEvents();
    
    // Bind preview events delegation
    document.addEventListener('input', (e) => {
      if(e.target.closest('#fb-live-preview')) {
        this.evaluateConditionals();
      }
    });
    document.addEventListener('change', (e) => {
      if(e.target.closest('#fb-live-preview')) {
        this.evaluateConditionals();
      }
    });
  }

  static async loadData() {
    try {
      if (typeof Loading !== 'undefined' && Loading.show) Loading.show();
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
      if (typeof Loading !== 'undefined' && Loading.hide) Loading.hide();
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
        <div class="section-panel draggable-item" draggable="true" data-type="section" data-id="${escapeHTML(section.id || section.name)}" data-section-id="${escapeHTML(section.id || section.name)}" style="border: 1px solid var(--color-border, #e0e0e0); border-radius: 8px; background: var(--color-surface, #fff); overflow: hidden;">
          <div class="section-header" style="padding: 12px 16px; background: rgba(0,0,0,0.02); display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid var(--color-border, #e0e0e0); cursor: grab;">
            <div style="display: flex; align-items: center; gap: 8px;">
              <span class="drag-handle" title="Drag to reorder">☰</span>
              <span>${SECTION_ICONS[section.icon] || '📁'}</span>
              <h4 style="margin: 0; font-size: 16px;">${escapeHTML(section.label)}</h4>
            </div>
            <button class="btn-icon edit-section-btn" style="background: none; border: none; cursor: pointer;">✏️</button>
          </div>
          <div class="section-body dropzone" data-dropzone-type="field" data-section="${escapeHTML(section.name)}" style="padding: 16px; background: #fafafa; min-height: 50px;">
            <div class="fields-container" style="display: flex; flex-direction: column; gap: 8px;">
              ${sectionFields.length ? sectionFields.map(field => this.renderFieldCard(field)).join('') : '<div class="empty-dropzone" style="color: #888; text-align: center; padding: 10px; border: 1px dashed #ccc; border-radius: 4px;">Drag fields here</div>'}
            </div>
          </div>
        </div>
      `;
    }).join('');

    this.bindDragAndDrop(container);

    container.querySelectorAll('.edit-section-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const sectionId = e.target.closest('.section-panel').dataset.sectionId;
        this.openSectionEditor(sectionId);
      });
    });

    container.querySelectorAll('.edit-field-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const fieldId = e.target.closest('.field-card').dataset.fieldId;
        this.openFieldEditor(fieldId);
      });
    });
    
    container.querySelectorAll('.toggle-field-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const fieldId = e.target.closest('.field-card').dataset.fieldId;
        this.toggleFieldActive(fieldId);
      });
    });
  }

  static bindDragAndDrop(container) {
    const draggables = container.querySelectorAll('.draggable-item');
    const dropzones = container.querySelectorAll('.dropzone, #fb-sections-container');
    
    draggables.forEach(draggable => {
      draggable.addEventListener('dragstart', (e) => {
        this.draggedElement = draggable;
        e.dataTransfer.effectAllowed = 'move';
        setTimeout(() => draggable.style.opacity = '0.5', 0);
        e.stopPropagation();
      });

      draggable.addEventListener('dragend', (e) => {
        draggable.style.opacity = '1';
        this.draggedElement = null;
        e.stopPropagation();
      });
    });

    dropzones.forEach(zone => {
      zone.addEventListener('dragover', (e) => {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';
        e.stopPropagation();
      });

      zone.addEventListener('drop', async (e) => {
        e.preventDefault();
        e.stopPropagation();
        if (!this.draggedElement) return;

        const type = this.draggedElement.dataset.type;
        const targetZone = e.target.closest('.dropzone, #fb-sections-container');
        
        if (!targetZone) return;

        if (type === 'field' && targetZone.dataset.dropzoneType === 'field') {
          const container = targetZone.querySelector('.fields-container');
          this.insertAfterClosest(container, e.clientY, this.draggedElement, '.field-card');
          const newSectionName = targetZone.dataset.section;
          
          // Update order locally
          const allCards = Array.from(container.querySelectorAll('.field-card'));
          const updates = [];
          
          allCards.forEach((card, index) => {
            const fId = card.dataset.fieldId;
            const field = this.fields.find(f => (f._id || f.id) === fId);
            if (field) {
              if (fId === this.draggedElement.dataset.fieldId) {
                field.section = newSectionName;
              }
              field.order = index + 1;
              updates.push({ id: fId, order: field.order, section: field.section });
            }
          });
          
          await this.saveBulkOrder(updates, 'fields');
          this.renderPreview();
        } 
        else if (type === 'section' && targetZone.id === 'fb-sections-container') {
          this.insertAfterClosest(targetZone, e.clientY, this.draggedElement, '.section-panel');
          
          // Update order locally
          const allSections = Array.from(targetZone.querySelectorAll('.section-panel'));
          const updates = [];
          allSections.forEach((panel, index) => {
            const sId = panel.dataset.sectionId;
            const section = this.sections.find(s => (s.id || s.name) === sId);
            if (section) {
              section.order = index + 1;
              updates.push({ id: sId, order: section.order });
            }
          });
          
          await this.saveBulkOrder(updates, 'sections');
          this.renderPreview();
        }
      });
    });
  }

  static insertAfterClosest(container, y, element, selector) {
    const draggableElements = [...container.querySelectorAll(`${selector}:not(.dragging)`)];
    const afterElement = draggableElements.reduce((closest, child) => {
      const box = child.getBoundingClientRect();
      const offset = y - box.top - box.height / 2;
      if (offset < 0 && offset > closest.offset) {
        return { offset: offset, element: child };
      } else {
        return closest;
      }
    }, { offset: Number.NEGATIVE_INFINITY }).element;
    
    if (afterElement == null) {
      container.appendChild(element);
    } else {
      container.insertBefore(element, afterElement);
    }
  }

  static async saveBulkOrder(items, type) {
    try {
      await api.put(`/api/custom-fields/reorder/bulk`, { type, items });
    } catch (e) {
      console.error('Reorder error', e);
      Toast.error('Failed to save order');
    }
  }

  static renderFieldCard(field) {
    const icon = FIELD_ICONS[field.type] || '📝';
    const fId = field._id || field.id;
    return `
      <div class="field-card draggable-item" draggable="true" data-type="field" data-field-id="${escapeHTML(fId)}" style="background: #fff; border: 1px solid #ddd; border-radius: 6px; padding: 12px; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 1px 3px rgba(0,0,0,0.05); cursor: grab; opacity: ${field.isActive === false ? '0.6' : '1'};">
        <div style="display: flex; align-items: center; gap: 12px;">
          <span class="drag-handle" style="color: #888;">☰</span>
          <span style="font-size: 18px;">${icon}</span>
          <div>
            <div style="font-weight: 500; font-size: 14px; text-decoration: ${field.isActive === false ? 'line-through' : 'none'};">
              ${escapeHTML(field.label)}
              ${field.required ? '<span style="color: #e53935;">*</span>' : ''}
            </div>
            <div style="font-size: 12px; color: #666; margin-top: 2px;">
              <span class="badge" style="background: #eef2f6; color: #4361ee; padding: 2px 6px; border-radius: 4px; font-size: 10px;">${escapeHTML(field.type)}</span>
              ${field.name ? `<code style="background: #f5f5f5; padding: 2px 4px; border-radius: 3px;">${escapeHTML(field.name)}</code>` : ''}
              ${field.width === 'half' ? '<span style="font-size: 10px; margin-left: 4px; color: #888;">[50%]</span>' : ''}
            </div>
          </div>
        </div>
        <div style="display: flex; gap: 8px;">
          <button class="btn-icon toggle-field-btn" style="background: none; border: none; cursor: pointer; padding: 4px;" title="Toggle Active">
            ${field.isActive === false ? '👁️‍🗨️' : '👁️'}
          </button>
          <button class="btn-icon edit-field-btn" style="background: none; border: none; cursor: pointer; padding: 4px;" title="Edit">✏️</button>
        </div>
      </div>
    `;
  }

  static renderPreview() {
    const container = document.getElementById('fb-live-preview');
    if (!container) return;

    let html = `
      <div style="margin-bottom: 24px; text-align: center;">
        <h3 style="margin: 0; color: #333;">Student Registration</h3>
        <p style="margin: 4px 0 0 0; color: #666; font-size: 14px;">Library Management System</p>
      </div>
    `;

    this.sections.sort((a, b) => a.order - b.order);
    const totalSteps = this.sections.length;
    
    html += `
      <div style="display: flex; justify-content: space-between; margin-bottom: 24px; position: relative;">
        <div style="position: absolute; top: 12px; left: 0; right: 0; height: 2px; background: #e0e0e0; z-index: 1;"></div>
        ${this.sections.map((sec, i) => `
          <div style="position: relative; z-index: 2; display: flex; flex-direction: column; align-items: center; gap: 4px;">
            <div style="width: 24px; height: 24px; border-radius: 50%; background: ${i <= this.currentPreviewStep ? '#4361ee' : '#e0e0e0'}; color: ${i <= this.currentPreviewStep ? '#fff' : '#888'}; display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: bold;">${i + 1}</div>
          </div>
        `).join('')}
      </div>
    `;

    const currentSec = this.sections[this.currentPreviewStep];
    if (currentSec) {
      const secFields = this.fields.filter(f => f.section === currentSec.name && f.isActive !== false).sort((a, b) => a.order - b.order);
      
      html += `
        <div style="background: #fff; border-radius: 12px; padding: 16px; box-shadow: 0 2px 8px rgba(0,0,0,0.05); margin-bottom: 20px;">
          <h4 style="margin: 0 0 16px 0; display: flex; align-items: center; gap: 8px;">
            <span>${SECTION_ICONS[currentSec.icon] || ''}</span> ${escapeHTML(currentSec.label)}
          </h4>
          <div style="display: flex; flex-wrap: wrap; gap: 16px;">
            ${secFields.map(f => this.renderPreviewField(f)).join('')}
          </div>
        </div>
        <div style="display: flex; gap: 10px;">
          ${this.currentPreviewStep > 0 ? `<button id="fb-prev-step" style="flex: 1; padding: 12px; background: #f0f0f0; color: #333; border: none; border-radius: 8px; font-weight: 600; cursor: pointer;">Previous Step</button>` : ''}
          ${this.currentPreviewStep < totalSteps - 1 ? `<button id="fb-next-step" style="flex: 1; padding: 12px; background: #4361ee; color: white; border: none; border-radius: 8px; font-weight: 600; cursor: pointer;">Next Step</button>` : ''}
          ${this.currentPreviewStep === totalSteps - 1 ? `<button style="flex: 1; padding: 12px; background: #28a745; color: white; border: none; border-radius: 8px; font-weight: 600; cursor: pointer;">Submit</button>` : ''}
        </div>
      `;
    } else {
      html += `<div style="text-align: center; color: #888; padding: 40px 0;">No sections available</div>`;
    }

    container.innerHTML = html;
    
    setTimeout(() => this.evaluateConditionals(), 50);

    const prevBtn = document.getElementById('fb-prev-step');
    if(prevBtn) prevBtn.addEventListener('click', () => { this.currentPreviewStep--; this.renderPreview(); });
    const nextBtn = document.getElementById('fb-next-step');
    if(nextBtn) nextBtn.addEventListener('click', () => { this.currentPreviewStep++; this.renderPreview(); });
  }

  static evaluateConditionals() {
    const container = document.getElementById('fb-live-preview');
    if(!container) return;
    
    const currentSec = this.sections[this.currentPreviewStep];
    if(!currentSec) return;
    const secFields = this.fields.filter(f => f.section === currentSec.name && f.isActive !== false);

    secFields.forEach(field => {
      if (field.conditional && field.conditional.enabled) {
        const wrapper = container.querySelector(`[data-field-wrapper="${escapeHTML(field.name)}"]`);
        if(!wrapper) return;

        const targetName = field.conditional.field;
        const operator = field.conditional.operator;
        const targetValue = field.conditional.value;
        
        let shouldShow = false;
        
        const targetInput = container.querySelector(`[name="${escapeHTML(targetName)}"]`);
        if (targetInput) {
          let val = '';
          if (targetInput.type === 'checkbox' || targetInput.type === 'radio') {
            const checked = container.querySelector(`[name="${escapeHTML(targetName)}"]:checked`);
            val = checked ? checked.value : (targetInput.checked ? 'true' : 'false');
          } else {
            val = targetInput.value;
          }
          
          if (operator === 'equals' && val === targetValue) shouldShow = true;
          if (operator === 'not_equals' && val !== targetValue) shouldShow = true;
          if (operator === 'contains' && val.includes(targetValue)) shouldShow = true;
        }

        wrapper.style.display = shouldShow ? (field.width === 'half' ? 'block' : 'block') : 'none';
      }
    });
  }

  static renderPreviewField(field) {
    let inputHtml = '';
    const placeholder = field.placeholder ? `placeholder="${escapeHTML(field.placeholder)}"` : '';
    const style = 'width: 100%; padding: 10px 12px; border: 1px solid #ddd; border-radius: 6px; box-sizing: border-box; font-size: 14px;';
    const validationProps = `
      ${field.validation?.minLength ? `minlength="${field.validation.minLength}"` : ''}
      ${field.validation?.maxLength ? `maxlength="${field.validation.maxLength}"` : ''}
      ${field.validation?.pattern ? `pattern="${escapeHTML(field.validation.pattern)}"` : ''}
      ${field.validation?.patternError ? `title="${escapeHTML(field.validation.patternError)}"` : ''}
    `;

    switch (field.type) {
      case 'textarea':
        inputHtml = `<textarea name="${escapeHTML(field.name)}" ${placeholder} ${validationProps} style="${style} min-height: 80px; resize: vertical;"></textarea>`;
        break;
      case 'select':
        inputHtml = `
          <select name="${escapeHTML(field.name)}" style="${style}">
            <option value="">Select option</option>
            ${(field.options || []).map(o => `<option value="${escapeHTML(o.label || o)}">${escapeHTML(o.label || o)}</option>`).join('')}
          </select>
        `;
        break;
      case 'radio':
        inputHtml = `<div style="display: flex; gap: 12px; flex-wrap: wrap;">
          ${(field.options || ['Option 1', 'Option 2']).map(o => `
            <label style="display: flex; align-items: center; gap: 4px; font-size: 14px;">
              <input type="radio" name="${escapeHTML(field.name)}" value="${escapeHTML(o.label || o)}"> ${escapeHTML(o.label || o)}
            </label>
          `).join('')}
        </div>`;
        break;
      case 'checkbox':
      case 'terms_checkbox':
        inputHtml = `
          <label style="display: flex; align-items: flex-start; gap: 8px; font-size: 14px;">
            <input type="checkbox" name="${escapeHTML(field.name)}" value="true" style="margin-top: 3px;">
            <span>${escapeHTML(field.label)}</span>
          </label>
        `;
        break;
      case 'color':
        inputHtml = `<input type="color" name="${escapeHTML(field.name)}" style="width: 100%; height: 40px; padding: 0; border: 1px solid #ddd; border-radius: 6px;">`;
        break;
      case 'file':
      case 'photo_upload':
      case 'signature_pad':
        inputHtml = `<input type="file" name="${escapeHTML(field.name)}" style="${style}">`;
        break;
      default:
        let t = field.type;
        if(!['text','number','email','password','date','time','url','tel'].includes(t)) t = 'text';
        if(t === 'phone') t = 'tel';
        inputHtml = `<input type="${t}" name="${escapeHTML(field.name)}" ${placeholder} ${validationProps} style="${style}">`;
    }

    const flexBasis = field.width === 'half' ? 'calc(50% - 8px)' : '100%';

    if (field.type === 'checkbox' || field.type === 'terms_checkbox') {
      return `<div data-field-wrapper="${escapeHTML(field.name)}" style="flex: 1 1 ${flexBasis}; width: ${flexBasis};">${inputHtml}</div>`;
    }

    return `
      <div data-field-wrapper="${escapeHTML(field.name)}" style="display: flex; flex-direction: column; gap: 4px; flex: 1 1 ${flexBasis}; width: ${flexBasis};">
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
    const section = sectionId ? this.sections.find(s => (s.id || s.name) === sectionId) : {
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
        ...(!isNew ? [{ text: 'Delete', type: 'danger', onClick: () => this.deleteSection(section.name) }] : []),
        { text: 'Save', type: 'primary', onClick: () => this.saveSection(isNew, section) }
      ]
    });
  }

  static async saveSection(isNew, sectionObj) {
    const newLabel = document.getElementById('sec-label').value.trim();
    const newName = document.getElementById('sec-name').value.trim();
    const newIcon = document.getElementById('sec-icon').value;
    
    if (!newLabel || !newName) return Toast.warning('Label and Name required');

    const payload = {
      name: newName,
      label: newLabel,
      icon: newIcon,
      order: sectionObj.order || this.sections.length + 1
    };

    try {
      if (typeof Loading !== 'undefined' && Loading.show) Loading.show();
      if (isNew) {
        const res = await api.post('/api/custom-fields/sections', payload);
        this.sections.push(res.data || { id: 'sec_' + Date.now(), ...payload });
      } else {
        const res = await api.put('/api/custom-fields/sections/' + sectionObj.name, payload);
        Object.assign(sectionObj, payload);
      }
      this.renderSections();
      this.renderPreview();
      Modal.hide();
      Toast.success('Section saved');
    } catch (e) {
      console.error(e);
      Toast.error('Failed to save section');
    } finally {
      if (typeof Loading !== 'undefined' && Loading.hide) Loading.hide();
    }
  }

  static async deleteSection(sectionKey) {
    Confirm.show({
      title: 'Delete Section',
      message: 'Are you sure you want to delete this section?',
      className: 'btn-danger',
      onConfirm: async () => {
        try {
          if (typeof Loading !== 'undefined' && Loading.show) Loading.show();
          await api.delete('/api/custom-fields/sections/' + sectionKey);
          this.sections = this.sections.filter(s => s.name !== sectionKey);
          this.fields = this.fields.filter(f => f.section !== sectionKey);
          this.currentPreviewStep = 0;
          this.renderSections();
          this.renderPreview();
          Modal.hide();
          Toast.success('Section deleted');
        } catch (e) {
          console.error(e);
          Toast.error('Failed to delete section');
        } finally {
          if (typeof Loading !== 'undefined' && Loading.hide) Loading.hide();
        }
      }
    });
  }

  static openFieldEditor(fieldId = null) {
    const field = fieldId ? this.fields.find(f => (f._id || f.id) === fieldId) : {
      label: '', name: '', type: 'text', section: this.sections[0]?.name || '', required: false, placeholder: '', helpText: '', options: [],
      width: 'full', validation: {}, conditional: { enabled: false, field: '', operator: 'equals', value: '' }
    };
    const isNew = !fieldId;

    const html = `
      <div class="tabs-container" style="margin-bottom: 16px;">
        <div style="display: flex; gap: 8px; border-bottom: 1px solid #ddd; margin-bottom: 16px;">
          <button class="tab-btn active" data-tab="general" style="padding: 8px 16px; border: none; background: none; border-bottom: 2px solid #4361ee; font-weight: 500; cursor: pointer;">General</button>
          <button class="tab-btn" data-tab="validation" style="padding: 8px 16px; border: none; background: none; cursor: pointer;">Validation</button>
          <button class="tab-btn" data-tab="conditional" style="padding: 8px 16px; border: none; background: none; cursor: pointer;">Conditional Logic</button>
        </div>

        <!-- GENERAL TAB -->
        <div class="tab-content" id="tab-general">
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
            <div class="form-group">
              <label>Column Width</label>
              <select id="fld-width" class="form-input">
                <option value="full" ${field.width !== 'half' ? 'selected' : ''}>Full Width (100%)</option>
                <option value="half" ${field.width === 'half' ? 'selected' : ''}>Half Width (50%)</option>
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
        </div>

        <!-- VALIDATION TAB -->
        <div class="tab-content" id="tab-validation" style="display: none;">
          <div class="form-group">
            <label>Min Length</label>
            <input type="number" id="fld-val-min" class="form-input" value="${field.validation?.minLength || ''}">
          </div>
          <div class="form-group">
            <label>Max Length</label>
            <input type="number" id="fld-val-max" class="form-input" value="${field.validation?.maxLength || ''}">
          </div>
          <div class="form-group">
            <label>Regex Pattern</label>
            <input type="text" id="fld-val-pattern" class="form-input" value="${escapeHTML(field.validation?.pattern || '')}" placeholder="e.g. ^[0-9]{10}$">
          </div>
          <div class="form-group">
            <label>Pattern Error Message</label>
            <input type="text" id="fld-val-error" class="form-input" value="${escapeHTML(field.validation?.patternError || '')}" placeholder="Invalid format">
          </div>
        </div>

        <!-- CONDITIONAL LOGIC TAB -->
        <div class="tab-content" id="tab-conditional" style="display: none;">
          <div class="form-group" style="display: flex; align-items: center; gap: 8px; margin-bottom: 16px;">
            <input type="checkbox" id="fld-cond-enable" ${field.conditional?.enabled ? 'checked' : ''}>
            <label for="fld-cond-enable" style="margin: 0; font-weight: bold;">Enable Conditional Display</label>
          </div>
          <div id="cond-settings" style="display: ${field.conditional?.enabled ? 'block' : 'none'}; border: 1px solid #ddd; padding: 16px; border-radius: 8px;">
            <div class="form-group">
              <label>Show only when Field:</label>
              <select id="fld-cond-field" class="form-input">
                <option value="">Select Field</option>
                ${this.fields.map(f => `<option value="${f.name}" ${field.conditional?.field === f.name ? 'selected' : ''}>${escapeHTML(f.label)}</option>`).join('')}
              </select>
            </div>
            <div class="form-group">
              <label>Operator</label>
              <select id="fld-cond-op" class="form-input">
                <option value="equals" ${field.conditional?.operator === 'equals' ? 'selected' : ''}>Equals</option>
                <option value="not_equals" ${field.conditional?.operator === 'not_equals' ? 'selected' : ''}>Not Equals</option>
                <option value="contains" ${field.conditional?.operator === 'contains' ? 'selected' : ''}>Contains</option>
              </select>
            </div>
            <div class="form-group">
              <label>Target Value</label>
              <input type="text" id="fld-cond-val" class="form-input" value="${escapeHTML(field.conditional?.value || '')}">
            </div>
          </div>
        </div>

      </div>
    `;

    Modal.show({
      title: isNew ? 'Add Field' : 'Edit Field',
      content: html,
      width: '600px',
      buttons: [
        { text: 'Cancel', type: 'secondary', onClick: () => Modal.hide() },
        ...(!isNew ? [{ text: 'Delete', type: 'danger', onClick: () => this.deleteField(fieldId) }] : []),
        { text: 'Save', type: 'primary', onClick: () => this.saveField(isNew, field) }
      ]
    });

    // Tab switching logic
    document.querySelectorAll('.tab-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        document.querySelectorAll('.tab-btn').forEach(b => {
          b.classList.remove('active');
          b.style.borderBottom = 'none';
        });
        e.target.classList.add('active');
        e.target.style.borderBottom = '2px solid #4361ee';
        
        document.querySelectorAll('.tab-content').forEach(c => c.style.display = 'none');
        document.getElementById(`tab-${e.target.dataset.tab}`).style.display = 'block';
      });
    });

    if (isNew) {
      document.getElementById('fld-label').addEventListener('input', (e) => {
        const val = e.target.value;
        document.getElementById('fld-name').value = val.toLowerCase().replace(/[^a-z0-9]/g, '_').replace(/_+/g, '_').replace(/^_|_$/g, '');
      });
    }

    document.getElementById('fld-type').addEventListener('change', (e) => {
      const type = e.target.value;
      const optsContainer = document.getElementById('fld-options-container');
      optsContainer.style.display = ['select','radio','multiselect'].includes(type) ? 'block' : 'none';
    });

    document.getElementById('fld-cond-enable').addEventListener('change', (e) => {
      document.getElementById('cond-settings').style.display = e.target.checked ? 'block' : 'none';
    });
  }

  static async saveField(isNew, fieldObj) {
    const payload = {
      label: document.getElementById('fld-label').value.trim(),
      name: document.getElementById('fld-name').value.trim(),
      type: document.getElementById('fld-type').value,
      section: document.getElementById('fld-section').value,
      width: document.getElementById('fld-width').value,
      placeholder: document.getElementById('fld-placeholder').value.trim(),
      helpText: document.getElementById('fld-help').value.trim(),
      required: document.getElementById('fld-required').checked,
      options: [],
      validation: {
        minLength: document.getElementById('fld-val-min').value,
        maxLength: document.getElementById('fld-val-max').value,
        pattern: document.getElementById('fld-val-pattern').value,
        patternError: document.getElementById('fld-val-error').value
      },
      conditional: {
        enabled: document.getElementById('fld-cond-enable').checked,
        field: document.getElementById('fld-cond-field').value,
        operator: document.getElementById('fld-cond-op').value,
        value: document.getElementById('fld-cond-val').value.trim()
      }
    };

    if (['select','radio','multiselect'].includes(payload.type)) {
      const optsStr = document.getElementById('fld-options').value.trim();
      if (optsStr) {
        payload.options = optsStr.split(',').map(s => s.trim()).filter(Boolean);
      }
    }

    if (!payload.label || !payload.name) return Toast.warning('Label and Name required');

    try {
      if (typeof Loading !== 'undefined' && Loading.show) Loading.show();
      if (isNew) {
        payload.order = this.fields.length + 1;
        const res = await api.post('/api/custom-fields', payload);
        this.fields.push(res.data || { _id: 'fld_' + Date.now(), ...payload });
      } else {
        const id = fieldObj._id || fieldObj.id;
        const res = await api.put('/api/custom-fields/' + id, payload);
        Object.assign(fieldObj, payload);
      }
      this.renderSections();
      this.renderPreview();
      Modal.hide();
      Toast.success('Field saved');
    } catch (e) {
      console.error(e);
      Toast.error('Failed to save field');
    } finally {
      if (typeof Loading !== 'undefined' && Loading.hide) Loading.hide();
    }
  }

  static async deleteField(fieldId) {
    Confirm.show({
      title: 'Delete Field',
      message: 'Are you sure you want to delete this field? This action cannot be undone.',
      className: 'btn-danger',
      onConfirm: async () => {
        try {
          if (typeof Loading !== 'undefined' && Loading.show) Loading.show();
          await api.delete('/api/custom-fields/' + fieldId);
          this.fields = this.fields.filter(f => (f._id || f.id) !== fieldId);
          this.renderSections();
          this.renderPreview();
          Modal.hide();
          Toast.success('Field deleted');
        } catch(e) {
          console.error(e);
          Toast.error('Failed to delete field');
        } finally {
          if (typeof Loading !== 'undefined' && Loading.hide) Loading.hide();
        }
      }
    });
  }

  static async toggleFieldActive(fieldId) {
    try {
      if (typeof Loading !== 'undefined' && Loading.show) Loading.show();
      await api.put('/api/custom-fields/' + fieldId + '/toggle');
      const field = this.fields.find(f => (f._id || f.id) === fieldId);
      if(field) {
        field.isActive = field.isActive === false ? true : false;
      }
      this.renderSections();
      this.renderPreview();
      Toast.success(field.isActive ? 'Field enabled' : 'Field disabled');
    } catch(e) {
      console.error(e);
      Toast.error('Failed to toggle field');
    } finally {
      if (typeof Loading !== 'undefined' && Loading.hide) Loading.hide();
    }
  }
}
