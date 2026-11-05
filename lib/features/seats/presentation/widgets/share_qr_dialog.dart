import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/services/poster_config_service.dart';
import 'package:study_library/services/a4_entrance_poster_pdf_service.dart';
import 'package:study_library/features/qr_share/presentation/widgets/entrance_poster_card.dart';

class ShareQrDialog extends ConsumerStatefulWidget {
  final String libraryId;
  final String? libraryName;
  final String? address;

  const ShareQrDialog({
    super.key,
    required this.libraryId,
    this.libraryName,
    this.address,
  });

  @override
  ConsumerState<ShareQrDialog> createState() => _ShareQrDialogState();
}

class _ShareQrDialogState extends ConsumerState<ShareQrDialog> {
  final GlobalKey _posterCardKey = GlobalKey();
  bool _isPrinting = false;

  String get seatMapUrl => 'https://study-lib-mgmt-2026.web.app/seats?lib=${widget.libraryId}';

  Future<void> _printPoster(LibraryModel? library) async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
      await A4EntrancePosterPdfService.printA4Poster(
        context: context,
        libraryId: widget.libraryId,
        library: library,
        seatMapUrl: seatMapUrl,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to print poster: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveLibrary = ref.watch(currentLibraryProvider).value;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Action Bar
              Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.tune_rounded, size: 16, color: Colors.white),
                      label: const Text('Customize Badges', style: TextStyle(color: Colors.white, fontSize: 12)),
                      onPressed: () => PosterConfigService.showCustomizer(context, widget.libraryId),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // The Live Entrance Poster Card Preview wrapped in RepaintBoundary for 300+ DPI PDF export
              Container(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AspectRatio(
                  aspectRatio: 210 / 297,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: RepaintBoundary(
                      key: _posterCardKey,
                      child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: PosterConfigService.streamAmenities(widget.libraryId),
                        builder: (context, snapshot) {
                          final amenities = snapshot.data ?? PosterConfigService.defaultAmenities;
                          return EntrancePosterCard(
                            library: liveLibrary,
                            libraryId: widget.libraryId,
                            amenities: amenities,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Bottom Action Buttons
              Container(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text('Share Link'),
                        onPressed: () async {
                          final libName = liveLibrary?.name ?? widget.libraryName ?? 'Study Library';
                          await SharePlus.instance.share(
                            ShareParams(
                              text: 'Check live seat availability at $libName: $seatMapUrl',
                              subject: '$libName - Live Seat Map',
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF5D4037),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _isPrinting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.print_rounded, size: 18),
                        label: Text(_isPrinting ? 'Preparing…' : 'Print Poster'),
                        onPressed: _isPrinting ? null : () => _printPoster(liveLibrary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
