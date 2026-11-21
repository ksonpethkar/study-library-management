import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:study_library/core/utils/error_formatter.dart';
import 'package:study_library/core/utils/file_download_helper.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:study_library/features/receipts/presentation/screens/receipt_preview_screen.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/models/plan_model.dart';
import 'package:study_library/models/receipt_model.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/services/pdf_service.dart';

/// Unified, interactive action sheet for receipts across Admin and Student portals.
/// Solves the issue where "Download" and "Share" behaved identically on Web.
class ReceiptActionSheet extends StatelessWidget {
  final ReceiptModel receipt;
  final StudentModel? student;
  final PlanModel? plan;
  final LibraryModel? library;
  final bool isStudent;

  const ReceiptActionSheet({
    super.key,
    required this.receipt,
    this.student,
    this.plan,
    this.library,
    this.isStudent = false,
  });

  static Future<void> show(
    BuildContext context, {
    required ReceiptModel receipt,
    StudentModel? student,
    PlanModel? plan,
    LibraryModel? library,
    bool isStudent = false,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReceiptActionSheet(
        receipt: receipt,
        student: student,
        plan: plan,
        library: library,
        isStudent: isStudent,
      ),
    );
  }

  String get _receiptUrl {
    final id = receipt.id.trim();
    if (id.isEmpty) return '';
    return 'https://study-lib-mgmt-2026.web.app/app/admin/receipts/$id';
  }

  String _buildFormattedShareText() {
    final df = DateFormat('dd MMM yyyy');
    final sName = student?.name.isNotEmpty == true ? student!.name : 'Student';
    final lName = library?.name.isNotEmpty == true ? library!.name : 'The Cozy Corner Study Centre';
    final pName = plan?.name.isNotEmpty == true ? plan!.name : 'Monthly Study Plan';
    final seat = (student?.seatId != null && student!.seatId!.isNotEmpty)
        ? SeatHelper.formatSeatLabel(seatId: student!.seatId)
        : 'Assigned Desk';
    final validStr = '${df.format(receipt.validFrom)} to ${df.format(receipt.validTo)}';

    return '🏛️ *$lName — Official Fee Receipt*\n\n'
        '📄 *Receipt No:* ${receipt.receiptNumber}\n'
        '👤 *Student Name:* $sName\n'
        '🪑 *Desk:* $seat\n'
        '📋 *Plan:* $pName\n'
        '💰 *Amount Paid:* ₹${receipt.amount.toStringAsFixed(0)}\n'
        '💳 *Mode:* ${receipt.paymentMethod}\n'
        '📅 *Validity:* $validStr\n\n'
        'Verify receipt online:\n$_receiptUrl';
  }

  Future<void> _shareOnWhatsApp(BuildContext context) async {
    HapticFeedback.selectionClick();
    final message = _buildFormattedShareText();
    final encoded = Uri.encodeComponent(message);

    Uri uri;
    if (!isStudent && student?.phone != null && student!.phone.trim().isNotEmpty) {
      final cleanPhone = student!.phone.replaceAll(RegExp(r'\D'), '');
      final fullPhone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
      uri = Uri.parse('https://wa.me/$fullPhone?text=$encoded');
    } else {
      uri = Uri.parse('https://wa.me/?text=$encoded');
    }

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not launch WhatsApp'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('WhatsApp error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _copyReceiptLink(BuildContext context) async {
    HapticFeedback.selectionClick();
    final url = _receiptUrl;
    if (url.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt link copied to clipboard! Share it in WhatsApp or Email. 📋'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _downloadPdf(BuildContext context) async {
    Navigator.of(context).pop();
    final filename = 'Receipt_${receipt.receiptNumber}.pdf';

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text('Generating $filename...'),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      final pdfBytes = await PdfService().generateReceiptPdf(
        receipt,
        student ??
            StudentModel(
              id: receipt.studentId,
              name: 'Student',
              fatherName: '',
              phone: '',
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
              customFields: const {},
            ),
        plan ??
            PlanModel(
              id: receipt.planId,
              libraryId: receipt.libraryId,
              name: 'Study Membership',
              price: receipt.amount,
              duration: 1,
              durationUnit: DurationUnit.months,
              description: '',
              gracePeriodDays: 0,
              isActive: true,
              isFeatured: false,
              displayOrder: 0,
            ),
        library ??
            LibraryModel(
              id: receipt.libraryId,
              name: 'The Cozy Corner Study Centre',
              address: '',
              logoUrl: '',
              contact: '',
              ownerId: '',
              accentColor: 0xFF10B981,
              welcomeMessage: '',
              operatingHours: '',
              socialLinks: const {},
              rulesText: '',
              helplineNumber: '',
              adminPhotoUrl: '',
              waitingListMode: WaitingListMode.waitingList,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
        null,
      );

      await FileDownloadHelper.downloadFile(
        bytes: pdfBytes,
        fileName: filename,
        mimeType: 'application/pdf',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved $filename successfully! ✅'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'receipt');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = DateFormat('dd MMM yyyy');

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF059669), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              receipt.receiptNumber,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace'),
                            ),
                            Text(
                              '₹${receipt.amount.toStringAsFixed(0)} • Issued ${df.format(receipt.createdAt ?? DateTime.now())}',
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Option 1: WhatsApp Share (1-Tap direct action)
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: const Color(0xFF25D366).withValues(alpha: 0.12),
                    leading: const Icon(Icons.chat_rounded, color: Color(0xFF16A34A)),
                    title: Text(
                      isStudent ? 'Share via WhatsApp' : 'Dispatch Receipt to Student on WhatsApp',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF15803D)),
                    ),
                    subtitle: Text(
                      isStudent
                          ? 'Send formatted receipt details to parents or contacts'
                          : 'Sends 1-tap message to ${student?.phone ?? "student"} with online receipt link',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF166534)),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _shareOnWhatsApp(context);
                    },
                  ),
                  const SizedBox(height: 10),

                  // Option 2: Full PDF Interactive Preview
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: theme.colorScheme.surfaceContainerLow,
                    leading: Icon(Icons.preview_rounded, color: theme.colorScheme.primary),
                    title: const Text('View Full Receipt Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    subtitle: const Text('Inspect watermark, seal, signature, and tax breakdown', style: TextStyle(fontSize: 11.5)),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                          builder: (_) => ReceiptPreviewScreen(
                            receiptId: receipt.id,
                            preloadedReceipt: receipt,
                            preloadedStudent: student,
                            preloadedPlan: plan,
                            isStudent: isStudent,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // Option 3: Download PDF file
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: theme.colorScheme.surfaceContainerLow,
                    leading: const Icon(Icons.download_rounded, color: Color(0xFF0284C7)),
                    title: const Text('Download PDF File', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    subtitle: const Text('Save official printable PDF to device Downloads folder', style: TextStyle(fontSize: 11.5)),
                    onTap: () => _downloadPdf(context),
                  ),
                  const SizedBox(height: 10),

                  // Option 4: Copy Online Receipt Link
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: theme.colorScheme.surfaceContainerLow,
                    leading: const Icon(Icons.link_rounded, color: Color(0xFF8B5CF6)),
                    title: const Text('Copy Online Receipt Link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    subtitle: const Text('Copy verification web link to clipboard', style: TextStyle(fontSize: 11.5)),
                    onTap: () => _copyReceiptLink(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
