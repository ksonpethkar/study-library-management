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

---

## 13. Dynamic Features, Web Deployment & Direct Action Pairings (Learned Nov 2026)
1. **Mandatory Web Build & Firebase Hosting Deploy Pipeline:**
   - Root Cause: Source code fixes for desk labels (`SeatHelper.formatDeskLabel`) and 1-tap phone dialer buttons were committed and tested locally, but the production web application was not compiled and deployed to Firebase Hosting (`public/app`), causing live users to encounter stale cached bundles displaying `Desk #Seat #35` and missing call buttons.
   - Guardrail: After completing any UI or operational fix, always run `scripts/publish_web.ps1` (or `flutter build web --release --base-href /app/`, sync to `public/app`, inject loader, and `firebase deploy --only hosting`). Always update the cache-buster token `v=YYYYMMDD_XX` in `index.html` to force browser service workers to invalidate stale JavaScript bundles.
2. **Admission & Contact Cards 1-Tap Action Pairing:**
   - Root Cause: Online admission cards on the Students Screen (`_buildPendingAdmissionCard`) and request lists displayed only a WhatsApp chat button. Receptionists who needed to urgently contact applicants offline were forced to manually re-type phone numbers.
   - Guardrail: Every contact point must feature a paired 1-tap phone dialer button (`Icons.phone_outlined`, `tel:$clean`) adjacent to the WhatsApp button (`Icons.chat_bubble_outline`, `https://wa.me/...`).
3. **Student Outstanding Fee Dues Dynamic Resolution (`due_payment`):**
   - Root Cause: Outstanding fee balances (`student.pendingDueBalance > 0`) were displayed only as a passive text label on the back of the student ID pass, with no interactive mechanism to clear dues.
   - Guardrail: When `pendingDueBalance > 0`, render an interactive warning card above the smart pass on `StudentHomeScreen` offering:
     a) 1-tap UPI deep-link (`upi://pay?pa=$upiId&am=$due...`)
     b) Modal bottom sheet to submit UTR / Payment Proof (`type: 'due_payment'`).
     c) 1-tap approval in `RequestDetailScreen` that atomically decrements `pendingDueBalance` and logs a completed payment receipt.
4. **Registration Desk Collision Soft-Lock (5-Minute Cart Timer):**
   - Root Cause: Multiple applicants selecting desks at the same time could submit registrations for the same seat before counter review.
   - Guardrail: When a candidate selects an available seat in `SeatSelectionScreen`, immediately write a 5-minute soft-lock to Firestore (`status: 'reserved'`, `reservationType: 'registration_hold'`, `reservationExpiresAt: now + 5 min`). Desks under active soft-lock display an amber hold badge to other users and auto-unlock upon expiration.
5. **Offline ID Pass Styling Synchronization:**
   - Root Cause: Sudden internet disconnections caused ID card template customization streams to emit null/empty defaults, degrading ID pass styling.
   - Guardrail: Cache `IdCardTemplateSettings` in `SharedPreferences` (`cached_id_card_template_settings`) on every Firestore snapshot to guarantee 100% styled offline pass rendering.

---

## 14. Web Intrinsic Rendering, Modal Layouts, Dynamic Forms & Security Discipline (Learned Nov 2026)
1. **Web BottomSheet & LayoutBuilder Freeze Guardrail:**
   - Root Cause: `LayoutBuilder` + `Wrap` inside an unconstrained height modal (`showModalBottomSheet(isScrollControlled: true)`) triggered an infinite intrinsic dimension measurement loop in Flutter Web's CanvasKit/HTML engine, locking the JavaScript thread and causing Chrome's "This page isn't responding" freeze.
   - Guardrail: NEVER place `LayoutBuilder` or `Wrap` inside unconstrained vertical sheets. Construct multi-column grids using deterministic `Column`s containing bounded `Row`s with `Expanded` tiles. Always wrap modal content in `Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 540), child: ...))`.
2. **Modal Dialog In-Context Feedback Standard:**
   - Root Cause: PIN creation dialogs triggered snackbars via the dialog's context (`ctx`), displaying snackbars behind/underneath the modal dialog where users could not see errors or success messages.
   - Guardrail: Every modal dialog must provide inline error banners via `StatefulBuilder` and direct field error states. On success, show an inline animated green confirmation badge inside the dialog or parent sheet with auto-dismiss.
3. **Web Receipt Action Sheet & WhatsApp Link Protocol:**
   - Root Cause: On Flutter Web, `Printing.sharePdf` uses an anchor download tag, making "Download Receipt" and "Share Receipt" perform identical duplicate downloads without preview or WhatsApp sharing.
   - Guardrail: Deploy the unified `ReceiptActionSheet` providing:
     a) 1-tap WhatsApp deep link (`https://wa.me/?text=...`) containing full receipt metadata and verification link.
     b) Interactive in-app receipt preview (`ReceiptPreviewScreen`).
     c) Explicit PDF file download (`FileDownloadHelper.downloadFile`).
     d) 1-tap clipboard link copy.
4. **Multi-Alias Student Photo Persistence & Admin Avatar Controls:**
   - Root Cause: Student photos disappeared after sign-in because `users/{uid}` updates omitted `photoUrl`, `StudentModel.fromJson` lacked fallbacks (`photo`, `avatar`, `avatarUrl`, `profilePhoto`, `studentPhoto`), and `StudentDetailScreen` lacked photo upload triggers.
   - Guardrail: `StudentModel.fromJson` must parse all 11 photo key aliases. In `StudentDetailScreen`, tapping the student avatar must open an action sheet with "View Photo", "Change / Upload Photo" (`ImageService.pickAndUploadImage`), and "Remove Photo", with a visible camera edit badge.
5. **Preloaded Student Dossier Navigation Pattern:**
   - Root Cause: Opening a student detail dossier triggered a cold Firestore `.get()` query with library ID mismatches, causing "Student not found" or empty rosters.
   - Guardrail: `StudentDetailScreen` must accept `preloadedStudent`. Lists with students in memory must pass `preloadedStudent: student` in split-views and `extra: student` in router transitions to render dossiers instantaneously with 0ms delay.
6. **Form Builder Dynamic Field Enforcement:**
   - Root Cause: Customizations in `/app/admin/more` (Form Fields) were ignored because `add_student_screen.dart` and `edit_student_screen.dart` hardcoded fields.
   - Guardrail: All built-in student fields (`dob`, `gender`, `bloodGroup`, `email`, `address`, `pincode`, `emergencyContact`, `college`, `course`, `year`, `rollNumber`, `prep`) must dynamically check `FormConfigService.isFieldVisible(formFields, id)` and consume `FormConfigService.getFieldLabel(formFields, id, default)`.
7. **Inactivity Lock Route Preservation & Web Path Normalization:**
   - Root Cause: Inactivity timeouts routed to `Routes.biometricLock` without saving the current route, and Web base-href `/app/` prefixes broke route matching, forcing users to the home screen after every unlock.
   - Guardrail: Both `AdminShell` and `StudentShell` must persist the active URI to `last_active_route` before routing to lock. `BiometricLockScreen` must normalize `/app/` prefixes and restore the exact screen the user was on before lock.
8. **Receipt Template Dynamic Fallback & Elements Wiring:**
   - Root Cause: `PdfService.generateReceiptPdf` ignored template toggles (`Seat Number`, `Payment Method`, `receiptStyle`, `pageSize`), and `ReceiptPdfService` hardcoded `template: null`.
   - Guardrail: If `template` is null, `PdfService` must asynchronously fetch the active `receipt_template` settings from Firestore. All template toggles must be strictly respected.
