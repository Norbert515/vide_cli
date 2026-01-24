import 'package:riverpod/riverpod.dart';

import 'package:vide_cli/modules/toast/models/toast_data.dart';

/// State holding the current list of active toasts.
class ToastState {
  final List<ToastData> toasts;

  const ToastState({this.toasts = const []});
}

/// Notifier for managing toast notifications.
///
/// Provides methods to show and dismiss toasts. Toasts auto-dismiss
/// after their duration expires.
class ToastNotifier extends StateNotifier<ToastState> {
  ToastNotifier() : super(const ToastState());

  /// Shows a toast notification.
  ///
  /// The toast will auto-dismiss after its [ToastData.duration] expires.
  void show(ToastData toast) {
    state = ToastState(toasts: [...state.toasts, toast]);
    // Auto-dismiss after duration
    Future.delayed(toast.duration, () => dismiss(toast.id));
  }

  /// Dismisses a toast by its ID.
  void dismiss(String id) {
    state = ToastState(toasts: state.toasts.where((t) => t.id != id).toList());
  }

  /// Shows a success toast.
  void success(String message, {Duration? duration}) => show(
    ToastData(
      message: message,
      type: ToastType.success,
      duration: duration ?? const Duration(seconds: 3),
    ),
  );

  /// Shows an error toast.
  void error(String message, {Duration? duration}) => show(
    ToastData(
      message: message,
      type: ToastType.error,
      duration: duration ?? const Duration(seconds: 5),
    ),
  );

  /// Shows an info toast.
  void info(String message, {Duration? duration}) => show(
    ToastData(
      message: message,
      type: ToastType.info,
      duration: duration ?? const Duration(seconds: 3),
    ),
  );

  /// Shows a warning toast.
  void warning(String message, {Duration? duration}) => show(
    ToastData(
      message: message,
      type: ToastType.warning,
      duration: duration ?? const Duration(seconds: 4),
    ),
  );
}

/// Provider for the toast notification system.
final toastProvider = StateNotifierProvider<ToastNotifier, ToastState>(
  (ref) => ToastNotifier(),
);
