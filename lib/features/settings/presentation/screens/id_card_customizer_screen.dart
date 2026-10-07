import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/models/id_card_template_model.dart';

final idCardTemplateProvider = StreamProvider<IdCardTemplateSettings>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty) {
    return Stream.value(const IdCardTemplateSettings());
  }

  return FirebaseFirestore.instance
      .collection('libraries')
      .doc(libraryId)
      .collection('settings')
      .doc('id_card_template')
      .snapshots()
      .map((doc) {
    if (!doc.exists || doc.data() == null) {
      return const IdCardTemplateSettings();
    }
    return IdCardTemplateSettings.fromJson(doc.data()!);
  });
});

class IdCardCustomizerScreen extends ConsumerStatefulWidget {
  const IdCardCustomizerScreen({super.key});

  @override
  ConsumerState<IdCardCustomizerScreen> createState() => _IdCardCustomizerScreenState();
}

class _IdCardCustomizerScreenState extends ConsumerState<IdCardCustomizerScreen> {
  IdCardTemplateSettings _settings = const IdCardTemplateSettings();
  final _rulesController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _rulesController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('id_card_template')
          .get();

      if (doc.exists && mounted && doc.data() != null) {
        final s = IdCardTemplateSettings.fromJson(doc.data()!);
        setState(() {
          _settings = s;
          _rulesController.text = s.customRulesText;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final updated = _settings.copyWith(customRulesText: _rulesController.text.trim());
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('id_card_template')
          .set({
        ...updated.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ref.invalidate(idCardTemplateProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ID Card template saved! Reflected in admin and student app.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Customize ID Card')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customize ID Card Layout'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded),
            tooltip: 'Save Settings',
            onPressed: _isSaving ? null : _saveSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.badge_rounded, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Front Card Elements', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Student Photo'),
                    subtitle: const Text('Show passport photo on the left'),
                    value: _settings.showPhoto,
                    onChanged: (v) => setState(() => _settings = _settings.copyWith(showPhoto: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Verification QR Code'),
                    subtitle: const Text('Scan to verify active membership'),
                    value: _settings.showQrCode,
                    onChanged: (v) => setState(() => _settings = _settings.copyWith(showQrCode: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Assigned Seat & Section'),
                    subtitle: const Text('e.g. A-12 (Main Hall)'),
                    value: _settings.showSeat,
                    onChanged: (v) => setState(() => _settings = _settings.copyWith(showSeat: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Membership Plan Name'),
                    subtitle: const Text('e.g. Dedicated Desk (Monthly)'),
                    value: _settings.showPlan,
                    onChanged: (v) => setState(() => _settings = _settings.copyWith(showPlan: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Validity Expiration Date'),
                    subtitle: const Text('Valid Till: DD/MM/YYYY'),
                    value: _settings.showValidTill,
                    onChanged: (v) => setState(() => _settings = _settings.copyWith(showValidTill: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Library Address & Helpline Footer'),
                    value: _settings.showAddress,
                    onChanged: (v) => setState(() => _settings = _settings.copyWith(showAddress: v)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.contact_phone_rounded, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Back Card Elements', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Guardian / Father Name'),
                    value: _settings.showFatherName,
                    onChanged: (v) => setState(() => _settings = _settings.copyWith(showFatherName: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Emergency Contact Badge'),
                    subtitle: const Text('Emergency contact number highlighted on back'),
                    value: _settings.showEmergencyContact,
                    onChanged: (v) => setState(() => _settings = _settings.copyWith(showEmergencyContact: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Library Rules & Guidelines'),
                    value: _settings.showRules,
                    onChanged: (v) => setState(() => _settings = _settings.copyWith(showRules: v)),
                  ),
                  if (_settings.showRules) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _rulesController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Custom Terms / Rules (Optional, 1 per line)',
                        hintText: 'Leave empty for default library rules',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isSaving ? null : _saveSettings,
            icon: const Icon(Icons.save_rounded),
            label: Text(_isSaving ? 'Saving...' : 'Save ID Card Settings'),
          ),
        ],
      ),
    );
  }
}