9. **Autonomous Quality Watchdog System & Trust Architecture:**
   - Guardrail: To eliminate human error and unverified claims, all builds must undergo:
     a) Automated QA regression suite execution (`flutter test test/system_qa_test.dart`) covering every reported production bug.
     b) Static analysis verification (`flutter analyze` with 0 issues).
     c) Web compilation and deployment verification with cache-busting tokens.

---

## 15. OS Dialog Lifecycle Immunity, Inactivity Timer Floor & Safe Image Rendering (Learned Nov 2026)
1. **OS File Picker Lifecycle & Lockout Suppression (`InactivityLockService.isExternalDialogActive`):**
   - Root Cause: Clicking "Upload File" in "Add Student" opens the native OS File Explorer. On Flutter Web, window focus shifts to the OS dialog, firing `AppLifecycleState.inactive` or `resumed`. `BiometricService.shouldLockOnResume` checked `_lastPausedTime == null` and erroneously returned `true`, instantly kicking the user to the Lock Screen and erasing their half-filled form.
   - Guardrail: Wrap all native file/camera pickers in `InactivityLockService.setExternalDialogActive(true) ... finally { InactivityLockService.setExternalDialogActive(false); }`. During external dialog activity, all inactivity checks and lifecycle resumes are completely suppressed. Furthermore, `_lastPausedTime == null` MUST return `false` (never lock if the app was never placed in paused background).
2. **Auto-Lock "Immediately" Setting vs In-App Idle Conflation:**
   - Root Cause: Selecting "Immediately" (0 minutes) was applied to foreground in-app idle checks, causing the app to lock every 15 seconds even while the admin was actively viewing records. Moreover, resuming from a 1-second tab switch immediately locked the session without grace.
   - Guardrail:
     a) Foreground Inactivity Timer Floor: In `InactivityLockService._checkInactivity()`, floor the idle check to a minimum of 2 minutes when `timeoutMinutes == 0`.
     b) Background Grace Period: When `timeoutMinutes == 0` ("Immediately"), require at least 15 seconds in background before triggering the lock barrier, preventing locks on momentary window blur or OS dialog interactions.
3. **Pushed Lock Barrier & Form State Preservation:**
   - Root Cause: Lockouts executed `context.go(Routes.biometricLock)` which unmounted the current screen, destroying all unsaved form inputs in `AddStudentScreen` or `StudentDetailScreen`.
   - Guardrail: Trigger lock barriers using `context.push(Routes.biometricLock)` or `appRouterProvider.push`. On unlock, if `context.canPop()` is true, simply `context.pop()` to reveal the underlying screen with 100% of state, scroll, and form entries preserved.
4. **Empty Document Studio & Cross-Platform Web Image Safety:**
   - Root Cause: Clicking "Attach ID" for students with no ID passed an empty URL `""` to `AdminDocumentStudioDialog`. `ImageService.buildImageWidget` called `File(pathOrUrl).existsSync()` which threw an unhandled `Unsupported operation: _Namespace` exception on Flutter Web, crashing the dialog build and rendering an empty grey screen.
   - Guardrail: In `ImageService.buildImageWidget`, return a safe placeholder when `pathOrUrl.trim().isEmpty`, and wrap all `File(...)` checks in `if (!kIsWeb)`. In `AdminDocumentStudioDialog`, when no document is attached, display a clear "No Document Attached Yet" card with a 1-tap "Upload Front Side Document" button.

---

## 16. Request Provisioning Data-Type Cast Resilience & Partial Payment Dues Auto-Retention (Learned Nov 2026)
1. **Request Hub Provisioning Data Type Safety:**
   - Root Cause: Approving admissions in Requests Hub failed with a silent freeze or type cast exception because `data['studentData']` from Firestore Web is `_Map<Object?, Object?>` instead of `Map<String, dynamic>`.
   - Guardrail: Always cast nested Firestore objects with `(data['studentData'] as Map?)?.cast<String, dynamic>() ?? {}`. Use `?.toString()` for ID fields (`seatId`, `sectionId`, `planId`) and `(snap.data()?[...] as num?)?.toInt() ?? 0` for sequence counters. Provide inline `CircularProgressIndicator` on modal approval buttons so staff see active provisioning.
2. **Partial Payment Automatic Due Preservation & Detection:**
   - Root Cause: Staff collecting ₹30 cash at desk for a ₹230 prorated plan saw the ₹200 pending due erased because `remainingDue` was strictly gated behind a hidden manual switch `_isPartialPayment`. The receipt printed "Balance Due: ₹0.00 (Nil)" and student due balance cleared to ₹0.
   - Guardrail: In `RecordPaymentScreen` and `EditPaymentScreen`, automatically detect partial payments: `final remainingDue = (_isPartialPayment || _calculatedRemainingDue > 0) ? _calculatedRemainingDue : 0.0;` and `final bool isPartial = remainingDue > 0;`. If paid < total fee, display an amber warning container showing the exact due carried forward and persist `pendingDueBalance` on the student record.
3. **Direct Student Profile Due Adjustment:**
   - Guardrail: Provide a direct 1-tap dialog `_showAdjustDueDialog` in `StudentDetailScreen` header (`Due: ₹... (Edit)` / `Set Due`) and action menu so reception staff can immediately correct or adjust any student's outstanding due balance.

---

## 17. Dynamic Payment Settings Sync, Web BottomSheet Freeze Elimination & Registration State Isolation (Learned Nov 2026)
1. **Web BottomSheet Layout Loops & Freeze Elimination:**
   - Root Cause: Opening `QuickControlCenterSheet` using `Center(child: ...)` inside `showModalBottomSheet(isScrollControlled: true)` caused Flutter Web's CanvasKit layout engine to run an infinite intrinsic dimension loop, triggering Chrome's `"This page isn't responding"` popup.
   - Guardrail: Always wrap modal bottom sheets in `Align(alignment: Alignment.bottomCenter)` with bounded constraints (`maxWidth: 540, maxHeight: MediaQuery.of(context).size.height * 0.9`) and `SingleChildScrollView(physics: const ClampingScrollPhysics())`. Never use `Center` directly inside vertical scroll-controlled bottom sheets on Web.
2. **Dual-Portal Dynamic Payment Methods Synchronization:**
   - Root Cause: Toggling off payment modes (such as UPI) in Admin Settings was ignored on Student Home because the student portal checked `if (upiId.isNotEmpty)` rather than reading `paymentMethodsStreamProvider` or `library.enabledPaymentMethods`.
   - Guardrail: Student Home and clearance forms must dynamically consume `paymentMethodsStreamProvider` with fallback to `library.enabledPaymentMethods`. When an admin turns off UPI, the `[Pay via UPI]` button must disappear, and clearance forms must restrict dropdown options strictly to active methods (`Cash at Desk`, `Bank Transfer`, etc.).
3. **Applicant Registration State Isolation & Photo Carry-Over Prevention:**
   - Root Cause: Starting a new registration via `_startNewRegistration` did not invoke `.clear()` on `registrationNotifierProvider`, `ocrResultProvider`, and `selectedSeatProvider`. When one applicant uploaded a photo and another registered in the same session, leftover base64 photo strings in Riverpod state leaked into the new registration, overwriting profile photos.
   - Guardrail: Always call `.clear()` on `registrationNotifierProvider`, `ocrResultProvider`, `selectedSeatProvider`, and `selectedSeatDetailsProvider` immediately inside `_startNewRegistration` before pushing the wizard route.
