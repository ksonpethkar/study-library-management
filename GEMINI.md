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
3. **No Raw Firebase Exception Dumps:**
   - Never display raw database exception traces (e.g. index URLs, internal error codes) directly on user-facing widgets. Wrap stream and future errors in clean, friendly retry cards using `AppErrorFormatter`.
4. **Multi-Tenant Library Isolation:**
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

---

## 4. Mobile Screen Layout, Overflow & Viewport Standards
Derived from past bugs: *RenderFlex overflows on small devices, dialog buttons clipped, keyboard obscuring inputs*.
1. **Zero RenderFlex Overflow Tolerance:**
   - Never use fixed widths or unconstrained horizontal rows for action buttons or headers.
   - Always wrap action buttons in `Wrap(spacing: 8, runSpacing: 8)` or `FittedBox(fit: BoxFit.scaleDown)`.
   - In `Row` widgets, wrap variable-length text in `Expanded` or `Flexible` with `overflow: TextOverflow.ellipsis`.
2. **Mobile Form Scrolling & Keyboard Behavior:**
   - Every form must use `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag` so the virtual keyboard does not block submit buttons or inputs.
3. **Text Scaling Clamping:**
   - Protect layouts against accessibility text scaling > 1.5x using `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3)`.
4. **Memory-Safe Image Rendering:**
   - Never load uncompressed base64 photo strings or raw network images directly into high-density lists or ID cards.
   - Always wrap in `CachedNetworkImage` and use `ResizeImage` downsampling (e.g., max 256x256 for avatars) to prevent Android out-of-memory (OOM) crashes and scrolling jank.

---

## 5. Mobile Hardware Back-Button & Route Navigation Safety
Derived from past bug: *Pressing Android physical back button on inner screens exited the app completely*.
1. **Resilient Pop Scope:**
   - Every secondary or inner screen (ID Card, Settings, Feedback, Receipts, Holidays, Announcements) must implement resilient back handling:
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

## 7. Android Binary Build, Signing & OTA Distribution Discipline
Derived from past bugs: *Mismatched keystore prevented OTA update installation; ARM64 APK failed on 32-bit devices; ServiceWorker cached stale web bundles*.
1. **Identical Release Signing Keystore:**
   - All production APKs and App Bundles must be signed with the permanent release keystore (`upload-keystore.jks`). Never use debug or regenerated keys, or in-app OTA updates will fail with `"Package conflicts with an existing package"`.
2. **Universal APK is Primary:**
   - The primary public download link (`StudyLibrary.apk`) must ALWAYS be the Universal (FAT) APK containing all ABIs (`armeabi-v7a`, `arm64-v8a`, `x86_64`) to guarantee 100% device compatibility.
   - Split-per-abi builds (54 MB) are published alongside as secondary optimized options.
3. **Synchronized Version Manifest (`update.json`):**
   - Whenever a new version is released, synchronize `pubspec.yaml`, `update.json`, GitHub Releases CDN, and Firebase download landing page in a single commit.
4. **Web Cache Busting:**
   - Always update cache-busting timestamps in `public/app/index.html` and invoke service worker eviction to prevent browsers from serving stale cached JavaScript bundles.

---

## 8. Mandatory Pre-Commit & Pre-Release Verification Protocol
Before any feature or bug fix is concluded:
1. `flutter analyze` must run and output **0 issues found**.
2. `flutter test test/system_qa_test.dart` must run and all QA tests must pass.
3. Every new feature or fixed bug must have a dedicated automated test added to `test/system_qa_test.dart`.
