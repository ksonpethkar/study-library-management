import 'package:flutter/material.dart';
import 'package:quick_actions/quick_actions.dart';

/// Manages Android home screen long-press shortcuts.
/// Admin sees: Add Student, Record Payment, Scan QR, Announcements
/// Student sees: My Membership, My ID Card
class QuickActionsService {
  static const _quickActions = QuickActions();
  static String? _pendingShortcut;

  /// Call this ONCE from the root app widget (after login is known).
  static void initializeForAdmin(BuildContext context, Function(String) onShortcut) {
    _quickActions.initialize((shortcutType) {
      _pendingShortcut = shortcutType;
      onShortcut(shortcutType);
    });

    _quickActions.setShortcutItems([
      const ShortcutItem(
        type: 'add_student',
        localizedTitle: 'Add Student',
        icon: 'ic_shortcut_person',
      ),
      const ShortcutItem(
        type: 'record_payment',
        localizedTitle: 'Record Payment',
        icon: 'ic_shortcut_payment',
      ),
      const ShortcutItem(
        type: 'scan_qr',
        localizedTitle: 'Scan QR',
        icon: 'ic_shortcut_qr',
      ),
      const ShortcutItem(
        type: 'announcements',
        localizedTitle: 'Announcements',
        icon: 'ic_shortcut_announce',
      ),
    ]);
  }

  static void initializeForStudent(BuildContext context, Function(String) onShortcut) {
    _quickActions.initialize((shortcutType) {
      _pendingShortcut = shortcutType;
      onShortcut(shortcutType);
    });

    _quickActions.setShortcutItems([
      const ShortcutItem(
        type: 'my_membership',
        localizedTitle: 'My Membership',
        icon: 'ic_shortcut_member',
      ),
      const ShortcutItem(
        type: 'my_id_card',
        localizedTitle: 'My ID Card',
        icon: 'ic_shortcut_id',
      ),
    ]);
  }

  static void clearShortcuts() {
    _quickActions.clearShortcutItems();
    _pendingShortcut = null;
  }

  static String? get pendingShortcut => _pendingShortcut;
  static void clearPending() => _pendingShortcut = null;
}
