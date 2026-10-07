import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/security/audit_logger.dart';
import 'package:study_library/features/seats/presentation/providers/seat_providers.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/services/message_template_service.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/utils/sequence_counter.dart';

class RequestDetailScreen extends ConsumerStatefulWidget {
  final String requestId;
  const RequestDetailScreen({super.key, required this.requestId});

  @override
  ConsumerState<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  bool _isLoading = true;
  bool _isProcessing = false;
  Map<String, dynamic>? _requestData;
  String? _newCreatedStudentId;

  @override
  void initState() {
    super.initState();
    _loadRequest();
  }

  Future<void> _loadRequest() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('requests')
          .doc(widget.requestId)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _requestData = doc.data();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approveRequest() async {
    final String libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty || _requestData == null) return;

    setState(() => _isProcessing = true);

    try {
      final data = _requestData!;
      final studentData = (data['studentData'] as Map<String, dynamic>?) ?? {};
      final type = data['type'] as String? ?? 'registration';
      DateTime? finalPlanEndDate;

      if (type == 'registration') {
        // Calculate plan dates if planId is present
        final planId = studentData['planId'] ?? data['planId'] as String?;
        DateTime? planStartDate;
        DateTime? planEndDate;
        MembershipStatus status = MembershipStatus.active;

        if (planId != null && planId.isNotEmpty) {
          final plansAsync = ref.read(plansStreamProvider);
          final plans = plansAsync.value ?? [];
          final plan = plans.where((p) => p.id == planId).firstOrNull;
          if (plan != null) {
            planStartDate = DateTime.now();
            if (plan.durationUnit.name == 'months') {
              planEndDate = DateTime(planStartDate.year, planStartDate.month + plan.duration, planStartDate.day);
            } else {
              planEndDate = planStartDate.add(Duration(days: plan.duration));
            }
          }
        }
        
        finalPlanEndDate = planEndDate;

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

        final libDoc = await FirebaseFirestore.instance.collection('libraries').doc(libraryId).get();
        final prefix = (libDoc.data()?['membershipPrefix'] as String?)?.toUpperCase() ?? 'CC';
        final membershipNumber = await SequenceCounter.nextMembershipNumber(libraryId, prefix: prefix);

        final newStudent = StudentModel(
          id: '',
          membershipNumber: membershipNumber,
          name: studentData['name'] ?? data['studentName'] ?? 'Student',
          fatherName: studentData['fatherName'] ?? '',
          phone: studentData['phone'] ?? data['studentPhone'] ?? '',
          email: studentData['email'] ?? '',
          gender: gender,
          address: studentData['address'] ?? '',
          pincode: studentData['pincode'] ?? '',
          govIdType: govIdType,                    // fixed: was hardcoded to aadhaar
          govIdNumber: studentData['govIdNumber'] ?? '',
          govIdImageUrl: '',
          photoUrl: studentData['photoUrl'] ?? '',
          college: studentData['college'] ?? '',
          course: studentData['course'] ?? '',
          year: studentData['year'] ?? '',
          emergencyContact: studentData['emergencyContact'] ?? '',
          dob: StudentModel.parseDateStatic(studentData['dob']), // fixed: was missing
          bloodGroup: studentData['bloodGroup'] as String?,      // fixed: was missing
          rollNumber: studentData['rollNumber'] as String?,      // fixed: was missing
          seatId: studentData['seatId'] ?? data['requestedSeatId'],
          sectionId: studentData['sectionId'] ?? data['requestedSectionId'],
          planId: planId,
          planStartDate: planStartDate,
          planEndDate: planEndDate,
          membershipStatus: status,
          customFields: {},
          notes: 'Registered via In-App Request (${widget.requestId})',
          userId: studentData['userId'] ?? data['studentId'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final repo = ref.read(studentRepositoryProvider);
        final newId = await repo.createStudent(libraryId, newStudent);
        _newCreatedStudentId = newId;

        // If seat was assigned, mark seat occupied and release any previously occupied seat
        if (newStudent.seatId != null && newStudent.sectionId != null) {
          await ref.read(seatRepositoryProvider).assignStudent(
                libraryId,
                newStudent.sectionId!,
                newStudent.seatId!,
                newId,
              );
        }

        // Link student's Firebase Auth account to role: 'student' and this libraryId
        // This breaks the login loop and redirects the student directly to StudentHome
        final studentUserId = studentData['userId'] ?? data['studentId'];
        if (studentUserId != null && studentUserId.toString().isNotEmpty) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(studentUserId.toString())
                .set({
              'role': 'student',
              'libraryId': libraryId,
              'studentId': newId,
              'email': newStudent.email,
              'displayName': newStudent.name,
              'phone': newStudent.phone,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } catch (e) {
            debugPrint('Failed to link student user account: $e');
          }
        }
      }

      // Mark request approved
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('requests')
          .doc(widget.requestId)
          .update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'createdStudentId': _newCreatedStudentId,
      });

      AuditLogger().log(
        action: AuditAction.approved,
        entityType: AuditEntity.request,
        entityId: widget.requestId,
        details: {'libraryId': libraryId},
      ).ignore();

      ref.invalidate(studentsStreamProvider);
      await _loadRequest();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request approved successfully! Student profile created.'), backgroundColor: Colors.green),
        );
        final studentName = _requestData?['studentName'] ?? (_requestData?['studentData'] as Map<String, dynamic>?)?['name'] ?? 'Student';
        final studentPhone = ((_requestData?['studentData'] as Map<String, dynamic>?)?['phone'] ?? _requestData?['studentPhone'] ?? '').toString();
        final studentUserId = ((_requestData?['studentData'] as Map<String, dynamic>?)?['userId'] ?? _requestData?['studentId'] ?? '').toString();
        if (_newCreatedStudentId != null) {
          _promptPaymentAfterApproval(
            libraryId,
            _newCreatedStudentId!,
            studentUserId,
            studentName.toString(),
            studentPhone,
            planEndDate: finalPlanEndDate,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectRequest() async {
    final reasonController = TextEditingController();
    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please specify a reason for rejecting this request:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for rejection',
                hintText: 'e.g. Seats currently full, blurry ID photo...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject Application'),
          ),
        ],
      ),
    );

    if (shouldReject != true) return;

    final String libraryId = ref.read(currentLibraryIdProvider) ?? '';
    if (libraryId.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('requests')
          .doc(widget.requestId)
          .update({
        'status': 'rejected',
        'rejectionReason': reasonController.text.trim().isNotEmpty
            ? reasonController.text.trim()
            : 'Application could not be approved at this time.',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      AuditLogger().log(
        action: AuditAction.rejected,
        entityType: AuditEntity.request,
        entityId: widget.requestId,
        details: {'libraryId': libraryId},
      ).ignore();

      await _loadRequest();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request rejected.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Request Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_requestData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Request Details')),
        body: const Center(child: Text('Request not found or has been deleted.')),
      );
    }

    final data = _requestData!;
    final studentData = (data['studentData'] as Map<String, dynamic>?) ?? {};
    final status = (data['status'] as String? ?? 'pending').toLowerCase();
    final isPending = status == 'pending';
    final photoUrl = studentData['photoUrl'] as String? ?? '';
    final studentName = studentData['name'] ?? data['studentName'] ?? 'Student';
    final studentPhone = studentData['phone'] ?? data['studentPhone'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/admin/requests');
            }
          },
        ),
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (photoUrl.isNotEmpty) {
                              ImageService.showImageViewer(
                                context,
                                imageUrl: photoUrl,
                                title: studentName,
                              );
                            }
                          },
                          child: CircleAvatar(
                            radius: 48,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                            child: photoUrl.isEmpty
                                ? const Icon(Icons.person, size: 48)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(studentName, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(studentPhone, style: TextStyle(color: Colors.grey.shade600)),
                        const SizedBox(height: 12),
                        Chip(
                          label: Text(status.toUpperCase()),
                          backgroundColor: status == 'approved'
                              ? Colors.green.shade100
                              : status == 'rejected'
                                  ? Colors.red.shade100
                                  : Colors.orange.shade100,
                          labelStyle: TextStyle(
                            color: status == 'approved'
                                ? Colors.green.shade900
                                : status == 'rejected'
                                    ? Colors.red.shade900
                                    : Colors.orange.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submitted Details Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Application Information', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const Divider(height: 20),
                          _buildRow('Request Type', (data['type'] ?? 'Registration').toString().toUpperCase()),
                          if (studentData['fatherName'] != null)
                            _buildRow("Father's Name", studentData['fatherName']),
                          if (studentData['gender'] != null)
                            _buildRow('Gender', studentData['gender'].toString().toUpperCase()),
                          if (studentData['email'] != null && studentData['email'].isNotEmpty)
                            _buildRow('Email', studentData['email']),
                          if (studentData['govIdNumber'] != null && studentData['govIdNumber'].isNotEmpty)
                            _buildRow('Govt ID', studentData['govIdNumber']),
                          if (studentData['college'] != null && studentData['college'].isNotEmpty)
                            _buildRow('College', studentData['college']),
                          if (studentData['course'] != null && studentData['course'].isNotEmpty)
                            _buildRow('Course', studentData['course']),
                          if (studentData['address'] != null && studentData['address'].isNotEmpty)
                            _buildRow('Address', studentData['address']),
                          if (data['rejectionReason'] != null)
                            _buildRow('Rejection Reason', data['rejectionReason'], color: Colors.red),
                        ],
                      ),
                    ),
                  ),

                  if (data['createdStudentId'] != null) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.go('/admin/students/${data['createdStudentId']}'),
                      icon: const Icon(Icons.badge_rounded),
                      label: const Text('View Created Student Profile'),
                    ),
                  ],

                  if (isPending) ...[
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _rejectRequest,
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Reject Request'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _approveRequest,
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Approve & Add'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color),
            ),
          ),
        ],
      ),
    );
  }

  void _promptPaymentAfterApproval(String libraryId, String studentId, String studentUserId, String studentName, String studentPhone, {DateTime? planEndDate}) {
    if (!mounted) return;
    final amountController = TextEditingController();
    String paymentMethod = 'Cash';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          icon: const Icon(Icons.celebration_rounded, color: Colors.green, size: 36),
          title: const Text('Registration Approved! 🎉'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$studentName has been approved. Record their payment to generate a receipt.'),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: paymentMethod,
                decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                  DropdownMenuItem(value: 'Card', child: Text('Card')),
                  DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                ],
                onChanged: (v) => setDs(() => paymentMethod = v ?? 'Cash'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (mounted && studentPhone.isNotEmpty) _offerWhatsAppWelcome(studentId, studentName, studentPhone, 0, 'None', planEndDate: planEndDate);
              },
              child: const Text('Skip Payment'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim()) ?? 0;
                Navigator.of(ctx).pop();
                if (amount > 0) {
                  await _recordPaymentAndReceipt(libraryId, studentId, studentUserId, studentName, studentPhone, amount, paymentMethod, planEndDate: planEndDate);
                }
                if (mounted && studentPhone.isNotEmpty) _offerWhatsAppWelcome(studentId, studentName, studentPhone, amount, paymentMethod, planEndDate: planEndDate);
              },
              child: const Text('Confirm & Generate Receipt'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _recordPaymentAndReceipt(String libraryId, String studentId, String studentUserId, String studentName, String studentPhone, double amount, String paymentMethod, {DateTime? planEndDate}) async {
    try {
      final paymentRef = FirebaseFirestore.instance
          .collection('libraries').doc(libraryId)
          .collection('students').doc(studentId)
          .collection('payments').doc();
      await paymentRef.set({
        'id': paymentRef.id,
        'studentId': studentId,
        'amount': amount,
        'method': paymentMethod,        // fixed: was 'paymentMethod' (PaymentModel uses 'method')
        'status': 'paid',               // fixed: was 'completed' (not a valid PaymentStatus enum)
        'date': FieldValue.serverTimestamp(), // fixed: was 'paidAt' (PaymentModel uses 'date')
        'createdAt': FieldValue.serverTimestamp(),
        'recordedBy': FirebaseAuth.instance.currentUser?.email ?? 'admin',
      });
      final receiptNum = 'REC${DateTime.now().year}${(DateTime.now().millisecondsSinceEpoch % 100000).toString().padLeft(5,'0')}';
      await FirebaseFirestore.instance.collection('libraries').doc(libraryId).collection('receipts').add({
        'receiptNumber': receiptNum,
        'studentId': studentId,
        'studentUserId': studentUserId,
        'studentName': studentName,
        'studentPhone': studentPhone,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'status': 'active',
        'validFrom': FieldValue.serverTimestamp(),
        if (planEndDate != null) 'validTo': Timestamp.fromDate(planEndDate),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'libraryId': libraryId,
        'planId': '',
        'customFields': {},
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Payment recorded & Receipt $receiptNum generated ✓'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment failed: $e'), backgroundColor: Colors.red));
    }
  }

  void _offerWhatsAppWelcome(String studentId, String studentName, String studentPhone, double amount, String paymentMethod, {DateTime? planEndDate}) {
    if (!mounted) return;

    final library = ref.read(currentLibraryProvider).value;
    final rawTemplate = library?.whatsappWelcomeTemplate ?? '';
    final template = rawTemplate.isNotEmpty ? rawTemplate : MessageTemplateService.defaultWelcomeTemplate;
    
    // Attempt to get more student info from requestData or providers
    final data = _requestData ?? {};
    final studentData = (data['studentData'] as Map<String, dynamic>?) ?? {};
    final seatId = studentData['seatId'] ?? data['requestedSeatId'];
    final planId = studentData['planId'] ?? data['planId'];
    
    String planName = '';
    if (planId != null) {
      final plans = ref.read(plansStreamProvider).value ?? [];
      planName = plans.where((p) => p.id == planId).firstOrNull?.name ?? '';
    }

    final messageStr = MessageTemplateService.substitute(
      template,
      studentName: studentName,
      planName: planName,
      expiryDate: planEndDate != null ? DateFormat('dd MMM yyyy').format(planEndDate) : 'N/A',
      membershipId: studentId,
      seatLabel: seatId ?? 'To be assigned',
      libraryName: library?.name ?? '',
      amount: amount > 0 ? amount.toStringAsFixed(0) : '0',
      paymentMethod: paymentMethod,
      phone: studentPhone,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send WhatsApp Welcome?'),
        content: Text('Send a welcome message to $studentName via WhatsApp?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Skip')),
          FilledButton.icon(
            icon: const Icon(Icons.chat_rounded),
            label: const Text('Send WhatsApp'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
            onPressed: () {
              Navigator.of(ctx).pop();
              final cleanPhone = studentPhone.replaceAll(RegExp(r'[^0-9]'), '');
              final fullPhone = cleanPhone.startsWith('91') ? cleanPhone : '91$cleanPhone';
              final message = Uri.encodeComponent(messageStr);
              launchUrl(Uri.parse('https://wa.me/$fullPhone?text=$message'), mode: LaunchMode.externalApplication);
            },
          ),
        ],
      ),
    );
  }
}
