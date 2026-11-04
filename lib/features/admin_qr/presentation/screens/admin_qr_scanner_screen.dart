import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/core/utils/error_formatter.dart';

class AdminQrScannerScreen extends ConsumerStatefulWidget {
  const AdminQrScannerScreen({super.key});

  @override
  ConsumerState<AdminQrScannerScreen> createState() => _AdminQrScannerScreenState();
}

class _AdminQrScannerScreenState extends ConsumerState<AdminQrScannerScreen> {
  late final MobileScannerController _controller;
  bool _isProcessing = false;
  bool _scanned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleTorch() async {
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💡 Hardware flashlight requires Android native APK. Web browsers do not permit camera torch access.'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    try {
      await _controller.toggleTorch();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppErrorFormatter.toUserFriendly(e, actionContext: 'camera')),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _switchCamera() async {
    try {
      if (kIsWeb) {
        await _controller.stop();
        await Future.delayed(const Duration(milliseconds: 250));
      }
      await _controller.switchCamera();
      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 250));
        await _controller.start();
      }
    } catch (e) {
      await _restartCamera();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppErrorFormatter.toUserFriendly(e, actionContext: 'camera')),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _restartCamera() async {
    try {
      await _controller.stop();
      await Future.delayed(const Duration(milliseconds: 300));
      await _controller.start();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'camera');
      }
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_scanned || _isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;
    HapticFeedback.mediumImpact();
    setState(() { _isProcessing = true; _scanned = true; });
    await _verifyStudent(barcode!.rawValue!);
  }

  Future<void> _verifyStudent(String qrValue) async {
    String studentId = '';
    String libraryId = '';

    // Handle signed/standard format prefixes:
    // Pattern 1: COZY:{studentId}:{libraryId}
    // Pattern 2: STUDENT-{studentId}||{libraryId}
    // Pattern 3: {studentId}||{libraryId}
    if (qrValue.startsWith('{') && qrValue.endsWith('}')) {
      try {
        final map = jsonDecode(qrValue) as Map<String, dynamic>;
        studentId = (map['id'] ?? map['studentId'] ?? '').toString().trim();
        libraryId = (map['lib'] ?? map['libraryId'] ?? '').toString().trim();
      } catch (_) {}
    } else if (qrValue.startsWith('COZY:')) {
      final parts = qrValue.substring(5).split(':');
      if (parts.isNotEmpty) studentId = parts[0].trim();
      if (parts.length > 1) libraryId = parts[1].trim();
    } else if (qrValue.startsWith('STUDENT-')) {
      final clean = qrValue.substring(8);
      final parts = clean.split('||');
      if (parts.isNotEmpty) studentId = parts[0].trim();
      if (parts.length > 1) libraryId = parts[1].trim();
    } else {
      final parts = qrValue.split('||');
      studentId = parts.isNotEmpty ? parts[0].trim() : qrValue.trim();
      if (parts.length > 1 && parts[1].isNotEmpty) libraryId = parts[1].trim();
    }

    if (libraryId.isEmpty) {
      libraryId = ref.read(currentLibraryIdProvider) ?? '';
    }

    if (studentId.isEmpty || libraryId.isEmpty) {
      _showError('Invalid QR code format');
      return;
    }

    final currentLibId = ref.read(currentLibraryIdProvider) ?? '';
    if (currentLibId.isNotEmpty && libraryId != currentLibId) {
      _showError('Security Alert: This pass belongs to another library!');
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('libraries').doc(libraryId)
          .collection('students').doc(studentId).get();

      if (!doc.exists || doc.data() == null) {
        _showError('Student not found in this library');
        return;
      }

      final student = StudentModel.fromJson({...doc.data()!, 'id': doc.id});
      if (mounted) _showVerification(student);
    } catch (e) {
      _showError('Verification failed: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() { _scanned = false; _isProcessing = false; });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
    );
  }

  void _showVerification(StudentModel student) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final now = DateTime.now();

    final effectiveStatus = student.effectiveMembershipStatus;
    final isActive = effectiveStatus == MembershipStatus.active;
    final isGrace = effectiveStatus == MembershipStatus.grace;
    final isExpired = effectiveStatus == MembershipStatus.expired || effectiveStatus == MembershipStatus.blocked;

    final Color statusColor = isActive ? Colors.green : (isGrace ? Colors.orange : Colors.red);
    final String statusText = isActive ? '✅ ACTIVE MEMBER' : (isGrace ? '⚠️ GRACE PERIOD' : '❌ EXPIRED PASS');
    final IconData statusIcon = isActive ? Icons.verified_rounded : (isGrace ? Icons.warning_rounded : Icons.cancel_rounded);

    final endDate = student.planEndDate;
    final daysLeft = endDate != null ? endDate.difference(now).inDays : 0;
    final df = DateFormat('dd MMM yyyy');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        builder: (ctx, scroll) => SingleChildScrollView(
          controller: scroll,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Handle bar
                Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),

                // Status banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(statusIcon, color: statusColor, size: 24),
                    const SizedBox(width: 10),
                    Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 17)),
                  ]),
                ),
                const SizedBox(height: 20),

                // Photo + Name
                CircleAvatar(
                  radius: 44,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage: student.photoUrl.isNotEmpty ? ImageService.getImageProvider(student.photoUrl) : null,
                  child: student.photoUrl.isEmpty
                      ? Text(student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(height: 12),
                Text(student.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                if (student.membershipNumber != null && student.membershipNumber!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('🏷 ${student.membershipNumber}',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                  ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                _InfoRow(label: 'Phone', value: student.phone, icon: Icons.phone_rounded),
                _InfoRow(label: 'Seat', value: student.seatId ?? 'Not assigned', icon: Icons.event_seat_rounded),
                if (endDate != null) ...[
                  _InfoRow(label: 'Valid Until', value: df.format(endDate), icon: Icons.calendar_today_rounded),
                  _InfoRow(
                    label: daysLeft >= 0 ? 'Days Remaining' : 'Days Overdue',
                    value: daysLeft >= 0 ? '$daysLeft days' : '${(-daysLeft)} days',
                    icon: daysLeft >= 0 ? Icons.timer_outlined : Icons.timer_off_outlined,
                    valueColor: daysLeft < 0 ? Colors.red : (daysLeft < 7 ? Colors.orange : Colors.green),
                  ),
                ],
                _InfoRow(
                  label: 'Status',
                  value: effectiveStatus.name.toUpperCase(),
                  icon: Icons.badge_rounded,
                  valueColor: statusColor,
                ),

                const SizedBox(height: 24),
                if (isExpired || isGrace) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.payment_rounded),
                      label: const Text('Record Renewal Payment'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        context.push(Routes.adminRecordPayment.replaceFirst(':studentId', student.id));
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Scan Another Student'),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      setState(() => _scanned = false);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openManualSearchDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final studentsAsync = ref.watch(studentsStreamProvider);
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              maxChildSize: 0.92,
              builder: (context, scrollController) {
                return Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 16),
                  child: Column(
                    children: [
                      Container(
                        width: 40, height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.person_search_rounded, size: 24),
                          const SizedBox(width: 8),
                          Text('Manual Student Lookup', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search by Name, Roll #, or Phone...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => setModalState(() => query = ''),
                                )
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (val) => setModalState(() => query = val.trim().toLowerCase()),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: studentsAsync.when(
                          data: (students) {
                            final filtered = students.where((s) {
                              if (query.isEmpty) return true;
                              final name = s.name.toLowerCase();
                              final phone = s.phone.toLowerCase();
                              final roll = (s.membershipNumber ?? '').toLowerCase();
                              return name.contains(query) || phone.contains(query) || roll.contains(query);
                            }).toList();

                            if (filtered.isEmpty) {
                              return Center(
                                child: Text('No students matching "$query"', style: const TextStyle(color: Colors.grey)),
                              );
                            }

                            return ListView.separated(
                              controller: scrollController,
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, idx) {
                                final s = filtered[idx];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: s.photoUrl.isNotEmpty ? ImageService.getImageProvider(s.photoUrl) : null,
                                    child: s.photoUrl.isEmpty ? Text(s.name.isNotEmpty ? s.name[0] : 'S') : null,
                                  ),
                                  title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('${s.membershipNumber != null ? '#${s.membershipNumber} • ' : ''}${s.phone}'),
                                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    _showVerification(s);
                                  },
                                );
                              },
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                AppErrorFormatter.toUserFriendly(e, actionContext: 'student'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.adminHome),
        ),
        title: const Text('Scan Student ID'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Lookup Student Manually',
            onPressed: _openManualSearchDialog,
          ),
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (_, state, _) => Icon(state.torchState == TorchState.on ? Icons.flash_on_rounded : Icons.flash_off_rounded),
            ),
            onPressed: _toggleTorch,
            tooltip: 'Torch',
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded),
            onPressed: _switchCamera,
            tooltip: 'Switch Camera',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.videocam_off_rounded, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 14),
                        const Text(
                          'Camera Access Notice',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppErrorFormatter.toUserFriendly(
                            error.errorDetails?.message ?? error.errorCode.name,
                            actionContext: 'camera',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: _restartCamera,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Restart Camera'),
                            ),
                            FilledButton.icon(
                              onPressed: _openManualSearchDialog,
                              icon: const Icon(Icons.search_rounded, size: 18),
                              label: const Text('Manual Lookup'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // Scanning frame overlay
          Center(
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.primary, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Instructions (safe area anchored)
          Positioned(
            bottom: 32, left: 24, right: 24,
            child: SafeArea(
              bottom: true,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    _isProcessing ? 'Verifying student...' : 'Point camera at student\'s ID card QR code',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  const _InfoRow({required this.label, required this.value, required this.icon, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(icon, size: 18, color: theme.colorScheme.outline),
        const SizedBox(width: 10),
        Text('$label: ', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
        Expanded(child: Text(value,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: valueColor),
          overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}
