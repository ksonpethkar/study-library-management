import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/features/seats/presentation/providers/seat_providers.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/features/payments/presentation/screens/record_payment_screen.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/features/id_cards/presentation/screens/id_card_preview_screen.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/payment_model.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/models/seat_model.dart';
import 'package:study_library/models/section_model.dart';
import 'package:flutter/services.dart';
import 'package:study_library/core/security/encryption_service.dart';
import 'package:study_library/core/security/audit_logger.dart';
import 'package:study_library/core/utils/secure_screen_mixin.dart';

class StudentDetailScreen extends ConsumerStatefulWidget {
  final String studentId;

  const StudentDetailScreen({super.key, required this.studentId});

  @override
  ConsumerState<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends ConsumerState<StudentDetailScreen> with SecureScreenMixin {
  StudentModel? student;
  bool isLoading = true;
  bool _isGovIdVisible = false;
  String seatLabel = '';
  String sectionName = '';
  String planName = '';
  double planPrice = 0;

  @override
  void initState() {
    super.initState();
    _loadStudent();
  }

  Future<void> _loadStudent() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('students')
          .doc(widget.studentId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        final rawGovId = data['govIdNumber']?.toString() ?? '';
        final decryptedGovId = EncryptionService.safeDecryptGovId(rawGovId, libraryId);
        final s = StudentModel.fromJson({
          ...data,
          'id': doc.id,
          'govIdNumber': decryptedGovId,
        });
        
        // Load seat + section names
        String loadedSeatLabel = '';
        String loadedSectionName = '';
        if (s.seatId != null && s.sectionId != null) {
          final sectionDoc = await FirebaseFirestore.instance
              .collection('libraries').doc(libraryId)
              .collection('sections').doc(s.sectionId)
              .get();
          if (sectionDoc.exists) {
            loadedSectionName = sectionDoc.data()?['name'] ?? 'Unknown Section';
          }
          
          final seatDoc = await FirebaseFirestore.instance
              .collection('libraries').doc(libraryId)
              .collection('sections').doc(s.sectionId)
              .collection('seats').doc(s.seatId)
              .get();
          if (seatDoc.exists) {
            loadedSeatLabel = seatDoc.data()?['label'] ?? 'Unknown Seat';
          }
        }

        // Load plan name
        String loadedPlanName = '';
        double loadedPlanPrice = 0;
        if (s.planId != null) {
          final planDoc = await FirebaseFirestore.instance
              .collection('libraries').doc(libraryId)
              .collection('plans').doc(s.planId)
              .get();
          if (planDoc.exists) {
            loadedPlanName = planDoc.data()?['name'] ?? 'Unknown Plan';
            loadedPlanPrice = (planDoc.data()?['price'] ?? 0).toDouble();
          }
        }

        setState(() {
          student = s;
          seatLabel = loadedSeatLabel;
          sectionName = loadedSectionName;
          planName = loadedPlanName;
          planPrice = loadedPlanPrice;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading student: $e');
      setState(() => isLoading = false);
    }
  }

  Color _getStatusColor(MembershipStatus status) {
    switch (status) {
      case MembershipStatus.active:
        return Colors.green;
      case MembershipStatus.expired:
      case MembershipStatus.blocked:
        return Colors.red;
      case MembershipStatus.grace:
        return Colors.orange;
      case MembershipStatus.pending:
        return Colors.blue;
      case MembershipStatus.inactive:
      case MembershipStatus.archived:
        return Colors.grey;
    }
  }

  void _showAssignSeatSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          builder: (context, scrollController) {
            return Consumer(
              builder: (context, ref, child) {
                final sectionsAsync = ref.watch(sectionsProvider);
                return sectionsAsync.when(
                  data: (sections) {
                    if (sections.isEmpty) {
                      return const Center(child: Text('No sections available'));
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: sections.length,
                      itemBuilder: (context, index) {
                        final section = sections[index];
                        return _SectionItem(
                          section: section,
                          studentId: widget.studentId,
                          onSeatAssigned: () {
                            Navigator.pop(context);
                            _loadStudent(); // Reload student data
                          },
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showAssignPlanSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          builder: (context, scrollController) {
            return Consumer(
              builder: (context, ref, child) {
                final plansAsync = ref.watch(plansStreamProvider);
                return plansAsync.when(
                  data: (plans) {
                    final activePlans = plans.where((p) => p.isActive).toList();
                    if (activePlans.isEmpty) {
                      return const Center(child: Text('No active plans available'));
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: activePlans.length,
                      itemBuilder: (context, index) {
                        final plan = activePlans[index];
                        return ListTile(
                          title: Text(plan.name),
                          subtitle: Text('Duration: ${plan.duration} ${plan.durationUnit.name}'),
                          trailing: Text('₹${plan.price}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          onTap: () async {
                            final libraryId = ref.read(currentLibraryIdProvider);
                            if (libraryId == null) return;
                            
                            final now = DateTime.now();
                            DateTime endDate = now;
                            final durationInt = plan.duration.toInt();
                            if (plan.durationUnit == DurationUnit.days) {
                              endDate = now.add(Duration(days: durationInt));
                            } else if (plan.durationUnit == DurationUnit.months) {
                              endDate = DateTime(now.year, now.month + durationInt, now.day);
                            }
                            
                            await FirebaseFirestore.instance
                                .collection('libraries')
                                .doc(libraryId)
                                .collection('students')
                                .doc(widget.studentId)
                                .update({
                              'planId': plan.id,
                              'planStartDate': Timestamp.fromDate(now),
                              'planEndDate': Timestamp.fromDate(endDate),
                              'membershipStatus': MembershipStatus.active.name,
                            });
                            
                            AuditLogger().log(
                              action: AuditAction.updated,
                              entityType: AuditEntity.student,
                              entityId: widget.studentId,
                              details: {'planChanged': true, 'planId': plan.id},
                            ).ignore();

                            if (context.mounted) {
                              Navigator.pop(context);
                              _loadStudent(); // Reload student data
                            }
                          },
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _deleteStudent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: const Text('Are you sure you want to delete this student?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final libraryId = ref.read(currentLibraryIdProvider);
      if (libraryId != null) {
        await FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('students')
            .doc(widget.studentId)
            .update({
          'deletedAt': Timestamp.now(),
          'membershipStatus': MembershipStatus.archived.name,
        });
        if (mounted) {
          context.pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (student == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Student Not Found')),
        body: const Center(child: Text('The student could not be found.')),
      );
    }

    final s = student!;
    final libraryId = ref.read(currentLibraryIdProvider) ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/admin/students');
            }
          },
        ),
        title: const Text('Student Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.badge_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => IdCardPreviewScreen(
                    student: s,
                    seatLabel: seatLabel,
                    sectionName: sectionName,
                    planName: planName,
                  ),
                ),
              );
            },
            tooltip: 'Print / Share ID Card',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await context.push('/admin/students/${widget.studentId}/edit');
              _loadStudent(); // Reload after edit
            },
            tooltip: 'Edit Student',
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteStudent,
            tooltip: 'Delete Student',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (s.photoUrl.isNotEmpty) {
                      ImageService.showImageViewer(
                        context,
                        imageUrl: s.photoUrl,
                        title: s.name,
                      );
                    }
                  },
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        backgroundImage: ImageService.getImageProvider(s.photoUrl),
                        child: s.photoUrl.isEmpty
                            ? Text(
                                s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      if (s.photoUrl.isNotEmpty)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: const Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone_rounded, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(s.phone, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                      if (s.email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(s.email, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Chip(
                        label: Text(s.membershipStatus.name.toUpperCase()),
                        backgroundColor: _getStatusColor(s.membershipStatus).withValues(alpha: 0.15),
                        labelStyle: TextStyle(color: _getStatusColor(s.membershipStatus), fontWeight: FontWeight.bold, fontSize: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: s.membershipStatus == MembershipStatus.blocked
                      ? FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: Colors.green),
                          icon: const Icon(Icons.lock_open_rounded),
                          label: const Text('Unblock Student'),
                          onPressed: () async {
                            final repo = ref.read(studentRepositoryProvider);
                            await repo.unblockStudent(libraryId, s.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Student unblocked ✓'), backgroundColor: Colors.green),
                              );
                              _loadStudent();
                            }
                          },
                        )
                      : OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                          icon: const Icon(Icons.block_rounded),
                          label: const Text('Block Student'),
                          onPressed: () async {
                            String reason = '';
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) {
                                final ctrl = TextEditingController();
                                return AlertDialog(
                                  title: const Text('Block Student'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('Student will be locked out of the app. Seat stays assigned.'),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: ctrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Reason for blocking *',
                                          border: OutlineInputBorder(),
                                        ),
                                        maxLines: 2,
                                        onChanged: (v) => reason = v,
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    FilledButton(
                                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () {
                                        if (reason.trim().isEmpty) return;
                                        Navigator.pop(ctx, true);
                                      },
                                      child: const Text('Block'),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (confirmed != true || !context.mounted) return;
                            final repo = ref.read(studentRepositoryProvider);
                            await repo.blockStudent(libraryId, s.id, reason: reason.trim());
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Student blocked'), backgroundColor: Colors.orange),
                              );
                              _loadStudent();
                            }
                          },
                        ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Personal & Academic Details Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Profile Details', style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (s.fatherName.isNotEmpty)
                      _buildDetailRow(context, 'Father / Guardian', s.fatherName, Icons.family_restroom_rounded),
                    if (s.dob != null)
                      _buildDetailRow(context, 'Date of Birth', DateFormat('dd MMM yyyy').format(s.dob!), Icons.cake_outlined),
                    _buildDetailRow(context, 'Gender', s.gender.name.toUpperCase(), Icons.people_outline_rounded),
                    if (s.govIdNumber.isNotEmpty)
                      _buildGovIdRow(context, s.govIdType.name.toUpperCase(), s.govIdNumber),
                    if (s.college.isNotEmpty)
                      _buildDetailRow(context, 'College / Institute', s.college, Icons.school_outlined),
                    if (s.course.isNotEmpty)
                      _buildDetailRow(context, 'Course & Year', '${s.course} ${s.year.isNotEmpty ? "(${s.year})" : ""}', Icons.menu_book_outlined),
                    if (s.address.isNotEmpty)
                      _buildDetailRow(context, 'Address', '${s.address} ${s.pincode.isNotEmpty ? "- ${s.pincode}" : ""}', Icons.location_on_outlined),
                    if (s.emergencyContact.isNotEmpty)
                      _buildDetailRow(context, 'Emergency Contact', s.emergencyContact, Icons.phone_in_talk_outlined),
                    if (s.notes != null && s.notes!.isNotEmpty)
                      _buildDetailRow(context, 'Notes', s.notes!, Icons.note_alt_outlined),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Seat Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.event_seat_rounded, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Seat Info', style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (s.seatId != null && s.sectionId != null)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.chair, size: 32, color: Theme.of(context).colorScheme.primary),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  seatLabel.isNotEmpty ? 'Seat $seatLabel' : 'Seat Assigned',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  sectionName.isNotEmpty ? 'Section: $sectionName' : 'Section assigned',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[400]),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(onPressed: _showAssignSeatSheet, child: const Text('Change')),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Icon(Icons.chair_outlined, size: 40, color: Colors.grey[600]),
                          const SizedBox(width: 16),
                          const Expanded(child: Text('No seat assigned yet')),
                          FilledButton.icon(
                            onPressed: _showAssignSeatSheet,
                            icon: const Icon(Icons.add),
                            label: const Text('Assign Seat'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Plan Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.assignment_rounded, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Plan Info', style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (s.planId != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      planName.isNotEmpty ? planName : 'Plan Assigned',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    if (planPrice > 0)
                                      Text('₹${planPrice.toStringAsFixed(0)}',
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              OutlinedButton(onPressed: _showAssignPlanSheet, child: const Text('Change')),
                            ],
                          ),
                          if (s.planStartDate != null && s.planEndDate != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text('${DateFormat.yMMMd().format(s.planStartDate!)} → ${DateFormat.yMMMd().format(s.planEndDate!)}'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Builder(builder: (context) {
                              final daysLeft = s.planEndDate!.difference(DateTime.now()).inDays;
                              final color = daysLeft > 7 ? Colors.green : daysLeft > 0 ? Colors.orange : Colors.red;
                              final label = daysLeft > 0 ? '$daysLeft days remaining' : 'Expired ${-daysLeft} days ago';
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                              );
                            }),
                          ],
                        ],
                      )
                    else
                      Row(
                        children: [
                          Icon(Icons.assignment_outlined, size: 40, color: Colors.grey[600]),
                          const SizedBox(width: 16),
                          const Expanded(child: Text('No plan assigned yet')),
                          FilledButton.icon(
                            onPressed: _showAssignPlanSheet,
                            icon: const Icon(Icons.add),
                            label: const Text('Assign Plan'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Payment History Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.payments_rounded, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('Payment History', style: Theme.of(context).textTheme.titleLarge),
                          ],
                        ),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RecordPaymentScreen(
                                  studentId: widget.studentId,
                                  studentName: s.name,
                                  planPrice: planPrice,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Record Payment'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('libraries')
                          .doc(libraryId)
                          .collection('payments')
                          .where('studentId', isEqualTo: widget.studentId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Text('Error: ${snapshot.error}');
                        }
                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return const Text('No payments recorded.');
                        }
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: docs.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final data = docs[index].data() as Map<String, dynamic>;
                            final payment = PaymentModel.fromJson({...data, 'id': docs[index].id});
                            return ListTile(
                              title: Text('₹${payment.amount} - ${payment.method}'),
                              subtitle: Text(DateFormat.yMMMd().format(payment.date)),
                              trailing: Chip(label: Text(payment.status.name.toUpperCase())),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGovIdRow(BuildContext context, String type, String number) {
    String masked;
    final cleanDigits = number.replaceAll(RegExp(r'\D'), '');
    if (cleanDigits.length >= 4) {
      final last4 = cleanDigits.substring(cleanDigits.length - 4);
      masked = type.contains('AADHAAR') ? '•••• •••• $last4' : '••••••$last4';
    } else if (number.length > 4 && !number.contains('=')) {
      final last4 = number.substring(number.length - 4);
      masked = '•••• $last4';
    } else {
      masked = '•••• •••• ••••';
    }

    final displayVal = _isGovIdVisible ? number : masked;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.badge_outlined, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 130,
            child: Text(
              type,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              displayVal,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: _isGovIdVisible ? 0.5 : 1.5,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _isGovIdVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18,
              color: Colors.grey.shade700,
            ),
            tooltip: _isGovIdVisible ? 'Hide ID' : 'Show ID',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _isGovIdVisible = !_isGovIdVisible),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
            tooltip: 'Copy ID',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: number));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$type copied to clipboard!'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionItem extends ConsumerWidget {
  final SectionModel section;
  final String studentId;
  final VoidCallback onSeatAssigned;

  const _SectionItem({
    required this.section,
    required this.studentId,
    required this.onSeatAssigned,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seatsAsync = ref.watch(seatsProvider(section.id));

    return ExpansionTile(
      title: Text(section.name),
      children: [
        seatsAsync.when(
          data: (seats) {
            final availableSeats = seats.where((s) => s.status == SeatStatus.available).toList();
            if (availableSeats.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No available seats in this section.'),
              );
            }
            return Wrap(
              spacing: 8,
              children: availableSeats.map((seat) {
                return ActionChip(
                  label: Text(seat.label),
                  onPressed: () async {
                    final libraryId = ref.read(currentLibraryIdProvider);
                    if (libraryId == null) return;

                    // Update Student
                    await FirebaseFirestore.instance
                        .collection('libraries')
                        .doc(libraryId)
                        .collection('students')
                        .doc(studentId)
                        .update({
                      'seatId': seat.id,
                      'sectionId': section.id,
                    });

                    // Update Seat
                    await FirebaseFirestore.instance
                        .collection('libraries')
                        .doc(libraryId)
                        .collection('sections')
                        .doc(section.id)
                        .collection('seats')
                        .doc(seat.id)
                        .update({
                      'status': SeatStatus.occupied.name,
                      'studentId': studentId,
                    });

                    AuditLogger().log(
                      action: AuditAction.updated,
                      entityType: AuditEntity.student,
                      entityId: studentId,
                      details: {'seatAssigned': true, 'seatId': seat.id},
                    ).ignore();

                    onSeatAssigned();
                  },
                );
              }).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ),
          error: (err, stack) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error loading seats: $err'),
          ),
        ),
      ],
    );
  }
}
