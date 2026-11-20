import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsRepository {
  final FirebaseFirestore _firestore;

  SettingsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _settingsDoc(String libraryId, String docName) =>
      _firestore.collection('libraries').doc(libraryId).collection('settings').doc(docName);

  Stream<Map<String, dynamic>> streamSetting(String libraryId, String docName) {
    if (libraryId.isEmpty) return Stream.value({});
    return _settingsDoc(libraryId, docName).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return {};
      return doc.data()!;
    });
  }

  Future<Map<String, dynamic>?> getSetting(String libraryId, String docName) async {
    if (libraryId.isEmpty) return null;
    final doc = await _settingsDoc(libraryId, docName).get();
    return doc.data();
  }

  Future<void> saveSetting(
    String libraryId,
    String docName,
    Map<String, dynamic> data, {
    bool merge = true,
  }) async {
    if (libraryId.isEmpty) return;
    await _settingsDoc(libraryId, docName).set(data, SetOptions(merge: merge));
  }
}
