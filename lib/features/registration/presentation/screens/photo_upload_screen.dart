import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/registration_provider.dart';
import 'package:study_library/services/image_service.dart';

class PhotoUploadScreen extends ConsumerStatefulWidget {
  const PhotoUploadScreen({super.key});

  @override
  ConsumerState<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends ConsumerState<PhotoUploadScreen> {
  File? _pickedFile;

  @override
  void initState() {
    super.initState();
    final regData = ref.read(registrationNotifierProvider);
    final existingPath = regData['photoPath'] as String?;
    if (existingPath != null && existingPath.isNotEmpty) {
      final f = File(existingPath);
      if (f.existsSync()) _pickedFile = f;
    }
  }

  Future<void> _pickPhoto() async {
    final source = await ImageService.showSourcePicker(
      context,
      canRemove: _pickedFile != null,
    );
    if (!mounted) return;

    if (source == null) {
      setState(() => _pickedFile = null);
      ref.read(registrationNotifierProvider.notifier).updateField('photoPath', null);
      return;
    }

    final compressed = await ImageService.pickAndCompressImage(source: source);
    if (compressed != null && mounted) {
      setState(() => _pickedFile = compressed);
      ref.read(registrationNotifierProvider.notifier).updateField('photoPath', compressed.path);
    }
  }

  void _onNext() {
    ref.read(registrationStepProvider.notifier).goTo(4);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile Photo')),
      body: Column(
        children: [
          const LinearProgressIndicator(value: 3 / 5),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Upload Your Profile Photo',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This photo will be printed on your library ID card and membership profile.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 36),
                  GestureDetector(
                    onTap: () {
                      if (_pickedFile != null) {
                        ImageService.showImageViewer(
                          context,
                          imageFile: _pickedFile,
                          title: 'Profile Photo Preview',
                        );
                      } else {
                        _pickPhoto();
                      }
                    },
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 75,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          backgroundImage: _pickedFile != null ? FileImage(_pickedFile!) : null,
                          child: _pickedFile == null
                              ? Icon(Icons.person_rounded, size: 75, color: theme.colorScheme.onPrimaryContainer)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 4,
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: theme.colorScheme.primary,
                            child: const Icon(Icons.camera_alt_rounded, size: 20, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_pickedFile != null)
                    TextButton.icon(
                      onPressed: () {
                        ImageService.showImageViewer(
                          context,
                          imageFile: _pickedFile,
                          title: 'Profile Photo Preview',
                        );
                      },
                      icon: const Icon(Icons.zoom_in_rounded),
                      label: const Text('Tap to Preview Fullscreen'),
                    ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _pickPhoto,
                    icon: Icon(_pickedFile == null ? Icons.add_a_photo_rounded : Icons.sync_rounded),
                    label: Text(_pickedFile == null ? 'Select Photo' : 'Change Photo'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton(
                        onPressed: () => ref.read(registrationStepProvider.notifier).goTo(2),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                        child: const Text('Back'),
                      ),
                      ElevatedButton(
                        onPressed: _onNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        ),
                        child: Text(_pickedFile != null ? 'Next: Plan Selection ➔' : 'Skip & Continue ➔'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
