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

  const WhatsAppPreviewSheet({
    super.key,
    required this.phone,
    required this.message,
    this.recipientName,
    this.title,
  });

  /// Displays the preview sheet and returns the confirmed message string
  /// if the user taps 'Open WhatsApp', or null if cancelled.
  static Future<String?> show(
    BuildContext context, {
    required String phone,
    required String message,
    String? recipientName,
    String? title,
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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.message);
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
