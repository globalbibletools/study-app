import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/reading_plan/day_activity_log_panel.dart';
import 'package:gbt/reading_plan/day_activity_log_view_model.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/messaging/messenger_host.dart';
import 'package:gbt/ui/messaging/messenger_view_model.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_reading_plan_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeReadingPlanService planService;
  late DateTime date;

  setUp(() {
    planService = FakeReadingPlanService();
    date = DateTime(2026, 11, 17);
    getIt.registerSingleton<MessengerViewModel>(MessengerViewModel());
  });

  tearDown(() async {
    await getIt.reset();
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
      builder: (context, child) => Material(
        color: Theme.of(context).colorScheme.surface,
        child: MessengerHost(
          messenger: getIt<MessengerViewModel>(),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
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
          [
            DetailedProgess(63, 1, 4, 4),
            DetailedProgess(63, 1, 1, 2),
            DetailedProgess(63, 2, 1, 3),
            DetailedProgess(64, 1, 1, 1),
          ],
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
      expect(find.text('2 John 1:1-2, 1:4, 2:1-3, 3 John 1:1'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets(
      'shows manual sessions with start time, description, and trash icon',
      (tester) async {
        planService.detailedProgress = [
          session(
            id: 1,
            startTime: DateTime(2026, 11, 17, 9, 5),
            readSeconds: 300,
            verses: 2,
          ),
          session(
            id: 2,
            isManual: true,
            startTime: DateTime(2026, 11, 16, 22, 15),
            readSeconds: 120,
            verses: 1,
          ),
        ];
        final viewModel = newViewModel();
        await viewModel.initialize();

        await tester.pumpWidget(
          buildApp(DayActivityLogPanel(viewModel: viewModel)),
        );
        await tester.pumpAndSettle();

        expect(find.text('09:05'), findsOneWidget);
        expect(find.text('22:15'), findsOneWidget);
        expect(find.text('No verses read'), findsOneWidget);
        expect(find.text('Manually added'), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
        expect(
          find.byKey(const ValueKey('deleteManualSession-2')),
          findsOneWidget,
        );

        final deleteButton = find.byKey(
          const ValueKey('deleteManualSession-2'),
        );
        expect(tester.getSize(deleteButton).height, lessThanOrEqualTo(18));
        final deleteButtonWidget = tester.widget<IconButton>(deleteButton);
        final errorColor = Theme.of(
          tester.element(find.byType(DayActivityLogPanel)),
        ).colorScheme.error;
        expect(deleteButtonWidget.color, errorColor);
      },
    );
  });

  group('manual sessions', () {
    Finder manualMinutesField() => find.descendant(
      of: find.byKey(const ValueKey('manualMinutesStepper')),
      matching: find.byType(TextField),
    );

    Finder manualVersesField() => find.descendant(
      of: find.byKey(const ValueKey('manualVersesStepper')),
      matching: find.byType(TextField),
    );

    testWidgets('plus button opens the dialog and submits totals', (
      tester,
    ) async {
      planService.detailedProgress = [];
      final viewModel = newViewModel();
      await viewModel.initialize();

      await tester.pumpWidget(
        buildApp(DayActivityLogPanel(viewModel: viewModel)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('addManualSessionButton')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Add Session'), findsNWidgets(2));

      final title = tester.widget<Text>(
        find.byKey(const ValueKey('manualSessionTitle')),
      );
      expect(title.textAlign, TextAlign.center);

      final cancelLabel = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('manualSessionCancel')),
          matching: find.byType(Text),
        ),
      );
      final submitLabel = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('manualSessionSubmit')),
          matching: find.byType(Text),
        ),
      );
      expect(cancelLabel.style?.fontWeight, FontWeight.bold);
      expect(submitLabel.style?.fontWeight, FontWeight.bold);

      final minutesStepper = find.byKey(const ValueKey('manualMinutesStepper'));
      final versesStepper = find.byKey(const ValueKey('manualVersesStepper'));
      expect(
        tester.getTopLeft(minutesStepper).dx,
        closeTo(tester.getTopLeft(versesStepper).dx, 0.1),
      );

      expect(
        tester.getTopLeft(find.text('minutes')).dx,
        greaterThan(
          tester
              .getTopLeft(find.byKey(const Key('manual-minutes-increase')))
              .dx,
        ),
      );
      expect(
        tester.getTopLeft(find.text('verses')).dx,
        greaterThan(
          tester.getTopLeft(find.byKey(const Key('manual-verses-increase'))).dx,
        ),
      );

      await tester.enterText(manualMinutesField(), '5.5');
      await tester.enterText(manualVersesField(), '2');
      await tester.tap(find.byKey(const ValueKey('manualSessionSubmit')));
      await tester.pumpAndSettle();

      final call = planService.addedManualSessions.single;
      expect(call.readingPlanId, 1);
      expect(call.date, date);
      expect(call.minutes, 5.5);
      expect(call.verses, 2);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Nov 17, 2026'), findsOneWidget);
      expect(find.text('09:30'), findsOneWidget);
      expect(find.text('Manually added'), findsOneWidget);
      expect(viewModel.sessions.single.rsSession.isManual, isTrue);
      expect(viewModel.totalMinutes, 5.5);
      expect(viewModel.totalVerses, 2);
    });

    testWidgets('cancel closes the dialog without adding a session', (
      tester,
    ) async {
      planService.detailedProgress = [];
      final viewModel = newViewModel();
      await viewModel.initialize();

      await tester.pumpWidget(
        buildApp(DayActivityLogPanel(viewModel: viewModel)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('addManualSessionButton')));
      await tester.pumpAndSettle();
      await tester.enterText(manualMinutesField(), '5');
      await tester.tap(find.byKey(const ValueKey('manualSessionCancel')));
      await tester.pumpAndSettle();

      expect(planService.addedManualSessions, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
      expect(viewModel.sessions, isEmpty);
    });

    testWidgets('rejects a submission with no minutes or verses', (
      tester,
    ) async {
      planService.detailedProgress = [];
      final viewModel = newViewModel();
      await viewModel.initialize();

      await tester.pumpWidget(
        buildApp(DayActivityLogPanel(viewModel: viewModel)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('addManualSessionButton')));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(DayActivityLogPanel)),
      )!;
      await tester.tap(find.byKey(const ValueKey('manualSessionSubmit')));
      await tester.pumpAndSettle();

      expect(find.text(l10n.invalidManualSession), findsOneWidget);
      expect(planService.addedManualSessions, isEmpty);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('trash icon deletes a manual session', (tester) async {
      planService.detailedProgress = [
        session(
          id: 7,
          isManual: true,
          startTime: DateTime(2026, 11, 17, 9, 30),
          readSeconds: 120,
          verses: 1,
        ),
      ];
      final viewModel = newViewModel();
      await viewModel.initialize();

      await tester.pumpWidget(
        buildApp(DayActivityLogPanel(viewModel: viewModel)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('deleteManualSession-7')));
      await tester.pumpAndSettle();

      expect(planService.deletedManualSessionIds, [7]);
      expect(viewModel.sessions, isEmpty);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });
  });

  group('navigation', () {
    setUp(() {
      getIt.registerSingleton<ReadingPlanService>(planService);
    });

    tearDown(() async {
      await getIt.reset();
    });

    testWidgets(
      'shows an error message and keeps the panel closed on load error',
      (tester) async {
        planService.detailedProgressError = StateError('load failed');

        await tester.pumpWidget(buildApp(const _NavigateToLauncher()));
        await tester.tap(find.text('Open activity'));
        await tester.pumpAndSettle();

        expect(find.byType(DayActivityLogPanel), findsNothing);
        expect(find.text('Open activity'), findsOneWidget);

        final context = tester.element(find.text('Open activity'));
        final l10n = AppLocalizations.of(context)!;
        expect(find.text(l10n.errorLoadingContent), findsOneWidget);

        await tester.pump(const Duration(seconds: 8));
        await tester.pumpAndSettle();
      },
    );
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
  int? id,
  DateTime? startTime,
  int readSeconds = 0,
  int verses = 0,
  bool isManual = false,
  List<DetailedProgess> progress = const [],
}) {
  return SessionDetails(
    RsSession(
      id: id,
      rsDate: DateTime(2026, 11, 17),
      startTime: startTime ?? DateTime(2026, 11, 17, 9),
      readSeconds: readSeconds,
      verses: verses,
      readingPlanId: 1,
      isManual: isManual,
    ),
    progress,
  );
}
