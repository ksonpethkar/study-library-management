import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/models/library_model.dart';
import 'package:study_library/services/message_template_service.dart';
import 'package:study_library/services/whatsapp_service.dart';

/// Interactive WYSIWYG WhatsApp & SMS Message Template Studio.
/// Allows library administrators to personalize automated messages
/// with dynamic tags, live WhatsApp chat bubble simulation, and
/// multilingual presets (English, Hindi, Marathi).
class MessageTemplateStudioScreen extends ConsumerStatefulWidget {
  const MessageTemplateStudioScreen({super.key});

  @override
  ConsumerState<MessageTemplateStudioScreen> createState() =>
      _MessageTemplateStudioScreenState();
}

enum _TemplateType {
  welcome,
  receipt,
  dueReminder,
  expiryReminder,
  waitlistOffer,
}

class _MessageTemplateStudioScreenState
    extends ConsumerState<MessageTemplateStudioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  _TemplateType _selectedType = _TemplateType.welcome;
  String _activeLanguage = 'en'; // 'en', 'hi', 'mr'
  bool _isLoading = true;
  bool _isSaving = false;

  // Controllers for each template type
  final _welcomeController = TextEditingController();
  final _receiptController = TextEditingController();
  final _dueReminderController = TextEditingController();
  final _expiryReminderController = TextEditingController();
  final _waitlistController = TextEditingController();

  // Focus nodes
  final _welcomeFocus = FocusNode();
  final _receiptFocus = FocusNode();
  final _dueFocus = FocusNode();
  final _expiryFocus = FocusNode();
  final _waitlistFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedType = _TemplateType.values[_tabController.index];
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTemplates();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _welcomeController.dispose();
    _receiptController.dispose();
    _dueReminderController.dispose();
    _expiryReminderController.dispose();
    _waitlistController.dispose();

    _welcomeFocus.dispose();
    _receiptFocus.dispose();
    _dueFocus.dispose();
    _expiryFocus.dispose();
    _waitlistFocus.dispose();
    super.dispose();
  }

  TextEditingController get _currentController {
    switch (_selectedType) {
      case _TemplateType.welcome:
        return _welcomeController;
      case _TemplateType.receipt:
        return _receiptController;
      case _TemplateType.dueReminder:
        return _dueReminderController;
      case _TemplateType.expiryReminder:
        return _expiryReminderController;
      case _TemplateType.waitlistOffer:
        return _waitlistController;
    }
  }

  FocusNode get _currentFocus {
    switch (_selectedType) {
      case _TemplateType.welcome:
        return _welcomeFocus;
      case _TemplateType.receipt:
        return _receiptFocus;
      case _TemplateType.dueReminder:
        return _dueFocus;
      case _TemplateType.expiryReminder:
        return _expiryFocus;
      case _TemplateType.waitlistOffer:
        return _waitlistFocus;
    }
  }

  String get _currentTypeString {
    switch (_selectedType) {
      case _TemplateType.welcome:
        return 'welcome';
      case _TemplateType.receipt:
        return 'receipt';
      case _TemplateType.dueReminder:
        return 'due_reminder';
      case _TemplateType.expiryReminder:
        return 'expiry_reminder';
      case _TemplateType.waitlistOffer:
        return 'waitlist_offer';
    }
  }

  Future<void> _loadTemplates() async {
    final library = ref.read(currentLibraryProvider).value;
    if (library != null) {
      _activeLanguage = library.templateLanguage.isNotEmpty ? library.templateLanguage : 'en';

      _welcomeController.text = library.whatsappWelcomeTemplate.isNotEmpty
          ? library.whatsappWelcomeTemplate
          : MessageTemplateService.getTemplate(type: 'welcome', language: _activeLanguage);

      _receiptController.text = library.whatsappReceiptTemplate.isNotEmpty
          ? library.whatsappReceiptTemplate
          : MessageTemplateService.getTemplate(type: 'receipt', language: _activeLanguage);

      _dueReminderController.text = library.whatsappDueReminderTemplate.isNotEmpty
          ? library.whatsappDueReminderTemplate
          : MessageTemplateService.getTemplate(type: 'due_reminder', language: _activeLanguage);

      _expiryReminderController.text = library.whatsappExpiryReminderTemplate.isNotEmpty
          ? library.whatsappExpiryReminderTemplate
          : MessageTemplateService.getTemplate(type: 'expiry_reminder', language: _activeLanguage);

      _waitlistController.text = library.waitingListNotificationTemplate.isNotEmpty
          ? library.waitingListNotificationTemplate
          : MessageTemplateService.getTemplate(type: 'waitlist_offer', language: _activeLanguage);
    } else {
      _welcomeController.text = MessageTemplateService.defaultWelcomeTemplate;
      _receiptController.text = MessageTemplateService.defaultPaymentReceiptTemplate;
      _dueReminderController.text = MessageTemplateService.defaultDueReminderTemplate;
      _expiryReminderController.text = MessageTemplateService.defaultExpiryReminderTemplate;
      _waitlistController.text = MessageTemplateService.defaultWaitlistOfferTemplate;
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _insertTag(String tag) {
    final ctrl = _currentController;
    final selection = ctrl.selection;
    final text = ctrl.text;

    int start = selection.start;
    int end = selection.end;

    if (start < 0 || end < 0) {
      start = text.length;
      end = text.length;
    }

    final newText = text.replaceRange(start, end, tag);
    ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + tag.length),
    );
    _currentFocus.requestFocus();
    setState(() {});
  }

  void _applyLanguagePreset(String langCode) {
    final preset = MessageTemplateService.getTemplate(
      type: _currentTypeString,
      language: langCode,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.translate_rounded, color: Color(0xFF25D366)),
            const SizedBox(width: 8),
            Text('Apply ${langCode == "mr" ? "Marathi (मराठी)" : langCode == "hi" ? "Hindi (हिंदी)" : "English"} Preset?'),
          ],
        ),
        content: Text(
          'This will overwrite the current ${_getTabTitle(_selectedType)} template with the professionally curated ${langCode == "mr" ? "Marathi" : langCode == "hi" ? "Hindi" : "English"} preset. You can still modify it afterwards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _activeLanguage = langCode;
                _currentController.text = preset;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Applied ${langCode.toUpperCase()} preset to ${_getTabTitle(_selectedType)}! ✨'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Apply Preset'),
          ),
        ],
      ),
    );
  }

  void _resetToDefault() {
    final defaultText = MessageTemplateService.getTemplate(
      type: _currentTypeString,
      language: _activeLanguage,
    );
    setState(() {
      _currentController.text = defaultText;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Restored ${_getTabTitle(_selectedType)} default template.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sendTestWhatsApp(LibraryModel? library) async {
    final rawTemplate = _currentController.text.trim();
    if (rawTemplate.isEmpty) return;

    final previewMessage = MessageTemplateService.getLivePreview(
      rawTemplate,
      libraryName: library?.name,
      helpline: library?.phone,
      upiId: library?.upiId,
      address: library?.address,
      prefix: library?.membershipPrefix,
    );

    final phoneController = TextEditingController(text: library?.phone ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.send_to_mobile_rounded, color: Color(0xFF25D366)),
            SizedBox(width: 8),
            Text('Send Test WhatsApp'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter phone number to preview this template in your WhatsApp app:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: 'e.g. 9156944773 or +91 91569 44773',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Open WhatsApp'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final phone = phoneController.text.trim();
      if (phone.isNotEmpty) {
        await WhatsAppService().sendMessage(
          phone,
          previewMessage,
          context: context,
          title: 'Test Template Preview',
          recipientName: 'Test Recipient',
        );
      }
    }
  }

  Future<void> _saveAllTemplates() async {
    final libraryId = ref.read(currentLibraryIdProvider) ?? CurrentLibraryNotifier.defaultLibraryId;
    if (libraryId.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final firestore = FirebaseFirestore.instance;

      final dataToUpdate = {
        'whatsappWelcomeTemplate': _welcomeController.text.trim(),
        'whatsappReceiptTemplate': _receiptController.text.trim(),
        'whatsappDueReminderTemplate': _dueReminderController.text.trim(),
        'whatsappExpiryReminderTemplate': _expiryReminderController.text.trim(),
        'waitingListNotificationTemplate': _waitlistController.text.trim(),
        'templateLanguage': _activeLanguage,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 1. Update library document
      await firestore.collection('libraries').doc(libraryId).set(dataToUpdate, SetOptions(merge: true));

      // 2. Also mirror to messaging settings subdocument for unified access
      await firestore
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('messaging')
          .set({
        'templates': dataToUpdate,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Refresh Riverpod provider cache
      ref.invalidate(currentLibraryProvider);

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All WhatsApp message templates saved successfully! ✅'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error saving templates: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving templates: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getTabTitle(_TemplateType type) {
    switch (type) {
      case _TemplateType.welcome:
        return 'Admission Welcome';
      case _TemplateType.receipt:
        return 'Fee Receipt';
      case _TemplateType.dueReminder:
        return 'Due Balance';
      case _TemplateType.expiryReminder:
        return 'Plan Renewal';
      case _TemplateType.waitlistOffer:
        return 'Seat Available';
    }
  }

  IconData _getTabIcon(_TemplateType type) {
    switch (type) {
      case _TemplateType.welcome:
        return Icons.waving_hand_rounded;
      case _TemplateType.receipt:
        return Icons.receipt_long_rounded;
      case _TemplateType.dueReminder:
        return Icons.warning_amber_rounded;
      case _TemplateType.expiryReminder:
        return Icons.alarm_rounded;
      case _TemplateType.waitlistOffer:
        return Icons.event_seat_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final library = ref.watch(currentLibraryProvider).value;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 960;
    final isMobile = screenWidth <= 600;

    return Scaffold(
      appBar: AppBar(
        title: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Message Templates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('WhatsApp & SMS Studio', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                ],
              )
            : const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WhatsApp & Message Template Studio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('WYSIWYG personalization, dynamic tags & multi-language presets', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isSaving ? null : _saveAllTemplates,
              icon: _isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_rounded, size: 16),
              label: Text(_isSaving ? 'Saving...' : 'Save All', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelPadding: const EdgeInsets.symmetric(horizontal: 14),
          indicatorColor: const Color(0xFF25D366),
          indicatorWeight: 3,
          labelColor: isDark ? const Color(0xFF25D366) : const Color(0xFF075E54),
          unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
          tabs: _TemplateType.values.map((type) {
            return Tab(
              icon: Icon(_getTabIcon(type), size: 18),
              text: _getTabTitle(type),
            );
          }).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Template Editor & Dynamic Tags
                      Expanded(
                        flex: 6,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: _buildEditorSection(context, theme, library),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      // Right Column: Authentic WhatsApp Chat Simulator
                      Expanded(
                        flex: 5,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: _buildLiveSimulator(context, theme, library),
                        ),
                      ),
                    ],
                  );
                } else {
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildEditorSection(context, theme, library),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 12),
                        _buildLiveSimulator(context, theme, library),
                      ],
                    ),
                  );
                }
              },
            ),
    );
  }

  Widget _buildEditorSection(BuildContext context, ThemeData theme, LibraryModel? library) {
    final isDark = theme.brightness == Brightness.dark;
    final controller = _currentController;
    final currentText = controller.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preset Language Selector Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
          ),
          child: LayoutBuilder(
            builder: (context, boxConstraints) {
              final isCompact = boxConstraints.maxWidth < 580;
              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.language_rounded, color: Color(0xFF25D366), size: 20),
                        SizedBox(width: 8),
                        Text('Multilingual Presets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Load standard, professionally crafted templates in your preferred language',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildLanguageChoiceChip('🇬🇧 English', 'en'),
                        _buildLanguageChoiceChip('🇮🇳 हिंदी', 'hi'),
                        _buildLanguageChoiceChip('🚩 मराठी', 'mr'),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  const Icon(Icons.language_rounded, color: Color(0xFF25D366), size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Multilingual Presets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('Load standard, professionally crafted templates in your preferred language',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Wrap(
                    spacing: 6,
                    children: [
                      _buildLanguageChoiceChip('🇬🇧 English', 'en'),
                      _buildLanguageChoiceChip('🇮🇳 हिंदी', 'hi'),
                      _buildLanguageChoiceChip('🚩 मराठी', 'mr'),
                    ],
                  ),
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // Dynamic Tag Insertion Shelf
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.tag_rounded, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text('Tap to Insert Dynamic Variable Tag:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              ],
            ),
            TextButton.icon(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: _resetToDefault,
              icon: const Icon(Icons.restore_rounded, size: 15),
              label: const Text('Reset to Default', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: MessageTemplateService.variableDefinitions.map((variable) {
            return Tooltip(
              message: '${variable.description} · Example: "${variable.example}"',
              child: ActionChip(
                backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.add_circle_outline, size: 14, color: Color(0xFF25D366)),
                label: Text(
                  '${variable.label} ${variable.tag}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade200 : Colors.grey.shade800,
                  ),
                ),
                onPressed: () => _insertTag(variable.tag),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        // Text Editor Field
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_getTabTitle(_selectedType)} Template Content',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              '${currentText.length} chars · ${currentText.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length} words',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          focusNode: _currentFocus,
          maxLines: 12,
          minLines: 8,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.4),
          decoration: InputDecoration(
            hintText: 'Enter template text. Use {tag} for placeholders...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF25D366), width: 2),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          ),
        ),

        const SizedBox(height: 10),

        // Formatting Hints Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'WhatsApp formatting: *bold*, _italic_, ~strikethrough~, ```monospace```. Emoji and line breaks are fully supported.',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageChoiceChip(String label, String code) {
    final isSelected = _activeLanguage == code;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: const Color(0xFF25D366).withValues(alpha: 0.25),
      onSelected: (_) => _applyLanguagePreset(code),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildLiveSimulator(BuildContext context, ThemeData theme, LibraryModel? library) {
    final isDark = theme.brightness == Brightness.dark;
    final rawTemplate = _currentController.text;
    final simulatedText = MessageTemplateService.getLivePreview(
      rawTemplate,
      libraryName: library?.name,
      helpline: library?.phone,
      upiId: library?.upiId,
      address: library?.address,
      prefix: library?.membershipPrefix,
    );

    // Authentic WhatsApp palette
    final whatsappBg = isDark ? const Color(0xFF0B141B) : const Color(0xFFEFE7DE);
    final bubbleBg = isDark ? const Color(0xFF005C4B) : const Color(0xFFE7FFDB);
    final bubbleTextColor = isDark ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.remove_red_eye_rounded, size: 18, color: Color(0xFF25D366)),
                SizedBox(width: 6),
                Text('Live WhatsApp Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            Row(
              children: [
                Tooltip(
                  message: 'Copy preview text to clipboard',
                  child: IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: simulatedText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Preview copied to clipboard! 📋'), behavior: SnackBarBehavior.floating),
                      );
                    },
                  ),
                ),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: () => _sendTestWhatsApp(library),
                  icon: const Icon(Icons.send_rounded, size: 14, color: Color(0xFF25D366)),
                  label: const Text('Test Send', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Simulated Mobile Phone / Chat Frame
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: whatsappBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Chat Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1F2C34) : const Color(0xFF075E54),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person_rounded, size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            library?.name.isNotEmpty == true ? library!.name : 'The Cozy Corner Study Centre',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'Official WhatsApp Channel · Verified',
                            style: TextStyle(color: Colors.white70, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.videocam_rounded, color: Colors.white70, size: 20),
                    const SizedBox(width: 12),
                    const Icon(Icons.call_rounded, color: Colors.white70, size: 18),
                  ],
                ),
              ),

              // Chat Bubble Container
              Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      decoration: BoxDecoration(
                        color: bubbleBg,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(4),
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            simulatedText,
                            style: TextStyle(
                              color: bubbleTextColor,
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Spacer(),
                              Text(
                                '10:42 AM',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.done_all_rounded,
                                size: 14,
                                color: Color(0xFF53BDEB), // WhatsApp blue double tick
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Chat Bar Footer (Aesthetic)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1F2C34) : const Color(0xFFF0F0F0),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_emotions_outlined, color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Message', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ),
                    const Icon(Icons.attach_file_rounded, color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    const Icon(Icons.mic_rounded, color: Colors.grey, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
