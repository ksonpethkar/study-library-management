import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/core/utils/file_download_helper.dart';
import 'package:study_library/features/qr_share/presentation/widgets/entrance_poster_card.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/services/poster_config_service.dart';
import 'package:study_library/services/a4_entrance_poster_pdf_service.dart';
import 'package:study_library/core/utils/error_formatter.dart';

class QrShareScreen extends ConsumerStatefulWidget {
  const QrShareScreen({super.key});

  @override
  ConsumerState<QrShareScreen> createState() => _QrShareScreenState();
}

class _QrShareScreenState extends ConsumerState<QrShareScreen> {
  final GlobalKey _posterKey = GlobalKey();
  bool _isSavingImage = false;
  bool _isPrintingPdf = false;
  bool _isDownloadingPdf = false;

  Future<void> _savePosterAsImage(String libraryName) async {
    if (_isSavingImage) return;
    setState(() => _isSavingImage = true);

    try {
      final boundary = _posterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Unable to capture poster element. Please ensure it is visible.');
      }

      // High resolution capture for sharp print-quality PNG (autofit A4 ratio)
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to generate PNG image data');
      }

      final pngBytes = byteData.buffer.asUint8List();
      final cleanName = libraryName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final fileName = '${cleanName.isNotEmpty ? cleanName : "Study_Library"}_A4_Entrance_Poster.png';

      await FileDownloadHelper.downloadFile(
        fileName: fileName,
        bytes: pngBytes,
        mimeType: 'image/png',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('A4 Poster image saved successfully!'),
            ],
          ),
          backgroundColor: Color(0xFF15803D),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'receipt');
    } finally {
      if (mounted) {
        setState(() => _isSavingImage = false);
      }
    }
  }

  Future<void> _printPoster(
    String libraryId,
    LibraryModel? library,
    String url,
  ) async {
    if (_isPrintingPdf) return;
    setState(() => _isPrintingPdf = true);
    try {
      await A4EntrancePosterPdfService.printA4Poster(
        context: context,
        libraryId: libraryId,
        library: library,
        seatMapUrl: url,
      );
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'receipt');
      }
    } finally {
      if (mounted) setState(() => _isPrintingPdf = false);
    }
  }

  Future<void> _downloadA4Pdf(
    String libraryId,
    LibraryModel? library,
    String url,
  ) async {
    if (_isDownloadingPdf) return;
    setState(() => _isDownloadingPdf = true);
    try {
      await A4EntrancePosterPdfService.downloadA4Pdf(
        libraryId: libraryId,
        library: library,
        seatMapUrl: url,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('A4 Poster PDF downloaded successfully!'),
            ],
          ),
          backgroundColor: Color(0xFF15803D),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'receipt');
      }
    } finally {
      if (mounted) setState(() => _isDownloadingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final libraryAsync = ref.watch(currentLibraryProvider);
    final libraryId = ref.watch(currentLibraryIdProvider) ?? '';
    final library = libraryAsync.value;
    final libraryName = library?.name.isNotEmpty == true ? library!.name : 'Study Library';
    final seatMapUrl = 'https://study-lib-mgmt-2026.web.app/seats?lib=$libraryId';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Library QR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Customize Amenity Badges',
            onPressed: () => PosterConfigService.showCustomizer(context, libraryId),
          ),
          IconButton(
            icon: const Icon(Icons.image_rounded),
            tooltip: 'Save as Image (PNG)',
            onPressed: _isSavingImage ? null : () => _savePosterAsImage(libraryName),
          ),
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'Print A4 Poster (PDF)',
            onPressed: _isPrintingPdf ? null : () => _printPoster(libraryId, library, seatMapUrl),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Card(
              elevation: 0,
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Display this QR code at your reception or entrance so students can view live available seats on their phones.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AspectRatio(
                  aspectRatio: 210 / 297,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: RepaintBoundary(
                      key: _posterKey,
                      child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: PosterConfigService.streamAmenities(libraryId),
                        builder: (context, snapshot) {
                          final amenities = snapshot.data ?? PosterConfigService.defaultAmenities;
                          return EntrancePosterCard(
                            library: library,
                            libraryId: libraryId,
                            amenities: amenities,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            // Primary Action Row: Save A4 Image & Print A4 Poster
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _isSavingImage
                        ? null
                        : () => _savePosterAsImage(libraryName),
                    icon: _isSavingImage
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.image_rounded),
                    label: const Text('Save A4 Image'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isPrintingPdf
                        ? null
                        : () => _printPoster(libraryId, library, seatMapUrl),
                    icon: _isPrintingPdf
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.print_rounded),
                    label: const Text('Print Poster (A4)'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Secondary Action Row: Download PDF & Copy Link
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isDownloadingPdf
                        ? null
                        : () => _downloadA4Pdf(libraryId, library, seatMapUrl),
                    icon: _isDownloadingPdf
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text('Download A4 PDF'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: seatMapUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Portal link copied to clipboard!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy Link'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Tertiary Action: Share Link to Apps / WhatsApp
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await SharePlus.instance.share(
                    ShareParams(
                      text: 'Check live seat availability for $libraryName: $seatMapUrl',
                      subject: '$libraryName — Live Seat Availability',
                    ),
                  );
                },
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share Live Link via Apps'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
