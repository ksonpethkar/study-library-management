import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:study_library/core/utils/image_compressor.dart';

class ImageService {
  static final ImagePicker _picker = ImagePicker();

  /// Prompt the user with a bottom sheet to pick from Camera, Gallery, or Remove photo.
  static Future<ImageSource?> showSourcePicker(BuildContext context, {bool canRemove = false}) async {
    return showModalBottomSheet<ImageSource?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Select Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEEF2FF),
                  child: Icon(Icons.camera_alt_rounded, color: Color(0xFF4F46E5)),
                ),
                title: const Text('Take Photo with Camera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEEF2FF),
                  child: Icon(Icons.photo_library_rounded, color: Color(0xFF4F46E5)),
                ),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              if (canRemove) ...[
                const Divider(),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFEE2E2),
                    child: Icon(Icons.delete_outline_rounded, color: Colors.red),
                  ),
                  title: const Text('Remove Current Photo', style: TextStyle(color: Colors.red)),
                  onTap: () => Navigator.pop(ctx, null),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Pick and compress an image from specified source.
  static Future<File?> pickAndCompressImage({
    required ImageSource source,
    int maxWidth = 1024,
    int quality = 80,
  }) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth.toDouble(),
        imageQuality: quality,
      );
      if (picked == null) return null;

      final rawFile = File(picked.path);
      // Compress to optimize bandwidth and Firebase Storage
      final compressed = await ImageCompressor.compressImage(
        rawFile,
        maxWidth: maxWidth,
        quality: quality,
      );
      return compressed;
    } catch (e) {
      debugPrint('Error picking/compressing image: $e');
      return null;
    }
  }

  /// Stores an image as a compressed Base64 data URL in Firestore.
  /// Firebase Storage requires the paid Blaze plan, so we skip it entirely.
  /// Base64 is stored directly in the Firestore document — works on free Spark tier.
  /// Images are aggressively compressed to ~50 KB to keep Firestore docs small.
  static Future<String> uploadToStorage({
    required File file,
    required String path,
  }) async {
    try {
      // Compress aggressively before base64 encoding to keep Firestore doc small
      final compressed = await ImageCompressor.compressImage(
        file,
        maxWidth: 600,
        quality: 60,
      );
      final bytes = await compressed.readAsBytes();
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    } catch (e) {
      debugPrint('Image processing error: $e. Encoding raw bytes.');
      // Fallback: encode raw bytes without compression
      try {
        final bytes = await file.readAsBytes();
        return 'data:image/jpeg;base64,${base64Encode(bytes)}';
      } catch (innerErr) {
        throw Exception('Failed to process image: $innerErr');
      }
    }
  }

  /// Returns an ImageProvider supporting both remote URLs and Base64 data URLs.
  static ImageProvider? getImageProvider(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (trimmed.startsWith('data:image')) {
      try {
        final base64String = trimmed.contains(',') ? trimmed.split(',')[1] : trimmed;
        return MemoryImage(base64Decode(base64String));
      } catch (e) {
        debugPrint('Error decoding base64 image: $e');
        return null;
      }
    } else if (trimmed.startsWith('http')) {
      return NetworkImage(trimmed);
    }
    return null;
  }

  /// Convenience method: prompts for source, compresses, and uploads to Firebase Storage.
  static Future<String?> pickAndUploadImage({
    required BuildContext context,
    required String folder,
    bool canRemove = false,
  }) async {
    final source = await showSourcePicker(context, canRemove: canRemove);
    if (source == null) return null;

    final file = await pickAndCompressImage(source: source);
    if (file == null) return null;

    final filename = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = '$folder/$filename';
    return await uploadToStorage(file: file, path: path);
  }

  /// Shows an interactive fullscreen viewer for an image (remote URL or local File).
  static void showImageViewer(
    BuildContext context, {
    String? imageUrl,
    File? imageFile,
    String title = 'Photo Preview',
  }) {
    if ((imageUrl == null || imageUrl.isEmpty) && imageFile == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(title, style: const TextStyle(color: Colors.white)),
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.8,
              maxScale: 4.0,
              child: imageFile != null
                  ? Image.file(imageFile)
                  : imageUrl!.startsWith('data:image')
                      ? Image.memory(
                          base64Decode(
                            imageUrl.contains(',') ? imageUrl.split(',')[1] : imageUrl,
                          ),
                          fit: BoxFit.contain,
                        )
                      : Image.network(
                          imageUrl,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                              SizedBox(height: 12),
                              Text('Failed to load image', style: TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ),
            ),
          ),
        ),
      ),
    );
  }

  /// Universal image builder supporting Base64 data URLs, http(s) URLs, and local file paths.
  static Widget buildImageWidget(
    String pathOrUrl, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
  }) {
    if (pathOrUrl.startsWith('data:image') ||
        (!pathOrUrl.startsWith('http') && pathOrUrl.length > 200)) {
      try {
        final b64 = pathOrUrl.contains(',') ? pathOrUrl.split(',').last : pathOrUrl;
        return Image.memory(
          base64Decode(b64),
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(Icons.broken_image, color: Colors.grey),
          ),
        );
      } catch (_) {}
    }
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return Image.network(
        pathOrUrl,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }
    final file = File(pathOrUrl);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }
    return const Center(child: Icon(Icons.image_not_supported, color: Colors.grey));
  }
}
