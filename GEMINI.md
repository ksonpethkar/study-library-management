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

---

## 32. Seat Map Disambiguation, Recursive Double Prefix Elimination & Legend Real-Time Invariants (Learned Nov 2026)

1. **Desk Map Tile Occupant Disambiguation (`_formatTileName`):**
   - Root Cause: In `SeatAssignmentMapSheet`, desk tiles truncated names with `occupant.name.split(' ').first`. When multiple students shared a common first name (e.g. `Shubham Dixit` and `Shubham Kandukatle`), both desks displayed `Shubham`, causing counter staff to believe the same student was assigned to multiple desks or causing confusion between Seat 19, Seat 20, and Seat 40. Furthermore, lowercase names (`srikrishnadatta`, `shubham dixit`) lacked proper Title Casing.
   - Guardrail: In `SeatAssignmentMapSheet._formatTileName`, format occupant names with Title Casing and last-initial disambiguation (`First Name + Last Initial`, e.g. `Shubham D.` vs `Shubham K.`). For single-word names, format cleanly in Title Case (`Srikrishnadatta`, `Swati`).

2. **Recursive Double Prefix Eradication (`SeatHelper.formatDeskLabel`):**
   - Root Cause: In `SeatAssignmentMapSheet` lines 208, 368, and 884, string interpolation concatenated `'Desk #' + SeatHelper.formatSeatLabel(seatId: widget.currentSeatId)`. Since `formatSeatLabel` already produced `'Seat #20'`, the resulting string was `'Current: Desk #Seat #20'`.
   - Guardrail: Never concatenate `'Desk #' + SeatHelper.formatSeatLabel(...)`. Always invoke `SeatHelper.formatDeskLabel(seatId: ...)` or `SeatHelper.formatSeatNumberOnly(...)`.

3. **Current Desk Badge Semantic Clarity (`CURRENT` vs `MINE`):**
   - Root Cause: Current desk tiles displayed `MINE`, which is student-centric and misleading in an Admin staff workflow.
   - Guardrail: On admin assignment maps, display `CURRENT` with the purple star badge.

4. **Status Legend Real-Time Grid Count Synchronization:**
   - Root Cause: The legend ribbon calculated `availableCount` and `occupiedCount` using raw `s.status` without evaluating `s.effectiveStatus`, student assignments, or deducting `widget.currentSeatId`, causing the legend to state `Occupied (3)` while the grid displayed 4 occupied desks + 1 current desk.
   - Guardrail: Compute legend metrics by iterating over the active section's seats using the exact same `effectiveStatus` and occupant presence rules as the grid tiles, ensuring 100% mathematical parity.

5. **Stale Occupancy Pointer Auto-Detection (Cozy Sentinel):**
   - Root Cause: When students were moved from one desk to another, legacy or partially updated records could leave previous desks (e.g. Seat 19) retaining `studentId`, creating ghost occupancy.
   - Guardrail: In `DatabaseDiagnosticsService`, flag any seat whose `studentId` points to an active student whose `seatId` has moved elsewhere as `stale_seat_pointer` with 1-click auto-healing.


---

## 32. Restore Desk 1-Tap Optimistic State Mutation, Column Calculation & Double-Prefix Guardrails (Learned Nov 2026)

1. **1-Tap Optimistic State Mutation (0ms UI Latency vs 2-Tap User Confusion):**
   - Root Cause: Tapping "Restore Desk" in `student_detail_screen.dart` executed `await seatRepo.assignStudent(...)` and showed a green snackbar immediately, but `_loadStudent()` took several seconds across multiple sequential Firestore network calls. Without optimistic state mutation in memory, `student.seatId` stayed null and the "Seat Info" card continued showing "No seat assigned yet" + "Restore Desk". Users saw the green success toast but thought the UI was unresponsive or broken, prompting them to tap a second time.
   - Guardrail: When "Restore Desk" is tapped, immediately mutate local state in memory with `student = s.copyWith(seatId: targetSeat, sectionId: targetSec)`, `seatLabel = restoredSeatNumber`, and `sectionName = restoredSectionName` with 0ms latency. The UI instantly transitions to the active seat card. If the network transaction fails, gracefully revert state and display an error snackbar.

2. **Section Column Math Accuracy & Fallback Floor (Seat 16 vs Seat 20):**
   - Root Cause: `SeatHelper.formatSeatLabel` on composite seat coordinates `_r{row}_c{col}` (e.g. `sec_r1_c9` for Shubham Dixit in Cozy Hall) defaulted to `totalCols = 6` when `cols` was null. Row 1, Column 9 calculated as `1 * 6 + 9 + 1 = 16` (`Seat #16`). In Cozy Hall, the actual section width is 10 columns (`1 * 10 + 9 + 1 = 20`, Seat 20). When `_loadStudent()` subsequently finished fetching the real seat document from Firestore, the label updated from `Seat #16` to `Seat 20`, causing users to think a different seat was assigned.
   - Guardrail:
     a) Default Section Columns: `SeatHelper.formatSeatLabel` fallback column width for `_r{row}_c{col}` must match the application standard default section columns of `10` (`_colsController = TextEditingController(text: '10')`), NOT 6.
     b) Section & Seat Resolution: In `_loadStudent()`, safely query both `previousSectionId` and `previousSeatId` so `previousSeatLabel` and `previousSectionName` are resolved directly from Firestore seat documents (`label: '20'`) and section names (`name: 'Cozy Hall'`), never relying on blind coordinate math.
     c) Real-Time Stream Synchronization: In `_startLiveStudentSubscription`, update both `seatLabel` and `sectionName` when snapshot data emits.

3. **Universal Single-Prefix Discipline (Elimination of `Seat Seat #XX`):**
   - Root Cause: `SeatHelper.formatSeatLabel` automatically includes the `'Seat #'` prefix when `includePrefix: true`. `student_detail_screen.dart` concatenated `'Seat ' + SeatHelper.formatSeatLabel(...)`, `'Previously Allocated: Seat ' + ...`, and `'Restored Seat ' + ...`, producing recursive double prefixes (`Seat Seat #16`, `Previously Allocated: Seat Seat #33`, `Restored Seat Seat #33`).
   - Guardrail: Never prepend `'Seat '` outside `SeatHelper`. Always invoke `SeatHelper.formatSeatLabel(...)` directly, which handles prefixing and deduplication internally, or use `SeatHelper.formatDeskLabel(...)` or `SeatHelper.formatSeatNumberOnly(...)`.

---

## 33. Zero-Index Lookups, Responsive Update Banners, Digital Pass Geometry & OTA Discipline (Learned Nov 2026)

1. **Zero-Index Direct Primary-Key Lookups & Resilient Error Absorption (`currentStudentProvider`):**
   - Root Cause: `currentStudentProvider` executed `.where('userId', isEqualTo: uid)` queries on `libraries/{libraryId}/students`. When a single-field index exemption existed on Firestore, the query threw `failed-precondition: COLLECTION_ASC index for collection students and field userId not ready`, causing the Riverpod stream to crash and display raw Firebase console error URLs on both "My Membership" and "My Receipts" screens.
   - Guardrail: Always prioritize direct `.doc(knownDocId).snapshots()` lookups using cached IDs from `SharedPreferences`, `users/{uid}.studentId`, and direct `students/{uid}` existence checks. These require ZERO composite indexes. Wrap all Firestore query streams in error-absorbing handlers that fall back to offline cache and NEVER emit raw database exception URLs to the user interface.

2. **Elimination of `Filter.or(...)` on Student Document Collections:**
   - Root Cause: `my_receipts_screen.dart` and `my_membership_screen.dart` queried `receipts` and `payments` using `Filter.or(Filter('studentUserId', isEqualTo: uid), Filter('studentId', isEqualTo: student.id))`. In Firestore, multi-field OR queries require specialized composite indexes that fail with `failed-precondition` when unbuilt.
   - Guardrail: Use simple single-field queries on `studentId` (`where('studentId', isEqualTo: student.id)`). Perform multi-key resolution (`studentUserId`, `membershipNumber`) in Dart memory on the preloaded snapshots.

3. **Update Banner Responsive Flow & Vertical Squishing Guardrail (`effectiveWidth < 768`):**
   - Root Cause: In `AppUpdateBanner`, an unconstrained horizontal `Row` holding both the text section and action buttons (`What's New`, `Later`, `Reload`) was placed inside a mobile `ListView`. Action buttons took available width first, squishing the text container to <20px and forcing each character to wrap vertically into a 1-letter-wide column.
   - Guardrail: Safe compact detection must check `effectiveWidth < 768` (handling unbounded constraints via `MediaQuery.sizeOf(context).width`). Mobile viewports must strictly render a `Column`: full-width title/subtitle on top, and action buttons aligned cleanly underneath.

4. **Digital Pass 1:1 Height Geometry Parity & Clean Summary Rules:**
   - Root Cause: The front side of the student ID card occupied ~236px, while the back side expanded to >285px due to separate rows for guardian and blood group, large QR barcodes, and raw markdown headers (`# LIBRARY RULES & REGULATIONS`), causing an unseemly height jump when flipped.
   - Guardrail: Front and back faces must share the identical `minHeight: 236`. On the back face, combine Guardian and Blood Group into a single compact row, resize the QR barcode to 60x60 with tap-to-zoom, and format rules using `IdCardTemplateSettings.resolveSummaryRules(...)` (strictly 2 clean summary bullets stripped of markdown `#` headers).

