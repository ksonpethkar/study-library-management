import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/core/utils/app_validators.dart';
import 'package:study_library/features/auth/presentation/providers/auth_provider.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/services/image_transparency_service.dart';
import 'package:study_library/services/message_template_service.dart';
import 'package:study_library/core/utils/error_formatter.dart';

class LibraryProfileScreen extends ConsumerStatefulWidget {
  const LibraryProfileScreen({super.key});

  @override
  ConsumerState<LibraryProfileScreen> createState() => _LibraryProfileScreenState();
}

class _LibraryProfileScreenState extends ConsumerState<LibraryProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // 1. Core Identity & Branding
  final _nameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _membershipPrefixController = TextEditingController();
  final _hoursController = TextEditingController();

  // 2. Contact & Location
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _googleMapsController = TextEditingController();
  bool _sameAsWhatsApp = true;

  // 3. Personnel & Administration
  final _adminNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _managerNameController = TextEditingController();
  final _managerContactController = TextEditingController();
  bool _showManagerDetails = false;

  // 4. Facilities
  static const List<String> _standardFacilities = [
    'High-Speed Wi-Fi',
    'Power Sockets at Desk',
    'Purified RO Water',
    'Silent Study Zone',
    'CCTV Surveillance',
    'Ergonomic Chairs',
    'Air Conditioning (AC)',
    'Personal Locker',
    'Pantry & Cafeteria',
    'Daily Newspapers & Magazines',
    'Two-Wheeler / Car Parking',
  ];

  List<String> _selectedFacilities = [
    'High-Speed Wi-Fi',
    'Power Sockets at Desk',
    'Purified RO Water',
    'Silent Study Zone',
    'CCTV Surveillance',
    'Ergonomic Chairs',
  ];

  // 5. In-Place Advanced Overrides (Preserved for 100% backward compatibility)
  final _welcomeController = TextEditingController();
  final _upiIdController = TextEditingController();
  final _wifiSsidController = TextEditingController();
  final _wifiPasswordController = TextEditingController();
  late TextEditingController _whatsappTemplateController;
  late TextEditingController _receiptFooterController;
  int _reminderDays = 7;

  // B2B GST Commercial Tax Invoicing
  bool _enableGstBilling = false;
  final _gstinController = TextEditingController();
  final _gstLegalNameController = TextEditingController();
  final _sacCodeController = TextEditingController(text: '999293');
  double _gstRate = 18.0;

  // Brand Palette & Accent White-Labeling
  int _selectedAccentColor = 0xFF5D4037;
  final _hexColorController = TextEditingController(text: '#5D4037');

  static const List<Map<String, dynamic>> _brandColorPresets = [
    {
      'name': 'Cozy Chocolate',
      'subtitle': 'Warm study ambience',
      'color': Color(0xFF5D4037),
      'hex': '#5D4037',
    },
    {
      'name': 'Royal Sapphire',
      'subtitle': 'Focused corporate navy',
      'color': Color(0xFF1E3A8A),
      'hex': '#1E3A8A',
    },
    {
      'name': 'Academic Emerald',
      'subtitle': 'Forest calm & focus',
      'color': Color(0xFF065F46),
      'hex': '#065F46',
    },
    {
      'name': 'Heritage Burgundy',
      'subtitle': 'Classic university wine',
      'color': Color(0xFF831843),
      'hex': '#831843',
    },
    {
      'name': 'Midnight Indigo',
      'subtitle': 'Modern deep nocturnal',
      'color': Color(0xFF312E81),
      'hex': '#312E81',
    },
    {
      'name': 'Slate Minimalist',
      'subtitle': 'Cool neutral modern',
      'color': Color(0xFF334155),
      'hex': '#334155',
    },
    {
      'name': 'Warm Terracotta',
      'subtitle': 'Earthy autumn brick',
      'color': Color(0xFFC2410C),
      'hex': '#C2410C',
    },
    {
      'name': 'Deep Oceanic Teal',
      'subtitle': 'Vibrant balanced cyan',
      'color': Color(0xFF0F766E),
      'hex': '#0F766E',
    },
    {
      'name': 'Electric Violet',
      'subtitle': 'Creative premium purple',
      'color': Color(0xFF581C87),
      'hex': '#581C87',
    },
    {
      'name': 'Obsidian Noir',
      'subtitle': 'Sleek luxury charcoal',
      'color': Color(0xFF18181B),
      'hex': '#18181B',
    },
  ];

  String? _logoUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingLogo = false;

  @override
  void initState() {
    super.initState();
    _whatsappTemplateController = TextEditingController();
    _receiptFooterController = TextEditingController();
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
      } catch (_) { /* intentionally silent */ }
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

        final loadedAdmin = data['adminName'] ?? data['contactPerson'] ?? '';
        final loadedOwner = data['ownerName'] ?? '';
        _adminNameController.text = loadedAdmin.isNotEmpty ? loadedAdmin : loadedOwner;
        _ownerNameController.text = loadedOwner.isNotEmpty ? loadedOwner : loadedAdmin;

        _managerNameController.text = data['managerName'] ?? '';
        _managerContactController.text = data['managerContact'] ?? '';
        _showManagerDetails = _managerNameController.text.isNotEmpty || _managerContactController.text.isNotEmpty;

        if (data['facilities'] is List) {
          _selectedFacilities = (data['facilities'] as List).map((e) => e.toString()).toList();
        }
        _addressController.text = data['address'] ?? '';
        _googleMapsController.text = data['googleMapsUrl'] ?? data['mapsUrl'] ?? (data['socialLinks'] is Map ? (data['socialLinks']['maps'] ?? '') : '');

        final primaryPhone = data['contact'] ?? data['phone'] ?? data['helplineNumber'] ?? data['ownerContact'] ?? '';
        _phoneController.text = primaryPhone;

        final loadedWhatsApp = data['whatsappNumber'] ?? '';
        _whatsappController.text = loadedWhatsApp;
        _sameAsWhatsApp = loadedWhatsApp.isEmpty || loadedWhatsApp == primaryPhone;

        _emailController.text = data['email'] ?? '';
        _hoursController.text = data['operatingHours'] ?? '';
        _membershipPrefixController.text = data['membershipPrefix'] ?? 'CC';

        final loadedTagline = data['tagline'] ?? '';
        final loadedWelcome = data['welcomeMessage'] ?? '';
        _taglineController.text = loadedTagline.isNotEmpty ? loadedTagline : loadedWelcome;
        _welcomeController.text = loadedWelcome;

        _upiIdController.text = data['upiId'] ?? '';
        _wifiSsidController.text = data['wifiSsid'] ?? data['wifiName'] ?? '';
        _wifiPasswordController.text = data['wifiPassword'] ?? data['wifiPass'] ?? '';
        _whatsappTemplateController.text = data['whatsappWelcomeTemplate'] ?? '';
        _receiptFooterController.text = data['receiptFooterText'] ?? '';
        _reminderDays = data['renewalReminderDays'] is int
            ? data['renewalReminderDays'] as int
            : int.tryParse(data['renewalReminderDays']?.toString() ?? '7') ?? 7;

        // B2B GST Commercial Tax Invoicing
        _enableGstBilling = data['enableGstBilling'] == true;
        _gstinController.text = data['gstin'] ?? '';
        _gstLegalNameController.text = data['gstLegalName'] ?? '';
        _sacCodeController.text = data['sacCode'] ?? '999293';
        _gstRate = (data['gstRate'] as num?)?.toDouble() ?? 18.0;

        _logoUrl = data['logoUrl'] as String?;
        if (data['accentColor'] is int && data['accentColor'] != 0) {
          _selectedAccentColor = data['accentColor'] as int;
        } else {
          _selectedAccentColor = 0xFF5D4037;
        }
        _hexColorController.text = '#${_selectedAccentColor.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'announcement');
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
              width: 40,
              height: 4,
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

    if (choice == null) return;

    if (choice == 'remove') {
      setState(() => _logoUrl = null);
      return;
    }

    final source = choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
    setState(() => _isUploadingLogo = true);
    try {
      final url = await ImageService.pickImageAsDataUrl(source: source);
      if (url == null || !mounted) return;

      if (mounted) {
        final cleanUrl = ImageTransparencyService.removeBackgroundFromDataUri(url, threshold: 225);
        setState(() => _logoUrl = cleanUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo selected! Tap "Save Profile" to apply.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'camera');
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
      final primaryPhone = _phoneController.text.trim();
      final whatsappNumber = _sameAsWhatsApp ? primaryPhone : _whatsappController.text.trim();
      final adminName = _adminNameController.text.trim();
      final ownerName = _ownerNameController.text.trim().isNotEmpty ? _ownerNameController.text.trim() : adminName;
      final tagline = _taglineController.text.trim();
      final welcomeMessage = tagline.isNotEmpty ? tagline : 'Welcome to ${_nameController.text.trim()}';

      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .set({
        'name': _nameController.text.trim(),
        'ownerName': ownerName,
        'ownerContact': primaryPhone,
        'adminName': adminName,
        'adminContact': primaryPhone,
        'managerName': _showManagerDetails ? _managerNameController.text.trim() : '',
        'managerContact': _showManagerDetails ? _managerContactController.text.trim() : '',
        'facilities': _selectedFacilities,
        'address': _addressController.text.trim(),
        'googleMapsUrl': _googleMapsController.text.trim(),
        'mapsUrl': _googleMapsController.text.trim(),
        'contact': primaryPhone,
        'phone': primaryPhone,
        'helplineNumber': primaryPhone,
        'email': _emailController.text.trim(),
        'welcomeMessage': welcomeMessage,
        'operatingHours': _hoursController.text.trim(),
        'whatsappNumber': whatsappNumber,
        'membershipPrefix': _membershipPrefixController.text.trim().isNotEmpty
            ? _membershipPrefixController.text.trim().toUpperCase()
            : 'CC',
        'tagline': tagline,
        'whatsappWelcomeTemplate': _whatsappTemplateController.text.trim(),
        'receiptFooterText': _receiptFooterController.text.trim(),
        'renewalReminderDays': _reminderDays,
        'upiId': _upiIdController.text.trim(),
        'wifiSsid': _wifiSsidController.text.trim(),
        'wifiPassword': _wifiPasswordController.text.trim(),
        'enableGstBilling': _enableGstBilling,
        'gstin': _gstinController.text.trim().toUpperCase(),
        'gstLegalName': _gstLegalNameController.text.trim(),
        'sacCode': _sacCodeController.text.trim().isNotEmpty ? _sacCodeController.text.trim() : '999293',
        'gstRate': _gstRate,
        'logoUrl': _logoUrl ?? '',
        'accentColor': _selectedAccentColor,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also sync UPI ID to payment_methods subcollection if present
      if (_upiIdController.text.trim().isNotEmpty) {
        FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('settings')
            .doc('payment_methods')
            .set({
              'upiId': _upiIdController.text.trim(),
              'payeeName': _nameController.text.trim(),
            }, SetOptions(merge: true))
            .catchError((_) {});
      }

      // Also sync GSTIN to payment_methods subcollection if enabled
      if (_enableGstBilling && _gstinController.text.trim().isNotEmpty) {
        FirebaseFirestore.instance
            .collection('libraries')
            .doc(libraryId)
            .collection('settings')
            .doc('payment_methods')
            .set({
              'gstin': _gstinController.text.trim().toUpperCase(),
            }, SetOptions(merge: true))
            .catchError((_) {});
      }

      // Cache immediately to SharedPreferences for instant splash and offline load
      try {
        final prefs = ref.read(sharedPreferencesProvider);
        prefs.setString('cached_library_name', _nameController.text.trim());
        if (_logoUrl != null && _logoUrl!.isNotEmpty) {
          prefs.setString('cached_library_logo_url', _logoUrl!);
        } else {
          prefs.remove('cached_library_logo_url');
        }
        if (tagline.isNotEmpty) {
          prefs.setString('cached_library_tagline', tagline);
        }
        prefs.setInt('cached_library_accent_color', _selectedAccentColor);
      } catch (_) { /* intentionally silent */ }

      // Invalidate cached library data
      ref.invalidate(currentLibraryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Library profile updated successfully!'),
              ],
            ),
            backgroundColor: Color(0xFF15803D),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'announcement');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  ImageProvider? _getLogoImage() {
    if (_logoUrl == null || _logoUrl!.isEmpty) return null;
    if (_logoUrl!.startsWith('data:image')) {
      final base64String = _logoUrl!.split(',').last;
      return MemoryImage(base64Decode(base64String));
    }
    return NetworkImage(_logoUrl!);
  }

  Future<void> _showAddCustomFacilityDialog() async {
    final customCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Facility / Amenity'),
        content: TextField(
          controller: customCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Facility Name',
            hintText: 'e.g. Dedicated Discussion Room',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, customCtrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        if (!_selectedFacilities.contains(result)) {
          _selectedFacilities.add(result);
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _membershipPrefixController.dispose();
    _hoursController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _googleMapsController.dispose();
    _adminNameController.dispose();
    _ownerNameController.dispose();
    _managerNameController.dispose();
    _managerContactController.dispose();
    _welcomeController.dispose();
    _upiIdController.dispose();
    _wifiSsidController.dispose();
    _wifiPasswordController.dispose();
    _whatsappTemplateController.dispose();
    _receiptFooterController.dispose();
    _hexColorController.dispose();
    _gstinController.dispose();
    _gstLegalNameController.dispose();
    _sacCodeController.dispose();
    super.dispose();
  }

  List<Widget> _buildCategorizedFacilities(ThemeData theme) {
    const facilityCategories = <String, List<Map<String, dynamic>>>{
      'Study Ambience & Environment': [
        {'name': 'Silent Study Zone', 'icon': Icons.volume_off_rounded},
        {'name': 'Ergonomic Chairs', 'icon': Icons.chair_rounded},
        {'name': 'Air Conditioning (AC)', 'icon': Icons.ac_unit_rounded},
      ],
      'Power & Connectivity': [
        {'name': 'High-Speed Wi-Fi', 'icon': Icons.wifi_rounded},
        {'name': 'Power Sockets at Desk', 'icon': Icons.power_rounded},
      ],
      'Safety & Refreshments': [
        {'name': 'Purified RO Water', 'icon': Icons.water_drop_rounded},
        {'name': 'CCTV Surveillance', 'icon': Icons.videocam_rounded},
        {'name': 'Pantry & Cafeteria', 'icon': Icons.coffee_rounded},
      ],
      'Convenience & Amenities': [
        {'name': 'Personal Locker', 'icon': Icons.lock_rounded},
        {'name': 'Two-Wheeler / Car Parking', 'icon': Icons.local_parking_rounded},
        {'name': 'Daily Newspapers & Magazines', 'icon': Icons.menu_book_rounded},
      ],
    };

    final standardNames = _standardFacilities.toSet();

    final customFacilities = _selectedFacilities
        .where((f) => !standardNames.contains(f))
        .toList();

    final widgets = <Widget>[];

    facilityCategories.forEach((categoryTitle, items) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 6.0),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                categoryTitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      );

      widgets.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) {
            final name = item['name'] as String;
            final icon = item['icon'] as IconData;
            final isSelected = _selectedFacilities.contains(name);

            return FilterChip(
              selected: isSelected,
              showCheckmark: true,
              avatar: isSelected ? null : Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
              label: Text(
                name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.7)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              selectedColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              checkmarkColor: theme.colorScheme.primary,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    if (!_selectedFacilities.contains(name)) _selectedFacilities.add(name);
                  } else {
                    _selectedFacilities.remove(name);
                  }
                });
              },
            );
          }).toList(),
        ),
      );

      widgets.add(const SizedBox(height: 8));
    });

    if (customFacilities.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 6.0),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.teal,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Custom Organization Amenities',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
        ),
      );

      widgets.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: customFacilities.map((name) {
            return Chip(
              label: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              deleteIcon: const Icon(Icons.close_rounded, size: 16),
              onDeleted: () {
                setState(() => _selectedFacilities.remove(name));
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.teal.withValues(alpha: 0.5)),
              ),
              backgroundColor: Colors.teal.withValues(alpha: 0.12),
            );
          }).toList(),
        ),
      );
    }

    // Student 1-Tap Wi-Fi Hotspot Configuration
    widgets.add(const SizedBox(height: 14));
    widgets.add(
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wifi_rounded, size: 18, color: Color(0xFF0284C7)),
                const SizedBox(width: 8),
                const Text(
                  'Student 1-Tap Wi-Fi Hotspot',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('1-Tap Copy', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Enrolled students can copy this password with a single tap in their app to connect laptops and phones.',
              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            _buildTwoColRow(
              left: TextFormField(
                controller: _wifiSsidController,
                decoration: const InputDecoration(
                  labelText: 'Wi-Fi Network Name (SSID)',
                  hintText: 'e.g. CozyCorner_5G',
                  prefixIcon: Icon(Icons.network_wifi_rounded),
                  isDense: true,
                  filled: true,
                ),
              ),
              right: TextFormField(
                controller: _wifiPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Wi-Fi Password',
                  hintText: 'e.g. Study@Cozy2026',
                  prefixIcon: Icon(Icons.password_rounded),
                  isDense: true,
                  filled: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return widgets;
  }

  Widget _buildTwoColRow({required Widget left, required Widget right}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 560) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 14),
              Expanded(child: right),
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              left,
              const SizedBox(height: 12),
              right,
            ],
          );
        }
      },
    );
  }

  Widget _buildBentoCard({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildBrandPaletteCard(ThemeData theme) {
    final currentColor = Color(_selectedAccentColor);
    final isDark = theme.brightness == Brightness.dark;

    return _buildBentoCard(
      theme: theme,
      icon: Icons.palette_rounded,
      iconColor: currentColor,
      title: 'Brand Palette & Theme Customization',
      subtitle: 'Personalize your primary colors across admin consoles, student portals, and passes',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: currentColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: currentColor.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: currentColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _hexColorController.text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: currentColor,
              ),
            ),
          ],
        ),
      ),
      children: [
        // 1. Live Interactive Preview Canvas
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.black26 : currentColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: currentColor.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.visibility_rounded, size: 16, color: currentColor),
                  const SizedBox(width: 8),
                  Text(
                    'Real-Time Theme Preview',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: currentColor,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: currentColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'PREVIEW',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: currentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add_task_rounded, size: 16),
                    label: const Text('Primary Action'),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: currentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: currentColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 14, color: currentColor),
                        const SizedBox(width: 6),
                        Text(
                          'Active Status Pill',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: currentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chair_rounded, size: 14, color: currentColor),
                        const SizedBox(width: 6),
                        Text(
                          'Desk 12 • Reserved',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
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

        // 2. Curated Palette Presets Grid
        const Text(
          'Curated Executive & Academic Palettes',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 240,
            mainAxisExtent: 68,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _brandColorPresets.length,
          itemBuilder: (context, index) {
            final preset = _brandColorPresets[index];
            final pColor = preset['color'] as Color;
            final isSelected = _selectedAccentColor == pColor.toARGB32();

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedAccentColor = pColor.toARGB32();
                  _hexColorController.text = preset['hex'] as String;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? pColor.withValues(alpha: 0.12)
                      : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? pColor : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: pColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: pColor.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            preset['name'] as String,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? pColor : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            preset['subtitle'] as String,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 18),
        const Divider(height: 1),
        const SizedBox(height: 16),

        // 3. Custom Hex Color Input Field
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _hexColorController,
                decoration: InputDecoration(
                  labelText: 'Custom Brand Hex Code',
                  hintText: '#1E3A8A',
                  helperText: 'Enter any 6-digit RGB Hex color (e.g. #065F46 or 1E3A8A)',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: currentColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: currentColor.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (val) {
                  final clean = val.replaceAll('#', '').trim();
                  if (clean.length == 6) {
                    final intVal = int.tryParse('FF$clean', radix: 16);
                    if (intVal != null) {
                      setState(() {
                        _selectedAccentColor = intVal;
                      });
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGstBillingCard(ThemeData theme) {
    return _buildBentoCard(
      theme: theme,
      icon: Icons.receipt_long_rounded,
      iconColor: const Color(0xFF0D9488),
      title: 'B2B GST Commercial Tax Invoicing',
      subtitle: 'Organization-level tax invoicing toggle, legal name, GSTIN & SAC code breakdown',
      trailing: Switch.adaptive(
        value: _enableGstBilling,
        activeTrackColor: const Color(0xFF0D9488),
        onChanged: (val) {
          setState(() {
            _enableGstBilling = val;
          });
        },
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _enableGstBilling
                ? const Color(0xFF0D9488).withValues(alpha: 0.08)
                : theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _enableGstBilling
                  ? const Color(0xFF0D9488).withValues(alpha: 0.3)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _enableGstBilling ? Icons.verified_user_rounded : Icons.info_outline_rounded,
                size: 20,
                color: _enableGstBilling ? const Color(0xFF0D9488) : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _enableGstBilling
                      ? 'GST Billing Active: Receipts will be generated as "TAX INVOICE" with SAC 999293, itemized Taxable Value, CGST and SGST line items.'
                      : 'GST Billing Disabled: Standard institutional receipts will be generated without tax breakdown.',
                  style: TextStyle(
                    fontSize: 12,
                    color: _enableGstBilling ? const Color(0xFF0F766E) : theme.colorScheme.onSurfaceVariant,
                    fontWeight: _enableGstBilling ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_enableGstBilling) ...[
          const SizedBox(height: 14),
          _buildTwoColRow(
            left: TextFormField(
              controller: _gstinController,
              decoration: const InputDecoration(
                labelText: 'GSTIN (15 Characters) *',
                hintText: 'e.g. 27AAAAA0000A1Z5',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.pin_outlined),
                helperText: 'Mandatory for registered commercial tax entities',
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (v) => _enableGstBilling ? AppValidators.gstin(v, required: true) : null,
            ),
            right: TextFormField(
              controller: _gstLegalNameController,
              decoration: const InputDecoration(
                labelText: 'Registered Entity / Legal Trade Name',
                hintText: 'e.g. Cozy Corner Educational LLP',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.corporate_fare_rounded),
                helperText: 'Printed on official tax invoices',
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ),
          const SizedBox(height: 12),
          _buildTwoColRow(
            left: TextFormField(
              controller: _sacCodeController,
              decoration: const InputDecoration(
                labelText: 'Service Accounting Code (SAC)',
                hintText: '999293',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category_outlined),
                helperText: 'SAC 999293: Commercial Training & Coaching / Educational Services',
              ),
            ),
            right: DropdownButtonFormField<double>(
              initialValue: _gstRate,
              decoration: const InputDecoration(
                labelText: 'Applicable GST Tax Rate Slab',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.percent_rounded),
                helperText: 'Split equally into CGST & SGST',
              ),
              items: const [
                DropdownMenuItem(value: 18.0, child: Text('18% (9% CGST + 9% SGST) — Standard')),
                DropdownMenuItem(value: 12.0, child: Text('12% (6% CGST + 6% SGST)')),
                DropdownMenuItem(value: 5.0, child: Text('5% (2.5% CGST + 2.5% SGST)')),
                DropdownMenuItem(value: 0.0, child: Text('0% (Exempt Service)')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _gstRate = val);
              },
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLogo = _logoUrl != null && _logoUrl!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library Profile'),
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: _isSaving ? null : _saveProfile,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text('Save Profile'),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                    children: [
                      // ── Hero Logo & Institutional Branding Card ──────────
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
                              theme.colorScheme.surface,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(alpha: 0.05),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                GestureDetector(
                                  onTap: hasLogo
                                      ? () => ImageService.showImageViewer(
                                            context,
                                            imageUrl: _logoUrl,
                                            title: 'Library Logo',
                                          )
                                      : _pickLogo,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: theme.colorScheme.primary,
                                        width: 2.5,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 52,
                                      backgroundColor: theme.colorScheme.primaryContainer,
                                      backgroundImage: _getLogoImage(),
                                      child: !hasLogo
                                          ? Text(
                                              _nameController.text.isNotEmpty
                                                  ? _nameController.text[0].toUpperCase()
                                                  : 'CC',
                                              style: TextStyle(
                                                fontSize: 42,
                                                fontWeight: FontWeight.bold,
                                                color: theme.colorScheme.primary,
                                              ),
                                            )
                                          : null,
                                    ),
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
                                  bottom: 4,
                                  right: 4,
                                  child: Material(
                                    color: theme.colorScheme.primary,
                                    shape: const CircleBorder(),
                                    elevation: 4,
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: _pickLogo,
                                      child: const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _nameController.text.isNotEmpty ? _nameController.text : 'The Cozy Corner Study Centre',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            if (_taglineController.text.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                _taglineController.text,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              'Visual brand across student portals, dynamic receipts & printed ID passes',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _pickLogo,
                                  icon: const Icon(Icons.upload_rounded, size: 16),
                                  label: Text(hasLogo ? 'Change Library Logo' : 'Upload Library Logo'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (hasLogo)
                                  TextButton.icon(
                                    onPressed: () => setState(() => _logoUrl = null),
                                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                    label: const Text('Remove Logo', style: TextStyle(color: Colors.red, fontSize: 12)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // ── 0. Brand Palette & Theme Studio ─────────────────
                      _buildBrandPaletteCard(theme),

                      // ── 1. Basic Identity & Branding ─────────────────────
                      _buildBentoCard(
                        theme: theme,
                        icon: Icons.apartment_rounded,
                        iconColor: theme.colorScheme.primary,
                        title: 'Basic Identity & Branding',
                        subtitle: 'Official library naming, institutional tagline, prefix and daily hours',
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Library Name *',
                              hintText: 'e.g. The Cozy Corner Study Centre',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.business_rounded),
                            ),
                            textCapitalization: TextCapitalization.words,
                            validator: (v) => AppValidators.name(v, required: true, label: 'Library Name'),
                          ),
                          const SizedBox(height: 14),
                          _buildTwoColRow(
                            left: TextFormField(
                              controller: _taglineController,
                              decoration: const InputDecoration(
                                labelText: 'Tagline / Motto',
                                hintText: 'e.g. Smart Study Center & Silent Reading Hall',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.format_quote_rounded),
                                helperText: 'Displayed on student mobile login, QR posters & receipts',
                              ),
                              maxLength: 80,
                            ),
                            right: TextFormField(
                              controller: _membershipPrefixController,
                              decoration: const InputDecoration(
                                labelText: 'Membership ID Prefix',
                                hintText: 'e.g. CC',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.badge_outlined),
                                helperText: 'Generates prefixed IDs like CC20260001',
                              ),
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _hoursController,
                            decoration: const InputDecoration(
                              labelText: 'Operating Hours',
                              hintText: 'e.g. 06:00 AM – 11:00 PM',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.schedule_rounded),
                              helperText: 'Displayed on the entrance QR poster and student admission passes',
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (final preset in [
                                '06:00 AM – 11:00 PM',
                                '24 Hours Open (24x7)',
                                '07:00 AM – 10:00 PM',
                                '05:00 AM – 12:00 AM',
                              ])
                                ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(preset, style: const TextStyle(fontSize: 11)),
                                  onPressed: () => setState(() => _hoursController.text = preset),
                                ),
                            ],
                          ),
                        ],
                      ),

                      // ── 2. Contact & Physical Location ────────────────────
                      _buildBentoCard(
                        theme: theme,
                        icon: Icons.contact_phone_rounded,
                        iconColor: const Color(0xFF047857),
                        title: 'Contact & Physical Location',
                        subtitle: 'Official helpline, WhatsApp notifications channel, and physical address',
                        children: [
                          _buildTwoColRow(
                            left: TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Primary Helpline / Phone *',
                                hintText: '9403243830',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.phone_in_talk_outlined),
                                helperText: 'Primary official number printed on receipts & posters',
                              ),
                              keyboardType: TextInputType.phone,
                              inputFormatters: AppValidators.phoneFormatters,
                              validator: (v) => AppValidators.phone(v, required: true, label: 'Contact Phone'),
                            ),
                            right: TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Official Email',
                                hintText: 'e.g. thecozycornersc@gmail.com',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.email_outlined),
                                helperText: 'For official invoices and administrative notices',
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => AppValidators.email(v, required: false, label: 'Contact Email'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Clean WhatsApp Sync Toggle
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _sameAsWhatsApp,
                                  onChanged: (val) {
                                    setState(() {
                                      _sameAsWhatsApp = val ?? true;
                                      if (_sameAsWhatsApp) {
                                        _whatsappController.text = _phoneController.text;
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _sameAsWhatsApp = !_sameAsWhatsApp;
                                        if (_sameAsWhatsApp) {
                                          _whatsappController.text = _phoneController.text;
                                        }
                                      });
                                    },
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Use same number for WhatsApp Broadcasts',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          _sameAsWhatsApp
                                              ? 'Welcome alerts and renewal receipts will be sent from ${_phoneController.text.isNotEmpty ? _phoneController.text : "the helpline"}'
                                              : 'Custom separate WhatsApp number configured below',
                                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!_sameAsWhatsApp) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _whatsappController,
                              decoration: const InputDecoration(
                                labelText: 'Dedicated WhatsApp Number',
                                hintText: 'e.g. 9403243830',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.chat_outlined),
                                helperText: 'Direct WhatsApp API sender phone number',
                              ),
                              keyboardType: TextInputType.phone,
                              inputFormatters: AppValidators.phoneFormatters,
                              validator: (v) => _sameAsWhatsApp
                                  ? null
                                  : AppValidators.phone(v, required: true, label: 'WhatsApp Number'),
                            ),
                          ],
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              labelText: 'Physical Address',
                              hintText: 'e.g. Front Of Reliance Fashion Factory, Nath Road, Parli-431515',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.location_on_outlined),
                              helperText: 'Displayed on invoices, entrance posters & digital ID cards',
                            ),
                            maxLines: 2,
                            validator: (v) => AppValidators.address(v, required: false, label: 'Address'),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _googleMapsController,
                            decoration: InputDecoration(
                              labelText: 'Google Maps Navigation Link',
                              hintText: 'e.g. https://maps.app.goo.gl/...',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.map_outlined),
                              suffixIcon: _googleMapsController.text.trim().isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.open_in_new_rounded),
                                      tooltip: 'Test Navigation Link',
                                      onPressed: () async {
                                        final raw = _googleMapsController.text.trim();
                                        final uri = Uri.tryParse(raw);
                                        if (uri != null) {
                                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                                        }
                                      },
                                    )
                                  : null,
                              helperText: 'Used for 1-tap student directions, WhatsApp location messages, & portal sharing',
                            ),
                            keyboardType: TextInputType.url,
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),

                      // ── 3. Personnel & Administration ─────────────────────
                      _buildBentoCard(
                        theme: theme,
                        icon: Icons.badge_rounded,
                        iconColor: Colors.blue.shade700,
                        title: 'Personnel & Administration',
                        subtitle: 'Primary administrator details and optional staff desk contacts',
                        children: [
                          TextFormField(
                            controller: _adminNameController,
                            decoration: const InputDecoration(
                              labelText: 'Administrator / Owner Name *',
                              hintText: 'e.g. Sanket Shahane',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person_outline_rounded),
                              helperText: 'Displayed as authorized signatory and primary admin contact',
                            ),
                            textCapitalization: TextCapitalization.words,
                            validator: (v) => AppValidators.name(v, required: true, label: 'Admin Name'),
                          ),
                          const SizedBox(height: 12),
                          // Optional Manager / Supervisor Expansion
                          Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                            ),
                            child: Theme(
                              data: theme.copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                initiallyExpanded: _showManagerDetails,
                                onExpansionChanged: (exp) => setState(() => _showManagerDetails = exp),
                                leading: Icon(Icons.support_agent_rounded, size: 20, color: Colors.teal.shade700),
                                title: const Text(
                                  'Add Dedicated Manager / Staff (Optional)',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  _showManagerDetails
                                      ? 'Custom supervisor phone shown in student emergency rails'
                                      : 'Tap to configure separate shift manager or receptionist',
                                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                                    child: _buildTwoColRow(
                                      left: TextFormField(
                                        controller: _managerNameController,
                                        decoration: const InputDecoration(
                                          labelText: 'Manager Name',
                                          hintText: 'e.g. Rahul Deshmukh',
                                          border: OutlineInputBorder(),
                                          prefixIcon: Icon(Icons.person_pin_outlined),
                                          isDense: true,
                                        ),
                                        textCapitalization: TextCapitalization.words,
                                      ),
                                      right: TextFormField(
                                        controller: _managerContactController,
                                        decoration: const InputDecoration(
                                          labelText: 'Manager Phone',
                                          hintText: 'e.g. 9876543210',
                                          border: OutlineInputBorder(),
                                          prefixIcon: Icon(Icons.phone_outlined),
                                          isDense: true,
                                        ),
                                        keyboardType: TextInputType.phone,
                                        inputFormatters: AppValidators.phoneFormatters,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // ── 3.5 B2B GST Commercial Tax Invoicing ─────────────
                      _buildGstBillingCard(theme),

                      // ── 4. Study Privileges & Facilities (Arranged to Industry Standards) ──
                      _buildBentoCard(
                        theme: theme,
                        icon: Icons.room_service_rounded,
                        iconColor: Colors.amber.shade800,
                        title: 'Study Privileges & Facilities',
                        subtitle: 'Check ONLY amenities provided. Categorized according to study centre standards.',
                        trailing: OutlinedButton.icon(
                          onPressed: _showAddCustomFacilityDialog,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Custom', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        children: [
                          // Industry Standard Categories
                          ..._buildCategorizedFacilities(theme),
                        ],
                      ),

                      // ── 5. Quick Links to Dedicated Configuration Hubs ─────
                      _buildBentoCard(
                        theme: theme,
                        icon: Icons.tune_rounded,
                        iconColor: const Color(0xFF6366F1),
                        title: 'Dedicated System Configurations',
                        subtitle: 'Manage specialized payment gateways, invoices, and automated communications',
                        children: [
                          // 1. Payment Methods Hub Link
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.payment_rounded, color: Color(0xFF059669), size: 20),
                            ),
                            title: const Text('Payment Methods & UPI Gateway', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              _upiIdController.text.isNotEmpty
                                  ? 'Active UPI ID: ${_upiIdController.text}'
                                  : 'Configure dynamic UPI QR, Cash on desk & bank accounts',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                            onTap: () => context.push(Routes.adminPaymentMethods),
                          ),
                          const Divider(height: 1),
                          // 2. Receipt Template Customizer Link
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD97706).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFD97706), size: 20),
                            ),
                            title: const Text('Receipt & Invoice Layout Customizer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Customize invoice headers, GSTIN, terms & conditions', style: TextStyle(fontSize: 11)),
                            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                            onTap: () => context.push(Routes.adminReceiptTemplate),
                          ),
                          const Divider(height: 1),
                          // 3. Communications Hub Link
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.hub_rounded, color: Color(0xFF2563EB), size: 20),
                            ),
                            title: const Text('Communications & Automation Hub', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Broadcasts, automated renewal alerts, and notification channels', style: TextStyle(fontSize: 11)),
                            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                            onTap: () => context.go(Routes.adminCommunications),
                          ),
                          const SizedBox(height: 10),
                          // Optional In-Place Template Overrides (Clean Accordion)
                          Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                            ),
                            child: Theme(
                              data: theme.copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                leading: const Icon(Icons.code_rounded, size: 18),
                                title: const Text('Advanced In-Place Template Overrides', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                subtitle: const Text('Edit WhatsApp raw template, receipt footer & expiry alerts directly', style: TextStyle(fontSize: 10.5)),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        TextFormField(
                                          controller: _upiIdController,
                                          decoration: const InputDecoration(
                                            labelText: 'Library UPI ID / VPA',
                                            hintText: 'e.g. 7276959070@upi',
                                            border: OutlineInputBorder(),
                                            prefixIcon: Icon(Icons.qr_code_2_rounded),
                                            isDense: true,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        const Text('WhatsApp Welcome Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        const SizedBox(height: 4),
                                        TextFormField(
                                          controller: _whatsappTemplateController,
                                          maxLines: 4,
                                          decoration: const InputDecoration(
                                            hintText: MessageTemplateService.defaultWelcomeTemplate,
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 4,
                                          runSpacing: 4,
                                          children: MessageTemplateService.availableVariables.take(8).map((v) => ActionChip(
                                            label: Text(v, style: const TextStyle(fontSize: 10)),
                                            padding: EdgeInsets.zero,
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
                                                selection: TextSelection.collapsed(
                                                  offset: (selection.start < 0 ? ctrl.text.length : selection.start) + v.length,
                                                ),
                                              );
                                            },
                                          )).toList(),
                                        ),
                                        const SizedBox(height: 12),
                                        const Text('Receipt Footer Text', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        const SizedBox(height: 4),
                                        TextFormField(
                                          controller: _receiptFooterController,
                                          maxLines: 2,
                                          decoration: const InputDecoration(
                                            hintText: MessageTemplateService.defaultReceiptFooter,
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        const Text('Plan Expiry Reminder Window', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        const SizedBox(height: 4),
                                        DropdownButtonFormField<String>(
                                          initialValue: _reminderDays.toString(),
                                          items: ['3', '5', '7', '10', '14', '30'].map((d) =>
                                            DropdownMenuItem(value: d, child: Text('$d days before expiry'))
                                          ).toList(),
                                          onChanged: (v) => setState(() => _reminderDays = int.tryParse(v ?? '7') ?? 7),
                                          decoration: const InputDecoration(
                                            border: OutlineInputBorder(),
                                            prefixIcon: Icon(Icons.alarm_rounded),
                                            isDense: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // ── Primary Bottom Save Action ────────────────────────
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _saveProfile,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save_rounded, size: 20),
                          label: Text(
                            _isSaving ? 'Saving Profile...' : 'Save Library Profile',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
