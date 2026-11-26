import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:study_library/services/form_config_service.dart';

/// Shared dynamic form input renderer supporting all schema field types
/// (Text, LongText, Number, Phone, Email, Dropdown, MultiSelect, Date, Toggle)
/// with consistent validation, regex patterns, hints, and read-only lock support.
class DynamicFormFieldRenderer extends StatelessWidget {
  final Map<String, dynamic> field;
  final TextEditingController controller;
  final bool forceReadOnly;
  final VoidCallback? onChanged;
  final double bottomPadding;

  const DynamicFormFieldRenderer({
    super.key,
    required this.field,
    required this.controller,
    this.forceReadOnly = false,
    this.onChanged,
    this.bottomPadding = 14.0,
  });

  static List<String> _parseOptions(Map<String, dynamic> f) {
    final raw = f['options'];
    if (raw is! List) return const [];
    return raw.map((e) => e?.toString().trim() ?? '').where((e) => e.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final id = (field['id'] ?? '').toString();
    final label = (field['label'] ?? id).toString().trim();
    final fType = (field['type'] ?? 'Text').toString();
    final isRequired = field['required'] == true;
    final hintText = field['hintText']?.toString().trim();
    final isLocked = forceReadOnly;
    final effectiveLabel = '$label${isRequired ? ' *' : ''}${isLocked ? ' (Locked)' : ''}';
    final options = _parseOptions(field);

    Widget inputWidget;

    if (fType == 'Toggle') {
      final isChecked = controller.text.trim().toLowerCase() == 'yes' ||
          controller.text.trim().toLowerCase() == 'true';
      inputWidget = FormField<String>(
        initialValue: controller.text,
        validator: isRequired
            ? (v) {
                final cur = controller.text.trim().toLowerCase();
                if (cur != 'yes' && cur != 'true') {
                  return '$label must be enabled / accepted';
                }
                return null;
              }
            : null,
        builder: (formState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: formState.hasError
                        ? theme.colorScheme.error
                        : theme.colorScheme.outline.withValues(alpha: 0.6),
                  ),
                  color: isLocked
                      ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
                      : null,
                ),
                child: SwitchListTile(
                  title: Text(
                    effectiveLabel,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  subtitle: (hintText != null && hintText.isNotEmpty)
                      ? Text(hintText, style: const TextStyle(fontSize: 12))
                      : null,
                  value: isChecked,
                  onChanged: isLocked
                      ? null
                      : (val) {
                          controller.text = val ? 'Yes' : 'No';
                          formState.didChange(controller.text);
                          onChanged?.call();
                        },
                ),
              ),
              if (formState.hasError)
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 6),
                  child: Text(
                    formState.errorText!,
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                  ),
                ),
            ],
          );
        },
      );
    } else if (fType == 'MultiSelect' && options.isNotEmpty) {
      final selectedSet = controller.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty && options.contains(e))
          .toSet();
      inputWidget = FormField<String>(
        initialValue: controller.text,
        validator: (_) => FormConfigService.validateFieldValue(controller.text, field),
        builder: (formState) {
          return InputDecorator(
            decoration: InputDecoration(
              labelText: effectiveLabel,
              hintText: hintText,
              errorText: formState.errorText,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.checklist_rounded, size: 20),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: options.map((opt) {
                final isSelected = selectedSet.contains(opt);
                return FilterChip(
                  label: Text(opt, style: const TextStyle(fontSize: 12.5)),
                  selected: isSelected,
                  onSelected: isLocked
                      ? null
                      : (sel) {
                          if (sel) {
                            selectedSet.add(opt);
                          } else {
                            selectedSet.remove(opt);
                          }
                          controller.text = options.where(selectedSet.contains).join(', ');
                          formState.didChange(controller.text);
                          onChanged?.call();
                        },
                );
              }).toList(),
            ),
          );
        },
      );
    } else if (fType == 'Dropdown' && options.isNotEmpty) {
      final currentVal = controller.text.trim();
      final matchedVal = options.contains(currentVal) ? currentVal : null;
      inputWidget = DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: matchedVal,
        items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
        onChanged: isLocked
            ? null
            : (val) {
                controller.text = val ?? '';
                onChanged?.call();
              },
        decoration: InputDecoration(
          labelText: effectiveLabel,
          hintText: hintText,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.arrow_drop_down_circle_outlined, size: 20),
        ),
        validator: isRequired
            ? (val) => (val == null || val.trim().isEmpty) ? '$label is required' : null
            : null,
      );
    } else if (fType == 'Date') {
      inputWidget = InkWell(
        onTap: isLocked
            ? null
            : () async {
                DateTime? initialDate;
                try {
                  if (controller.text.trim().isNotEmpty) {
                    initialDate = DateFormat('dd/MM/yyyy').parse(controller.text.trim());
                  }
                } catch (_) {}
                final picked = await showDatePicker(
                  context: context,
                  initialDate: initialDate ?? DateTime.now(),
                  firstDate: DateTime(1940),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                  helpText: label,
                );
                if (picked != null) {
                  controller.text = DateFormat('dd/MM/yyyy').format(picked);
                  onChanged?.call();
                }
              },
        child: AbsorbPointer(
          child: TextFormField(
            controller: controller,
            readOnly: true,
            decoration: InputDecoration(
              labelText: effectiveLabel,
              hintText: (hintText != null && hintText.isNotEmpty) ? hintText : 'DD/MM/YYYY',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.calendar_today_rounded, size: 20),
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            validator: (_) => FormConfigService.validateFieldValue(controller.text, field),
          ),
        ),
      );
    } else if (fType == 'Number' || fType == 'Phone') {
      final isPhone = fType == 'Phone';
      inputWidget = TextFormField(
        controller: controller,
        readOnly: isLocked,
        keyboardType: isPhone ? TextInputType.phone : TextInputType.number,
        inputFormatters: isPhone
            ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)]
            : [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: effectiveLabel,
          hintText: hintText,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(
            isPhone ? Icons.phone_outlined : Icons.numbers_rounded,
            size: 20,
          ),
        ),
        onChanged: (_) => onChanged?.call(),
        validator: (val) => FormConfigService.validateFieldValue(val, field),
      );
    } else if (fType == 'Email') {
      inputWidget = TextFormField(
        controller: controller,
        readOnly: isLocked,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(
          labelText: effectiveLabel,
          hintText: hintText,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.email_outlined, size: 20),
        ),
        onChanged: (_) => onChanged?.call(),
        validator: (val) => FormConfigService.validateFieldValue(val, field),
      );
    } else {
      final isLong = fType == 'LongText';
      inputWidget = TextFormField(
        controller: controller,
        readOnly: isLocked,
        maxLines: isLong ? 3 : 1,
        decoration: InputDecoration(
          labelText: effectiveLabel,
          hintText: hintText,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(
            isLong ? Icons.notes_rounded : Icons.edit_note_rounded,
            size: 20,
          ),
        ),
        onChanged: (_) => onChanged?.call(),
        validator: (val) => FormConfigService.validateFieldValue(val, field),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: inputWidget,
    );
  }
}

