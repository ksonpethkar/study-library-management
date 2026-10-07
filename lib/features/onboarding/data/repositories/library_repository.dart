import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../../../../core/utils/image_compressor.dart';
import '../../../../models/library_model.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository();
});

class LibraryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createLibrary(LibraryModel libraryModel) async {
    final docRef = _firestore.collection(FirestorePaths.libraries).doc();
    final newLib = libraryModel.copyWith(id: docRef.id);
    await docRef.set(newLib.toJson());
    return docRef.id;
  }

  Future<void> updateLibrary(LibraryModel libraryModel) async {
    await _firestore.collection(FirestorePaths.libraries).doc(libraryModel.id).update(libraryModel.toJson());
  }

  Future<LibraryModel?> getLibrary(String libraryId) async {
    final doc = await _firestore.collection(FirestorePaths.libraries).doc(libraryId).get();
    if (doc.exists && doc.data() != null) {
      return LibraryModel.fromJson({...doc.data()!, 'id': doc.id});
    }
    return null;
  }

  Stream<LibraryModel?> streamLibrary(String libraryId) {
    return _firestore.collection(FirestorePaths.libraries).doc(libraryId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return LibraryModel.fromJson({...doc.data()!, 'id': doc.id});
      }
      return null;
    });
  }

  Future<LibraryModel?> getLibraryByOwnerId(String ownerId) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.libraries)
        .where('ownerId', isEqualTo: ownerId)
        .get();
    if (snapshot.docs.isNotEmpty) {
      final docs = snapshot.docs.toList()
        ..sort((a, b) {
          final aTime = (a.data()['updatedAt'] ?? a.data()['createdAt']) as Timestamp?;
          final bTime = (b.data()['updatedAt'] ?? b.data()['createdAt']) as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });
      return LibraryModel.fromJson({...docs.first.data(), 'id': docs.first.id});
    }
    return null;
  }

  Future<void> updateSettings(String libraryId, String settingsKey, Map<String, dynamic> data) async {
    await _firestore.collection(FirestorePaths.libraries).doc(libraryId).collection('settings').doc(settingsKey).set(data, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getSettings(String libraryId, String settingsKey) async {
    final doc = await _firestore.collection(FirestorePaths.libraries).doc(libraryId).collection('settings').doc(settingsKey).get();
    return doc.data();
  }

  /// Converts an image File to a compressed Base64 data URL and returns it.
  /// Firebase Storage requires the paid Blaze plan — we store images as Base64
  /// text in Firestore instead. Images are compressed to ~50 KB before encoding.
  Future<String> _imageToBase64(File image, {int maxWidth = 600, int quality = 60}) async {
    try {
      final compressed = await ImageCompressor.compressImage(image, maxWidth: maxWidth, quality: quality);
      final bytes = await compressed.readAsBytes();
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    } catch (e) {
      debugPrint('Compression failed, using raw bytes: $e');
      final bytes = await image.readAsBytes();
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }
  }

  /// Upload logo — stored as Base64 in Firestore (no Firebase Storage needed)
  Future<String> uploadLogo(String libraryId, File image) async {
    try {
      return await _imageToBase64(image, maxWidth: 400, quality: 70);
    } catch (e) {
      debugPrint('Logo encoding failed: $e');
      throw Exception('Failed to process logo image. Please try another photo.');
    }
  }

  /// Upload stamp — stored as Base64 in Firestore (no Firebase Storage needed)
  Future<String> uploadStamp(String libraryId, File image) async {
    try {
      return await _imageToBase64(image, maxWidth: 400, quality: 70);
    } catch (e) {
      debugPrint('Stamp encoding failed: $e');
      throw Exception('Failed to process stamp image. Please try another photo.');
    }
  }

  /// Upload signature — stored as Base64 in Firestore (no Firebase Storage needed)
  Future<String> uploadSignature(String libraryId, File image) async {
    try {
      return await _imageToBase64(image, maxWidth: 400, quality: 70);
    } catch (e) {
      debugPrint('Signature encoding failed: $e');
      throw Exception('Failed to process signature image. Please try another photo.');
    }
  }
}
