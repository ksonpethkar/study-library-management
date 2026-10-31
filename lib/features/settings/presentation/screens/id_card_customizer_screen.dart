import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/models/id_card_template_model.dart';
import 'package:study_library/core/widgets/brand_color_picker_dialog.dart';

final idCardTemplateProvider = StreamProvider<IdCardTemplateSettings>((ref) {
  final libraryId = ref.watch(currentLibraryIdProvider);
  if (libraryId == null || libraryId.isEmpty) {
    return Stream.value(const IdCardTemplateSettings());
  }

  return FirebaseFirestore.instance
      .collection('libraries')
      .doc(libraryId)
      .collection('settings')
      .doc('id_card_template')
      .snapshots()
      .map((doc) {
    if (!doc.exists || doc.data() == null) {
      return const IdCardTemplateSettings();
    }
    return IdCardTemplateSettings.fromJson(doc.data()!);
  });
});

class IdCardCustomizerScreen extends ConsumerStatefulWidget {
  const IdCardCustomizerScreen({super.key});

  @override
  ConsumerState<IdCardCustomizerScreen> createState() => _IdCardCustomizerScreenState();
}

class _IdCardCustomizerScreenState extends ConsumerState<IdCardCustomizerScreen> {
  IdCardTemplateSettings _settings = const IdCardTemplateSettings();
  final _rulesController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _rulesController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('id_card_template')
          .get();

