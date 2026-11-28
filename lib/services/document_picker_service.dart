import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:study_library/core/utils/pdf_helper.dart';
import 'package:study_library/core/widgets/id_document_editor_dialog.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/services/inactivity_lock_service.dart';

/// Represents a document or image picked from camera, gallery, or file system.
class PickedDocument {
  final Uint8List bytes;
  final String fileName;
  final String mimeType;
  final bool isPdf;
  final String dataUrl;
  final double fileSizeKB;

  const PickedDocument({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    required this.isPdf,
    required this.dataUrl,
    required this.fileSizeKB,
  });

  bool get isImage => !isPdf;
}

/// Universal, cross-platform document picker resilient to camera/web sandbox limitations.
/// 
/// Supported formats:
/// - Images: JPG, JPEG, PNG, WEBP, HEIC
/// - Documents: PDF (e.g. e-Aadhaar, DigiLocker certificates)
/// 
/// Fault-Tolerance Architecture:
/// 1. If camera capture is requested but camera hardware / permissions are unavailable (e.g. Web Desktop Chrome),
///    it gracefully falls back to device file selection without crashing or terminating the user flow.
/// 2. Handles in-memory bytes for Flutter Web (WASM / CanvasKit / HTML) and file paths on mobile/desktop platforms.
class DocumentPickerService {
  static final ImagePicker _imagePicker = ImagePicker();

  /// Checks if a given path or data URL represents a PDF document
  static bool isPdf(String? urlOrPath) {
    if (urlOrPath == null || urlOrPath.trim().isEmpty) return false;
    final lower = urlOrPath.trim().toLowerCase();
    return lower.startsWith('data:application/pdf') || lower.endsWith('.pdf');
  }

