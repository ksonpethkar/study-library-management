import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';
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
import '../../features/receipts/presentation/screens/receipt_preview_screen.dart';
import '../../features/receipts/presentation/screens/generate_receipt_screen.dart';
import '../../features/settings/presentation/screens/receipt_template_screen.dart';
import '../../features/requests/presentation/screens/request_list_screen.dart';
import '../../features/requests/presentation/screens/request_detail_screen.dart';
import '../../features/announcements/presentation/screens/announcement_list_screen.dart';
import '../../features/holidays/presentation/screens/holiday_calendar_screen.dart';
import '../../features/feedback/presentation/screens/feedback_list_screen.dart';
import '../../features/settings/presentation/screens/library_profile_screen.dart';
import '../../features/settings/presentation/screens/form_customizer_screen.dart';
import '../../features/settings/presentation/screens/payment_methods_screen.dart';
import '../../features/settings/presentation/screens/notification_settings_screen.dart';
import '../../features/backup/presentation/screens/backup_restore_screen.dart';
import '../../features/audit_log/presentation/screens/audit_log_screen.dart';
import '../../features/recycle_bin/presentation/screens/recycle_bin_screen.dart';
import '../../features/settings/presentation/screens/rules_editor_screen.dart';
import '../../features/settings/presentation/screens/waiting_list_settings_screen.dart';
import '../../features/waiting_list/presentation/screens/waiting_list_screen.dart';
import '../../features/staff/presentation/screens/staff_list_screen.dart';
import '../../features/qr_share/presentation/screens/qr_share_screen.dart';
import '../../features/admin_qr/presentation/screens/admin_qr_scanner_screen.dart';
import '../../features/settings/presentation/screens/grace_period_screen.dart';
import '../../features/settings/presentation/screens/id_card_customizer_screen.dart';

import '../../features/student_app/presentation/screens/student_home_screen.dart';
import '../../features/student_app/presentation/screens/my_membership_screen.dart';
import '../../features/student_app/presentation/screens/my_receipts_screen.dart';
import '../../features/student_app/presentation/screens/my_profile_screen.dart';
import '../../features/student_app/presentation/screens/my_payment_history_screen.dart';

import '../../features/registration/presentation/screens/student_registration_wizard.dart';
import '../../features/student_app/presentation/screens/student_feedback_screen.dart';
import '../../features/student_app/presentation/screens/renew_plan_screen.dart';
import '../../features/student_app/presentation/screens/my_id_card_screen.dart';
import '../../features/id_cards/presentation/screens/id_card_preview_screen.dart';
import '../../features/students/presentation/providers/student_providers.dart';
import '../../features/settings/presentation/screens/account_deletion_screen.dart';
import 'package:study_library/features/legal/presentation/screens/onboarding_consent_screen.dart';

class Routes {
  static const splash = '/splash';
  static const consent = '/consent';
  static const login = '/login';
  static const biometricLock = '/biometric-lock';
  static const setupWizard = '/setup-wizard';
  static const accessRestricted = '/access-restricted';

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
  static const adminRevenue = '/admin/revenue';
  static const adminGenerateReceipt = '/admin/receipts/generate/:studentId';
  static const adminReceiptTemplate = '/admin/receipts/template';
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
  static const adminNotifications = '/admin/settings/notifications';
  static const adminRules = '/admin/settings/rules';
  static const adminWaitingList = '/admin/settings/waiting-list';
  static const adminWaitingQueue = '/admin/waiting-queue';
  static const adminGracePeriod = '/admin/settings/grace-period';
  static const adminQrShare = '/admin/qr-share';
  static const adminQrScanner = '/admin/qr-scanner';
  static const adminWhitelist = '/admin/settings/admin-whitelist';
  static const adminStaff = '/admin/settings/staff';
  