      if (doc.exists && mounted && doc.data() != null) {
        final s = IdCardTemplateSettings.fromJson(doc.data()!);
        setState(() {
          _settings = s;
          _rulesController.text = s.customRulesText;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    final libraryId = ref.read(currentLibraryIdProvider);
    if (libraryId == null || libraryId.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final updated = _settings.copyWith(customRulesText: _rulesController.text.trim());
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('id_card_template')
          .set({
        ...updated.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ref.invalidate(idCardTemplateProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ID Card template saved! Reflected in admin and student app.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Customize ID Card')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customize ID Card Layout'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded),
            tooltip: 'Save Settings',
            onPressed: _isSaving ? null : _saveSettings,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            children: [
              _buildLivePreviewCard(context),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.palette_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ID Card Design Theme',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Select the official color palette used across student digital ID cards and passes.',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                  ...[
                    {
                      'id': 'royalNavy',
                      'title': 'Royal Navy (Recommended)',
                      'subtitle': 'Deep sapphire & ice blue — modern academic',
                      'primary': const Color(0xFF1E3A8A),
                      'secondary': const Color(0xFF0284C7),
                    },
                    {
                      'id': 'emeraldAcademic',
                      'title': 'Emerald Academic',
                      'subtitle': 'Forest jade & fresh mint — clean & professional',
                      'primary': const Color(0xFF065F46),
                      'secondary': const Color(0xFF059669),
                    },
                    {
                      'id': 'crimsonExecutive',
                      'title': 'Crimson Executive',
                      'subtitle': 'Deep ruby & soft rose — executive seal',
                      'primary': const Color(0xFF881337),
                      'secondary': const Color(0xFFBE123C),
                    },
                    {
                      'id': 'darkSlate',
                      'title': 'Slate Modern',
                      'subtitle': 'Charcoal black & cool steel — high contrast minimalist',
                      'primary': const Color(0xFF1E293B),
                      'secondary': const Color(0xFF475569),
                    },
                    {
                      'id': 'amberClassic',
                      'title': 'Amber Classic',
                      'subtitle': 'Warm leather & golden amber — traditional library',
                      'primary': const Color(0xFF78350F),
                      'secondary': const Color(0xFFB45309),
                    },
                    {
                      'id': 'amethystPurple',
                      'title': 'Amethyst Purple',
                      'subtitle': 'Deep violet & vivid purple — contemporary premium',
                      'primary': const Color(0xFF4C1D95),
                      'secondary': const Color(0xFF7C3AED),
                    },
                    {
                      'id': 'customBrand',
                      'title': 'Library Brand Accent',
                      'subtitle': 'Matches your library brand color configured in Settings',
                      'primary': Theme.of(context).colorScheme.primary,
                      'secondary': Theme.of(context).colorScheme.secondary,
                    },
                  ].map((theme) {
                    final themeId = theme['id'] as String;
                    final isSelected = _settings.cardTheme == themeId;
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _settings = _settings.copyWith(cardTheme: themeId)),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                            width: isSelected ? 2 : 1,
                          ),
                          color: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25)
                              : Colors.transparent,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme['primary'] as Color,
                                border: Border.all(color: theme['secondary'] as Color, width: 2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    theme['title'] as String,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    theme['subtitle'] as String,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                              color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      final currentHex = _settings.customColorHex ?? _settings.cardTheme;
                      final initial = currentHex.startsWith('#')
                          ? Color(int.parse('FF${currentHex.replaceAll('#', '')}', radix: 16))
                          : const Color(0xFF881337);
                      final chosen = await BrandColorPickerDialog.show(
                        context,
                        initialColor: initial,
                        title: 'Pick Custom Card Color',
                      );
                      if (chosen != null && mounted) {
                        final hex = '#${chosen.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
                        setState(() => _settings = _settings.copyWith(cardTheme: hex, customColorHex: hex));
                      }
                    },
                    icon: const Icon(Icons.colorize_rounded),
                    label: Text(
                      _settings.cardTheme.startsWith('#')
                          ? 'Custom Brand Color: ${_settings.cardTheme}'
                          : 'Choose Custom Color Picker...',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.badge_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Front Card Elements', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            Text('Student identity, QR verification & seat metadata', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Student Photo'),
                    subtitle: const Text('Show passport photo on the left'),
                    value: _settings.showPhoto,
                    onChanged: (v) => setState(() => _settings = _settings.copyWith(showPhoto: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Verification QR Code'),
                    subtitle: const Text('Scan to verify active membership'),
                    value: _settings.showQrCode,
                    onChanged: (v) => setState(() => _settings = _settings.copyWith(showQrCode: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Assigned Seat & Section'),
                    subtitle: const Text('e.g. A-12 (Main Hall)'),
                    value: _settings.showSeat,
                    onChanged: (v) => setState(() => _settings = _settings.copyWith(showSeat: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Membership Plan Name'),
                    subtitle: const Text('e.g. Dedicated Desk (Monthly)'),
                    value: _settings.showPlan,
                    onChanged: (v) => setState(() => _settings = _settings.copyWith(showPlan: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Validity Expiration Date'),
                    subtitle: const Text('Valid Till: DD/MM/YYYY'),
                    value: _settings.showValidTill,
                    onChanged: (v) => setState(() => _settings = _settings.copyWith(showValidTill: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Library Address & Helpline Footer'),
                    value: _settings.showAddress,
                    onChanged: (v) => setState(() => _settings = _settings.copyWith(showAddress: v)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.contact_phone_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Back Card Elements & Certification', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            Text('Guardian info, emergency contact & official rubber seal', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Guardian / Father Name'),
                    value: _settings.showFatherName,
                    onChanged: (v) => setState(() => _settings = _settings.copyWith(showFatherName: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Emergency Contact Badge'),
                    subtitle: const Text('Emergency contact number highlighted on back'),
                    value: _settings.showEmergencyContact,
                    onChanged: (v) => setState(() => _settings = _settings.copyWith(showEmergencyContact: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Library Rules & Guidelines'),
                    value: _settings.showRules,
                    onChanged: (v) => setState(() => _settings = _settings.copyWith(showRules: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Official Rubber Stamp / Seal'),
                    subtitle: const Text('Display certified organizational seal on back'),
                    value: _settings.showStamp,
                    onChanged: (v) => setState(() => _settings = _settings.copyWith(showStamp: v)),
                  ),
                  SwitchListTile(
                    title: const Text('Authorized Signatory Line'),
                    subtitle: const Text('Display administrative signature authorization on back'),
                    value: _settings.showSignature,
                    onChanged: (v) => setState(() => _settings = _settings.copyWith(showSignature: v)),
                  ),
                  if (_settings.showRules) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _rulesController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Custom Terms / Rules (Optional, 1 per line)',
                        hintText: 'Leave empty for default library rules',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSaving ? null : _saveSettings,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded),
              label: Text(_isSaving ? 'Saving...' : 'Save ID Card Settings', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildLivePreviewCard(BuildContext context) {
    Color primaryColor;
    Color secondaryColor;
    String themeDisplayName;

    final customHex = _settings.customColorHex ?? _settings.cardTheme;
    if (customHex.startsWith('#') || RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(customHex)) {
      final clean = customHex.replaceAll('#', '');
      final col = Color(int.parse('FF$clean', radix: 16));
      primaryColor = col;
      secondaryColor = col;
      themeDisplayName = 'Custom Brand (#$clean)';
    } else {
      switch (_settings.cardTheme) {
        case 'royalNavy':
          primaryColor = const Color(0xFF1E3A8A);
          secondaryColor = const Color(0xFF0284C7);
          themeDisplayName = 'Royal Navy';
          break;
        case 'emeraldAcademic':
          primaryColor = const Color(0xFF065F46);
          secondaryColor = const Color(0xFF059669);
          themeDisplayName = 'Emerald Academic';
          break;
        case 'crimsonExecutive':
          primaryColor = const Color(0xFF881337);
          secondaryColor = const Color(0xFFBE123C);
          themeDisplayName = 'Crimson Executive';
          break;
        case 'darkSlate':
          primaryColor = const Color(0xFF1E293B);
          secondaryColor = const Color(0xFF475569);
          themeDisplayName = 'Slate Modern';
          break;
        case 'amberClassic':
          primaryColor = const Color(0xFF78350F);
          secondaryColor = const Color(0xFFB45309);
          themeDisplayName = 'Amber Classic';
          break;
        case 'amethystPurple':
          primaryColor = const Color(0xFF4C1D95);
          secondaryColor = const Color(0xFF7C3AED);
          themeDisplayName = 'Amethyst Purple';
          break;
        case 'customBrand':
        default:
          primaryColor = Theme.of(context).colorScheme.primary;
          secondaryColor = Theme.of(context).colorScheme.secondary;
          themeDisplayName = 'Library Brand Accent';
          break;
      }
    }

    final libraryName = ref.watch(currentLibraryProvider).value?.name ?? 'Study Library';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: primaryColor.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Theme badge header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    libraryName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    themeDisplayName,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Card Body
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (_settings.showPhoto) ...[
                  Container(
                    width: 58,
                    height: 68,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: primaryColor.withValues(alpha: 0.4)),
                    ),
                    child: Icon(Icons.person, size: 38, color: primaryColor),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rahul Sharma',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        'ID: CC-2026-0042',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (_settings.showSeat)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Seat: A-12',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryColor),
                              ),
                            ),
                          if (_settings.showPlan)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Dedicated Desk',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blueGrey.shade800),
                              ),
                            ),
                          if (_settings.showValidTill)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Till: 31 Oct 2026',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_settings.showQrCode) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Center(
                      child: Icon(Icons.qr_code_2_rounded, size: 40, color: primaryColor),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (_settings.showAddress)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 12, color: primaryColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Builder(builder: (context) {
                      final lib = ref.watch(currentLibraryProvider).value;
                      final parts = <String>[
                        if (lib?.name != null && lib!.name.isNotEmpty) lib.name,
                        if (lib?.address != null && lib!.address.isNotEmpty) lib.address,
                        if (lib?.phone != null && lib!.phone.isNotEmpty) 'Contact: ${lib.phone}',
                      ];
                      return Text(
                        parts.isNotEmpty ? parts.join(' • ') : 'Study Library • Your Address Here',
                        style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    }),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
