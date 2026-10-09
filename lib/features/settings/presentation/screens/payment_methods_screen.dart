import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/core/providers/library_provider.dart';

class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen> {
  List<Map<String, dynamic>> _methods = [
    {'id': 'cash', 'name': 'Cash', 'active': true, 'details': 'Cash payment at reception'},
    {'id': 'upi', 'name': 'UPI / QR', 'active': true, 'details': 'GPay / PhonePe / Paytm'},
    {'id': 'bank', 'name': 'Bank Transfer', 'active': false, 'details': 'NEFT / RTGS / IMPS'},
  ];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadMethods();
  }

  Future<void> _loadMethods() async {
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
          .doc('payment_methods')
          .get();

      if (doc.exists && mounted) {
        final data = doc.data();
        if (data != null && data['methods'] is List) {
          final loaded = (data['methods'] as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          setState(() {
            _methods = loaded;
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMethods() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('payment_methods')
          .set({
        'methods': _methods,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment methods updated successfully!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save methods: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAddEditDialog({int? index}) {
    final isEditing = index != null;
    final current = isEditing ? _methods[index] : null;

    final nameController = TextEditingController(text: current?['name'] ?? '');
    final detailsController = TextEditingController(text: current?['details'] ?? '');
    bool isActive = current?['active'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Payment Method' : 'Add Payment Method'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Method Name (e.g. UPI, Cash, POS Card)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: detailsController,
                  decoration: const InputDecoration(
                    labelText: 'Instructions / ID (e.g. library@upi)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (val) => setDialogState(() => isActive = val),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            if (isEditing)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _methods.removeAt(index));
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                final item = {
                  'id': isEditing ? current!['id'] : DateTime.now().millisecondsSinceEpoch.toString(),
                  'name': name,
                  'details': detailsController.text.trim(),
                  'active': isActive,
                };

                setState(() {
                  if (isEditing) {
                    _methods[index] = item;
                  } else {
                    _methods.add(item);
                  }
                });

                Navigator.pop(ctx);
              },
              child: Text(isEditing ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Methods'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveMethods,
            child: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ReorderableListView(
              padding: const EdgeInsets.all(16),
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _methods.removeAt(oldIndex);
                  _methods.insert(newIndex, item);
                });
              },
              children: _methods.asMap().map((index, method) {
                final isActive = method['active'] == true;
                return MapEntry(
                  index,
                  Card(
                    key: ValueKey(method['id']),
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isActive ? theme.colorScheme.primary.withValues(alpha: 0.4) : theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: isActive
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          method['name'].toString().toLowerCase().contains('upi')
                              ? Icons.qr_code_rounded
                              : method['name'].toString().toLowerCase().contains('cash')
                                  ? Icons.money_rounded
                                  : Icons.account_balance_rounded,
                          color: isActive ? theme.colorScheme.primary : Colors.grey,
                        ),
                      ),
                      title: Text(
                        method['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isActive ? theme.colorScheme.onSurface : Colors.grey,
                        ),
                      ),
                      subtitle: method['details'].toString().isNotEmpty
                          ? Text(method['details'], style: TextStyle(color: isActive ? Colors.grey.shade700 : Colors.grey))
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: isActive,
                            onChanged: (v) => setState(() => method['active'] = v),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 20),
                            tooltip: 'Edit method',
                            onPressed: () => _showAddEditDialog(index: index),
                          ),
                          const Icon(Icons.drag_handle_rounded, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                );
              }).values.toList(),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Payment Method'),
      ),
    );
  }
}
