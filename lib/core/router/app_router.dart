import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'page_transitions.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_library/features/staff/presentation/providers/staff_providers.dart';
import 'package:study_library/features/dashboard/presentation/screens/revenue_dashboard_screen.dart';
import '../../features/students/presentation/screens/edit_student_screen.dart';
import '../../features/students/presentation/screens/bulk_import_screen.dart';
import 'admin_shell.dart';
import 'student_shell.dart';

import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/biometric_lock_screen.dart';
import '../../features/auth/presentation/screens/access_restricted_screen.dart';
import '../../features/auth/presentation/screens/admin_whitelist_screen.dart';
import '../../features/onboarding/presentation/screens/setup_wizard_screen.dart';

import '../../features/dashboard/presentation/screens/admin_dashboard_screen.dart';
import '../../features/seats/presentation/screens/seat_map_screen.dart';
import '../../features/students/presentation/screens/student_list_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

import '../../features/seats/presentation/screens/add_section_screen.dart';
import '../../features/seats/presentation/screens/section_detail_screen.dart';
import '../../features/students/presentation/screens/add_student_screen.dart';
// import '../../features/students/presentation/screens/bulk_import_screen.dart';
import '../../features/students/presentation/screens/student_detail_screen.dart';
import '../../features/students/presentation/screens/student_history_screen.dart';
import '../../features/plans/presentation/screens/plan_list_screen.dart';
import '../../features/plans/presentation/screens/add_plan_screen.dart';
import '../../features/payments/presentation/screens/record_payment_screen.dart';
import '../../features/receipts/presentation/screens/receipt_list_screen.dart';
import '../../features/expenses/presentation/screens/expense_list_screen.dart';
import '../../features/receipts/presentation/screens/receipt_preview_screen.dart';
import '../../features/receipts/presentation/screens/generate_receipt_screen.dart';
import '../../features/settings/presentation/screens/receipt_template_screen.dart';
import '../../features/settings/presentation/screens/message_template_studio_screen.dart';
import '../../features/requests/presentation/screens/request_list_screen.dart';
import '../../features/requests/presentation/screens/request_detail_screen.dart';
import '../../features/announcements/presentation/screens/announcement_list_screen.dart';
import '../../features/holidays/presentation/screens/holiday_calendar_screen.dart';
import '../../features/feedback/presentation/screens/feedback_list_screen.dart';
import '../../features/settings/presentation/screens/library_profile_screen.dart';
import '../../features/settings/presentation/screens/form_customizer_screen.dart';
import '../../features/settings/presentation/screens/payment_methods_screen.dart';
import '../../features/settings/presentation/screens/communications_hub_screen.dart';
import '../../features/backup/presentation/screens/backup_restore_screen.dart';
import '../../features/audit_log/presentation/screens/audit_log_screen.dart';
import '../../features/recycle_bin/presentation/screens/recycle_bin_screen.dart';
import '../../features/settings/presentation/screens/rules_editor_screen.dart';
import '../../features/waiting_list/presentation/screens/waiting_list_screen.dart';
import '../../features/staff/presentation/screens/staff_list_screen.dart';
import '../../features/qr_share/presentation/screens/qr_share_screen.dart';
import '../../features/admin_qr/presentation/screens/admin_qr_scanner_screen.dart';
import '../../features/settings/presentation/screens/grace_period_screen.dart';
import '../../features/settings/presentation/screens/id_card_customizer_screen.dart';
import '../../features/settings/presentation/screens/data_export_screen.dart';

import '../../features/student_app/presentation/screens/student_home_screen.dart';
import '../../features/student_app/presentation/screens/my_membership_screen.dart';
import '../../features/student_app/presentation/screens/my_receipts_screen.dart';
import '../../features/student_app/presentation/screens/my_profile_screen.dart';
import '../../features/student_app/presentation/screens/my_payment_history_screen.dart';

