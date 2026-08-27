const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const CustomField = require('../models/CustomField');
const FormTemplate = require('../models/FormTemplate');
const { protect } = require('../middleware/auth');
const { roleCheck } = require('../middleware/roleCheck');
const { validateCustomField } = require('../middleware/validate');
const memoryCache = require('../utils/memoryCache');

// =============================================================
// PUBLIC & SHARED READ ENDPOINTS
// =============================================================

// GET /api/custom-fields - Get all form fields with active status
router.get('/', async (req, res) => {
  res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
  try {
    const fields = await CustomField.find({ isDeleted: { $ne: true } }).sort({ order: 1, createdAt: 1 }).lean();
    res.json({ success: true, data: fields });
  } catch (err) {
    console.error('Error fetching custom fields:', err);
    res.status(500).json({ success: false, message: 'Failed to fetch form fields' });
  }
});

// GET /api/custom-fields/all - Get all fields including inactive
router.get('/all', async (req, res) => {
  res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
  try {
    const fields = await CustomField.find().sort({ order: 1, createdAt: 1 }).lean();
    res.json({ success: true, data: fields });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to fetch form fields' });
  }
});

// GET /api/custom-fields/templates/active - Get active template
router.get('/templates/active', async (req, res) => {
  res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
  try {
    const template = await FormTemplate.getActiveTemplate();
    res.json({ success: true, data: template });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to fetch active template' });
  }
});

// GET /api/custom-fields/sections - Get unique sections
router.get('/sections', async (req, res) => {
  res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
  try {
    const fields = await CustomField.find().sort({ order: 1 }).lean();
    const sectionsMap = new Map();
    
    fields.forEach(field => {
      if (!sectionsMap.has(field.section)) {
        sectionsMap.set(field.section, {
          key: field.section,
          label: field.sectionLabel || field.section,
          icon: field.sectionIcon || '',
          description: field.sectionDescription || '',
          instructions: field.sectionInstructions || '',
          fieldCount: 0
        });
      }
      sectionsMap.get(field.section).fieldCount++;
    });
    
    res.json({ success: true, data: Array.from(sectionsMap.values()) });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to fetch sections' });
  }
});