4. **Request Hub Robust Cash Detection:**
   - Root Cause: Student due clearance submissions saved `paymentMode` while Request Details only read `paymentMethod`. When `paymentMethod` was empty, the request defaulted to a purple `[QR] UPI` badge even though the student paid cash.
   - Guardrail: In `RequestDetailScreen` and `RequestListScreen`, evaluate `isDeskCash` across `paymentMethod`, `paymentMode`, `paymentModeLabel`, and `referenceNumber.toLowerCase().contains('cash')`. Display `'CASH AT RECEPTION'` with amber badge whenever cash is identified.
5. **Pending Due Notification Feed & 1-Tap WhatsApp Reminder:**
   - Root Cause: Adjusting student due balances or issuing receipts with outstanding dues updated Firestore but never dispatched an in-app notification to the student's notification center, and lacked a 1-tap WhatsApp due reminder.
   - Guardrail: When `remainingDue > 0` or due is adjusted via `_showAdjustDueDialog`, dispatch `AppNotificationService.sendNotification(type: 'due')` routing directly to `/student/home`. Provide a 1-tap "Send Due Fee Reminder" option in `_showWhatsAppSheet` with itemized balance and UPI details.

---

## 18. Admin Document Studio Filter Persistence & Dynamic WhatsApp Profile Status Reflection (Learned Nov 2026)
1. **Admin Document Studio Filter, Watermark & Rotation Persistence:**
   - Root Cause: Document Studio filters (`[Grayscale]`, `[High Contrast]`), watermark overlay toggle, and image rotation were stored only in transient dialog state. When an admin saved ID changes and closed the dialog, reopening it reverted the view to `[Original]` with watermark enabled.
   - Guardrail:
     a) `StudentModel` and `RequestModel` must serialize `govIdFilterMode`, `govIdShowWatermark`, and `govIdRotation`.
     b) `AdminDocumentStudioDialog` must load initial values from both `widget.initial...` and `SharedPreferences` (`doc_studio_<id>`).
     c) Any user change (filter mode, watermark toggle, 90° rotation) must immediately persist to `SharedPreferences` and write back to Firestore on `_saveIdDetails()`.
     d) Reopening the Document Studio from `StudentDetailScreen` or `RequestDetailScreen` must restore the exact filter mode, watermark toggle, and orientation.
2. **Dynamic Paid vs Due Reflection in WhatsApp Templates:**
   - Root Cause: WhatsApp welcome previews displayed only the paid amount `💰 *भरलेले शुल्क:* ₹2000` while omitting outstanding due balances (e.g. `Due: ₹1000`), and displayed literal English placeholders `🪑 *नेमून दिलेली डेस्क:* Allocated Desk` in Marathi messages.
   - Guardrail:
     a) In `MessageTemplateService.substitute`, automatically substitute `{cleanSeat}`. When unallocated, dynamically generate localized access text (`'फ्लेक्सिबल / जनरल सीट (रिसेप्शनवर संपर्क साधा)'` in Marathi, or `'Flexible / General Access'` in English). Never leak `'Allocated Desk'`.
     b) When `dueAmount > 0`, dynamically inject an itemized pending due line (`⚠️ *उर्वरित बाकी शुल्क:* *₹{dueAmount}*` and `📲 *बाकी भरण्यासाठी UPI ID:* {libraryUpiId}`) immediately below the fee line in Marathi, Hindi, and English.
     c) When `dueAmount == '0'`, automatically append `• पूर्ण भरले ✓` / `Paid in Full ✓`.
3. **Dynamic WhatsApp Action Sheet Prioritization by Student Profile Status:**
   - Root Cause: WhatsApp action sheet showed static options without tailoring actions to the student's current status (Active vs Expired vs Pending Dues).
   - Guardrail:
     a) In `StudentDetailScreen._showWhatsAppSheet`, display a dynamic student summary header with live status badges: Membership status (`ACTIVE`/`EXPIRED`/`FROZEN`), Payment status (`⚠️ Due: ₹{due}` or `✅ Paid in Full`), and Seat badge (`💺 {seat}`).
     b) If `student.pendingDueBalance > 0`, highlight and prioritize **`📢 Send Fee Due Reminder (₹{due} Due)`** at the very top with amber styling and `RECOMMENDED` badge.
     c) Tailor Admission & Fee Receipt message to display both paid (`₹{paid}`) and remaining due (`₹{due}`).


---

## 19. Dynamic Admission & Cycle Dates Recalculation, Trilingual WhatsApp Engine, Passport OCR MRZ Priority & Document Studio Preview Standard (Learned Nov 2026)
1. **Dynamic Cycle Dates Variance & Smart Pro-Rata Due Recalculation Engine:**
   - Root Cause: "Adjust Admission & Cycle Dates" dialog was static, displaying only date pickers with no calculation of stay duration, variance against the student's enrolled plan, or financial dues impact when dates were moved forward or backward.
   - Guardrail:
     a) Real-Time Duration & Variance Engine: Compute selected duration in days and fractional months (e.g. `72 Days (~2.4 Mo)`). Compare against enrolled plan standard duration with dynamic color-coded badges (`Exact Plan Match ✓`, `Shorter by X days`, `Extended by +X bonus/grace days`).
     b) One-Tap Alignment Preset Chips: Provide 4 instant smart presets: `[Fit Plan (<N>d)]`, `[Month End]`, `[+7d Grace]`, `[+15d Grace]`.
     c) Smart Dues Recalculation Selector: When `student.pendingDueBalance > 0`, offer admin radio choice: Keep Existing Due (recommended for administrative adjustments, exam grace, and holidays) or Recalculate Due Pro-Rata based on daily rate.
     d) Save timestamps, updated due balance, log audit event, and refresh state.
2. **Instant Screen Lock Detached Context & Web Navigation Freeze Guardrail:**
   - Root Cause: Tapping Instant Lock in `QuickControlCenterSheet` dismissed the bottom sheet and then invoked `triggerInstantLock` with the unmounted bottom sheet context, triggering recursive element lookup loops in Flutter Web's CanvasKit engine and causing Chrome's "This page isn't responding" freeze.
   - Guardrail: Check `BiometricService.isLockEnabled()` first, set `InactivityLockService.setLocked(true)`, persist the active URI, pop the sheet cleanly, and push `Routes.biometricLock` via root router. If lock is unconfigured, prompt to configure PIN without locking.
3. **Trilingual WhatsApp Preview & Real-Time Language Translation Switching:**
   - Root Cause: WhatsApp preview sheet was hardcoded to English only, lacking Marathi and Hindi language options and dynamic message translation.
   - Guardrail:
     a) In `WhatsAppPreviewSheet`, add a 3-tab segmented language pill bar (`English`, `मराठी`, `हिंदी`).
     b) Dynamically translate greeting, due notices, renewal dates, seat assignments, and payment instructions across English, Marathi, and Hindi while preserving user inline text edits per language tab.
4. **Indian Passport OCR MRZ Detection Priority & Document Type Override:**
   - Root Cause: Passports with MRZ codes (`P<IND...`, `EMIGRATION CHECK REQUIRED`) were checked after Aadhaar, and scanner dialog forced `_isAutoDetect = false`, falsely detecting passports as Aadhaar.
   - Guardrail:
     a) Check Passport first in `OcrParser.detectGovIdType` using MRZ regex (`P[<(\w]{1,4}IND`, `EMIGRATION CHECK REQUIRED`, `r'\b[A-Z][0-9]{7}\b'`).
     b) Default `_isAutoDetect = true` in scanner dialogs.
     c) Display dynamic on-screen document type override chips (`[Passport] [Aadhaar] [PAN] [DL]`) on the review card to allow 1-tap correction with automatic regex reparsing.
