import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:study_library/features/auth/services/admin_whitelist_service.dart';

class AdminWhitelistScreen extends ConsumerStatefulWidget {
  const AdminWhitelistScreen({super.key});

  @override
  ConsumerState<AdminWhitelistScreen> createState() => _AdminWhitelistScreenState();
}

class _AdminWhitelistScreenState extends ConsumerState<AdminWhitelistScreen> {
  void _showAddAdminDialog() {
    final emailController = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: Colors.indigo),
            SizedBox(width: 10),
            Text('Add Admin Email'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the Google account email address of the person you want to authorize as an administrator.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Google Email',
                  hintText: 'admin@gmail.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Email is required';
                  if (!val.contains('@') || !val.contains('.')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Designation / Note (Optional)',
                  hintText: 'e.g. Branch Co-Owner, Manager',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final currentEmail = FirebaseAuth.instance.currentUser?.email ?? 'owner';
              final targetEmail = emailController.text.trim().toLowerCase();

              await AdminWhitelistService.addWhitelistedAdmin(
                targetEmail,
                addedBy: currentEmail,
                notes: noteController.text.trim(),
              );

              if (ctx.mounted) {
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$targetEmail is now authorized as an administrator!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Authorize Admin'),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Admin Authorization?'),
        content: Text(
          'Are you sure you want to remove "$email"? They will no longer be able to log in to administrative portals.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await AdminWhitelistService.removeWhitelistedAdmin(email);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Revoked admin access for $email')),
                );
              }
            },
            child: const Text('Revoke Access'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentEmail = FirebaseAuth.instance.currentUser?.email?.toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Authorized Admin Emails'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAdminDialog,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Authorize Email'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: AdminWhitelistService.streamWhitelistedAdmins(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final admins = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Security info banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security_rounded, color: theme.colorScheme.primary, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Only emails listed here can access library setup and management features. Unauthorized Google sign-ins are restricted.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Approved Admin Accounts (${admins.length})',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              if (admins.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.shield_outlined, size: 48, color: theme.colorScheme.outline),
                          const SizedBox(height: 12),
                          const Text('No additional admin emails whitelisted yet.'),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ...admins.map((admin) {
                  final email = admin['email'] as String? ?? admin['id'] as String? ?? '';
                  final notes = admin['notes'] as String? ?? '';
                  final addedBy = admin['addedBy'] as String? ?? '';
                  final isSelf = email == currentEmail;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelf ? Colors.green.withValues(alpha: 0.15) : theme.colorScheme.primaryContainer,
                        child: Icon(
                          isSelf ? Icons.verified_user_rounded : Icons.admin_panel_settings_rounded,
                          color: isSelf ? Colors.green : theme.colorScheme.primary,
                        ),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              email,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelf) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('You', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (notes.isNotEmpty) Text(notes, style: const TextStyle(fontWeight: FontWeight.w500)),
                          if (addedBy.isNotEmpty)
                            Text(
                              'Added by: $addedBy',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                            ),
                        ],
                      ),
                      trailing: isSelf
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                              tooltip: 'Revoke Admin Access',
                              onPressed: () => _confirmRemove(email),
                            ),
                    ),
                  );
                }),
              const SizedBox(height: 80), // Fab space
            ],
          );
        },
      ),
    );
  }
}
