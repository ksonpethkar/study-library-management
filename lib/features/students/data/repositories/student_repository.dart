import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_paths.dart';
import 'package:study_library/core/security/audit_logger.dart';
import 'package:study_library/core/security/encryption_service.dart';
import 'package:study_library/models/student_model.dart';

class StudentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Convenience method to add a student with just the essentials
  Future<String> addStudent({
    required String libraryId,
    required String name,
    required String phone,
    String email = '',
    String address = '',
    String gender = 'male',
  }) async {
    final student = StudentModel(
      id: '',
      name: name,
      fatherName: '',
      phone: phone,
      email: email,
      gender: Gender.values.firstWhere(
        (g) => g.name == gender,
        orElse: () => Gender.male,
      ),
      address: address,
      pincode: '',
      govIdType: GovIdType.aadhaar,
      govIdNumber: '',
      govIdImageUrl: '',
      photoUrl: '',
      college: '',
      course: '',
      year: '',
      emergencyContact: '',
      membershipStatus: MembershipStatus.pending,
      customFields: {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return createStudent(libraryId, student);
  }

  Future<String> createStudent(String libraryId, StudentModel student) async {
    try {
      final cleanPhone = student.phone.trim();
      if (cleanPhone.isNotEmpty) {
        final existingPhone = await _firestore
            .collection(FirestorePaths.libraries)
            .doc(libraryId)
            .collection(FirestorePaths.students)
            .where('phone', isEqualTo: cleanPhone)
            .limit(1)
            .get();
        if (existingPhone.docs.isNotEmpty) {
          throw Exception('This phone number is already registered with us.');
        }
      }

      final cleanGovId = student.govIdNumber.trim();
      String encryptedGovId = cleanGovId;
      String govIdHash = '';
      if (cleanGovId.isNotEmpty) {
        govIdHash = sha256.convert(utf8.encode(cleanGovId)).toString();
        final existingGovIdByHash = await _firestore
            .collection(FirestorePaths.libraries)
            .doc(libraryId)
            .collection(FirestorePaths.students)
            .where('govIdHash', isEqualTo: govIdHash)
            .limit(1)
            .get();
        if (existingGovIdByHash.docs.isNotEmpty) {
          throw Exception('This ID number is already registered.');
        }

        final legacyGovId = await _firestore
            .collection(FirestorePaths.libraries)
            .doc(libraryId)
            .collection(FirestorePaths.students)
            .where('govIdNumber', isEqualTo: cleanGovId)
            .limit(1)
            .get();
        if (legacyGovId.docs.isNotEmpty) {
          throw Exception('This ID number is already registered.');
        }

        encryptedGovId = EncryptionService.encryptGovId(cleanGovId, libraryId);
      }

      final docRef = _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.students)
          .doc();
          
      // Auto-generate sequential membership number using Firestore transaction
      String membershipNumber = '';
      try {
        final libDocRef = _firestore.collection(FirestorePaths.libraries).doc(libraryId);
        await _firestore.runTransaction((tx) async {
          final libSnap = await tx.get(libDocRef);
          final libData = libSnap.data() ?? {};
          final prefix = ((libData['membershipPrefix'] as String?) ?? 'CC').toUpperCase();
          final year = DateTime.now().year;
          final lastNum = (libData['lastMembershipNumber'] as num?)?.toInt() ?? 0;
          final nextNum = lastNum + 1;
          membershipNumber = '$prefix$year${nextNum.toString().padLeft(4, '0')}';
          tx.update(libDocRef, {'lastMembershipNumber': nextNum});
        });
      } catch (e) {
        membershipNumber = 'CC${DateTime.now().year}${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}';
      }

      final base = student.copyWith(id: docRef.id, membershipNumber: membershipNumber).toJson();
      final dataToSave = {
        ...base,
        'govIdNumber': encryptedGovId,
        if (govIdHash.isNotEmpty) 'govIdHash': govIdHash,
        // Override date fields with Firestore Timestamps for range-query compatibility
        if (student.planStartDate != null) 'planStartDate': Timestamp.fromDate(student.planStartDate!),
        if (student.planEndDate != null)   'planEndDate':   Timestamp.fromDate(student.planEndDate!),
        if (student.graceEndDate != null)  'graceEndDate':  Timestamp.fromDate(student.graceEndDate!),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await docRef.set(dataToSave);
      AuditLogger().log(
        action: AuditAction.created,
        entityType: AuditEntity.student,
        entityId: docRef.id,
        details: {'name': student.name, 'libraryId': libraryId},
      ).ignore();
      return docRef.id;
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Failed to create student. Please try again.');
    }
  }

  Future<void> updateStudent(String libraryId, StudentModel student) async {
    try {
      final cleanPhone = student.phone.trim();
      if (cleanPhone.isNotEmpty) {
        final existingPhone = await _firestore
            .collection(FirestorePaths.libraries)
            .doc(libraryId)
            .collection(FirestorePaths.students)
            .where('phone', isEqualTo: cleanPhone)
            .limit(5)
            .get();
        for (final doc in existingPhone.docs) {
          if (doc.id != student.id) {
            throw Exception('This phone number is already registered with us.');
          }
        }
      }

      final cleanGovId = student.govIdNumber.trim();
      String encryptedGovId = cleanGovId;
      String govIdHash = '';
      if (cleanGovId.isNotEmpty) {
        govIdHash = sha256.convert(utf8.encode(cleanGovId)).toString();
        encryptedGovId = EncryptionService.encryptGovId(cleanGovId, libraryId);
      }

      final dataToUpdate = {
        ...student.toJson(),
        'govIdNumber': encryptedGovId,
        if (govIdHash.isNotEmpty) 'govIdHash': govIdHash,
      };

      await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.students)
          .doc(student.id)
          .update(dataToUpdate);
      AuditLogger().log(
        action: AuditAction.updated,
        entityType: AuditEntity.student,
        entityId: student.id,
        details: {'name': student.name, 'libraryId': libraryId},
      ).ignore();
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Failed to update student details.');
    }
  }

  Future<void> deleteStudent(String libraryId, String studentId) async {
    try {
      final studentDoc = await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.students)
          .doc(studentId)
          .get();
          
      final batch = _firestore.batch();
      
      final recycleBinRef = _firestore.collection(FirestorePaths.recycleBin).doc(studentId);
      batch.set(recycleBinRef, {
        ...studentDoc.data()!,
        'deletedAt': FieldValue.serverTimestamp(),
        'type': 'student',
        'libraryId': libraryId,
      });
      
      batch.delete(studentDoc.reference);
      await batch.commit();
      AuditLogger().log(
        action: AuditAction.deleted,
        entityType: AuditEntity.student,
        entityId: studentId,
        details: {'libraryId': libraryId},
      ).ignore();
    } catch (e) {
      throw Exception('Failed to delete student.');
    }
  }

  Future<void> deactivateStudent(String libraryId, String studentId) async {
    try {
      final studentRef = _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.students)
          .doc(studentId);

      final batch = _firestore.batch();

      // Deactivate student
      batch.update(studentRef, {
        'membershipStatus': 'inactive',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Free assigned seat if any
      final snap = await studentRef.get();
      final data = snap.data();
      final seatId = data?['seatId'] as String?;
      final sectionId = data?['sectionId'] as String?;
      if (seatId != null && sectionId != null && seatId.isNotEmpty && sectionId.isNotEmpty) {
        final seatRef = _firestore
            .collection(FirestorePaths.libraries)
            .doc(libraryId)
            .collection(FirestorePaths.sections)
            .doc(sectionId)
            .collection(FirestorePaths.seats)
            .doc(seatId);
        batch.update(seatRef, {'status': 'available', 'studentId': null});
        // Also clear seatId from student doc
        batch.update(studentRef, {'seatId': null, 'sectionId': null});
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to deactivate student: $e');
    }
  }

  Future<void> archiveStudent(String libraryId, String studentId) async {
    try {
      await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.students)
          .doc(studentId)
          .update({'membershipStatus': 'archived', 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      throw Exception('Failed to archive student.');
    }
  }

  Future<void> restoreStudent(String libraryId, String studentId) async {
    try {
      final recycleDoc = await _firestore.collection(FirestorePaths.recycleBin).doc(studentId).get();
      if (!recycleDoc.exists) throw Exception('Student not found in recycle bin.');
      
      final data = recycleDoc.data()!;
      data.remove('deletedAt');
      data.remove('type');
      
      final batch = _firestore.batch();
      
      final studentRef = _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.students)
          .doc(studentId);
          
      batch.set(studentRef, data);
      batch.delete(recycleDoc.reference);
      
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to restore student.');
    }
  }

  Future<void> reactivateStudent(String libraryId, String studentId) async {
    try {
      await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.students)
          .doc(studentId)
          .update({'membershipStatus': 'active', 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      throw Exception('Failed to reactivate student.');
    }
  }

  StudentModel _parseStudentDoc(DocumentSnapshot<Map<String, dynamic>> doc, String libraryId) {
    final data = doc.data() ?? {};
    final rawGovId = data['govIdNumber']?.toString() ?? '';
    final decryptedGovId = EncryptionService.safeDecryptGovId(rawGovId, libraryId);
    return StudentModel.fromJson({
      ...data,
      'id': doc.id,
      'govIdNumber': decryptedGovId,
    });
  }

  Stream<List<StudentModel>> getStudents(String libraryId) {
    return _firestore
        .collection(FirestorePaths.libraries)
        .doc(libraryId)
        .collection(FirestorePaths.students)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => _parseStudentDoc(doc, libraryId)).toList());
  }

  Future<StudentModel?> getStudentById(String libraryId, String studentId) async {
    try {
      final doc = await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.students)
          .doc(studentId)
          .get();
          
      if (doc.exists) {
        return _parseStudentDoc(doc, libraryId);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch student details.');
    }
  }

  Future<List<StudentModel>> searchStudents(String libraryId, String query) async {
    try {
      final snapshot = await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.students)
          .get();
          
      final q = query.toLowerCase();
      return snapshot.docs
          .map((doc) => _parseStudentDoc(doc, libraryId))
          .where((student) => 
              student.name.toLowerCase().contains(q) || 
              student.phone.contains(q) || 
              student.govIdNumber.toLowerCase().contains(q))
          .toList();
    } catch (e) {
      throw Exception('Failed to search students.');
    }
  }

  Stream<List<StudentModel>> getStudentsByStatus(String libraryId, String status) {
    return _firestore
        .collection(FirestorePaths.libraries)
        .doc(libraryId)
        .collection(FirestorePaths.students)
        .where('membershipStatus', isEqualTo: status)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => _parseStudentDoc(doc, libraryId)).toList());
  }

  Future<List<StudentModel>> getExpiringStudents(String libraryId, int daysAhead) async {
    try {
      final targetDate = DateTime.now().add(Duration(days: daysAhead));
      final snapshot = await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.students)
          .where('planEndDate', isLessThanOrEqualTo: Timestamp.fromDate(targetDate))
          .where('membershipStatus', isEqualTo: 'active')
          .get();
          
      return snapshot.docs.map((doc) => _parseStudentDoc(doc, libraryId)).toList();
    } catch (e) {
      throw Exception('Failed to fetch expiring students.');
    }
  }

  Future<bool> checkDuplicatePhone(String libraryId, String phone) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.libraries)
        .doc(libraryId)
        .collection(FirestorePaths.students)
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<bool> checkDuplicateGovId(String libraryId, String govIdNumber) async {
    final clean = govIdNumber.trim();
    if (clean.isEmpty) return false;
    final hash = sha256.convert(utf8.encode(clean)).toString();

    final hashSnap = await _firestore
        .collection(FirestorePaths.libraries)
        .doc(libraryId)
        .collection(FirestorePaths.students)
        .where('govIdHash', isEqualTo: hash)
        .limit(1)
        .get();
    if (hashSnap.docs.isNotEmpty) return true;

    final legacySnap = await _firestore
        .collection(FirestorePaths.libraries)
        .doc(libraryId)
        .collection(FirestorePaths.students)
        .where('govIdNumber', isEqualTo: clean)
        .limit(1)
        .get();
    return legacySnap.docs.isNotEmpty;
  }

  Future<void> changeSeat(String libraryId, String studentId, String newSeatId) async {
    try {
      await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.students)
          .doc(studentId)
          .update({'seatId': newSeatId, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      throw Exception('Failed to change seat.');
    }
  }

  Future<void> changePlan(String libraryId, String studentId, String planId, DateTime startDate, {DateTime? endDate}) async {
    try {
      final update = <String, dynamic>{
        'planId': planId,
        'planStartDate': Timestamp.fromDate(startDate),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (endDate != null) {
        update['planEndDate'] = Timestamp.fromDate(endDate);
      }
      await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.students)
          .doc(studentId)
          .update(update);
    } catch (e) {
      throw Exception('Failed to change plan.');
    }
  }

  Future<int> getStudentCount(String libraryId) async {
    try {
      final aggregateQuery = await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.students)
          .count()
          .get();
      return aggregateQuery.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> bulkDelete(String libraryId, List<String> studentIds) async {
    try {
      final batch = _firestore.batch();
      for (final id in studentIds) {
        final ref = _firestore
            .collection(FirestorePaths.libraries)
            .doc(libraryId)
            .collection(FirestorePaths.students)
            .doc(id);
            
        // Move to recycle bin ideally, but keeping it simple as delete for bulk
        batch.delete(ref);
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete students in bulk.');
    }
  }

  Future<void> bulkChangePlan(String libraryId, List<String> studentIds, String planId) async {
    try {
      final batch = _firestore.batch();
      for (final id in studentIds) {
        final ref = _firestore
            .collection(FirestorePaths.libraries)
            .doc(libraryId)
            .collection(FirestorePaths.students)
            .doc(id);
        batch.update(ref, {'planId': planId, 'updatedAt': FieldValue.serverTimestamp()});
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to change plans in bulk.');
    }
  }

  /// Evaluates active & grace memberships, transitions expired plans, and releases seats.
  Future<void> checkAndExpireMemberships(String libraryId) async {
    try {
      // Direct call to client-side automation engine
      final snapshot = await _firestore
          .collection(FirestorePaths.libraries)
          .doc(libraryId)
          .collection(FirestorePaths.students)
          .where('membershipStatus', whereIn: ['active', 'grace'])
          .get();

      final now = DateTime.now();
      final batch = _firestore.batch();
      bool hasUpdates = false;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final planEndRaw = data['planEndDate'];
        if (planEndRaw == null) continue;

        DateTime? planEnd;
        if (planEndRaw is Timestamp) {
          planEnd = planEndRaw.toDate();
        } else if (planEndRaw is String) {
          planEnd = DateTime.tryParse(planEndRaw);
        }

        if (planEnd == null) continue;

        DateTime? graceEnd;
        final graceEndRaw = data['graceEndDate'];
        if (graceEndRaw is Timestamp) {
          graceEnd = graceEndRaw.toDate();
        } else if (graceEndRaw is String) {
          graceEnd = DateTime.tryParse(graceEndRaw);
        }
        graceEnd ??= planEnd.add(const Duration(days: 3));

        final currentStatus = data['membershipStatus'] as String? ?? 'active';

        if (now.isAfter(graceEnd)) {
          final seatId = data['seatId'] as String?;
          final sectionId = data['sectionId'] as String?;

          // Release seat if assigned
          if (seatId != null && seatId.isNotEmpty && sectionId != null && sectionId.isNotEmpty) {
            final seatRef = _firestore
                .collection(FirestorePaths.libraries)
                .doc(libraryId)
                .collection('sections')
                .doc(sectionId)
                .collection('seats')
                .doc(seatId);

            batch.update(seatRef, {
              'status': 'available',
              'studentId': null,
            });
          }

          batch.update(doc.reference, {
            'membershipStatus': 'expired',
            'seatId': null,
            'sectionId': null,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          hasUpdates = true;
        } else if (now.isAfter(planEnd) && currentStatus == 'active') {
          batch.update(doc.reference, {
            'membershipStatus': 'grace',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          hasUpdates = true;
        }
      }

      if (hasUpdates) {
        await batch.commit();
      }
    } catch (_) {}
  }

  Future<void> blockStudent(
    String libraryId,
    String studentId, {
    required String reason,
  }) async {
    final batch = _firestore.batch();
    final studentRef = _firestore
        .collection('libraries').doc(libraryId)
        .collection('students').doc(studentId);
    batch.update(studentRef, {
      'membershipStatus': 'blocked',
      'blockedReason': reason,
      'blockedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    AuditLogger().log(
      action: AuditAction.updated,
      entityType: AuditEntity.student,
      entityId: studentId,
      details: {'blocked': true, 'reason': reason},
    ).ignore();
  }

  Future<void> unblockStudent(String libraryId, String studentId) async {
    await _firestore
        .collection('libraries').doc(libraryId)
        .collection('students').doc(studentId)
        .update({
      'membershipStatus': 'active',
      'blockedReason': FieldValue.delete(),
      'blockedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    AuditLogger().log(
      action: AuditAction.updated,
      entityType: AuditEntity.student,
      entityId: studentId,
      details: {'unblocked': true},
    ).ignore();
  }
}