5. **Identity Verification Uploaded Document Preview, Lightbox Zoom & Edit Action Suite:**
   - Root Cause: Scanned/uploaded ID cards in `AddStudentScreen` showed only "Scanned / Auto-filled" text without image thumbnails, zoom preview, or retake/replace options.
   - Guardrail: Render `_buildGovIdDocumentPreviewCard` with front/back thumbnails, `[Front (Zoom)]` / `[Back (Zoom)]` with `ImageService.showImageViewer`, and paired `[Retake / Replace]` and `[Remove]` buttons. Expand ID type options to include Passport, Voter ID, and Other Govt ID.


---

## 20. True 2D Floor Plan Spatial Grid Preservation & Student Sort Invariants (Learned Nov 2026)
1. **Seat Floor Plan Map Integrity (`SeatAssignmentMapSheet`):**
   - Root Cause: Student Details > "Change Desk" previously opened an unorganized `Wrap` of `ActionChip`s with occupied desks filtered out, causing available desks to wrap according to screen width rather than the configured room layout (e.g., 10 columns). This distorted spatial floor plans and made it impossible to locate desks relative to room features (entrance, windows) or perform direct desk swaps.
   - Guardrail: Never use `Wrap(ActionChip)` for desk assignment. Always render true 2D floor plans with spatial orientation banners (Entrance, Wi-Fi Zone, Quiet Study Zone), strict column preservation (`section.cols`), live multi-status markers (Emerald Green for Vacant, Purple for Current Desk with "MINE" badge, Rose/Red for Occupied with student names, and Amber for Hold/Maintenance), and atomic desk transfer / occupant swap capabilities (`SeatAssignmentMapSheet`).
2. **Student Sort Filter Invariants:**
   - Root Cause: The student roster lacked deterministic sorting by historical admission date (`effectiveAdmissionDate`), desk number ascending (`1 -> 100`), and highest pending dues (`pendingDueBalance`).
   - Guardrail: Provide deterministic sort orders (`StudentSortOrder.recent`, `StudentSortOrder.seatNumber`, `StudentSortOrder.highestDue`) with dynamic badges and icons. All sorting algorithms must be covered by automated regression tests in `test/system_qa_test.dart`.

---

## 21. Unified Control Center Web Freeze Immunity, Cozy Sentinel UI Surface & Admission Due Reflection (Learned Nov 2026)
1. **Deterministic Action Grid Layout & BottomSheet Constraint Wrapping:**
   - Root Cause: `QuickControlCenterSheet` used `LayoutBuilder` + `Wrap` within an unconstrained vertical modal sheet, triggering infinite intrinsic dimension loops in Flutter Web CanvasKit.
   - Guardrail: Eliminate `LayoutBuilder` and `Wrap` from modal bottom sheets. Construct deterministic 2-column rows using bounded `Row`s with `Expanded` tiles and `Align(alignment: Alignment.bottomCenter)` with `ConstrainedBox(maxWidth: 540)`.
2. **Cozy Sentinel AI Guardian Primary UI Access Surface:**
   - Root Cause: `SentinelDiagnosticScreen` (`/admin/sentinel`) had route wiring in `AppRouter`, but lacked high-visibility navigational entry points in both `QuickControlCenterSheet` and `SettingsScreen`.
   - Guardrail: Surface Cozy Sentinel AI Guardian directly in:
     a) `QuickControlCenterSheet`: Pinned 4th-row action tile with live shield icon (`Icons.health_and_safety_rounded`, emerald green) routing directly to `/admin/sentinel`.
     b) `SettingsScreen`: Listed in Group 5 (SECURITY, PRIVACY & DATA GOVERNANCE) alongside Audit Trail and Recycle Bin.
3. **Admission Request Approval Due Balance & UPI Reflection:**
   - Root Cause: When counter staff approved online admission requests in `RequestDetailScreen._offerWhatsAppWelcome`, only the collected amount was passed to `sendWelcomeMessage`, omitting outstanding balances (`dueAmount`) and UPI IDs (`libraryUpiId`).
   - Guardrail: `_offerWhatsAppWelcome` in `RequestDetailScreen` must extract `rawDue` across `liveStudentData`, `studentData`, and request `data`, and pass `dueAmount: rawDue.toStringAsFixed(0)` and `libraryUpiId: library?.upiId ?? ''` to ensure complete dual-entry financial transparency in WhatsApp welcome messages.

---

## 22. Student Card Grid Deterministic Key Binding & Orphaned Hero Elimination (Photo Cross-Swap Guardrail) (Learned Nov 2026)
1. **Orphaned `Hero` Widget Elimination in Recyclable Scroll Lists:**
   - Root Cause: `student_list_screen.dart` wrapped student avatars in `Hero(tag: 'student-avatar-${student.id}')` and names in `Hero(tag: 'student-name-${student.id}')`, but the target route `StudentDetailScreen` had no matching `Hero` tags. When tapping a card (e.g. Swati #CC20260012) and navigating to `StudentDetailScreen`, Flutter's `HeroController` detached the tapped avatar into the Navigator's overlay flight layer. Upon popping back to the list, the overlay returned the detached element to the recyclable `SliverGrid` without a matching destination flight.
   - Guardrail: NEVER place `Hero` widgets inside recyclable `GridView.builder` or `ListView.builder` items unless BOTH origin and destination routes share identical tags AND all elements have persistent keys. In `StudentListScreen`, omit orphaned `Hero` tags to eliminate overlay re-parenting glitches.
2. **Deterministic `ValueKey` Element Binding for Recyclable Cards & Avatars:**
   - Root Cause: In `GridView.builder` and `ListView.builder`, neither `PressableScale` nor the card `Container` nor `CircleAvatar` possessed a `Key` (`key: null`). Flutter's `SliverMultiBoxAdaptorElement` and element reconciliation matched elements by positional slot index. Furthermore, `CircleAvatar` wraps an `AnimatedContainer` whose internal `_AnimatedContainerState` retained the cached `DecorationImage` across recycled element slots, causing Card 3 (#CC20260014, Srikrishnadatta) and Card 6 (#CC20260012, Swati) to cross-swap decoded photos upon route pop.
   - Guardrail: Always assign explicit, entity-bound deterministic keys:
     a) Grid/List wrapper: `key: ValueKey('grid_item_${student.id}')` or `ValueKey('list_item_${student.id}')`.
     b) Card Container: `key: ValueKey('student_card_${student.id}')`.
     c) Avatar CircleAvatar: `key: ValueKey('avatar_${student.id}_${student.photoUrl.hashCode}')`.
     d) Desktop roster & bottom sheets: `key: ValueKey('desktop_item_${student.id}')`, `ValueKey('desktop_card_${student.id}')`, `ValueKey('desktop_avatar_${student.id}_${student.photoUrl.hashCode}')`, and `ValueKey('sheet_contact_avatar_...')`.
3. **Base64 Data URL Substring Extraction Robustness:**
   - Root Cause: `ImageService.getImageProvider` previously used naive string splitting that could fail on malformed MIME prefixes.
   - Guardrail: Use `trimmed.substring(trimmed.indexOf(',') + 1).trim()` and `.replaceAll(RegExp(r'\s+'), '')` to guarantee clean base64 byte decoding across all browser engines.

---

