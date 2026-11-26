import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/utils/app_validators.dart';
import 'package:study_library/models/student_model.dart';

class FormFieldCategory {
  static const String personal = 'personal';
  static const String contact = 'contact';
  static const String govId = 'govId';
  static const String academics = 'academics';
  static const String custom = 'custom';

  static const List<String> orderedCategories = [
    personal,
    contact,
    govId,
    academics,
    custom,
  ];

  static String getCategoryTitle(String category) {
    switch (category) {
      case personal:
        return 'Personal Details';
      case contact:
        return 'Contact & Residence';
      case govId:
        return 'Government ID & KYC';
      case academics:
        return 'Academic & Competitive Goals';
      case custom:
      default:
        return 'Custom & Additional Fields';
    }
  }

  static String getCategorySubtitle(String category) {
    switch (category) {
      case personal:
        return 'Name, guardian, gender, birth date & blood group';
      case contact:
        return 'Phone, email, emergency contact & address';
      case govId:
        return 'Identity proof type, number & photo verification';
      case academics:
        return 'Target exam, college name, degree, year & roll no.';
      case custom:
      default:
        return 'Library-specific custom questions and tags';
    }
  }
}

class FormRegexPreset {
  final String id;
  final String label;
  final String pattern;
  final String errorMessage;
  final String hint;

  const FormRegexPreset({
    required this.id,
    required this.label,
    required this.pattern,
    required this.errorMessage,
    required this.hint,
  });
}

class FormConfigService {
  static const List<String> supportedFieldTypes = [
    'Text',
    'LongText',
    'Number',
    'Phone',
    'Email',
    'Dropdown',
    'MultiSelect',
    'Date',
    'Toggle',
  ];

  static const List<FormRegexPreset> regexPresets = [
    FormRegexPreset(
      id: 'none',
      label: 'None (Any input)',
      pattern: '',
      errorMessage: '',
      hint: '',
    ),
    FormRegexPreset(
      id: 'indian_mobile',
      label: 'Indian Mobile (10 digits)',
      pattern: r'^[6-9]\d{9}$',
      errorMessage: 'Enter a valid 10-digit mobile number starting with 6-9',
      hint: 'e.g. 9823456789',
    ),
    FormRegexPreset(
      id: 'pincode',
      label: 'Postal PIN Code (6 digits)',
      pattern: r'^[1-9]\d{5}$',
      errorMessage: 'Enter a valid 6-digit PIN code',
      hint: 'e.g. 431515',
    ),
    FormRegexPreset(
      id: 'alphanumeric_id',
      label: 'Alphanumeric ID / Roll No',
      pattern: r'^[A-Za-z0-9\-/]{3,25}$',
      errorMessage: 'Use 3 to 25 letters, digits, hyphens, or slashes',
      hint: 'e.g. 2026-CS-042',
    ),
    FormRegexPreset(
      id: 'year_4d',
      label: 'Year (YYYY)',
      pattern: r'^(19|20)\d{2}$',
      errorMessage: 'Enter a valid 4-digit year (e.g. 2026)',
      hint: 'e.g. 2026',
    ),
    FormRegexPreset(
      id: 'email',
      label: 'Email Format',
      pattern: r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
      errorMessage: 'Enter a valid email address',
      hint: 'e.g. name@example.com',
    ),
  ];

  static const Set<String> _internalCustomFieldKeys = {
    'originalrequestid',
    'requestid',
    'admissionrequestid',
    'registrationid',
    'migratedfrom',
    'migrationid',
    'legacyid',
    'importbatchid',
    'source',
    'approvedat',
    'approvedby',
    'paymentid',
    'receiptid',
    'transactionid',
    'planname',
    'isrefund',
    'prep',
    'rollnumber',
  };

  static bool isInternalKey(String key) {
    final normalized = key.trim().toLowerCase();
    return normalized.isEmpty || _internalCustomFieldKeys.contains(normalized);
  }

