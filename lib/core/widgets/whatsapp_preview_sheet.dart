import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable modal sheet that previews a formatted WhatsApp message before
/// opening the external WhatsApp application.
/// Allows the user to inspect the full text, copy it, or edit it inline.
class WhatsAppPreviewSheet extends StatefulWidget {
  final String phone;
  final String message;
  final String? recipientName;
  final String? title;
  final Map<String, String>? multilingualMessages;
  final String? defaultLanguage;

  const WhatsAppPreviewSheet({
    super.key,
    required this.phone,
    required this.message,
    this.recipientName,
    this.title,
    this.multilingualMessages,
    this.defaultLanguage,
  });

  /// Displays the preview sheet and returns the confirmed message string
  /// if the user taps 'Open WhatsApp', or null if cancelled.
  static Future<String?> show(
    BuildContext context, {
    required String phone,
    required String message,
    String? recipientName,
    String? title,
    Map<String, String>? multilingualMessages,
    String? defaultLanguage,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WhatsAppPreviewSheet(
        phone: phone,
        message: message,
        recipientName: recipientName,
        title: title,
        multilingualMessages: multilingualMessages,
        defaultLanguage: defaultLanguage,
      ),
    );
  }

  @override
  State<WhatsAppPreviewSheet> createState() => _WhatsAppPreviewSheetState();
}

class _WhatsAppPreviewSheetState extends State<WhatsAppPreviewSheet> {
  late final TextEditingController _controller;
  bool _isEditing = false;
  bool _copied = false;
  late String _selectedLanguage;
  late Map<String, String> _messagesByLang;

  @override
  void initState() {
    super.initState();
    _messagesByLang = widget.multilingualMessages != null
        ? Map<String, String>.from(widget.multilingualMessages!)
        : _generateMultilingualMessages(widget.message, widget.recipientName, initialLang: widget.defaultLanguage);

    final preferred = widget.defaultLanguage ??
        (widget.multilingualMessages?.containsKey('mr') == true
            ? 'mr'
            : (RegExp(r'[\u0900-\u097F]').hasMatch(widget.message) ? 'mr' : 'en'));

    _selectedLanguage = _messagesByLang.containsKey(preferred) ? preferred : (_messagesByLang.keys.firstOrNull ?? 'en');

    if (!_messagesByLang.containsKey(_selectedLanguage)) {
      _messagesByLang[_selectedLanguage] = widget.message;
    }

    _controller = TextEditingController(text: _messagesByLang[_selectedLanguage] ?? widget.message);
  }

