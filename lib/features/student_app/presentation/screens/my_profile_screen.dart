import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/core/security/encryption_service.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/services/badge_service.dart';
import 'package:study_library/services/expiry_scheduler_service.dart';
import 'package:study_library/services/form_config_service.dart';
import 'package:study_library/features/settings/presentation/screens/security_settings_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_library/core/providers/theme_provider.dart';
import 'package:study_library/core/error/error_handler.dart';
import 'package:study_library/services/app_notification_service.dart';
import 'package:study_library/core/utils/error_formatter.dart';
import 'package:study_library/core/constants/app_constants.dart';
import 'package:study_library/services/whats_new_service.dart';
import 'package:study_library/services/force_update_service.dart';
import 'package:study_library/core/utils/web_reload_helper.dart';
import 'package:study_library/core/widgets/update_reminder_dialog.dart';
import 'package:study_library/core/widgets/facility_tour_sheet.dart';
import 'package:study_library/core/widgets/cozy_settings_tile.dart';

class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  bool _isUploadingPhoto = false;

  Future<void> _changePhoto(StudentModel student, String libraryId) async {
    final photoUrl = await ImageService.pickAndUploadImage(
      context: context,
      folder: 'students/${student.id}',
    );

    if (photoUrl != null && mounted) {
      setState(() => _isUploadingPhoto = true);
      try {
        if (photoUrl.length > 500 * 1024) {
          throw Exception('Photo exceeds compressed size limit. Please select a standard portrait photo.');
        }
        await FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('students')
            .doc(student.id)
            .update({
          'photoUrl': photoUrl,
          'updatedAt': DateTime.now().toIso8601String(),
        });
        ref.invalidate(currentStudentProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update photo: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploadingPhoto = false);
      }
    }
  }

  void _showHolidaysSheet(String libraryId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final dateFormat = DateFormat('EEE, dd MMM yyyy');
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          builder: (context, scrollController) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('libraries')
                  .doc(libraryId)
                  .collection('holidays')
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.celebration_rounded, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Text('Upcoming Library Holidays', style: Theme.of(context).textTheme.titleLarge),
                        ],
                      ),
                      const Divider(height: 24),
                      if (docs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(child: Text('No upcoming holidays scheduled. Library is open every day!')),
                        )
                      else
                        ...docs.map((doc) {
                          final data = doc.data();
                          final dateStr = data['date'] as String? ?? '';
                          final date = DateTime.tryParse(dateStr) ?? DateTime.now();
                          final reason = data['reason'] ?? 'Holiday';
                          final isFullDay = data['isFullDay'] ?? true;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.event_busy_rounded, color: Colors.orange),
                              title: Text(reason, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(dateFormat.format(date)),
                              trailing: Chip(
                                label: Text(isFullDay ? 'Closed' : 'Half Day', style: const TextStyle(fontSize: 11)),
                                backgroundColor: Colors.orange.withValues(alpha: 0.12),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _contactAdmin(String? phone) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Library phone number not configured.')),
      );
      return;
    }
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _showPersonnelContactSheet(BuildContext context, ThemeData theme, dynamic library) {
    final personnel = (library is LibraryModel) ? library.populatedPersonnel : <Map<String, String>>[];
    final libName = library?.name.isNotEmpty == true ? library!.name : 'Study Centre';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.support_agent_rounded, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Library Key Personnel & Support',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          libName,
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (personnel.isEmpty)
                ListTile(
                  leading: const Icon(Icons.phone_rounded, color: Colors.green),
                  title: const Text('Reception Desk'),
                  subtitle: Text(library?.contact ?? 'No phone configured'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.phone, color: Colors.green),
                        onPressed: () => _contactAdmin(library?.contact),
                      ),
                    ],
                  ),
                )
              else
                ...personnel.map((p) {
                  final role = p['role'] ?? 'Staff';
                  final name = p['name'] ?? '';
                  final phone = p['contact'] ?? '';
                  final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
                  final waPhone = cleanPhone.startsWith('91') || cleanPhone.length > 10 ? cleanPhone : '91$cleanPhone';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                          child: Icon(
                            role.toLowerCase().contains('owner')
                                ? Icons.person_pin_rounded
                                : (role.toLowerCase().contains('admin')
                                    ? Icons.admin_panel_settings_rounded
                                    : Icons.support_agent_rounded),
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  role.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: theme.colorScheme.primary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(phone, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton.filledTonal(
                              icon: const Icon(Icons.phone_rounded, color: Colors.green, size: 18),
                              tooltip: 'Call $role',
                              onPressed: () => _contactAdmin(phone),
                            ),
                            const SizedBox(width: 6),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF25D366), size: 18),
                              tooltip: 'WhatsApp $role',
                              onPressed: () async {
                                final msg = Uri.encodeComponent('Hello $name ($role), I am a student at $libName and need assistance.');
                                final uri = Uri.parse('https://wa.me/$waPhone?text=$msg');
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _checkForUpdates() async {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Checking for updates…'),
          ],
        ),
        duration: Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
      ),
    );

    await ref.read(updateServiceProvider.notifier).checkForUpdate(manualCheck: true);

    if (!mounted) return;
    final updateState = ref.read(updateServiceProvider);

    if (updateState.status == UpdateStatus.optionalUpdate ||
        updateState.status == UpdateStatus.forceUpdate) {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✨ A newer web version is available!'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Reload',
              textColor: Colors.amberAccent,
              onPressed: () => reloadAppWeb(),
            ),
          ),
        );
      } else {
        UpdateReminderDialog.checkAndShow(context, ref);
      }
    } else if (updateState.status == UpdateStatus.checkFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(updateState.errorMessage ?? 'Could not reach update server. Check your connection.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(kIsWeb
              ? 'Student portal is running the latest version (${AppConstants.appVersion}).'
              : 'Your app is on the latest version (${AppConstants.appVersion})!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

  void _showAboutDialog(dynamic library) {
    final theme = Theme.of(context);
    final libName = (library is LibraryModel && library.name.isNotEmpty) ? library.name : 'The Cozy Corner Study Centre';
    final libAddress = (library is LibraryModel && library.address.isNotEmpty) ? library.address : 'Front Of Reliance Fashion Factory, Nath Road, Parli-431515';
    final libContact = (library is LibraryModel && library.contact.isNotEmpty) ? library.contact : '+91 94032 43830';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.local_library_rounded, color: Color(0xFF5D4037), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                libName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cozy Corner Study Centre & Silent Reading Hall is equipped with dedicated personal desks, ergonomic chairs, high-speed Wi-Fi, and 24/7 security surveillance.',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(child: Text(libAddress, style: const TextStyle(fontSize: 12))),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(libContact, style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('App Version', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(
                    'v${AppConstants.appVersion}+${AppConstants.buildNumber}',
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    final lib = ref.read(currentLibraryProvider).value;
    final libName = lib?.name.isNotEmpty == true ? ' from ${lib!.name}' : '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: Text('Are you sure you want to sign out$libName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign Out')),
        ],
      ),
    );

    if (confirm == true) {
      await ExpirySchedulerService.cancelExpiryReminders();
      await BadgeService.clearBadge();
      ref.read(userRoleProvider.notifier).clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_current_user_role');
      await prefs.remove('persisted_role');
      await prefs.remove('persisted_uid');
      await FirebaseAuth.instance.signOut();
      if (mounted) context.go(Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final studentAsync = ref.watch(currentStudentProvider);
    final libraryAsync = ref.watch(currentLibraryProvider);
    final libraryId = ref.watch(currentLibraryIdProvider) ?? '';
    final library = libraryAsync.value;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Home',
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.studentHome),
        ),
        title: const Text('My Profile'),
        centerTitle: true,
        actions: [
          if (studentAsync.value != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Profile',
              onPressed: () => _showEditProfileSheet(context, ref, studentAsync.value!),
            ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: _signOut,
          ),
        ],
      ),
      body: studentAsync.when(
        data: (student) {
          if (student == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_off_outlined, size: 72, color: theme.colorScheme.outline),
                    const SizedBox(height: 16),
                    Text('Student Profile Not Linked', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      'This account is not associated with an enrolled student yet.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => context.push(Routes.studentRegister),
                      child: const Text('Register for Admission'),
                    ),
                  ],
                ),
              ),
            );
          }

          final hasPhoto = student.photoUrl.isNotEmpty;
          final membershipId = student.membershipNumber?.isNotEmpty == true
              ? student.membershipNumber!
              : 'CC${student.id.length >= 8 ? student.id.substring(0, 8).toUpperCase() : student.id.toUpperCase()}';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            children: [
              // 1. Executive Student Passport Header Card
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: theme.brightness == Brightness.dark
                        ? [const Color(0xFF0F172A), const Color(0xFF1E1B4B)]
                        : [const Color(0xFF1E1B4B), const Color(0xFF312E81)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF312E81).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded, size: 12, color: Color(0xFF38BDF8)),
                              SizedBox(width: 4),
                              Text(
                                'VERIFIED STUDENT',
                                style: TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.track_changes_rounded, size: 12, color: Color(0xFFFCD34D)),
                              SizedBox(width: 4),
                              Text(
                                'Target: RTO Exam',
                                style: TextStyle(
                                  color: Color(0xFFFCD34D),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Avatar with Camera Upload Icon
                    Center(
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: hasPhoto
                                ? () => ImageService.showImageViewer(
                                      context,
                                      imageUrl: student.photoUrl,
                                      title: student.name,
                                    )
                                : null,
                            child: CircleAvatar(
                              radius: 46,
                              backgroundColor: const Color(0xFF312E81),
                              backgroundImage: hasPhoto ? ImageService.getImageProvider(student.photoUrl) : null,
                              child: !hasPhoto
                                  ? Text(
                                      student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                                      style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                          ),
                          if (_isUploadingPhoto)
                            const Positioned.fill(
                              child: CircleAvatar(
                                backgroundColor: Colors.black45,
                                child: CircularProgressIndicator(color: Colors.white),
                              ),
                            ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Material(
                              color: const Color(0xFF6366F1),
                              shape: const CircleBorder(),
                              elevation: 4,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => _changePhoto(student, libraryId),
                                child: const Padding(
                                  padding: EdgeInsets.all(7.0),
                                  child: Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      student.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (student.college.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${student.course.isNotEmpty ? "${student.course} • " : ""}${student.college}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFFC7D2FE)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Chips Row (ID & Seat)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Text(
                            'ID: $membershipId',
                            style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (student.seatId != null && student.seatId!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.chair_rounded, size: 12, color: Color(0xFF34D399)),
                                const SizedBox(width: 4),
                                Text(
                                  SeatHelper.formatSeatLabel(seatId: student.seatId),
                                  style: const TextStyle(
                                    color: Color(0xFF34D399),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Bento Info Grid (4 Grouped Cards)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.phone_outlined, size: 14, color: theme.colorScheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                'DIRECT CONTACT',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(student.phone, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          if (student.email.isNotEmpty)
                            Text(student.email, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.emergency_outlined, size: 14, color: Colors.red),
                              SizedBox(width: 4),
                              Text(
                                'EMERGENCY',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            student.emergencyContact.isNotEmpty ? student.emergencyContact : student.phone,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            'Guardian: ${student.fatherName.isNotEmpty ? student.fatherName : "On Record"}',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.badge_outlined, size: 14, color: Colors.amber),
                              SizedBox(width: 4),
                              Text(
                                'GOVT ID & BLOOD',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Builder(
                            builder: (context) {
                              final raw = student.govIdNumber.trim();
                              String effectiveId = '';
                              if (raw.isNotEmpty) {
                                final attempt = EncryptionService.safeDecryptGovId(raw, libraryId);
                                if (attempt.isNotEmpty && attempt != '••••••••') {
                                  effectiveId = attempt;
                                } else if (!raw.contains('=') && raw.length <= 20) {
                                  effectiveId = raw;
                                } else {
                                  effectiveId = attempt;
                                }
                              }

                              String formattedGovId;
                              final cleanGov = effectiveId.replaceAll(' ', '');
                              if (cleanGov.isEmpty) {
                                formattedGovId = 'ID: Verified';
                              } else if (cleanGov.length == 12 && RegExp(r'^\d+$').hasMatch(cleanGov)) {
                                formattedGovId = 'ID: •••• •••• ${cleanGov.substring(8)}';
                              } else if (cleanGov.length == 10 && RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(cleanGov)) {
                                formattedGovId = 'PAN: ••••••${cleanGov.substring(6)}';
                              } else if (cleanGov.length > 4 && cleanGov != '••••••••') {
                                formattedGovId = 'ID: •••• ${cleanGov.substring(cleanGov.length - 4)}';
                              } else {
                                formattedGovId = 'ID: Verified';
                              }

                              return Text(
                                formattedGovId,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace'),
                              );
                            },
                          ),
                          Text(
                            'Blood Group: ${student.bloodGroup ?? "O+"}',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 14, color: Colors.green),
                              SizedBox(width: 4),
                              Text(
                                'RESIDENCE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            student.address.isNotEmpty ? student.address : 'Not Provided',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            student.pincode.isNotEmpty ? 'Pincode: ${student.pincode}' : 'Pincode: Not Provided',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Modern Settings Group 1: Access & Pass
              CozySettingsCard(
                margin: EdgeInsets.zero,
                children: [
                  CozySettingsTile(
                    icon: Icons.fingerprint_rounded,
                    iconColor: const Color(0xFF4F46E5),
                    title: 'Biometric & PIN App Lock',
                    subtitle: 'Protect pass, receipts & records with PIN',
                    onTap: () => SecuritySettingsDialog.show(
                      context,
                      isStudent: true,
                      studentId: student.id,
                      authUid: student.userId ?? FirebaseAuth.instance.currentUser?.uid,
                      libraryId: libraryId,
                    ),
                  ),
                  const CozySettingsDivider(),
                  CozySettingsTile(
                    icon: Icons.calendar_today_rounded,
                    iconColor: const Color(0xFFD97706),
                    title: 'Upcoming Library Holidays',
                    subtitle: 'View scheduled maintenance & closures',
                    onTap: () => _showHolidaysSheet(libraryId),
                  ),
                  const CozySettingsDivider(),
                  CozySettingsTile(
                    icon: Icons.support_agent_rounded,
                    iconColor: const Color(0xFF059669),
                    title: (library is LibraryModel && library.populatedPersonnel.isNotEmpty)
                        ? '${library.populatedPersonnel.first['role']}: ${library.populatedPersonnel.first['name']}'
                        : (library?.adminName.isNotEmpty == true ? 'Helpline: ${library!.adminName}' : 'Reception Helpline'),
                    subtitle: (library is LibraryModel && library.populatedPersonnel.length > 1)
                        ? '${library.populatedPersonnel.length} Contacts (Owner, Admin, Manager) • Tap to view'
                        : (library?.contact ?? 'Call library team'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_rounded, color: Colors.green, size: 20),
                        if (library is LibraryModel && library.populatedPersonnel.length > 1) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, size: 20),
                        ],
                      ],
                    ),
                    onTap: () {
                      if (library is LibraryModel && library.populatedPersonnel.isNotEmpty) {
                        _showPersonnelContactSheet(context, theme, library);
                      } else {
                        _contactAdmin(library?.contact);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 4. Modern Settings Group 2: Guidelines, Feedback & Theme
              CozySettingsCard(
                margin: EdgeInsets.zero,
                children: [
                  CozySettingsTile(
                    icon: Icons.gavel_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    title: 'Library Facilities & Rules Tour',
                    subtitle: 'Code of conduct, silence hours & guidelines',
                    onTap: () => FacilityTourSheet.show(context, force: true),
                  ),
                  const CozySettingsDivider(),
                  CozySettingsTile(
                    icon: Icons.rate_review_rounded,
                    iconColor: const Color(0xFFDB2777),
                    title: 'Send Feedback / Suggestion',
                    subtitle: 'Share your ideas or report a facility issue',
                    onTap: () => context.push(Routes.studentFeedback),
                  ),
                  const CozySettingsDivider(),
                  Consumer(
                    builder: (context, ref, _) {
                      final themeMode = ref.watch(themeNotifierProvider);
                      final isDark = themeMode == ThemeMode.dark;
                      return CozySettingsTile(
                        icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        iconColor: Colors.amber.shade700,
                        title: 'Dark Mode',
                        subtitle: isDark ? 'Dark theme active' : 'Light theme active',
                        trailing: Switch(
                          value: isDark,
                          onChanged: (_) {
                            HapticFeedback.lightImpact();
                            ref.read(themeNotifierProvider.notifier).toggleTheme();
                          },
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref.read(themeNotifierProvider.notifier).toggleTheme();
                        },
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 5. Modern Settings Group 3: App Updates, Legal & Info
              CozySettingsCard(
                margin: EdgeInsets.zero,
                children: [
                  CozySettingsTile(
                    icon: Icons.auto_awesome_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    title: "What's New in Cozy Corner",
                    subtitle: 'Explore latest student tools & automations',
                    onTap: () => WhatsNewService.showChangelog(context, isStudent: true),
                  ),
                  const CozySettingsDivider(),
                  CozySettingsTile(
                    icon: Icons.system_update_rounded,
                    iconColor: const Color(0xFF0284C7),
                    title: 'Check for Updates',
                    subtitle: 'v${AppConstants.appVersion}+${AppConstants.buildNumber} • Tap to check',
                    onTap: _checkForUpdates,
                  ),
                  const CozySettingsDivider(),
                  CozySettingsTile(
                    icon: Icons.description_outlined,
                    iconColor: const Color(0xFF4F46E5),
                    title: 'Terms of Service',
                    subtitle: 'Study hall guidelines & membership policy',
                    onTap: () => context.push(Routes.terms),
                  ),
                  const CozySettingsDivider(),
                  CozySettingsTile(
                    icon: Icons.shield_outlined,
                    iconColor: const Color(0xFF10B981),
                    title: 'Privacy Policy',
                    subtitle: 'Data protection & privacy guidelines',
                    onTap: () => context.push(Routes.privacyPolicy),
                  ),
                  const CozySettingsDivider(),
                  CozySettingsTile(
                    icon: Icons.info_outline_rounded,
                    iconColor: const Color(0xFF2563EB),
                    title: 'About Cozy Corner',
                    subtitle: 'Facility details & system info',
                    onTap: () => _showAboutDialog(library),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 6. Danger Zone Sign Out
              OutlinedButton.icon(
                icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18),
                label: Text('Sign Out from ${library?.name ?? "Study Centre"}', style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _signOut,
              ),
              const SizedBox(height: 32),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              ErrorHandler.handleError(err),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}

class _GovIdTile extends StatefulWidget {
  final String label;
  final String rawId;
  final String libraryId;

  const _GovIdTile({
    required this.label,
    required this.rawId,
    required this.libraryId,
  });

  @override
  State<_GovIdTile> createState() => _GovIdTileState();
}

class _GovIdTileState extends State<_GovIdTile> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final raw = widget.rawId.trim();
    String effectiveId = '';
    if (raw.isNotEmpty) {
      final attempt = EncryptionService.safeDecryptGovId(raw, widget.libraryId);
      if (attempt.isNotEmpty && attempt != '••••••••') {
        effectiveId = attempt;
      } else if (!raw.contains('=') && raw.length <= 20) {
        effectiveId = raw;
      } else {
        effectiveId = attempt;
      }
    }

    // Format display string cleanly: if hidden, show masked format e.g. •••• •••• 1234
    String displayValue;
    if (_revealed) {
      displayValue = effectiveId;
    } else {
      final clean = effectiveId.replaceAll(' ', '');
      if (clean.length == 12 && RegExp(r'^\d+$').hasMatch(clean)) {
        displayValue = '•••• •••• ${clean.substring(8)}';
      } else if (clean.length == 10 && RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(clean)) {
        displayValue = '••••••${clean.substring(6)}';
      } else if (clean.length > 4 && clean != '••••••••') {
        displayValue = '•••• •••• ${clean.substring(clean.length - 4)}';
      } else {
        displayValue = '••••••••';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.badge_rounded, size: 20, color: theme.colorScheme.outline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(height: 2),
                Text(
                  displayValue,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _revealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            tooltip: _revealed ? 'Hide ID Number' : 'Show ID Number',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _revealed = !_revealed),
          ),
          IconButton(
            icon: Icon(Icons.copy_rounded, size: 18, color: theme.colorScheme.outline),
            tooltip: 'Copy ID Number',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: effectiveId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ID Number copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

Future<void> _showEditProfileSheet(BuildContext context, WidgetRef ref, StudentModel student) async {
  final libraryId = ref.read(currentLibraryIdProvider) ?? '';
  List<Map<String, dynamic>> customFields = [];
  if (libraryId.isNotEmpty) {
    try {
      final all = await FormConfigService.fetchFormConfig(libraryId);
      customFields = all.where((f) =>
        (f['builtin'] as bool? ?? false) == false &&
        (f['visible'] as bool? ?? true) &&
        (f['showOnProfile'] as bool? ?? true)
      ).toList();
    } catch (_) { /* intentionally silent */ }
  }

  if (!context.mounted) return;

  final emergencyCtrl = TextEditingController(text: student.emergencyContact);
  final collegeCtrl = TextEditingController(text: student.college);
  final courseCtrl = TextEditingController(text: student.course);
  final yearCtrl = TextEditingController(text: student.year);
  final Map<String, TextEditingController> customCtrls = {};
  for (final f in customFields) {
    final fid = f['id']?.toString() ?? '';
    if (fid.isNotEmpty) {
      customCtrls[fid] = TextEditingController(text: student.customFields[fid]?.toString() ?? '');
    }
  }

  bool saving = false;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Edit Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              TextFormField(controller: emergencyCtrl, decoration: const InputDecoration(labelText: 'Emergency Contact', prefixIcon: Icon(Icons.emergency))),
              const SizedBox(height: 12),
              TextFormField(controller: collegeCtrl, decoration: const InputDecoration(labelText: 'College / Institution', prefixIcon: Icon(Icons.school))),
              const SizedBox(height: 12),
              TextFormField(controller: courseCtrl, decoration: const InputDecoration(labelText: 'Course', prefixIcon: Icon(Icons.book))),
              const SizedBox(height: 12),
              TextFormField(controller: yearCtrl, decoration: const InputDecoration(labelText: 'Year / Semester', prefixIcon: Icon(Icons.calendar_today))),
              if (customFields.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Additional Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),
                ...customFields.map((f) {
                  final fid = f['id']?.toString() ?? '';
                  final label = f['label']?.toString() ?? fid;
                  final ctrl = customCtrls[fid];
                  if (ctrl == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: ctrl,
                      decoration: InputDecoration(
                        labelText: label,
                        prefixIcon: const Icon(Icons.edit_note_rounded),
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: saving ? null : () async {
                    setSheetState(() => saving = true);
                    try {
                      if (libraryId.isEmpty) throw Exception('Library ID not found');

                      final proposedCustom = <String, dynamic>{};
                      for (final entry in customCtrls.entries) {
                        if (entry.key.isNotEmpty) {
                          proposedCustom[entry.key] = entry.value.text.trim();
                        }
                      }

                      final requestRef = FirebaseFirestore.instance
                          .collection('libraries')
                          .doc(libraryId)
                          .collection('requests')
                          .doc();

                      await requestRef.set({
                        'id': requestRef.id,
                        'studentId': student.id,
                        'studentName': student.name,
                        'studentPhone': student.phone,
                        'type': 'profile_update',
                        'title': 'Profile Information Update',
                        'description': 'Student requested profile update',
                        'currentData': {
                          'emergencyContact': student.emergencyContact,
                          'college': student.college,
                          'course': student.course,
                          'year': student.year,
                          'customFields': student.customFields,
                        },
                        'proposedData': {
                          'emergencyContact': emergencyCtrl.text.trim(),
                          'college': collegeCtrl.text.trim(),
                          'course': courseCtrl.text.trim(),
                          'year': yearCtrl.text.trim(),
                          'customFields': proposedCustom,
                        },
                        'status': 'pending',
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      await AppNotificationService.sendNotification(
                        libraryId: libraryId,
                        title: 'Profile Update Request',
                        body: '${student.name} requested profile updates.',
                        type: 'profile_update_request',
                        targetRole: 'admin',
                        actionRoute: Routes.adminRequests,
                        metadata: {
                          'studentId': student.id,
                          'studentName': student.name,
                        },
                      );

                      await FirebaseFirestore.instance
                          .collection('libraries')
                          .doc(libraryId)
                          .collection('admin_notifications')
                          .add({
                        'type': 'profile_update_request',
                        'title': 'Profile Update Request',
                        'body': '${student.name} requested profile updates.',
                        'createdAt': FieldValue.serverTimestamp(),
                        'read': false,
                      });

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profile update request submitted to admin for approval ✓'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      setSheetState(() => saving = false);
                      if (ctx.mounted) {
                        AppErrorFormatter.showErrorSnackBar(ctx, e, actionContext: 'student');
                      }
                    }
                  },
                  child: saving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  emergencyCtrl.dispose();
  collegeCtrl.dispose();
  courseCtrl.dispose();
  yearCtrl.dispose();
  for (final c in customCtrls.values) {
    c.dispose();
  }
}