import '../../features/registration/presentation/screens/student_registration_wizard.dart';
import '../../features/student_app/presentation/screens/student_feedback_screen.dart';
import '../../features/student_app/presentation/screens/renew_plan_screen.dart';
import '../../features/student_app/presentation/screens/my_id_card_screen.dart';
import '../../features/student_app/presentation/screens/student_seat_map_screen.dart';
import '../../features/student_app/presentation/screens/student_announcements_screen.dart';
import '../../features/id_cards/presentation/screens/id_card_preview_screen.dart';
import '../../features/students/presentation/providers/student_providers.dart';
import '../../features/settings/presentation/screens/account_deletion_screen.dart';
import 'package:study_library/features/legal/presentation/screens/onboarding_consent_screen.dart';
import 'package:study_library/features/legal/presentation/screens/terms_screen.dart';
import 'package:study_library/features/legal/presentation/screens/privacy_policy_screen.dart';
import '../widgets/not_found_screen.dart';

class Routes {
  static const splash = '/splash';
  static const consent = '/consent';
  static const login = '/login';
  static const biometricLock = '/biometric-lock';
  static const setupWizard = '/setup-wizard';
  static const accessRestricted = '/access-restricted';
  static const terms = '/terms';
  static const privacyPolicy = '/privacy-policy';
  static const notFound = '/404';

  // Admin routes
  static const adminHome = '/admin/home';
  static const adminSeats = '/admin/seats';
  static const adminStudents = '/admin/students';
  static const adminMore = '/admin/more';
  
  static const adminSeatsSection = '/admin/seats/section/:id';
  static const adminSeatsAddSection = '/admin/seats/add-section';
  
  static const adminStudentDetail = '/admin/students/:id';
  static const adminStudentAdd = '/admin/students/add';
  static const adminStudentEdit = '/admin/students/:id/edit';
  static const adminStudentHistory = '/admin/students/:id/history';
  static const adminStudentImport = '/admin/students/import';
  static const adminStudentIdCard = '/admin/students/:id/id-card';
  
  static const adminPlans = '/admin/plans';
  static const adminPlanAdd = '/admin/plans/add';
  static const adminPlanEdit = '/admin/plans/:id/edit';
  
  static const adminRecordPayment = '/admin/payments/record/:studentId';
  
  static const adminReceipts = '/admin/receipts';
  static const adminExpenses = '/admin/expenses';
  static const adminRevenue = '/admin/revenue';
  static const adminGenerateReceipt = '/admin/receipts/generate/:studentId';
  static const adminReceiptTemplate = '/admin/receipts/template';
  static const adminMessageTemplates = '/admin/settings/message-templates';
  static const adminIdCardTemplate = '/admin/settings/id-card-template';
  static const adminReceiptPreview = '/admin/receipts/:id';
  
  static const adminRequests = '/admin/requests';
  static const adminRequestDetail = '/admin/requests/:id';
  
  static const adminAnnouncements = '/admin/announcements';
  static const adminHolidays = '/admin/holidays';
  static const adminFeedback = '/admin/feedback';
  
  static const adminSettings = '/admin/settings';
  static const adminLibraryProfile = '/admin/settings/library-profile';
  static const adminFormCustomizer = '/admin/settings/form-customizer';
  static const adminPaymentMethods = '/admin/settings/payment-methods';
  static const adminCommunications = '/admin/settings/communications';
  static const adminNotifications = '/admin/settings/notifications';
  static const adminMessaging = '/admin/settings/messaging';
  static const adminRules = '/admin/settings/rules';
  static const adminWaitingList = '/admin/settings/waiting-list';
  static const adminWaitingQueue = '/admin/waiting-queue';
  static const adminGracePeriod = '/admin/settings/grace-period';
  static const adminQrShare = '/admin/qr-share';
  static const adminQrScanner = '/admin/qr-scanner';
  static const adminWhitelist = '/admin/settings/admin-whitelist';
  static const adminStaff = '/admin/settings/staff';
  
  static const adminBackup = '/admin/backup';
  static const adminDataExport = '/admin/data-export';
  static const adminAuditLog = '/admin/audit-log';
  static const adminRecycleBin = '/admin/recycle-bin';

