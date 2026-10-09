import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/core/providers/library_provider.dart';

class FormCustomizerScreen extends ConsumerStatefulWidget {
  const FormCustomizerScreen({super.key});

  @override
  ConsumerState<FormCustomizerScreen> createState() => _FormCustomizerScreenState();
}

class _FormCustomizerScreenState extends ConsumerState<FormCustomizerScreen> {
  List<Map<String, dynamic>> _fields = [
    {'id': 'name', 'label': 'Full Name', 'type': 'Text', 'required': true, 'visible': true, 'builtin': true, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false},
    {'id': 'phone', 'label': 'Phone Number', 'type': 'Number', 'required': true, 'visible': true, 'builtin': true, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false},
    {'id': 'email', 'label': 'Email Address', 'type': 'Text', 'required': false, 'visible': true, 'builtin': true, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false},
    {'id': 'govId', 'label': 'Aadhaar / Govt ID', 'type': 'Text', 'required': false, 'visible': true, 'builtin': true, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false},
    {'id': 'gender', 'label': 'Gender', 'type': 'Dropdown', 'required': false, 'visible': true, 'builtin': true, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false},
    {'id': 'address', 'label': 'Residential Address', 'type': 'Text', 'required': false, 'visible': true, 'builtin': true, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false},
    {'id': 'prep', 'label': 'Exam / Target Course', 'type': 'Text', 'required': false, 'visible': true, 'builtin': false, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false},
  ];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
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
          .doc('form_config')
          .get();

      if (doc.exists && mounted) {
        final data = doc.data();
        if (data != null && data['fields'] is List) {
          final loaded = (data['fields'] as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          setState(() {
            _fields = loaded;
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('form_config')
          .set({
        'fields': _fields,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration form layout saved!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save layout: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAddEditFieldDialog({int? index}) {
    final isEditing = index != null;
    final current = isEditing ? _fields[index] : null;
    final isBuiltin = current?['builtin'] == true;

    final labelController = TextEditingController(text: current?['label'] ?? '');
    String fieldType = current?['type'] ?? 'Text';
    bool isRequired = current?['required'] ?? false;
    bool isVisible = current?['visible'] ?? true;
    bool showOnProfile = current?['showOnProfile'] ?? true;
    bool showOnIdCard = current?['showOnIdCard'] ?? false;
    bool showOnReceipt = current?['showOnReceipt'] ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Field' : 'Add Custom Field'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(
                    labelText: 'Field Label (e.g. College Name, Target Exam)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: fieldType,
                  decoration: const InputDecoration(
                    labelText: 'Field Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Text', child: Text('Text Input')),
                    DropdownMenuItem(value: 'Number', child: Text('Numeric Number')),
                    DropdownMenuItem(value: 'Dropdown', child: Text('Dropdown Selection')),
                    DropdownMenuItem(value: 'Date', child: Text('Date Picker')),
                  ],
                  onChanged: isBuiltin ? null : (val) => setDialogState(() => fieldType = val!),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Mandatory (Required)'),
                  value: isRequired,
                  onChanged: (val) => setDialogState(() => isRequired = val ?? false),
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('Visible on Registration'),
                  value: isVisible,
                  onChanged: (val) => setDialogState(() => isVisible = val ?? true),
                  contentPadding: EdgeInsets.zero,
                ),
                if (!isBuiltin) ...[
                  CheckboxListTile(
                    title: const Text('Show on Student Profile'),
                    value: showOnProfile,
                    onChanged: (v) => setDialogState(() => showOnProfile = v ?? true),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: const Text('Show on ID Card'),
                    value: showOnIdCard,
                    onChanged: (v) => setDialogState(() => showOnIdCard = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: const Text('Show on Receipt'),
                    value: showOnReceipt,
                    onChanged: (v) => setDialogState(() => showOnReceipt = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (isEditing && !isBuiltin)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _fields.removeAt(index));
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
                final label = labelController.text.trim();
                if (label.isEmpty) return;

                final item = {
                  'id': isEditing ? current!['id'] : 'custom_${DateTime.now().millisecondsSinceEpoch}',
                  'label': label,
                  'type': fieldType,
                  'required': isRequired,
                  'visible': isVisible,
                  'builtin': isBuiltin,
                  'showOnProfile': showOnProfile,
                  'showOnIdCard': showOnIdCard,
                  'showOnReceipt': showOnReceipt,
                };

                setState(() {
                  if (isEditing) {
                    _fields[index] = item;
                  } else {
                    _fields.add(item);
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

  void _showFormPreview() {
    final visibleFields = _fields.where((f) => f['visible'] == true).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Student Registration Preview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Text('This is how the form appears to students during onboarding/registration:'),
              const Divider(height: 24),
              ...visibleFields.map((field) {
                final isReq = field['required'] == true;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: TextFormField(
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: '${field['label']} ${isReq ? '*' : '(Optional)'}',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: Icon(
                        field['type'] == 'Number'
                            ? Icons.phone_rounded
                            : field['type'] == 'Dropdown'
                                ? Icons.arrow_drop_down_circle_rounded
                                : field['type'] == 'Date'
                                    ? Icons.calendar_today_rounded
                                    : Icons.edit_note_rounded,
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Looks Good'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Form Fields'),
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility_outlined),
            tooltip: 'Preview Form',
            onPressed: _showFormPreview,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonal(
              onPressed: _isSaving ? null : _saveConfig,
              child: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ReorderableListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _fields.removeAt(oldIndex);
                  _fields.insert(newIndex, item);
                });
              },
              children: _fields.asMap().map((index, field) {
                final isVisible = field['visible'] == true;
                final isBuiltin = field['builtin'] == true;
                final isRequired = field['required'] == true;

                return MapEntry(
                  index,
                  Card(
                    key: ValueKey(field['id']),
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isVisible
                            ? theme.colorScheme.primary.withValues(alpha: 0.3)
                            : theme.colorScheme.outlineVariant,
                        width: 1.2,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _showAddEditFieldDialog(index: index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: isVisible
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                field['type'] == 'Number'
                                    ? Icons.numbers_rounded
                                    : field['type'] == 'Dropdown'
                                        ? Icons.list_rounded
                                        : field['type'] == 'Date'
                                            ? Icons.event_rounded
                                            : Icons.text_fields_rounded,
                                color: isVisible
                                    ? theme.colorScheme.primary
                                    : Colors.grey,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          field['label'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: isVisible
                                                ? theme.colorScheme.onSurface
                                                : Colors.grey,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isRequired) ...[
                                        const SizedBox(width: 4),
                                        const Text('*',
                                            style: TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16)),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Text(
                                        '${field['type']} • ${isRequired ? "Required" : "Optional"}${!isVisible ? " • Hidden" : ""}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: isVisible
                                                ? Colors.grey.shade700
                                                : Colors.grey),
                                      ),
                                      if (isBuiltin) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text('Standard',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.black54,
                                                  fontWeight: FontWeight.w600)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Transform.scale(
                              scale: 0.85,
                              child: Switch(
                                value: isVisible,
                                onChanged: (v) =>
                                    setState(() => field['visible'] = v),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Edit field',
                              onPressed: () =>
                                  _showAddEditFieldDialog(index: index),
                            ),
                            const Icon(Icons.drag_handle_rounded,
                                color: Colors.grey, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).values.toList(),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditFieldDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Custom Field'),
      ),
    );
  }
}
