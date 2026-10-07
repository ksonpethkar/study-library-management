import 'package:flutter/material.dart';

/// ActionBarItem defines an action to be shown in the ActionBar.
class ActionBarItem {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  ActionBarItem({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
}

/// ActionBar displays bulk actions when items are selected.
class ActionBar extends StatelessWidget {
  final int selectedCount;
  final List<ActionBarItem> actions;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final bool isAllSelected;

  const ActionBar({
    super.key,
    required this.selectedCount,
    required this.actions,
    required this.onSelectAll,
    required this.onDeselectAll,
    this.isAllSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AnimatedSlide(
      offset: selectedCount > 0 ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Text(
                '$selectedCount selected',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: isAllSelected ? onDeselectAll : onSelectAll,
                child: Text(
                  isAllSelected ? 'Deselect All' : 'Select All',
                  style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: 8),
              ...actions.map((action) {
                return IconButton(
                  icon: Icon(action.icon, color: theme.colorScheme.onPrimaryContainer),
                  tooltip: action.label,
                  onPressed: action.onPressed,
                );
              }),
              IconButton(
                icon: Icon(Icons.close, color: theme.colorScheme.onPrimaryContainer),
                tooltip: 'Dismiss',
                onPressed: onDeselectAll,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
