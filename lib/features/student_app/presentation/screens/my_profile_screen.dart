import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/services/whats_new_service.dart';
import 'package:study_library/services/badge_service.dart';
import 'package:study_library/services/expiry_scheduler_service.dart';

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

  void _showRulesDialog(String libraryId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          builder: (context, scrollController) {
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance.collection('libraries').doc(libraryId).get(),
              builder: (context, snapshot) {
                final rules = snapshot.data?.data()?['rulesText'] as String? ??
                    '1. Maintain complete silence in all study areas.\n'
                    '2. Cell phones must be kept on silent mode.\n'
                    '3. Seat reservations are strictly non-transferable.\n'
                    '4. Outside food is not allowed in reading halls.\n'
                    '5. Always carry your digital student ID.\n'
                    '6. Keep the study spaces clean and tidy.';

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
                          Icon(Icons.gavel_rounded, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Text('Library Rules & Guidelines', style: Theme.of(context).textTheme.titleLarge),
                        ],
                      ),
                      const Divider(height: 24),
                      Text(rules, style: const TextStyle(fontSize: 15, height: 1.6)),
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

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out from Cozy Corner?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign Out')),
        ],
      ),
    );

    if (confirm == true) {
      await ExpirySchedulerService.cancelExpiryReminders();
      await BadgeService.clearBadge();
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
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
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

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Avatar & Photo Upload
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
                        radius: 54,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        backgroundImage: hasPhoto ? ImageService.getImageProvider(student.photoUrl) : null,
                        child: !hasPhoto
                            ? Text(
                                student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                                style: TextStyle(fontSize: 44, color: theme.colorScheme.primary),
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
                        color: theme.colorScheme.primary,
                        shape: const CircleBorder(),
                        elevation: 4,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _changePhoto(student, libraryId),
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.camera_alt_rounded, size: 20, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Center(
                child: Text(
                  student.name,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (student.college.isNotEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${student.course.isNotEmpty ? "${student.course} • " : ""}${student.college}',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Personal Information Card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Personal Information', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const Divider(height: 20),
                      _ProfileTile(icon: Icons.phone_rounded, label: 'Phone', value: student.phone),
                      if (student.email.isNotEmpty)
                        _ProfileTile(icon: Icons.email_rounded, label: 'Email', value: student.email),
                      if (student.fatherName.isNotEmpty)
                        _ProfileTile(icon: Icons.family_restroom_rounded, label: "Father's Name", value: student.fatherName),
                      if (student.dob != null)
                        _ProfileTile(icon: Icons.cake_rounded, label: 'Date of Birth', value: dateFormat.format(student.dob!)),
                      _ProfileTile(icon: Icons.wc_rounded, label: 'Gender', value: student.gender.name.toUpperCase()),
                      if (student.address.isNotEmpty)
                        _ProfileTile(
                          icon: Icons.home_rounded,
                          label: 'Address',
                          value: '${student.address}${student.pincode.isNotEmpty ? " - ${student.pincode}" : ""}',
                        ),
                      if (student.emergencyContact.isNotEmpty)
                        _ProfileTile(icon: Icons.contact_emergency_rounded, label: 'Emergency Contact', value: student.emergencyContact),
                      if (student.govIdNumber.isNotEmpty)
                        _ProfileTile(
                          icon: Icons.badge_rounded,
                          label: 'Govt ID (${student.govIdType.name.toUpperCase()})',
                          value: student.govIdNumber,
                        ),
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('libraries').doc(libraryId)
                            .collection('settings').doc('form_config').get(),
                        builder: (context, snap) {
                          if (!snap.hasData) return const SizedBox();
                          final data = snap.data!.data() as Map<String, dynamic>?;
                          if (data == null) return const SizedBox();
                          final fields = (data['fields'] as List<dynamic>? ?? [])
                              .cast<Map<String, dynamic>>()
                              .where((f) =>
                                  !(f['builtin'] as bool? ?? false) && // custom fields only
                                  (f['showOnProfile'] as bool? ?? true) &&
                                  (f['visible'] as bool? ?? true))
                              .toList();
                          if (fields.isEmpty) return const SizedBox();
                          final customData = student.customFields;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 12, bottom: 4),
                                child: Text('Additional Info', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                              ),
                              ...fields.map((f) {
                                final value = customData[f['id']]?.toString() ?? '';
                                if (value.isEmpty) return const SizedBox();
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(f['label'] as String? ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  subtitle: Text(value, style: const TextStyle(fontSize: 15)),
                                );
                              }),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Library Services Card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    if (student.membershipNumber != null && student.membershipNumber!.isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.badge_rounded),
                        title: const Text('Membership ID'),
                        subtitle: Text(student.membershipNumber!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                      ),
                    if (student.membershipNumber != null && student.membershipNumber!.isNotEmpty)
                      const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.badge_rounded, color: Colors.blue),
                      title: const Text('Digital Student ID Card'),
                      subtitle: const Text('View & download official card PDF'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push(Routes.studentIdCard),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.gavel_rounded, color: theme.colorScheme.primary),
                      title: const Text('Library Rules & Guidelines'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showRulesDialog(libraryId),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.celebration_rounded, color: Colors.orange),
                      title: const Text('Upcoming Holidays'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showHolidaysSheet(libraryId),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.support_agent_rounded, color: Colors.teal),
                      title: const Text('Contact Library Admin'),
                      subtitle: Text(library?.contact ?? 'Call or WhatsApp'),
                      trailing: const Icon(Icons.call_rounded),
                      onTap: () => _contactAdmin(library?.contact),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.rate_review_rounded, color: Colors.purple),
                      title: const Text('Send Feedback / Suggestion'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push(Routes.studentFeedback),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.new_releases_rounded, color: Colors.teal),
                      title: const Text("What's New in This Version"),
                      subtitle: const Text("See latest features for students (v1.5.0)"),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => WhatsNewService.showChangelog(context, isStudent: true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Sign Out Button
              OutlinedButton.icon(
                icon: const Icon(Icons.logout_rounded, color: Colors.red),
                label: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _signOut,
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
                subtitle: const Text('Permanently delete your account and data'),
                onTap: () => context.push(Routes.accountDeletion),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading profile: $err')),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.outline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _showEditProfileSheet(BuildContext context, WidgetRef ref, StudentModel student) {
  final emergencyCtrl = TextEditingController(text: student.emergencyContact);
  final collegeCtrl = TextEditingController(text: student.college);
  final courseCtrl = TextEditingController(text: student.course);
  final yearCtrl = TextEditingController(text: student.year);
  bool saving = false;

  showModalBottomSheet(
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
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: saving ? null : () async {
                  setSheetState(() => saving = true);
                  try {
                    final libraryId = ref.read(currentLibraryIdProvider) ?? '';
                    final studentId = student.id;
                    await FirebaseFirestore.instance
                        .collection('libraries').doc(libraryId)
                        .collection('students').doc(studentId)
                        .update({
                      'emergencyContact': emergencyCtrl.text.trim(),
                      'college': collegeCtrl.text.trim(),
                      'course': courseCtrl.text.trim(),
                      'year': yearCtrl.text.trim(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile updated successfully ✓'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    setSheetState(() => saving = false);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
                      );
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
  );

  // Dispose controllers when sheet closes
  Future.delayed(const Duration(milliseconds: 500), () {
    emergencyCtrl.dispose();
    collegeCtrl.dispose();
    courseCtrl.dispose();
    yearCtrl.dispose();
  });
}