  /// Picks a document (Image or PDF) with automatic fallback for camera failures.
  ///
  /// When [enableEditor] is true and a [context] is provided, picked images open
  /// in [IdDocumentEditorDialog] for rotation, cropping, clarity filters,
  /// privacy masking, and optional KYC watermarking before upload.
  static Future<PickedDocument?> pickDocument({
    BuildContext? context,
    ImageSource? preferredSource,
    int imageQuality = 85,
    double maxWidth = 1600,
    bool enableEditor = false,
    GovIdType? govIdType,
  }) async {
    InactivityLockService.setExternalDialogActive(true);
    try {
      PickedDocument? pickedDoc;
      // ── 1. If Camera is explicitly requested ────────────────────────────────
      if (preferredSource == ImageSource.camera) {
        try {
          final picked = await _imagePicker.pickImage(
            source: ImageSource.camera,
            maxWidth: maxWidth,
            imageQuality: imageQuality,
          );
          if (picked != null) {
            final bytes = await picked.readAsBytes();
            if (bytes.isNotEmpty) {
              pickedDoc = _createFromBytes(
                bytes: bytes,
                fileName: picked.name.isNotEmpty ? picked.name : 'camera_capture.jpg',
                mimeType: 'image/jpeg',
              );
            }
          }
          if (pickedDoc == null) return null;
        } catch (cameraError) {
          debugPrint('[DocumentPickerService] Camera unavailable or denied: $cameraError');
          // Graceful fallback: If camera fails (e.g. desktop web or no permission), open file picker
          if (context != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.amberAccent, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Camera is not accessible on this browser/device. Please select a photo or PDF file.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Color(0xFF1E293B),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 3),
              ),
            );
          }
          // Fall through to file picker below
        }
      }

      // ── 2. Unified File / Gallery Picker (Images + PDFs) ──────────────────
      if (pickedDoc == null) {
        try {
          final pickedFiles = await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif', 'pdf'],
          );

          if (pickedFiles.isNotEmpty) {
            final platformFile = pickedFiles.first;
            Uint8List? fileBytes;
            try {
              fileBytes = await platformFile.xFile.readAsBytes();
            } catch (_) {
              if (!kIsWeb && platformFile.path != null) {
                final file = File(platformFile.path!);
                if (await file.exists()) {
                  fileBytes = await file.readAsBytes();
                }
              }
            }

            if (fileBytes != null && fileBytes.isNotEmpty) {
              final ext = platformFile.extension?.toLowerCase() ?? '';
              final isPdfFile = ext == 'pdf' || platformFile.name.toLowerCase().endsWith('.pdf');
              final mime = isPdfFile
                  ? 'application/pdf'
                  : (ext == 'png'
                      ? 'image/png'
                      : ext == 'webp'
                          ? 'image/webp'
                          : (ext == 'heic' || ext == 'heif')
                              ? 'image/heic'
                              : 'image/jpeg');

              if (isPdfFile) {
                pickedDoc = await _processPickedPdf(
                  context: context,
                  pdfBytes: fileBytes,
                  fileName: platformFile.name,
                );
              } else {
                pickedDoc = _createFromBytes(
                  bytes: fileBytes,
                  fileName: platformFile.name,
                  mimeType: mime,
                  isPdf: false,
                );
              }
            }
          }
        } on FormatException catch (limitError) {
          if (context != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(limitError.message),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 5),
              ),
            );
            return null;
          }
          rethrow;
        } catch (filePickerError) {
          debugPrint('[DocumentPickerService] FilePicker error: $filePickerError');
        }
      }

      // ── 3. Fallback to standard ImagePicker gallery if FilePicker was blocked
      if (pickedDoc == null) {
        try {
          final picked = await _imagePicker.pickImage(
            source: ImageSource.gallery,
            maxWidth: maxWidth,
            imageQuality: imageQuality,
          );
          if (picked != null) {
            final bytes = await picked.readAsBytes();
            if (bytes.isNotEmpty) {
              pickedDoc = _createFromBytes(
                bytes: bytes,
                fileName: picked.name.isNotEmpty ? picked.name : 'gallery_upload.jpg',
                mimeType: 'image/jpeg',
              );
            }
          }
        } catch (_) {}
      }

      if (pickedDoc == null) return null;

      // ── 4. Optional Pre-Upload Interactive ID Document Editor ─────────────
      if (enableEditor && !pickedDoc.isPdf && context != null && context.mounted) {
        final editedBytes = await IdDocumentEditorDialog.show(
          context,
          imageBytes: pickedDoc.bytes,
          govIdType: govIdType,
        );
        if (editedBytes == null) return null;
        final baseName = pickedDoc.fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
        pickedDoc = _createFromBytes(
          bytes: editedBytes,
          fileName: '${baseName}_edited.jpg',
          mimeType: 'image/jpeg',
          isPdf: false,
        );
      }

      return pickedDoc;
    } finally {
      InactivityLockService.setExternalDialogActive(false);
      InactivityLockService.recordInteraction();
    }
  }

  /// Handles oversized (> 650 KB) or password-protected PDFs (e.g. UIDAI e-Aadhaar)
  /// by prompting for the password client-side and rasterizing page 1 into a
  /// compact JPEG image.
  static Future<PickedDocument?> _processPickedPdf({
    required BuildContext? context,
    required Uint8List pdfBytes,
    required String fileName,
  }) async {
    const int maxPdfBytes = 650 * 1024;
    final needsRasterize = pdfBytes.lengthInBytes > maxPdfBytes;

    String? password;
    var rasterAttempt = needsRasterize
        ? await PdfHelper.renderFirstPageAsJpeg(pdfBytes, dpi: 150)
        : null;

    if (!needsRasterize) {
      final probeText = await PdfHelper.extractText(pdfBytes);
      if (probeText == '__PDF_PASSWORD_REQUIRED__') {
        rasterAttempt = await PdfHelper.renderFirstPageAsJpeg(pdfBytes, dpi: 150);
      }
    }

    if (rasterAttempt != null &&
        (rasterAttempt.passwordRequired || rasterAttempt.incorrectPassword)) {
      if (context == null || !context.mounted) {
        throw const FormatException(
          'This PDF is password-protected. Please unlock it or upload a screenshot instead.',
        );
      }
      bool incorrect = false;
      while (true) {
        if (!context.mounted) return null;
        password = await _promptPdfPassword(context, incorrect: incorrect);
        if (password == null) return null;
        rasterAttempt = await PdfHelper.renderFirstPageAsJpeg(
          pdfBytes,
          password: password,
          dpi: 150,
        );
        if (rasterAttempt.jpegBytes != null) break;
        if (rasterAttempt.incorrectPassword || rasterAttempt.passwordRequired) {
          incorrect = true;
          continue;
        }
        throw FormatException(
          rasterAttempt.errorMessage ?? 'Could not unlock PDF document.',
        );
      }
    }

    if (rasterAttempt != null && rasterAttempt.jpegBytes != null) {
      final baseName = fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
      return _createFromBytes(
        bytes: rasterAttempt.jpegBytes!,
        fileName: '$baseName.jpg',
        mimeType: 'image/jpeg',
        isPdf: false,
      );
    }

    return _createFromBytes(
      bytes: pdfBytes,
      fileName: fileName,
      mimeType: 'application/pdf',
      isPdf: true,
    );
  }

  static Future<String?> _promptPdfPassword(
    BuildContext context, {
    bool incorrect = false,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Expanded(child: Text('Unlock Protected PDF')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This PDF is password-protected (e.g. UIDAI e-Aadhaar uses first 4 letters of name in CAPS + birth year). It is unlocked locally on your device.',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'PDF Password',
                errorText: incorrect ? 'Incorrect password. Please try again.' : null,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Unlock & Convert'),
          ),
        ],
      ),
    );
  }

  static PickedDocument _createFromBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    bool? isPdf,
  }) {
    final pdfFlag = isPdf ?? mimeType.contains('pdf');
    const int maxPdfBytes = 650 * 1024;
    if (pdfFlag && bytes.lengthInBytes > maxPdfBytes) {
      final sizeKb = (bytes.lengthInBytes / 1024.0).round();
      throw FormatException(
        'Selected PDF is $sizeKb KB, which exceeds the 650 KB limit. Please compress the PDF or upload a photo/screenshot of your ID instead.',
      );
    }
    Uint8List processedBytes = bytes;
    if (!pdfFlag && bytes.lengthInBytes > 60 * 1024) {
      try {
        processedBytes = ImageService.compressBytesToSafeJpeg(bytes, maxDimension: 600, initialQuality: 65);
      } catch (_) {}
    }
    final base64Content = base64Encode(processedBytes);
    final dataUrl = 'data:$mimeType;base64,$base64Content';
    final sizeKB = processedBytes.lengthInBytes / 1024.0;

    return PickedDocument(
      bytes: processedBytes,
      fileName: fileName,
      mimeType: mimeType,
      isPdf: pdfFlag,
      dataUrl: dataUrl,
      fileSizeKB: sizeKB,
    );
  }
}
