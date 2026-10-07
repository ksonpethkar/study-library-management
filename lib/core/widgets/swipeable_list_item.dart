import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'confirmation_sheet.dart';

class SwipeableListItem extends StatelessWidget {
  final Widget child;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool confirmDelete;

  const SwipeableListItem({
    super.key,
    required this.child,
    this.onEdit,
    this.onDelete,
    this.confirmDelete = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Slidable(
      key: UniqueKey(),
      startActionPane: onEdit != null ? ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onEdit!(),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            icon: Icons.edit,
            label: 'Edit',
          ),
        ],
      ) : null,
      endActionPane: onDelete != null ? ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) async {
              if (confirmDelete) {
                bool confirmed = false;
                await ConfirmationSheet.show(
                  context,
                  title: 'Confirm Delete',
                  message: 'Are you sure you want to delete this item? This action cannot be undone.',
                  confirmLabel: 'Delete',
                  isDestructive: true,
                  onConfirm: () {
                    confirmed = true;
                  },
                );
                if (confirmed) {
                  onDelete!();
                }
              } else {
                onDelete!();
              }
            },
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
            icon: Icons.delete,
            label: 'Delete',
          ),
        ],
      ) : null,
      child: child,
    );
  }
}
