import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/ui/messaging/ephemeral_message.dart';
import 'package:gbt/ui/messaging/messenger_view_model.dart';

void main() {
  MessengerViewModel newViewModel() {
    final viewModel = MessengerViewModel();
    addTearDown(viewModel.dispose);
    return viewModel;
  }

  testWidgets('shows exactly one message at a time and queues the rest', (
    tester,
  ) async {
    final viewModel = newViewModel();

    viewModel.showInfo('first');
    viewModel.showSuccess('second');

    expect(viewModel.visibleMessage?.text, 'first');
    expect(viewModel.pendingMessages.map((m) => m.text), ['second']);

    viewModel.dismissVisible();

    expect(viewModel.visibleMessage?.text, 'second');
    expect(viewModel.pendingMessages, isEmpty);
  });

  testWidgets('orders the queue by severity, then by arrival', (tester) async {
    final viewModel = newViewModel();

    viewModel.showInfo('visible');
    viewModel.showSuccess('success-1');
    viewModel.showInfo('info-1');
    viewModel.showWarning('warning');
    viewModel.showSuccess('success-2');
    viewModel.showError('error');

    // Nothing preempts the visible message.
    expect(viewModel.visibleMessage?.text, 'visible');

    viewModel.dismissVisible();
    expect(viewModel.visibleMessage?.text, 'error');

    viewModel.dismissVisible();
    expect(viewModel.visibleMessage?.text, 'warning');

    viewModel.dismissVisible();
    expect(viewModel.visibleMessage?.text, 'success-1');

    viewModel.dismissVisible();
    expect(viewModel.visibleMessage?.text, 'success-2');

    viewModel.dismissVisible();
    expect(viewModel.visibleMessage?.text, 'info-1');
  });

  testWidgets('a higher priority message does not preempt the visible one', (
    tester,
  ) async {
    final viewModel = newViewModel();

    viewModel.showSuccess('already showing');
    viewModel.showError('urgent');

    expect(viewModel.visibleMessage?.text, 'already showing');
    expect(viewModel.pendingMessages.single.text, 'urgent');

    viewModel.dismissVisible();

    expect(viewModel.visibleMessage?.text, 'urgent');
  });

  testWidgets('auto-dismisses after each severity duration', (tester) async {
    final cases = <MessageSeverity, void Function(MessengerViewModel, String)>{
      MessageSeverity.info: (vm, text) => vm.showInfo(text),
      MessageSeverity.success: (vm, text) => vm.showSuccess(text),
      MessageSeverity.warning: (vm, text) => vm.showWarning(text),
      MessageSeverity.error: (vm, text) => vm.showError(text),
    };

    for (final entry in cases.entries) {
      final viewModel = MessengerViewModel();
      final duration = entry.key.duration;
      entry.value(viewModel, entry.key.name);

      await tester.pump(duration - const Duration(milliseconds: 1));
      expect(
        viewModel.visibleMessage,
        isNotNull,
        reason: '${entry.key.name} should still be visible',
      );

      await tester.pump(const Duration(milliseconds: 1));
      expect(
        viewModel.visibleMessage,
        isNull,
        reason: '${entry.key.name} should have auto-dismissed',
      );

      viewModel.dispose();
    }
  });

  testWidgets('manual dismissal advances to the next queued message', (
    tester,
  ) async {
    final viewModel = newViewModel();

    viewModel.showInfo('first');
    viewModel.showSuccess('second');

    viewModel.dismissVisible();

    expect(viewModel.visibleMessage?.text, 'second');
    expect(viewModel.visibleMessage?.severity, MessageSeverity.success);

    viewModel.dismissVisible();

    expect(viewModel.visibleMessage, isNull);
    expect(viewModel.pendingMessages, isEmpty);
  });

  testWidgets('coalesces a visible duplicate and restarts its timer', (
    tester,
  ) async {
    final viewModel = newViewModel();

    final firstId = viewModel.showError('same message');
    await tester.pump(const Duration(seconds: 7));

    final secondId = viewModel.showError('same message');

    expect(secondId, firstId);
    expect(viewModel.visibleMessage?.text, 'same message');
    expect(viewModel.pendingMessages, isEmpty);

    // Seven seconds elapsed before the duplicate; the timer restarts at eight.
    await tester.pump(const Duration(seconds: 7));
    expect(viewModel.visibleMessage, isNotNull);

    await tester.pump(const Duration(seconds: 1));
    expect(viewModel.visibleMessage, isNull);
  });

  testWidgets('coalesces a queued duplicate without adding another entry', (
    tester,
  ) async {
    final viewModel = newViewModel();

    viewModel.showError('visible');
    final firstId = viewModel.showWarning('duplicate');
    final secondId = viewModel.showWarning('duplicate');

    expect(secondId, firstId);
    expect(viewModel.pendingMessages.length, 1);

    viewModel.dismissVisible();

    expect(viewModel.visibleMessage?.text, 'duplicate');
    expect(viewModel.pendingMessages, isEmpty);
  });

  testWidgets('only the visible message has a running timer', (tester) async {
    final viewModel = newViewModel();

    viewModel.showError('visible');
    viewModel.showWarning('queued');

    // The warning's five second timer must not start while it is queued.
    await tester.pump(const Duration(seconds: 6));

    expect(viewModel.visibleMessage?.text, 'visible');
    expect(viewModel.pendingMessages.single.text, 'queued');

    viewModel.dismissVisible();
    expect(viewModel.visibleMessage?.text, 'queued');

    await tester.pump(const Duration(seconds: 4));
    expect(viewModel.visibleMessage, isNotNull);

    await tester.pump(const Duration(seconds: 1));
    expect(viewModel.visibleMessage, isNull);
  });

  testWidgets('dispose cancels the visible timer and clears state', (
    tester,
  ) async {
    final viewModel = MessengerViewModel();

    viewModel.showError('visible');
    viewModel.showInfo('queued');
    viewModel.dispose();

    // Advancing past every duration must not fire a timer on a disposed VM.
    await tester.pump(const Duration(seconds: 20));
  });
}