  static String formatFieldKey(String key) {
    final spaced = key
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    return spaced
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static const List<Map<String, dynamic>> defaultBuiltinFields = [
    // ── 1. Personal Details ───────────────────────────────────────────────────
    {'id': 'name', 'label': 'Full Name', 'type': 'Text', 'required': true, 'visible': true, 'builtin': true, 'category': FormFieldCategory.personal, 'showOnProfile': true, 'showOnIdCard': true, 'showOnReceipt': true, 'showOnExport': true, 'readOnlyForStudent': true},
    {'id': 'fatherName', 'label': "Father's / Guardian's Name", 'type': 'Text', 'required': false, 'visible': true, 'builtin': true, 'category': FormFieldCategory.personal, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false, 'showOnExport': true, 'readOnlyForStudent': false},
    {'id': 'gender', 'label': 'Gender', 'type': 'Dropdown', 'required': true, 'visible': true, 'builtin': true, 'category': FormFieldCategory.personal, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false, 'showOnExport': true, 'readOnlyForStudent': true},
    {'id': 'dob', 'label': 'Date of Birth', 'type': 'Date', 'required': true, 'visible': true, 'builtin': true, 'category': FormFieldCategory.personal, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false, 'showOnExport': true, 'readOnlyForStudent': true},
    {'id': 'bloodGroup', 'label': 'Blood Group', 'type': 'Dropdown', 'required': false, 'visible': true, 'builtin': true, 'category': FormFieldCategory.personal, 'showOnProfile': true, 'showOnIdCard': true, 'showOnReceipt': false, 'showOnExport': true, 'readOnlyForStudent': false},

    // ── 2. Contact & Residence ────────────────────────────────────────────────
    {'id': 'phone', 'label': 'Phone Number', 'type': 'Phone', 'required': true, 'visible': true, 'builtin': true, 'category': FormFieldCategory.contact, 'showOnProfile': true, 'showOnIdCard': true, 'showOnReceipt': true, 'showOnExport': true, 'readOnlyForStudent': true},
    {'id': 'email', 'label': 'Email Address', 'type': 'Email', 'required': false, 'visible': true, 'builtin': true, 'category': FormFieldCategory.contact, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false, 'showOnExport': true, 'readOnlyForStudent': false},
    {'id': 'emergencyContact', 'label': 'Emergency Contact', 'type': 'Phone', 'required': false, 'visible': true, 'builtin': true, 'category': FormFieldCategory.contact, 'showOnProfile': true, 'showOnIdCard': true, 'showOnReceipt': false, 'showOnExport': true, 'readOnlyForStudent': false},
    {'id': 'address', 'label': 'Residential Address', 'type': 'LongText', 'required': true, 'visible': true, 'builtin': true, 'category': FormFieldCategory.contact, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false, 'showOnExport': true, 'readOnlyForStudent': false},
    {'id': 'pincode', 'label': 'Pincode', 'type': 'Number', 'required': true, 'visible': true, 'builtin': true, 'category': FormFieldCategory.contact, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false, 'showOnExport': true, 'readOnlyForStudent': false},

    // ── 3. Government ID & KYC ────────────────────────────────────────────────
    {'id': 'govId', 'label': 'Aadhaar / Govt ID', 'type': 'Text', 'required': true, 'visible': true, 'builtin': true, 'category': FormFieldCategory.govId, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false, 'showOnExport': true, 'readOnlyForStudent': true},

    // ── 4. Academic & Competitive Goals ───────────────────────────────────────
    {'id': 'prep', 'label': 'Exam / Target Course', 'type': 'Text', 'required': false, 'visible': true, 'builtin': true, 'category': FormFieldCategory.academics, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false, 'showOnExport': true, 'readOnlyForStudent': false},
    {'id': 'college', 'label': 'College / Institute Name', 'type': 'Text', 'required': false, 'visible': true, 'builtin': true, 'category': FormFieldCategory.academics, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false, 'showOnExport': true, 'readOnlyForStudent': false},
    {'id': 'course', 'label': 'Course / Degree', 'type': 'Text', 'required': false, 'visible': true, 'builtin': true, 'category': FormFieldCategory.academics, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false, 'showOnExport': true, 'readOnlyForStudent': false},
    {'id': 'year', 'label': 'Year / Sem', 'type': 'Text', 'required': false, 'visible': true, 'builtin': true, 'category': FormFieldCategory.academics, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false, 'showOnExport': true, 'readOnlyForStudent': false},
    {'id': 'rollNumber', 'label': 'Roll / Enroll Number', 'type': 'Text', 'required': false, 'visible': true, 'builtin': true, 'category': FormFieldCategory.academics, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false, 'showOnExport': true, 'readOnlyForStudent': false},
  ];

  /// Merges loaded fields with default built-ins while preserving sequence, schema defaults, and canonical category mapping.
  static List<Map<String, dynamic>> normalizeConfig(List<dynamic>? rawList) {
    final Map<String, Map<String, dynamic>> builtinMap = {
      for (final def in defaultBuiltinFields) def['id'] as String: def,
    };

    if (rawList == null || rawList.isEmpty) {
      return List<Map<String, dynamic>>.from(
        defaultBuiltinFields.map((f) => Map<String, dynamic>.from(f)),
      );
    }

    final seenIds = <String>{};
    final loaded = <Map<String, dynamic>>[];

    for (final item in rawList) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      var id = (m['id'] ?? m['key'] ?? '').toString().trim();
      if (id == 'pinCode') id = 'pincode';
      if (id.isEmpty || seenIds.contains(id)) continue;
      seenIds.add(id);
      m['id'] = id;

      if (builtinMap.containsKey(id)) {
        final def = builtinMap[id]!;
        m['category'] = def['category'];
        m['builtin'] = true;
        m['type'] = (m['type']?.toString().isNotEmpty == true) ? m['type'] : def['type'];
        m['showOnProfile'] = m['showOnProfile'] as bool? ?? def['showOnProfile'] as bool? ?? true;
        m['showOnIdCard'] = m['showOnIdCard'] as bool? ?? def['showOnIdCard'] as bool? ?? false;
        m['showOnReceipt'] = m['showOnReceipt'] as bool? ?? def['showOnReceipt'] as bool? ?? false;
        m['showOnExport'] = m['showOnExport'] as bool? ?? true;
        m['readOnlyForStudent'] = m['readOnlyForStudent'] as bool? ?? def['readOnlyForStudent'] as bool? ?? false;
      } else {
        final cat = m['category']?.toString();
        m['category'] = (cat != null && FormFieldCategory.orderedCategories.contains(cat))
            ? cat
            : FormFieldCategory.custom;
        m['builtin'] = false;
        m['visible'] = m['visible'] as bool? ?? true;
        m['required'] = m['required'] as bool? ?? false;
        m['showOnProfile'] = m['showOnProfile'] as bool? ?? true;
        m['showOnIdCard'] = m['showOnIdCard'] as bool? ?? false;
        m['showOnReceipt'] = m['showOnReceipt'] as bool? ?? false;
        m['showOnExport'] = m['showOnExport'] as bool? ?? true;
        m['readOnlyForStudent'] = m['readOnlyForStudent'] as bool? ?? false;
      }
      loaded.add(m);
    }

    // Append any newly introduced built-ins that didn't exist when the tenant last saved config
    for (final def in defaultBuiltinFields) {
      final defId = def['id'] as String;
      if (!seenIds.contains(defId)) {
        loaded.add(Map<String, dynamic>.from(def));
      }
    }
    return loaded;
  }