  static Map<String, String> _generateMultilingualMessages(String baseMsg, String? recipientName, {String? initialLang}) {
    final name = (recipientName != null && recipientName.trim().isNotEmpty) ? recipientName.trim() : 'विद्यार्थी मित्र';
    final nameEn = (recipientName != null && recipientName.trim().isNotEmpty) ? recipientName.trim() : 'Dear Student';
    final nameHi = (recipientName != null && recipientName.trim().isNotEmpty) ? recipientName.trim() : 'प्रिय छात्र';

    final amountMatch = RegExp(r'₹\s*([0-9,]+)').firstMatch(baseMsg) ?? RegExp(r'fee of ([0-9,]+)').firstMatch(baseMsg);
    final amount = amountMatch?.group(1) ?? '200';

    final isDevanagari = RegExp(r'[\u0900-\u097F]').hasMatch(baseMsg);
    final lower = baseMsg.toLowerCase();
    String en;
    String mr;
    String hi;

    if (lower.contains('pending fee') || lower.contains('due') || lower.contains('outstanding') || baseMsg.contains('थकबाकी') || baseMsg.contains('उर्वरित') || baseMsg.contains('बाकी')) {
      en = 'Dear $nameEn,\n\nThis is a friendly reminder that you have a pending fee due of ₹$amount for your study library subscription at The Cozy Corner Study Centre. Kindly clear your balance at the reception to maintain your seat reservation.\n\nThank you,\nThe Cozy Corner Study Centre';
      mr = 'सस्नेह नमस्कार $name,\n\nद कोझी कॉर्नर स्टडी सेंटर मधील आपल्या अभ्यासिकेचे ₹$amount चे उर्वरित शुल्क (Pending Due) बाकी आहे. कृपया लवकरात लवकर आपले शुल्क जमा करून आपली बैठक व्यवस्था अबाधित ठेवावी.\n\nधन्यवाद,\nद कोझी कॉर्नर स्टडी सेंटर';
      hi = 'नमस्ते $nameHi,\n\nद कोज़ी कॉर्नर स्टडी सेंटर में आपकी लाइब्रेरी सदस्यता का ₹$amount बकाया शुल्क शेष है। कृपया जल्द से जल्द अपना बकाया शुल्क जमा करके अपनी सीट सुनिश्चित रखें।\n\nधन्यवाद,\nद कोज़ी कॉर्नर स्टडी सेंटर';
    } else if (lower.contains('expir') || lower.contains('renew') || baseMsg.contains('नूतनीकरण') || baseMsg.contains('समाप्त') || baseMsg.contains('मुदत')) {
      en = 'Dear $nameEn,\n\nYour study desk subscription at The Cozy Corner Study Centre will expire soon. To enjoy uninterrupted study hours and keep your reserved seat, please renew your plan at the counter.\n\nThank you,\nThe Cozy Corner Study Centre';
      mr = 'सस्नेह नमस्कार $name,\n\nद कोझी कॉर्नर स्टडी सेंटर मधील आपली अभ्यासिकेची सदस्यता लवकरच समाप्त होत आहे. अखंड आणि शांत अभ्यासासाठी कृपया वेळेत नूतनीकरण (Renewal) करावे.\n\nधन्यवाद,\nद कोझी कॉर्नर स्टडी सेंटर';
      hi = 'नमस्ते $nameHi,\n\nद कोज़ी कॉर्नर स्टडी सेंटर में आपकी सदस्यता की वैधता समाप्त होने वाली है। निरंतर अध्ययन जारी रखने के लिए कृपया समय पर नवीनीकरण (Renewal) कराएं।\n\nधन्यवाद,\nद कोज़ी कॉर्नर स्टडी सेंटर';
    } else if (lower.contains('admiss') || lower.contains('welcom') || lower.contains('approv') || baseMsg.contains('सहर्ष स्वागत') || baseMsg.contains('प्रवेश') || baseMsg.contains('तपशील')) {
      en = '🎉 *Welcome to The Cozy Corner Study Centre!*\n\nDear *$nameEn*,\nWe are delighted to welcome you to our study community! Your library membership registration has been confirmed.\n\nWarm regards,\n*Team The Cozy Corner Study Centre*';
      mr = isDevanagari ? baseMsg : 'सस्नेह नमस्कार $name,\n\nद कोझी कॉर्नर स्टडी सेंटर मध्ये आपले हार्दिक स्वागत आहे! आपला प्रवेश आणि डेस्क यशस्वीरीत्या निश्चित झाला आहे. आपल्या उज्ज्वल भविष्यासाठी हार्दिक शुभेच्छा!\n\nद कोझी कॉर्नर स्टडी सेंटर';
      hi = 'नमस्ते $nameHi,\n\nद कोज़ी कॉर्नर स्टडी सेंटर में आपका हार्दिक स्वागत है! आपका प्रवेश और डेस्क सफलतापूर्वक आवंटित हो गया है। आपके उज्ज्वल भविष्य के लिए शुभकामनाएं!\n\nद कोज़ी कॉर्नर स्टडी सेंटर';
    } else if (lower.contains('receipt') || lower.contains('payment') || baseMsg.contains('पावती') || baseMsg.contains('जमा')) {
      en = 'Dear $nameEn,\n\nThank you for your payment of ₹$amount. Your digital fee receipt has been registered in our system.\n\nThank you,\nThe Cozy Corner Study Centre';
      mr = isDevanagari ? baseMsg : 'सस्नेह नमस्कार $name,\n\nद कोझी कॉर्नर स्टडी सेंटर मध्ये आपले ₹$amount चे शुल्क यशस्वीरीत्या प्राप्त झाले आहे. आपली डिजिटल पावती प्रणालीमध्ये नोंदवली गेली आहे.\n\nधन्यवाद,\nद कोझी कॉर्नर स्टडी सेंटर';
      hi = 'नमस्ते $nameHi,\n\nद कोज़ी कॉर्नर स्टडी सेंटर में आपका ₹$amount का शुल्क सफलतापूर्वक प्राप्त हो गया है। आपकी रसीद सिस्टम में दर्ज कर दी गई है।\n\nधन्यवाद,\nद कोज़ी कॉर्नर स्टडी सेंटर';
    } else {
      if (isDevanagari) {
        mr = baseMsg;
        hi = baseMsg;
        en = 'Dear $nameEn,\n\nHere is an update regarding your library membership at The Cozy Corner Study Centre.\n\nRegards,\nThe Cozy Corner Study Centre';
      } else {
        en = baseMsg;
        mr = 'सस्नेह नमस्कार $name,\n\n$baseMsg\n\nधन्यवाद,\nद कोझी कॉर्नर स्टडी सेंटर';
        hi = 'नमस्ते $nameHi,\n\n$baseMsg\n\nधन्यवाद,\nद कोज़ी कॉर्नर स्टडी सेंटर';
      }
    }

    return {
      'en': en,
      'mr': mr,
      'hi': hi,
    };
  }