## 23. Dynamic Partial vs Full Payment Messaging & Zero-Due Stripping Guardrail (Learned Nov 2026)
1. **Industry Reference Architecture (Classplus, Stripe, Zoho, Razorpay):**
   - Root Cause: Administrators who had custom templates without `{dueAmount}` noticed students with partial payments (e.g. ₹1900 due on ₹3900 plan) received welcome messages with only the paid amount (₹2000) and no mention of dues. Conversely, if an admin explicitly added `{dueAmount}` to their template, students who paid in full received awkward `Due: ₹0` lines.
   - Guardrail (Single-Template Smart Block Paradigm): Operators should never have to maintain duplicate templates for full vs partial payments. The engine must compile templates dynamically:
     a) Partial Payment (`pendingDueBalance > 0`): Dynamically resolve and inject `⚠️ *उर्वरित बाकी शुल्क:* *₹{dueAmount}*` and `📲 *बाकी भरण्यासाठी UPI ID:* {libraryUpiId}` (in Marathi, Hindi, or English).
     b) Fully Paid (`pendingDueBalance <= 0` or null): NEVER display `Due: ₹0` or `बाकी शुल्क: ₹0`. Automatically strip any dedicated due line containing `{dueAmount}` or `{due}`, and append verified completion check `• पूर्ण भरले ✓` / `• Paid in Full ✓` to the amount line.
2. **Template Studio Interactive Live State Simulator:**
   - Root Cause: In `MessageTemplateStudioScreen`, `getLivePreview` hardcoded `dueAmount: '0'`, preventing administrators from inspecting or test-sending how their templates render for partial payment students.
   - Guardrail: Provide an interactive simulation selector (`[ Fully Paid (₹0 Due) ✓ ]` vs `[ Partial Payment (₹300 Due) ⚠️ ]`) directly above the simulated mobile phone frame in `MessageTemplateStudioScreen`. Forward the simulation flag to `getLivePreview` and `_sendTestWhatsApp` so administrators can verify both states in real time.
3. **Safe Multi-Line Regex Line Stripping:**
   - Guardrail: When stripping zero-due lines, only remove lines dedicated to due balances. If a single-line compact template contains both profile tags (`{name}`, `{plan}`, `{desk}`) and `{due}`, preserve the line and replace `{due}` with `0`. Dedicated due lines (`r'^[^\n]*\{due(?:Amount)?\}[^\n]*(?:\r?\n)?'`) are completely removed when dues are zero.

---

## 24. Multilingual WhatsApp Preview Hot-Swapping, Ledger-Backed Payment Resolution & Student Dossier Architecture (Learned Nov 2026)
1. **Multilingual Preview Hot-Swapping & Dynamic Language Dictionaries:**
   - Root Cause: When previewing WhatsApp messages in `WhatsAppPreviewSheet`, switching language pills (`English`, `मराठी`, `हिंदी`) failed to change the message text because callers passed a single pre-rendered Marathi string without supplying a `multilingualMessages` map, causing the sheet to populate all language slots with the same Marathi message.
   - Guardrail: Every messaging trigger (`sendWelcomeMessage`, `sendPaymentConfirmation`, `sendDueReminder`, `sendExpiryReminder`) must generate all 3 language representations (`en`, `mr`, `hi`) using `MessageTemplateService.substitute` and supply `multilingualMessages: {'en': enMsg, 'mr': mrMsg, 'hi': hiMsg}`. In `WhatsAppPreviewSheet`, switching language tabs must immediately hot-swap `_controller.text`, preserve user edit buffers per language, and bind `ValueKey('preview_$_selectedLanguage')` and `ValueKey('edit_$_selectedLanguage')` to eliminate state retention.
2. **Ledger-Backed Payment Resolution (Elimination of Empty `₹ ()` Placeholders):**
   - Root Cause: In `StudentDetailScreen._showWhatsAppSheet`, paid amount was computed using `effectivePlanCost - due`. When `planPrice` was 0 (or unresolved from a custom plan), `paidCalc` evaluated to 0, resulting in `friendlyAmount = ""`. The template then replaced `{amount}` with an empty string, yielding `*भरलेले शुल्क:* ₹ (Cash / Pay at Reception)`.
   - Guardrail: Always query the student's verified payment ledger (`libraries/{libId}/payments` where `studentId == widget.studentId`) to resolve `lastPaidAmount`, `totalPaidAmount`, and `lastPaymentMethod`. If `planPrice == 0`, infer plan fee as `totalPaidAmount + pendingDueBalance` (e.g. ₹200 paid + ₹1800 due = ₹2000 plan). If `lastPaidAmount > 0`, format as exact currency (e.g. `₹200 (Cash)`). If amount is missing or due, fallback to `'0'` and strip bare currency prefix regex (`r'₹\s*(?=\()'` -> `'₹0 '`).
3. **Student Overview Primary Dossier Standard (Immediate KYC Visibility):**
   - Root Cause: Moving `_buildProfileDetailsCard` into Tab 2 (`Profile & KYC`) caused student detail screens to render without the student's essential KYC dossier (Father's Name, DOB, Gender, PAN card with Studio thumbnail, College, Course, Address, Emergency Contact), giving the impression that profile data failed to load.
   - Guardrail: In accordance with CRM best practices (Classplus, Teachmint, Khatabook), the primary tab (Tab 0) must be `Overview & Profile` combining Seat Info, Plan Info, and the full Profile Details dossier on a single scrollable surface. Secondary tabs (`Payments & Dues`, `Documents & KYC`, `Activity & PIN`) provide deep-dive management.
4. **Responsive Header Typography & Anti-Clipping Wrap Standard:**
   - Root Cause: Long student names (`Srikrishnadatta Bharatrao Sonpethkar`) and phone numbers were clipped with ellipsis (`Srikris...`, `93594...`) on narrow viewports because headers used single-line unconstrained `Row` children.
   - Guardrail: Student names must use `titleLarge` with `maxLines: 2, softWrap: true`, and contact info rows must wrap text in `Expanded` with clean ellipsis to ensure full legibility across mobile screens and split-screen desktop layouts.






---

## 20. Cozy Sentinel Full-Inventory Audit & Auto-Heal Invariants (Learned Nov 2026)
1. **Complete Seat Inventory Ingestion for Invariant Audits:**
   - Root Cause: `SentinelDiagnosticScreen._runDeepScan` previously fed `ref.read(availableSeatsProvider).value ?? []` into the diagnostic scan. Because `availableSeatsProvider` filters strictly for `status == 'available'`, all occupied desks were omitted from the audit. Sentinel's double-binding check looked for `seatMap[student.seatId]`, found nothing, and erroneously flagged all seated students with `"Invalid Desk Reference"`, causing false panic and dropping health score to 68%.
   - Guardrail: Sentinel diagnostic scans must ALWAYS query 100% of seats across all sections (`allSeatsProvider` / `SeatRepository.getAllSeats`), containing both occupied and vacant desks. If `effectiveSeats.every((s) => s.status == SeatStatus.available)`, Sentinel must automatically trigger a repository fallback to load the full seat inventory before running invariant assertions.
2. **1-Tap Auto-Heal & Dossier Navigation Dual Actions:**
   - Root Cause: Clicking the action button on student desk discrepancies executed `execute1TapAutoHeal` which lacked an implementation for `mismatch_student_..._missing_seat`, resulting in the error banner `"Failed to auto-heal: Invalid Desk Reference..."`.
   - Guardrail:
     a) Implement `autoHealInvalidDeskReference` in `SentinelInvariantEngine`: verifies if the referenced desk exists in Firestore; if present, it re-binds seat occupancy (`status: 'occupied'`, `studentId`); if deleted, it safely unsets the invalid pointer on the student profile with audit logging.
     b) Provide paired action buttons on student anomaly cards: **`Update Dossier (तपशील उघडा)`** (navigates directly to `/admin/students/:id` for manual inspection) and **`Auto-Heal Reference`** (autonomous Firestore repair).

---

