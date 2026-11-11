import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/models/staff_model.dart';
import 'package:study_library/features/staff/presentation/providers/staff_providers.dart';
import 'package:study_library/core/security/audit_logger.dart';
import 'package:study_library/core/utils/app_validators.dart';
import 'package:study_library/core/error/error_handler.dart';

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
    bool canViewRevenue = existingStaff?.canViewRevenue ?? (selectedRole != StaffRole.operator);
    bool canManageSettings = existingStaff?.canManageSettings ?? (selectedRole == StaffRole.admin);
    bool canManagePlans = existingStaff?.canManagePlans ?? (selectedRole != StaffRole.operator);
    bool canExportData = existingStaff?.canExportData ?? (selectedRole == StaffRole.admin);
    bool canManageRequests = existingStaff?.canManageRequests ?? (selectedRole != StaffRole.operator);
    bool canViewAuditLog = existingStaff?.canViewAuditLog ?? (selectedRole != StaffRole.operator);

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
              top: 16,
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
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Top Header with Title and Close (✕) Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                existingStaff == null
                                    ? 'Add Staff / Admin Member'
                                    : 'Edit Staff Permissions',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Assign a Google email and configure access permissions.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 24),
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => AppValidators.name(v, label: 'Staff Member Name'),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: emailController,
                      enabled: existingStaff == null,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Google Email Address *',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                        hintText: 'admin_or_staff@gmail.com',
                      ),
                      validator: (v) => AppValidators.email(v, required: true, label: 'Email Address'),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<StaffRole>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Role & Tier',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: StaffRole.admin,
                          child: Text('🛡️ Admin / Co-Owner (Full Library Access)'),
                        ),
                        DropdownMenuItem(
                          value: StaffRole.manager,
                          child: Text('💼 Manager (Operations & Billing)'),
                        ),
                        DropdownMenuItem(
                          value: StaffRole.operator,
                          child: Text('👤 Operator (Front Desk & Seating Only)'),
                        ),
                      ],
                      onChanged: (role) {
                        if (role != null) {
                          setModalState(() {
                            selectedRole = role;
                            if (role == StaffRole.admin) {
                              canManageSeats = true;
                              canRecordPayments = true;
                              canManageStudents = true;
                              canDeleteStudents = true;
                              canViewRevenue = true;
                              canManageSettings = true;
                              canManagePlans = true;
                              canExportData = true;
                              canManageRequests = true;
                              canViewAuditLog = true;
                            } else if (role == StaffRole.manager) {
                              canManageSeats = true;
                              canRecordPayments = true;
                              canManageStudents = true;
                              canDeleteStudents = false;
                              canViewRevenue = true;
                              canManageSettings = false;
                              canManagePlans = true;
                              canExportData = false;
                              canManageRequests = true;
                              canViewAuditLog = true;
                            } else {
                              canManageSeats = true;
                              canRecordPayments = true;
                              canManageStudents = false;
                              canDeleteStudents = false;
                              canViewRevenue = false;
                              canManageSettings = false;
                              canManagePlans = false;
                              canExportData = false;
                              canManageRequests = false;
                              canViewAuditLog = false;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Operational Privileges',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
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
                      title: const Text('Approve / Reject Admissions'),
                      subtitle: const Text('Review and approve new student online requests'),
                      value: canManageRequests,
                      onChanged: (v) => setModalState(() => canManageRequests = v),
                    ),
                    SwitchListTile(
                      dense: true,
                      title: const Text('Manage Membership Plans & Fees'),
                      subtitle: const Text('Create, modify, and price subscription plans'),
                      value: canManagePlans,
                      onChanged: (v) => setModalState(() => canManagePlans = v),
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
                      title: const Text('Export Data & Backups'),
                      subtitle: const Text('Download full database backups and CSV reports'),
                      value: canExportData,
                      onChanged: (v) => setModalState(() => canExportData = v),
                    ),
                    SwitchListTile(
                      dense: true,
                      title: const Text('View Security & Audit Trail'),
                      subtitle: const Text('Inspect administrative logs, device logins and changes'),
                      value: canViewAuditLog,
                      onChanged: (v) => setModalState(() => canViewAuditLog = v),
                    ),
                    SwitchListTile(
                      dense: true,
                      title: const Text('Manage Library Settings'),
                      subtitle: const Text('Edit library profile, operating hours, and configuration'),
                      value: canManageSettings,
                      onChanged: (v) => setModalState(() => canManageSettings = v),
                    ),
                    const SizedBox(height: 24),

                    // Bottom Buttons: Cancel and Save
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
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
                                  canManagePlans: canManagePlans,
                                  canExportData: canExportData,
                                  canManageRequests: canManageRequests,
                                  canViewAuditLog: canViewAuditLog,
                                  createdAt: DateTime.now(),
                                );
                                await repo.addStaff(libraryId, newStaff);
                                AuditLogger().log(
                                  action: AuditAction.created,
                                  entityType: AuditEntity.staff,
                                  libraryId: libraryId,
                                  entityId: newStaff.id,
                                  entityName: newStaff.name,
                                  details: {'email': newStaff.email, 'role': newStaff.role.name},
                                ).ignore();
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
                                  canManagePlans: canManagePlans,
                                  canExportData: canExportData,
                                  canManageRequests: canManageRequests,
                                  canViewAuditLog: canViewAuditLog,
                                  updatedAt: DateTime.now(),
                                );
                                await repo.updateStaff(libraryId, updated);
                                AuditLogger().log(
                                  action: AuditAction.updated,
                                  entityType: AuditEntity.staff,
                                  libraryId: libraryId,
                                  entityId: updated.id,
                                  entityName: updated.name,
                                  details: {'email': updated.email, 'role': updated.role.name},
                                ).ignore();
                              }

                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      existingStaff == null
                                          ? 'Staff member invited and authorized!'
                                          : 'Permissions updated!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              existingStaff == null ? 'Save & Authorize' : 'Save Changes',
                            ),
                          ),
                        ),
                      ],
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
              AuditLogger().log(
                action: AuditAction.deleted,
                entityType: AuditEntity.staff,
                libraryId: libraryId,
                entityId: staff.id,
                entityName: staff.name,
                details: {'email': staff.email},
              ).ignore();
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
        title: const Text('Staff & Admin Access'),
      ),
      floatingActionButton: (isOwner && (staffAsync.value?.isNotEmpty ?? false))
          ? FloatingActionButton.extended(
              onPressed: () => _showStaffDialog(),
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Add Member'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(staffListStreamProvider);
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
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
                      'Delegate library operations to co-owners, admins, managers, and front-desk staff with granular role-based permissions.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Owner Card
            Text(
              'Primary Library Owner',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFFEF3C7),
                      radius: 20,
                      child: Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentUser?.uid == library?.ownerId
                                ? (currentUser?.displayName ?? 'You (Primary Owner)')
                                : 'Primary Owner',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentUser?.uid == library?.ownerId
                                ? (currentUser?.email ?? '')
                                : 'Primary License Holder',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: const Text(
                        '👑 OWNER',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Staff & Admin List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Authorized Administrators & Staff',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (staffAsync.value != null)
                  Text(
                    '${staffAsync.value!.length} active',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                  ),
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
                            const Text('No additional administrators or staff members added yet.'),
                            if (isOwner) ...[
                              const SizedBox(height: 16),
                              FilledButton.tonalIcon(
                                onPressed: () => _showStaffDialog(),
                                icon: const Icon(Icons.person_add_rounded),
                                label: const Text('Add Co-Owner / Staff Member'),
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
                    final isAdmin = staff.role == StaffRole.admin;
                    final isManager = staff.role == StaffRole.manager;

                    final Color badgeBg = isAdmin
                        ? const Color(0xFFE0E7FF)
                        : isManager
                            ? const Color(0xFFF3E5AB)
                            : const Color(0xFFF3F4F6);
                    final Color badgeColor = isAdmin
                        ? const Color(0xFF3730A3)
                        : isManager
                            ? const Color(0xFF5D4037)
                            : const Color(0xFF4B5563);
                    final String badgeLabel = isAdmin
                        ? 'ADMIN / CO-OWNER'
                        : isManager
                            ? 'MANAGER'
                            : 'OPERATOR';

                    final chips = [
                      if (staff.canManageSeats) _permChip('Seats'),
                      if (staff.canRecordPayments) _permChip('Billing'),
                      if (staff.canManageStudents) _permChip('Students'),
                      if (staff.canManageRequests) _permChip('Admissions'),
                      if (staff.canManagePlans) _permChip('Plans'),
                      if (staff.canViewRevenue) _permChip('Revenue'),
                      if (staff.canExportData) _permChip('Export'),
                      if (staff.canViewAuditLog) _permChip('Audit Trail'),
                    ];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Tier 1: Avatar, Name, Email, Role Badge & Options Menu
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: badgeBg,
                                  radius: 20,
                                  child: Icon(
                                    isAdmin
                                        ? Icons.verified_user_rounded
                                        : isManager
                                            ? Icons.shield_rounded
                                            : Icons.person_rounded,
                                    color: badgeColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        staff.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        staff.email,
                                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    badgeLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: badgeColor,
                                    ),
                                  ),
                                ),
                                if (isOwner)
                                  PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                    onSelected: (val) {
                                      if (val == 'edit') {
                                        _showStaffDialog(existingStaff: staff);
                                      } else if (val == 'delete') {
                                        _confirmDeleteStaff(staff, libraryId);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit Permissions'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Remove Member', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                              ],
                            ),

                            // Tier 2: Full-width Permission Chips
                            if (chips.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              const Divider(height: 1),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: chips,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()),
              ),
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
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black87),
      ),
    );
  }
}