5. **OTA Keystore Identity Discipline (Elimination of "App not installed"):**
   - Root Cause: When users previously installed the app via USB debugging (`flutter run` using Android SDK's `debug.keystore`) and then attempted to install an in-app OTA update signed with the permanent release keystore (`upload-keystore.jks`), Android PackageInstaller rejected the APK with `"App not installed"`.
   - Guardrail: Production OTA updates must strictly match the signature of the installed application. Users migrating from development/debug builds must perform a one-time uninstall of the debug version before installing the production release APK. Ensure `update.json` defaults to the high-performance 54.5 MB 64-bit ARM binary (`StudyLibrary-arm64-v8a.apk`).

---

## 34. Strict Occupancy Invariants, Zero-Collision Seat Allocation & Stale Pointer Eviction (Learned Nov 2026)

1. **Strict Occupancy vs Temporary Soft-Lock Invariant (`overrideSoftLock` Decoupling):**
   - Root Cause: In `SeatRepository.assignStudent`, `bool overrideSoftLock = true` was passed by default from desk allocation dialogs. The occupancy collision guard was wrapped in `if (!overrideSoftLock)`, which unintentionally allowed active occupied desks to be overwritten as if they were merely expired 5-minute registration soft-locks.
   - Guardrail: Permanent occupancy is strictly decoupled from temporary soft-locks. If a desk has `status == 'occupied'` and `currentOccupant.isNotEmpty`, verify if the occupant is an active enrolled student. If active, strictly reject reassignment with `Exception('Desk #X is already assigned to active student "Y"...')`. The `overrideSoftLock` flag must strictly apply ONLY to temporary cart soft-locks (`SeatStatus.reserved`), NEVER to active occupied desks.

2. **Atomic Double-Binding Sweep (`staleStudentRefs`):**
   - Root Cause: When a desk was reassigned, `assignStudent` only updated the physical seat and cleared the new student's previous seat references. Any other student records in Firestore that pointed to `seatId` (e.g. `shubham dixit` when `sk` was assigned) remained untouched, leaving multiple student documents pointing to the same `seatId`.
   - Guardrail: Before executing the assignment transaction, sweep Firestore for all student documents where `seatId == targetSeatId`. Inside the atomic transaction, execute `tx.update(staleRef, {'seatId': FieldValue.delete(), 'previousSeatId': seatId})` on all non-matching student records so orphan or duplicate pointers are eliminated in the exact same transaction.

3. **Sentinel Anomaly Audit & Autonomous Auto-Healing (Invariant 1c):**
   - Root Cause: Neither `SentinelInvariantEngine` nor `DatabaseDiagnosticsService` audited whether multiple active students had identical `seatId` values.
   - Guardrail: Implement Invariant 1c across both engines:
     a) Audit: Group all active students by `seatId`. Flag any group with `length > 1` as a Critical Anomaly (`duplicate_allocation_seat_X` / `duplicate_seat_allocation`).
     b) Auto-Heal: Resolve against the physical seat document (`seat.studentId`). The verified occupant keeps the seat; all other conflicting student documents have their `seatId` cleared and moved to `previousSeatId`.

4. **Multi-Section Visual Disambiguation (`_formatDeskWithSection`):**
   - Root Cause: If multiple sections each had a desk numbered 16 (e.g., Section A Desk 16 and Section B Desk 16), the student card only displayed `Desk #16`, making distinct desks appear like a single conflicting desk.
   - Guardrail: When multiple active sections exist in the library, format desk tags dynamically as `Desk #16 • SectionName` across all student rosters and search listings.

---

## 35. Bidirectional Seat-Student Synchronization & Public Map Auto-Healing (Learned Nov 2026)

1. **First-Class `studentName` Serialization & Dual Invalidation:**
   - Root Cause: Unassignment, bulk updates, and membership expiration operations set `status: 'available'` and `studentId: null`, but omitted `studentName: FieldValue.delete()`. This left residual names on available seats. Admin Seat Map evaluated `(seat.studentName.isNotEmpty) => occupied` rendering them pink, while public seat map checked `seat.status == 'occupied'` rendering them green, and student documents had `seatId: null` rendering "No Desk".
   - Guardrail: `SeatModel` must serialize and deserialize `studentName` as a first-class field. Every seat status modification (unassign, bulk update, expiration) must delete `studentName` alongside `studentId`. `SeatTile`, seat assignment sheets, and count ribbons must strictly evaluate `effectiveStatus`.

2. **Public Live Seat Map Typo Auto-Healing & Realtime Resolution:**
   - Root Cause: When users opened the public seat map with a library ID typo (e.g. character 17 typed as '1' or 'l' instead of capital 'T'), Firestore returned 404, causing the web view to fall back to hardcoded client defaults (60 total, 60 available, 0 occupied).
   - Guardrail: Public seat map `public/seats/index.html` must implement fuzzy typo auto-healing and 404 fallback to `DEFAULT_LIBRARY_ID`. In `resolveEffectiveStatus`, evaluate `status === 'occupied' || Boolean(seat.studentId) || Boolean(seat.studentName)`.

---

## 36. Public Live Seat Map Responsive Touch Hints & Viewport Guardrails (Learned Nov 2026)

1. **Intelligent Mobile Swipe Hint (`checkSwipeHint`):**
   - Root Cause: An animated horizontal gesture tip (`👉 Swipe to view all desks`) was rendered unconditionally across all display sizes, including widescreen desktop monitors (1920x1080) where all 60 desks fit within the viewport and mouse/trackpad controls are used, causing user confusion ("Swipe to view all desks? what is this?").
   - Guardrail:
     a) CSS: `.swipe-hint` is set to `display: none;` by default. It is only displayed via `@media (max-width: 768px)` when the `.visible` class is present.
     b) JS Invariant: `checkSwipeHint()` verifies both `window.innerWidth <= 768` AND horizontal content overflow (`viewport.scrollWidth > viewport.clientWidth + 16`) before adding `.visible`.
     c) Auto-Fade & Interaction Dismissal: Auto-fade the hint after 4 seconds, dismiss immediately on scroll/touch, and remove it whenever the user clicks `⛶ Fit Hall`.

---

## 37. Soundbox Audio Announcement Discipline (Zero False Announcements on Pending Student Requests) (Learned Nov 2026)

1. **Separation of Student Request Submission vs Admin Fund Collection:**
   - Root Cause: In `renew_plan_screen.dart`, when a student submitted a renewal request (e.g. Half Year ₹3800, "Pay at Desk"), the code called `soundboxServiceProvider.announcePayment(amount: 3800)`. Because both admin and student portal run on the same Flutter codebase (or when testing on the same machine/browser), the Web Audio & SpeechSynthesis soundbox synthesized a vocal announcement: *"Payment of 3800 rupees received for Student Name on Cozy Corner"*, even though the student had only submitted a pending request and admin had not approved or collected any cash yet.
   - Guardrail: Student self-serve actions (`renew_plan_screen.dart`, `registration_screen.dart`, seat change requests) MUST NEVER invoke `soundboxServiceProvider.announcePayment`. Spoken payment announcements are strictly reserved for:
     a) Reception desk staff recording an offline/counter payment (`record_payment_screen.dart`).
     b) Admin manually recording payment during student renewal (`student_detail_screen.dart`).
     c) Admin approving a pending renewal request and recording payment (`request_detail_screen.dart`).








---

## 38. Comprehensive Occupancy Mathematics, Public Seat Map Syntax Immunity & Filter Chip Reconciliation (Learned Nov 2026)

1. **Occupancy Availability Mathematical Invariant:**
   - Root Cause: In `seat_providers.dart` (`occupancyProvider`), `availableSeats` was calculated as `totalCapacity - occupiedSeats`. This completely ignored `reserved` and `maintenance` desks. When Desk #60 was reserved, the Admin Home Dashboard reported `Available: 52 ready to assign`, while the Seat Map reported `Vacant: 51`, creating an unexplained 1-desk discrepancy across screens.
   - Guardrail: Always compute available seats as:
     $$\text{availableSeats} = \text{totalCapacity} - \text{occupiedSeats} - \text{reservedSeats} - \text{maintenanceSeats}$$
   - The provider must yield `'reserved': reservedSeats, 'maintenance': maintenanceSeats` in addition to total, occupied, and available. The dashboard micro-metric tile must clarify reserved counts when present (`ready (1 res)`).

2. **Filter Chip Zero-Gap Reconciliation ($51 + 8 + 1 = 60$):**
   - Root Cause: `seat_grid_widget.dart` only displayed chips for `All Desks (60)`, `Vacant (51)`, and `Occupied (8)`. The sum was 59, leaving Desk #60 (Reserved) completely unrepresented, with no way for counter staff to filter or inspect reserved desks.
   - Guardrail: Filter chips must account for 100% of seats in a section. When `reservedCount > 0` or `maintenanceCount > 0`, the UI must dynamically render `Reserved ($count)` (Amber `0xFFF59E0B`, `Icons.lock_clock_rounded`) and `Maintenance ($count)` (Slate `0xFF64748B`, `Icons.build_rounded`).
   - Tapping the `Reserved` chip must highlight only reserved and soft-locked desks, dimming all vacant and occupied desks.

3. **Public Live Seat Map JavaScript Syntax Immunity (`public/seats/index.html`):**
   - Root Cause: Stray duplicate calls and unmatched closing braces (`}`) at line 1254 in `public/seats/index.html` caused an uncaught browser `SyntaxError: missing ) after argument list`. The script halted before execution, leaving the public visitor page permanently stuck on the loading spinner (`Connecting to live seating network...`) with stale hardcoded HTML values (`57 Available, 3 Occupied`).
   - Guardrail: Any static HTML/JS web viewers hosted in `public/` must undergo automated JavaScript syntax parsing (`node --check`) in CI/QA before deployment to prevent runtime script crashes.

4. **Sentinel 1-Tap Auto-Heal for Duplicate Seat Allocations:**
   - Root Cause: Sentinel Guardian detected `Duplicate Desk Allocation: Desk #20` (e.g. Srikrishnadatta and Shubham simultaneously linked to the same desk), but clicking 'Re-sync Seat' threw `Failed to auto-heal` because `SentinelService.execute1TapAutoHeal` lacked the `duplicate_allocation_seat_` branch.
   - Guardrail: `SentinelService.execute1TapAutoHeal` must route duplicate seat anomalies to `autoHealDuplicateSeatAllocation` in `SentinelInvariantEngine`, performing multi-section lookup, determining the legitimate occupant, clearing duplicate pointers from conflicting student records, and double-binding the retained student atomically.

---

## 39. Admin Reset Student PIN Isolation, Live Unlock Safeguards & Zero Cross-Student Session Conflation (Learned Nov 2026)

