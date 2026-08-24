const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const Trash = require('../models/Trash');
const Student = require('../models/Student');
const Payment = require('../models/Payment');
const Expense = require('../models/Expense');
const Seat = require('../models/Seat');
const Plan = require('../models/Plan');
const Shift = require('../models/Shift');
const Branch = require('../models/Branch');
const Locker = require('../models/Locker');
const CustomField = require('../models/CustomField');
const Coupon = require('../models/Coupon');
const WaitingList = require('../models/WaitingList');
const AuditLog = require('../models/AuditLog');
const { protect } = require('../middleware/auth');
const { roleCheck } = require('../middleware/roleCheck');

// All Trash routes require authentication
router.use(protect);
router.use(roleCheck('owner', 'branch_manager', 'staff'));

// Map itemType to Mongoose Model
const MODEL_MAP = {
  student: Student,
  payment: Payment,
  expense: Expense,
  seat: Seat,
  plan: Plan,
  shift: Shift,
  branch: Branch,
  locker: Locker,
  custom_field: CustomField,
  coupon: Coupon,
  waiting_list: WaitingList
};

// Helper: Soft-delete an entity and create Trash snapshot
async function moveToTrash({ itemType, itemId, itemTitle, itemSubtitle, originalCollection, itemData, user, reason }) {
  try {
    // 1. Mark original document as isDeleted if model supports it
    const Model = MODEL_MAP[itemType];
    if (Model) {
      await Model.findByIdAndUpdate(itemId, {
        isDeleted: true,
        deletedAt: new Date(),
        deletedBy: user?._id
      });
    }

    // 2. Create Trash record
    const trashDoc = await Trash.create({
      itemType,
      itemId,
      itemTitle: itemTitle || 'Untitled Item',
      itemSubtitle: itemSubtitle || '',
      originalCollection: originalCollection || itemType,
      itemData: itemData || {},
      deletedAt: new Date(),
      deletedBy: user?._id,
      deletedByName: user?.name || 'Admin',
      deletionReason: reason || ''
    });

    // 3. Log Audit Trail
    try {
      if (AuditLog) {
        await AuditLog.create({
          user: user?._id,
          userName: user?.name || 'Admin',
          action: 'DELETE',
          module: 'TRASH',
          details: `Moved ${itemType} "${itemTitle}" to Recycle Bin`,
          ipAddress: 'System'
        });
      }
    } catch (e) {}

    return trashDoc;
  } catch (err) {
    console.error('Error moving item to trash:', err);
    throw err;
  }
}

// GET /api/trash - List deleted items with search, filters & pagination
router.get('/', async (req, res) => {
  try {
    const { type, search, page = 1, limit = 25 } = req.query;
    const query = {};

    if (type && type !== 'all') {
      query.itemType = type;
    }

    if (search && search.trim()) {
      const regex = new RegExp(search.trim(), 'i');
      query.$or = [
        { itemTitle: regex },
        { itemSubtitle: regex },
        { deletedByName: regex }
      ];
    }

    const pageNum = Math.max(1, parseInt(page, 10));
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10)));
    const skip = (pageNum - 1) * limitNum;

    const [items, total] = await Promise.all([
      Trash.find(query)
        .sort({ deletedAt: -1 })
        .skip(skip)
        .limit(limitNum)
        .lean(),
      Trash.countDocuments(query)
    ]);

    res.json({
      success: true,
      data: {
        items,
        total,
        page: pageNum,
        totalPages: Math.ceil(total / limitNum) || 1
      }
    });
  } catch (err) {
    console.error('Error fetching trash items:', err);
    res.status(500).json({ success: false, message: 'Failed to load recycle bin records' });
  }
});