// GET /api/custom-fields/templates - List all templates
router.get('/templates', async (req, res) => {
  try {
    const templates = await FormTemplate.find().sort({ createdAt: -1 });
    res.json({ success: true, data: templates });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// =============================================================
// PROTECTED ADMIN WRITE / MUTATION ENDPOINTS
// =============================================================
router.use(protect);
router.use(roleCheck('owner', 'branch_manager'));
router.use((req, res, next) => {
  if (['POST', 'PUT', 'DELETE', 'PATCH'].includes(req.method)) {
    memoryCache.clear();
  }
  next();
});

// 1. REORDER ROUTES (MUST BE BEFORE /:id PARAMETERIZED ROUTES)
// PUT /api/custom-fields/reorder & /reorder/bulk - Bulk update field orders & sections
router.put(['/reorder', '/reorder/bulk'], async (req, res) => {
  try {
    const { items, orders, orderedIds, sections } = req.body;
    const fieldsToUpdate = orders || items;

    if (Array.isArray(fieldsToUpdate) && fieldsToUpdate.length > 0) {
      const bulkOps = [];
      for (let i = 0; i < fieldsToUpdate.length; i++) {
        const item = fieldsToUpdate[i];
        const idVal = item.id || item._id;
        const newOrder = item.order !== undefined ? Number(item.order) : (i + 1);
        const updateData = { order: newOrder };
        if (item.section) updateData.section = item.section;

        if (idVal && mongoose.Types.ObjectId.isValid(idVal)) {
          bulkOps.push({
            updateOne: {
              filter: { _id: idVal },
              update: { $set: updateData }
            }
          });
        } else {
          const fn = (item.fieldName || item.name || idVal || '').toString().replace(/^sys_/, '').trim().toLowerCase();
          if (fn) {
            bulkOps.push({
              updateOne: {
                filter: { fieldName: fn },
                update: { $set: updateData }
              }
            });
          }
        }
      }
      if (bulkOps.length > 0) {
        await CustomField.bulkWrite(bulkOps);
      }
    } else if (Array.isArray(orderedIds) && orderedIds.length > 0) {
      const bulkOps = [];
      for (let i = 0; i < orderedIds.length; i++) {
        const id = orderedIds[i];
        if (id && mongoose.Types.ObjectId.isValid(id)) {
          bulkOps.push({
            updateOne: {
              filter: { _id: id },
              update: { $set: { order: i + 1 } }
            }
          });
        }
      }
      if (bulkOps.length > 0) {
        await CustomField.bulkWrite(bulkOps);
      }
    }

    if (Array.isArray(sections) && sections.length > 0) {
      const cleanSections = sections.map((s, idx) => ({
        name: s.name,
        label: s.label,
        icon: s.icon || 'other',
        order: s.order !== undefined ? Number(s.order) : (idx + 1),
        isSystem: Boolean(s.isSystem),
        isHidden: Boolean(s.isHidden)
      }));
      let template = await FormTemplate.findOne({ isActive: true });
      if (template) {
        template.sections = cleanSections;
        await template.save();
      }
    }

    memoryCache.clear();
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.json({ success: true, message: 'Fields and sections reordered & saved successfully' });
  } catch (err) {
    console.error('Error reordering custom fields:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// 2. TEMPLATE ACTIVE & BRANDING ROUTES
// PUT /api/custom-fields/templates/active - Update active template branding & settings
router.put('/templates/active', async (req, res) => {
  try {
    let template = await FormTemplate.findOne({ isActive: true });
    
    // Sanitize sections array if present to ensure clean persistence
    if (req.body.sections && Array.isArray(req.body.sections)) {
      req.body.sections = req.body.sections.map((s, idx) => ({
        name: s.name,
        label: s.label,
        icon: s.icon || 'other',
        order: s.order !== undefined ? Number(s.order) : (idx + 1),
        isSystem: Boolean(s.isSystem),
        isHidden: Boolean(s.isHidden)
      }));
    }

    if (!template) {
      template = await FormTemplate.create({ name: 'Default Template', slug: 'default', isActive: true, ...req.body });
    } else {
      // Merge settings, branding and sections properly
      if (req.body.settings && template.settings) {
        req.body.settings = { ...template.settings.toObject(), ...req.body.settings };
      }
      if (req.body.branding && template.branding) {
        req.body.branding = { ...template.branding.toObject(), ...req.body.branding };
      }
      template = await FormTemplate.findByIdAndUpdate(template._id, { $set: req.body }, { new: true, runValidators: false });
    }
    memoryCache.clear();
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.json({ success: true, data: template, message: 'Header branding & template updated successfully' });
  } catch (err) {
    console.error('Error updating active template:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// 3. RESET DEFAULTS ROUTE
// POST /api/custom-fields/reset-defaults - Re-seed standard fields
router.post('/reset-defaults', async (req, res) => {
  try {
    await CustomField.seedDefaultFields(true);
    const fields = await CustomField.find().sort({ order: 1 });
    res.json({ success: true, message: 'All standard admission form fields reset to defaults', data: fields });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// 4. SECTION SPECIFIC ROUTES
// PUT /api/custom-fields/sections/:sectionKey - Update section metadata
router.put('/sections/:sectionKey', async (req, res) => {
  try {
    const { sectionKey } = req.params;
    const { label, icon, description, instructions } = req.body;
    
    const updateData = {};
    if (label !== undefined) updateData.sectionLabel = label;
    if (icon !== undefined) updateData.sectionIcon = icon;
    if (description !== undefined) updateData.sectionDescription = description;
    if (instructions !== undefined) updateData.sectionInstructions = instructions;
    
    if (label !== undefined) {
      await CustomField.updateMany({ section: sectionKey }, { sectionLabel: label });
    }
    
    const firstField = await CustomField.findOne({ section: sectionKey }).sort({ order: 1 });
    if (firstField) {
      Object.assign(firstField, updateData);
      await firstField.save();
    }
    
    res.json({ success: true, message: 'Section updated successfully' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/custom-fields/sections - Create a new section
router.post('/sections', async (req, res) => {
  try {
    const { key, label } = req.body;
    if (!key || !label) {
      return res.status(400).json({ success: false, message: 'Section key and label are required' });
    }
    
    const existing = await CustomField.findOne({ section: key });
    if (existing) {
      return res.status(400).json({ success: false, message: 'Section key already exists' });
    }
    
    res.status(201).json({ success: true, message: 'Section added. Add fields to make it visible.' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE /api/custom-fields/sections/:sectionKey - Delete section and move fields
router.delete('/sections/:sectionKey', async (req, res) => {
  try {
    const { sectionKey } = req.params;
    if (sectionKey === 'general') {
      return res.status(400).json({ success: false, message: 'Cannot delete the default section' });
    }
    await CustomField.updateMany({ section: sectionKey }, { section: 'general', sectionLabel: 'General' });
    res.json({ success: true, message: 'Section deleted, fields moved to Additional Information' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// 5. TEMPLATE CRUD ROUTES
// POST /api/custom-fields/templates - Create template
router.post('/templates', async (req, res) => {
  try {
    const template = new FormTemplate(req.body);
    await template.save();
    res.status(201).json({ success: true, data: template, message: 'Template created successfully' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/custom-fields/templates/:id/activate - Activate template
router.put('/templates/:id/activate', async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ success: false, message: 'Invalid template ID' });
    }
    const template = await FormTemplate.findById(req.params.id);
    if (!template) return res.status(404).json({ success: false, message: 'Template not found' });
    template.isActive = true;
    await template.save();
    res.json({ success: true, message: 'Template activated successfully' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/custom-fields/templates/:id - Update template
router.put('/templates/:id', async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ success: false, message: 'Invalid template ID' });
    }
    const template = await FormTemplate.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!template) return res.status(404).json({ success: false, message: 'Template not found' });
    res.json({ success: true, data: template, message: 'Template updated successfully' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE /api/custom-fields/templates/:id - Delete template
router.delete('/templates/:id', async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ success: false, message: 'Invalid template ID' });
    }
    const template = await FormTemplate.findById(req.params.id);
    if (!template) return res.status(404).json({ success: false, message: 'Template not found' });
    if (template.isActive) return res.status(400).json({ success: false, message: 'Cannot delete active template' });
    await FormTemplate.findByIdAndDelete(req.params.id);
    res.json({ success: true, message: 'Template deleted successfully' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// 6. GENERAL FIELD CREATION ROUTE
// POST /api/custom-fields - Create a new form field
router.post('/', validateCustomField, async (req, res) => {
  try {
    const { 
      fieldName, label, type, placeholder, options, required, section, sectionLabel, helpText, defaultValue,
      colSpan, validation, conditional, sectionIcon, sectionDescription
    } = req.body;

    if (!label) {
      return res.status(400).json({ success: false, message: 'Field label is required' });
    }

    // Generate unique slug
    let slug = (fieldName || label).toLowerCase().replace(/[^a-z0-9]/g, '_');
    const existing = await CustomField.findOne({ fieldName: slug });
    if (existing) {
      slug = `${slug}_${Date.now().toString().slice(-4)}`;
    }

    const count = await CustomField.countDocuments();

    const field = new CustomField({
      fieldName: slug,
      label,
      type: type || 'text',
      placeholder: placeholder || '',
      options: Array.isArray(options) ? options : (options ? options.split(',').map(s => s.trim()).filter(Boolean) : []),
      required: Boolean(required),
      order: count + 1,
      section: section || 'general',
      sectionLabel: sectionLabel || (section ? section.charAt(0).toUpperCase() + section.slice(1) : 'General'),
      helpText: helpText || '',
      defaultValue: defaultValue || null,
      colSpan: colSpan || 12,
      validation: validation || {},
      conditional: conditional || {},
      sectionIcon: sectionIcon || '',
      sectionDescription: sectionDescription || '',
      isActive: true,
      isSystemField: false,
      isDeletable: true
    });

    await field.save();
    res.status(201).json({ success: true, message: 'Form field created successfully', data: field });
  } catch (err) {
    console.error('Error creating custom field:', err);
    res.status(500).json({ success: false, message: err.message || 'Failed to create form field' });
  }
});

// 7. PARAMETERIZED FIELD ROUTES (MUST BE AT THE VERY END OF THE FILE)
// PUT /api/custom-fields/:id/toggle - Toggle active/inactive
router.put('/:id/toggle', async (req, res, next) => {
  if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
    return next();
  }
  try {
    const field = await CustomField.findById(req.params.id);
    if (!field) return res.status(404).json({ success: false, message: 'Field not found' });

    field.isActive = !field.isActive;
    await field.save();

    res.json({ success: true, message: `Field is now ${field.isActive ? 'Active (Shown)' : 'Inactive (Hidden)'}`, data: field });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/custom-fields/:id - Update form field
router.put('/:id', async (req, res, next) => {
  if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
    return next();
  }
  try {
    const { 
      label, type, placeholder, options, required, section, sectionLabel, helpText, isActive, order, defaultValue,
      colSpan, validation, conditional, sectionIcon, sectionDescription
    } = req.body;

    const updateData = {};
    if (label !== undefined) updateData.label = label;
    if (type !== undefined) updateData.type = type;
    if (placeholder !== undefined) updateData.placeholder = placeholder;
    if (options !== undefined) {
      updateData.options = Array.isArray(options) ? options : (options ? options.split(',').map(s => s.trim()).filter(Boolean) : []);
    }
    if (required !== undefined) updateData.required = Boolean(required);
    if (section !== undefined) updateData.section = section;
    if (sectionLabel !== undefined) updateData.sectionLabel = sectionLabel;
    if (helpText !== undefined) updateData.helpText = helpText;
    if (isActive !== undefined) updateData.isActive = Boolean(isActive);
    if (order !== undefined) updateData.order = parseInt(order, 10);
    if (defaultValue !== undefined) updateData.defaultValue = defaultValue;
    if (colSpan !== undefined) updateData.colSpan = colSpan;
    if (validation !== undefined) updateData.validation = validation;
    if (conditional !== undefined) updateData.conditional = conditional;
    if (sectionIcon !== undefined) updateData.sectionIcon = sectionIcon;
    if (sectionDescription !== undefined) updateData.sectionDescription = sectionDescription;

    const field = await CustomField.findByIdAndUpdate(req.params.id, updateData, { new: true });
    if (!field) {
      return res.status(404).json({ success: false, message: 'Field not found' });
    }

    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.json({ success: true, message: 'Field updated successfully', data: field });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message || 'Failed to update field' });
  }
});

// DELETE /api/custom-fields/:id - Direct delete with undo support (no trash clogging)
router.delete('/:id', async (req, res, next) => {
  if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
    return next();
  }
  try {
    const field = await CustomField.findById(req.params.id);
    if (!field) return res.status(404).json({ success: false, message: 'Field not found' });

    if (field.isSystemField && !field.isDeletable) {
      return res.status(400).json({ success: false, message: 'Essential core fields (like Name and Phone) cannot be deleted. You can edit their labels or set them inactive.' });
    }

    const deletedDoc = await CustomField.findByIdAndDelete(req.params.id);

    // Clean up any residual trash records for this field to keep recycle bin clean
    try {
      const Trash = require('../models/Trash');
      await Trash.deleteMany({ itemType: 'custom_field', itemId: field._id });
    } catch (e) {}

    res.json({
      success: true,
      message: `Question "${field.label || field.name}" deleted`,
      data: deletedDoc
    });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to delete field' });
  }
});

module.exports = router;
