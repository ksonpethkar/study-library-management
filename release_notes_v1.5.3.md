## Cozy Corner Study Library v1.5.3 (Build 10) 🚀

### 🌟 What's New in This Release

#### 📊 Revenue & Financial Analytics
- **Executive Revenue Dashboard**: Track total collections, monthly diffs, and historical financial performance.
- **Breakdown Analytics**: Visual proportional charts for revenue by subscription plan and payment mode breakdown.
- **Recent Receipts Ledger**: Live list of the 10 most recent fee payments with instant verification.

#### ⚡ Android Home Screen Long-Press Shortcuts
- **Admin Shortcuts**: 1-tap launcher access to *Add Student*, *Record Payment*, *Scan QR*, and *Announcements*.
- **Student Shortcuts**: Direct access to *My Membership* and *My ID Card*.

#### 🔔 Proactive Notifications & Badges
- **Offline Scheduled Expiry Alarms**: Guaranteed reminder notifications at 3 days, 1 day, and on expiry morning—works completely offline and survives device restarts.
- **Dynamic App Icon Badges**: Real-time counter of pending student registration requests right on the launcher icon.

#### 🧾 Sequential Numbering & Audit Integrity
- **Atomic Sequential Receipts**: `REC-0001` format generated via atomic Firestore transactions, preventing number collisions.
- **Sequential Student Membership IDs**: `CC20260001` format customized with your organization prefix.
- **Comprehensive Audit Trail**: Security audit logging across student edits, receipt generation, seat allocations, and plan changes.

#### 👥 Advanced Student Management
- **Student Bulk Operations**: Multi-select mode on student list to deactivate, export structured CSV records, or send WhatsApp notifications.
- **Temporary Student Suspension / Block**: Moderation control to temporarily lock out students with documented reason while holding their seat.
- **Dynamic Payment History**: Full student payment history view detailing every transaction and total fees paid.

#### 🖨️ Seating & Customization
- **Printable Seating Chart PDF**: High-resolution, section-wise wall charts showing student allocations and occupancy colors.
- **Custom Form Fields Everywhere**: Extra fields configured in Form Customizer now show on Student Profiles, Digital ID passes, and ID Card PDFs.
- **Section Type Badges**: Distinguish AC Zones ❄️, Window seats 🪟, and Premium zones 🌟 with visual chips.
- **Firebase Remote Config**: 15 live feature toggles configurable from Firebase Console without app updates.

---

### 📦 APK Downloads
- **Primary ARM64 APK**: `StudyLibrary.apk` (Recommended for 99% of modern Android devices)
- **Universal / 32-bit APK**: `app-armeabi-v7a-release.apk`
- **Emulator / x86_64 APK**: `app-x86_64-release.apk`
