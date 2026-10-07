import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/core/providers/library_provider.dart';

class WaitingListSettingsScreen extends ConsumerStatefulWidget {
  const WaitingListSettingsScreen({super.key});

  @override
  ConsumerState<WaitingListSettingsScreen> createState() => _WaitingListSettingsScreenState();
}

class _WaitingListSettingsScreenState extends ConsumerState<WaitingListSettingsScreen> {
  String _mode = 'waiting_list';
  bool _isLoading = true;
  bool _isSaving = false;

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
      if (doc.exists && mounted) {
        final mode = doc.data()?['waitingListMode'] as String? ?? 'waiting_list';
        setState(() => _mode = mode);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading: $e')));
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('libraries').doc(libraryId).update({
        'waitingListMode': _mode,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      ref.invalidate(currentLibraryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Capacity settings saved successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capacity & Waiting List')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'What happens when all seats are full?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                RadioGroup<String>(
                  groupValue: _mode,
                  onChanged: (String? v) {
                    if (v != null) setState(() => _mode = v);
                  },
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          title: const Text('Enable Waiting List Queue', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Students can join a digital queue and are notified when a seat becomes free.'),
                          value: 'waiting_list',
                        ),
                        const Divider(height: 1),
                        RadioListTile<String>(
                          title: const Text('Show "Library Full" Notice', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Students see a standard library full message without joining a queue.'),
                          value: 'no_seats',
                        ),
                        const Divider(height: 1),
                        RadioListTile<String>(
                          title: const Text('Prompt Contact Administrator', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Students are prompted to call or message library management directly.'),
                          value: 'contact_admin',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text('Student View Preview:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Center(
                      child: Text(
                        _mode == 'waiting_list'
                            ? 'Library is currently full. Would you like to join the waiting list (Queue Pos: #4)?'
                            : _mode == 'no_seats'
                                ? 'Sorry, all study desks are currently occupied. Please check back later.'
                                : 'All desks are occupied. Please contact library management directly for priority booking.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(height: 1.4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _saveSettings,
                    icon: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded),
                    label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ],
            ),
    );
  }
}
