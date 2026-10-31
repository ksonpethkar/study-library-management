import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/core/providers/library_provider.dart';

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

class FormConfigService {
  static const List<Map<String, dynamic>> defaultBuiltinFields = [
    // ── 1. Personal Details ───────────────────────────────────────────────────
    {'id': 'name', 'label': 'Full Name', 'type': 'Text', 'required': true, 'visible': true, 'builtin': true, 'category': FormFieldCategory.personal, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false},
    {'id': 'fatherName', 'label': "Father's / Guardian's Name", 'type': 'Text', 'required': false, 'visible': true, 'builtin': true, 'category': FormFieldCategory.personal, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false},
    {'id': 'gender', 'label': 'Gender', 'type': 'Dropdown', 'required': true, 'visible': true, 'builtin': true, 'category': FormFieldCategory.personal, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false},
    {'id': 'dob', 'label': 'Date of Birth', 'type': 'Date', 'required': true, 'visible': true, 'builtin': true, 'category': FormFieldCategory.personal, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false},
    {'id': 'bloodGroup', 'label': 'Blood Group', 'type': 'Dropdown', 'required': false, 'visible': true, 'builtin': true, 'category': FormFieldCategory.personal, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false},

    // ── 2. Contact & Residence ────────────────────────────────────────────────
    {'id': 'phone', 'label': 'Phone Number', 'type': 'Number', 'required': true, 'visible': true, 'builtin': true, 'category': FormFieldCategory.contact, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false},
    {'id': 'email', 'label': 'Email Address', 'type': 'Text', 'required': false, 'visible': true, 'builtin': true, 'category': FormFieldCategory.contact, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false},
    {'id': 'emergencyContact', 'label': 'Emergency Contact', 'type': 'Number', 'required': false, 'visible': true, 'builtin': true, 'category': FormFieldCategory.contact, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false},
    {'id': 'address', 'label': 'Residential Address', 'type': 'Text', 'required': true, 'visible': true, 'builtin': true, 'category': FormFieldCategory.contact, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false},
    {'id': 'pincode', 'label': 'Pincode', 'type': 'Number', 'required': true, 'visible': true, 'builtin': true, 'category': FormFieldCategory.contact, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false},

    // ── 3. Government ID & KYC ────────────────────────────────────────────────
    {'id': 'govId', 'label': 'Aadhaar / Govt ID', 'type': 'Text', 'required': true, 'visible': true, 'builtin': true, 'category': FormFieldCategory.govId, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false},

    // ── 4. Academic & Competitive Goals ───────────────────────────────────────
    {'id': 'prep', 'label': 'Exam / Target Course', 'type': 'Text', 'required': false, 'visible': true, 'builtin': true, 'category': FormFieldCategory.academics, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false},
    {'id': 'college', 'label': 'College / Institute Name', 'type': 'Text', 'required': false, 'visible': true, 'builtin': true, 'category': FormFieldCategory.academics, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false},
    {'id': 'course', 'label': 'Course / Degree', 'type': 'Text', 'required': false, 'visible': true, 'builtin': true, 'category': FormFieldCategory.academics, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false},
    {'id': 'year', 'label': 'Year / Sem', 'type': 'Text', 'required': false, 'visible': true, 'builtin': true, 'category': FormFieldCategory.academics, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false},
    {'id': 'rollNumber', 'label': 'Roll / Enroll Number', 'type': 'Text', 'required': false, 'visible': true, 'builtin': true, 'category': FormFieldCategory.academics, 'showOnProfile': true, 'showOnIdCard': false, 'showOnReceipt': false},
  ];

  /// Merges loaded fields with default built-ins while strictly preserving configured sequence and canonical category mapping.
  static List<Map<String, dynamic>> normalizeConfig(List<dynamic>? rawList) {
    final Map<String, Map<String, dynamic>> builtinMap = {
      for (final def in defaultBuiltinFields) def['id'] as String: def,
    };

    if (rawList == null || rawList.isEmpty) {
      return List<Map<String, dynamic>>.from(defaultBuiltinFields.map((f) => Map<String, dynamic>.from(f)));
    }

    final loaded = rawList
        .whereType<Map>()
        .map((item) {
          final m = Map<String, dynamic>.from(item);
          final id = m['id']?.toString() ?? '';
          if (builtinMap.containsKey(id)) {
            final def = builtinMap[id]!;
            m['category'] = def['category'];
            m['builtin'] = true;
            if (id == 'prep') {
              m['builtin'] = true;
              m['category'] = FormFieldCategory.academics;
            }
          } else {
            m['category'] = m['category'] ?? FormFieldCategory.custom;
            m['builtin'] = false;
          }
          return m;
        })
        .toList();

    // Check if any default built-ins are missing and append them
    final existingIds = loaded.map((f) => f['id']?.toString()).toSet();
    for (final def in defaultBuiltinFields) {
      if (!existingIds.contains(def['id'])) {
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
        return List<Map<String, dynamic>>.from(defaultBuiltinFields.map((f) => Map<String, dynamic>.from(f)));
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
    return List<Map<String, dynamic>>.from(defaultBuiltinFields.map((f) => Map<String, dynamic>.from(f)));
  }

  /// Checks if a field is visible
  static bool isFieldVisible(List<Map<String, dynamic>> fields, String fieldId) {
    if (fields.isEmpty) {
      final def = defaultBuiltinFields.firstWhere((f) => f['id'] == fieldId, orElse: () => {});
      return def['visible'] == true;
    }
    final match = fields.where((f) => f['id'] == fieldId).firstOrNull;
    if (match != null) {
      return match['visible'] == true;
    }
    return false;
  }

  /// Checks if a field is required
  static bool isFieldRequired(List<Map<String, dynamic>> fields, String fieldId) {
    if (fields.isEmpty) {
      return fieldId == 'name' || fieldId == 'phone';
    }
    final match = fields.where((f) => f['id'] == fieldId).firstOrNull;
    if (match != null) {
      return match['required'] == true;
    }
    return false;
  }

  /// Returns the configured custom label or fallback
  static String getFieldLabel(List<Map<String, dynamic>> fields, String fieldId, String defaultLabel) {
    if (fields.isNotEmpty) {
      final match = fields.where((f) => f['id'] == fieldId).firstOrNull;
      if (match != null && match['label'] != null && match['label'].toString().trim().isNotEmpty) {
        return match['label'].toString().trim();
      }
    }
    return defaultLabel;
  }

  /// Returns fields visible in form entry in the exact configured sequence
  static List<Map<String, dynamic>> getVisibleFields(List<Map<String, dynamic>> fields) {
    return fields.where((f) => f['visible'] == true).toList();
  }

  /// Returns fields to show in the student's profile view in the exact configured sequence
  static List<Map<String, dynamic>> getProfileFields(List<Map<String, dynamic>> fields) {
    return fields.where((f) => f['visible'] != false && f['showOnProfile'] != false).toList();
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