  static const adminBackup = '/admin/backup';
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
  static const accountDeletion = '/student/account-deletion';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _adminShellNavigatorKey = GlobalKey<NavigatorState>();
final _studentShellNavigatorKey = GlobalKey<NavigatorState>();



final appRouterProvider = Provider<GoRouter>((ref) {
  // Watch role changes so router refreshes when user signs in/out
  final role = ref.watch(userRoleProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.splash,
    // ── Security: Role-based redirect guard ─────────────────────────────────
    redirect: (context, state) {
      final path = state.uri.toString();

      // Public routes — always accessible
      final publicRoutes = [
        Routes.splash,
        Routes.consent,
        Routes.login,
        Routes.biometricLock,
        Routes.accessRestricted,
        Routes.setupWizard,
        Routes.studentRegister,
      ];
      if (publicRoutes.any((r) => path == r || path.startsWith(r))) {
        return null; // allow
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

      return null; // allow
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.consent,
        builder: (context, state) => const OnboardingConsentScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.biometricLock,
        builder: (context, state) => const BiometricLockScreen(),
      ),
      GoRoute(
        path: Routes.setupWizard,
        builder: (context, state) => const SetupWizardScreen(),
      ),
      GoRoute(
        path: Routes.accessRestricted,
        builder: (context, state) => const AccessRestrictedScreen(),
      ),

      // Admin Routes
      ShellRoute(
        navigatorKey: _adminShellNavigatorKey,
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: Routes.adminHome,
            builder: (context, state) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: Routes.adminSeats,
            builder: (context, state) => const SeatMapScreen(),
          ),
          GoRoute(
            path: Routes.adminStudents,
            builder: (context, state) => const StudentListScreen(),
          ),
          GoRoute(
            path: Routes.adminMore,
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
      
      // Admin Sub-routes
      GoRoute(
        path: Routes.adminSeatsSection,
        builder: (context, state) => SectionDetailScreen(sectionId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(path: Routes.adminSeatsAddSection, builder: (context, state) {
        return Consumer(builder: (ctx, ref, _) {
          final libId = ref.watch(currentLibraryIdProvider) ?? '';
          return AddSectionScreen(libraryId: libId);
        });
      }),
      GoRoute(path: Routes.adminStudentAdd, builder: (context, state) => const AddStudentScreen()),
      GoRoute(path: Routes.adminStudentImport, builder: (context, state) => const BulkImportScreen()),
      GoRoute(path: Routes.adminStudentDetail, builder: (context, state) => StudentDetailScreen(studentId: state.pathParameters['id'] ?? '')),
      GoRoute(path: Routes.adminStudentEdit, builder: (context, state) => EditStudentScreen(studentId: state.pathParameters['id'] ?? '')),
      GoRoute(path: Routes.adminStudentHistory, builder: (context, state) => StudentHistoryScreen(studentId: state.pathParameters['id'] ?? '')),
      GoRoute(
        path: Routes.adminStudentIdCard,
        builder: (context, state) {
          final studentId = state.pathParameters['id'] ?? '';
          return Consumer(
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
          );
        },
      ),
      GoRoute(path: Routes.adminPlans, builder: (context, state) => const PlanListScreen()),
      GoRoute(path: Routes.adminPlanAdd, builder: (context, state) => const AddPlanScreen()),
      GoRoute(path: Routes.adminPlanEdit, builder: (context, state) {
        final planId = state.pathParameters['id'] ?? '';
        return Consumer(builder: (ctx, ref, _) {
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
        });
      }),
      GoRoute(path: Routes.adminRecordPayment, builder: (context, state) {
        final studentId = state.pathParameters['studentId'] ?? '';
        return Consumer(builder: (ctx, ref, _) {
          return _PaymentRouteWrapper(studentId: studentId);
        });
      }),
      GoRoute(path: Routes.adminReceipts, builder: (context, state) => const ReceiptListScreen()),
      GoRoute(path: Routes.adminRevenue, builder: (context, state) => const RevenueDashboardScreen()),
      GoRoute(
        path: Routes.adminGenerateReceipt,
        builder: (context, state) {
          final studentId = state.pathParameters['studentId'] ?? '';
          // amount and paymentMethod may be passed as query params from RecordPaymentScreen
          final amountParam = state.uri.queryParameters['amount'];
          final methodParam = state.uri.queryParameters['method'];
          return Consumer(builder: (ctx, ref, _) {
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
          });
        },
      ),
      GoRoute(path: Routes.adminReceiptTemplate, builder: (context, state) => const ReceiptTemplateScreen()),
      GoRoute(path: Routes.adminIdCardTemplate, builder: (context, state) => const IdCardCustomizerScreen()),
      GoRoute(
        path: Routes.adminReceiptPreview,
        builder: (context, state) => ReceiptPreviewScreen(receiptId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(path: Routes.adminRequests, builder: (context, state) => const RequestListScreen()),
      GoRoute(path: Routes.adminRequestDetail, builder: (context, state) => RequestDetailScreen(requestId: state.pathParameters['id'] ?? '')),
      GoRoute(path: Routes.adminAnnouncements, builder: (context, state) => const AnnouncementListScreen()),
      GoRoute(path: Routes.adminHolidays, builder: (context, state) => const HolidayCalendarScreen()),
      GoRoute(path: Routes.adminFeedback, builder: (context, state) => const FeedbackListScreen()),
      GoRoute(path: Routes.adminSettings, builder: (context, state) => const SettingsScreen()),
      GoRoute(path: Routes.adminLibraryProfile, builder: (context, state) => const LibraryProfileScreen()),
      GoRoute(path: Routes.adminFormCustomizer, builder: (context, state) => const FormCustomizerScreen()),
      GoRoute(path: Routes.adminPaymentMethods, builder: (context, state) => const PaymentMethodsScreen()),
      GoRoute(path: Routes.adminNotifications, builder: (context, state) => const NotificationSettingsScreen()),
      GoRoute(path: Routes.adminBackup, builder: (context, state) => const BackupRestoreScreen()),
      GoRoute(path: Routes.adminAuditLog, builder: (context, state) => const AuditLogScreen()),
      GoRoute(path: Routes.adminRecycleBin, builder: (context, state) => const RecycleBinScreen()),
      GoRoute(path: Routes.adminRules, builder: (context, state) => const RulesEditorScreen()),
      GoRoute(path: Routes.adminWaitingList, builder: (context, state) => const WaitingListSettingsScreen()),
      GoRoute(path: Routes.adminWaitingQueue, builder: (context, state) => const WaitingListScreen()),
      GoRoute(path: Routes.adminWhitelist, builder: (context, state) => const AdminWhitelistScreen()),
      GoRoute(path: Routes.adminStaff, builder: (context, state) => const StaffListScreen()),
      GoRoute(path: Routes.adminGracePeriod, builder: (context, state) => const GracePeriodScreen()),
      GoRoute(path: Routes.adminQrShare, builder: (context, state) => const QrShareScreen()),
      GoRoute(path: Routes.adminQrScanner, builder: (context, state) => const AdminQrScannerScreen()),

      // Student Routes
      ShellRoute(
        navigatorKey: _studentShellNavigatorKey,
        builder: (context, state, child) => StudentShell(child: child),
        routes: [
          GoRoute(
            path: Routes.studentHome,
            builder: (context, state) => const StudentHomeScreen(),
          ),
          GoRoute(
            path: Routes.studentMembership,
            builder: (context, state) => const MyMembershipScreen(),
          ),
          GoRoute(
            path: Routes.studentReceipts,
            builder: (context, state) => const MyReceiptsScreen(),
          ),
          GoRoute(
            path: Routes.studentProfile,
            builder: (context, state) => const MyProfileScreen(),
          ),
          GoRoute(
            path: Routes.studentPaymentHistory,
            builder: (context, state) => const MyPaymentHistoryScreen(),
          ),
        ],
      ),
      
      // Student Sub-routes
      GoRoute(path: Routes.studentRegister, builder: (context, state) => const StudentRegistrationWizard()),
      GoRoute(path: Routes.studentSeatMap, builder: (context, state) => const SeatMapScreen()),
      GoRoute(path: Routes.studentFeedback, builder: (context, state) => const StudentFeedbackScreen()),
      GoRoute(path: Routes.studentRenew, builder: (context, state) => const RenewPlanScreen()),
      GoRoute(path: Routes.studentIdCard, builder: (context, state) => const MyIdCardScreen()),
      GoRoute(path: Routes.accountDeletion, builder: (context, state) => const AccountDeletionScreen()),
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStudent();
  }

  Future<void> _loadStudent() async {
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty || widget.studentId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final doc = await FirebaseFirestore.instance
        .collection('libraries').doc(libraryId)
        .collection('students').doc(widget.studentId).get();
    if (doc.exists && mounted) {
      setState(() {
        _student = StudentModel.fromJson({...doc.data()!, 'id': doc.id});
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_student == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Student not found')));
    return RecordPaymentScreen(
      studentId: _student!.id,
      studentName: _student!.name,
      planPrice: 0,
    );
  }
}