## 25. Automation Resilience, Dynamic Grace, Inactivity Safeguards & Secondary Route PopScope Standards (Learned Nov 2026)
1. **`remindedStages` Reset Lifecycle on Plan Renewal (`clearRemindedStages: true`):**
   - Root Cause: When students renewed their plans via administrative provisioning or self-service requests, the `remindedStages` tracking array (`['3_day', '1_day', 'today']`) was not cleared in Firestore. When the new renewal cycle approached its end 30 or 90 days later, `ExpiryNotificationService` saw `'3_day'` already in `remindedStages` and skipped sending expiry alerts, leaving students and counter staff unaware that validity was expiring.
   - Guardrail: Every renewal transaction in `StudentProvisioningService` and `StudentModel.copyWith` MUST pass `clearRemindedStages: true` (or write `'remindedStages': <String>[]` to Firestore), cleanly resetting the reminder cycle for the renewed term.
2. **Single Source of Truth for Expiry & Grace Periods (Firestore `settings/grace_period`):**
   - Root Cause: Remote Config contained a hardcoded fallback `'grace_period_days': 7`, which contradicted the library administrator's configurable setting in Firestore (`settings/grace_period` defaulted to 3 days), causing UI badges and notifications to display conflicting grace expiration dates.
   - Guardrail: Remote Config must NEVER hardcode conflicting operational thresholds. All background services (`ExpiryNotificationService`, `ExpirySchedulerService`, `MembershipAutomationService`) must dynamically query Firestore `settings/grace_period.defaultDays` and `settings/communications.reminderDays`, falling back to 3 days only if Firestore is completely offline.
3. **Resilient Secondary Screen `PopScope` & Hardware Back-Button Safety:**
   - Root Cause: Inner administration screens (`ExpenseListScreen`, `StaffListScreen`, `RecycleBinScreen`, `DataExportScreen`, `WaitingListScreen`) lacked explicit `PopScope` handlers. Pressing the physical Android back button caused the operating system to exit the application or unmount the shell.
   - Guardrail: All secondary and tertiary screens must wrap their `Scaffold` in `PopScope(canPop: false, onPopInvokedWithResult: (didPop, _) { if (didPop) return; if (context.canPop()) { context.pop(); } else { context.go(Routes.adminHome); } })` and include a top AppBar leading back button with `FittedBox` on the title.
4. **Form Builder Dynamic Visibility on Identity Verification & Remarks:**
   - Root Cause: Customizations configured in Form Builder (`/app/admin/more` -> Form Fields) for identity documents and notes were ignored by `AddStudentScreen` and `EditStudentScreen`, forcing fields to show even when the library administrator marked them hidden.
   - Guardrail: All built-in student identity fields (`govId`, `govIdType`, `govIdNumber`, `remarks`) must dynamically check `FormConfigService.isFieldVisible(formFields, id)` and consume `FormConfigService.getFieldLabel(formFields, id, default)` before rendering.
5. **Standardized Receipt Counter Format (`CC-YYYY-NNNN`):**
   - Root Cause: Receipt number generations were inconsistent between `RecordPaymentScreen` and `ReceiptRepository`, occasionally using random timestamp suffixes (`REC-2026-X8F9`) instead of formal accounting sequential numbers.
   - Guardrail: Standardize all receipt numbers to `ReceiptRepository.formatReceiptNumber(prefix: libPrefix ?? 'CC', count: nextCount)` producing `CC-YYYY-NNNN` (e.g. `CC-2026-0042`).
6. **ID Card Adaptive Header Text Luminance (`computeLuminance() > 0.55`):**
   - Root Cause: In `IdCardCustomizerScreen`, selecting a bright custom brand color (e.g. #FFFFFF or bright amber) caused white text headers to be completely unreadable due to zero contrast.
   - Guardrail: Always evaluate `primaryColor.computeLuminance() > 0.55` to dynamically switch text to `Colors.black87` and badge backgrounds to `Colors.black.withValues(alpha: 0.12)` for high-luminance themes, while preserving `Colors.white` for dark themes.
7. **Waiting List Promotion Lifecycle Tracking in Requests Hub:**
   - Root Cause: When a seat opened and the top candidate from the queue was offered the desk, no formal request was generated in the Requests Hub, forcing staff to navigate between Waiting List and Requests screens.
   - Guardrail: `WaitingListPromotionService` creates a linked `waiting_list_promotion` request doc in `requests` collection upon hold placement with `reservationExpiresAt`, auto-approving on seat confirmation or cascading on expiration.

---

## 26. Real-Time Seat Map Occupancy, Effective Status & Spatial Parity Standards (Learned Nov 2026)
1. **Dynamic Effective Seat Status & Occupancy Invariants (`SeatModel.effectiveStatus` & `isOccupied`):**
   - Root Cause: In Firestore, seat documents may contain `studentId != null` while raw `status` remains `'available'` due to legacy writes or partial updates. `SeatTile.dart`, `SeatGridWidget`, `occupancyProvider`, and `public/seats/index.html` were checking only the raw string `seat.status == 'occupied'`, causing the Admin Seat Map (`/admin/seats`), Admin Radar (`/admin/home`), and Public Live Seat Map (`/seats/?lib=...`) to display "0 Occupied" and paint occupied desks as green/vacant, while `SeatAssignmentMapSheet` displayed them as red/occupied.
   - Guardrail: Always evaluate occupancy through `seat.effectiveStatus` and `seat.isOccupied`:
     a) `SeatModel.effectiveStatus`: If `status == SeatStatus.available && studentId != null && studentId.trim().isNotEmpty`, dynamically promote to `SeatStatus.occupied`.
     b) `SeatTile`: Switch on `effectiveStatus` and evaluate `isOccupied = seat.isOccupied || student != null || studentName != null`. Never evaluate raw `seat.status` in isolation.
     c) `SeatGridWidget`: Quick filter chips must count `sectionSeats.where((s) => s.isOccupied || studentMap.containsKey(s.studentId)).length`.
2. **Public Live Seat Map Parity (`public/seats/index.html`):**
   - Root Cause: In the standalone JavaScript web view (`public/seats/index.html`), `resolveEffectiveStatus` checked only `seat.status`, causing prospective students visiting via shared link or QR code to see 100% available desks even when desks were actively assigned to students.
   - Guardrail: In `public/seats/index.html`, `resolveEffectiveStatus` must check `if (seat.studentId && typeof seat.studentId === 'string' && seat.studentId.trim().length > 0) return 'occupied';` and update the bottom action drawer to show "🔴 Currently Occupied by Student" and disable booking for occupied desks.
3. **Admin Dashboard Facility Occupancy Radar Parity (`occupancyProvider`):**
   - Root Cause: `occupancyProvider` in `seat_providers.dart` only counted `students.where((s) => s.membershipStatus == active && s.seatId != null)`. If student desk pointers were stored on seat documents or desynced, the radar showed 0% occupied.
   - Guardrail: `occupancyProvider` must unify both `students.where((s) => s.seatId != null)` AND `allSeats.where((s) => s.isOccupied)` into a merged deduplicated set of occupied seat keys, guaranteeing 100% mathematical consistency with `/admin/seats` and `/seats/?lib=...`.
4. **Cozy Sentinel Desynced Seat Binding Auto-Heal (`autoHealDesyncedSeatBinding`):**
   - Root Cause: Clicking "Auto-Heal" on `mismatch_seat_..._student_...` (Desk ↔ Student Desync) previously failed because `SentinelService.execute1TapAutoHeal` had no handler for seat-to-student desynchronization.
   - Guardrail: Implement `autoHealDesyncedSeatBinding` in `SentinelInvariantEngine`:
     a) If student has no assigned desk, establishes the double-binding (`student.seatId = seat.id`, `seat.status = 'occupied'`).
     b) If student has moved to another desk, vacates the stale desk (`seat.status = 'available'`, `seat.studentId = null`) to eliminate ghost occupancy.
     c) Wire into `SentinelService.execute1TapAutoHeal` with zero runtime exceptions.