/// Ensures controllers exist in [controllerMap] for all non-builtin custom fields in [fields].
void syncCustomFieldControllers(
  List<Map<String, dynamic>> fields,
  Map<String, TextEditingController> controllerMap, {
  Map<String, dynamic>? initialValues,
}) {
  for (final f in fields) {
    final id = (f['id'] ?? '').toString().trim();
    final isBuiltin = f['builtin'] as bool? ?? false;
    if (!isBuiltin && id.isNotEmpty && !controllerMap.containsKey(id)) {
      final initText = initialValues?[id]?.toString() ?? '';
      controllerMap[id] = TextEditingController(text: initText);
    }
  }
}

/// Renders visible non-builtin custom fields belonging to [category].
class DynamicCategoryCustomFieldsSection extends StatelessWidget {
  final List<Map<String, dynamic>> fields;
  final String category;
  final Map<String, TextEditingController> controllers;
  final bool profileOnly;
  final bool enforceStudentReadOnly;
  final VoidCallback? onChanged;
  final Widget? header;

  const DynamicCategoryCustomFieldsSection({
    super.key,
    required this.fields,
    required this.category,
    required this.controllers,
    this.profileOnly = false,
    this.enforceStudentReadOnly = false,
    this.onChanged,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    final categoryFields = FormConfigService.getCustomFieldsForCategory(
      fields,
      category,
      profileOnly: profileOnly,
    );
    if (categoryFields.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ?header,
        for (final f in categoryFields)
          Builder(
            builder: (_) {
              final fid = (f['id'] ?? '').toString();
              if (fid.isEmpty) return const SizedBox.shrink();
              final ctrl = controllers[fid] ??= TextEditingController();
              return DynamicFormFieldRenderer(
                field: f,
                controller: ctrl,
                forceReadOnly: enforceStudentReadOnly && (f['readOnlyForStudent'] == true),
                onChanged: onChanged,
              );
            },
          ),
      ],
    );
  }
}
