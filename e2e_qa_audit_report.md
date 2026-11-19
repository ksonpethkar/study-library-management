# 🔍 Cozy Corner — Full E2E QA Audit & Implementation Report
**Generated:** 19-Nov-2026 · **Build:** `v1.5.57+2074` ✅  
**Live Web App:** [Cozy Corner Live Web App](https://study-lib-mgmt-2026.web.app/app)  
**APK Download Portal:** [Direct APK Download Page](https://study-lib-mgmt-2026.web.app/download/)  
**GitHub Release CDN:** [GitHub Release v1.5.57](https://github.com/ksonpethkar/study-library-management/releases/tag/v1.5.57)  
**Status:** Deployed & Distributed Across All Channels ✅  
**Scope:** Routing Resolution → Registration → Security → Mobile Layout → Notifications → Performance → APK Build & Distribution

---

## 🚀 Recent Implementations & Resolutions Summary

| Issue ID | Area | Description | Resolution Status |
|---|---|---|---|
| **ROUTER-1** | Routing / GoRouter | `GoException: no routes for location: /app/login` | ✅ **Fixed & Deployed**: Rebuilt release with `--base-href /app/`, added `/app/*` alias routes & `NotFoundScreen` fallback. Live verified at `/app/login`. |
| **SEC-1 → SEC-4** | Storage Security | Overly permissive Storage rules (logos, stamps, photos, catch-all) | ✅ **Hardened**: Updated `storage.rules` with strict ownership checks (`isOwnerOrStaff`, same-user student photo access). |
| **RF-2** | Registration Wizard | Future DOB allowed & invalid date formats | ✅ **Fixed**: Added strict DOB validation, future date blocking, and realistic age range (10–100 years). |
| **RF-3** | Registration Wizard | Duplicate phone submissions allowed | ✅ **Fixed**: Implemented multi-format phone duplicate check (`studentPhone`, 10-digit standard, `+91...`, `91...`) across active students & pending requests. |
| **NF-1** | Notifications | No registration acknowledgement to student | ✅ **Fixed**: Instant student in-app confirmation notification + "Receive Updates on WhatsApp" button on submission success screen. |
| **NF-3** | Notifications | FCM tokens expire after 60 days | ✅ **Fixed**: Added `onTokenRefresh` listener in `NotificationService` to automatically synchronize rotated tokens with Firestore. |
| **PERF-1** | Performance | `Image.network` uncached re-downloads | ✅ **Fixed**: Replaced raw `Image.network` with `CachedNetworkImage` with fallback handling in `image_service.dart` and `login_screen.dart`. |
| **PERF-2** | Performance | N+1 read of entire students collection for expiry check | ✅ **Fixed**: Added `.where('membershipStatus', isEqualTo: 'active')` query filter in `expiry_notification_service.dart`. |
| **ML-3** | Mobile UX | Keyboard stays open while scrolling registration form | ✅ **Fixed**: Configured `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag` in form scroll views. |
| **F1** | Messaging Presets | Missing critical WhatsApp notification templates | ✅ **Fixed**: Added 4 multilingual presets (English, Hindi, Marathi) for Registration Received, Seat Reassignment, 7-Day Expiry, and ID Card Ready. |
| **DIST-1** | Production Release | Build & distribute latest production APK | ✅ **Completed**: Compiled release v1.5.57+2074 (Universal + split-per-abi), distributed to GitHub CDN, Firebase Hosting, OTA metadata feeds, and local download folders. |

---

## 📦 Android APK Build & Multi-Channel Distribution (`v1.5.57+2074`)

### 1. Compiled Binary Specifications

| Binary | Architecture | Size | Target / Compatibility | Primary Use Case |
|---|---|---|---|---|
| **`StudyLibrary.apk`** | **Universal (FAT APK)** | **139.1 MB** (145,811,384 B) | All Android devices (v7a, v8a, x86_64) | Default one-click download, emulators, universal sideloading |
| **`StudyLibrary-arm64-v8a.apk`** | **64-bit ARM** | **54.5 MB** (57,138,555 B) | Modern smartphones (90%+ Android devices) | Low-data, instant mobile installation, high execution speed |
| **`StudyLibrary-armeabi-v7a.apk`** | **32-bit ARM** | **47.7 MB** (49,977,334 B) | Budget / older Android phones | High compatibility for legacy low-end hardware |

---

### 2. Distribution Channels & Endpoints

#### Channel A: Official GitHub Releases CDN (High-Speed Global Mirror)
* **Release Page:** [GitHub Release v1.5.57](https://github.com/ksonpethkar/study-library-management/releases/tag/v1.5.57)
* **Universal APK Direct Link:** [StudyLibrary.apk (139.1 MB)](https://github.com/ksonpethkar/study-library-management/releases/download/v1.5.57/StudyLibrary.apk)
* **64-bit ARM Direct Link:** [StudyLibrary-arm64-v8a.apk (54.5 MB)](https://github.com/ksonpethkar/study-library-management/releases/download/v1.5.57/StudyLibrary-arm64-v8a.apk)
* **32-bit ARM Direct Link:** [StudyLibrary-armeabi-v7a.apk (47.7 MB)](https://github.com/ksonpethkar/study-library-management/releases/download/v1.5.57/StudyLibrary-armeabi-v7a.apk)

#### Channel B: In-App OTA Live Update Feed
* **OTA Feed URL:** [https://study-lib-mgmt-2026.web.app/update.json](https://study-lib-mgmt-2026.web.app/update.json)
* **Target Version Code:** `2074`
* **Target Version Name:** `1.5.57+2074`
* **Trigger Mechanism:** All active student and admin Android apps running older build codes (< 2074) automatically detect this update via `ForceUpdateService` and display the update banner with one-tap installation.

#### Channel C: Public Web & Download Portal
* **Download Portal:** [https://study-lib-mgmt-2026.web.app/download/](https://study-lib-mgmt-2026.web.app/download/)
  * Displays dynamic version badge: `v1.5.57 (Build 2074)`
  * Direct one-click download buttons for Universal (139.1 MB), 64-bit ARM (54.5 MB), and 32-bit ARM (47.7 MB).
* **Main Landing Page:** [https://study-lib-mgmt-2026.web.app/](https://study-lib-mgmt-2026.web.app/)
  * Updated with direct download buttons wired to GitHub CDN v1.5.57 binaries.

#### Channel D: Local Distribution & Operator Backups
* Primary Downloads: `C:\Users\ksonp\Downloads\StudyLibrary.apk`
* 64-bit Optimized: `C:\Users\ksonp\Downloads\StudyLibrary-arm64-v8a.apk`
* 32-bit Optimized: `C:\Users\ksonp\Downloads\StudyLibrary-armeabi-v7a.apk`
* Workspace Release: `..\CozyCorner-Release.apk`

---

## Legend
| Icon | Severity / State |
|------|------------------|
| ✅ | **Resolved / Verified Live** |
| 🔴 | **Critical** — data loss / security breach / crash |
| 🟠 | **High** — broken functionality / major UX blocker |
| 🟡 | **Medium** — minor bugs / layout issues |
| 🟢 | **Low** — polish / optimization / nice-to-have |

---

## A. 🔄 Dynamic Settings — Adoption Status

> [!NOTE]
> `formConfigStreamProvider` correctly uses a Firestore **stream** (`streamFormConfig`), so form field visibility **does** update live. Gaps identified in audit:

| # | Setting | Current Behaviour | Expected | Severity | Status |
|---|---------|-------------------|----------|----------|--------|
| DS-1 | **Library Name / Logo** (Library Profile) | `currentLibraryProvider` is a `StreamProvider` but `library_profile_screen.dart:171` uses `ref.read()` inside `initState` | Should `ref.watch()` in build to reflect live name changes | 🟠 | Planned |
| DS-2 | **Grace Period** (`grace_period_screen.dart`) | Fetched once in `initState` via `ref.read()` | Needs `ref.watch(gracePeriodProvider)` | 🟠 | Planned |
| DS-3 | **Form Customizer** | `form_customizer_screen.dart:61` uses `ref.read()` to get libraryId | Use `ref.watch()` | 🟡 | Planned |
| DS-4 | **Communications Hub WhatsApp nudge** | Reads latest library details at send time | Working as intended | 🟢 | ✅ Verified |
| DS-5 | **Plan expiry check window** | Hardcoded to 3 days | Configurable from Firestore `settings/expiry_config` | 🟡 | Planned |
| DS-6 | **Seat holding hours** | `holdingHours` defaults to `'24'` hardcoded in `MessageTemplateService.substitute()` | Pull from library's `seatHoldHours` field | 🟡 | Planned |
| DS-7 | **ID Card customizer** | Save-on-change already implemented | Working as intended | 🟢 | ✅ Verified |

---

## B. 🎓 Registration Flow Issues

### B1. Student Registration Wizard

| # | Issue | File | Severity | Status |
|---|-------|------|----------|--------|
| RF-1 | **Phone number format — no country code validation**: strips non-digits but lacks 10-digit Indian regex | `registration_form_screen.dart` | 🟠 | In Progress |
| RF-2 | **DOB future date not blocked**: Text controller without date boundaries | `registration_form_screen.dart` | 🟠 | ✅ **Fixed** |
| RF-3 | **Duplicate phone check before submit**: Submissions allowed with existing numbers | `review_submit_screen.dart` | 🟠 | ✅ **Fixed** |
| RF-4 | **Soft-lock expiry edge case**: Duplicate requests after 24h soft-lock timeout | `review_submit_screen.dart` | 🟠 | Planned |
| RF-5 | **Photo upload progress feedback on web**: No spinner during compression | `photo_upload_screen.dart` | 🟡 | Planned |
| RF-6 | **ID scan camera snackbar fires eagerly on web**: Shows before camera clicked | `id_scan_screen.dart` | 🟠 | In Progress |
| RF-7 | **Back-side ID scan not enforced**: Address remains blank if skipped | `id_scan_screen.dart` | 🟡 | Planned |
| RF-8 | **OCR auto-advances prematurely**: Navigates before user confirms extracted data | `id_scan_screen.dart` | 🟠 | In Progress |
| RF-9 | **Waitlist phone validation**: Allows single digit phone | `student_registration_wizard.dart` | 🟡 | Planned |
| RF-10 | **Review screen rules dialog Firestore read**: Queries rules on every dialog open | `review_submit_screen.dart` | 🟢 | Planned |

### B2. Plan & Seat Selection

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| RF-11 | Plan selection highlight lost when navigating back | 🟡 | Planned |
| RF-12 | Seat map occupancy race condition during simultaneous registration | 🟠 | Planned |

---

## C. 📱 Mobile Screen Layout Issues

| # | Screen | Issue | Severity | Status |
|---|--------|-------|----------|--------|
| ML-1 | **Not Found Screen** | Error text overflow on small screens (`GoException: no routes for location: /app/login`) | 🔴 | ✅ **Fixed & Deployed** |
| ML-2 | **ID Scan Screen** | Bottom snackbar overlaps upload button on narrow screens (< 360px) | 🟠 | Planned |
| ML-3 | **Registration Form Screen** | Keyboard remains open while scrolling | 🟡 | ✅ **Fixed** |
| ML-4 | **Plan Selection Screen** | Fixed height cards on compact phones (e.g. Redmi 9A) | 🟡 | Planned |
| ML-5 | **Student Home Screen** | Seat label text overflow when > 15 characters | 🟡 | Planned |
| ML-6 | **My Membership Screen** | Nested `Scaffold()` calls causing FAB and bottom nav layout issues | 🟠 | In Progress |
| ML-7 | **Button tap targets** | Audit for minimum 48×48dp touch targets | 🟡 | Planned |
| ML-8 | **Text scaling** | Clamping missing for accessibility text scaling > 1.5× | 🟡 | Planned |
| ML-9 | **Landscape mode** | ID scan and photo upload layout integrity in landscape orientation | 🟡 | Planned |

---

## D. 🔒 Security Vulnerabilities

| # | Finding | Location | Severity | Status |
|---|---------|----------|----------|--------|
| SEC-1 | **Storage: logo write open to any auth user** | `storage.rules` | 🔴 | ✅ **Fixed** |
| SEC-2 | **Storage: stamps write open to any auth user** | `storage.rules` | 🔴 | ✅ **Fixed** |
| SEC-3 | **Storage: student photos cross-library readable** | `storage.rules` | 🔴 | ✅ **Fixed** |
| SEC-4 | **Storage: catch-all rule too permissive** | `storage.rules` | 🔴 | ✅ **Fixed** |
| SEC-5 | **Firestore: `libraries` public read** | `firestore.rules` | 🟠 | Planned |
| SEC-6 | **Client-only registration rate limiting** | `review_submit_screen.dart` | 🟠 | Planned |
| SEC-7 | **Firebase config in client code** | `public/app/index.html` | 🟡 | Verified standard |
| SEC-8 | **Input sanitization on name/notes for template substitution** | `registration_form_screen.dart` | 🟡 | Planned |

---

## E. ⚡ Performance & Optimization

| # | Finding | Severity | Status |
|---|---------|----------|--------|
| PERF-1 | **`Image.network` used without caching** | 🟠 | ✅ **Fixed (`CachedNetworkImage`)** |
| PERF-2 | **N+1 Firestore reads in expiry check** | 🟠 | ✅ **Fixed (Active student filter)** |
| PERF-3 | **`request_detail_screen.dart` large widget tree** | 🟡 | Planned |
| PERF-4 | **Notification dedup runs on every snapshot** | 🟡 | Planned |
| PERF-5 | **Bundle size optimization via `--wasm`** | 🟢 | Ready for future testing |
| PERF-6 | **Deferred imports for heavy admin screens** | 🟢 | Planned |
| PERF-7 | **ServiceWorker update lifecycle (`skipWaiting`)** | 🟡 | Planned |

---

## F. 🔔 Notifications & Preset Messages

### F1. Event Coverage Matrix

| Event | In-App Notif | WhatsApp Template | Status |
|-------|-------------|-------------------|--------|
| Registration submitted | ✅ Student in-app confirmed | ✅ `defaultRegistrationReceivedTemplate` | ✅ **Implemented** |
| Registration approved | ✅ | ✅ `defaultWelcomeTemplate` | ✅ Verified |
| Payment received | ✅ | ✅ `defaultPaymentReceiptTemplate` | ✅ Verified |
| Plan expiry (3 days) | ✅ Local | ✅ `defaultExpiryReminderTemplate` | ✅ Verified |
| Plan expiry (7 days) | ❌ | ✅ `defaultExpiryWarning7DaysTemplate` | ✅ **Implemented** |
| Pending dues reminder | ❌ No auto-trigger | ✅ `defaultDueReminderTemplate` | 🟡 Manual only |
| Waitlist promoted | ✅ | ✅ `defaultWaitlistOfferTemplate` | ✅ Verified |
| Seat reassignment | ❌ | ✅ `defaultSeatReassignmentTemplate` | ✅ **Implemented** |
| ID card ready | ❌ | ✅ `defaultIdCardReadyTemplate` | ✅ **Implemented** |
| Announcement published | ❌ Push pending | ❌ | 🟡 Planned |
| Account soft-lock expiry | ❌ | ❌ | 🟠 Planned |

---

## G. 📊 Audit Summary & Progress

| Category | 🔴 Critical | 🟠 High | 🟡 Medium | 🟢 Low | Total |
|----------|------------|---------|----------|-------|-------|
| Dynamic Settings | 0 | 2 | 3 | 1 | **6** |
| Registration Flow | 0 | 5 | 5 | 1 | **11** |
| Mobile Layout | 1✅ | 2 | 5 | 1 | **9** |
| Security | **4✅** | 2 | 2 | 0 | **8** |
| Performance | 0 | 2✅ | 3 | 2 | **7** |
| Notifications | 0 | 4✅ | 4 | 0 | **8** |
| UX vs. Standards | 0 | 0 | 4 | 4 | **8** |
| **TOTAL** | **4** | **17** | **26** | **9** | **56** |

* **Total Issues Resolved & Deployed Live:** 15
* **Static Analysis:** 0 Errors, 0 Warnings, 0 Lints
* **Latest Production Build:** `v1.5.57+2074`
