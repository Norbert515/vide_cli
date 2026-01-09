import 'package:uuid/uuid.dart';

/// Types of toast notifications with different visual styles.
enum ToastType { success, error, warning, info }

/// Data class representing a toast notification.
class ToastData {
  /// Unique identifier for this toast.
  final String id;

  /// The message to display.
  final String message;

  /// The type of toast (affects color and icon).
  final ToastType type;

  /// How long the toast should be visible before auto-dismissing.
  final Duration duration;

  /// When this toast was created.
  final DateTime createdAt;

  ToastData({
    String? id,
    required this.message,
    required this.type,
    this.duration = const Duration(seconds: 3),
  })  : id = id ?? const Uuid().v4(),
        createdAt = DateTime.now();
}
