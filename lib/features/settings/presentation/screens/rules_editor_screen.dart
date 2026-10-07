import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/core/providers/library_provider.dart';

class RulesEditorScreen extends ConsumerStatefulWidget {
  const RulesEditorScreen({super.key});

  @override
  ConsumerState<RulesEditorScreen> createState() => _RulesEditorScreenState();
}

class _RulesEditorScreenState extends ConsumerState<RulesEditorScreen> {
  final _rulesController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('libraries').doc(libraryId).get();
      if (doc.exists && mounted) {
        final rules = doc.data()?['rulesText'] as String? ?? doc.data()?['rules'] as String? ??
            '1. Maintain complete silence in all study areas.\n'
            '2. Cell phones must be kept on silent mode at all times.\n'
            '3. Seat allocation is strictly non-transferable.\n'
            '4. Outside food and beverages (except water) are prohibited inside reading halls.\n'
            '5. Always carry your digital student ID.\n'
            '6. Keep the study spaces clean and tidy.';
        _rulesController.text = rules;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading rules: $e')));
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveRules() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final text = _rulesController.text.trim();
      await FirebaseFirestore.instance.collection('libraries').doc(libraryId).update({
        'rulesText': text,
        'rules': text,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      ref.invalidate(currentLibraryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Library rules saved successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving rules: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showPreview() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.gavel_rounded, color: Colors.indigo),
            SizedBox(width: 10),
            Text('Rules Preview'),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            _rulesController.text.isNotEmpty ? _rulesController.text : 'No rules specified.',
            style: const TextStyle(height: 1.5),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _rulesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rules & Regulations'),
        actions: [
          TextButton.icon(
            onPressed: _showPreview,
            icon: const Icon(Icons.preview_rounded),
            label: const Text('Preview'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'These rules will be displayed to students during registration and on their profile screen.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _rulesController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter library code of conduct, timings, and policies...',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _saveRules,
                      icon: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded),
                      label: Text(_isSaving ? 'Saving...' : 'Save Rules & Regulations'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
