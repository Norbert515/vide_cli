import 'package:nocterm/nocterm.dart';
import 'package:nocterm_riverpod/nocterm_riverpod.dart';

import 'package:vide_cli/modules/toast/models/toast_data.dart';
import 'package:vide_cli/modules/toast/toast_service.dart';
import 'package:vide_cli/theme/theme.dart';

/// Overlay component that displays toast notifications.
///
/// Renders toasts in the bottom-right corner of the screen.
/// Should be placed in a Stack as one of the top-level children.
class ToastOverlay extends StatelessComponent {
  const ToastOverlay({super.key});

  @override
  Component build(BuildContext context) {
    final toasts = context.watch(toastProvider).toasts;
    if (toasts.isEmpty) return const SizedBox();

    final theme = VideTheme.of(context);

    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: EdgeInsets.only(right: 2, bottom: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [for (final toast in toasts) _buildToastItem(toast, theme)],
        ),
      ),
    );
  }

  Component _buildToastItem(ToastData toast, VideThemeData theme) {
    final (icon, color) = switch (toast.type) {
      ToastType.success => ('✓', theme.base.success),
      ToastType.error => ('✗', theme.base.error),
      ToastType.warning => ('⚠', theme.base.warning),
      ToastType.info => ('ℹ', theme.base.primary),
    };

    return Padding(
      padding: EdgeInsets.only(top: 1),
      child: Container(
        decoration: BoxDecoration(
          color: theme.base.surface,
          border: BoxBorder.all(color: color),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$icon ', style: TextStyle(color: color)),
              Text(
                toast.message,
                style: TextStyle(color: theme.base.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
