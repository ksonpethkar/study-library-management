# Cozy Corner — Agent Build & Modification Master Guidelines

> [!IMPORTANT]
> These rules are STRICT and MANDATORY for all builds, code modifications, bug fixes, and feature additions. They are derived directly from real production issues and historical bug reports to prevent any regression from ever repeating.

---

## 1. Strictly Forbidden Features & Architectural Constraints
DO NOT propose, implement, or wire any of the following into this system:
1. **NO Shifts or Shift Swapping:** Cozy Corner operates strictly on dedicated 24x7 or assigned desk reservations. Never introduce morning/afternoon shift toggles or peer-to-peer swap workflows.
2. **NO Streaks, Karma, or Gamification:** No study streaks, reward badges, leaderboards, or point systems.
3. **NO Google Wallet Passes:** ID cards are hosted natively in the app and downloadable as high-resolution printable PDFs/images; do not introduce Google Wallet API dependencies.
4. **NO Mobile SMS OTP Verification:** Authentication and onboarding use Email/Password and Admin-assisted onboarding only. Do not add third-party SMS OTP gateways.
5. **NO Attendance Check-in / Check-out Wiring:** Completely removed from all screens, providers, and background services. Do not re-add attendance toggles or check-in listeners.

---

## 2. Database, Querying & Firestore Index Safety
Derived from past index crash: `"The query requires a COLLECTION_ASC index for collection students and field userId"`.
1. **Zero-Index Direct Primary-Key Lookups:**
   - Always query single entities (e.g. current student, library settings) using `.doc(id).snapshots()` rather than collection-wide `.where(...)` queries whenever the document ID is known or cached in `SharedPreferences`.
2. **Never Disable `COLLECTION` Scope in `firestore.indexes.json`:**
   - When adding `COLLECTION_GROUP` overrides, NEVER omit the `{ "order": "ASCENDING", "queryScope": "COLLECTION" }` and `{ "order": "DESCENDING", "queryScope": "COLLECTION" }` definitions for core fields (`userId`, `email`, `phone`).
3. **Atomic Transactions for Seat Allocation:**
   - Prevent race conditions when two counter staff assign a seat at the same second: always wrap seat status changes in `FirebaseFirestore.instance.runTransaction()`.
4. **No Raw Firebase Exception Dumps:**
   - Never display raw database exception traces (e.g. index URLs, internal error codes) directly on user-facing widgets. Wrap stream and future errors in clean, friendly retry cards using `AppErrorFormatter`.
5. **Multi-Tenant Library Isolation:**
   - Every read and write to subcollections or library assets must be strictly scoped to `libraries/{libraryId}`.

---

## 3. Asynchronous Stream Resilience & Lifecycle (No Session Eviction)
Derived from past bug: *Students refreshed and were immediately logged out or trapped in a loading loop*.
1. **Never Evict Users on Initial Null Frame:**
   - In `student_home_screen.dart` and auth wrappers, NEVER call `signOut()` or redirect to `/login` inside `addPostFrameCallback` simply because a Riverpod `AsyncValue` is in loading state or emitted `null` before Firestore syncs.
2. **Graceful Loading & Manual Retry:**
   - If user data is resolving, render a stable "Connecting to your dashboard..." card with a manual "Retry Connection" button, allowing at least a 10-second grace window for slow 3G/4G networks.
3. **Stream Fallback Providers:**
   - If a stream provider fails or encounters network degradation, fall back to cached local `SharedPreferences` state without crashing the screen.
4. **Offline ID Pass & Barcode Availability:**
   - The student's digital ID card, barcode, seat number, and validity dates must be cached in local storage so students can enter the library even during internet/broadband outages.

---

## 4. Mobile Screen Layout, Overflow & Viewport Standards
Derived from past bugs: *RenderFlex overflows on small devices, dialog buttons clipped, keyboard obscuring inputs, vertical scroll cut-off*.
1. **Zero RenderFlex Overflow Tolerance:**
   - Never use fixed widths or unconstrained horizontal rows for action buttons or headers.
   - Always wrap action buttons in `Wrap(spacing: 8, runSpacing: 8)` or `FittedBox(fit: BoxFit.scaleDown)`.
   - In `Row` widgets, wrap variable-length text in `Expanded` or `Flexible` with `overflow: TextOverflow.ellipsis`.
2. **Mobile Form Scrolling & Keyboard Behavior:**
   - Every form must use `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag` so the virtual keyboard does not block submit buttons or inputs.
