/**
 * Automated Cloud & Local Backup Service
 * Study Library Management System
 */

const fs = require('fs');
const path = require('path');
const https = require('https');
const mongoose = require('mongoose');

const BACKUP_DIR = path.join(__dirname, '..', 'backups');
const MAX_BACKUP_RETENTION = 7; // Keep last 7 daily snapshots

class BackupService {
  constructor() {
    this.ensureBackupDir();
  }

  ensureBackupDir() {
    try {
      if (!fs.existsSync(BACKUP_DIR)) {
        fs.mkdirSync(BACKUP_DIR, { recursive: true });
      }
    } catch (e) {
      console.warn('[BackupService] Could not create backup directory:', e.message);
    }
  }

  /**
   * Generates a full system snapshot JSON
   */
  async generateSnapshotData() {
    const Student = require('../models/Student');
    const Seat = require('../models/Seat');
    const Plan = require('../models/Plan');
    const Payment = require('../models/Payment');
    const Attendance = require('../models/Attendance');
    const Expense = require('../models/Expense');
    const Locker = require('../models/Locker');
    const Shift = require('../models/Shift');
    const Branch = require('../models/Branch');
    const BusinessProfile = require('../models/BusinessProfile');
    const SystemSetting = require('../models/SystemSetting');

    const [
      businessProfile,
      systemSettings,
      branches,
      shifts,
      plans,
      seats,
      students,
      payments,
      attendances,
      expenses,
      lockers
    ] = await Promise.all([
      BusinessProfile.getProfile().then(p => [p]).catch(() => []),
      SystemSetting.find().lean().maxTimeMS(4000).catch(() => []),
      Branch.find().lean().maxTimeMS(4000).catch(() => []),
      Shift.find().lean().maxTimeMS(4000).catch(() => []),
      Plan.find().lean().maxTimeMS(4000).catch(() => []),
      Seat.find().lean().maxTimeMS(4000).catch(() => []),
      Student.find().sort({ createdAt: -1 }).limit(10000).lean().maxTimeMS(4000).catch(() => []),
      Payment.find().sort({ paymentDate: -1 }).limit(20000).lean().maxTimeMS(4000).catch(() => []),
      Attendance.find().sort({ date: -1 }).limit(10000).lean().maxTimeMS(4000).catch(() => []),
      Expense.find().sort({ createdAt: -1 }).limit(5000).lean().maxTimeMS(4000).catch(() => []),
      Locker.find().lean().maxTimeMS(4000).catch(() => [])
    ]);

    return {
      version: '3.0.0',
      exportedAt: new Date().toISOString(),
      metadata: {
        studentsCount: students.length,
        paymentsCount: payments.length,
        attendanceCount: attendances.length,
        seatsCount: seats.length
      },
      businessProfile,
      systemSettings,
      branches,
      shifts,
      plans,
      seats,
      students,
      payments,
      attendances,
      expenses,
      lockers
    };
  }

  /**
   * Creates a backup file on disk and optionally dispatches to Telegram
   */
  async createBackup(trigger = 'manual') {
    this.ensureBackupDir();
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const filename = `studylib_backup_${timestamp}.json`;
    const filePath = path.join(BACKUP_DIR, filename);

    try {
      console.log(`[BackupService] Starting backup (${trigger})...`);
      const snapshot = await this.generateSnapshotData();
      const content = JSON.stringify(snapshot, null, 2);

      fs.writeFileSync(filePath, content, 'utf8');
      const stats = fs.statSync(filePath);
      const sizeMB = (stats.size / (1024 * 1024)).toFixed(2);
      console.log(`[BackupService] Snapshot saved: ${filename} (${sizeMB} MB)`);

      // Rotate local backups (keep latest MAX_BACKUP_RETENTION)
      await this.rotateBackups();

      // Optional Telegram Cloud Dispatch
      const telegramResult = await this.dispatchToTelegram(filePath, filename, snapshot.metadata);

      return {
        success: true,
        filename,
        path: filePath,
        sizeBytes: stats.size,
        sizeMB,
        metadata: snapshot.metadata,
        telegramDispatched: telegramResult.dispatched,
        exportedAt: snapshot.exportedAt
      };
    } catch (err) {
      console.error('[BackupService] Backup creation failed:', err);
      throw err;
    }
  }