1. **Live Instant Unlock Mechanism (How It Works):**
   - Root Cause / Architectural Context: When an admin resets a student's PIN in `StudentDetailScreen` (`BiometricService.adminResetStudentPin`), the system flags the student's Firestore document with `pinResetByAdmin: true` and `pinResetAt: serverTimestamp()`. On the student's locked device running `BiometricLockScreen`, an active real-time Firestore stream (`_subscribeToLiveSecurityUpdates`) receives this event, clears the local lockout timer and PIN, and automatically navigates via `_unlockApp()` (`context.go(Routes.studentHome)`). This allows counter staff to unlock a forgotten student pass in real time without requiring the student to re-open or reload their app.

2. **Shared `userId` Collision & Session Conflation Elimination:**
   - Root Cause: In `BiometricService.syncStudentSecurityToFirestore` and `restoreStudentSecurityFromFirestore`, the code included `payload['userId'] = currentAuthUid` and `healPayload['userId'] = currentAuthUid`. When an admin or staff tested or restored PINs while logged in with one Google account (e.g. `Z4vp6LzMXkMaLbGfUm7XEyfcr463`), that Google account UID was erroneously stamped onto multiple student documents (both Ashish and Srikrishnadatta). When `BiometricLockScreen` queried `.where('userId', isEqualTo: authUid).limit(1)`, Firestore returned Ashish, subscribing Chrome to Ashish's document. When admin reset Ashish's PIN, Chrome unlocked; but upon navigating to `/app/student/home`, `currentStudentProvider` read the locally cached student ID for that browser profile (`dHWJekG8DtXm0lQJiX6d` / Srikrishnadatta), causing the dashboard to display Srikrishnadatta instead of Ashish.
   - Guardrails:
     a) **Zero `userId` Overwriting in Security Services:** `BiometricService` must NEVER mutate `userId` on student documents. Primary authentication bindings belong exclusively to the formal onboarding & login pipeline (`StudentProvisioningService`).
     b) **Admin Reset Device Isolation:** `BiometricService.adminResetStudentPin` must strictly clear local `SharedPreferences` keys for `studentId`. It must NEVER clear keys matching `FirebaseAuth.instance.currentUser?.uid` (the admin's own session), preventing reception counter lockouts.
     c) **Session-First Lock Listener Binding:** In `BiometricLockScreen`, the live security listener must prioritize `currentStudentProvider.value?.id` and `cached_student_doc_id_${libraryId}_${authUser.uid}` over unindexed or ambiguous queries, ensuring a locked device only ever listens to the exact student session active on that browser.


---

## 40. Calendar-Month Dynamic Pro-Rata Approval & Advance Credit Adjustment (Learned Nov 2026)

1. **Dynamic Approval Re-Calculation (Option A Enforced, Option B Rejected):**
   - Root Cause: In `RequestDetailScreen._promptPaymentAfterApproval`, `defaultAmount` read stale `proratedFee` stored at request creation (e.g. Nov 6 for 25 days = ₹580), while approval took place days later (Nov 16). The code also set a rolling 30-day month (16 Nov -> 16 Dec) while charging the 25-day fee of ₹580, resulting in 31 days given for ₹580 without collecting the full ₹700 monthly price.
   - Guardrail: When approving an admission request, the system must ALWAYS dynamically recalculate pro-rata from the approval timestamp to the calendar month-end (`PlanCalculatorService.calculateSmartPlan(plan: matchedPlan, fromDate: DateTime.now())`). Rolling 30-day cycles (Option B) are strictly prohibited for calendar-month aligned libraries. All plan end dates on approval must strictly terminate at the calendar month-end (e.g., Nov 30 23:59:59).

2. **Unutilized Pro-Rata Advance Credit Carry-Forward (Wallet Balance):**
   - Architectural Standard: If a student paid a pre-calculated pro-rata amount (e.g., ₹580 for 25 days) but approval was delayed so actual usage is fewer days (e.g., 15 days = ₹350), the unutilized surplus (`₹580 paid − ₹350 usage = ₹230`) must be credited to the student's `walletBalance`.
   - On the next recurring cycle (December 1 renewal), `RecordPaymentScreen` surfaces this credit via an interactive banner (`Unused Proration Balance: ₹230 Available`).
   - Tapping **Apply Credit** automatically offsets the December plan price (`₹700 − ₹230 = ₹470 net payable`) and updates the student ledger transparently, matching the gold standard of Stripe Billing, Nexudus, and telecom utility billing.

---

## 41. Lifecycle Notification Dispatch, Cross-ID Targeting & Sticky Rejection Invariants (Learned Nov 2026)

1. **Rejection Notification Omission & Parameter Dropping Root Causes:**
   - Root Cause A: In `RequestDetailScreen._rejectRequest()`, the handler updated Firestore `status: 'rejected'` and logged audits, but completely omitted calling `AppNotificationService.sendNotification(...)`. Zero notification documents were written to Firestore.
   - Root Cause B: In `RequestListScreen._promptReject()`, line 1540 called `_updateRequestStatus(context, libraryId, request.id, 'rejected', reason: reasonController.text)` without passing `requestItem: request`. In `_updateRequestStatus()`, `requestItem` defaulted to `null`, causing `if (requestItem != null)` at line 1380 to evaluate to `false` and bypass notification dispatch entirely.
   - Guardrails:
     a) Every rejection flow (`RequestDetailScreen`, `RequestListScreen`, `RequestRepository`) MUST atomically write an in-app notification to `libraries/{libId}/notifications` targeting the student.
     b) Rejection notification titles must include explicit feedback: `$reqTitle Rejected ❌`, containing the admin's rejection reason in the body (`could not be approved: "$reason"`).
     c) Mandatory metadata: `{ 'requestId': id, 'studentId': studentId, 'studentUserId': authUid, 'rejectionReason': reason, 'type': type }`.

2. **Universal Lifecycle Audit & Auto-Dispatch Enforcement:**
   - Forensic audit revealed that multiple critical lifecycle events lacked notifications:
     a) **Plan Renewal Approval via Counter Payment** (`RequestDetailScreen._recordPaymentAndReceipt`): Now auto-dispatches `Plan Renewal Confirmed! 🎉` with receipt number and new validity dates.
     b) **Profile Update Approval** (`RequestDetailScreen:514`): Now auto-dispatches `Profile Details Updated ✅`.
     c) **Desk De-allocation / Vacating** (`SeatRepository.unassignStudent`): Now auto-dispatches `Desk De-allocated 🪑` notifying the student that their desk was vacated so they can re-select.

3. **Dual-ID Cross-Matching Filter Architecture:**
   - Root Cause: Notifications written with `targetUserId = student.id` failed to display if the student's notification sheet initialized before `student.id` resolved (using `FirebaseAuth.currentUser.uid`), and vice-versa.
   - Guardrail: In `studentNotificationsStreamProvider`, notifications are matched if `n.targetUserId == effectiveId || n.targetUserId == authUid || n.targetUserId == studentId` OR if `n.metadata['studentId'] == studentId || n.metadata['studentUserId'] == authUid || n.metadata['userId'] == authUid`. Cross-ID metadata matching guarantees that personal notifications are never silently filtered out due to ID type asymmetry.

4. **Sticky Rejection Feedback Banner on Student Dashboard (Zero Disappearing Requests):**
   - Root Cause: When a renewal was pending, `student_home_screen.dart` rendered the "Desk Renewal Registered" card. Upon rejection, the card instantly vanished into thin air because `pendingRenewal` only matched `status == 'pending'`, leaving the student confused with zero visible feedback.
   - Guardrail: When a student request is rejected, `studentRecentRejectedRequestProvider` streams the rejected document (within 7 days). `StudentHomeScreen` renders a prominent Amber/Red feedback banner directly above the pass showing:
     a) Clear header: `Plan Renewal Request Rejected`
     b) Exact admin reason box: `Reason: "fake"`
     c) 1-tap WhatsApp deep link (`https://wa.me/...`) to contact reception.
     d) 1-tap "Re-apply / Change Plan" button routing to `Routes.studentRenew`.
     e) Dismiss button persisting `dismissed_rejected_<requestId>` in `SharedPreferences`.

---

## 42. Counter Renewal Approval Protocol, Sequential Receipt Invariants & Payment Deduplication (Learned Nov 2026)

1. **Sequential Receipt Generation & Double-Collection Linkage (`student_provisioning_service.dart`):**
   - Root Cause: In `StudentProvisioningService.approveRenewalPayment`, receipt numbers were synthesized using random document ID substrings (`'REC-${DateTime.now().year}-${recRef.id.substring(0, 6)}'`), resulting in non-sequential identifiers like `REC-2026-RE1S9V`. Furthermore, the generated `payments` document omitted `'receiptId'` and `'receiptNumber'`, preventing bidirectional cross-referencing between payments and receipts.
   - Guardrails:
     a) All renewal approvals must generate standardized sequential receipt numbers exclusively through `ReceiptRepository.getNextReceiptNumber(libraryId)` (`REC-YYYY-XXXX`).
     b) The `payments` document must explicitly store `receiptId: recRef.id`, `receiptNumber: recNum`, `paidAmount`, `totalFee`, `remainingDue`, and `referenceNumber`.
     c) The `receipts` document must explicitly store `paymentId: payRef.id`, `receiptNumber: recNum`, `paidAmount`, `totalFee`, `remainingDue`, and `referenceNumber`.
     d) If partial payment is collected (`remainingDue > 0`), the student record must atomically update `studentUpdates['pendingDueBalance'] = remainingDue`.

2. **Student Payment History Stream Deduplication & Accurate Ledger Sums (`my_payment_history_screen.dart`):**
   - Root Cause: Because the `payments` collection lacked a populated `receiptId`, `MyPaymentHistoryScreen` (which streams both `receipts` and `payments` to support legacy records) treated the renewal as two separate payments (`REC-2026-RE1S9V` and `Payment #ZZQOF6`), displaying duplicate ?3,800 entries and inflating Ashish's Total Paid Fees from ?8,500 to ?12,300 (5 records instead of 4).
   - Guardrails:
     a) Implement multi-key deduplication tracking across both streams: `seenReceiptIds`, `seenPaymentIds`, `seenReceiptNumbers`, and `seenRequestIds`.
     b) For legacy unlinked payments, apply a 15-minute fuzzy time window check: if a payment has the same amount as an existing receipt within 15 minutes, it is deduplicated as a mirror entry.
     c) The Total Paid Fees calculation (`totalPaid`) must sum only unique deduplicated transactions, guaranteeing exact ledger reconciliation.

