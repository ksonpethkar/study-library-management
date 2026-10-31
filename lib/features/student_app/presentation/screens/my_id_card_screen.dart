import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/models/id_card_template_model.dart';
import 'package:study_library/features/plans/presentation/providers/plan_providers.dart';
import 'package:study_library/features/students/presentation/providers/student_providers.dart';
import 'package:study_library/features/settings/presentation/screens/id_card_customizer_screen.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/services/whatsapp_service.dart';
import 'package:study_library/core/utils/secure_screen_mixin.dart';
import 'package:study_library/core/utils/seat_helper.dart';
import 'package:study_library/core/error/error_handler.dart';

class MyIdCardScreen extends ConsumerStatefulWidget {
  const MyIdCardScreen({super.key});

  @override
  ConsumerState<MyIdCardScreen> createState() => _MyIdCardScreenState();
}

class _MyIdCardScreenState extends ConsumerState<MyIdCardScreen>
    with SingleTickerProviderStateMixin, SecureScreenMixin {
  String? _seatLabel;
  String? _sectionName;

  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _showBack = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    )..addListener(() {
        if (_flipAnimation.value >= 0.5 && !_showBack) {
          setState(() => _showBack = true);
        } else if (_flipAnimation.value < 0.5 && _showBack) {
          setState(() => _showBack = false);
        }
      });
    _loadSeatInfo();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    HapticFeedback.lightImpact();
    if (_flipController.isCompleted) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
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

  List<Color> _getThemeGradient(String themeId, Color libraryAccent) {
    if (themeId.startsWith('#')) {
      try {
        final c = Color(int.parse('FF${themeId.replaceAll('#', '')}', radix: 16));
        return [c, Color.lerp(c, Colors.black, 0.45) ?? Colors.black];
      } catch (_) {}
    }
    switch (themeId) {
      case 'royalNavy':
        return const [Color(0xFF1E3A8A), Color(0xFF0F172A)];
      case 'emeraldAcademic':
        return const [Color(0xFF065F46), Color(0xFF022C22)];
      case 'darkSlate':
        return const [Color(0xFF1E293B), Color(0xFF0F172A)];
      case 'amberClassic':
        return const [Color(0xFF78350F), Color(0xFF451A03)];
      case 'customBrand':
        return [libraryAccent, Color.lerp(libraryAccent, Colors.black, 0.45) ?? Colors.black];
      case 'crimsonExecutive':
      default:
        return const [Color(0xFF881337), Color(0xFF4C0519)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final studentAsync = ref.watch(currentStudentProvider);
    final libraryAsync = ref.watch(currentLibraryProvider);
    final plansAsync = ref.watch(plansStreamProvider);
    final templateAsync = ref.watch(idCardTemplateProvider);
    final dateFormat = DateFormat('dd MMM yyyy');

    final library = libraryAsync.value;
    final libraryName = library?.name.isNotEmpty == true ? library!.name : 'Study Library';
    final savedSettings = templateAsync.value ?? const IdCardTemplateSettings();
    final activeTheme = savedSettings.customColorHex ?? savedSettings.cardTheme;

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

          final plans = plansAsync.value ?? [];
          final plan = plans.where((p) => p.id == student.planId).firstOrNull;
          final planName = plan?.name ?? 'Standard Membership';

          final seatText = SeatHelper.formatSeatLabel(seatId: student.seatId, rawLabel: _seatLabel, includePrefix: false);
          final secText = _sectionName != null && _sectionName!.isNotEmpty ? ' ($_sectionName)' : '';

          final hasPhoto = student.photoUrl.isNotEmpty;
          final dynamicId = student.membershipNumber?.isNotEmpty == true
              ? student.membershipNumber!
              : 'CC${student.id.length > 6 ? student.id.substring(0, 6).toUpperCase() : student.id.toUpperCase()}';

          final gradientColors = _getThemeGradient(activeTheme, Color(library?.accentColor ?? 0xFF1E3A8A));

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Interactive 3D Virtual Card Hint
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Interactive 3D Virtual Card • Tap card to flip',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 3D Flip Card Container (No choices for student, styles follow admin settings)
                    GestureDetector(
                      onTap: _toggleFlip,
                      child: AnimatedBuilder(
                        animation: _flipAnimation,
                        builder: (context, child) {
                          final angle = _flipAnimation.value * math.pi;
                          final transform = Matrix4.identity()
                            ..setEntry(3, 2, 0.001) // perspective
                            ..rotateY(angle);
                          final isFlipping = _flipController.isAnimating;

                          return Transform(
                            transform: transform,
                            alignment: Alignment.center,
                            child: _showBack
                                ? Transform(
                                    transform: Matrix4.identity()..rotateY(math.pi),
                                    alignment: Alignment.center,
                                    child: RepaintBoundary(
                                      child: _buildCardBack(
                                        student: student,
                                        library: library,
                                        dynamicId: dynamicId,
                                        seatText: '$seatText$secText',
                                        dateFormat: dateFormat,
                                        isFlipping: isFlipping,
                                      ),
                                    ),
                                  )
                                : RepaintBoundary(
                                    child: _buildCardFront(
                                      student: student,
                                      library: library,
                                      libraryName: libraryName,
                                      gradientColors: gradientColors,
                                      dynamicId: dynamicId,
                                      seatText: '$seatText$secText',
                                      planName: planName,
                                      hasPhoto: hasPhoto,
                                      dateFormat: dateFormat,
                                      isFlipping: isFlipping,
                                    ),
                                  ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Flip Card Button
                    OutlinedButton.icon(
                      onPressed: _toggleFlip,
                      icon: const Icon(Icons.flip_camera_android_rounded, size: 18),
                      label: Text(
                        _showBack ? 'View Front Side' : 'Flip to View Back Side & QR',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Verified Digital Pass Confirmation Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.verified_user_rounded,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Official Digital Student Pass Active',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'This verified virtual pass with security QR code is your official membership credential for daily desk check-in, attendance, and identity authentication.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Share Digital Pass via WhatsApp
                    FilledButton.icon(
                      onPressed: () async {
                        final whatsapp = ref.read(whatsappServiceProvider);
                        final message = 'Hello, here is my official Digital Student Pass for ${library?.name ?? 'the library'} (Seat: $seatText, ID: $dynamicId).';
                        final targetContact = (library?.contact.isNotEmpty == true)
                            ? library!.contact
                            : (library?.effectiveHelpline ?? '');
                        if (targetContact.isNotEmpty) {
                          await whatsapp.sendMessage(
                            targetContact,
                            message,
                            context: context,
                            recipientName: library?.name,
                            title: 'Share Digital Pass',
                          );
                        }
                      },
                      icon: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                      label: const Text(
                        'Share Digital Pass via WhatsApp',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              ErrorHandler.handleError(err),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }

  /// Front face of the ultra-modern ID card with Dotted Mesh, 3D Logo Watermark, & verified checks
  Widget _buildCardFront({
    required StudentModel student,
    required LibraryModel? library,
    required String libraryName,
    required List<Color> gradientColors,
    required String dynamicId,
    required String seatText,
    String? planName,
    required bool hasPhoto,
    required DateFormat dateFormat,
    bool isFlipping = false,
  }) {
    final validTillText = student.planEndDate != null
        ? dateFormat.format(student.planEndDate!)
        : 'Active';

    final logoProvider = (library != null && library.logoUrl.isNotEmpty)
        ? ImageService.getImageProvider(library.logoUrl)
        : null;

    final addressParts = (library?.address ?? '').split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    final localityName = addressParts.length >= 3
        ? addressParts.last.replaceAll(RegExp(r'-\d+'), '').trim()
        : (addressParts.length == 2 ? addressParts[1] : (addressParts.isNotEmpty ? addressParts.first : ''));
    final cardSubtitle = localityName.isNotEmpty && localityName.length <= 16
        ? '$localityName • Smart Study Center'
        : (addressParts.isNotEmpty && addressParts.first.length <= 18
            ? '${addressParts.first} • Study Center'
            : 'Smart Study Center');

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 440),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: isFlipping ? 0.20 : 0.40),
            blurRadius: isFlipping ? 6 : 24,
            offset: isFlipping ? const Offset(0, 4) : const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // 1. Dotted Mesh Grid Overlay
            Positioned.fill(
              child: CustomPaint(
                painter: DottedMeshPainter(
                  dotColor: Colors.white.withValues(alpha: 0.12),
                  spacing: 16.0,
                  dotRadius: 1.1,
                ),
              ),
            ),

            // 2. 3D Organisational Logo Watermark in Background (Perfect Center)
            Positioned.fill(
              child: Center(
                child: Opacity(
                  opacity: 0.12,
                  child: ClipOval(
                    child: logoProvider != null
                        ? Image(
                            image: logoProvider,
                            width: 155,
                            height: 155,
                            fit: BoxFit.cover,
                          )
                        : const Icon(
                            Icons.local_library_rounded,
                            size: 150,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
            ),

            // 3. Card Content (No bottom gap, fully balanced)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Header: Logo + Name + Locality + Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              child: ClipOval(
                                child: logoProvider != null
                                    ? Image(
                                        image: logoProvider,
                                        fit: BoxFit.cover,
                                      )
                                    : const Center(
                                        child: Icon(Icons.school_rounded, color: Colors.white, size: 20),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 10),
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
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12.0,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  Text(
                                    cardSubtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.75),
                                      fontSize: 9.0,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0x33F59E0B),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0x66FDE68A)),
                        ),
                        child: const Text(
                          'STUDENT PASS',
                          style: TextStyle(
                            color: Color(0xFFFDE68A),
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
                  const SizedBox(height: 10),

                  // Middle Section: Photo + Full Details (No NFC/Gold Chip)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Photo Container with Verified Badge
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          GestureDetector(
                            onTap: hasPhoto
                                ? () => ImageService.showImageViewer(
                                      context,
                                      imageUrl: student.photoUrl,
                                      title: student.name,
                                    )
                                : null,
                            child: Container(
                              width: 78,
                              height: 98,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
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
                                        style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: -3,
                            right: -3,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.check_rounded, color: Colors.white, size: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // Fulfilled Student Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Student Name (Bold & Crisp)
                            Text(
                              student.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 2),

                            // Member ID & Plan Row
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0x2610B981),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0x6610B981)),
                                  ),
                                  child: Text(
                                    'ID: $dynamicId',
                                    style: const TextStyle(
                                      color: Color(0xFF6EE7B7),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                if (planName != null && planName.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      planName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Seat & Validity
                            Row(
                              children: [
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      text: 'Seat: ',
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10.5),
                                      children: [
                                        TextSpan(
                                          text: seatText,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      text: 'Valid: ',
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10.5),
                                      children: [
                                        TextSpan(
                                          text: validTillText,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Student Phone
                            if (student.phone.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  'Phone: ${student.phone}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 10.5, fontWeight: FontWeight.w600),
                                ),
                              ),

                            // College / Course / Blood Group
                            if (student.college.isNotEmpty || student.course.isNotEmpty || student.bloodGroup != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (student.course.isNotEmpty || student.college.isNotEmpty)
                                    Expanded(
                                      child: Text(
                                        student.course.isNotEmpty ? student.course : student.college,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 9.5),
                                      ),
                                    ),
                                  if (student.bloodGroup != null && student.bloodGroup!.isNotEmpty) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade900.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.red.shade300, width: 0.6),
                                      ),
                                      child: Text(
                                        'Blood: ${student.bloodGroup}',
                                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
                  const SizedBox(height: 6),

                  // Bottom Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SECURE DIGITAL ID',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 9,
                          fontFamily: 'monospace',
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        student.membershipNumber != null && student.membershipNumber!.isNotEmpty
                            ? 'PASS ID: ${student.membershipNumber}'
                            : (student.id.length >= 8 ? 'PASS ID: ${student.id.substring(0, 8).toUpperCase()}' : 'STUDENT PASS'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Back face of the ultra-modern ID card with Magnetic stripe, rules, QR, & official seal
  Widget _buildCardBack({
    required StudentModel student,
    required LibraryModel? library,
    required String dynamicId,
    required String seatText,
    required DateFormat dateFormat,
    bool isFlipping = false,
  }) {
    final effectiveHelpline = library?.effectiveHelpline.isNotEmpty == true
        ? library!.effectiveHelpline
        : (library?.effectiveContact.isNotEmpty == true ? library!.effectiveContact : "");

    final effectiveReception = library?.effectiveContact.isNotEmpty == true
        ? library!.effectiveContact
        : effectiveHelpline;

    final logoProvider = (library != null && library.logoUrl.isNotEmpty)
        ? ImageService.getImageProvider(library.logoUrl)
        : null;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 440),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Dark slate
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isFlipping ? 0.25 : 0.45),
            blurRadius: isFlipping ? 6 : 24,
            offset: isFlipping ? const Offset(0, 4) : const Offset(0, 10),
          ),
        ],
        border: Border.all(color: const Color(0xFF334155), width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // 1. Dotted Mesh Grid Overlay on Back
            Positioned.fill(
              child: CustomPaint(
                painter: DottedMeshPainter(
                  dotColor: Colors.white.withValues(alpha: 0.08),
                  spacing: 16.0,
                  dotRadius: 1.1,
                ),
              ),
            ),

            // 2. 3D Organisational Logo Watermark in Center Background (Perfect Center)
            Positioned.fill(
              child: Center(
                child: Opacity(
                  opacity: 0.10,
                  child: ClipOval(
                    child: logoProvider != null
                        ? Image(
                            image: logoProvider,
                            width: 155,
                            height: 155,
                            fit: BoxFit.cover,
                          )
                        : const Icon(
                            Icons.local_library_rounded,
                            size: 150,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
            ),

            // 3. Main Content
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Magnetic Stripe Bar
                Container(
                  height: 32,
                  color: const Color(0xFF020617),
                  alignment: Alignment.center,
                  child: Container(
                    height: 8,
                    color: const Color(0xFF1E293B),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Back Header: Title
                      const Row(
                        children: [
                          Icon(Icons.gavel_rounded, size: 14, color: Color(0xFFFDE68A)),
                          SizedBox(width: 6),
                          Text(
                            'TERMS OF ACCESS & CONDUCT',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Middle Section: Rules & Emergency Contact + QR Code & Seal
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Rules and Contact Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildRuleBullet('Mandatory for biometric check-in & reading hall admission.'),
                                _buildRuleBullet('Strict pin-drop silence must be observed inside study zones.'),
                                _buildRuleBullet('Loss of ID card must be reported immediately to reception.'),
                                const SizedBox(height: 6),

                                // Guardian & Emergency Contact Combined Box
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B).withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF334155)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.emergency_rounded, size: 14, color: Color(0xFFF87171)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              student.fatherName.isNotEmpty
                                                  ? 'GUARDIAN & EMERGENCY CONTACT'
                                                  : 'EMERGENCY CONTACT',
                                              style: const TextStyle(
                                                color: Color(0xFF94A3B8),
                                                fontSize: 7.5,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              student.fatherName.isNotEmpty
                                                  ? '${student.fatherName} (Guardian) • ${student.emergencyContact.isNotEmpty ? student.emergencyContact : (student.phone.isNotEmpty ? student.phone : effectiveReception)}'
                                                  : 'Emergency: ${student.emergencyContact.isNotEmpty ? student.emergencyContact : (student.phone.isNotEmpty ? student.phone : effectiveReception)}',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFFE2E8F0),
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Verification QR Code Column
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0x3338BDF8),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: const Color(0x6638BDF8)),
                                ),
                                child: const Text(
                                  'MEMBER',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF38BDF8),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                ),
                                child: QrImageView(
                                  data: jsonEncode({
                                    'type': 'STUDENT_PASS',
                                    'id': student.id,
                                    'lib': library?.id ?? '',
                                    'name': student.name,
                                    'memNo': student.membershipNumber ?? '',
                                    'phone': student.phone,
                                    'bloodGroup': student.bloodGroup ?? '',
                                    'emergency': student.emergencyContact,
                                    'seat': _seatLabel ?? student.seatId ?? 'Unassigned',
                                    'expiry': student.planEndDate != null ? DateFormat('dd/MM/yyyy').format(student.planEndDate!) : 'Active',
                                  }),
                                  version: QrVersions.auto,
                                  size: 60,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'SCAN TO VERIFY',
                                style: TextStyle(
                                  fontSize: 7,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 3),
                              // Official Seal Stamp graphic
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0x2610B981),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0x6610B981)),
                                ),
                                child: const Text(
                                  '★ VERIFIED PASS ★',
                                  style: TextStyle(
                                    fontSize: 6.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF34D399),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Bottom Contact Bar
                      Container(
                        padding: const EdgeInsets.only(top: 6),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: Color(0xFF334155))),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.support_agent_rounded, size: 13, color: Color(0xFFFB7185)),
                            const SizedBox(width: 6),
                            Text(
                              effectiveHelpline == effectiveReception || effectiveReception.isEmpty
                                  ? 'Helpline & Reception: $effectiveHelpline'
                                  : 'Helpline: $effectiveHelpline  •  Reception: $effectiveReception',
                              style: const TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleBullet(String rule) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Color(0xFF64748B), fontSize: 9)),
          Expanded(
            child: Text(
              rule,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 8.5, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for dotted grid background mesh
class DottedMeshPainter extends CustomPainter {
  final Color dotColor;
  final double spacing;
  final double dotRadius;

  const DottedMeshPainter({
    required this.dotColor,
    required this.spacing,
    required this.dotRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
