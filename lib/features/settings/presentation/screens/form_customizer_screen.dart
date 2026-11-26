import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/widgets/dynamic_form_field_renderer.dart';
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
    final fieldId = (current?['id'] ?? '').toString();
    final isCoreLocked = fieldId == 'name' || fieldId == 'phone';
    String selectedCategory = (current?['category'] as String?) ?? FormFieldCategory.custom;

    final labelController = TextEditingController(text: current?['label'] ?? '');
    final hintController = TextEditingController(text: current?['hintText'] ?? '');
    final optionsController = TextEditingController(
      text: (current?['options'] as List?)?.join(', ') ?? '',
    );
    final patternController = TextEditingController(text: current?['pattern'] ?? '');
    final patternErrorController = TextEditingController(text: current?['patternError'] ?? '');

    String fieldType = (current?['type']?.toString().isNotEmpty == true)
        ? current!['type'].toString()
        : 'Text';
    if (!FormConfigService.supportedFieldTypes.contains(fieldType)) {
      fieldType = 'Text';
    }
    String selectedPresetId = 'none';
    for (final preset in FormConfigService.regexPresets) {
      if (preset.pattern.isNotEmpty && preset.pattern == patternController.text.trim()) {
        selectedPresetId = preset.id;
        break;
      }
    }

    bool isRequired = isCoreLocked ? true : (current?['required'] ?? false);
    bool isVisible = isCoreLocked ? true : (current?['visible'] ?? true);
    bool showOnProfile = current?['showOnProfile'] ?? true;
    bool showOnIdCard = current?['showOnIdCard'] ?? false;
    bool showOnReceipt = current?['showOnReceipt'] ?? false;
    bool showOnExport = current?['showOnExport'] ?? true;
    bool readOnlyForStudent = current?['readOnlyForStudent'] ?? false;
    String? inlineError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? (isBuiltin ? 'Customize Standard Field' : 'Edit Custom Field') : 'Add Custom Field'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (inlineError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              inlineError!,
                              style: TextStyle(color: Colors.red.shade800, fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  TextField(
                    controller: labelController,
                    decoration: const InputDecoration(
                      labelText: 'Field Label *',
                      hintText: 'e.g. Library Locker No, Exam Batch',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: hintController,
                    decoration: const InputDecoration(
                      labelText: 'Placeholder / Hint Text (Optional)',
                      hintText: 'e.g. Enter 6-digit hall ticket number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: fieldType,
                    decoration: const InputDecoration(
                      labelText: 'Field Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Text', child: Text('Short Text')),
                      DropdownMenuItem(value: 'LongText', child: Text('Long Text (Multi-line)')),
                      DropdownMenuItem(value: 'Number', child: Text('Numeric Number')),
                      DropdownMenuItem(value: 'Phone', child: Text('Phone Number (10-digit)')),
                      DropdownMenuItem(value: 'Email', child: Text('Email Address')),
                      DropdownMenuItem(value: 'Dropdown', child: Text('Dropdown Selection')),
                      DropdownMenuItem(value: 'MultiSelect', child: Text('Multi-Select Tags')),
                      DropdownMenuItem(value: 'Date', child: Text('Date Picker')),
                      DropdownMenuItem(value: 'Toggle', child: Text('Yes / No Toggle Switch')),
                    ],
                    onChanged: isBuiltin ? null : (val) => setDialogState(() => fieldType = val ?? 'Text'),
                  ),
                  if (fieldType == 'Dropdown' || fieldType == 'MultiSelect') ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: optionsController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Options (comma-separated) *',
                        hintText: 'e.g. UPSC, MPSC, NEET, JEE, Banking',
                        helperText: 'Separate each option with a comma',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.list_alt_rounded),
                      ),
                    ),
                  ],
                  if (!isBuiltin) ...[
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: FormFieldCategory.orderedCategories.contains(selectedCategory)
                          ? selectedCategory
                          : FormFieldCategory.custom,
                      decoration: const InputDecoration(
                        labelText: 'Form Section Category',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: FormFieldCategory.personal, child: Text('Personal Details')),
                        DropdownMenuItem(value: FormFieldCategory.contact, child: Text('Contact & Residence')),
                        DropdownMenuItem(value: FormFieldCategory.govId, child: Text('Government ID & KYC')),
                        DropdownMenuItem(value: FormFieldCategory.academics, child: Text('Academic & Competitive Goals')),
                        DropdownMenuItem(value: FormFieldCategory.custom, child: Text('Custom & Additional Fields')),
                      ],
                      onChanged: (v) => setDialogState(() => selectedCategory = v ?? FormFieldCategory.custom),
                    ),
                    if (fieldType == 'Text' || fieldType == 'LongText' || fieldType == 'Number') ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedPresetId,
                        decoration: const InputDecoration(
                          labelText: 'Validation Format Preset',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.verified_outlined),
                        ),
                        items: [
                          ...FormConfigService.regexPresets.map(
                            (p) => DropdownMenuItem(value: p.id, child: Text(p.label)),
                          ),
                          const DropdownMenuItem(value: 'custom', child: Text('Custom Regex Pattern')),
                        ],
                        onChanged: (v) {
                          setDialogState(() {
                            selectedPresetId = v ?? 'none';
                            if (selectedPresetId != 'custom') {
                              final preset = FormConfigService.regexPresets.firstWhere(
                                (p) => p.id == selectedPresetId,
                                orElse: () => FormConfigService.regexPresets.first,
                              );
                              patternController.text = preset.pattern;
                              patternErrorController.text = preset.errorMessage;
                              if (hintController.text.trim().isEmpty && preset.hint.isNotEmpty) {
                                hintController.text = preset.hint;
                              }
                            }
                          });
                        },
                      ),
                      if (selectedPresetId == 'custom' || patternController.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: patternController,
                          decoration: const InputDecoration(
                            labelText: 'Regex Pattern',
                            hintText: r'e.g. ^[A-Z]{2}\d{4}$',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: patternErrorController,
                          decoration: const InputDecoration(
                            labelText: 'Validation Error Message',
                            hintText: 'e.g. Must match format AB1234',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ],
                  ],
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 4),
                  Text(
                    'FIELD RULES & SURFACE VISIBILITY',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  CheckboxListTile(
                    title: const Text('Mandatory (Required)'),
                    value: isCoreLocked ? true : isRequired,
                    onChanged: isCoreLocked ? null : (val) => setDialogState(() => isRequired = val ?? false),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: const Text('Visible on Admission & Registration Forms'),
                    value: isCoreLocked ? true : isVisible,
                    onChanged: isCoreLocked ? null : (val) => setDialogState(() => isVisible = val ?? true),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: const Text('Show on Student Profile & Admin Dossier'),
                    value: showOnProfile,
                    onChanged: isCoreLocked ? null : (v) => setDialogState(() => showOnProfile = v ?? true),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: const Text('Lock from Student Self-Edit (Read-Only)'),
                    subtitle: const Text('Admin can still edit; students view only', style: TextStyle(fontSize: 11)),
                    value: readOnlyForStudent,
                    onChanged: isCoreLocked ? null : (v) => setDialogState(() => readOnlyForStudent = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: const Text('Show on Digital & Printed ID Card'),
                    value: showOnIdCard,
                    onChanged: (v) => setDialogState(() => showOnIdCard = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: const Text('Show on Payment Receipt'),
                    value: showOnReceipt,
                    onChanged: (v) => setDialogState(() => showOnReceipt = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: const Text('Include in CSV / Excel Exports'),
                    value: showOnExport,
                    onChanged: (v) => setDialogState(() => showOnExport = v ?? true),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ],
              ),
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
                if (label.isEmpty) {
                  setDialogState(() => inlineError = 'Please enter a field label.');
                  return;
                }

                List<String> options = [];
                if (fieldType == 'Dropdown' || fieldType == 'MultiSelect') {
                  options = optionsController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                  if (!isBuiltin && options.isEmpty) {
                    setDialogState(() => inlineError = 'Please add at least one option separated by commas.');
                    return;
                  }
                } else if (current?['options'] is List) {
                  options = List<String>.from(current!['options']);
                }

                final rawPattern = patternController.text.trim();
                if (rawPattern.isNotEmpty) {
                  try {
                    RegExp(rawPattern);
                  } catch (_) {
                    setDialogState(() => inlineError = 'Invalid regex pattern syntax. Please double check.');
                    return;
                  }
                }

                final item = {
                  'id': isEditing ? current!['id'] : 'custom_${DateTime.now().millisecondsSinceEpoch}',
                  'label': label,
                  'type': fieldType,
                  'required': isCoreLocked ? true : isRequired,
                  'visible': isCoreLocked ? true : isVisible,
                  'builtin': isBuiltin,
                  'category': isBuiltin ? (current?['category'] ?? FormFieldCategory.custom) : selectedCategory,
                  'showOnProfile': showOnProfile,
                  'showOnIdCard': showOnIdCard,
                  'showOnReceipt': showOnReceipt,
                  'showOnExport': showOnExport,
                  'readOnlyForStudent': readOnlyForStudent,
                  if (hintController.text.trim().isNotEmpty) 'hintText': hintController.text.trim(),
                  if (rawPattern.isNotEmpty) 'pattern': rawPattern,
                  if (patternErrorController.text.trim().isNotEmpty) 'patternError': patternErrorController.text.trim(),
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
    final previewCtrls = <String, TextEditingController>{};
    for (final f in _fields) {
      final fid = (f['id'] ?? '').toString();
      if (fid.isNotEmpty) {
        previewCtrls[fid] = TextEditingController();
      }
    }
    int surfaceIndex = 0; // 0 = Registration, 1 = Student Profile, 2 = ID Card & Receipt

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setPreviewState) {
          final visibleFields = _fields.where((f) {
            if (f['visible'] != true) return false;
            if (surfaceIndex == 1) return f['showOnProfile'] != false;
            if (surfaceIndex == 2) return f['showOnIdCard'] == true || f['showOnReceipt'] == true;
            return true;
          }).toList();

          final grouped = FormConfigService.groupFieldsByCategory(visibleFields);

          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Live Form Preview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Registration')),
                      ButtonSegment(value: 1, label: Text('Profile')),
                      ButtonSegment(value: 2, label: Text('ID & Receipt')),
                    ],
                    selected: {surfaceIndex},
                    onSelectionChanged: (sel) => setPreviewState(() => surfaceIndex = sel.first),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 16),
                  if (visibleFields.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No fields currently enabled for this view.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    for (final catKey in FormFieldCategory.orderedCategories)
                      if ((grouped[catKey] ?? []).isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 10),
                          child: Text(
                            FormFieldCategory.getCategoryTitle(catKey).toUpperCase(),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        ...grouped[catKey]!.map((field) {
                          final fid = (field['id'] ?? '').toString();
                          final ctrl = previewCtrls[fid] ??= TextEditingController();
                          final previewField = Map<String, dynamic>.from(field);
                          if (fid == 'gender' && (previewField['options'] is! List || (previewField['options'] as List).isEmpty)) {
                            previewField['options'] = const ['Male', 'Female', 'Other'];
                          }
                          if (fid == 'bloodGroup' && (previewField['options'] is! List || (previewField['options'] as List).isEmpty)) {
                            previewField['options'] = const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
                          }
                          return DynamicFormFieldRenderer(
                            field: previewField,
                            controller: ctrl,
                            forceReadOnly: surfaceIndex == 1 && (field['readOnlyForStudent'] == true),
                            onChanged: () => setPreviewState(() {}),
                          );
                        }),
                      ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Looks Good'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      for (final c in previewCtrls.values) {
        c.dispose();
      }
    });
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
            tooltip: 'Interactive Live Preview',
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
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

  Widget _buildSurfaceChip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4, top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.28), width: 0.6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _buildFieldCard(
    BuildContext context,
    int index,
    Map<String, dynamic> field,
    ThemeData theme, {
    bool isFirstInCategory = false,
    bool isLastInCategory = false,
  }) {
    final isVisible = field['visible'] == true;
    final isBuiltin = field['builtin'] == true;
    final isRequired = field['required'] == true;
    final options = (field['options'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final fType = (field['type'] ?? 'Text').toString();

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
                  fType == 'Number' || fType == 'Phone'
                      ? Icons.numbers_rounded
                      : (fType == 'Dropdown' || fType == 'MultiSelect')
                          ? Icons.list_rounded
                          : fType == 'Date'
                              ? Icons.event_rounded
                              : fType == 'Toggle'
                                  ? Icons.toggle_on_rounded
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
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '$fType • ${isRequired ? "Required" : "Optional"}${!isVisible ? " • Hidden" : ""}${options.isNotEmpty ? " • ${options.length} opts" : ""}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isVisible ? Colors.grey.shade700 : Colors.grey,
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
                    Wrap(
                      children: [
                        if (field['showOnProfile'] != false) _buildSurfaceChip('Profile', Colors.teal),
                        if (field['showOnIdCard'] == true) _buildSurfaceChip('ID Card', Colors.indigo),
                        if (field['showOnReceipt'] == true) _buildSurfaceChip('Receipt', Colors.purple),
                        if (field['readOnlyForStudent'] == true) _buildSurfaceChip('Locked', Colors.amber.shade800),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: isFirstInCategory ? null : () => _moveFieldInCategory(index, true),
                    borderRadius: BorderRadius.circular(4),
                    child: Icon(
                      Icons.arrow_drop_up_rounded,
                      size: 20,
                      color: isFirstInCategory ? Colors.grey.shade300 : theme.colorScheme.primary,
                    ),
                  ),
                  InkWell(
                    onTap: isLastInCategory ? null : () => _moveFieldInCategory(index, false),
                    borderRadius: BorderRadius.circular(4),
                    child: Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 20,
                      color: isLastInCategory ? Colors.grey.shade300 : theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
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