3. **Renewal Approval Modal UX & Multi-Factor Information Hierarchy (`request_list_screen.dart`):**
   - Root Cause: The previous "Collect Payment & Approve Renewal" dialog displayed only Student Name, Plan Name, and Amount, with a hardcoded dropdown defaulting to "Other". Admins had no visibility into assigned desk, validity cycle, remaining dues, or payment reference IDs.
   - Guardrails:
     a) **Desk & Cycle Context:** Display the student's assigned desk badge (`Desk #6 • Cozy Hall`) and cycle preview (`23 Nov 2026 ? 23 May 2027`).
     b) **Editable Amount & Real-Time Due Math:** Provide an editable Collected Fee Amount field with live helper text calculating remaining due balance in real time.
     c) **Payment Method & Reference:** Default to 'UPI', dynamically surfacing a UPI UTR / Bank Reference Number field with a 1-tap clipboard paste button.
     d) **Receipt Dispatch & Soundbox:** Include a pre-checked WhatsApp receipt toggle and trigger real-time voice announcement via `SoundboxService.announcePayment(amount: paidAmt, studentName: studentName)`.

4. **Soft-Lock Immediate Release on Request Rejection (`request_list_screen.dart`):**
   - Root Cause: Rejecting an admission or seat shift request in `RequestListScreen` updated request status and sent notifications, but failed to call `releaseSoftLock` on the candidate desk. The desk remained trapped in `reserved` soft-lock status until cache expiry.
   - Guardrail: In `RequestListScreen._updateRequestStatus`, when `newStatus == 'rejected'`, immediately call `ref.read(seatRepositoryProvider).releaseSoftLock(libraryId, targetSectionId, targetSeatId)` to return the seat to available pool with zero latency.

5. **Sentinel Invariant Engine Duplicate Seat Auto-Heal Resilience (`sentinel_invariant_engine.dart`):**
   - Root Cause: Sentinel Guardian flagged `CRITICAL: Duplicate Desk Allocation: Desk #20` (Srikrishnadatta & Shubham Dixit simultaneously linked to Desk #20), but 1-tap auto-heal failed with `"Failed to auto-heal: Duplicate Desk Allocation: Desk #20"` because `batch.update()` threw an exception if a conflicting student record was missing or archived, and audit logger throws were uncaught.
   - Guardrail: In `autoHealDuplicateSeatAllocation`, verify student snapshot existence (`sSnap.exists`, `retSnap.exists`), use `batch.set(..., SetOptions(merge: true))` for fault-tolerant upserts, and isolate audit logs in try/catch to guarantee 100% resilient auto-heal execution.

---

## 43. Row/Column Suppression, Hospitable Member Copywriting & Dynamic Text Streaming (Learned Nov 2026)

1. **Complete Row & Column Suppression Across Entire System:**
   - Root Cause: Physical study libraries operate on assigned desk numbers (`Desk #21`, `Desk #35`), but the public viewer generated spreadsheet coordinates (`C1..C10` column headers) and desk detail sheets showed `Row 1, Column 5`. This created a cold, Excel-like user experience.
   - Guardrails:
     a) **Public Viewer (`public/seats/index.html`):** Remove all `column-headers-row` and `col-header` (`C1..C10`) DOM generation. Maintain clean architectural floor plans oriented by room landmarks (e.g. `MAIN ENTRANCE & RECEPTION DESK` and `ROAD-FACING QUIET STUDY ZONE`).
     b) **Desk Details Sheet (`seat_detail_sheet.dart`):** Replace `'Row ${seat.row + 1}, Column ${seat.col + 1}'` with `'Dedicated Study Desk • Quiet Zone'`. Desk titles must always invoke `SeatHelper.formatDeskLabel(seatId: seat.id, rawLabel: seat.label)`.
     c) **Admin Section Creator (`add_section_screen.dart`, `seat_map_screen.dart`):** Replace technical `'Rows'` and `'Columns'` form labels with architectural room terms: `'Desk Rows (Hall Depth)'` and `'Desks per Row (Hall Width)'`.

2. **Polite, Hospitable & Courteous Member Copywriting:**
   - Root Cause: Robotic developer terminology (`VERIFYING UTR`, `PAY AT DESK`, `Reason: fake`, `Request Rejected ❌`, `Maintenance`) caused student confusion and felt blunt or unfriendly.
   - Guardrails:
     a) **Payment Badges:** Replace `VERIFYING UTR` with `PAYMENT UNDER REVIEW 🙏` and `PAY AT DESK` with `PAY CASH AT RECEPTION`.
     b) **Action Required Notifications:** When an admin rejects or flags an application, notifications must use courteous framing: `$reqTitle Update • Action Required ℹ️` with body `"...requires an update: $reason. Kindly visit reception or contact WhatsApp for assistance. 🙏"`.
     c) **Reason Labels:** Replace blunt developer labels like `Reason: "fake"` with empathetic service labels: `Note from Reception: "...""`.
     d) **Legend Labels:** Use `Facility Care 🧹` or `Sanitization` instead of technical `Maintenance`.

3. **Dual-Stage Financial Reconciliation vs Real-Time Soundbox Announcement:**
   - Root Cause: When students scan the library's dynamic UPI QR code (`7276969070@upi`), real funds hit the library's bank account in 2 seconds, causing the counter's physical merchant Soundbox (Paytm/PhonePe) to verbally announce: *"Payment of ₹3,800 received"*. However, inside the app, the student's pass is not yet active because the renewal request is pending counter approval.
   - Guardrails:
     a) Clearly communicate the two distinct financial stages to both student and admin.
     b) For Student: Render a calming status banner: *"Payment received at bank • Pass activating shortly 🙏"*.
     c) For Admin: In Requests Hub, elevate incoming UPI submissions with a prominent 1-tap "Collect & Approve" action so the counter staff can match the spoken Soundbox announcement with the on-screen student in 1 click.
     d) In `SoundboxService.formatAnnouncement`, check both `seat` and `desk` prefixes to prevent double-prefix synthesis (`Seat Desk #21`).

4. **Dynamic Administrator Text Configuration Streaming:**
   - Root Cause: Hardcoded library slogans, guidelines, payment instructions, and helpline numbers required code recompilation and redeployment whenever library policies changed.
   - Guardrail: All public and student texts (Welcome slogan, WiFi notes, Reception timings, WhatsApp helpline, UPI ID, and Notice Board rules) must stream dynamically from Firestore settings (`libraries/{libraryId}/settings/communications` and `library_profile`) with resilient fallbacks, reflecting changes across all devices in real time without app updates.

---

## 44. Admin PIN Reset Dedicated Dialog & Route Popping Immunity (Learned Nov 2026)

1. **Dedicated PIN Setup Dialog vs Generic Settings Conflation:**
   - Root Cause: When an admin remotely reset a student's PIN or when a student verified their identity via Google OAuth, the success dialog offered `"Set New PIN Now"`. However, clicking this button invoked `_unlockApp()` asynchronously while simultaneously calling `SecuritySettingsDialog.show()`. `_unlockApp()` popped the active route or triggered navigation away to `/student/home`, instantly closing the settings dialog before it could open. Furthermore, `SecuritySettingsDialog` is a multi-option settings panel (biometrics, timeouts, screenshot protection), NOT a focused 4-digit PIN setup window. This left the user stranded back on the lock screen with an empty PIN keypad and no way to set their PIN.
   - Guardrails:
     a) **Dedicated PIN Dialog (`SecuritySettingsDialog.showSetPinDialog`):** Provide a focused, direct 4-digit PIN dialog with numeric keypad input, confirmation matching, and clear error banners.
     b) **Sequential Navigation (Never Unlock Before Setting PIN):** Never call `_unlockApp()` prior to showing `showSetPinDialog`. Await the dialog's completion: if the PIN is configured, sync to Firestore and local storage, show confirmation feedback, and then call `_unlockApp()`.
     c) **Admin Flag Cleanup (`BiometricService.clearAdminPinResetFlag`):** Whenever the user completes or skips PIN setup or taps "Go to Dashboard", immediately delete `pinResetByAdmin` and `pinResetMessage` from both `students/{studentId}` and `users/{authUid}` to prevent infinite notification loops on subsequent snapshot streams.
     d) **Keypad Infinite Loop Immunity:** If a student without an active PIN attempts to enter digits on the lock keypad, do not loop into raw reset dialogs. Offer direct PIN configuration or unlock to prevent blocking students from accessing their passes.




---

## 45. Test Version Invariant Synchronization & Binary Build Pipeline Discipline (Learned Nov 2026)

1. **System QA Test Suite Version Invariants (`test/system_qa_test.dart`):**
   - Root Cause: Version bumps in `pubspec.yaml`, `app_constants.dart`, and `whats_new_service.dart` triggered test assertion failures in Tests 67, 109, and 126 because tests asserted against hardcoded version strings (`'1.5.58'` and `2075`).
   - Guardrail: Whenever a new version is released, synchronize the assertions in `test/system_qa_test.dart` (Tests 67, 109, 126) to match the new `AppConstants.appVersion` and `AppConstants.buildNumber` before running regression tests. Verify all 193+ automated QA tests pass with 0 failures (`flutter test test/system_qa_test.dart`).

2. **JDK 17 Toolchain & Release Binary Packaging Protocol:**
   - Root Cause: Flutter Android builds fail if `JAVA_HOME` is unset or points to an incompatible Java version.
   - Guardrails:
     a) Ensure `JAVA_HOME` points to Temurin JDK 17 (`C:\Users\ksonp\.bubblewrap\jdk\jdk-17.0.19+10`) and Flutter is configured via `flutter config --jdk-dir`.
     b) Always generate all 4 production artifacts signed with the permanent release keystore:
        - `StudyLibrary-arm64-v8a.apk` (Lean 64-bit ARM, default download)
        - `StudyLibrary-armeabi-v7a.apk` (Legacy 32-bit ARM)
        - `StudyLibrary.apk` (Universal FAT APK)
        - `StudyLibrary.aab` (Google Play App Bundle)
     c) Stage all assets in `release_assets/v<version>/` and create the GitHub Release with all 4 binaries uploaded via `gh release create`.
     d) Perform byte-range health checks (`curl -s -L -r 0-10 -o NUL -w "%{http_code}"`) to verify all assets return `206 Partial Content` (or `200 OK`) before deploying hosting.