  // Student routes
  static const studentHome = '/student/home';
  static const studentMembership = '/student/membership';
  static const studentReceipts = '/student/receipts';
  static const studentProfile = '/student/profile';
  static const studentPaymentHistory = '/student/payment-history';
  
  static const studentRegister = '/student/register';
  static const studentSeatMap = '/student/seat-map';
  static const studentFeedback = '/student/feedback';
  static const studentRenew = '/student/renew';
  static const studentIdCard = '/student/id-card';
  static const studentAnnouncements = '/student/announcements';
  static const accountDeletion = '/student/account-deletion';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _adminShellNavigatorKey = GlobalKey<NavigatorState>();
final _studentShellNavigatorKey = GlobalKey<NavigatorState>();



final appRouterProvider = Provider<GoRouter>((ref) {
  // Watch role changes so router refreshes when user signs in/out
  final role = ref.watch(userRoleProvider);
  final canViewRevenue = ref.watch(canViewRevenueProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.splash,
    errorPageBuilder: (context, state) {
      final loc = state.uri.toString();
      // Auto-recover seamlessly if path has /app/ prefix
      if (loc.startsWith('/app/')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final stripped = loc.substring(4);
          GoRouter.of(context).go(stripped);
        });
        return AppPageTransitions.fadeThrough(
          state: state,
          child: const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        );
      }
      return AppPageTransitions.fadeThrough(
        state: state,
        child: NotFoundScreen(
          uri: state.uri,
          error: state.error,
        ),
      );
    },
    // ── Security: Role-based redirect guard ─────────────────────────────────
    redirect: (context, state) {
      final uri = state.uri;
      final rawPath = uri.path;

      // Normalize if path starts with '/app' (e.g. '/app/admin/students/...' -> '/admin/students/...')
      if (rawPath.startsWith('/app/')) {
        final stripped = rawPath.substring(4);
        final query = uri.hasQuery ? '?${uri.query}' : '';
        return '$stripped$query';
      }
      if (rawPath == '/app') {
        return Routes.splash;
      }

      final path = uri.toString();

      // Public routes — always accessible
      final publicRoutes = [
        Routes.splash,
        Routes.consent,
        Routes.login,
        Routes.terms,
        Routes.privacyPolicy,
        Routes.biometricLock,
        Routes.accessRestricted,
        Routes.studentRegister,
        Routes.notFound,
      ];
      if (publicRoutes.any((r) => path == r || path.startsWith(r))) {
        return null; // allow
      }

      // Setup wizard route — strictly restricted from student access
      if (path == Routes.setupWizard || path.startsWith(Routes.setupWizard)) {
        if (role == AppUserRole.student) {
          return Routes.studentHome;
        }
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return Routes.login;
        return null;
      }

      // Admin-only routes
      if (path.startsWith('/admin/')) {
        if (role == AppUserRole.student) {
          return Routes.accessRestricted;
        }
        if (role == AppUserRole.none) {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return Routes.login;
          // While role is resolving, allow splash/admin to continue without false denial
          return null;
        }
      }

      // Student-only routes
      if (path.startsWith('/student/')) {
        // Registration wizard is always accessible for prospective students
        if (path == Routes.studentRegister || path.startsWith(Routes.studentRegister)) {
          return null;
        }
        if (role == AppUserRole.admin) {
          return Routes.accessRestricted;
        }
        if (role == AppUserRole.none) {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return Routes.login;
          return null;
        }
      }

      // Staff permission: revenue and operating expenses require canViewRevenue
      if ((path == Routes.adminRevenue || path == Routes.adminExpenses) && !canViewRevenue) {
        return Routes.adminHome;
      }

      return null; // allow
    },
    routes: [
      // ── Web Base Path Normalization & Wildcard Aliases ─────────────────────
      // Transparently maps /app and /app/* into the application route hierarchy
      GoRoute(
        path: '/app',
        redirect: (context, state) => Routes.splash,
      ),
      GoRoute(
        path: '/app/:subpath(.*)',
        redirect: (context, state) {
          final sub = state.pathParameters['subpath'] ?? '';
          final q = state.uri.hasQuery ? '?${state.uri.query}' : '';
          return '/$sub$q';
        },
      ),
      GoRoute(
        path: Routes.notFound,
        pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
          state: state,
          child: NotFoundScreen(uri: state.uri, error: state.error),
        ),
      ),
      GoRoute(
        path: Routes.splash,
        pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
          state: state, child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: Routes.consent,
        pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
          state: state, child: const OnboardingConsentScreen(),
        ),
      ),
      GoRoute(
        path: Routes.login,
        pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
          state: state, child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: Routes.biometricLock,
        pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
          state: state, child: const BiometricLockScreen(),
        ),
      ),
      GoRoute(
        path: Routes.setupWizard,
        pageBuilder: (context, state) => AppPageTransitions.slideUp(
          state: state, child: const SetupWizardScreen(),
        ),
      ),
      GoRoute(
        path: Routes.accessRestricted,
        pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
          state: state, child: const AccessRestrictedScreen(),
        ),
      ),
      GoRoute(
        path: Routes.terms,
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          state: state, child: const TermsScreen(),
        ),
      ),
      GoRoute(
        path: Routes.privacyPolicy,
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          state: state, child: const PrivacyPolicyScreen(),
        ),
      ),

      // Admin Routes
      ShellRoute(
        navigatorKey: _adminShellNavigatorKey,
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: Routes.adminHome,
            pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
              state: state,
              child: const AdminDashboardScreen(),
            ),
          ),
          GoRoute(
            path: Routes.adminSeats,
            pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
              state: state,
              child: const SeatMapScreen(),
            ),
          ),
          GoRoute(
            path: Routes.adminStudents,
            pageBuilder: (context, state) {
              final filter = state.uri.queryParameters['filter'];
              return AppPageTransitions.fadeThrough(
                state: state,
                child: StudentListScreen(initialFilter: filter),
              );
            },
          ),
          GoRoute(
            path: Routes.adminMore,
            pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
              state: state,
              child: const SettingsScreen(),
            ),
          ),
        ],
      ),
      
      // Admin Sub-routes
      GoRoute(
        path: Routes.adminSeatsSection,
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          state: state, child: SectionDetailScreen(sectionId: state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminSeatsAddSection, pageBuilder: (context, state) {
        return AppPageTransitions.slideUp(state: state, child: Consumer(builder: (ctx, ref, _) {
          final libId = ref.watch(currentLibraryIdProvider) ?? '';
          return AddSectionScreen(libraryId: libId);
        }));
      }),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminStudentAdd, pageBuilder: (context, state) => AppPageTransitions.slideUp(
        state: state, child: AddStudentScreen(initialData: state.extra as Map<String, dynamic>?),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminStudentImport, pageBuilder: (context, state) => AppPageTransitions.slideUp(
        state: state, child: const BulkImportScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminStudentDetail, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: StudentDetailScreen(studentId: state.pathParameters['id'] ?? ''),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminStudentEdit, pageBuilder: (context, state) => AppPageTransitions.slideUp(
        state: state, child: EditStudentScreen(studentId: state.pathParameters['id'] ?? ''),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminStudentHistory, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: StudentHistoryScreen(studentId: state.pathParameters['id'] ?? ''),
      )),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: Routes.adminStudentIdCard,
        pageBuilder: (context, state) {
          final studentId = state.pathParameters['id'] ?? '';
          return AppPageTransitions.slideRight(
            state: state,
            child: Consumer(
              builder: (ctx, ref, _) {
                final studentAsync = ref.watch(studentDetailProvider(studentId));
                return studentAsync.when(
                  data: (student) => student != null
                      ? IdCardPreviewScreen(student: student)
                      : const Scaffold(body: Center(child: Text('Student not found'))),
                  loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
                  error: (e, _) => Scaffold(body: Center(child: Text('Error loading ID Card'))),
                );
              },
            ),
          );
        },
      ),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminPlans, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const PlanListScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminPlanAdd, pageBuilder: (context, state) => AppPageTransitions.slideUp(
        state: state, child: const AddPlanScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminPlanEdit, pageBuilder: (context, state) {
        final planId = state.pathParameters['id'] ?? '';
        return AppPageTransitions.slideUp(state: state, child: Consumer(builder: (ctx, ref, _) {
          final libraryId = ref.watch(currentLibraryIdProvider);
          if (libraryId == null) return const Center(child: CircularProgressIndicator());
          return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('libraries').doc(libraryId)
                .collection('plans').doc(planId).get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Scaffold(body: Center(child: Text('Plan not found')));
              }
              final plan = PlanModel.fromJson({...snapshot.data!.data()!, 'id': snapshot.data!.id});
              return AddPlanScreen(plan: plan);
            },
          );
        }));
      }),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminRecordPayment, pageBuilder: (context, state) {
        final studentId = state.pathParameters['studentId'] ?? '';
        return AppPageTransitions.slideRight(state: state, child: Consumer(builder: (ctx, ref, _) {
          return _PaymentRouteWrapper(studentId: studentId);
        }));
      }),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminReceipts, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const ReceiptListScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminRevenue, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const RevenueDashboardScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminExpenses, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const ExpenseListScreen(),
      )),
      GoRoute(
        path: Routes.adminGenerateReceipt,
        pageBuilder: (context, state) {
          final studentId = state.pathParameters['studentId'] ?? '';
          // amount and paymentMethod may be passed as query params from RecordPaymentScreen
          final amountParam = state.uri.queryParameters['amount'];
          final methodParam = state.uri.queryParameters['method'];
          return AppPageTransitions.slideUp(state: state, child: Consumer(builder: (ctx, ref, _) {
            final libraryId = ref.watch(currentLibraryIdProvider) ?? '';
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance
                  .collection('libraries').doc(libraryId)
                  .collection('students').doc(studentId).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                final data = snapshot.data?.data() ?? {};
                // Use query-param amount if provided, otherwise look up latest payment
                final amount = amountParam != null ? (double.tryParse(amountParam) ?? 0.0) : 0.0;
                final paymentMethod = methodParam ?? 'Cash';
                return GenerateReceiptScreen(
                  studentId: studentId,
                  studentName: data['name'] ?? 'Student',
                  studentPhone: data['phone'] ?? '',
                  amount: amount,
                  paymentMethod: paymentMethod,
                );
              },
            );
          }));
        },
      ),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminReceiptTemplate, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const ReceiptTemplateScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminMessageTemplates, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const MessageTemplateStudioScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminIdCardTemplate, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const IdCardCustomizerScreen(),
      )),
      GoRoute(
        path: Routes.adminReceiptPreview,
        pageBuilder: (context, state) => AppPageTransitions.slideRight(
          state: state, child: ReceiptPreviewScreen(receiptId: state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminRequests, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const RequestListScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminRequestDetail, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: RequestDetailScreen(requestId: state.pathParameters['id'] ?? ''),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminAnnouncements, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const AnnouncementListScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminHolidays, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const HolidayCalendarScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminFeedback, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const FeedbackListScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminSettings, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const SettingsScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminLibraryProfile, pageBuilder: (context, state) => AppPageTransitions.slideUp(
        state: state, child: const LibraryProfileScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminFormCustomizer, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const FormCustomizerScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminPaymentMethods, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const PaymentMethodsScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminCommunications, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const CommunicationsHubScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminNotifications, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const CommunicationsHubScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminMessaging, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const CommunicationsHubScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminBackup, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const BackupRestoreScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminDataExport, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const DataExportScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminAuditLog, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const AuditLogScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminRecycleBin, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const RecycleBinScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminRules, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const RulesEditorScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminWaitingList, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const WaitingListScreen(initialTab: 1),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminWaitingQueue, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const WaitingListScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminWhitelist, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const AdminWhitelistScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminStaff, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const StaffListScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminGracePeriod, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const GracePeriodScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminQrShare, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const QrShareScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.adminQrScanner, pageBuilder: (context, state) => AppPageTransitions.slideUp(
        state: state, child: const AdminQrScannerScreen(),
      )),

      // Student Routes
      ShellRoute(
        navigatorKey: _studentShellNavigatorKey,
        builder: (context, state, child) => StudentShell(child: child),
        routes: [
          GoRoute(
            path: Routes.studentHome,
            pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
              state: state,
              child: const StudentHomeScreen(),
            ),
          ),
          GoRoute(
            path: Routes.studentMembership,
            pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
              state: state,
              child: const MyMembershipScreen(),
            ),
          ),
          GoRoute(
            path: Routes.studentReceipts,
            pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
              state: state,
              child: const MyReceiptsScreen(),
            ),
          ),
          GoRoute(
            path: Routes.studentProfile,
            pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
              state: state,
              child: const MyProfileScreen(),
            ),
          ),
          GoRoute(
            path: Routes.studentPaymentHistory,
            pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
              state: state,
              child: const MyPaymentHistoryScreen(),
            ),
          ),
        ],
      ),
      
      // Student Sub-routes
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.studentRegister, pageBuilder: (context, state) => AppPageTransitions.slideUp(
        state: state, child: const StudentRegistrationWizard(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.studentSeatMap, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const StudentSeatMapScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.studentFeedback, pageBuilder: (context, state) => AppPageTransitions.slideUp(
        state: state, child: const StudentFeedbackScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.studentRenew, pageBuilder: (context, state) => AppPageTransitions.slideUp(
        state: state, child: const RenewPlanScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.studentIdCard, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const MyIdCardScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.studentAnnouncements, pageBuilder: (context, state) => AppPageTransitions.slideRight(
        state: state, child: const StudentAnnouncementsScreen(),
      )),
      GoRoute(parentNavigatorKey: _rootNavigatorKey, path: Routes.accountDeletion, pageBuilder: (context, state) => AppPageTransitions.slideUp(
        state: state, child: const AccountDeletionScreen(),
      )),
    ],
  );
});

