import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/services/form_config_service.dart';

class FormCustomizerScreen extends ConsumerStatefulWidget {
  const FormCustomizerScreen({super.key});

  @override
  ConsumerState<FormCustomizerScreen> createState() => _FormCustomizerScreenState();
}

class _FormCustomizerScreenState extends ConsumerState<FormCustomizerScreen> {
  List<Map<String, dynamic>> _fields = List.from(
    FormConfigService.defaultBuiltinFields.map((f) => Map<String, dynamic>.from(f)),
  );

  bool _isLoading = true;
  bool _isSaving = false;

  static IconData _getCategoryIcon(String category) {
    switch (category) {
      case FormFieldCategory.personal:
        return Icons.person_outline_rounded;
      case FormFieldCategory.contact:
        return Icons.contact_phone_outlined;
      case FormFieldCategory.govId:
        return Icons.badge_outlined;
      case FormFieldCategory.academics:
        return Icons.school_outlined;
      case FormFieldCategory.custom:
      default:
        return Icons.tune_rounded;
    }
  }

  static Color _getCategoryColor(String category) {
    switch (category) {
      case FormFieldCategory.personal:
        return Colors.teal;
      case FormFieldCategory.contact:
        return Colors.blue;
      case FormFieldCategory.govId:
        return Colors.brown;
      case FormFieldCategory.academics:
        return Colors.purple;
      case FormFieldCategory.custom:
      default:
        return Colors.orange.shade800;
    }
  }

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
        final rawList = data != null ? data['fields'] as List<dynamic>? : null;
        setState(() {
          _fields = FormConfigService.normalizeConfig(rawList);
        });
      } else {
        setState(() {
          _fields = List<Map<String, dynamic>>.from(
            FormConfigService.defaultBuiltinFields.map((f) => Map<String, dynamic>.from(f)),
          );
        });
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

  void _moveFieldInCategory(int fieldIndex, bool moveUp) {
    if (fieldIndex < 0 || fieldIndex >= _fields.length) return;
    final category = _fields[fieldIndex]['category']?.toString() ?? FormFieldCategory.custom;

    // Find all indices belonging to this category in order
    final catIndices = <int>[];
    for (int i = 0; i < _fields.length; i++) {
      final c = _fields[i]['category']?.toString() ?? FormFieldCategory.custom;
      if (c == category) {
        catIndices.add(i);
      }
    }

    final pos = catIndices.indexOf(fieldIndex);
    if (pos == -1) return;

    if (moveUp && pos > 0) {
      final targetIdx = catIndices[pos - 1];
      final temp = _fields[fieldIndex];
      _fields[fieldIndex] = _fields[targetIdx];
      _fields[targetIdx] = temp;
      setState(() {});
    } else if (!moveUp && pos < catIndices.length - 1) {
      final targetIdx = catIndices[pos + 1];
      final temp = _fields[fieldIndex];
      _fields[fieldIndex] = _fields[targetIdx];
      _fields[targetIdx] = temp;
      setState(() {});
    }
  }

  void _showAddEditFieldDialog({int? index}) {
    final isEditing = index != null;
    final current = isEditing ? _fields[index] : null;
    final isBuiltin = current?['builtin'] == true;
    String selectedCategory = (current?['category'] as String?) ?? FormFieldCategory.custom;

    final labelController = TextEditingController(text: current?['label'] ?? '');
    final optionsController = TextEditingController(
      text: (current?['options'] as List?)?.join(', ') ?? '',
    );
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
                if (fieldType == 'Dropdown') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: optionsController,
                    decoration: const InputDecoration(
                      labelText: 'Dropdown Options (comma-separated)',
                      hintText: 'e.g. Morning, Evening, Full Day',
                      helperText: 'Separate multiple options with commas',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.list_alt_rounded),
                    ),
                  ),
                ],
                if (!isBuiltin) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Section Category',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: FormFieldCategory.personal, child: Text('Personal Details')),
                      DropdownMenuItem(value: FormFieldCategory.contact, child: Text('Contact & Residence')),
                      DropdownMenuItem(value: FormFieldCategory.academics, child: Text('Academic & Goals')),
                      DropdownMenuItem(value: FormFieldCategory.custom, child: Text('Custom & Additional')),
                    ],
                    onChanged: (v) => setDialogState(() => selectedCategory = v ?? FormFieldCategory.custom),
                  ),
                ],
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Mandatory (Required)'),
                  value: (current?['id'] == 'name' || current?['id'] == 'phone') ? true : isRequired,
                  onChanged: (current?['id'] == 'name' || current?['id'] == 'phone')
                      ? null
                      : (val) => setDialogState(() => isRequired = val ?? false),
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('Visible on Registration'),
                  value: (current?['id'] == 'name' || current?['id'] == 'phone') ? true : isVisible,
                  onChanged: (current?['id'] == 'name' || current?['id'] == 'phone')
                      ? null
                      : (val) => setDialogState(() => isVisible = val ?? true),
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

                List<String> options = [];
                if (fieldType == 'Dropdown') {
                  options = optionsController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                } else if (current?['options'] is List) {
                  options = List<String>.from(current!['options']);
                }

                final item = {
                  'id': isEditing ? current!['id'] : 'custom_${DateTime.now().millisecondsSinceEpoch}',
                  'label': label,
                  'type': fieldType,
                  'required': isRequired,
                  'visible': isVisible,
                  'builtin': isBuiltin,
                  'category': isBuiltin ? (current?['category'] ?? FormFieldCategory.custom) : selectedCategory,
                  'showOnProfile': showOnProfile,
                  'showOnIdCard': showOnIdCard,
                  'showOnReceipt': showOnReceipt,
                  if (options.isNotEmpty) 'options': options,
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
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              children: [
                for (final categoryKey in FormFieldCategory.orderedCategories) ...[
                  Builder(builder: (context) {
                    final catFields = _fields
                        .asMap()
                        .entries
                        .where((e) {
                          final f = e.value;
                          final cat = f['category']?.toString() ?? FormFieldCategory.custom;
                          return cat == categoryKey;
                        })
                        .toList();

                    if (catFields.isEmpty && categoryKey == FormFieldCategory.custom) {
                      return const SizedBox.shrink();
                    }

                    final activeCount = catFields.where((e) => e.value['visible'] == true).length;
                    final totalCount = catFields.length;
                    final catTitle = FormFieldCategory.getCategoryTitle(categoryKey);
                    final catSubtitle = FormFieldCategory.getCategorySubtitle(categoryKey);
                    final catIcon = _getCategoryIcon(categoryKey);
                    final catColor = _getCategoryColor(categoryKey);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 14, bottom: 8, left: 4, right: 4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: catColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(catIcon, size: 16, color: catColor),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      catTitle,
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    Text(
                                      catSubtitle,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: activeCount > 0
                                      ? Colors.green.withValues(alpha: 0.12)
                                      : Colors.grey.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: activeCount > 0
                                        ? Colors.green.withValues(alpha: 0.3)
                                        : Colors.grey.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  '$activeCount/$totalCount active',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: activeCount > 0 ? Colors.green.shade700 : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (int i = 0; i < catFields.length; i++)
                          _buildFieldCard(
                            context,
                            catFields[i].key,
                            catFields[i].value,
                            theme,
                            isFirstInCategory: i == 0,
                            isLastInCategory: i == catFields.length - 1,
                          ),
                        const SizedBox(height: 6),
                      ],
                    );
                  }),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditFieldDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Custom Field'),
      ),
    );
  }

  Widget _buildFieldCard(BuildContext context, int index, Map<String, dynamic> field, ThemeData theme) {
    final isVisible = field['visible'] == true;
    final isBuiltin = field['builtin'] == true;
    final isRequired = field['required'] == true;

    return Card(
      key: ValueKey(field['id']),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isVisible
              ? theme.colorScheme.primary.withValues(alpha: 0.25)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showAddEditFieldDialog(index: index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 18,
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
                  size: 18,
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
                              fontSize: 14,
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
                          const Text(
                            '*',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${field['type']} • ${isRequired ? "Required" : "Optional"}${!isVisible ? " • Hidden" : ""}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isVisible
                                ? Colors.grey.shade700
                                : Colors.grey,
                          ),
                        ),
                        if (isBuiltin) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Standard',
                              style: TextStyle(fontSize: 9.5, color: Colors.black54, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Transform.scale(
                scale: 0.82,
                child: Switch(
                  value: (field['id'] == 'name' || field['id'] == 'phone') ? true : isVisible,
                  onChanged: (field['id'] == 'name' || field['id'] == 'phone')
                      ? null
                      : (v) => setState(() => field['visible'] = v),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                visualDensity: VisualDensity.compact,
                tooltip: 'Edit field',
                onPressed: () => _showAddEditFieldDialog(index: index),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
