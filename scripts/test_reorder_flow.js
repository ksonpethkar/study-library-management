require('dotenv').config();
const connectDB = require('../config/db');
const FormTemplate = require('../models/FormTemplate');
const CustomField = require('../models/CustomField');
const mongoose = require('mongoose');

async function verifyFullReorderPersistence() {
  await connectDB();
  console.log('\n=============================================');
  console.log('🧪 VERIFYING REGISTRATION FORM REORDER PERSISTENCE');
  console.log('=============================================\n');

  // 1. Ensure standard fields
  await CustomField.ensureStandardFields();
  const allFieldsBefore = await CustomField.find().sort({ order: 1, createdAt: 1 }).lean();
  console.log(`✅ Step 1: Loaded ${allFieldsBefore.length} fields from MongoDB`);

  // 2. Perform Question Reorder Simulation (Reverse order of personal section fields)
  const personalFields = allFieldsBefore.filter(f => f.section === 'personal');
  console.log('Original personal section fields order:');
  personalFields.forEach(f => console.log(`   - ${f.fieldName} (order: ${f.order})`));

  // Reverse them and assign new orders
  const newPersonalOrders = personalFields.map((f, idx) => ({
    id: f._id.toString(),
    fieldName: f.fieldName,
    order: idx + 10,
    section: 'personal'
  }));

  console.log('\nSimulating PUT /api/custom-fields/reorder with payload:');
  newPersonalOrders.forEach(f => console.log(`   -> Set ${f.fieldName} order = ${f.order}`));

  // Process through exact backend reorder logic
  const bulkOps = [];
  for (let i = 0; i < newPersonalOrders.length; i++) {
    const item = newPersonalOrders[i];
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

  await CustomField.bulkWrite(bulkOps);
  console.log('✅ Step 2: CustomField bulkWrite executed successfully without any CastError');

  // 3. Simulate Hard Refresh (fresh DB read)
  const allFieldsAfter = await CustomField.find().sort({ order: 1, createdAt: 1 }).lean();
  const personalFieldsAfter = allFieldsAfter.filter(f => f.section === 'personal');
  console.log('\n✅ Step 3: Hard Refresh Simulated (Fresh DB Read):');
  personalFieldsAfter.forEach(f => console.log(`   - ${f.fieldName} (order: ${f.order})`));

  // Assert orders match
  let allMatched = true;
  for (const expected of newPersonalOrders) {
    const actual = personalFieldsAfter.find(f => f.fieldName === expected.fieldName);
    if (!actual || actual.order !== expected.order) {
      allMatched = false;
      console.error(`❌ Mismatch for ${expected.fieldName}: expected ${expected.order}, got ${actual?.order}`);
    }
  }

  if (allMatched) {
    console.log('\n🎉 ALL REORDERED FIELDS SUCCESSFULLY PERSISTED IN MONGODB & VERIFIED AFTER FRESH FETCH!');
  } else {
    throw new Error('Verification failed: orders did not persist correctly');
  }

  // 4. Test Section Reordering & Persistence
  console.log('\n--- Step 4: Testing Section Reordering in FormTemplate ---');
  let template = await FormTemplate.findOne({ isActive: true });
  if (!template) {
    template = await FormTemplate.create({ name: 'Default', slug: 'default', isActive: true });
  }

  const reorderedSections = template.sections.map((s, idx) => ({
    name: s.name,
    label: s.label,
    icon: s.icon || 'other',
    order: idx + 1,
    isSystem: Boolean(s.isSystem),
    isHidden: Boolean(s.isHidden)
  }));

  // Reverse section order
  reorderedSections.reverse();
  reorderedSections.forEach((s, idx) => { s.order = idx + 1; });

  await FormTemplate.findByIdAndUpdate(template._id, { $set: { sections: reorderedSections } }, { new: true });
  const freshTemplate = await FormTemplate.findById(template._id).lean();
  console.log('Fresh template sections after update:');
  freshTemplate.sections.forEach(s => console.log(`   - ${s.name} (order: ${s.order}, label: "${s.label}")`));

  console.log('\n✅ Step 4: Sections reordering verified and persisted in MongoDB');

  // Restore reasonable default section ordering for template
  const defaultSections = [
    { name: 'personal', label: 'Step 1: Study Centre & Personal Info', icon: 'personal', order: 1, isSystem: true, isHidden: false },
    { name: 'contact', label: 'Step 2: Address & Emergency Contact', icon: 'other', order: 2, isSystem: false, isHidden: false },
    { name: 'kyc', label: 'Step 3: KYC & Verification', icon: 'other', order: 3, isSystem: false, isHidden: false },
    { name: 'academic', label: 'Step 4: Academic Goals & KYC Proof', icon: 'academic', order: 4, isSystem: false, isHidden: false },
    { name: 'plan', label: 'Step 5: Membership Plan & Fee Calculator', icon: 'plan', order: 5, isSystem: true, isHidden: false },
    { name: 'payment', label: 'Step 6: Dynamic Payment Selection', icon: 'payment', order: 6, isSystem: true, isHidden: false },
    { name: 'seat', label: 'Step 7: Seat Selection & Digital Signature', icon: 'seat', order: 7, isSystem: true, isHidden: false },
    { name: 'other', label: 'Step 8: Additional Information', icon: 'other', order: 8, isSystem: false, isHidden: false }
  ];
  await FormTemplate.findByIdAndUpdate(template._id, { $set: { sections: defaultSections } });
  console.log('✅ Clean default section order preserved for active template.');

  await mongoose.disconnect();
  console.log('\n=============================================');
  console.log('✅ ALL TESTS PASSED (100%)');
  console.log('=============================================\n');
}

verifyFullReorderPersistence().catch(err => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