  Widget _buildLangTab(String langCode, String label) {
    final isSelected = _selectedLanguage == langCode;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedLanguage == langCode) return;
          _messagesByLang[_selectedLanguage] = _controller.text;
          setState(() {
            _selectedLanguage = langCode;
            final newText = _messagesByLang[langCode] ?? widget.message;
            _controller.text = newText;
            _controller.selection = TextSelection.collapsed(offset: newText.length);
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF25D366) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF25D366).withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey.shade300 : Colors.black87),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _controller.text));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  String _formatPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    if (digits.startsWith('91') && digits.length == 12) {
      final sub = digits.substring(2);
      return '+91 ${sub.substring(0, 5)} ${sub.substring(5)}';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final formattedPhone = _formatPhone(widget.phone);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            bottom: bottomInset + 16,
            top: 12,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle bar
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat_rounded,
                      color: Color(0xFF25D366),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title ?? 'WhatsApp Message Preview',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.recipientName != null &&
                                  widget.recipientName!.isNotEmpty
                              ? 'To: ${widget.recipientName} · $formattedPhone'
                              : 'To: $formattedPhone',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Multi-language switcher tabs (English | मराठी | हिंदी)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _buildLangTab('en', 'English'),
                    _buildLangTab('mr', 'मराठी'),
                    _buildLangTab('hi', 'हिंदी'),
                  ],
                ),
              ),

              // Sub-header with mode toggle & copy button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditing ? 'Editing Message:' : 'Prepared Message:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    ),
                  ),
                  Row(
                    children: [
                      // Copy Button
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: Icon(
                          _copied ? Icons.check_rounded : Icons.copy_rounded,
                          size: 15,
                          color: _copied ? Colors.green : Colors.grey.shade600,
                        ),
                        label: Text(
                          _copied ? 'Copied' : 'Copy',
                          style: TextStyle(
                            fontSize: 12,
                            color: _copied ? Colors.green : Colors.grey.shade600,
                          ),
                        ),
                        onPressed: _copyToClipboard,
                      ),
                      const SizedBox(width: 4),

                      // Edit / Preview Toggle
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: Icon(
                          _isEditing ? Icons.visibility_rounded : Icons.edit_rounded,
                          size: 15,
                          color: theme.colorScheme.primary,
                        ),
                        label: Text(
                          _isEditing ? 'Preview' : 'Edit',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        onPressed: () => setState(() => _isEditing = !_isEditing),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Message Body
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.42,
                  minHeight: 120,
                ),
                child: _isEditing
                    ? TextFormField(
                        key: ValueKey('edit_$_selectedLanguage'),
                        controller: _controller,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(fontSize: 13.5, height: 1.45),
                        decoration: InputDecoration(
                          hintText: 'Type your message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      )
                    : Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E2D24)
                              : const Color(0xFFE8F5E9).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF25D366).withValues(alpha: 0.25),
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            _controller.text,
                            key: ValueKey('preview_$_selectedLanguage'),
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.48,
                              color: isDark ? Colors.grey.shade200 : const Color(0xFF1B3B2B),
                            ),
                          ),
                        ),
                      ),
              ),

              const SizedBox(height: 8),
              // Hint info
              Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tapping "Open WhatsApp" will launch WhatsApp with this message ready to send.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(null),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text(
                        'Open WhatsApp',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        final trimmed = _controller.text.trim();
                        Navigator.of(context).pop(trimmed.isNotEmpty ? trimmed : null);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