---

## 27. Seat Map Multi-Zoom Invariants, Atomic Transfers, Inline Student Assignment & Bulk Status Purge Guardrails (Learned Nov 2026)
1. **Atomic Transaction Enforcement on Seat Transfers (`ref.read(seatRepositoryProvider).transferStudent`):**
   - Root Cause: `_SeatTransferSheetState._transferTo()` used `FirebaseFirestore.instance.batch()` without validating target seat availability prior to write, exposing the system to race conditions where two simultaneous transfers or an assignment could write two students to the same desk (double-occupancy data corruption).
   - Guardrail: Always invoke `ref.read(seatRepositoryProvider).transferStudent(...)`. This operation enforces a full Firestore transaction (`_firestore.runTransaction`) validating destination availability, releasing the source desk, populating `previousSeatId`, dispatching push notifications, and recording audit log entries.
2. **Inline Admin Desk Assignment Sheet (`_SeatAssignStudentSheet`):**
   - Root Cause: Clicking "Assign Student" on an available seat in `SeatDetailSheet` previously executed `context.go('/admin/students')`, navigating away from the seat map and discarding the selected seat context.
   - Guardrail: Tapping "Assign Student" on an available desk must open the inline `_SeatAssignStudentSheet`. This sheet offers instant search by name or phone, unassigned student filtering, and executes `SeatRepository.assignStudent` with instant haptic/snackbar feedback without route displacement.
3. **Bulk Status Purge & Student Link Release (`bulkUpdateStatus`):**
   - Root Cause: Marking seats as "Available" in bulk (`SeatMapScreen` -> Bulk Actions) set `status: 'available'` on seat documents but failed to delete `studentId`, `reservationType`, `reservedCandidateId`, `reservedCandidateName`, and `reservationExpiresAt`, causing tiles to immediately revert to red/occupied on subsequent renders due to residual `studentId`s.
   - Guardrail: In `SeatRepository.bulkUpdateStatus`, when `status == SeatStatus.available`, atomically delete all reservation fields and nullify `studentId` on the seats, while querying and clearing `seatId: null` on all matching student documents in the section.
4. **Manual Status Picker Elimination of Raw "Occupied" Option:**
   - Root Cause: Admin "Change Status" picker in `SeatDetailSheet` offered `SeatStatus.occupied`. Setting a desk to occupied without a student created an unlinked orphan occupied seat with no name or contact data.
   - Guardrail: Filter out `SeatStatus.occupied` from manual status pickers (`SeatStatus.values.where((s) => s != SeatStatus.occupied)`). Desks can only enter `occupied` status through formal student allocation via `assignStudent`.
5. **Multi-Zoom Column Unified Effective Status (`SeatTile._buildTileContent`):**
   - Root Cause: In `SeatTile`, Level 0 (10 columns) and Level 1 (6-8 columns) checked raw `seat.status == SeatStatus.reserved`, causing seats with expired soft-locks to display yellow "Res." text across green/available tiles.
   - Guardrail: Pass `effectiveStatus` into `_buildTileContent`. All zoom tiers (Level 0 through 3) must evaluate `isOccupied = effectiveStatus == SeatStatus.occupied` and `isReserved = effectiveStatus == SeatStatus.reserved`.
6. **Student Seat Map Resilient "My Seat" Matching:**
   - Root Cause: In `StudentSeatMapScreen`, `isMySeat` performed a strict string equality `seat.id == student.seatId`, failing to identify the student's desk when legacy database records stored bare numbers (e.g. `12`) or prefixed strings (e.g. `Desk #12`) while the seat ID was composite (`sec1_seat_12`).
   - Guardrail: Check both `seat.id == student.seatId`, `seat.label == student.seatId`, and compare normalized numbers via `SeatHelper.formatSeatNumberOnly`.
7. **Admin Section Expansion Persistence (`PageStorageKey`):**
   - Root Cause: `SeatMapScreen` expansion tiles lacked persistent keys, causing all expanded halls to collapse back to index 0 whenever live Firestore streams updated.
   - Guardrail: Assign `key: PageStorageKey('admin_section_tile_${section.id}')` to `ExpansionTile` to preserve expansion state across real-time updates and view scrolling.




---

## 28. OCR Pipeline Guardrails (Learned Nov 2026)

**Root Cause:** Full OCR system audit revealed 14 issues across the 13-file OCR architecture spanning Mobile/Web × Admin/Student platforms.

1. **Tesseract.js MUST include Hindi language:** Always initialize with `Tesseract.createWorker(["eng", "hin"])` on web. Never use `"eng"` alone — the majority of Aadhaar cards used in rural Maharashtra have Hindi/Marathi script fields (`जन्म तिथि`, `पिता का नाम`). Single-language `"eng"` causes DOB and address extraction to return empty strings on these cards.

2. **MobileScannerController MUST be disposed in finally:** Any instantiation of `MobileScannerController` for `analyzeImage()` must be wrapped in an inner try-finally block so the controller is always disposed, even if `analyzeImage()` throws. Without this, each failed scan leaks a camera pipeline instance. After 10–20 failed scans the camera can freeze.

3. **aspectRatio MUST be passed to DocumentLayoutClassifier.classify():** Every call to `DocumentLayoutClassifier.classify()` must pass the actual `aspectRatio` computed from image bytes via `ui.instantiateImageCodec()`. Without it the A4-portrait combined-page detection (bothSidesCombined) is dead code, causing the system to always prompt for a back side even when both sides appear on a single xerox sheet.

4. **UIDAI Secure QR v2 field offset must be detected:** The 2024 PVC Aadhaar Secure QR format prepends a 1–2 digit version token at `fields[0]`. All field-index extractions in `_parseSecureAadhaarQr()` must check whether `fields[0]` is a numeric version byte and apply `offset = 1` if so, or `offset = 0` for pre-2024 cards. Without this, name ends up in DOB, gender in name, etc.

5. **OCR errors MUST NOT be silently swallowed in `catch (_)`:** Every OCR error catch block must (a) `debugPrint` the error for developer visibility and (b) show a classified, actionable hint to the user via `_ocrErrorHint(e)` — never just a generic "please enter manually" message. Classify: permission denied, unsupported format, image too large, generic.

6. **UPI UTR fallback MUST exclude valid Aadhaar numbers:** The 12-digit standalone fallback in `UpiPaymentOcrParser` must check `!AadhaarValidator.validateVerhoeff(candidate)` before accepting a 12-digit number as a UTR. Aadhaar numbers pass Verhoeff checksum; real UTRs do not follow the Verhoeff algorithm.

7. **Expense OCR MUST use the last labelled total, not the first ₹ match:** Use `allMatches().last` on the `Total Amount / Grand Total / Net Payable` pattern. Electricity bills and GST invoices contain multiple ₹ amounts (meter readings, sub-totals, tax lines); the first match is almost never the correct "Total Payable" figure.

---

## 29. Mobile Requests Hub, Trilingual WhatsApp Identifiers & Sentinel Multi-Section Invariants (Learned Nov 2026)

1. **Requests Hub Tab-Scoped Filtering & Fresh Active Tab Rendering:**
   - Root Cause: Category filter chips showed pending counts (e.g. `All Modules 13`, `Admissions 4`) but the list displayed "All caught up" because `TabBarView` pre-renders all 4 tabs simultaneously, caching empty list states from earlier transitions without re-evaluating category filter state. Furthermore, `isPending` did not catch actionable registration states like `new`, `desk_payment_pending`, `submitted`, `waiting`, or `review`.
   - Guardrail: Replace pre-cached `TabBarView` with reactive active-tab switching (`_buildActiveTabList`). Expand `isPending` to evaluate all actionable statuses (`pending`, `new`, `desk_payment_pending`, `payment_pending`, `submitted`, `open`, `waiting`, `review`, `under_review`). Category filter chips and counters must strictly reflect items in the active tab.

