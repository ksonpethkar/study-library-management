import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/features/id_cards/presentation/screens/id_card_preview_screen.dart';
import 'package:study_library/features/settings/presentation/screens/id_card_customizer_screen.dart';
import 'package:study_library/models/id_card_template_model.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/services/whatsapp_service.dart';
import 'package:study_library/core/utils/secure_screen_mixin.dart';

class MyIdCardScreen extends ConsumerStatefulWidget {
  const MyIdCardScreen({super.key});

  @override
  ConsumerState<MyIdCardScreen> createState() => _MyIdCardScreenState();
}

class _MyIdCardScreenState extends ConsumerState<MyIdCardScreen> with SecureScreenMixin {
  String? _seatLabel;
  String? _sectionName;

  @override
  void initState() {
    super.initState();
    _loadSeatInfo();
  }

  Future<void> _loadSeatInfo() async {
    final student = ref.read(currentStudentProvider).value;
    final libraryId = ref.read(currentLibraryIdProvider);

    if (student == null || libraryId == null || student.seatId == null || student.sectionId == null) {
      return;
    }

    try {
      final seatDoc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('sections')
          .doc(student.sectionId)
          .collection('seats')
          .doc(student.seatId)
          .get();

      final secDoc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('sections')
          .doc(student.sectionId)
          .get();

      if (mounted) {
        setState(() {
          _seatLabel = seatDoc.data()?['label'] ?? student.seatId;
          _sectionName = secDoc.data()?['name'] ?? '';
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final studentAsync = ref.watch(currentStudentProvider);
    final libraryAsync = ref.watch(currentLibraryProvider);
    final plansAsync = ref.watch(plansStreamProvider);
    final templateAsync = ref.watch(idCardTemplateProvider);
    final settings = templateAsync.value ?? const IdCardTemplateSettings();
    final dateFormat = DateFormat('dd MMM yyyy');

    final library = libraryAsync.value;
    final libraryName = library?.name ?? 'Cozy Corner Library';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Digital ID Card'),
        centerTitle: true,
      ),
      body: studentAsync.when(
        data: (student) {
          if (student == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.badge_outlined, size: 72, color: theme.colorScheme.outline),
                    const SizedBox(height: 16),
                    Text(
                      'No Active ID Card',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You do not have an active membership registered with this account.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => context.push(Routes.studentRegister),
                      child: const Text('Register for Admission'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Match plan
          final plans = plansAsync.value ?? [];
          final plan = plans.where((p) => p.id == student.planId).firstOrNull;
          final planName = plan?.name ?? 'Standard Membership';

          final seatText = _seatLabel ?? (student.seatId ?? 'Unassigned');
          final secText = _sectionName != null && _sectionName!.isNotEmpty ? ' ($_sectionName)' : '';

          final hasPhoto = student.photoUrl.isNotEmpty;
          final primaryColor = theme.colorScheme.primary;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Modern Wallet-Style Card Widget
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Card Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    libraryName.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'STUDENT IDENTITY CARD',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                student.membershipStatus.name.toUpperCase(),
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Card Content
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Photo
                                GestureDetector(
                                  onTap: hasPhoto
                                      ? () => ImageService.showImageViewer(
                                            context,
                                            imageUrl: student.photoUrl,
                                            title: student.name,
                                          )
                                      : null,
                                  child: Container(
                                    width: 80,
                                    height: 96,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: primaryColor, width: 2),
                                      image: hasPhoto
                                          ? DecorationImage(
                                              image: NetworkImage(student.photoUrl),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: !hasPhoto
                                        ? Center(
                                            child: Text(
                                              student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                                              style: TextStyle(
                                                fontSize: 36,
                                                fontWeight: FontWeight.bold,
                                                color: primaryColor,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Student Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        student.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (student.membershipNumber != null && student.membershipNumber!.isNotEmpty)
                                        Text(
                                          'ID: ${student.membershipNumber}',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.primary),
                                        ),
                                      Text(
                                        'Member ID: ${student.id.length > 8 ? student.id.substring(0, 8).toUpperCase() : student.id.toUpperCase()}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      _buildCardRow(Icons.phone_rounded, student.phone),
                                      if (settings.showSeat)
                                        FutureBuilder<DocumentSnapshot>(
                                          future: student.sectionId != null && student.sectionId!.isNotEmpty && library?.id != null
                                              ? FirebaseFirestore.instance
                                                  .collection('libraries').doc(library!.id)
                                                  .collection('sections').doc(student.sectionId!)
                                                  .get()
                                              : Future.value(null as DocumentSnapshot?),
                                          builder: (context, snap) {
                                            String? sectionType;
                                            if (snap.hasData && snap.data != null && snap.data!.exists) {
                                              sectionType = (snap.data!.data() as Map<String, dynamic>?)?['sectionType'] as String?;
                                            }
                                            final badge = sectionType != null && sectionType != 'normal'
                                                ? _sectionTypeBadge(sectionType)
                                                : null;
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.event_seat_rounded, size: 14, color: Colors.grey.shade600),
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                    child: Text(
                                                      '$seatText$secText',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                                                    ),
                                                  ),
                                                  ?badge,
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      if (settings.showPlan)
                                        _buildCardRow(Icons.card_membership_rounded, planName),
                                      FutureBuilder<DocumentSnapshot>(
                                        future: library?.id != null
                                            ? FirebaseFirestore.instance
                                                .collection('libraries').doc(library!.id)
                                                .collection('settings').doc('form_config').get()
                                            : null,
                                        builder: (context, snap) {
                                          if (!snap.hasData || snap.data == null || !snap.data!.exists) {
                                            return const SizedBox.shrink();
                                          }
                                          final data = snap.data!.data() as Map<String, dynamic>?;
                                          final rawFields = data?['fields'] as List<dynamic>? ?? [];
                                          final idFields = rawFields
                                              .whereType<Map>()
                                              .map((f) => Map<String, dynamic>.from(f))
                                              .where((f) =>
                                                  !(f['builtin'] as bool? ?? false) &&
                                                  (f['showOnIdCard'] as bool? ?? false) &&
                                                  (f['visible'] as bool? ?? true))
                                              .toList();
                                          if (idFields.isEmpty) return const SizedBox.shrink();

                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              for (final field in idFields) ...[
                                                if (((student.customFields[field['id'] as String? ?? ''])?.toString() ?? '').isNotEmpty)
                                                  _buildCardRow(
                                                    Icons.info_outline_rounded,
                                                    '${field['label'] ?? field['id']}: ${student.customFields[field['id']]}',
                                                  ),
                                              ],
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const Divider(height: 32),

                            // Validity & Verification QR Code
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'VALID TILL',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      student.planEndDate != null
                                          ? dateFormat.format(student.planEndDate!)
                                          : 'No expiry date set',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                    if (settings.showHelpline) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Helpline: ${library?.contact ?? "N/A"}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ],
                                ),
                                if (settings.showQrCode)
                                  Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(10),
                                        color: Colors.white,
                                      ),
                                      child: QrImageView(
                                        data: '${student.id}||${library?.id ?? ''}',
                                        version: QrVersions.auto,
                                        size: 72,
                                        eyeStyle: const QrEyeStyle(
                                          eyeShape: QrEyeShape.square,
                                          color: Color(0xFF1E1B4B),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'SCAN TO VERIFY',
                                      style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Card Footer Address
                      if (settings.showAddress)
                        Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(19)),
                        ),
                        child: Text(
                          library?.address ?? 'Cozy Corner Study Library',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => IdCardPreviewScreen(
                          student: student,
                          seatLabel: _seatLabel,
                          sectionName: _sectionName,
                          planName: planName,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.print_rounded),
                  label: const Text('Print / Download Official PDF Card'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final whatsapp = ref.read(whatsappServiceProvider);
                    final message = 'Hello Admin, here is my digital ID Card verification for ${student.name} (Seat: $seatText).';
                    if (library?.contact != null && library!.contact.isNotEmpty) {
                      await whatsapp.sendMessage(library.contact, message);
                    }
                  },
                  icon: const Icon(Icons.share_rounded, color: Color(0xFF25D366)),
                  label: const Text('Share with Library Admin (WhatsApp)'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading ID Card: $err')),
      ),
    );
  }

  static Widget _sectionTypeBadge(String type) {
    final (label, color) = switch (type) {
      'window' => ('🪟 Window', Colors.blue.shade100),
      'ac' => ('❄️ AC Zone', Colors.cyan.shade100),
      'premium' => ('🌟 Premium', Colors.amber.shade100),
      _ => ('Normal', Colors.grey.shade200),
    };
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }

  static Widget _buildCardRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }
}