  /// Groups fields into the 5 canonical categories in standardized order.
  static Map<String, List<Map<String, dynamic>>> groupFieldsByCategory(List<Map<String, dynamic>> fields) {
    final Map<String, List<Map<String, dynamic>>> grouped = {
      for (final cat in FormFieldCategory.orderedCategories) cat: [],
    };

    for (final f in fields) {
      final cat = f['category']?.toString() ?? FormFieldCategory.custom;
      if (grouped.containsKey(cat)) {
        grouped[cat]!.add(f);
      } else {
        grouped[FormFieldCategory.custom]!.add(f);
      }
    }
    return grouped;
  }

  /// Live Firestore Stream of the library's form configuration.
  static Stream<List<Map<String, dynamic>>> streamFormConfig(String libraryId) {
    return FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId)
        .collection('settings')
        .doc('form_config')
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) {
        return List<Map<String, dynamic>>.from(
          defaultBuiltinFields.map((f) => Map<String, dynamic>.from(f)),
        );
      }
      final rawFields = snap.data()!['fields'] as List<dynamic>?;
      return normalizeConfig(rawFields);
    });
  }

  /// One-time fetch of the library's form configuration.
  static Future<List<Map<String, dynamic>>> fetchFormConfig(String libraryId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('form_config')
          .get();
      if (snap.exists && snap.data() != null) {
        return normalizeConfig(snap.data()!['fields'] as List<dynamic>?);
      }
    } catch (_) { /* intentionally silent */ }
    return List<Map<String, dynamic>>.from(
      defaultBuiltinFields.map((f) => Map<String, dynamic>.from(f)),
    );
  }

  static Map<String, dynamic>? _findField(List<Map<String, dynamic>> fields, String fieldId) {
    if (fields.isEmpty) return null;
    final normId = fieldId == 'pinCode' ? 'pincode' : fieldId;
    return fields.where((f) {
      final id = (f['id'] ?? f['key'] ?? '').toString();
      return id == fieldId || id == normId || (id == 'pinCode' && normId == 'pincode');
    }).firstOrNull;
  }

  /// Checks if a field is visible
  static bool isFieldVisible(List<Map<String, dynamic>> fields, String fieldId) {
    if (fields.isEmpty) {
      final normId = fieldId == 'pinCode' ? 'pincode' : fieldId;
      final def = defaultBuiltinFields.firstWhere(
        (f) => f['id'] == fieldId || f['id'] == normId,
        orElse: () => {},
      );
      return def['visible'] == true;
    }
    final match = _findField(fields, fieldId);
    if (match != null) {
      return match['visible'] == true;
    }
    return false;
  }

  /// Checks if a field is required
  static bool isFieldRequired(List<Map<String, dynamic>> fields, String fieldId) {
    if (fields.isEmpty) {
      final normId = fieldId == 'pinCode' ? 'pincode' : fieldId;
      final def = defaultBuiltinFields.firstWhere(
        (f) => f['id'] == fieldId || f['id'] == normId,
        orElse: () => {},
      );
      return def['required'] == true || fieldId == 'name' || fieldId == 'phone';
    }
    final match = _findField(fields, fieldId);
    if (match != null) {
      return match['required'] == true;
    }
    return false;
  }

  /// Checks if a field should be visible on a given surface (Profile, ID Card, Receipt, Export).
  static bool isFieldVisibleOnSurface(
    List<Map<String, dynamic>> fields,
    String fieldId, {
    bool profile = false,
    bool idCard = false,
    bool receipt = false,
    bool export = false,
  }) {
    if (fields.isEmpty) {
      final normId = fieldId == 'pinCode' ? 'pincode' : fieldId;
      final def = defaultBuiltinFields.firstWhere(
        (f) => f['id'] == fieldId || f['id'] == normId,
        orElse: () => {},
      );
      if (def.isEmpty || def['visible'] != true) return false;
      if (profile && def['showOnProfile'] == false) return false;
      if (idCard && def['showOnIdCard'] != true) return false;
      if (receipt && def['showOnReceipt'] != true) return false;
      return true;
    }
    final match = _findField(fields, fieldId);
    if (match == null) return false;
    if (match['visible'] == false) return false;
    if (profile && match['showOnProfile'] == false) return false;
    if (idCard && match['showOnIdCard'] != true) return false;
    if (receipt && match['showOnReceipt'] != true) return false;
    if (export && match['showOnExport'] == false) return false;
    return true;
  }

  static bool isReadOnlyForStudent(List<Map<String, dynamic>> fields, String fieldId) {
    final match = _findField(fields, fieldId);
    return match?['readOnlyForStudent'] == true;
  }

  /// Returns the configured custom label or fallback
  static String getFieldLabel(List<Map<String, dynamic>> fields, String fieldId, String defaultLabel) {
    final match = _findField(fields, fieldId);
    if (match != null && match['label'] != null && match['label'].toString().trim().isNotEmpty) {
      return match['label'].toString().trim();
    }
    return defaultLabel;
  }

  /// Returns configured dropdown/multi-select options for a field (if any)
  static List<String> getFieldOptions(List<Map<String, dynamic>> fields, String fieldId) {
    final match = _findField(fields, fieldId);
    if (match != null && match['options'] is List) {
      return (match['options'] as List)
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  /// Returns fields visible in form entry in the exact configured sequence
  static List<Map<String, dynamic>> getVisibleFields(List<Map<String, dynamic>> fields) {
    return fields.where((f) => f['visible'] == true).toList();
  }

  /// Returns custom fields for a specific category
  static List<Map<String, dynamic>> getCustomFieldsForCategory(
    List<Map<String, dynamic>> fields,
    String category, {
    bool profileOnly = false,
  }) {
    return fields.where((f) {
      final isBuiltin = f['builtin'] as bool? ?? false;
      final cat = f['category']?.toString() ?? FormFieldCategory.custom;
      final visible = f['visible'] as bool? ?? true;
      final onProfile = !profileOnly || (f['showOnProfile'] as bool? ?? true);
      return !isBuiltin && visible && onProfile && cat == category;
    }).toList();
  }

  /// Returns fields tagged for a specific display surface (Profile, ID Card, Receipt, Export).
  static List<Map<String, dynamic>> getSurfaceFields(
    List<Map<String, dynamic>> fields, {
    bool onProfile = false,
    bool onIdCard = false,
    bool onReceipt = false,
    bool onExport = false,
    bool? builtinFilter,
  }) {
    return fields.where((f) {
      if (f['visible'] == false) return false;
      final isBuiltin = f['builtin'] as bool? ?? false;
      if (builtinFilter != null && isBuiltin != builtinFilter) return false;
      if (onProfile && f['showOnProfile'] == false) return false;
      if (onIdCard && f['showOnIdCard'] != true) return false;
      if (onReceipt && f['showOnReceipt'] != true) return false;
      if (onExport && f['showOnExport'] == false) return false;
      return true;
    }).toList();
  }

  /// Returns fields to show in the student's profile view in the exact configured sequence
  static List<Map<String, dynamic>> getProfileFields(List<Map<String, dynamic>> fields) {
    return getSurfaceFields(fields, onProfile: true);
  }

  /// Returns ONLY custom fields (`builtin == false`) configured for Export, normalized with `id` and `key` fallbacks.
  static List<Map<String, dynamic>> getExportCustomFields(List<Map<String, dynamic>> fields) {
    return fields.where((f) {
      final isBuiltin = f['builtin'] as bool? ?? false;
      final isCustomExplicit = f['isCustom'] as bool?;
      final matchesCustom = isCustomExplicit == true || !isBuiltin;
      return matchesCustom && f['visible'] != false && f['showOnExport'] != false;
    }).toList();
  }

  /// Resolves the canonical string value for any built-in or custom field from a [StudentModel].
  static String resolveStudentFieldValue(
    StudentModel student,
    String fieldId, {
    bool maskSensitiveGovId = true,
  }) {
    switch (fieldId) {
      case 'name':
        return student.name.trim();
      case 'fatherName':
        return student.fatherName.trim();
      case 'gender':
        return student.gender.name.toUpperCase();
      case 'dob':
        return student.dob != null ? DateFormat('dd MMM yyyy').format(student.dob!) : '';
      case 'bloodGroup':
        return (student.bloodGroup ?? '').trim();
      case 'phone':
        return student.phone.trim();
      case 'email':
        return student.email.trim();
      case 'emergencyContact':
        return student.emergencyContact.trim();
      case 'address':
        return student.address.trim();
      case 'pincode':
      case 'pinCode':
        return student.pincode.trim();
      case 'govId':
        final raw = student.govIdNumber.trim();
        if (raw.isEmpty) return '';
        if (!maskSensitiveGovId) return raw;
        final clean = raw.replaceAll(' ', '');
        if (clean.length > 4) {
          return '${student.govIdType.shortCode} •••• ${clean.substring(clean.length - 4)}';
        }
        return '${student.govIdType.shortCode} Verified';
      case 'prep':
        final t = (student.targetExamName ?? '').trim();
        return t.isNotEmpty ? t : (student.customFields['prep']?.toString().trim() ?? '');
      case 'college':
        return student.college.trim();
      case 'course':
        return student.course.trim();
      case 'year':
        return student.year.trim();
      case 'rollNumber':
        final r = (student.rollNumber ?? '').trim();
        return r.isNotEmpty ? r : (student.customFields['rollNumber']?.toString().trim() ?? '');
      default:
        return (student.customFields[fieldId] ?? '').toString().trim();
    }
  }

  /// Validates any dynamic field (built-in or custom) consistently across screens.
  static String? validateFieldValue(
    String? rawValue,
    Map<String, dynamic> field,
  ) {
    final label = (field['label'] ?? field['id'] ?? 'Field').toString().trim();
    final isRequired = field['required'] == true;
    final fType = (field['type'] ?? 'Text').toString();
    final pattern = field['pattern']?.toString();
    final patternError = field['patternError']?.toString();
    final val = (rawValue ?? '').trim();

    if (isRequired && val.isEmpty) {
      return '$label is required';
    }
    if (val.isEmpty) return null;

    if (fType == 'Phone') {
      return AppValidators.phone(val, required: isRequired, label: label);
    }
    if (fType == 'Email') {
      return AppValidators.email(val, required: isRequired, label: label);
    }
    if (fType == 'Number' && pattern == null) {
      if (num.tryParse(val) == null) return '$label must be a valid number';
    }
    if (pattern != null && pattern.trim().isNotEmpty) {
      return AppValidators.validatePattern(
        val,
        pattern,
        errorMessage: patternError,
        required: isRequired,
        label: label,
      );
    }
    return null;
  }
}

/// Riverpod StreamProvider for Form Configuration
final formConfigStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty) {
    return Stream.value(FormConfigService.defaultBuiltinFields);
  }
  return FormConfigService.streamFormConfig(libraryId);
});
