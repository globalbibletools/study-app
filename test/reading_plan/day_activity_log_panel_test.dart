import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/reading_plan/day_activity_log_panel.dart';
import 'package:gbt/reading_plan/day_activity_log_view_model.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_reading_plan_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeReadingPlanService planService;
  late DateTime date;

  setUp(() {
    planService = FakeReadingPlanService();
    date = DateTime(2026, 11, 17);
  });

  DayActivityLogViewModel newViewModel() {
    return DayActivityLogViewModel.withDependencies(
      readingPlanId: 1,
      date: date,
      planService: planService,
    );
  }

  Widget buildApp(Widget home) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) =>
          Material(color: Theme.of(context).colorScheme.surface, child: child),
      home: home,
    );
  }

  group('rendering', () {
    testWidgets('renders sessions and totals from the view model', (
      tester,
    ) async {
      planService.detailedProgress = [
        SessionDetails(
          RsSession(
            rsDate: date,
            startTime: DateTime(2026, 11, 17, 9, 5),
            readSeconds: 90,
            verses: 3,
            readingPlanId: 1,
          ),
          [DetailedProgess(63, 1, 4, 4), DetailedProgess(63, 1, 1, 2)],
        ),
      ];
      final viewModel = newViewModel();
      await viewModel.initialize();

      await tester.pumpWidget(
        buildApp(DayActivityLogPanel(viewModel: viewModel)),
      );
      await tester.pumpAndSettle();

      expect(find.text('09:05'), findsOneWidget);
      expect(find.text('1.5 min • 3 verses'), findsNWidgets(2));
      expect(find.text('2 John 1:1-2, 2 John 1:4'), findsOneWidget);
    });
  });

  group('navigation', () {
    setUp(() {
      getIt.registerSingleton<ReadingPlanService>(planService);
    });

    tearDown(() async {
      await getIt.reset();
    });

    testWidgets('shows a snackbar and keeps the panel closed on load error', (
      tester,
    ) async {
      planService.detailedProgressError = StateError('load failed');

      await tester.pumpWidget(buildApp(const _NavigateToLauncher()));
      await tester.tap(find.text('Open activity'));
      await tester.pumpAndSettle();

      expect(find.byType(DayActivityLogPanel), findsNothing);
      expect(find.text('Open activity'), findsOneWidget);

      final context = tester.element(find.text('Open activity'));
      final l10n = AppLocalizations.of(context)!;
      expect(find.text(l10n.errorLoadingContent), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });

  testWidgets('back closes the panel', (tester) async {
    planService.detailedProgress = [session()];
    final viewModel = newViewModel();
    await viewModel.initialize();

    await tester.pumpWidget(
      buildApp(_ActivityLogLauncher(viewModel: viewModel)),
    );
    await tester.tap(find.text('Open activity'));
    await tester.pumpAndSettle();

    expect(find.byType(DayActivityLogPanel), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.byType(DayActivityLogPanel), findsNothing);
    expect(find.text('Open activity'), findsOneWidget);
  });
}

class _ActivityLogLauncher extends StatelessWidget {
  const _ActivityLogLauncher({required this.viewModel});

  final DayActivityLogViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DayActivityLogPanel(viewModel: viewModel),
              ),
            );
          },
          child: const Text('Open activity'),
        ),
      ),
    );
  }
}

class _NavigateToLauncher extends StatelessWidget {
  const _NavigateToLauncher();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await DayActivityLogPanel.navigateTo(
              context,
              DateTime(2026, 11, 17),
              readingPlanId: 1,
            );
          },
          child: const Text('Open activity'),
        ),
      ),
    );
  }
}

SessionDetails session({
  DateTime? startTime,
  int readSeconds = 0,
  int verses = 0,
  List<DetailedProgess> progress = const [],
}) {
  return SessionDetails(
    RsSession(
      rsDate: DateTime(2026, 11, 17),
      startTime: startTime ?? DateTime(2026, 11, 17, 9),
      readSeconds: readSeconds,
      verses: verses,
      readingPlanId: 1,
    ),
    progress,
  );
}
