import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:study_library/core/security/audit_logger.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:study_library/core/utils/sequence_counter.dart';
import 'package:study_library/features/receipts/data/repositories/receipt_repository.dart';
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
  static final ReceiptRepository _receiptRepo = ReceiptRepository();

  /// Centralized logic to approve any student request and create/update
  /// the corresponding student in libraries/{libraryId}/students,
  /// assign the requested seat, and link users/{uid}.
  static Future<String?> approveAndProvisionRequest({
    required String libraryId,
    required String requestId,
    Map<String, dynamic>? preloadedData,
    bool allowSharedGovId = false,
    bool allowSharedPhone = false,
    bool mergeExistingPhone = true,
    bool overrideSeatCollision = false,
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
      final studentData = (data['studentData'] as Map?)?.cast<String, dynamic>() ?? {};
      final studentUserId = (studentData['userId'] ?? data['studentId'] ?? '').toString();
      final rawStudentEmail = (studentData['email'] ?? data['studentEmail'] ?? data['email'] ?? '').toString().trim();
      final studentEmail = rawStudentEmail.toLowerCase();
      final requestedSeatId = (studentData['seatId'] ?? data['requestedSeatId'])?.toString();
      final requestedSectionId = (studentData['sectionId'] ?? data['requestedSectionId'])?.toString();
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
          var queryByEmail = await _firestore
              .collection('libraries')
              .doc(libraryId)
              .collection('students')
              .where('email', isEqualTo: studentEmail)
              .limit(1)
              .get();
          if (queryByEmail.docs.isEmpty && rawStudentEmail != studentEmail) {
            queryByEmail = await _firestore
                .collection('libraries')
                .doc(libraryId)
                .collection('students')
                .where('email', isEqualTo: rawStudentEmail)
                .limit(1)
                .get();
          }
          if (queryByEmail.docs.isNotEmpty) {
            existingStudent = StudentModel.fromJson({
              ...queryByEmail.docs.first.data(),
              'id': queryByEmail.docs.first.id,
            });
            createdStudentId = existingStudent.id;
          }
        }

        final cleanPhone = (studentData['phone'] ?? data['studentPhone'] ?? '').toString().trim();
        if (existingStudent == null && cleanPhone.isNotEmpty && !allowSharedPhone && mergeExistingPhone) {
          final queryByPhone = await _firestore
              .collection('libraries')
              .doc(libraryId)
              .collection('students')
              .where('phone', isEqualTo: cleanPhone)
              .limit(1)
              .get();
          if (queryByPhone.docs.isNotEmpty) {
            existingStudent = StudentModel.fromJson({
              ...queryByPhone.docs.first.data(),
              'id': queryByPhone.docs.first.id,
            });
            createdStudentId = existingStudent.id;
          }
        }

        // 2. Calculate Plan Expiry Dates if plan is selected
        final planId = (studentData['planId'] ?? data['planId'])?.toString();
        DateTime? planStartDate = StudentModel.parseDateStatic(
            studentData['planStartDate'] ?? data['planStartDate'] ?? studentData['admissionDate'] ?? data['admissionDate']);
        DateTime? planEndDate = StudentModel.parseDateStatic(studentData['planEndDate'] ?? data['planEndDate']);
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
              planStartDate ??= DateTime.now();
              if (planEndDate == null) {
                final smartCalc = PlanCalculatorService.calculateSmartPlan(
                  plan: plan,
                  fromDate: planStartDate,
                );
                planEndDate = smartCalc.endDate;
              }
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
            clearRemindedStages: isPaid,
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
            targetExamName: (studentData['targetExamName'] ?? studentData['prep'])?.toString(),
            seatId: requestedSeatId,
            sectionId: requestedSectionId,
            planId: planId,
            admissionDate: StudentModel.parseDateStatic(studentData['admissionDate'] ?? data['admissionDate'] ?? studentData['joiningDate'] ?? data['joiningDate']) ?? planStartDate ?? DateTime.now(),
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

          createdStudentId = await _studentRepo.createStudent(
            libraryId,
            newStudent,
            allowSharedGovId: allowSharedGovId,
            allowSharedPhone: allowSharedPhone,
          );
        }

        // 3. Assign Seat if specified (never silently swallow conflicts!)
        if (requestedSeatId != null &&
            requestedSeatId.isNotEmpty &&
            requestedSectionId != null &&
            requestedSectionId.isNotEmpty &&
            !requestedSeatId.toLowerCase().contains('auto')) {
          try {
            await _seatRepo.assignStudent(
              libraryId,
              requestedSectionId,
              requestedSeatId,
              createdStudentId,
              studentUserId: studentUserId,
              overrideSoftLock: overrideSeatCollision || studentUserId.isNotEmpty,
            );
          } catch (e) {
            if (kDebugMode) debugPrint('Failed to assign seat during provisioning: $e');
            if (!overrideSeatCollision) {
              // Roll back request status & seat on student if collision blocks assignment
              rethrow;
            }
            // Only when overrideSeatCollision explicitly skips seat check, clear ghost seat
            try {
              await _firestore
                  .collection('libraries')
                  .doc(libraryId)
                  .collection('students')
                  .doc(createdStudentId)
                  .update({
                'seatId': null,
                'sectionId': null,
                'notes': 'Admission approved, but requested desk ($requestedSeatId) was unavailable. Pending manual desk allocation.',
                'updatedAt': FieldValue.serverTimestamp(),
              });
            } catch (cleanupErr) {
              if (kDebugMode) debugPrint('Failed to rollback ghost seat on student: $cleanupErr');
            }
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
        final targetSeatId = (data['targetSeatId'] ?? data['seatId'] ?? studentData['targetSeatId'])?.toString();
        final targetSectionId = (data['targetSectionId'] ?? data['sectionId'] ?? studentData['targetSectionId'])?.toString();
        final currentSeatId = (data['currentSeatId'] ?? studentData['currentSeatId'])?.toString();
        final currentSectionId = (data['currentSectionId'] ?? studentData['currentSectionId'])?.toString();

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
              await _seatRepo.assignStudent(
                libraryId,
                targetSectionId,
                targetSeatId,
                targetStudentId,
                studentUserId: studentUserId,
                overrideSoftLock: true,
              );
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
          final formattedDesk = SeatHelper.formatDeskLabel(rawLabel: targetSeatLabel?.toString());
          AppNotificationService.sendNotification(
            libraryId: libraryId,
            title: 'Seat Change Approved! 🪑',
            body: 'Hello $studentName! Your seat change request has been approved. You are now assigned to $formattedDesk.',
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
                  'rejectionReason': 'Superseded by approval of seat change to $formattedDesk',
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

            // Create Payment and Receipt records ONLY if a positive fee was actually collected
            String? paymentId;
            String? receiptId;
            String? recNum;
            double remainingDue = 0.0;
            final bool skipPayment = data['skipPayment'] == true;
            final double collectedPaidAmount = skipPayment
                ? 0.0
                : ((data['paidAmount'] as num?)?.toDouble() ??
                    (data['amount'] as num?)?.toDouble() ??
                    amount);

            if (collectedPaidAmount > 0 && !isPaid) {
              final double clearedDue = (data['pendingDueAmount'] as num?)?.toDouble() ?? 0.0;
              final double paidAmount = collectedPaidAmount;
              final double totalFee = (data['totalFee'] as num?)?.toDouble() ?? amount;
              remainingDue = (data['remainingDue'] as num?)?.toDouble() ??
                  ((totalFee - paidAmount) > 0 ? (totalFee - paidAmount) : 0.0);
              final String? refNumber = (data['referenceNumber'] ?? data['transactionId'])?.toString();

              final recDescription = clearedDue > 0
                  ? 'Plan Renewal ($requestedPlanName) + Cleared Past Due (₹${clearedDue.toStringAsFixed(0)})'
                  : 'Plan Renewal - $requestedPlanName';

              // Load library GST settings once for renewal receipts
              Map<String, dynamic> libMeta = {};
              try {
                final lDoc = await _firestore.collection('libraries').doc(libraryId).get();
                libMeta = lDoc.data() ?? {};
              } catch (_) {}
              final gst = ReceiptRepository.calculateGstBreakdown(
                amount: paidAmount,
                isGstBilling: libMeta['enableGstBilling'] == true,
                gstRate: (libMeta['gstRate'] as num?)?.toDouble() ?? 18.0,
                sacCode: (libMeta['sacCode'] as String?)?.isNotEmpty == true ? libMeta['sacCode'].toString() : '999293',
                gstin: (libMeta['gstin'] ?? '').toString(),
              );

              recNum = await _receiptRepo.getNextReceiptNumber(libraryId);
              final recRef = _firestore.collection('libraries').doc(libraryId).collection('receipts').doc();
              receiptId = recRef.id;

              final payRef = _firestore.collection('libraries').doc(libraryId).collection('payments').doc();
              paymentId = payRef.id;

              final batch = _firestore.batch();
              batch.set(payRef, {
                'id': paymentId,
                'studentId': targetStudentId,
                if (studentUserId.isNotEmpty) 'studentUserId': studentUserId,
                'studentName': data['studentName'] ?? sData['name'] ?? 'Student',
                'amount': paidAmount,
                'totalFee': totalFee,
                'paidAmount': paidAmount,
                'remainingDue': remainingDue,
                'paymentMethod': paymentMethod,
                'method': paymentMethod,
                'status': 'paid',
                'receiptId': receiptId,
                'receiptNumber': recNum,
                if (refNumber != null && refNumber.isNotEmpty) 'referenceNumber': refNumber,
                if (refNumber != null && refNumber.isNotEmpty) 'transactionId': refNumber,
                'paymentDate': FieldValue.serverTimestamp(),
                'date': FieldValue.serverTimestamp(),
                'createdAt': FieldValue.serverTimestamp(),
                'notes': recDescription,
                'requestId': requestId,
                'aggregateSyncedByClient': true,
              });

              batch.set(recRef, {
                'id': recRef.id,
                'libraryId': libraryId,
                'receiptNumber': recNum,
                'paymentId': paymentId,
                'studentId': targetStudentId,
                if (studentUserId.isNotEmpty) 'studentUserId': studentUserId,
                'studentName': data['studentName'] ?? sData['name'] ?? 'Student',
                'amount': paidAmount,
                'totalFee': totalFee,
                'paidAmount': paidAmount,
                'remainingDue': remainingDue,
                if (refNumber != null && refNumber.isNotEmpty) 'referenceNumber': refNumber,
                if (refNumber != null && refNumber.isNotEmpty) 'transactionId': refNumber,
                'method': paymentMethod,
                'paymentMethod': paymentMethod,
                'status': 'active',
                'issuedAt': FieldValue.serverTimestamp(),
                'description': recDescription,
                'validFrom': Timestamp.fromDate(newStartDate),
                'validTo': Timestamp.fromDate(newEndDate),
                'planId': requestedPlanId.isNotEmpty ? requestedPlanId : (sData['planId'] ?? 'plan_renewal'),
                if (gst.isGstInvoice) ...{
                  'isGstInvoice': true,
                  if (gst.gstin.isNotEmpty) 'gstin': gst.gstin,
                  'sacCode': gst.sacCode,
                  'gstRate': gst.gstRate,
                  'taxableAmount': gst.taxableAmount,
                  'cgstAmount': gst.cgstAmount,
                  'sgstAmount': gst.sgstAmount,
                },
                'customFields': {
                  'planName': requestedPlanName,
                  'isRenewal': true,
                  'requestId': requestId,
                  if (refNumber != null && refNumber.isNotEmpty) 'referenceNumber': refNumber,
                  if (gst.isGstInvoice) ...{
                    'isGstInvoice': true,
                    'gstin': gst.gstin,
                    'sacCode': gst.sacCode,
                    'gstRate': gst.gstRate,
                    'taxableAmount': gst.taxableAmount,
                    'cgstAmount': gst.cgstAmount,
                    'sgstAmount': gst.sgstAmount,
                  },
                },
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });

              ReceiptRepository.addRevenueAggregateToBatch(
                batch,
                _firestore,
                libraryId,
                amountDelta: paidAmount,
                paymentsDelta: 1,
                referenceDate: DateTime.now(),
              );
              await batch.commit();
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
                      await _seatRepo.assignStudent(
                        libraryId,
                        targetSecId,
                        requestedDesk,
                        targetStudentId,
                        studentUserId: studentUserId,
                        overrideSoftLock: true,
                      );
                      assignedSeatId = requestedDesk;
                      assignedSectionId = targetSecId;
                    }
                  }
                }
              } catch (seatErr) {
                if (kDebugMode) debugPrint('[StudentProvisioningService] Error auto-retaining seat during renewal: $seatErr');
              }
            }

            // Update student document ONLY to active when fee is genuinely paid/settled
            final bool isRenewalFeeSettled = isPaid || collectedPaidAmount > 0;
            final Map<String, dynamic> studentUpdates = {
              'membershipStatus': isRenewalFeeSettled ? 'active' : 'inactive',
              'status': isRenewalFeeSettled ? 'active' : 'inactive',
              if (isRenewalFeeSettled) 'planStartDate': Timestamp.fromDate(newStartDate),
              if (isRenewalFeeSettled) 'planEndDate': Timestamp.fromDate(newEndDate),
              if (isRenewalFeeSettled) 'remindedStages': <String>[],
              if (!isRenewalFeeSettled) 'notes': 'Renewal Approved — Pending Fee Payment at Counter',
              'updatedAt': FieldValue.serverTimestamp(),
            };
            if (data['clearedDue'] == true || (data['pendingDueAmount'] as num?)?.toDouble() != null) {
              studentUpdates['pendingDueBalance'] = 0.0;
            } else if (remainingDue > 0) {
              studentUpdates['pendingDueBalance'] = remainingDue;
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
            if (recNum != null) {
              updateData['receiptNumber'] = recNum;
            }
            createdStudentId = targetStudentId;

            // Student Notification — strictly reflect fee settlement status
            final studentName = data['studentName'] ?? sData['name'] ?? 'Student';
            AppNotificationService.sendNotification(
              libraryId: libraryId,
              title: isRenewalFeeSettled
                  ? 'Plan Renewal Approved! 🎉'
                  : 'Renewal Approved — Payment Pending ⏳',
              body: isRenewalFeeSettled
                  ? 'Hello $studentName! Your renewal for $requestedPlanName has been approved. Your pass is now active!'
                  : 'Hello $studentName! Your renewal request for $requestedPlanName is approved. Please pay your renewal fee at the counter to activate your pass.',
              type: 'renewal',
              targetRole: 'student',
              targetUserId: targetStudentId,
              actionRoute: isRenewalFeeSettled ? '/student/id-card' : '/student/membership',
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
        final seatNotice = seatLabelStr != null && !seatLabelStr.toLowerCase().contains('auto') ? ' (${SeatHelper.formatDeskLabel(rawLabel: seatLabelStr)})' : '';
        final primaryTarget = (studentUserId.isNotEmpty) ? studentUserId : createdStudentId;
        AppNotificationService.sendNotification(
          libraryId: libraryId,
          notificationId: 'admission_approved_$requestId',
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
