import 'package:flutter/material.dart';

/// ConfirmationSheet displays a bottom sheet for confirmations, optionally requiring typed confirmation for destructive actions.
class ConfirmationSheet extends StatefulWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;
  final IconData? icon;
  final VoidCallback onConfirm;
  final String? impactSummary;

  const ConfirmationSheet({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = 'Cancel',
    this.isDestructive = false,
    this.icon,
    required this.onConfirm,
    this.impactSummary,
  });

  /// Helper method to easily show the confirmation sheet
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
    IconData? icon,
    required VoidCallback onConfirm,
    String? impactSummary,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ConfirmationSheet(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        icon: icon,
        onConfirm: onConfirm,
        impactSummary: impactSummary,
      ),
    );
  }

  @override
  ConfirmationSheetState createState() => ConfirmationSheetState();
}

class ConfirmationSheetState extends State<ConfirmationSheet> {
  final TextEditingController _confirmController = TextEditingController();
  bool _canConfirm = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isDestructive) {
      _canConfirm = true;
    }
  }

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: widget.isDestructive ? theme.colorScheme.error : theme.colorScheme.primary),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(widget.message, style: theme.textTheme.bodyMedium),
            if (widget.impactSummary != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.impactSummary!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
            if (widget.isDestructive) ...[
              const SizedBox(height: 24),
              Text(
                'Please type "confirm" to proceed:',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmController,
                decoration: const InputDecoration(
                  hintText: 'confirm',
                ),
                onChanged: (value) {
                  setState(() {
                    _canConfirm = value.trim().toLowerCase() == 'confirm';
                  });
                },
              ),
            ],
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(widget.cancelLabel),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _canConfirm
                      ? () {
                          Navigator.of(context).pop();
                          widget.onConfirm();
                        }
                      : null,
                  style: widget.isDestructive
                      ? ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                        )
                      : null,
                  child: Text(widget.confirmLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