---

## 46. Notification Role Fencing, Local Read/Dismissal Persistence & Batch Isolation Standard (Learned Nov 2026)

1. **Strict Notification Role Fencing (`targetRole == 'admin'`):**
   - Root Cause: Administrative alerts (such as `Profile Update Request` dispatched when a student submitted profile edits) attached `metadata['studentId']` for administrative reference. In `studentNotificationsStreamProvider`, notifications were matched against `metadata['studentId']` before evaluating `targetRole`. This leaked administrative alerts into the student notification center with confusing prompts (e.g. "shubham dixit requested profile updates").
   - Guardrails:
     a) In `studentNotificationsStreamProvider`, enforce an immediate strict role fence `if (n.targetRole == 'admin') return false;` at the very beginning of the evaluation loop. Students must NEVER receive, view, or count alerts meant for administrators.
     b) Filter sensitive personal types (`receipt`, `payment`, `seat`, `renewal`) to ensure they only render when explicitly addressed to the student's direct ID or Auth UID.

2. **Hybrid Local Persistence (`SharedPreferences`) for Zero-Stuck Notification Badges:**
   - Root Cause: Public broadcast notices (`targetRole == 'all'`) and cross-role documents cannot be deleted or modified in Firestore by student client credentials under `firestore.rules`. When students tapped "Clear Read", "Mark all read", or swiped to dismiss, Firestore rejected the write, causing notifications and unread badge counts to persistently stick on screen after reloading.
   - Guardrails:
     a) Implement hybrid local persistence using `_locallyReadIds` and `_locallyDismissedIds` backed by `SharedPreferences` keys (`locally_read_notifs_${libraryId}_${userId}` and `locally_dismissed_notifs_${libraryId}_${userId}`).
     b) Both `studentNotificationsStreamProvider` and `adminNotificationsStreamProvider` must filter out any locally dismissed notification IDs and mark read state instantaneously (`copyWith(read: true)`).
     c) Notification center sheets must maintain local optimistic sets and update the UI instantly (0ms latency) upon swipe-to-dismiss, checkmark tap, "Mark all read", or "Clear Read".

3. **Atomic Batch Isolation & Fault-Tolerant Operations:**
   - Root Cause: `markAllAsRead` and `clearAllRead` previously bundled multiple notification documents into a single Firestore `WriteBatch`. If a single broadcast document failed security rule checks, Firestore aborted the entire batch with `PERMISSION_DENIED`, leaving all valid personal notifications unread and stuck.
   - Guardrails:
     a) Eliminate monolithic `WriteBatch` writes for heterogeneous notification lists.
     b) Use resilient individual document operations (`doc.reference.update(...).catchError((_) {})` and `doc.reference.delete().catchError((_) {})`) alongside immediate local state persistence.
     c) Permission failure on a shared or broadcast item must NEVER block personal items from being updated or cleared.

---

## 47. Student Admission Approval Pending Payment Lifecycle, Zero Fake Receipt Synthesis & Local Role Fencing Discipline (Learned Nov 2026)

1. **Zero Fake Receipt Synthesis for Unpaid Students:**
   - Root Cause: In `my_receipts_screen.dart`, when a student had an approved admission but the counter had not yet recorded their initial fee payment, `hasActiveAdmission` checked `student.seatId != null || student.planId != null`. This condition was true immediately upon admission approval, triggering in-memory synthesis of a fake `REC-2026-CC20260016 [PAID] ₹700` receipt claiming "100% Settled • 0 Pending Dues" before any payment was actually collected.
   - Guardrails:
     a) Replace broad `hasActiveAdmission` with strict `hasPaidAdmission`: `student.membershipStatus == MembershipStatus.active && student.planStartDate != null && student.planEndDate != null`.
     b) When `student.planId != null` and fee payment is not recorded (`isPaymentPending`), display a dedicated **"ADMISSION APPROVED • AWAITING PAYMENT"** invoice card with `UNPAID / PENDING AT RECEPTION` and a 1-tap WhatsApp contact button. Never synthesize `[PAID]` receipts or claim fees are settled.

2. **Digital ID Card Provisional State Determination (`Awaiting Payment`):**
   - Root Cause: In `my_id_card_screen.dart`, ternary status chains fell through to `'ACTIVE PASS'`, `'Active'`, and live security clocks for newly approved students whose `membershipStatus` was `inactive` or `pending` (awaiting initial counter fee payment).
   - Guardrails:
     a) Formulate `isPaymentPending`: `effectiveStatus == MembershipStatus.inactive || effectiveStatus == MembershipStatus.pending || (student.planEndDate == null && effectiveStatus != MembershipStatus.active)`.
     b) When `isPaymentPending` is true:
        - Front badge: Display `'AWAITING PAYMENT'` (Amber) instead of `'ACTIVE PASS'`.
        - Validity label: Display `'Awaiting Payment'` instead of `'Active'`.
        - Verification QR: Overlay `'PENDING'` badge on the card back.
        - Bottom ticker: Display `'PENDING HH:mm:ss'` with amber indicator.
        - Render dedicated "Admission Approved • Pass Awaiting Fee Payment" status banner with direct counter contact.

3. **Student Home Screen Smart Pass Invariant (`Fee Pending`):**
   - Root Cause: In `student_home_screen.dart`, the smart pass footer displayed `'Fee ₹700 Settled'` with a green checkmark next to `'No Active Plan'`, presenting conflicting information to the student.
   - Guardrail: When `student.planEndDate == null` or membership status is `inactive`/`pending`, display `'Fee ₹${plan.price} Pending'` (or `'Payment Awaiting'`) with an amber `Icons.schedule_rounded` icon. Never display `'Fee Settled'` when payment has not been recorded in Firestore.

4. **Membership Screen Expiry Disambiguation:**
   - Root Cause: In `my_membership_screen.dart`, unpaid students with `planEndDate == null` were marked with a red `[Expired]` badge alongside an "Active Pass" subtitle.
   - Guardrails:
     a) Differentiate `isPaymentPending` from `isExpired`. Unpaid students whose plan has not started are NOT expired.
     b) Display badge `'Payment Pending'`, subtitle `'Starts on fee payment'`, progress label `'Starts Upon Payment'`, and seat guarantee pill `'🔒 Desk is held for you • Settle fee at reception to activate'`.
     c) Render amber quick action button: `'Pay Fee / Settle at Counter'`.

5. **Local Device Notification Role Fencing:**
   - Root Cause: In `AppNotificationService.sendNotification`, calling `NotificationService.showNotification` showed OS-level local push notifications on the current device regardless of `targetRole`. When a student submitted a self-registration, their phone triggered both the student confirmation and the admin alert (`📋 New Registration Request... Please review and approve`).
   - Guardrail: In `AppNotificationService.sendNotification`, evaluate the current device's logged-in role (`cached_current_user_role` or `persisted_role`). If `targetRole == 'admin'` and the current session is a `student`, suppress the local push notification entirely.




---

## 48. Zero-Junk OCR Auto-Fill, Ledger Amount Fallback & Clean Auth Invariants (Learned Nov 2026)

1. **Request Ledger Amount Resolution Fallback (`Total Payable Amount`):**
   - Root Cause: In `RequestDetailScreen`, the ledger card read only `data['amount']`. In desk cash registrations, the payable fee was stored under `data['proratedFee']` or `studentData['proratedFee']` (`₹190`). Because `data['amount']` was null, the UI displayed `Total Payable Amount: ₹—`.
   - Guardrail: Always resolve fee amounts with multi-tier fallbacks:
     ```dart
     final amount = (data['amount'] as num?)?.toDouble() ??
         (data['proratedFee'] as num?)?.toDouble() ??
         (studentData['proratedFee'] as num?)?.toDouble() ??
         (studentData['amount'] as num?)?.toDouble() ??
         (data['totalPayable'] as num?)?.toDouble() ??
         (data['planPrice'] as num?)?.toDouble();
     ```
     Ensure `RequestItem.fromFirestore` and `ReviewSubmitScreen` also explicitly persist `amount` across all layers so ledger amounts never render as `₹—`.

2. **Zero-Junk OCR Auto-Fill & Token Shift Immunity:**
   - Root Cause: Unvalidated regex extraction and shifting index offsets on newer PVC Aadhaar cards caused the applicant's name ('Vikrant Vaijanath Dhondge') to be extracted into the `dob` field. The form and preview screens blindly displayed this text as Date of Birth.
   - Guardrails:
     a) **OcrResult Sanitization (`result.sanitized(type)`):** Every OCR extraction must be passed through `OcrResult.sanitized()`. Any candidate that fails strict regex or semantic validation (`GovIdValidator.isValidDob`, `isValidGovId`, etc.) is immediately discarded to `null`.
     b) **Clean Manual Input Fallback:** Form fields must only auto-fill if confidence is 100% verified. If uncertain or invalid, fields must remain completely blank for clean, hassle-free manual entry without showing confusing red error badges or noisy junk strings.
     c) **DOB Sanitized Display:** Formatters (`_formatDob`) and view widgets must discard unparseable or out-of-range dates (valid birth year range: 1920 to current year). If invalid, suppress the Date of Birth row entirely.

3. **Strict Prohibition on Mobile Account Linking & QR Scanners:**
   - Root Cause: An obsolete 'Link Mobile Number' button existed in the `/login` 'Account Not Found' dialog, and a non-functional green 'Scan Aadhaar QR Code' tab existed in `IdScanScreen`, violating Master Rule 1 (Email/Password & Admin-assisted onboarding only; zero SMS OTP / mobile linking).
   - Guardrails:
     a) Remove all mobile linking buttons and dialogs from login flows. Direct unverified users to tap 'Register New' or sign in with their registered email.
     b) Remove camera QR code scanners for Aadhaar. Use the clean, standardized document photo scan and gallery upload pipeline with sanitized OCR parsing.

---

## 49. Receipt Date Sync, Payment Modal Ledger, ID Card Theme & Security PIN Flow (Learned Nov 2026)

