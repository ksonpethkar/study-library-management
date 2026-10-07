import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/core/providers/library_provider.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  bool _allNotifications = true;
  bool _newRequest = true;
  bool _planExpiring = true;
  bool _planExpired = true;
  bool _announcementPush = true;
  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('libraries').doc(libraryId).get();
      final n = (doc.data()?['notificationSettings'] as Map<String, dynamic>?) ?? {};
      setState(() {
        _allNotifications = n['allNotifications'] as bool? ?? true;
        _newRequest = n['newRequest'] as bool? ?? true;
        _planExpiring = n['planExpiring'] as bool? ?? true;
        _planExpired = n['planExpired'] as bool? ?? true;
        _announcementPush = n['announcementPush'] as bool? ?? true;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('libraries').doc(libraryId).update({
        'notificationSettings': {
          'allNotifications': _allNotifications,
          'newRequest': _newRequest,
          'planExpiring': _planExpiring,
          'planExpired': _planExpired,
          'announcementPush': _announcementPush,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification settings saved ✓'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveSettings,
            icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
            label: Text(_isSaving ? 'Saving...' : 'Save'),
          ),
        ],
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('All Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Master switch for all push and in-app notifications'),
            value: _allNotifications,
            onChanged: (val) => setState(() {
              _allNotifications = val;
              if (!val) { _newRequest = false; _planExpiring = false; _planExpired = false; _announcementPush = false; }
            }),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('ADMIN NOTIFICATIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey)),
          ),
          SwitchListTile(
            title: const Text('New Student Request'),
            subtitle: const Text('Push + in-app when a student submits registration'),
            value: _newRequest,
            onChanged: _allNotifications ? (val) => setState(() => _newRequest = val) : null,
          ),
          SwitchListTile(
            title: const Text('Plan Expiring Soon'),
            subtitle: const Text('Push + in-app when student plan is near expiry'),
            value: _planExpiring,
            onChanged: _allNotifications ? (val) => setState(() => _planExpiring = val) : null,
          ),
          SwitchListTile(
            title: const Text('Plan Expired'),
            subtitle: const Text('Push + in-app when a student membership expires'),
            value: _planExpired,
            onChanged: _allNotifications ? (val) => setState(() => _planExpired = val) : null,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('STUDENT NOTIFICATIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey)),
          ),
          SwitchListTile(
            title: const Text('Announcement Push Notifications'),
            subtitle: const Text('Send FCM push to all students on new announcements'),
            value: _announcementPush,
            onChanged: _allNotifications ? (val) => setState(() => _announcementPush = val) : null,
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _saveSettings,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save Notification Settings'),
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
