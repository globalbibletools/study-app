import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/l10n/localizations.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/messaging/messenger_view_model.dart';
import 'package:gbt/ui/navigation/view_model_navigation.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/fake_messenger_view_model.dart';

class _TestViewModel extends ChangeNotifier {
  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

class _DisposingPage extends StatefulWidget {
  const _DisposingPage({required this.viewModel});

  final _TestViewModel viewModel;

  @override
  State<_DisposingPage> createState() => _DisposingPageState();
}

class _DisposingPageState extends State<_DisposingPage> {
  @override
  void dispose() {
    widget.viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(42),
          child: const Text('view model page'),
        ),
      ),
    );
  }
}

void main() {
  Widget buildApp(Widget home) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
  }

  FakeMessengerViewModel newMessenger() {
    final messenger = FakeMessengerViewModel();
    getIt.registerSingleton<MessengerViewModel>(messenger);
    addTearDown(() async {
      messenger.dispose();
      await getIt.reset();
    });
    return messenger;
  }

  testWidgets('pushes a page and returns the route result', (tester) async {
    newMessenger();
    final viewModel = _TestViewModel();
    int? result;

    await tester.pumpWidget(
      buildApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await pushViewModelPage<_TestViewModel, int>(
                    context: context,
                    create: () async => viewModel,
                    buildView: (viewModel) =>
                        _DisposingPage(viewModel: viewModel),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('view model page'), findsOneWidget);

    await tester.tap(find.text('view model page'));
    await tester.pumpAndSettle();

    expect(result, 42);
    expect(viewModel.disposed, isTrue);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('shows the messenger error when initialization fails', (
    tester,
  ) async {
    final messenger = newMessenger();

    await tester.pumpWidget(
      buildApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  pushViewModelPage<_TestViewModel, void>(
                    context: context,
                    create: () async => throw StateError('failed'),
                    buildView: (_) => const SizedBox.shrink(),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(messenger.messages.single.text, 'Error loading content.');
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('uses a custom load error message', (tester) async {
    final messenger = newMessenger();

    await tester.pumpWidget(
      buildApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  pushViewModelPage<_TestViewModel, void>(
                    context: context,
                    create: () async => throw StateError('failed'),
                    buildView: (_) => const SizedBox.shrink(),
                    loadErrorMessage: (_) => 'Could not open that',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(messenger.messages.single.text, 'Could not open that');
  });

  testWidgets('disposes an abandoned view model when context unmounts', (
    tester,
  ) async {
    newMessenger();
    final viewModel = _TestViewModel();
    final completer = Completer<_TestViewModel>();

    await tester.pumpWidget(
      buildApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  pushViewModelPage<_TestViewModel, void>(
                    context: context,
                    create: () => completer.future,
                    buildView: (_) => const SizedBox.shrink(),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    completer.complete(viewModel);
    await tester.pump();

    expect(viewModel.disposed, isTrue);
    expect(find.text('open'), findsNothing);
  });

  testWidgets('uses a custom present callback instead of a route', (
    tester,
  ) async {
    newMessenger();
    Widget? presentedPage;
    int? result;

    await tester.pumpWidget(
      buildApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await pushInitializedPage<String, int>(
                    context: context,
                    initialize: () async => 'initialized',
                    buildView: (value) => Text(value),
                    present: (context, page) {
                      presentedPage = page;
                      return Future.value(7);
                    },
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(result, 7);
    expect((presentedPage! as Text).data, 'initialized');
    expect(find.text('open'), findsOneWidget);
  });
}