2. **WhatsApp Message Human Identifiers & Zero Empty-Bracket Policy:**
   - Root Cause: In `StudentDetailScreen._showWhatsAppSheet`, fallback logic for missing admission numbers defaulted to 20-character Firestore document UIDs (`TFBktLryOfa4FlDLVvyl`). Missing or 20-character plan IDs printed as raw database strings (`8pLhPZX5pRBNOT5NR7Me`). Unloaded payment methods and amounts left awkward dangling parentheses and empty brackets like `💰 *भरलेले शुल्क:* ₹ ()`.
   - Guardrail: Never expose raw Firestore UIDs to students in WhatsApp messages. Convert raw UIDs to readable abbreviations (`CC-${id.substring(0,6).toUpperCase()}`). Resolve plan names from `plansStreamProvider` before falling back to default plan names. Clean up all empty brackets `()` and dangling currency symbols in `MessageTemplateService.substitute` so message previews are always 100% human-friendly.

3. **Sentinel Multi-Section Invariant Healing & Composite Seat Key Resolution:**
   - Root Cause: Sentinel's `autoHealInvalidDeskReference` attempted to locate seats using a flat Firestore path `libraries/{libId}/seats/{seatId}`, whereas Cozy Corner seats are stored nested inside sections (`libraries/{libId}/sections/{secId}/seats/{seatId}`). This caused 1-tap auto-heal to throw an exception and display a red error toast: `"Failed to auto-heal: Invalid Desk Reference for ..."`.
   - Guardrail: Always search across section collections when healing desk references. Fall back to matching by assigned student ID and normalized seat number (`SeatHelper.formatSeatNumberOnly`). When a valid seat is found, re-bind double-binding on BOTH the seat document and the student profile. If the seat truly no longer exists in any section, cleanly delete the invalid pointer from the student document so the student can be reassigned without crash loops.

---

## 30. Advanced OCR Engine Guardrails (Learned Nov 2026)

1. **PVC Card Image Preprocessing Before ML Kit (F4):**
   - Root Cause: Glossy PVC cards (Aadhaar, PAN, College ID) and laminated cards cause specular reflections under room lighting, reducing OCR character recognition accuracy to ~60%.
   - Guardrail: In `ocr_service_io.dart`, run `preprocessImage(Uint8List bytes)` using `package:image/image.dart` before ML Kit. Scale oversized images down to max 1600px, convert to grayscale, and enhance contrast/brightness (`img.adjustColor(contrast: 1.3, brightness: 1.05)`). If the preprocessed text produces fewer than 10 characters, gracefully fall back to raw image bytes.

2. **Async `compute()` Isolate for UIDAI Secure QR Decompression (F6):**
   - Root Cause: Parsing 300+ digit BigInt strings and executing GZip decompression on the Flutter main UI thread froze the app for 400–900ms on budget Android devices.
   - Guardrail: Always execute `parseSecureAadhaarQrIsolate()` inside Flutter's `compute()` via `QrIdParser.parseQrStringAsync(raw)` and `OcrParser.parseUnifiedAsync()`. Keep the UI thread completely unblocked with 60 FPS fluidity.

3. **Two-Pass College Header Banner Disambiguation (F10):**
   - Root Cause: Maharashtra college ID cards frequently feature the affiliating university (e.g. `Dr. Babasaheb Ambedkar Marathwada University` or `Savitribai Phule Pune University`) on line 0 and the actual college (e.g. `Government Polytechnic, Beed` or `Fergusson College`) on line 1. A naive first-match header search captured the parent university instead of the student's actual college. Furthermore, matching inline labels with `[:\s]+` caused words like `COLLEGE` in `FERGUSSON COLLEGE (AUTONOMOUS)` to be treated as a label, eating the college name.
   - Guardrail:
     a) Separator Enforcement: Inline field search (`_inlineValue`) must require explicit colon/hyphen separators (`[:\-]+`) or start-of-line positioning to prevent standard English words inside institution names from acting as field keys.
     b) Two-Pass Header Extraction: In `_parseCollegeId()`, Pass 1 strictly prioritizes specific institution keywords (`COLLEGE`, `POLYTECHNIC`, `INSTITUTE`, `MAHAVIDYALAYA`, `COEP`, `VJTI`, `MIT`). Pass 2 serves as a fallback for parent university banners (`UNIVERSITY`, `VIDYAPEETH`, `SPPU`, `BAMU`, `SRTMU`) only when no specific college name is found.

4. **Web Digital Document PDF.js Extraction Pipeline (F11):**
   - Root Cause: e-Aadhaar and DigiLocker PDF uploads on Flutter Web were attached as opaque binary files with 0 text extraction, forcing students to manually type all personal details.
   - Guardrail: Provide a client-side vector text extraction pipeline via PDF.js (`window.extractPdfText(base64)`) in both `web/index.html` and `public/app/index.html`. In `OcrService.extractPdfText()`, extract text layers directly from PDF pages and feed them into `OcrParser.parseAadhaar()`, auto-filling student name, DOB, ID number, and address with 100% accuracy without OCR raster degradation.

---

## 31. Popped Context Modal-on-Modal Web Freeze & Mandatory Web Deployment Pipeline (Learned Nov 2026)

1. **Popped Context Modal-on-Modal Freeze Guardrail (`QuickControlCenterSheet` Root Navigator Routing):**
   - Root Cause: In `QuickControlCenterSheet`, tapping "Instant Lock" or secondary actions (Typography, Global Search, Notifications, Sentinel AI Guardian, Audit Log) called `Navigator.of(context).pop()` and immediately invoked `showDialog(context: context)` or `context.push()` using the popping bottom sheet's context. When an admin had no PIN configured (`isLockEnabled == false`), pushing an `AlertDialog` onto a disposing `ModalBottomSheetRoute` caused Flutter Web's CanvasKit layout engine (`_ModalBottomSheetLayoutFactory` + `_RenderConstrainedBox`) to enter an infinite layout measurement loop on the JavaScript main thread, locking the thread and triggering Chrome's *"This page isn't responding"* freeze.
   - Guardrail: Never pass a popping sheet's context to subsequent navigation or dialog triggers. Dismiss the sheet route first, and dispatch the target action inside `WidgetsBinding.instance.addPostFrameCallback((_) { final rootCtx = rootNavigatorKey.currentContext; ... })`. For instant screen locks, always push the lock barrier (`rootCtx.push(Routes.biometricLock)`) rather than `.go` so that the underlying screen state and unsaved form data are 100% preserved.

2. **Mandatory Web Compilation & Firebase Hosting Deployment Synchronization:**
   - Root Cause: Fixes for dynamic payment dues in WhatsApp templates, desk label format stripping (`Allocated Desk` to localized flexible seat text), and Quick Controls instant lock were written and verified via unit tests, but `scripts/publish_web.ps1` (`flutter build web --release --base-href /app/`, copy to `public/app`, `inject_loader.js`, and `firebase deploy --only hosting`) was not executed. Live users testing `https://study-lib-mgmt-2026.web.app` continued to run stale cached bundles displaying missing due balances, English placeholders in Marathi messages, and the unresponsive script freeze.
   - Guardrail: No bug fix or operational enhancement is complete without running `scripts/publish_web.ps1`, verifying successful deployment to Firebase Hosting, and bumping the cache-busting token `v=YYYYMMDD_XX` across `study_library/web/index.html` and `public/app/index.html`.



