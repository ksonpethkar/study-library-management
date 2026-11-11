import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/registration_provider.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/services/form_config_service.dart';
import 'package:study_library/core/utils/error_formatter.dart';

class PhotoUploadScreen extends ConsumerStatefulWidget {
  const PhotoUploadScreen({super.key});

  @override
  ConsumerState<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends ConsumerState<PhotoUploadScreen> {
  String? _photoUrlOrDataUrl;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    final regData = ref.read(registrationNotifierProvider);
    _photoUrlOrDataUrl = (regData['photoDataUrl'] as String?) ??
        (regData['photoUrl'] as String?) ??
        (regData['photoPath'] as String?);
  }

  Future<void> _pickPhoto() async {
    final source = await ImageService.showSourcePicker(
      context,
      canRemove: _photoUrlOrDataUrl != null && _photoUrlOrDataUrl!.isNotEmpty,
    );
    if (!mounted) return;

    if (source == null) {
      setState(() => _photoUrlOrDataUrl = null);
      ref.read(registrationNotifierProvider.notifier).updateFields({
        'photoDataUrl': null,
        'photoUrl': null,
        'photoPath': null,
      });
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final dataUrl = await ImageService.pickImageAsDataUrl(
        source: source,
        maxWidth: 800,
        quality: 75,
      );

      if (dataUrl != null && mounted) {
        setState(() => _photoUrlOrDataUrl = dataUrl);
        ref.read(registrationNotifierProvider.notifier).updateFields({
          'photoDataUrl': dataUrl,
          'photoUrl': dataUrl,
          'photoPath': dataUrl,
        });
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'camera');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _onNext() {
    ref.read(registrationStepProvider.notifier).goTo(4);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageProvider = ImageService.getImageProvider(_photoUrlOrDataUrl);
    final hasPhoto = imageProvider != null;

    final formConfigAsync = ref.watch(formConfigStreamProvider);
    final isGovIdVisible = FormConfigService.isFieldVisible(formConfigAsync.value ?? [], 'govId');
    final stepTitle = isGovIdVisible ? 'Step 3 of 6: Profile Photo' : 'Step 2 of 5: Profile Photo';
    final progressValue = isGovIdVisible ? 3 / 6 : 2 / 5;

    return Scaffold(
      appBar: AppBar(
        title: Text(stepTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => ref.read(registrationStepProvider.notifier).goTo(2),
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: progressValue),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded, size: 16, color: Color(0xFF059669)),
                        SizedBox(width: 6),
                        Text(
                          'Govt ID Attached • Single-Upload Complete',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Upload Your Portrait Photo',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This photo will appear on your digital student pass and membership profile.\n(Your Government ID document is already securely attached).',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 36),
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 75,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          backgroundImage: imageProvider,
                          child: !hasPhoto
                              ? (_isProcessing
                                  ? const CircularProgressIndicator()
                                  : Icon(Icons.person_rounded, size: 75, color: theme.colorScheme.onPrimaryContainer))
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
                  if (hasPhoto)
                    Text(
                      '✓ Photo Selected Ready',
                      style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isProcessing ? null : _pickPhoto,
                    icon: Icon(!hasPhoto ? Icons.add_a_photo_rounded : Icons.sync_rounded),
                    label: Text(!hasPhoto ? 'Select Photo' : 'Change Photo'),
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
                        child: Text(hasPhoto ? 'Next: Plan Selection ➔' : 'Skip & Continue ➔'),
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
