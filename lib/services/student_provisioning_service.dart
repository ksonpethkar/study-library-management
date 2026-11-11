import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:study_library/core/security/audit_logger.dart';
import 'package:study_library/core/utils/sequence_counter.dart';
import 'package:study_library/features/seats/data/repositories/seat_repository.dart';
import 'package:study_library/features/students/data/repositories/student_repository.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/services/plan_calculator_service.dart';
import 'package:study_library/services/app_notification_service.dart';

class StudentProvisioningService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final StudentRepository _studentRepo = StudentRepository();
  static final SeatRepository _seatRepo = SeatRepository();

  /// Centralized logic to approve any student request and create/update
  /// the corresponding student in libraries/{libraryId}/students,
  /// assign the requested seat, and link users/{uid}.
  static Future<String?> approveAndProvisionRequest({
    required String libraryId,
    required String requestId,
    Map<String, dynamic>? preloadedData,
    bool allowSharedGovId = false,
  }) async {
    if (libraryId.isEmpty || requestId.isEmpty) return null;

    try {
      final docRef = _firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('requests')
          .doc(requestId);

      Map<String, dynamic>? data = preloadedData;
      if (data == null) {
        final snap = await docRef.get();
        if (!snap.exists) return null;
        data = snap.data();
      }
      if (data == null) return null;

      final type = data['type'] as String? ?? 'registration';
      final studentData = (data['studentData'] as Map<String, dynamic>?) ?? {};
      final studentUserId = (studentData['userId'] ?? data['studentId'] ?? '').toString();
      final studentEmail = (studentData['email'] ?? data['studentEmail'] ?? '').toString().trim();
      final requestedSeatId = (studentData['seatId'] ?? data['requestedSeatId']) as String?;
      final requestedSectionId = (studentData['sectionId'] ?? data['requestedSectionId']) as String?;
      final bool isPaid = data['isPaid'] == true ||
          data['paymentReceived'] == true ||
          data['receiptId'] != null ||
          data['paymentStatus'] == 'paid' ||
          studentData['isPaid'] == true;

      String? createdStudentId = data['createdStudentId'] as String?;

      if (type == 'registration' || type == 'newregistration') {
        // 1. Check if student already exists by userId or email
        StudentModel? existingStudent;
        if (studentUserId.isNotEmpty) {
          final queryByUid = await _firestore
              .collection('libraries')
              .doc(libraryId)
              .collection('students')
              .where('userId', isEqualTo: studentUserId)
              .limit(1)
              .get();
          if (queryByUid.docs.isNotEmpty) {
            existingStudent = StudentModel.fromJson({
              ...queryByUid.docs.first.data(),
              'id': queryByUid.docs.first.id,
            });
            createdStudentId = existingStudent.id;
          }
        }

        if (existingStudent == null && studentEmail.isNotEmpty) {
          final queryByEmail = await _firestore
              .collection('libraries')
              .doc(libraryId)
              .collection('students')
              .where('email', isEqualTo: studentEmail)
              .limit(1)
              .get();
          if (queryByEmail.docs.isNotEmpty) {
            existingStudent = StudentModel.fromJson({
              ...queryByEmail.docs.first.data(),
              'id': queryByEmail.docs.first.id,
            });
            createdStudentId = existingStudent.id;
          }
        }

        // 2. Calculate Plan Expiry Dates if plan is selected
        final planId = (studentData['planId'] ?? data['planId'] as String?)?.toString();
        DateTime? planStartDate;
        DateTime? planEndDate;
        double? planSecurityDeposit;
        if (planId != null && planId.isNotEmpty) {
          try {
            final planDoc = await _firestore
                .collection('libraries')
                .doc(libraryId)
                .collection('plans')
                .doc(planId)
                .get();
            if (planDoc.exists && planDoc.data() != null) {
              final plan = PlanModel.fromJson({...planDoc.data()!, 'id': planDoc.id});
              if (plan.hasSecurityDeposit && plan.securityDepositAmount != null) {
                planSecurityDeposit = plan.securityDepositAmount;
              }
              planStartDate = DateTime.now();
              final smartCalc = PlanCalculatorService.calculateSmartPlan(
                plan: plan,
                fromDate: planStartDate,
              );
              planEndDate = smartCalc.endDate;
            }
          } catch (e) {
            if (kDebugMode) debugPrint('Failed to calculate plan duration: $e');
          }
        }

        final genderStr = (studentData['gender'] ?? 'male').toString().toLowerCase();
        final gender = Gender.values.firstWhere(
          (g) => g.name == genderStr,
          orElse: () => Gender.male,
        );

        final govIdTypeStr = (studentData['govIdType'] ?? 'aadhaar').toString().toLowerCase();
        final govIdType = GovIdType.values.firstWhere(
          (g) => g.name.toLowerCase() == govIdTypeStr,
          orElse: () => GovIdType.aadhaar,
        );

        final extractedGovIdFront = (studentData['govIdImageUrl'] ??
                studentData['govIdFrontUrl'] ??
                studentData['govIdImagePath'] ??
                studentData['govIdDataUrl'] ??
                studentData['idCardUrl'] ??
                studentData['idProofUrl'] ??
                studentData['documentUrl'] ??
                data['govIdImageUrl'] ??
                data['govIdFrontUrl'] ??
                data['govIdImagePath'] ??
                data['govIdDataUrl'] ??
                data['idProofUrl'] ??
                '')
            .toString();

        final extractedGovIdBack = (studentData['govIdBackImageUrl'] ??
                studentData['govIdBackUrl'] ??
                studentData['govIdBackImagePath'] ??
                studentData['govIdBackDataUrl'] ??
                studentData['idProofBackUrl'] ??
                studentData['documentBackUrl'] ??
                studentData['idCardBackUrl'] ??
                data['govIdBackImageUrl'] ??
                data['govIdBackUrl'] ??
                data['govIdBackImagePath'] ??
                data['govIdBackDataUrl'] ??
                data['idProofBackUrl'])
            ?.toString();

        final rawCustom = studentData['customFields'] ?? data['customFields'];
        final Map<String, dynamic> extractedCustomFields = rawCustom is Map
            ? Map<String, dynamic>.from(rawCustom)
            : <String, dynamic>{};

        if (existingStudent != null) {
          // Student already exists -> update status & sync gov id if missing
          final updatedStudent = existingStudent.copyWith(
            membershipStatus: isPaid ? MembershipStatus.active : MembershipStatus.inactive,
            seatId: requestedSeatId ?? existingStudent.seatId,
            sectionId: requestedSectionId ?? existingStudent.sectionId,
            planId: planId ?? existingStudent.planId,
            planStartDate: isPaid ? (planStartDate ?? existingStudent.planStartDate) : null,
            planEndDate: isPaid ? (planEndDate ?? existingStudent.planEndDate) : null,
            govIdImageUrl: existingStudent.govIdImageUrl.isNotEmpty ? existingStudent.govIdImageUrl : extractedGovIdFront,
            govIdBackImageUrl: existingStudent.govIdBackImageUrl ?? extractedGovIdBack,
            customFields: {
              ...existingStudent.customFields,
              ...extractedCustomFields,
            },
            userId: studentUserId.isNotEmpty ? studentUserId : existingStudent.userId,
            updatedAt: DateTime.now(),
          );
          await _studentRepo.updateStudent(libraryId, updatedStudent);
          createdStudentId = existingStudent.id;
        } else {
          // Create brand new student in libraries/{libraryId}/students
          final libDoc = await _firestore.collection('libraries').doc(libraryId).get();
          final prefix = (libDoc.data()?['membershipPrefix'] as String?)?.toUpperCase() ?? 'CC';
          final membershipNumber = await SequenceCounter.nextMembershipNumber(libraryId, prefix: prefix);

          final newStudent = StudentModel(
            id: '',
            membershipNumber: membershipNumber,
            name: studentData['name'] ?? data['studentName'] ?? 'Student',
            fatherName: studentData['fatherName'] ?? '',
            phone: studentData['phone'] ?? data['studentPhone'] ?? '',
            email: studentEmail,
            gender: gender,
            address: studentData['address'] ?? '',
            pincode: studentData['pincode'] ?? '',
            govIdType: govIdType,
            govIdNumber: (studentData['govIdNumber'] ?? studentData['idNumber'] ?? studentData['aadhaarNumber'] ?? studentData['panNumber'] ?? '').toString(),
            govIdImageUrl: extractedGovIdFront,
            govIdBackImageUrl: extractedGovIdBack,
            photoUrl: (studentData['photoUrl'] ?? data['photoUrl'] ?? '').toString(),
            college: studentData['college'] ?? '',
            course: studentData['course'] ?? '',
            year: studentData['year'] ?? '',
            emergencyContact: studentData['emergencyContact'] ?? '',
            dob: StudentModel.parseDateStatic(studentData['dob']),
            bloodGroup: studentData['bloodGroup'] as String?,
            rollNumber: studentData['rollNumber'] as String?,
            seatId: requestedSeatId,
            sectionId: requestedSectionId,
            planId: planId,
            planStartDate: isPaid ? planStartDate : null,
            planEndDate: isPaid ? planEndDate : null,
            membershipStatus: isPaid ? MembershipStatus.active : MembershipStatus.inactive,
            customFields: {
              ...extractedCustomFields,
              'originalRequestId': requestId,
            },
            securityDepositAmount: planSecurityDeposit,
            notes: isPaid
                ? 'Approved via Student App'
                : 'Admission Approved via App — Pending Fee Payment',
            userId: studentUserId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          createdStudentId = await _studentRepo.createStudent(libraryId, newStudent, allowSharedGovId: allowSharedGovId);
        }

        // 3. Assign Seat if specified
        if (requestedSeatId != null && requestedSectionId != null) {
          try {
            await _seatRepo.assignStudent(
              libraryId,
              requestedSectionId,
              requestedSeatId,
              createdStudentId,
            );
          } catch (e) {
            if (kDebugMode) debugPrint('Failed to assign seat during provisioning: $e');
          }
        }

        // 4. Link User Account in users/{uid}
        if (studentUserId.isNotEmpty) {
          try {
            await _firestore.collection('users').doc(studentUserId).set({
              'role': 'student',
              'libraryId': libraryId,
              'studentId': createdStudentId,
              'email': studentEmail,
              'displayName': studentData['name'] ?? data['studentName'] ?? 'Student',
              'phone': studentData['phone'] ?? data['studentPhone'] ?? '',
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } catch (e) {
            if (kDebugMode) debugPrint('Failed to link student in users collection: $e');
          }
        }
      }

      if (type == 'seat_change' || type == 'seatchange') {
        final targetStudentId = (data['studentId'] ?? studentData['studentId'] ?? studentUserId).toString();
        final targetSeatId = (data['targetSeatId'] ?? data['seatId'] ?? studentData['targetSeatId']) as String?;
        final targetSectionId = (data['targetSectionId'] ?? data['sectionId'] ?? studentData['targetSectionId']) as String?;
        final currentSeatId = (data['currentSeatId'] ?? studentData['currentSeatId']) as String?;
        final currentSectionId = (data['currentSectionId'] ?? studentData['currentSectionId']) as String?;

        if (targetStudentId.isNotEmpty && targetSeatId != null && targetSectionId != null) {
          if (currentSeatId != null && currentSectionId != null && currentSeatId.isNotEmpty && currentSectionId.isNotEmpty) {
            try {
              await _seatRepo.transferStudent(
                libraryId,
                currentSectionId,
                currentSeatId,
                targetSectionId,
                targetSeatId,
                targetStudentId,
              );
            } catch (e) {
              if (kDebugMode) debugPrint('Error in transferStudent: $e');
            }
          } else {
            try {
              await _seatRepo.assignStudent(libraryId, targetSectionId, targetSeatId, targetStudentId);
            } catch (e) {
              if (kDebugMode) debugPrint('Error assigning target seat: $e');
            }
          }

          // Update student document
          try {
            await _firestore
                .collection('libraries')
                .doc(libraryId)
                .collection('students')
                .doc(targetStudentId)
                .update({
              'seatId': targetSeatId,
              'sectionId': targetSectionId,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } catch (e) {
            if (kDebugMode) debugPrint('Error updating student doc: $e');
          }

          // Notify student
          final studentName = data['studentName'] ?? studentData['name'] ?? 'Student';
          final targetSeatLabel = data['targetSeatLabel'] ?? targetSeatId;
          AppNotificationService.sendNotification(
            libraryId: libraryId,
            title: 'Seat Change Approved! 🪑',
            body: 'Hello $studentName! Your seat change request has been approved. You are now assigned to Seat #$targetSeatLabel.',
            type: 'seat_change',
            targetRole: 'student',
            targetUserId: targetStudentId,
            actionRoute: '/student/home',
          ).ignore();

          createdStudentId = targetStudentId;

          // Automatically mark all other pending seat change requests from this student as superseded
          try {
            final allPending = await _firestore
                .collection('libraries')
                .doc(libraryId)
                .collection('requests')
                .where('status', isEqualTo: 'pending')
                .get();

            for (final otherDoc in allPending.docs) {
              if (otherDoc.id == requestId) continue;
              final d = otherDoc.data();
              final reqType = (d['type'] as String? ?? '').toLowerCase();
              if (reqType != 'seat_change' && reqType != 'seatchange') continue;

              final sId = (d['studentId'] ?? '').toString();
              final sUid = (d['studentUserId'] ?? d['userId'] ?? '').toString();
              if (sId == targetStudentId || (studentUserId.isNotEmpty && sUid == studentUserId)) {
                await otherDoc.reference.update({
                  'status': 'superseded',
                  'processedAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                  'rejectionReason': 'Superseded by approval of seat change to Seat #$targetSeatLabel',
                });
              }
            }
          } catch (e) {
            if (kDebugMode) debugPrint('Error superseding other pending requests: $e');
          }
        }
      }

      final Map<String, dynamic> updateData = {
        'status': 'approved',
        'processedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (type == 'renewal' || type == 'plan_renewal') {
        final targetStudentId = (data['studentId'] ?? studentData['studentId'] ?? studentUserId).toString();
        final requestedPlanId = (data['requestedPlanId'] ?? data['planId'] ?? studentData['planId'] ?? '').toString();
        final requestedPlanName = (data['requestedPlanName'] ?? data['planName'] ?? 'Standard Plan').toString();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final paymentMethod = (data['paymentMethod'] ?? data['method'] ?? 'Cash').toString();

        DateTime? newStartDate;
        DateTime? newEndDate;

        if (data['cycleStartDate'] != null && data['cycleEndDate'] != null) {
          newStartDate = StudentModel.parseDateStatic(data['cycleStartDate']);
          newEndDate = StudentModel.parseDateStatic(data['cycleEndDate']);
        }

        if (targetStudentId.isNotEmpty) {
          final studentDocRef = _firestore
              .collection('libraries')
              .doc(libraryId)
              .collection('students')
              .doc(targetStudentId);
          final studentSnap = await studentDocRef.get();

          if (studentSnap.exists) {
            final sData = studentSnap.data()!;

            // Calculate start and end date using centralized calendar-month engine
            if (newStartDate == null || newEndDate == null) {
              if (requestedPlanId.isNotEmpty) {
                final planDoc = await _firestore
                    .collection('libraries')
                    .doc(libraryId)
                    .collection('plans')
                    .doc(requestedPlanId)
                    .get();
                if (planDoc.exists && planDoc.data() != null) {
                  final plan = PlanModel.fromJson({...planDoc.data()!, 'id': planDoc.id});
                  final student = StudentModel.fromJson({...sData, 'id': targetStudentId});
                  final renewalCalc = PlanCalculatorService.calculateRenewal(
                    student: student,
                    plan: plan,
                    chooseBridgeBundle: data['isBridgeBundle'] == true,
                  );
                  newStartDate = renewalCalc.startDate;
                  newEndDate = renewalCalc.endDate;
                }
              }

              // Fallback to calendar month-end alignment if plan document not found
              if (newStartDate == null || newEndDate == null) {
                final currentPlanEndDate = StudentModel.parseDateStatic(sData['planEndDate']);
                if (currentPlanEndDate != null && currentPlanEndDate.isAfter(DateTime.now())) {
                  newStartDate = currentPlanEndDate;
                } else {
                  newStartDate = DateTime.now();
                }
                newEndDate = DateTime(newStartDate.year, newStartDate.month + 1, 0, 23, 59, 59);
              }
            }

            // Create Payment and Receipt records
            String? paymentId;
            String? receiptId;
            if (amount > 0 && !isPaid) {
              final double clearedDue = (data['pendingDueAmount'] as num?)?.toDouble() ?? 0.0;
              final recDescription = clearedDue > 0
                  ? 'Plan Renewal ($requestedPlanName) + Cleared Past Due (₹${clearedDue.toStringAsFixed(0)})'
                  : 'Plan Renewal - $requestedPlanName';

              final payRef = _firestore.collection('libraries').doc(libraryId).collection('payments').doc();
              paymentId = payRef.id;
              await payRef.set({
                'id': paymentId,
                'studentId': targetStudentId,
                if (studentUserId.isNotEmpty) 'studentUserId': studentUserId,
                'studentName': data['studentName'] ?? sData['name'] ?? 'Student',
                'amount': amount,
                'paymentMethod': paymentMethod,
                'method': paymentMethod,
                'status': 'paid',
                'paymentDate': FieldValue.serverTimestamp(),
                'date': FieldValue.serverTimestamp(),
                'createdAt': FieldValue.serverTimestamp(),
                'notes': recDescription,
                'requestId': requestId,
              });

              final recRef = _firestore.collection('libraries').doc(libraryId).collection('receipts').doc();
              receiptId = recRef.id;
              final recNum = 'REC-${DateTime.now().year}-${recRef.id.substring(0, recRef.id.length >= 6 ? 6 : recRef.id.length).toUpperCase()}';
              await recRef.set({
                'id': recRef.id,
                'libraryId': libraryId,
                'receiptNumber': recNum,
                'paymentId': paymentId,
                'studentId': targetStudentId,
                if (studentUserId.isNotEmpty) 'studentUserId': studentUserId,
                'studentName': data['studentName'] ?? sData['name'] ?? 'Student',
                'amount': amount,
                'method': paymentMethod,
                'paymentMethod': paymentMethod,
                'status': 'active',
                'issuedAt': FieldValue.serverTimestamp(),
                'description': recDescription,
                'createdAt': FieldValue.serverTimestamp(),
              });
            }

            // Zero-Click Auto-Seat Allocation & Retention Engine
            final bool retainSeatRequested = data['retainSeat'] ?? true;
            final String? requestedDesk = (data['currentSeatId'] ??
                    data['requestedSeatId'] ??
                    data['seatId'] ??
                    sData['seatId'] ??
                    sData['previousSeatId'])
                ?.toString();

            String? assignedSeatId;
            String? assignedSectionId;

            if (retainSeatRequested && requestedDesk != null && requestedDesk.trim().isNotEmpty) {
              String? targetSecId = (data['sectionId'] ??
                      data['requestedSectionId'] ??
                      sData['sectionId'] ??
                      sData['previousSectionId'])
                  ?.toString();

              try {
                if (targetSecId == null || targetSecId.trim().isEmpty) {
                  final sectionsSnap = await _firestore
                      .collection('libraries')
                      .doc(libraryId)
                      .collection('sections')
                      .get();

                  for (final sec in sectionsSnap.docs) {
                    final seatSnap = await sec.reference.collection('seats').doc(requestedDesk).get();
                    if (seatSnap.exists) {
                      targetSecId = sec.id;
                      break;
                    }
                  }
                }

                if (targetSecId != null && targetSecId.isNotEmpty) {
                  final seatRef = _firestore
                      .collection('libraries')
                      .doc(libraryId)
                      .collection('sections')
                      .doc(targetSecId)
                      .collection('seats')
                      .doc(requestedDesk);

                  final seatDoc = await seatRef.get();
                  if (seatDoc.exists) {
                    final seatData = seatDoc.data() ?? {};
                    final occupant = (seatData['studentId'] ?? '').toString();
                    final seatStatus = (seatData['status'] ?? 'available').toString();
                    final resExpiresRaw = seatData['reservationExpiresAt'];
                    DateTime? resExpires;
                    if (resExpiresRaw is Timestamp) {
                      resExpires = resExpiresRaw.toDate();
                    } else if (resExpiresRaw is String) {
                      resExpires = DateTime.tryParse(resExpiresRaw);
                    }
                    final isExpiredReservation = seatStatus == 'reserved' &&
                        (resExpires == null || resExpires.isBefore(DateTime.now()));

                    if (occupant.isEmpty || occupant == targetStudentId || seatStatus == 'available' || isExpiredReservation) {
                      await _seatRepo.assignStudent(libraryId, targetSecId, requestedDesk, targetStudentId);
                      assignedSeatId = requestedDesk;
                      assignedSectionId = targetSecId;
                    }
                  }
                }
              } catch (seatErr) {
                if (kDebugMode) debugPrint('[StudentProvisioningService] Error auto-retaining seat during renewal: $seatErr');
              }
            }

            // Update student document to active status and new plan validity with restored seat
            final Map<String, dynamic> studentUpdates = {
              'membershipStatus': 'active',
              'status': 'active',
              'planStartDate': Timestamp.fromDate(newStartDate),
              'planEndDate': Timestamp.fromDate(newEndDate),
              'updatedAt': FieldValue.serverTimestamp(),
            };
            if (data['clearedDue'] == true || (data['pendingDueAmount'] as num?)?.toDouble() != null) {
              studentUpdates['pendingDueBalance'] = 0.0;
            }
            if (assignedSeatId != null) {
              studentUpdates['seatId'] = assignedSeatId;
              studentUpdates['sectionId'] = assignedSectionId;
              studentUpdates['previousSeatId'] = assignedSeatId;
              studentUpdates['previousSectionId'] = assignedSectionId;
            } else if (requestedDesk != null && requestedDesk.trim().isNotEmpty) {
              studentUpdates['previousSeatId'] = requestedDesk;
              if (sData['previousSectionId'] != null) {
                studentUpdates['previousSectionId'] = sData['previousSectionId'];
              }
            }
            if (requestedPlanId.isNotEmpty) {
              studentUpdates['planId'] = requestedPlanId;
            }
            if (requestedPlanName.isNotEmpty) {
              studentUpdates['planName'] = requestedPlanName;
            }
            await studentDocRef.update(studentUpdates);

            if (paymentId != null) {
              updateData['paymentId'] = paymentId;
              updateData['paymentStatus'] = 'paid';
            }
            if (receiptId != null) {
              updateData['receiptId'] = receiptId;
            }
            createdStudentId = targetStudentId;

            // Student Notification
            final studentName = data['studentName'] ?? sData['name'] ?? 'Student';
            AppNotificationService.sendNotification(
              libraryId: libraryId,
              title: 'Plan Renewal Approved! 🎉',
              body: 'Hello $studentName! Your renewal for $requestedPlanName has been approved. Your pass is now active!',
              type: 'renewal',
              targetRole: 'student',
              targetUserId: targetStudentId,
              actionRoute: '/student/id-card',
            ).ignore();
          }
        }
      }

      // 5. Update Request Status to 'approved' and link createdStudentId
      if (createdStudentId != null) {
        updateData['createdStudentId'] = createdStudentId;
      }
      await docRef.set(updateData, SetOptions(merge: true));

      // 5.5 Dispatch Student Notification for Admission Only
      if (type == 'registration' || type == 'newregistration') {
        final studentName = studentData['name'] ?? data['studentName'] ?? 'Student';
        final seatLabelStr = (data['requestedSeatLabel'] ?? studentData['requestedSeatLabel'] ?? requestedSeatId)?.toString();
        final seatNotice = seatLabelStr != null && !seatLabelStr.toLowerCase().contains('auto') ? ' (Desk #$seatLabelStr)' : '';
        final primaryTarget = (studentUserId.isNotEmpty) ? studentUserId : createdStudentId;
        AppNotificationService.sendNotification(
          libraryId: libraryId,
          title: 'Admission Approved! 🎉',
          body: isPaid
              ? 'Hello $studentName! Your admission is confirmed$seatNotice and your membership is active. Digital ID Pass unlocked!'
              : 'Hello $studentName! Your admission is approved$seatNotice. Complete your fee payment to activate your pass.',
          type: 'admission',
          targetRole: 'student',
          targetUserId: primaryTarget,
          actionRoute: '/student/id-card',
          metadata: {
            'studentId': createdStudentId,
            'studentUserId': studentUserId,
            'isPaid': isPaid,
          },
        ).ignore();
      }

      // 6. Audit Logging
      AuditLogger().log(
        action: AuditAction.approved,
        entityType: AuditEntity.request,
        libraryId: libraryId,
        entityId: requestId,
        entityName: studentData['name'] ?? data['studentName'] ?? 'Student',
        details: {
          'createdStudentId': createdStudentId,
          'type': type,
        },
      ).ignore();

      return createdStudentId;
    } catch (e) {
      if (kDebugMode) debugPrint('Error in approveAndProvisionRequest: $e');
      rethrow;
    }
  }

  /// Self-Healing Sync: Scans for any requests marked 'approved'
  /// whose student profile was not created yet, and automatically provisions them.
  static Future<int> healUnprovisionedApprovedRequests(
    String libraryId, {
    String? studentUserId,
  }) async {
    if (libraryId.isEmpty) return 0;
    int healedCount = 0;

    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('requests')
          .where('status', isEqualTo: 'approved');

      if (studentUserId != null && studentUserId.isNotEmpty) {
        query = query.where('studentId', isEqualTo: studentUserId);
      }

      final snap = await query.limit(20).get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final createdStudentId = data['createdStudentId'] as String?;
        final uid = (data['studentData']?['userId'] ?? data['studentId'] ?? '').toString();
        final email = (data['studentData']?['email'] ?? data['studentEmail'] ?? '').toString();

        bool needsProvisioning = false;
        if (createdStudentId == null || createdStudentId.isEmpty) {
          needsProvisioning = true;
        } else {
          // Verify if student doc actually exists
          final studentDoc = await _firestore
              .collection('libraries')
              .doc(libraryId)
              .collection('students')
              .doc(createdStudentId)
              .get();
          if (!studentDoc.exists) {
            needsProvisioning = true;
          } else {
            // Also heal govId photos if they were left blank
            final sData = studentDoc.data() ?? {};
            final existingGovIdFront = (sData['govIdImageUrl'] ?? '').toString();
            final reqGovIdFront = (data['studentData']?['govIdImageUrl'] ??
                    data['studentData']?['govIdFrontUrl'] ??
                    data['studentData']?['govIdImagePath'] ??
                    data['studentData']?['govIdDataUrl'] ??
                    data['govIdImageUrl'] ??
                    data['govIdFrontUrl'] ??
                    data['govIdImagePath'] ??
                    data['govIdDataUrl'] ??
                    '')
                .toString();
            final reqGovIdBack = (data['studentData']?['govIdBackImageUrl'] ??
                    data['studentData']?['govIdBackUrl'] ??
                    data['studentData']?['govIdBackImagePath'] ??
                    data['studentData']?['govIdBackDataUrl'] ??
                    data['govIdBackImageUrl'] ??
                    data['govIdBackUrl'] ??
                    data['govIdBackImagePath'] ??
                    data['govIdBackDataUrl'])
                ?.toString();

            if (existingGovIdFront.isEmpty && reqGovIdFront.isNotEmpty) {
              await studentDoc.reference.update({
                'govIdImageUrl': reqGovIdFront,
                if (reqGovIdBack != null && reqGovIdBack.isNotEmpty)
                  'govIdBackImageUrl': reqGovIdBack,
              });
            }
          }
        }

        // Also check if existing student can be found by UID or email
        if (needsProvisioning) {
          if (uid.isNotEmpty) {
            final existingSnap = await _firestore
                .collection('libraries')
                .doc(libraryId)
                .collection('students')
                .where('userId', isEqualTo: uid)
                .limit(1)
                .get();
            if (existingSnap.docs.isNotEmpty) {
              await doc.reference.update({'createdStudentId': existingSnap.docs.first.id});
              needsProvisioning = false;
            }
          }

          if (needsProvisioning && email.isNotEmpty) {
            final existingSnap = await _firestore
                .collection('libraries')
                .doc(libraryId)
                .collection('students')
                .where('email', isEqualTo: email)
                .limit(1)
                .get();
            if (existingSnap.docs.isNotEmpty) {
              await doc.reference.update({'createdStudentId': existingSnap.docs.first.id});
              needsProvisioning = false;
            }
          }
        }

        if (needsProvisioning) {
          await approveAndProvisionRequest(
            libraryId: libraryId,
            requestId: doc.id,
            preloadedData: data,
          );
          healedCount++;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error in healUnprovisionedApprovedRequests: $e');
    }

    return healedCount;
  }
}
