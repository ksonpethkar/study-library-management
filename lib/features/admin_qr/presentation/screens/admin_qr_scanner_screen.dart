import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/services/image_service.dart';

class AdminQrScannerScreen extends ConsumerStatefulWidget {
  const AdminQrScannerScreen({super.key});

  @override
  ConsumerState<AdminQrScannerScreen> createState() => _AdminQrScannerScreenState();
}

class _AdminQrScannerScreenState extends ConsumerState<AdminQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_scanned || _isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;
    setState(() { _isProcessing = true; _scanned = true; });
    await _verifyStudent(barcode!.rawValue!);
  }

  Future<void> _verifyStudent(String qrValue) async {
    final parts = qrValue.split('||');
    final studentId = parts.isNotEmpty ? parts[0].trim() : qrValue.trim();
    final libraryId = (parts.length > 1 && parts[1].isNotEmpty)
        ? parts[1].trim()
        : (ref.read(currentLibraryIdProvider) ?? '');

    if (studentId.isEmpty || libraryId.isEmpty) {
      _showError('Invalid QR code format');
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

    final isActive = student.membershipStatus == MembershipStatus.active;
    final isGrace = student.membershipStatus == MembershipStatus.grace;

    final Color statusColor = isActive ? Colors.green : (isGrace ? Colors.orange : Colors.red);
    final String statusText = isActive ? '✅ ACTIVE MEMBER' : (isGrace ? '⚠️ GRACE PERIOD' : '❌ EXPIRED / INACTIVE');
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
                  value: student.membershipStatus.name.toUpperCase(),
                  icon: Icons.badge_rounded,
                  valueColor: statusColor,
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Student ID'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (_, state, _) => Icon(state.torchState == TorchState.on ? Icons.flash_on_rounded : Icons.flash_off_rounded),
            ),
            onPressed: () => _controller.toggleTorch(),
            tooltip: 'Torch',
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded),
            onPressed: () => _controller.switchCamera(),
            tooltip: 'Switch Camera',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
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
          // Instructions
          Positioned(
            bottom: 48, left: 24, right: 24,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isProcessing ? 'Verifying student...' : 'Point camera at student\'s ID card QR code',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
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