  /**
   * Delete older backups exceeding retention count
   */
  async rotateBackups() {
    try {
      const files = fs.readdirSync(BACKUP_DIR)
        .filter(f => f.startsWith('studylib_backup_') && f.endsWith('.json'))
        .map(f => ({
          name: f,
          path: path.join(BACKUP_DIR, f),
          time: fs.statSync(path.join(BACKUP_DIR, f)).mtime.getTime()
        }))
        .sort((a, b) => b.time - a.time);

      if (files.length > MAX_BACKUP_RETENTION) {
        const toDelete = files.slice(MAX_BACKUP_RETENTION);
        for (const file of toDelete) {
          try {
            fs.unlinkSync(file.path);
            console.log(`[BackupService] Rotated old backup: ${file.name}`);
          } catch (delErr) {
            console.warn('[BackupService] Error deleting old backup:', delErr.message);
          }
        }
      }
    } catch (e) {
      console.warn('[BackupService] Backup rotation skipped:', e.message);
    }
  }

  /**
   * Dispatches backup file to Telegram Bot if credentials are configured
   */
  async dispatchToTelegram(filePath, filename, metadata) {
    const SystemSetting = require('../models/SystemSetting');
    let botToken = process.env.TELEGRAM_BOT_TOKEN;
    let chatId = process.env.TELEGRAM_CHAT_ID;

    if (!botToken || !chatId) {
      try {
        botToken = await SystemSetting.getSetting('notifications.telegramBotToken');
        chatId = await SystemSetting.getSetting('notifications.telegramChatId');
      } catch (e) {}
    }

    if (!botToken || !chatId) {
      return { dispatched: false, reason: 'Telegram credentials not configured' };
    }

    try {
      const fileBuffer = fs.readFileSync(filePath);
      const boundary = '----StudyLibBoundary' + Date.now().toString(16);

      const caption = `📚 *Study Library Automated Cloud Backup*\n` +
        `📅 Date: ${new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' })}\n` +
        `👥 Students: ${metadata.studentsCount}\n` +
        `💳 Payments: ${metadata.paymentsCount}\n` +
        `💺 Desks: ${metadata.seatsCount}`;

      // Multipart form data payload construction
      let body = '';
      body += `--${boundary}\r\n`;
      body += `Content-Disposition: form-data; name="chat_id"\r\n\r\n${chatId}\r\n`;
      body += `--${boundary}\r\n`;
      body += `Content-Disposition: form-data; name="caption"\r\n\r\n${caption}\r\n`;
      body += `--${boundary}\r\n`;
      body += `Content-Disposition: form-data; name="parse_mode"\r\n\r\nMarkdown\r\n`;
      body += `--${boundary}\r\n`;
      body += `Content-Disposition: form-data; name="document"; filename="${filename}"\r\n`;
      body += `Content-Type: application/json\r\n\r\n`;

      const bodyEnd = `\r\n--${boundary}--\r\n`;
      const fullBuffer = Buffer.concat([
        Buffer.from(body, 'utf8'),
        fileBuffer,
        Buffer.from(bodyEnd, 'utf8')
      ]);

      const res = await fetch(`https://api.telegram.org/bot${botToken}/sendDocument`, {
        method: 'POST',
        headers: {
          'Content-Type': `multipart/form-data; boundary=${boundary}`,
          'Content-Length': fullBuffer.length
        },
        body: fullBuffer
      });

      const resData = await res.json().catch(() => ({}));
      if (res.ok && resData.ok) {
        console.log('[BackupService] ✅ Backup dispatched to Telegram successfully');
        return { dispatched: true };
      } else {
        console.warn('[BackupService] Telegram dispatch returned error:', resData.description || res.statusText);
        return { dispatched: false, reason: resData.description };
      }
    } catch (err) {
      console.warn('[BackupService] Telegram dispatch failed:', err.message);
      return { dispatched: false, reason: err.message };
    }
  }

  /**
   * List all stored backup files
   */
  listBackups() {
    this.ensureBackupDir();
    try {
      return fs.readdirSync(BACKUP_DIR)
        .filter(f => f.startsWith('studylib_backup_') && f.endsWith('.json'))
        .map(f => {
          const stats = fs.statSync(path.join(BACKUP_DIR, f));
          return {
            filename: f,
            sizeBytes: stats.size,
            sizeMB: (stats.size / (1024 * 1024)).toFixed(2),
            createdAt: stats.birthtime || stats.mtime
          };
        })
        .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    } catch (e) {
      return [];
    }
  }
}

module.exports = new BackupService();
