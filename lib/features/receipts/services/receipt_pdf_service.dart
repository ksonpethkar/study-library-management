import 'dart:typed_data';
import 'package:study_library/services/pdf_service.dart';
import 'package:study_library/models/receipt_model.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/models/library_model.dart';

class ReceiptPdfService {
  /// Generates the official fee receipt PDF matching the modern Stripe / Zoho SaaS architecture
  static Future<Uint8List> generateReceipt({
    required String receiptNumber,
    required String libraryName,
    required String libraryAddress,
    required String libraryPhone,
    String? logoUrl,
    required String studentName,
    required String studentPhone,
    required String planName,
    required double amount,
    required String paymentMethod,
    required DateTime paymentDate,
    required DateTime? validFrom,
    required DateTime? validTo,
    double? securityDeposit,
    String? notes,
  }) async {
    final effectiveValidFrom = validFrom ?? paymentDate;
    final effectiveValidTo = validTo ?? DateTime(paymentDate.year, paymentDate.month + 1, 0, 23, 59, 59);

    final receipt = ReceiptModel(
      id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
      libraryId: 'lib_default',
      receiptNumber: receiptNumber,
      studentId: 'std_default',
      planId: 'plan_default',
      amount: amount,
      securityDeposit: securityDeposit,
      paymentMethod: paymentMethod,
      validFrom: effectiveValidFrom,
      validTo: effectiveValidTo,
      status: ReceiptStatus.active,
      customFields: notes != null ? {'notes': notes} : const {},
      totalFee: amount,
      paidAmount: amount,
      remainingDue: 0.0,
      createdAt: paymentDate,
      updatedAt: paymentDate,
    );

    final student = StudentModel(
      id: 'std_default',
      name: studentName,
      fatherName: '',
      phone: studentPhone,
      email: '',
      gender: Gender.other,
      address: '',
      pincode: '',
      govIdType: GovIdType.other,
      govIdNumber: '',
      govIdImageUrl: '',
      photoUrl: '',
      college: '',
      course: '',
      year: '',
      emergencyContact: '',
      membershipStatus: MembershipStatus.active,
      membershipNumber: receiptNumber.contains('-') ? receiptNumber.split('-').last : null,
      customFields: const {},
    );

    final plan = PlanModel(
      id: 'plan_default',
      libraryId: 'lib_default',
      name: planName,
      price: amount,
      duration: 1,
      durationUnit: DurationUnit.months,
      description: 'Silent Reading Hall • Reserved Desk • High-Speed Wi-Fi • Power Backup',
      gracePeriodDays: 0,
      isActive: true,
      isFeatured: false,
      displayOrder: 0,
    );

    final library = LibraryModel(
      id: 'lib_default',
      name: libraryName,
      address: libraryAddress,
      logoUrl: logoUrl ?? '',
      contact: libraryPhone,
      ownerId: 'owner_default',
      accentColor: 0xFF881337,
      welcomeMessage: 'Your Peaceful Study Haven',
      operatingHours: '6 AM - 11 PM',
      socialLinks: const {},
      rulesText: 'Strict silence must be maintained.',
      helplineNumber: libraryPhone,
      adminPhotoUrl: '',
      waitingListMode: WaitingListMode.waitingList,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return PdfService().generateReceiptPdf(
      receipt,
      student,
      plan,
      library,
      null,
    );
  }
}
