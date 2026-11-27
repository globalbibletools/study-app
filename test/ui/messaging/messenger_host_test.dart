import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/l10n/localizations.dart';
import 'package:gbt/ui/messaging/messenger_host.dart';
import 'package:gbt/ui/messaging/messenger_view_model.dart';

void main() {
  MessengerViewModel newViewModel() {
    final viewModel = MessengerViewModel();
    addTearDown(viewModel.dispose);
    return viewModel;
  }

  Widget buildApp(MessengerViewModel messenger, {Widget? home}) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MessengerHost(
        messenger: messenger,
        child: child ?? const SizedBox.shrink(),
      ),
      home: home ?? const Scaffold(body: SizedBox.expand()),
    );
  }

  testWidgets('renders a message at the top of the screen', (tester) async {
    final messenger = newViewModel();
    await tester.pumpWidget(buildApp(messenger));

    messenger.showSuccess('Saved');

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Saved'), findsOneWidget);
    final topLeft = tester.getTopLeft(find.byKey(MessengerHost.cardKey));
    expect(topLeft.dy, lessThan(100));
    expect(topLeft.dy, lessThan(tester.view.physicalSize.height / 2));
  });

  testWidgets('renders a distinct icon for each severity', (tester) async {
    final messenger = newViewModel();
    await tester.pumpWidget(buildApp(messenger));

    messenger.showInfo('info');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byIcon(Icons.info_outline), findsOneWidget);

    messenger.dismissVisible();
    await tester.pump(const Duration(milliseconds: 250));

    messenger.showSuccess('success');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

    messenger.dismissVisible();
    await tester.pump(const Duration(milliseconds: 250));

    messenger.showWarning('warning');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

    messenger.dismissVisible();
    await tester.pump(const Duration(milliseconds: 250));

    messenger.showError('error');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byIcon(Icons.error_outline), findsOneWidget);

    messenger.dismissVisible();
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('the close button dismisses the message', (tester) async {
    final messenger = newViewModel();
    await tester.pumpWidget(buildApp(messenger));

    messenger.showError('Something failed');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(MessengerHost.dismissButtonKey), findsOneWidget);

    await tester.tap(find.byKey(MessengerHost.dismissButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Something failed'), findsNothing);
    expect(messenger.visibleMessage, isNull);
  });

  testWidgets('auto-dismisses a success message after three seconds', (
    tester,
  ) async {
    final messenger = newViewModel();
    await tester.pumpWidget(buildApp(messenger));

    messenger.showSuccess('Saved');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Saved'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Saved'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('shows the queued successor after the visible one dismisses', (
    tester,
  ) async {
    final messenger = newViewModel();
    await tester.pumpWidget(buildApp(messenger));

    messenger.showInfo('First');
    messenger.showSuccess('Second');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);

    messenger.dismissVisible();
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('renders above an open dialog and stays interactive', (
    tester,
  ) async {
    final messenger = newViewModel();
    await tester.pumpWidget(
      buildApp(
        messenger,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => const AlertDialog(
                  title: Text('Dialog title'),
                  content: Text('Dialog content'),
                ),
              ),
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    messenger.showError('Above the dialog');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Above the dialog'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.byKey(MessengerHost.dismissButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Above the dialog'), findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('renders above an open modal bottom sheet', (tester) async {
    final messenger = newViewModel();
    await tester.pumpWidget(
      buildApp(
        messenger,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (context) => const SizedBox(
                  height: 200,
                  child: Center(child: Text('Sheet content')),
                ),
              ),
              child: const Text('Open sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    expect(find.text('Sheet content'), findsOneWidget);

    messenger.showWarning('Above the sheet');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Above the sheet'), findsOneWidget);
    expect(find.text('Sheet content'), findsOneWidget);

    await tester.tap(find.byKey(MessengerHost.dismissButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Above the sheet'), findsNothing);
    expect(find.text('Sheet content'), findsOneWidget);
  });

  testWidgets('an empty host does not block taps', (tester) async {
    final messenger = newViewModel();
    var tapped = false;

    await tester.pumpWidget(
      buildApp(
        messenger,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: TextButton(
              onPressed: () => tapped = true,
              child: const Text('Top button'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Top button'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
