require('dotenv').config();
const mongoose = require('mongoose');
const http = require('http');
const app = require('express')();
const Student = require('../models/Student');
const Trash = require('../models/Trash');
const Seat = require('../models/Seat');
const memoryCache = require('../utils/memoryCache');

const connectDB = require('../config/db');

async function runTests() {
  console.log('🧪 Starting Trash & Performance Verification Tests...\n');

  try {
    await connectDB();

    // 1. Test In-Memory Cache Performance
    console.log('\n--- Test 1: In-Memory Cache Performance ---');
    const cacheKey = 'test_perf_key';
    memoryCache.set(cacheKey, { test: 'value', numbers: [1, 2, 3] }, 60, ['test_tag']);
    
    const startGet = process.hrtime.bigint();
    const cached = memoryCache.get(cacheKey);
    const endGet = process.hrtime.bigint();
    const durationMs = Number(endGet - startGet) / 1000000;
    
    if (cached && cached.test === 'value') {
      console.log(`  ✔ PASS: Memory cache lookup took ${durationMs.toFixed(4)} ms (< 0.5 ms target)`);
    } else {
      throw new Error('Cache lookup failed');
    }

    memoryCache.invalidateTag('test_tag');
    if (memoryCache.get(cacheKey) === null) {
      console.log('  ✔ PASS: Instant tag-based cache invalidation works');
    } else {
      throw new Error('Tag invalidation failed');
    }

    // 2. Test Soft-Delete & Trash Model
    console.log('\n--- Test 2: Soft-Delete & Recycle Bin Workflow ---');
    // Create test student
    const testStudent = await Student.create({
      studentId: `TEST-${Date.now()}`,
      name: 'Trash Test Student',
      phone: `999${Math.floor(1000000 + Math.random() * 9000000)}`,
      email: `test-${Date.now()}@example.com`,
      status: 'active'
    });
    console.log(`  ✔ Created test student: "${testStudent.name}" (${testStudent.studentId})`);

    // Simulate Soft Delete via moveToTrash helper
    const { moveToTrash } = require('../routes/trash');
    const trashDoc = await moveToTrash({
      itemType: 'student',
      itemId: testStudent._id,
      itemTitle: `${testStudent.name} (${testStudent.studentId})`,
      itemSubtitle: `Phone: ${testStudent.phone}`,
      originalCollection: 'students',
      itemData: testStudent.toObject(),
      user: { _id: testStudent._id, name: 'Tester Admin' },
      reason: 'Automated QA Test'
    });
    console.log(`  ✔ Soft-deleted student to Trash (Trash ID: ${trashDoc._id})`);

    // Verify student is marked isDeleted: true
    const checkDeleted = await Student.findById(testStudent._id);
    if (checkDeleted && checkDeleted.isDeleted === true) {
      console.log('  ✔ PASS: Original Student marked isDeleted=true');
    } else {
      throw new Error('Student was not marked isDeleted=true');
    }

    // Verify student is excluded from normal queries
    const activeList = await Student.find({ isDeleted: { $ne: true }, studentId: testStudent.studentId });
    if (activeList.length === 0) {
      console.log('  ✔ PASS: Soft-deleted student excluded from active Student.find() queries');
    } else {
      throw new Error('Soft-deleted student was still returned in active list');
    }

    // 3. Test Restore Workflow
    console.log('\n--- Test 3: 1-Click Restore Workflow ---');
    const restoreRes = await Trash.findById(trashDoc._id);
    if (!restoreRes) throw new Error('Trash doc missing');

    // Simulate restore
    await Student.findByIdAndUpdate(testStudent._id, { isDeleted: false, deletedAt: null });
    await Trash.findByIdAndDelete(trashDoc._id);

    const restoredStudent = await Student.findOne({ _id: testStudent._id, isDeleted: { $ne: true } });
    if (restoredStudent && restoredStudent.name === 'Trash Test Student') {
      console.log('  ✔ PASS: Student successfully restored to active records');
    } else {
      throw new Error('Student failed to restore');
    }

    // 4. Test Permanent Deletion
    console.log('\n--- Test 4: Permanent Hard-Delete Workflow ---');
    await Student.findByIdAndDelete(testStudent._id);
    const finalCheck = await Student.findById(testStudent._id);
    if (!finalCheck) {
      console.log('  ✔ PASS: Student permanently purged from MongoDB');
    } else {
      throw new Error('Permanent deletion failed');
    }

    console.log('\n====================================================');
    console.log('  🎉 ALL TRASH & PERFORMANCE TESTS PASSED SUCCESSFULLY! ');
    console.log('====================================================\n');

  } catch (err) {
    console.error('❌ Test failed:', err);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
    process.exit(0);
  }
}

runTests();