class _PaymentRouteWrapper extends ConsumerStatefulWidget {
  final String studentId;
  const _PaymentRouteWrapper({required this.studentId});

  @override
  ConsumerState<_PaymentRouteWrapper> createState() => _PaymentRouteWrapperState();
}

class _PaymentRouteWrapperState extends ConsumerState<_PaymentRouteWrapper> {
  StudentModel? _student;
  double _planPrice = 0.0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStudent();
  }

  Future<void> _loadStudent() async {
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty || widget.studentId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final doc = await FirebaseFirestore.instance
        .collection('libraries').doc(libraryId)
        .collection('students').doc(widget.studentId).get();
    if (doc.exists && mounted) {
      final student = StudentModel.fromJson({...doc.data()!, 'id': doc.id});
      double planPrice = 0.0;
      if (student.planId != null && student.planId!.isNotEmpty) {
        try {
          final planDoc = await FirebaseFirestore.instance
              .collection('libraries').doc(libraryId)
              .collection('plans').doc(student.planId!).get();
          if (planDoc.exists) {
            planPrice = (planDoc.data()?['price'] as num?)?.toDouble() ?? 0.0;
          }
        } catch (_) { /* fallback to 0 if plan missing */ }
      }
      if (mounted) {
        setState(() {
          _student = student;
          _planPrice = planPrice;
          _loading = false;
        });
      }
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_student == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Student not found')));
    return RecordPaymentScreen(
      studentId: _student!.id,
      studentName: _student!.name,
      studentPhone: _student!.phone,
      planPrice: _planPrice,
      pendingDue: (_student!.pendingDueBalance != null && _student!.pendingDueBalance! > 0)
          ? _student!.pendingDueBalance
          : null,
    );
  }
}