1. **Receipt Date Synchronization with Admin Date Adjustments:**
   - Root Cause: When an admin adjusted admission and plan cycle dates in `student_detail_screen.dart`, only `students/{id}` was updated, leaving `libraries/{libId}/receipts` with stale timestamps. This caused discrepancies where WhatsApp messages reflected adjusted dates (`15 Nov → 30 Nov`) while app receipts and PDF invoices retained default monthly cycle dates (`23 Nov → 30 Nov`).
   - Guardrail: When adjusting student cycle dates or approving requests with custom start/end dates, always query and update active receipts (`libraries/{libId}/receipts`) matching `studentId == s.id` so that `validFrom` and `validTo` remain 100% synchronized across the Student Dossier, Receipts Screen, PDF invoices, and WhatsApp notifications.

2. **Approval Payment Modal Contextual Fields & Custom Date Pickers:**
   - Root Cause: `_promptPaymentAfterApproval` and `_promptRenewalPaymentAfterApproval` showed only an amount box and a generic dropdown, lacking custom cycle date selectors and payment-specific transaction fields (UTR, bank name, card digits, cash notes).
   - Guardrails:
     a) Provide interactive `Plan Start Date` and `Plan End Date` pickers with a real-time duration counter (`X Days (dd MMM yyyy → dd MMM yyyy)`).
     b) Provide contextual dynamic inputs: UPI Transaction ID / UTR with 1-tap clipboard paste button; Bank name + IMPS/NEFT reference; Card details + auth slip #; Cash notes / received by.
     c) Include an instant Soundbox speaker announcement toggle (`🔊 Announce Payment on Soundbox Speaker`).

3. **ID Card Template Custom Color Persistence & Preset Switch Guard:**
   - Root Cause: `IdCardTemplateSettings.copyWith` could not clear `customColorHex`, and choosing a preset theme in `id_card_customizer_screen.dart` didn't delete `customColorHex` from Firestore. Because `customColorHex ?? cardTheme` was used, stale custom hex colors permanently overrode preset themes on the card back, resulting in a color mismatch (front amber vs back navy).
   - Guardrail: Always provide `bool clearCustomColor = false` in `IdCardTemplateSettings.copyWith`. When selecting any named preset (e.g., `amberClassic`), set `clearCustomColor: true` and write `customColorHex: FieldValue.delete()` to Firestore so custom colors do not clobber preset card styles.

4. **Multi-Step In-Dialog Security PIN Reset Flow:**
   - Root Cause: Tapping "Set New PIN Now" in the "Security PIN Reset by Admin" dialog called `Navigator.pop(ctx)` and attempted to launch a second modal (`showSetPinDialog`). On Flutter Web, navigator collisions and dialog race conditions dismissed the popups and left the user stranded on the locked keypad without showing the PIN setup window.
   - Guardrail: Never dismiss a modal dialog to open a second one for sequential security flows. Embed the PIN setup form directly inside the reset dialog via in-place state switching (`isConfiguringPin = true`). Allow the user to enter and confirm their new 4-digit PIN directly inside the same window, saving and unlocking seamlessly with zero navigator race conditions.

5. **Counter Soundbox Audio Synthesis (Web Audio & Native TTS):**
   - Root Cause: Soundbox announcements on desktop web failed due to suspended Web Audio contexts and lack of native text-to-speech fallback on mobile.
   - Guardrail: Deploy dual-mode audio synthesis using `flutter_tts` on mobile and Web Audio API with auto-resume (`ctx.resume()`) and SpeechSynthesis on web, with standardized payment confirmations in Marathi, Hindi, and English.

6. **Mobile Viewport Wrapping for Header Actions ("Set Due / Set Amount"):**
   - Root Cause: Unconstrained horizontal `Row` containing "Admitted", "Adjust Dates", and "Set Due" clipped the "Set Due / Set Amount" button on narrow viewports (<390px).
   - Guardrail: Wrap all variable-width header action clusters in `Wrap(spacing: 10, runSpacing: 6)` and provide a minimum bottom scroll inset of `80 + MediaQuery.of(context).padding.bottom` across all scrollable views.

---

## 50. Dynamic Adjusted Dates Fee Math, Pro-Rata Engine & Direct Collection Flow (Learned Nov 2026)

1. **Dynamic Pro-Rata Fee Calculation Engine:**
   - Root Cause: When admin adjusted plan dates (e.g., Nov 15 to Nov 30 = 16 days), `_showAdjustDatesDialog` had `if (recalculateDueProRata && currentPendingDue > 0)`, which silently bypassed setting `pendingDueBalance` and `totalFee` when `currentPendingDue == 0`. When admin subsequently clicked "Record Fee", the payment screen had no knowledge of adjusted dates, defaulted `validFrom` to `DateTime.now()` (23 Nov), and billed 8 days (₹350) instead of 16 days (₹373).
   - Guardrail: Always expose dynamic pro-rata fee math ($\text{Daily Rate} = \text{Plan Price} / \text{Standard Days}$, $\text{Pro-Rata Fee} = \text{Selected Days} \times \text{Daily Rate}$) and allow updating `pendingDueBalance` and `totalFee` whether existing dues are zero or positive.

2. **Direct Collection Action (`Save & Collect Fee`):**
   - Root Cause: Admin had to adjust dates, close the dialog, and separately find and tap "Record Fee", losing date context and forcing manual re-entry.
   - Guardrail: Always provide a direct action button: `Save & Collect Fee (₹$due)` in date adjustment dialogs. Tapping it saves updates to Firestore, synchronizes active receipts, closes the dialog, and directly navigates to `RecordPaymentScreen` passing `initialStartDate`, `initialEndDate`, `overridePlanPrice`, and `overrideDue`.

3. **Date Context Inheritance in `RecordPaymentScreen`:**
   - Root Cause: `RecordPaymentScreen` lacked `initialStartDate` and `initialEndDate`, falling back to `DateTime.now()` or jumping to next month via advance continuity logic (`planEndDate + 1`).
   - Guardrail: Always accept `initialStartDate` and `initialEndDate` in `RecordPaymentScreen`. When present, initialize `_customStartDate` and `_customCustomExpiryDate`, set `_extendValidity = false` (paying for configured cycle), and pre-calculate pro-rata fees from the selected plan's daily rate.

4. **Retroactive Receipt Self-Healing in PDF & In-App Previews:**
   - Root Cause: Receipts created mid-cycle burned transaction dates (e.g. `23/11/2026 to 30/11/2026`) into `validFrom`, conflicting with the student's actual subscription cycle (`15/11/2026 to 30/11/2026`).
   - Guardrail: In `PdfService.generateReceiptPdf` and `receipt_preview_screen.dart`, when a receipt's `validTo` matches the student's `planEndDate` and `student.planStartDate` is earlier than `receipt.validFrom`, dynamically self-heal `effectiveValidFrom` to `student.planStartDate` and display `($cycleDays Days)` so all printed and previewed receipts accurately reflect the full subscription coverage.

---

## 51. Notification Audience Role Fencing & Student Portal Screenshot Protection (Learned Nov 2026)

1. **Notification Audience Role Fencing & Self-Notification Suppression:**
   - Root Cause: In `AppNotificationService.sendNotification`, `shouldShowLocally` defaulted to `true`. When an admin approved a student or assigned a desk on their Android phone, the method dispatched the Firestore write and immediately called `NotificationService.showNotification` locally on the sender's own device! Because `currentRole` fell back to `'student'`, the admin's phone popped up student-targeted alerts in the Android notification drawer: `"Admission Approved! 🎉 Hello Shubham katle!"` and `"Desk Allocated 🪑 You have been assigned to Seat #15."`. Similarly, announcements posted by admin buzzed the admin's own phone.
   - Guardrails:
     a) `shouldShowLocally` must default to `false`. The initiating device never needs a local status-bar notification for an action it just performed locally.
     b) When `currentRole == 'admin'`: NEVER display student-targeted notifications (`targetRole == 'student'`), such as admission approvals, desk allocations, payment confirmations, or student broadcasts.
     c) When `currentRole == 'student'`: NEVER display admin-targeted notifications (`targetRole == 'admin'`). Student notifications only display if `targetUserId` matches the student's Auth UID or student document ID, and the action was not initiated by the student.
     d) On role persistence (`persistUserRole`) and startup (`SplashScreen`), automatically synchronize FCM topic subscriptions (`admin-$safeLibId` vs `student-$safeLibId`) to guarantee background pushes never deliver to the wrong role.

2. **Screenshot Protection Role Separation (Student Protection Plane vs Admin Control Plane):**
   - Root Cause: Screenshot Protection (`FLAG_SECURE`) was applied globally to the Android Activity window on startup (`app.dart`) and immediately upon toggling in `SecuritySettingsDialog`. Consequently, the Admin's phone was locked down from screenshots of admin reports, seat layouts, and student rosters, while `StudentHomeScreen` (which displays the digital smart pass, QR code, and desk info) and `MyReceiptsScreen` completely lacked `SecureScreenMixin` and were unblocked.
   - Guardrails:
     a) Admin Exemption: The Admin Portal must NEVER be blocked from taking screenshots (`applyNativeSecureFlag(false)`). Library owners and staff require screenshot capability for accounting, audit receipts, seat maps, and support.
     b) Student Enforcement: Screenshot Protection controls exist in the Admin Portal (`SecuritySettingsDialog`), but the enforcement plane is exclusively the **Student Portal**.
     c) When `role == 'student'`, enforce `FLAG_SECURE` on `StudentHomeScreen`, `MyIdCardScreen`, and `MyReceiptsScreen` whenever the library policy (`screenshotProtectionEnabled`, default: `true`) is active. When admin turns the toggle OFF, student screens are unblocked.

---

## 52. Ledger Truthfulness, Exclusive Desk Holds & Mixed-Case Applicant Onboarding Integrity (Learned Nov 2026)

