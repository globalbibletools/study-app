import 'package:flutter/foundation.dart';

enum MessageSeverity {
  info(0),
  success(1),
  warning(2),
  error(3);

  const MessageSeverity(this.priority);

  final int priority;

  Duration get visibilityTimeout => switch (this) {
    MessageSeverity.info => const Duration(seconds: 3),
    MessageSeverity.success => const Duration(seconds: 3),
    MessageSeverity.warning => const Duration(seconds: 5),
    MessageSeverity.error => const Duration(seconds: 8),
  };
}

@immutable
class EphemeralMessage {
  const EphemeralMessage({
    required this.id,
    required this.severity,
    required this.text,
  });

  final String id;
  final MessageSeverity severity;
  final String text;

  @override
  String toString() => 'EphemeralMessage($id, ${severity.name}, "$text")';
}
