import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/models/staff_model.dart';
import 'package:study_library/features/staff/presentation/providers/staff_providers.dart';

class StaffListScreen extends ConsumerStatefulWidget {
  const StaffListScreen({super.key});

  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen> {
  void _showStaffDialog({StaffModel? existingStaff}) {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController(text: existingStaff?.email ?? '');
    final nameController = TextEditingController(text: existingStaff?.name ?? '');
    StaffRole selectedRole = existingStaff?.role ?? StaffRole.manager;

    bool canManageSeats = existingStaff?.canManageSeats ?? true;
    bool canRecordPayments = existingStaff?.canRecordPayments ?? true;
    bool canManageStudents = existingStaff?.canManageStudents ?? true;
    bool canDeleteStudents = existingStaff?.canDeleteStudents ?? false;
    bool canViewRevenue = existingStaff?.canViewRevenue ?? (selectedRole == StaffRole.manager);
    bool canManageSettings = existingStaff?.canManageSettings ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      existingStaff == null ? 'Add Staff / Admin Member' : 'Edit Staff Permissions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Assign a Google account email and define their operational privileges.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: emailController,
                      enabled: existingStaff == null,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Google Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                        hintText: 'staff@gmail.com',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Email is required';
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<StaffRole>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: StaffRole.manager,
                          child: Text('🛡️ Manager (Operations & Billing)'),
                        ),
                        DropdownMenuItem(
                          value: StaffRole.operator,
                          child: Text('👤 Operator (Front Desk & Seating)'),
                        ),
                      ],
                      onChanged: (role) {
                        if (role != null) {
                          setModalState(() {
                            selectedRole = role;
                            if (role == StaffRole.manager) {
                              canManageSeats = true;
                              canRecordPayments = true;
                              canManageStudents = true;
                              canViewRevenue = true;
                            } else {
                              canManageSeats = true;
                              canRecordPayments = true;
                              canManageStudents = false;
                              canViewRevenue = false;
                              canManageSettings = false;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    Text('Permissions & Controls', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    SwitchListTile(
                      dense: true,
                      title: const Text('Manage Seats & Layout'),
                      subtitle: const Text('Assign desks, vacate seats, change status'),
                      value: canManageSeats,
                      onChanged: (v) => setModalState(() => canManageSeats = v),
                    ),
                    SwitchListTile(
                      dense: true,
                      title: const Text('Record Payments & Invoices'),
                      subtitle: const Text('Collect fees, mark payments, issue receipts'),
                      value: canRecordPayments,
                      onChanged: (v) => setModalState(() => canRecordPayments = v),
                    ),
                    SwitchListTile(
                      dense: true,
                      title: const Text('Add & Edit Students'),
                      subtitle: const Text('Enroll new admissions, edit profile information'),
                      value: canManageStudents,
                      onChanged: (v) => setModalState(() => canManageStudents = v),
                    ),
                    SwitchListTile(
                      dense: true,
                      title: const Text('Delete Students'),
                      subtitle: const Text('Soft delete and permanently remove student records'),
                      value: canDeleteStudents,
                      onChanged: (v) => setModalState(() => canDeleteStudents = v),
                    ),
                    SwitchListTile(
                      dense: true,
                      title: const Text('View Revenue & Financials'),
                      subtitle: const Text('Access revenue charts, collection analytics'),
                      value: canViewRevenue,
                      onChanged: (v) => setModalState(() => canViewRevenue = v),
                    ),
                    SwitchListTile(
                      dense: true,
                      title: const Text('Manage Library Settings'),
                      subtitle: const Text('Edit plans, capacity rules, and library profile'),
                      value: canManageSettings,
                      onChanged: (v) => setModalState(() => canManageSettings = v),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final repo = ref.read(staffRepositoryProvider);
                          final email = emailController.text.trim().toLowerCase();
                          final name = nameController.text.trim();

                          if (existingStaff == null) {
                            final newStaff = StaffModel(
                              id: '',
                              libraryId: libraryId,
                              userId: '',
                              email: email,
                              name: name,
                              role: selectedRole,
                              canManageSeats: canManageSeats,
                              canRecordPayments: canRecordPayments,
                              canManageStudents: canManageStudents,
                              canDeleteStudents: canDeleteStudents,
                              canViewRevenue: canViewRevenue,
                              canManageSettings: canManageSettings,
                              createdAt: DateTime.now(),
                            );
                            await repo.addStaff(libraryId, newStaff);
                          } else {
                            final updated = existingStaff.copyWith(
                              name: name,
                              role: selectedRole,
                              canManageSeats: canManageSeats,
                              canRecordPayments: canRecordPayments,
                              canManageStudents: canManageStudents,
                              canDeleteStudents: canDeleteStudents,
                              canViewRevenue: canViewRevenue,
                              canManageSettings: canManageSettings,
                              updatedAt: DateTime.now(),
                            );
                            await repo.updateStaff(libraryId, updated);
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(existingStaff == null ? 'Staff member invited and authorized!' : 'Permissions updated!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        child: Text(existingStaff == null ? 'Save & Authorize Staff' : 'Save Changes'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteStaff(StaffModel staff, String libraryId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Staff Member?'),
        content: Text(
          'Are you sure you want to remove "${staff.name}" (${staff.email})? Their administrative access to this library will be revoked immediately.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final repo = ref.read(staffRepositoryProvider);
              await repo.removeStaff(libraryId, staff.id, staff.email);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Removed ${staff.name} from staff')),
                );
              }
            },
            child: const Text('Remove Staff'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final library = ref.watch(currentLibraryProvider).value;
    final libraryId = ref.watch(currentLibraryIdProvider) ?? '';
    final staffAsync = ref.watch(staffListStreamProvider);
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = library != null && library.ownerId == currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff & Admin Roles'),
      ),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => _showStaffDialog(),
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Add Staff'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(staffListStreamProvider);
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings_rounded, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Delegate responsibilities to managers and front-desk staff with granular role-based controls.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Owner Card
          Text('Library Owner', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFEF3C7),
                child: Icon(Icons.star_rounded, color: Color(0xFFD97706)),
              ),
              title: Text(
                currentUser?.uid == library?.ownerId ? (currentUser?.displayName ?? 'You (Owner)') : 'Primary Owner',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(currentUser?.uid == library?.ownerId ? (currentUser?.email ?? '') : 'Primary License Holder'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: const Text('👑 OWNER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Staff List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Managers & Operators', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              if (staffAsync.value != null)
                Text('${staffAsync.value!.length} active', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
          const SizedBox(height: 8),

          staffAsync.when(
            data: (staffList) {
              if (staffList.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.group_outlined, size: 48, color: theme.colorScheme.outline),
                          const SizedBox(height: 12),
                          const Text('No additional staff members added yet.'),
                          if (isOwner) ...[
                            const SizedBox(height: 16),
                            FilledButton.tonalIcon(
                              onPressed: () => _showStaffDialog(),
                              icon: const Icon(Icons.person_add_rounded),
                              label: const Text('Invite First Staff Member'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: staffList.map((staff) {
                  final isManager = staff.role == StaffRole.manager;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: isManager ? const Color(0xFFEEF2FF) : const Color(0xFFF3F4F6),
                        child: Icon(
                          isManager ? Icons.shield_rounded : Icons.person_rounded,
                          color: isManager ? const Color(0xFF4F46E5) : const Color(0xFF4B5563),
                        ),
                      ),
                      title: Text(staff.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(staff.email, style: theme.textTheme.bodySmall),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (staff.canManageSeats) _permChip('Seats'),
                              if (staff.canRecordPayments) _permChip('Billing'),
                              if (staff.canManageStudents) _permChip('Students'),
                              if (staff.canViewRevenue) _permChip('Revenue'),
                            ],
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isManager ? const Color(0xFFEEF2FF) : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isManager ? 'MANAGER' : 'STAFF',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isManager ? const Color(0xFF4F46E5) : const Color(0xFF4B5563),
                              ),
                            ),
                          ),
                          if (isOwner)
                            PopupMenuButton<String>(
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _showStaffDialog(existingStaff: staff);
                                } else if (val == 'delete') {
                                  _confirmDeleteStaff(staff, libraryId);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(value: 'edit', child: Text('Edit Permissions')),
                                const PopupMenuItem(value: 'delete', child: Text('Remove Staff', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
            error: (err, _) => Center(child: Text('Error loading staff: $err')),
          ),
          const SizedBox(height: 80),
        ],
        ),
      ),
    );
  }

  Widget _permChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black87)),
    );
  }
}