// GET /api/trash/counts - Live category counts for badge tabs
router.get('/counts', async (req, res) => {
  try {
    const counts = await Trash.aggregate([
      {
        $group: {
          _id: '$itemType',
          count: { $sum: 1 }
        }
      }
    ]);

    const countsMap = { all: 0 };
    counts.forEach(c => {
      countsMap[c._id] = c.count;
      countsMap.all += c.count;
    });

    res.json({ success: true, data: countsMap });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/trash/restore/:id - Restore single deleted item
router.post('/restore/:id', async (req, res) => {
  try {
    const trashDoc = await Trash.findById(req.params.id);
    if (!trashDoc) {
      return res.status(404).json({ success: false, message: 'Trash item not found or already restored' });
    }

    const Model = MODEL_MAP[trashDoc.itemType];
    if (Model) {
      const existing = await Model.findById(trashDoc.itemId);
      if (existing) {
        // Unmark soft-delete
        existing.isDeleted = false;
        existing.deletedAt = undefined;
        existing.deletedBy = undefined;
        await existing.save();
      } else if (trashDoc.itemData) {
        // Recreate from snapshot
        const cleanData = { ...trashDoc.itemData };
        delete cleanData.isDeleted;
        delete cleanData.deletedAt;
        delete cleanData.deletedBy;
        await Model.create(cleanData);
      }
    }

    // Remove from Trash
    await Trash.findByIdAndDelete(trashDoc._id);

    // Audit Log
    try {
      if (AuditLog) {
        await AuditLog.create({
          user: req.user?._id,
          userName: req.user?.name || 'Admin',
          action: 'RESTORE',
          module: 'TRASH',
          details: `Restored ${trashDoc.itemType} "${trashDoc.itemTitle}" from Recycle Bin`,
          ipAddress: req.ip
        });
      }
    } catch (e) {}

    res.json({
      success: true,
      message: `"${trashDoc.itemTitle}" restored successfully!`
    });
  } catch (err) {
    console.error('Error restoring trash item:', err);
    res.status(500).json({ success: false, message: 'Failed to restore item: ' + err.message });
  }
});

// POST /api/trash/restore-bulk - Bulk restore multiple items
router.post('/restore-bulk', async (req, res) => {
  try {
    const { ids } = req.body;
    if (!Array.isArray(ids) || ids.length === 0) {
      return res.status(400).json({ success: false, message: 'No item IDs provided for restore' });
    }

    const trashDocs = await Trash.find({ _id: { $in: ids } });
    let restoredCount = 0;

    for (const doc of trashDocs) {
      const Model = MODEL_MAP[doc.itemType];
      if (Model) {
        const existing = await Model.findById(doc.itemId);
        if (existing) {
          existing.isDeleted = false;
          existing.deletedAt = undefined;
          existing.deletedBy = undefined;
          await existing.save();
        } else if (doc.itemData) {
          const cleanData = { ...doc.itemData };
          delete cleanData.isDeleted;
          delete cleanData.deletedAt;
          await Model.create(cleanData);
        }
      }
      await Trash.findByIdAndDelete(doc._id);
      restoredCount++;
    }

    res.json({
      success: true,
      message: `Successfully restored ${restoredCount} items from Recycle Bin`
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE /api/trash/permanent/:id - Hard Delete permanently with confirmation
router.delete('/permanent/:id', roleCheck('owner', 'branch_manager'), async (req, res) => {
  try {
    const trashDoc = await Trash.findById(req.params.id);
    if (!trashDoc) {
      return res.status(404).json({ success: false, message: 'Trash item not found or already deleted' });
    }

    // Permanently remove from underlying MongoDB collection
    const Model = MODEL_MAP[trashDoc.itemType];
    if (Model) {
      await Model.findByIdAndDelete(trashDoc.itemId);
    }

    // Remove from Trash collection
    await Trash.findByIdAndDelete(trashDoc._id);

    // Audit Log
    try {
      if (AuditLog) {
        await AuditLog.create({
          user: req.user?._id,
          userName: req.user?.name || 'Admin',
          action: 'HARD_DELETE',
          module: 'TRASH',
          details: `Permanently destroyed ${trashDoc.itemType} "${trashDoc.itemTitle}" from database`,
          ipAddress: req.ip
        });
      }
    } catch (e) {}

    res.json({
      success: true,
      message: `"${trashDoc.itemTitle}" has been permanently erased from the database.`
    });
  } catch (err) {
    console.error('Error permanently deleting item:', err);
    res.status(500).json({ success: false, message: 'Failed to permanently delete: ' + err.message });
  }
});

// DELETE /api/trash/empty - Purge all items in trash
router.delete('/empty', roleCheck('owner'), async (req, res) => {
  try {
    const { type } = req.query;
    const query = (type && type !== 'all') ? { itemType: type } : {};

    const docsToPurge = await Trash.find(query).lean();
    for (const doc of docsToPurge) {
      const Model = MODEL_MAP[doc.itemType];
      if (Model) {
        await Model.findByIdAndDelete(doc.itemId);
      }
    }

    const deleteRes = await Trash.deleteMany(query);

    // Audit Log
    try {
      if (AuditLog) {
        await AuditLog.create({
          user: req.user?._id,
          userName: req.user?.name || 'Owner',
          action: 'EMPTY_TRASH',
          module: 'TRASH',
          details: `Purged ${deleteRes.deletedCount} items permanently from Recycle Bin`,
          ipAddress: req.ip
        });
      }
    } catch (e) {}

    res.json({
      success: true,
      message: `Recycle Bin emptied. ${deleteRes.deletedCount} items permanently erased.`
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
module.exports.moveToTrash = moveToTrash;