3. **No Bottom Viewport Clipping:**
   - All scroll views with bottom action buttons must provide bottom padding (`EdgeInsets.only(bottom: 80 + MediaQuery.of(context).padding.bottom)`) to prevent bottom navigation bars or FABs from hiding options.
4. **Text Scaling Clamping:**
   - Protect layouts against accessibility text scaling > 1.5x using `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3)`.
5. **Memory-Safe Image Rendering:**
   - Never load uncompressed base64 photo strings or raw network images directly into high-density lists or ID cards.
   - Always wrap in `CachedNetworkImage` and use `ResizeImage` downsampling (e.g., max 256x256 for avatars) to prevent Android out-of-memory (OOM) crashes and scrolling jank.

---

## 5. Mobile Hardware Back-Button & Route Navigation Safety
Derived from past bug: *Pressing Android physical back button on inner screens exited the app completely*.
1. **Resilient Pop Scope:**
   - Every secondary or inner screen (ID Card, Settings, Feedback, Receipts, Holidays, Announcements, Edit Student) must implement resilient back handling:
     ```dart
     if (context.canPop()) {
       context.pop();
     } else {
       context.go(Routes.home); // or Routes.studentHome
     }
     ```
2. **Web Routing & Base Href:**
   - Web builds must always be compiled with `--base-href /app/`.
   - Never create recursive redirects in `firebase.json` (e.g. `/app` -> `/app/` loops).
   - Maintain route aliases (`/login` and `/app/login`) and a fallback `NotFoundScreen`.

---

## 6. Dual-Portal Feature Parity & Dynamic Settings Synchronization
Derived from past bugs: *Typography settings existed for Admin but missing for Students; ID card template changes in Admin did not show on Student passes*.
1. **User Personalization Parity:**
   - Any accessibility, typography, font-scale, or dark/light theme setting available to Admin must have equivalent parity in the Student Portal (`MyProfileScreen`).
2. **Single Source of Truth for Dynamic Layouts:**
   - Both Admin preview screens and Student-facing screens (such as ID cards and Receipts) must consume the exact same Firestore stream settings (`ref.watch(idCardTemplateStreamProvider)`).
3. **Bilingual Requirement:**
   - All legal agreements, rules, Terms of Service, and Privacy Policies must be available in both English and Marathi (मराठी) with dual-language tab switching.

---

## 7. Android Binary Build, 64-Bit Architecture & OTA Discipline
1. **64-bit ARM (`arm64-v8a`) as Primary Production Binary:**
   - Make the lean **54.5 MB** 64-bit APK (`StudyLibrary-arm64-v8a.apk`) the primary default download. 96%+ of active Android devices in 2026 run 64-bit OS.
   - Retain a secondary legacy 32-bit (`armeabi-v7a`, 47 MB) download link on the portal for vintage budget devices.
2. **Identical Release Signing Keystore:**
   - All production APKs and App Bundles must be signed with the permanent release keystore (`upload-keystore.jks`). Never use debug or regenerated keys, or in-app OTA updates will fail with `"Package conflicts with an existing package"`.
3. **Synchronized Version Manifest (`update.json`):**
   - Whenever a new version is released, synchronize `pubspec.yaml`, `update.json`, GitHub Releases CDN, and Firebase download landing page in a single commit.
4. **Web Cache Busting:**
   - Always update cache-busting timestamps in `public/app/index.html` and invoke service worker eviction to prevent browsers from serving stale cached JavaScript bundles.

---

## 8. Unspoken but Critical Production Safeguards (Operator Best Practices)
1. **Automated WhatsApp Renewal Notification Fallback:**
   - Indian OEM Android skins (MIUI, ColorOS, FunTouchOS) aggressively kill background FCM push notifications.
   - For all critical lifecycle events (Membership expiring in 3 days, Payment receipt ready, Desk reassignment), always provide a 1-tap WhatsApp deep-link (`https://wa.me/...`) so reminders are guaranteed to be delivered.
2. **Counter Tablet Auto-Lock PIN (Data Privacy):**
   - When the library admin/receptionist steps away from the counter, the admin tablet must auto-lock after 3 minutes of inactivity to protect student Aadhaar, phone numbers, and financial drawer records from visiting students.
3. **Receipt Voiding on Payment Rollback:**
   - If a payment is refunded or cancelled, the PDF receipt record must be marked `status: 'cancelled'` in Firestore to prevent students from using invalid downloaded PDFs as proof of active membership.
4. **Aadhaar Data Masking Compliance:**
   - In accordance with UIDAI best practices, only display the last 4 digits (`XXXX-XXXX-1234`) on screens, ID cards, and receipts. Store identity document images strictly in private, role-restricted Firebase Storage buckets.
