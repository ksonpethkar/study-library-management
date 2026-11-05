import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

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
  static Future<PickedDocument?> pickDocument({
    BuildContext? context,
    ImageSource? preferredSource,
    int imageQuality = 85,
    double maxWidth = 1600,
  }) async {
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
            return _createFromBytes(
              bytes: bytes,
              fileName: picked.name.isNotEmpty ? picked.name : 'camera_capture.jpg',
              mimeType: 'image/jpeg',
            );
          }
        }
        return null;
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

    // ── 2. Unified File / Gallery Picker (Images + PDFs) ────────────────────
    try {
      final pickedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
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
          final isPdfFile = ext == 'pdf';
          final mime = isPdfFile
              ? 'application/pdf'
              : (ext == 'png' ? 'image/png' : 'image/jpeg');

          return _createFromBytes(
            bytes: fileBytes,
            fileName: platformFile.name,
            mimeType: mime,
            isPdf: isPdfFile,
          );
        }
      }
    } catch (filePickerError) {
      debugPrint('[DocumentPickerService] FilePicker error: $filePickerError');
    }

    // ── 3. Fallback to standard ImagePicker gallery if FilePicker was blocked ──
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth,
        imageQuality: imageQuality,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (bytes.isNotEmpty) {
          return _createFromBytes(
            bytes: bytes,
            fileName: picked.name.isNotEmpty ? picked.name : 'gallery_upload.jpg',
            mimeType: 'image/jpeg',
          );
        }
      }
    } catch (_) {}

    return null;
  }

  static PickedDocument _createFromBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    bool? isPdf,
  }) {
    final pdfFlag = isPdf ?? mimeType.contains('pdf');
    final base64Content = base64Encode(bytes);
    final dataUrl = 'data:$mimeType;base64,$base64Content';
    final sizeKB = bytes.lengthInBytes / 1024.0;

    return PickedDocument(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      isPdf: pdfFlag,
      dataUrl: dataUrl,
      fileSizeKB: sizeKB,
    );
  }
}
