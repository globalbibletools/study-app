import 'package:flutter/foundation.dart';

/// Severity of an ephemeral message.
///
/// The declaration order doubles as the display priority: a higher [priority]
/// wins when several messages are waiting. Severities with the same priority
/// are shown in the order they were queued.
enum MessageSeverity {
  info(0),
  success(1),
  warning(2),
  error(3);

  const MessageSeverity(this.priority);

  final int priority;

  /// How long a message of this severity stays visible.
  Duration get duration => switch (this) {
    MessageSeverity.info => const Duration(seconds: 3),
    MessageSeverity.success => const Duration(seconds: 3),
    MessageSeverity.warning => const Duration(seconds: 5),
    MessageSeverity.error => const Duration(seconds: 8),
  };
}

/// One transient, app-level message.
///
/// Messages are deliberately small: severity and already-localized text. They
/// carry their own identity and duration, so the view model can coalesce
/// duplicates and schedule the dismissal without knowing anything about the
/// widget tree.
@immutable
class EphemeralMessage {
  const EphemeralMessage({
    required this.id,
    required this.severity,
    required this.text,
    required this.duration,
  });

  final String id;
  final MessageSeverity severity;
  final String text;
  final Duration duration;

  @override
  String toString() =>
      'EphemeralMessage($id, ${severity.name}, "$text", $duration)';
}