5. **Daily Database Backup (Disaster Recovery):**
   - Scheduled export of core collections (`students`, `payments`, `libraries`) to ensure complete zero-data-loss recovery.

---

## 9. Continuous Learning & Auto-Rule Appending Rule
- Whenever the user reports a bug, layout glitch, broken button, or operational requirement in chat:
  1. Immediately record the root cause and guardrail in this `GEMINI.md` file.
  2. Add an automated regression test to `test/system_qa_test.dart`.
  3. Verify with `flutter analyze` and `flutter test` before completing the turn.

---

## 10. Master Module Wiring & Desk Format Guardrails (Learned Nov 2026)
1. **Centralized Desk Label Formatting (`SeatHelper.formatDeskLabel`):**
   - Root Cause: Multiple widgets were prefixing `'Desk #' + SeatHelper.formatSeatLabel(...)` where `formatSeatLabel` already produced `#35` or `Seat #35`, creating recursive double prefixes like `'Desk #Seat #35'` or `'Desk ##35'`.
   - Guardrail: NEVER concatenate `'Desk #' + ...`. Always invoke `SeatHelper.formatDeskLabel(seatId: ..., rawLabel: ...)` or `SeatHelper.formatSeatNumberOnly(...)`. `SeatHelper.formatSeatLabel` uses an iterative stripping loop to ensure legacy database strings containing nested prefixes (e.g., `'Desk #Seat #35'`) are cleanly reduced to the bare seat identifier.
2. **Web Cache Busting & Service Worker Synchronization:**
   - Always synchronize `<script src="/app/flutter_bootstrap.js?v=..." async></script>` in `study_library/web/index.html` and `public/app/index.html` on each deployment to force browser service workers to evict stale cached JavaScript bundles.
3. **Announcements Repository & Dynamic Student Notice Board:**
   - Always route announcements through `AnnouncementsRepository` and `announcementsStreamProvider`.
   - The student portal Notice Board must dynamically display unread badge counts via `unreadAnnouncementsCountProvider(studentId)`.
4. **Cross-Collection Global Search:**
   - Search across students, plans, announcements, desks, and payments via `SearchRepository.searchAll` with a 300ms debounce timer to prevent Firestore query spikes.
5. **Settings Dynamic Streams:**
   - Settings for ID cards, receipts, grace periods, communications, and legal terms must use shared `StreamProvider`s in `settings_provider.dart` to maintain strict dual-portal parity between Admin and Student applications.

---

## 11. GitHub Releases & APK CDN Distribution Safeguard (Learned Nov 2026)
1. **GitHub Release Publication Guardrail:**
   - Root Cause: Version `v1.5.58` was tagged and `update.json` was updated pointing to GitHub release asset URLs (`.../releases/download/v1.5.58/StudyLibrary-arm64-v8a.apk`), but the GitHub release was not created or binaries were not uploaded. This caused users downloading the APK from the portal to hit a GitHub 404 error page.
   - Guardrail: Never push a version manifest (`update.json`) pointing to a GitHub release tag before creating the GitHub release and uploading all 4 assets (`StudyLibrary-arm64-v8a.apk`, `StudyLibrary-armeabi-v7a.apk`, `StudyLibrary.apk`, and `StudyLibrary.aab`) via `gh release create <tag> ...`. Always verify download URL health (`HTTP 200 OK`) prior to deploying hosting.

---

## 12. Unified Quick Control Hub & Instant Screen Lock Discipline (Learned Nov 2026)
1. **Top-Bar De-Cluttering & Consolidation:**
   - Root Cause: Multiple loose action buttons in the top app bar (Theme toggle, Search, Notifications, Sync, Lock) caused mobile header crowding and RenderFlex overflow on viewports < 360px.
   - Guardrail: Consolidate utilities into the unified `QuickControlCenterSheet` (`Icons.tune_rounded`). The top app bar must keep only the high-priority live notification bell and the quick control hub button.
2. **Zero-Latency Instant Screen Lock:**
   - Root Cause: Staff stepping away from counter or students stepping away from desks lacked a 1-tap lock mechanism to immediately shield Aadhaar, fees, and pass data from nearby onlookers.
   - Guardrail: Tapping Instant Lock in `QuickControlCenterSheet`, Admin settings, or Student profile must immediately check `BiometricService.isLockEnabled()`, set `InactivityLockService.setLocked(true)`, and route to `Routes.biometricLock` with zero confirmation delay. If unconfigured, prompt to set up a 4-digit PIN in `SecuritySettingsDialog` without locking the user out.
