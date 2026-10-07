import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/services/message_template_service.dart';

class LibraryProfileScreen extends ConsumerStatefulWidget {
  const LibraryProfileScreen({super.key});

  @override
  ConsumerState<LibraryProfileScreen> createState() => _LibraryProfileScreenState();
}

class _LibraryProfileScreenState extends ConsumerState<LibraryProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _welcomeController = TextEditingController();
  final _hoursController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _membershipPrefixController = TextEditingController();
  final _taglineController = TextEditingController();
  late TextEditingController _whatsappTemplateController;
  late TextEditingController _receiptFooterController;
  String _reminderDays = '7';
  String? _logoUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingLogo = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<String?> _getEffectiveLibraryId() async {
    var libId = ref.read(currentLibraryIdProvider);
    if (libId != null && libId.isNotEmpty) return libId;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final lib = await ref
            .read(libraryRepositoryProvider)
            .getLibraryByOwnerId(user.uid);
        if (lib != null) {
          ref.read(currentLibraryIdProvider.notifier).set(lib.id);
          return lib.id;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> _loadProfile() async {
    final libraryId = await _getEffectiveLibraryId();
    if (libraryId == null || libraryId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        _nameController.text = data['name'] ?? '';
        _addressController.text = data['address'] ?? '';
        _phoneController.text = data['contact'] ?? data['phone'] ?? '';
        _emailController.text = data['email'] ?? '';
        _welcomeController.text = data['welcomeMessage'] ?? '';
        _hoursController.text = data['operatingHours'] ?? '';
        _whatsappController.text = data['whatsappNumber'] ?? '';
        _membershipPrefixController.text = data['membershipPrefix'] ?? 'CC';
        _taglineController.text = data['tagline'] ?? '';
        _whatsappTemplateController = TextEditingController(text: data['whatsappWelcomeTemplate'] ?? '');
        _receiptFooterController = TextEditingController(text: data['receiptFooterText'] ?? '');
        _reminderDays = (data['renewalReminderDays']?.toString() ?? '7').isEmpty ? '7' : data['renewalReminderDays']?.toString() ?? '7';
        _logoUrl = data['logoUrl'] as String?;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading: $e')));
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pickLogo() async {
    final libraryId = await _getEffectiveLibraryId();
    if (libraryId == null || libraryId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to update library profile.')),
        );
      }
      return;
    }

    final hasLogo = _logoUrl != null && _logoUrl!.isNotEmpty;

    if (!mounted) return;

    // Inline bottom sheet — returns 'camera', 'gallery', 'remove', or null (dismissed)
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.camera_alt_rounded)),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.photo_library_rounded)),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (hasLogo)
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFEBEE),
                  child: Icon(Icons.delete_rounded, color: Colors.red),
                ),
                title: const Text('Remove Logo', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    // null = user closed sheet without choosing → do nothing
    if (choice == null) return;

    if (choice == 'remove') {
      setState(() => _logoUrl = null);
      return;
    }

    // Pick and upload
    final source = choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
    setState(() => _isUploadingLogo = true);
    try {
      final file = await ImageService.pickAndCompressImage(source: source);
      if (file == null) return;

      final filename = 'logo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'libraries/$libraryId/logos/$filename';
      
      String url;
      try {
        url = await ImageService.uploadToStorage(file: file, path: path);
      } catch (storageErr) {
        // Fallback: If Firebase Storage is not set up on Spark tier, store as compressed base64 data URL
        debugPrint('Storage upload failed, using Base64 data URL: $storageErr');
        final bytes = await file.readAsBytes();
        url = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }

      if (mounted) {
        setState(() => _logoUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo selected! Tap "Save Profile" to apply.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Upload failed: ${e.toString().replaceAll("Exception:", "").trim()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final libraryId = await _getEffectiveLibraryId();
    if (libraryId == null || libraryId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active library found. Please sign in again.')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .set({
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'contact': _phoneController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'welcomeMessage': _welcomeController.text.trim(),
        'operatingHours': _hoursController.text.trim(),
        'whatsappNumber': _whatsappController.text.trim(),
        'membershipPrefix': _membershipPrefixController.text.trim().isNotEmpty
            ? _membershipPrefixController.text.trim().toUpperCase()
            : 'CC',
        'tagline': _taglineController.text.trim(),
        'whatsappWelcomeTemplate': _whatsappTemplateController.text.trim(),
        'receiptFooterText': _receiptFooterController.text.trim(),
        'renewalReminderDays': _reminderDays,
        'logoUrl': _logoUrl ?? '',
        'updatedAt': FieldValue.serverTimestamp(), // fixed: was ISO string; library_repository sorts by Timestamp
      }, SetOptions(merge: true));

      // Cache immediately to SharedPreferences for instant splash and offline load
      try {
        final prefs = ref.read(sharedPreferencesProvider);
        prefs.setString('cached_library_name', _nameController.text.trim());
        if (_logoUrl != null && _logoUrl!.isNotEmpty) {
          prefs.setString('cached_library_logo_url', _logoUrl!);
        } else {
          prefs.remove('cached_library_logo_url');
        }
        if (_welcomeController.text.trim().isNotEmpty) {
          prefs.setString('cached_library_tagline', _welcomeController.text.trim());
        }
      } catch (_) {}

      // Invalidate cached library data
      ref.invalidate(currentLibraryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Library profile updated successfully!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update library profile. Please check your network and try again.')),
        );
      }
    }

    if (mounted) setState(() => _isSaving = false);
  }

  ImageProvider? _getLogoImage() {
    if (_logoUrl == null || _logoUrl!.isEmpty) return null;
    if (_logoUrl!.startsWith('data:image')) {
      final base64String = _logoUrl!.split(',').last;
      return MemoryImage(base64Decode(base64String));
    }
    return NetworkImage(_logoUrl!);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _welcomeController.dispose();
    _hoursController.dispose();
    _whatsappController.dispose();
    _membershipPrefixController.dispose();
    _taglineController.dispose();
    _whatsappTemplateController.dispose();
    _receiptFooterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLogo = _logoUrl != null && _logoUrl!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Library Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Logo Picker
                  Center(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: hasLogo
                              ? () => ImageService.showImageViewer(
                                    context,
                                    imageUrl: _logoUrl,
                                    title: 'Library Logo',
                                  )
                              : _pickLogo,
                          child: CircleAvatar(
                            radius: 54,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            backgroundImage: _getLogoImage(),
                            child: !hasLogo
                                ? Text(
                                    _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : '?',
                                    style: TextStyle(fontSize: 44, color: theme.colorScheme.primary),
                                  )
                                : null,
                          ),
                        ),
                        if (_isUploadingLogo)
                          const Positioned.fill(
                            child: CircleAvatar(
                              backgroundColor: Colors.black45,
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Material(
                            color: theme.colorScheme.primary,
                            shape: const CircleBorder(),
                            elevation: 4,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _pickLogo,
                              child: const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Icon(Icons.camera_alt_rounded, size: 20, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: _pickLogo,
                      icon: const Icon(Icons.upload_rounded, size: 18),
                      label: Text(hasLogo ? 'Change Library Logo' : 'Upload Library Logo'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Library Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone / Contact Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _welcomeController,
                    decoration: const InputDecoration(
                      labelText: 'Welcome Message',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.message),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _hoursController,
                    decoration: const InputDecoration(
                      labelText: 'Operating Hours',
                      hintText: 'e.g. 7:00 AM - 11:00 PM',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.schedule),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _whatsappController,
                    decoration: const InputDecoration(
                      labelText: 'WhatsApp Number',
                      hintText: 'e.g. 9876543210',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.chat_rounded),
                      helperText: 'Used to send welcome messages to approved students',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _membershipPrefixController,
                    decoration: const InputDecoration(
                      labelText: 'Membership ID Prefix',
                      hintText: 'e.g. CC (generates CC20260001)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge_rounded),
                      helperText: 'Short 2–4 letter code used to prefix membership numbers',
                    ),
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 4,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _taglineController,
                    decoration: const InputDecoration(
                      labelText: 'Library Tagline',
                      hintText: 'e.g. Your Focus, Our Responsibility',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.format_quote_rounded),
                      helperText: 'Shown below library name on the login screen',
                    ),
                    maxLength: 80,
                  ),
                  const SizedBox(height: 16),
                  const Text('WhatsApp Welcome Message Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _whatsappTemplateController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: MessageTemplateService.defaultWelcomeTemplate,
                      helperText: 'Leave blank to use the default message',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: MessageTemplateService.availableVariables.map((v) => ActionChip(
                      label: Text(v, style: const TextStyle(fontSize: 11)),
                      onPressed: () {
                        final ctrl = _whatsappTemplateController;
                        final selection = ctrl.selection;
                        final newText = ctrl.text.replaceRange(
                          selection.start < 0 ? ctrl.text.length : selection.start,
                          selection.end < 0 ? ctrl.text.length : selection.end,
                          v,
                        );
                        ctrl.value = ctrl.value.copyWith(
                          text: newText,
                          selection: TextSelection.collapsed(offset: (selection.start < 0 ? ctrl.text.length : selection.start) + v.length),
                        );
                      },
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Receipt Footer Text', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _receiptFooterController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: MessageTemplateService.defaultReceiptFooter,
                      helperText: 'Appears at the bottom of every receipt. Supports {libraryName}.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Plan Expiry Reminder (days before)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                     value: _reminderDays,
                    items: ['3', '5', '7', '10', '14', '30'].map((d) =>
                      DropdownMenuItem(value: d, child: Text('$d days before expiry'))
                    ).toList(),
                    onChanged: (v) => setState(() => _reminderDays = v ?? '7'),
                    decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.alarm)),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save Profile'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