1. **Zero-Payment Approval Ledger Integrity & No Synthetic 90/91-Day Receipts:**
   - Root Cause: Multiple surfaces treated any non-null `planId` (or unverified fallback `enteredAmount == 0 -> amount`) as paid:
     a) `StudentProvisioningService` defaulted unpaid new admissions' `planStartDate`/`planEndDate` to 30 days and treated unpaid renewals (`paidAmount == 0` / `skipPayment: true`) as active paid extensions.
     b) `RequestListScreen._openPaymentModal` fell back from `enteredAmount == 0` to `amount` and fired `SoundboxService.announcePayment` and WhatsApp payment confirmation even when ₹0 was collected.
     c) `MyMembershipScreen._StudentTransactionsSection` and `MyReceiptsScreen` synthesized fake `CONFIRMED` ₹700/`91 Days` receipts whenever `receipts` was empty and `student.planId != null`, and `MyPaymentHistoryScreen` used `Filter.or(...)` causing silent index failures.
   - Guardrails:
     a) Centralize all student payment/receipt eligibility and ledger synthesis in `StudentLedgerHelper` (`isPaidAdmissionEligible`, `isConfirmedPaidStatus`, `shouldAnnounceApprovalPayment`, `resolveFallbackPlanEndDate`, `buildTransactionsLedger`, `computeTotalPaid`). Unpaid / `paymentPending` admissions MUST have zero confirmed history and `null` synthetic receipt.
     b) NEVER fabricate a fallback `+90 days` or `+91 days` validity window (`resolveFallbackPlanEndDate` returns `null` when `planEndDate` is missing).
     c) NEVER announce a Soundbox payment chime or dispatch a WhatsApp payment confirmation when collected `paidAmt <= 0` or outside `renewal` / `due_payment` collections.
     d) Wrap variable-width plan chips and billing subtitles in `MyMembershipScreen` with `Expanded`/`Flexible` and `FittedBox` so right-edge badges (`Payment Pending` / `Starts on fee payment`) never clip on 360px viewports.

2. **Exclusive Pre-Submit Seat Soft-Lock & Multi-Applicant Conflict Defense:**
   - Root Cause: `SeatSelectionScreen` wrote to the nonexistent `/seats` flat path instead of `SeatRepository.softLockSeat` on `libraries/{libId}/sections/{secId}/seats/{seatId}`; `ReviewSubmitScreen` acquired the 24h lock only after `requestRef.set` and swallowed errors (`proceeding anyway`); `StudentSeatMapScreen` (`seat_change`) ignored `SeatStatus.reserved` and never locked seats; `RequestDetailScreen` ignored active soft-locks and competing pending requests and blindly called `releaseSoftLock` without checking `expectedCandidateId`; and `StudentProvisioningService` silently wiped `seatId: null` on collision.
   - Guardrails:
     a) Acquire transactional `SeatRepository.softLockSeat` BEFORE writing `requests/{id}` (in both `ReviewSubmitScreen` and `StudentSeatMapScreen`); if the request write fails, immediately roll back via `releaseSoftLock(..., expectedCandidateId: uid)`.
     b) Strictly scope `firestore.rules` soft-lock writes on `/sections/{sectionId}/seats/{seatId}` so candidates can only hold an `available` or expired `reserved` desk with `status == 'reserved'` and `reservationType` in `['registration_hold', 'seat_change_hold']`, leaving all other fields immutable.
     c) `releaseSoftLock` and `rejectRequest` must pass `expectedCandidateId` so rejecting Applicant B cannot release Applicant A's hold.
     d) Block accidental double-booking at approval time (`RequestDetailScreen`, `RequestListScreen`, and `StudentProvisioningService` with `overrideSeatCollision = false`) when the desk is occupied, held by another user, or requested by competing pending applications.

3. **Case-Insensitive Applicant Lookup, Redirect Draft Persistence & Router Stability (`Sj98191@gmail.com` Cluster):**
   - Root Cause: `waiting_list_repository.dart` matched emails via `email.contains(entry.studentPhone)` (matching `98191` inside `Sj98191@gmail.com`); `ReviewSubmitScreen` / `RegistrationFormScreen` wrote mixed-case emails without top-level `email`/`studentEmail`/`userId`; `appRouterProvider` watched `userRoleProvider`, rebuilding `GoRouter(initialLocation: Routes.splash)` and bouncing students mid-flow back to Splash/Login; Web `signInWithRedirect` + `StudentRegistrationWizard` cleared in-progress wizard state; `functions/index.js` `onRequestCreated` deleted newly created requests whenever any older pending doc existed; and oversized PDFs exceeded Firestore's 1 MiB limit without clear early validation.
   - Guardrails:
     a) NEVER match phone numbers via substring search inside email addresses. Normalize `email.trim().toLowerCase()` everywhere (`RegistrationFormScreen`, `ReviewSubmitScreen`, `StudentSeatMapScreen`, `StudentProvisioningService`, `firestore.rules`) and include raw mixed-case fallback queries for legacy docs in Splash/Login/AuthRoleService.
     b) Keep `GoRouter` persistent via `refreshListenable` + `ref.listen`; never `ref.watch(userRoleProvider)` directly inside `appRouterProvider`.
     c) Persist `RegistrationDraftStorage` across Web OAuth redirects and hold `registrationSubmissionSuccessProvider` true until the confirmation screen `Done` action completes; protect wizard steps 2..6 with `PopScope`.
     d) Reject > 650 KB PDFs upfront in `DocumentPickerService` (and > 940 KB total request payloads before soft-locking) and mark older same-type pending requests `'superseded'` in `onRequestCreated` instead of deleting newly submitted docs.

---

## 53. Announcement Role Isolation, Communications Hub Hardening & Backup Restore Resilience (Learned Nov 2026)

1. **Announcement Role Isolation & Admin Topic Separation:**
   - Root Cause: `announcement_list_screen.dart` dispatched announcements with `targetRole: 'all'`, `actionRoute: '/student/announcements'`, and topic `'lib-${libraryId}'`. Meanwhile, `NotificationService.subscribeToLibraryTopics` subscribed Admin devices to `lib-${libraryId}`, and `functions/index.js` (`onNotificationCreated`) sent `targetRole == 'all'` notifications directly to `adminFcmToken`, `admin-${libraryId}`, and Admin Telegram — causing Chrome Web push (`study-lib-m...`) and Admin notifications to buzz on the Admin's own phone whenever Admin posted a student circular.
   - Guardrails:
     a) Always dispatch student announcements with `targetRole: 'student'`, topic `'student-${libraryId}'`, and `metadata['initiatedBy']`.
     b) In `subscribeToLibraryTopics`: when `isAdmin == true`, subscribe ONLY to `admin-$safeLibId` and explicitly unsubscribe from `lib-$safeLibId` and `student-$safeLibId`.
     c) Exclude student-routed announcements (`type == 'announcement' && targetRole != 'admin'`) from `adminNotificationsStreamProvider` and from `onNotificationCreated` Admin/Telegram dispatch.

2. **Communications Hub Layout Safety, Secret Isolation & Cross-Platform Webhooks:**
   - Root Cause: Soundbox test buttons (`Test Chime` + `Test ₹500 Announcement`) sat inside an unconstrained `Row` causing right-edge clipping on mobile Web; `firestore.rules` allowed any authenticated student to read `settings/{id}` (including `settings/messaging` API tokens & webhooks); `NotificationWebhookService` used `dart:io` `HttpClient` (crashing on Flutter Web) and read an unused `settings/webhooks` path; scheduled Cloud Functions ignored automation rule toggles; and background snapshot listeners overwrote unsaved token inputs.
   - Guardrails:
     a) Wrap Soundbox preview/test buttons in responsive `Wrap(spacing: 10, runSpacing: 8)` with unified ₹500 sample amount.
     b) Store secret keys (`telegramBotToken`, `metaAccessToken`, `smsApiKey`, `customWebhookUrl`) in `libraries/{libraryId}/admin_secrets/communications`, locked alongside `settings/messaging` & `settings/webhooks` exclusively to `isOwner(libraryId) || staffCan(libraryId, 'canManageSettings')` in `firestore.rules`. Strip raw API secrets from public `settings/communications`.
     c) Use `package:http` in `NotificationWebhookService`, resolve real plan pricing & `SeatHelper.formatDeskLabel` in Action Queue, and honor `rules` toggles (`morningBriefing`, `nightlySettlement`, `waitlistCascade`, `multiStageRenewals`) inside `functions/index.js`.

3. **Backup & Restore Integrity, Chunk Cleanup & Post-Restore Verification:**
   - Root Cause: `_supportedCollections` omitted `expenses`, `feedback`, and `libraryProfile`; `SetOptions(merge: true)` could not revert fields added after a snapshot; shrinking same-day `daily_backups/{dateKey}` overwrites left stale trailing chunks in `chunks/` corrupting base64/GZip decoding; a single failed payment/staff validation aborted all 450 operations in a `WriteBatch`; cloud snapshot restore forgot to update `_statusText` percentages and only ticked progress every 450 writes; and `checkAndRunRollingBackup` shared one key across libraries.
   - Guardrails:
     a) Back up `expenses`, `feedback`, and safe root `libraryProfile` alongside existing collections, clean up stale chunks (`idx >= totalChunks`) during `saveDailyCloudSnapshot`, commit chunks in <=15-chunk batches (~6 MB) BEFORE writing final snapshot metadata, and scope `last_daily_cloud_backup_date_$libraryId` per library.
     b) In `restoreFromJsonString`: flush in responsive batches (`50` on Web / `250` on mobile) with per-doc resilient fallback on batch error, support optional `exactMirror` (`Strict Snapshot Replace Mode`), invalidate core Riverpod providers after completion, and present a verified record count breakdown dialog (`_showRestoreSummaryDialog`).
     c) Wrap manual restore `FilePicker.pickFiles` in `InactivityLockService.setExternalDialogActive(true/false)` so OS file dialog blur does not auto-lock the Admin.

---

## 54. Web Performance, Asset HTTP Caching, Encryption Memoization & Zero-Jank Frame Discipline (Learned Nov 2026)

> [!CAUTION]
> This section is **STRICT & PERMANENT** for every future build, deployment, and UI feature addition. Never reintroduce full-bundle cache prevention, uncached heavy crypto on UI threads, or per-frame offscreen GPU blur layers.

