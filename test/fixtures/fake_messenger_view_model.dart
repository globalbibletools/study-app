import 'package:gbt/ui/messaging/ephemeral_message.dart';
import 'package:gbt/ui/messaging/messenger_view_model.dart';

class FakeMessengerViewModel extends MessengerViewModel {
  final List<({MessageSeverity severity, String text})> messages = [];

  @override
  String showInfo(String text) => _show(MessageSeverity.info, text);

  @override
  String showSuccess(String text) => _show(MessageSeverity.success, text);

  @override
  String showWarning(String text) => _show(MessageSeverity.warning, text);

  @override
  String showError(String text) => _show(MessageSeverity.error, text);

  String _show(MessageSeverity severity, String text) {
    messages.add((severity: severity, text: text));
    return switch (severity) {
      MessageSeverity.info => super.showInfo(text),
      MessageSeverity.success => super.showSuccess(text),
      MessageSeverity.warning => super.showWarning(text),
      MessageSeverity.error => super.showError(text),
    };
  }
}