1. **HTTP Asset & Bundle Caching Headers (`firebase.json`):**
   - Root Cause: `"**"` and `"**/*.@(js|mjs)"` in `firebase.json` set `"Cache-Control": "no-cache, no-store, must-revalidate"`, forcing browsers to discard the 10.6 MB `main.dart.js`, 7.3 MB `canvaskit.wasm`, fonts, and icons and re-download them over the network on reloads and route transitions.
   - Guardrails:
     a) Allow long-lived HTTP caching (`public, max-age=604800, stale-while-revalidate=86400`) on `**/*.wasm` and static media/fonts (`png|jpg|jpeg|webp|gif|svg|ico|ttf|otf|woff|woff2`).
     b) Use `public, max-age=0, must-revalidate` for `**/*.@(js|mjs)` so browsers retain `main.dart.js` on disk via ETag (`304 Not Modified`) while serving fresh code immediately on redeploys.
     c) Restrict `no-cache, no-store, must-revalidate` strictly to entrypoints (`**/index.html`, `**/flutter_bootstrap.js`, `**/flutter_service_worker.js`, `**/version.json`, `update.json`).
     d) Never leave bloated, unreferenced files (such as the removed 1.15 MB `logo_b64.txt`) inside `assets/`.

2. **Non-Blocking Startup & On-Demand Heavy Scripts (`web/index.html`, `main.dart`, `splash_screen.dart`):**
   - Root Cause: Eager synchronous CDN `<script>` tags (`tesseract.min.js`, `pdf.min.js`, `jsQR.min.js`) and an 8-family Google Fonts stylesheet blocked initial HTML parsing; `main.dart` awaited a 10s network `RemoteConfigService.initialize()` before `runApp()`; and `SplashScreen` awaited `checkForUpdate()` + an artificial `1600ms` delay.
   - Guardrails:
     a) Lazy-load optional heavy web libraries (`Tesseract`, `PDF.js`, `jsQR`) on demand inside their respective JS helper functions via `_loadExternalScript(...)`.
     b) Load web fonts asynchronously (`rel="preload" as="style" ... onload="this.rel='stylesheet'"`).
     c) Never block `runApp()` or splash navigation on network fetches (`RemoteConfigService.initialize(waitForFetch: false)`, `checkForUpdate().ignore()`, `runDailyMaintenance().ignore()`). Keep splash wait snappy (`200ms` web / `450ms` native).

3. **Zero Synchronous 100k-Iteration PBKDF2 Loops on the UI Thread (`encryption_service.dart`):**
   - Root Cause: `StudentRepository._parseStudentDoc` and `StudentPageNotifier._safeParseDoc` ran `EncryptionService.safeDecryptGovId()` synchronously for every student on every Firestore snapshot emission, re-executing **100,000 PBKDF2 HMAC-SHA256 iterations** per student without caching the derived AES key, freezing the JavaScript main thread for seconds.
   - Guardrails:
     a) Always memoize derived keys (`_derivedKeyCache`, `_legacyKeyCache`) per passphrase and cache decrypted values (`_decryptedValueCache`).
     b) Never execute uncached key derivation inside synchronous `.map()` stream transformers or widget `build()` methods.

4. **Zero-Jank Compositing, Memoized Themes & O(1) List/Grid Rendering:**
   - Root Cause: `AdminShell` and `StudentShell` wrapped solid bottom `NavigationBar`s in `BackdropFilter(sigmaX: 16, sigmaY: 16)`; `StudyLibraryApp.build` watched the entire `currentLibraryProvider` and recalculated 30 `GoogleFonts` styles via unmemoized `AppTheme.fromSeed` calls; `SeatTile` instantiated 3 `AnimationController`s + multiple Gaussian `BoxShadow`s per seat (180+ controllers for 60 seats); `StudentListScreen` used `IntrinsicHeight` (`O(N^2)` double layout) and linear `allSeats` loops per card; `SentinelEchoVerifier` spun a 500ms `Timer.periodic` permanently on idle; and `ExpiryNotificationService.checkExpiringPlans` had previously executed `.get()` queries inside `build()` or on Web.
   - Guardrails:
     a) NEVER place `BackdropFilter` / `ImageFilter.blur` over persistent navigation bars or scrolling lists.
     b) Memoize `AppTheme.fromSeed` in `_themeCache`, read theme/font prefs synchronously via `sharedPreferencesProvider`, and scope root `MaterialApp` rebuilds using `currentLibraryProvider.select(...)`.
     c) NEVER use `IntrinsicHeight`, stacked per-tile `AnimationController`s (`PressableScale` + `AnimatedContainer` + `AnimatedOpacity`), or pervasive `BoxShadow` blurs inside `ListView.builder` / `GridView.builder` cells; precompute lookup maps once per `build()`.
     d) Isolate infinite animations (`LiveRadarPulse`, `LiveRadarDot`, `PulsingGlowContainer`, `HolographicCard3D`) inside `RepaintBoundary` and stop background timers (`SentinelEchoVerifier`) when idle.
     e) Guard mobile-only local notification services (`ExpiryNotificationService`) with `if (kIsWeb) return;` and NEVER perform Firestore `.get()` or notification side effects inside `Widget.build()`.

5. **Unified Financial Collection Aggregation (`unifiedFinancialLedgerProvider`):**
   - Root Cause: `netProfitProvider` and `revenueDataProvider` executed redundant sequential full-collection `.get()` scans across `payments` and `receipts` on every Admin Dashboard load and pull-to-refresh.
   - Guardrails:
     a) Fetch `payments`, `receipts`, and `expenses` ONCE in parallel via `Future.wait` inside `unifiedFinancialLedgerProvider`, and derive both `netProfitProvider` and `revenueDataProvider` from that single ledger pass.
     b) Invalidate `unifiedFinancialLedgerProvider` after recording/updating payments or expenses so both Net Profit and Revenue Chart refresh together without duplicate reads.

6. **Modern `package:web` + `dart:js_interop`, Scoped `Consumer` Boundaries & Deferred Route Splitting:**
   - Root Cause: First-party web utilities used deprecated `dart:html` / `dart:js` (`eval`), dashboards watched secondary streams at top-level `build()` without downsampling AppBar logos (`ImageService.getAvatarProvider`), and rarely visited Admin tools bloated initial `main.dart.js`.
   - Guardrails:
     a) Use strictly `package:web` + `dart:js_interop` with `if (dart.library.js_interop)` conditional imports; NEVER reintroduce `dart:html`, `dart:js`, or `dart:js_util` anywhere in `lib/`.
     b) Isolate localized banners and sub-cards (holidays, financial pulse, student notices, renewal/seat-change banners) inside scoped `Consumer` widgets and render circular avatars/logos with `ImageService.getAvatarProvider(...)`.
     c) Import standalone heavy Admin screens (Bulk Import, Backup, Maintenance, Sentinel Diagnostics, Data Export, Audit Log, Recycle Bin, Revenue Dashboard, Template/Form Studios, QR Scanner) via `deferred as` + `_DeferredRouteLoader` in `app_router.dart` so `main.dart.js` stays lean on initial boot.





---

## 57. Dual-Portal Identical ID Pass Geometry, Official Seal Stamp, Inactive State Fencing & Clean OCR Protocol (Learned Nov 2026)

1. **Dual-Face Identical ID Pass Geometry (440 x 256px Parity):**
   - Root Cause: Front ID card was rendered with loose vertical constraints (~240px height) while back ID card rendered with ~340px height due to unconstrained terms, QR verification box, and contact tiles. Tapping "Flip to View Back Side" caused vertical layout jumps and clipping across Admin (IdCardPreviewScreen) and Student (MyIdCardScreen).
   - Guardrails:
     a) Both _buildCardFront and _buildCardBack MUST be constrained to identical dimensions: width: double.infinity, height: 256, constraints: const BoxConstraints(maxWidth: 440, minHeight: 256, maxHeight: 256).
     b) Back card terms, emergency contacts, and signatory sections must scale smoothly inside this 256px boundary with zero RenderFlex overflow.

2. **Strict Inactive & Expired State Fencing on ID Passes:**
   - Root Cause: Inactive or suspended students (e.g. Shubham Katle CC20260017, Savita Wagesh Choudhari CC20260018) still showed green STUDENT PASS / ACTIVE PASS headers, active validity dates, live clock tickers (● LIVE 19:56:23), green Verified Digital Student Pass Active bottom cards, and stale unassigned seats (Seat: #15).
   - Guardrails:
     a) If student.status == 'inactive' or status == 'suspended' or status == 'expired':
        - Header badge must render red INACTIVE PASS or SUSPENDED or EXPIRED PASS.
        - Valid: date must display 'Inactive' / 'Suspended' / 'Expired'.
        - Anti-screenshot live ticker must display static red ● PASS INACTIVE or ● PASS EXPIRED with zero pulsing live dot.
        - Digital pass verification banner must display a red caution container: "Inactive Pass - Unassigned / Suspended".
        - Back QR code status pill must display red INACTIVE / SUSPENDED and bottom badge must render ✕ INACTIVE PASS instead of ★ VERIFIED PASS ★.
     b) Seat Allocation Fencing: If student.seatId == null || student.seatId.isEmpty, display 'Unassigned' - NEVER render stale or previously allocated desk numbers.

3. **Official Institutional Double-Ring Rubber Seal Stamp (OrganisationalSealStamp):**
   - Root Cause: ID passes lacked authentic library branding and seal stamps, rendering either no stamp or a flat 28px placeholder circle.
   - Guardrails:
     a) Render OrganisationalSealStamp on both front and back faces with dual concentric rings, curved library header text, locality text, and central status emblem (OFFICIALLY APPROVED in teal/green or INACTIVE / VOID in crimson/red).
     b) Apply authentic -7 deg rotational tilt and rubber stamp text styling for high-trust verification.

4. **Zero OCR Hallucination Leakage & Elimination of Unused Scanners:**
   - Root Cause: Client-side Aadhaar QR parsing was inaccurate, and OCR auto-fill captured government headers (e.g., "GOVERNMENT OF INDIA", "Unique Identification Authority") into student name/address fields, and previewed dirty garbage text.
   - Guardrails:
     a) Completely eliminate client-side Aadhaar QR scanner tabs/buttons in favor of standard camera/gallery photo OCR and clean manual entry.
     b) Enforce strict regex validation on extracted text (isIdValid, isNameValid, isDobValid, isPinValid, isAddressValid). If confidence is low or text contains administrative government boilerplate, discard it (null) and require user manual entry rather than filling false data.
