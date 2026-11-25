import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/asyncutils/cancellation.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_queries.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_read_models.dart';
import 'package:gbt/reading_plan/data_access/rs_database.dart';
import 'package:gbt/reading_plan/data_access/session_log_repository.dart';
import 'package:gbt/reading_plan/data_access/session_repository.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/ui/day_activity_log_panel.dart';
import 'package:gbt/reading_plan/ui/day_activity_log_view_model.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/messaging/messenger_host.dart';
import 'package:gbt/ui/messaging/messenger_view_model.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/bible_navigation_fixture.dart';
import '../../fixtures/fake_messenger_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingSessionDatabase database;
  late ReadingPlanService planService;
  late FakeMessengerViewModel messenger;
  late DateTime date;
  late int planId;
  var databaseDisposed = false;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    databaseDisposed = false;
    date = DateTime(2026, 11, 17);
    messenger = FakeMessengerViewModel();
    database = ReadingSessionDatabase.withDependencies(
      databasePath: inMemoryDatabasePath,
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    await database.init();
    planService = ReadingPlanService.withDependencies(database: database);
    planId = await planService.saveReadingPlan(
      planName: 'Day Activity Test Plan',
      goalType: GoalType.verses,
      goalValue: 10,
      bookIds: [63, 64],
    );
  });

  tearDown(() async {
    if (!databaseDisposed) database.dispose();
    messenger.dispose();
    await getIt.reset();
  });

  Future<DayActivityLogViewModel> newViewModel() {
    return DayActivityLogViewModel.create(
      readingPlanId: planId,
      date: date,
      queries: database.queries,
      planService: planService,
    );
  }

  Future<DayActivityLogViewModel> newDirectViewModel() async {
    final viewModel = await newViewModel();
    addTearDown(viewModel.dispose);
    return viewModel;
  }

  Future<Session> seedSession({
    DateTime? startTime,
    int readSeconds = 0,
    int verses = 0,
    bool isManual = false,
  }) async {
    final start = startTime ?? DateTime(2026, 11, 17, 9);
    final session = await database.session.commit(
      Session(
        rsDate: date,
        startTime: start,
        endTime: start.add(Duration(seconds: readSeconds)),
        readSeconds: readSeconds,
        verses: verses,
        readingPlanId: planId,
        isManual: isManual,
      ),
    );
    await database.daySummary.upsert(planId, date);
    return session;
  }

  Future<void> seedLogs(int sessionId, List<(int, int, int)> verses) async {
    for (final (bookId, chapter, verse) in verses) {
      await database.sessionLog.append(
        SessionLogEntry(
          sessionId: sessionId,
          readingPlanId: planId,
          bookId: bookId,
          chapter: chapter,
          verse: verse,
          dateTime: DateTime(2026, 11, 17, 9, 5),
        ),
      );
    }
  }

  Widget buildApp(Widget home) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => Material(
        color: Theme.of(context).colorScheme.surface,
        child: MessengerHost(
          messenger: messenger,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: home,
    );
  }

  Future<void> waitFor(WidgetTester tester, bool Function() condition) async {
    for (var attempt = 0; attempt < 300; attempt++) {
      if (condition()) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    fail('Timed out waiting for the widget to update.');
  }

  Future<DayActivityLogViewModel> pumpPanel(WidgetTester tester) async {
    final viewModel = (await tester.runAsync(newViewModel))!;
    await tester.pumpWidget(
      buildApp(DayActivityLogPanel(viewModel: viewModel, messenger: messenger)),
    );
    await tester.pumpAndSettle();
    return viewModel;
  }

  void registerRealDependencies() {
    getIt.registerSingleton<ReadingPlanQueries>(database.queries);
    getIt.registerSingleton<ReadingPlanService>(planService);
  }

  Finder minutesField() => find.descendant(
    of: find.byKey(const ValueKey('manualMinutesStepper')),
    matching: find.byType(TextField),
  );

  Finder versesField() => find.descendant(
    of: find.byKey(const ValueKey('manualVersesStepper')),
    matching: find.byType(TextField),
  );

  group('rendering', () {
    testWidgets('renders a session with references and the day totals', (
      tester,
    ) async {
      final session = (await tester.runAsync(
        () => seedSession(
          startTime: DateTime(2026, 11, 17, 9, 5),
          readSeconds: 90,
          verses: 3,
        ),
      ))!;
      await tester.runAsync(
        () => seedLogs(session.id!, const [
          (63, 1, 1),
          (63, 1, 2),
          (63, 1, 4),
          (63, 2, 1),
          (63, 2, 2),
          (63, 2, 3),
          (64, 1, 1),
        ]),
      );

      await pumpPanel(tester);

      expect(find.text('Nov 17, 2026'), findsOneWidget);
      expect(find.text('09:05'), findsOneWidget);
      expect(find.text('1.5 min • 3 verses'), findsNWidgets(2));
      expect(find.text('2 John 1:1-2, 1:4, 2:1-3, 3 John 1:1'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('renders manual sessions and empty non-manual sessions', (
      tester,
    ) async {
      final manual = (await tester.runAsync(
        () => seedSession(
          startTime: DateTime(2026, 11, 17, 22, 15),
          readSeconds: 120,
          verses: 1,
          isManual: true,
        ),
      ))!;
      await tester.runAsync(
        () => seedSession(
          startTime: DateTime(2026, 11, 17, 9, 5),
          readSeconds: 300,
          verses: 2,
        ),
      );

      await pumpPanel(tester);

      expect(find.text('Manually added'), findsOneWidget);
      expect(find.text('22:15'), findsOneWidget);
      expect(find.text('No verses read'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      final deleteButton = find.byKey(
        ValueKey('deleteManualSession-${manual.id}'),
      );
      expect(deleteButton, findsOneWidget);
      expect(tester.getSize(deleteButton).height, lessThanOrEqualTo(18));

      final button = tester.widget<IconButton>(deleteButton);
      final errorColor = Theme.of(
        tester.element(find.byType(DayActivityLogPanel)),
      ).colorScheme.error;
      expect(button.color, errorColor);
    });

    testWidgets('formats whole and fractional minutes', (tester) async {
      await tester.runAsync(
        () => seedSession(
          startTime: DateTime(2026, 11, 17, 8),
          readSeconds: 600,
          verses: 10,
        ),
      );
      await tester.runAsync(
        () => seedSession(
          startTime: DateTime(2026, 11, 17, 9, 5),
          readSeconds: 90,
          verses: 3,
        ),
      );

      await pumpPanel(tester);

      expect(find.text('10 min • 10 verses'), findsOneWidget);
      expect(find.text('1.5 min • 3 verses'), findsOneWidget);
      expect(find.text('11.5 min • 13 verses'), findsOneWidget);
    });
  });

  group('manual sessions', () {
    testWidgets('adds a session through the dialog and persists it', (
      tester,
    ) async {
      final viewModel = await pumpPanel(tester);
      expect(find.text('0 min • 0 verses'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('addManualSessionButton')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.enterText(minutesField(), '5.5');
      await tester.enterText(versesField(), '2');
      await tester.tap(find.byKey(const ValueKey('manualSessionSubmit')));

      await waitFor(tester, () => viewModel.sessions.length == 1);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Manually added'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.text('5.5 min • 2 verses'), findsNWidgets(2));

      final sessions = await tester.runAsync(
        () => database.session.listForDate(date, planId),
      );
      expect(sessions, hasLength(1));
      final session = sessions!.single;
      expect(session.rsDate, date);
      expect(session.readSeconds, 330);
      expect(session.verses, 2);
      expect(session.readingPlanId, planId);
      expect(session.isManual, isTrue);

      final summary = await tester.runAsync(
        () => database.daySummary.get(planId, date),
      );
      expect(summary, isNotNull);
      expect(summary!.rsSeconds, 330);
      expect(summary.rsVerses, 2);
    });

    testWidgets('cancel closes the dialog without writing a session', (
      tester,
    ) async {
      final viewModel = await pumpPanel(tester);

      await tester.tap(find.byKey(const ValueKey('addManualSessionButton')));
      await tester.pumpAndSettle();
      await tester.enterText(minutesField(), '5');
      await tester.tap(find.byKey(const ValueKey('manualSessionCancel')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(viewModel.sessions, isEmpty);

      final sessions = await tester.runAsync(
        () => database.session.listForDate(date, planId),
      );
      expect(sessions, isEmpty);
    });

    testWidgets('rejects a submission with no minutes or verses', (
      tester,
    ) async {
      final viewModel = await pumpPanel(tester);

      await tester.tap(find.byKey(const ValueKey('addManualSessionButton')));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(DayActivityLogPanel)),
      )!;
      await tester.tap(find.byKey(const ValueKey('manualSessionSubmit')));
      await tester.pumpAndSettle();

      expect(find.text(l10n.invalidManualSession), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(viewModel.sessions, isEmpty);

      final sessions = await tester.runAsync(
        () => database.session.listForDate(date, planId),
      );
      expect(sessions, isEmpty);
    });

    testWidgets('deletes a manual session and recalculates the day', (
      tester,
    ) async {
      final manual = (await tester.runAsync(
        () => seedSession(
          startTime: DateTime(2026, 11, 17, 9, 30),
          readSeconds: 120,
          verses: 2,
          isManual: true,
        ),
      ))!;
      await tester.runAsync(
        () => seedSession(
          startTime: DateTime(2026, 11, 17, 8),
          readSeconds: 300,
          verses: 3,
        ),
      );
      final viewModel = await pumpPanel(tester);
      expect(find.text('7 min • 5 verses'), findsOneWidget);

      await tester.tap(
        find.byKey(ValueKey('deleteManualSession-${manual.id}')),
      );
      await waitFor(tester, () => viewModel.sessions.length == 1);
      await tester.pumpAndSettle();

      expect(find.text('Manually added'), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.text('5 min • 3 verses'), findsNWidgets(2));

      final deleted = await tester.runAsync(
        () => database.session.getById(manual.id!),
      );
      expect(deleted, isNull);

      final summary = await tester.runAsync(
        () => database.daySummary.get(planId, date),
      );
      expect(summary, isNotNull);
      expect(summary!.rsSeconds, 300);
      expect(summary.rsVerses, 3);
    });

    testWidgets('shows an error when adding a manual session fails', (
      tester,
    ) async {
      final viewModel = await pumpPanel(tester);
      await tester.tap(find.byKey(const ValueKey('addManualSessionButton')));
      await tester.pumpAndSettle();
      await tester.enterText(minutesField(), '5');
      await tester.enterText(versesField(), '2');

      await tester.runAsync(() async {
        database.dispose();
        databaseDisposed = true;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.tap(find.byKey(const ValueKey('manualSessionSubmit')));
      await waitFor(tester, () => messenger.messages.isNotEmpty);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(viewModel.sessions, isEmpty);
      expect(messenger.messages.single.text, startsWith('Error: '));

      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
    });

    testWidgets('shows an error when deleting a manual session fails', (
      tester,
    ) async {
      final manual = (await tester.runAsync(
        () => seedSession(
          startTime: DateTime(2026, 11, 17, 9, 30),
          readSeconds: 120,
          verses: 2,
          isManual: true,
        ),
      ))!;
      final viewModel = (await tester.runAsync(newViewModel))!;
      getIt.registerSingleton<MessengerViewModel>(messenger);

      await tester.pumpWidget(
        buildApp(DayActivityLogPanel(viewModel: viewModel)),
      );
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        database.dispose();
        databaseDisposed = true;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.tap(
        find.byKey(ValueKey('deleteManualSession-${manual.id}')),
      );
      await waitFor(tester, () => messenger.messages.isNotEmpty);
      await tester.pumpAndSettle();

      expect(find.text('Manually added'), findsOneWidget);
      expect(messenger.messages.single.text, startsWith('Error: '));

      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
    });

    test(
      'invalid manual input throws without changing state, then a valid add works',
      () async {
        await seedSession(
          startTime: DateTime(2026, 11, 17, 8),
          readSeconds: 60,
          verses: 1,
        );
        final viewModel = await newDirectViewModel();
        final sessionsBefore = viewModel.sessions;
        final minutesBefore = viewModel.totalMinutes;
        final versesBefore = viewModel.totalVerses;

        await expectLater(
          viewModel.addManualSession(minutes: -1, verses: 1),
          throwsArgumentError,
        );

        expect(viewModel.sessions, sessionsBefore);
        expect(viewModel.totalMinutes, minutesBefore);
        expect(viewModel.totalVerses, versesBefore);
        expect(await database.session.listForDate(date, planId), hasLength(1));

        await viewModel.addManualSession(minutes: 5.5, verses: 2);

        expect(viewModel.sessions, hasLength(2));
        expect(viewModel.sessions.last.isManual, isTrue);
        expect(viewModel.sessions.last.readSeconds, 330);
        expect(viewModel.totalMinutes, minutesBefore + 5.5);
        expect(viewModel.totalVerses, versesBefore + 2);
        expect(await database.session.listForDate(date, planId), hasLength(2));
      },
    );

    test(
      'deleting a missing or already-deleted session throws without changing state',
      () async {
        final manual = await seedSession(
          startTime: DateTime(2026, 11, 17, 9, 30),
          readSeconds: 120,
          verses: 2,
          isManual: true,
        );
        final viewModel = await newDirectViewModel();
        expect(viewModel.sessions, hasLength(1));

        await expectLater(
          viewModel.deleteManualSession(manual.id! + 1000),
          throwsA(isA<StateError>()),
        );

        expect(viewModel.sessions.map((session) => session.sessionId), [
          manual.id,
        ]);
        expect(viewModel.totalMinutes, 2);
        expect(viewModel.totalVerses, 2);

        await viewModel.deleteManualSession(manual.id!);

        expect(viewModel.sessions, isEmpty);
        expect(await database.session.getById(manual.id!), isNull);
        expect(await database.daySummary.get(planId, date), isNull);

        await expectLater(
          viewModel.deleteManualSession(manual.id!),
          throwsA(isA<StateError>()),
        );

        expect(viewModel.sessions, isEmpty);
        expect(viewModel.totalMinutes, 0);
        expect(viewModel.totalVerses, 0);
      },
    );
  });

  group('refresh', () {
    test('a newer refresh cancels the in-flight one and wins', () async {
      await seedSession(readSeconds: 60, verses: 1);
      final viewModel = await newDirectViewModel();

      final first = viewModel.refresh();
      final second = viewModel.refresh();

      await expectLater(first, throwsA(isA<CancelledError>()));
      await second;

      expect(viewModel.sessions, hasLength(1));
      expect(viewModel.sessions.single.verses, 1);
      expect(viewModel.totalMinutes, 1);
    });

    test(
      'does not notify after dispose while a refresh is in flight',
      () async {
        await seedSession(readSeconds: 60, verses: 1);
        final viewModel = await DayActivityLogViewModel.create(
          readingPlanId: planId,
          date: date,
          queries: database.queries,
          planService: planService,
        );
        var notifications = 0;
        viewModel.addListener(() => notifications++);

        final future = viewModel.refresh();
        viewModel.dispose();

        await expectLater(future, throwsA(isA<CancelledError>()));
        expect(notifications, 0);
      },
    );

    test(
      'propagates an error after a successful load and keeps state',
      () async {
        await seedSession(readSeconds: 60, verses: 1);
        final viewModel = await newDirectViewModel();
        database.dispose();
        databaseDisposed = true;
        await Future<void>.delayed(const Duration(milliseconds: 100));

        await expectLater(viewModel.refresh(), throwsA(isA<Object>()));

        expect(viewModel.sessions, hasLength(1));
        expect(viewModel.totalMinutes, 1);
      },
    );
  });

  group('navigation', () {
    test('create propagates a load error from a closed database', () async {
      database.dispose();
      databaseDisposed = true;
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await expectLater(newViewModel(), throwsA(isA<Object>()));
    });

    testWidgets('back closes the panel', (tester) async {
      await tester.runAsync(() => seedSession(readSeconds: 60, verses: 1));
      final viewModel = (await tester.runAsync(newViewModel))!;

      await tester.pumpWidget(
        buildApp(
          _ActivityLogLauncher(viewModel: viewModel, messenger: messenger),
        ),
      );
      await tester.tap(find.text('Open activity'));
      await tester.pumpAndSettle();
      expect(find.byType(DayActivityLogPanel), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(DayActivityLogPanel), findsNothing);
      expect(find.text('Open activity'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('navigateTo reports load errors without opening the panel', (
      tester,
    ) async {
      registerRealDependencies();
      await tester.runAsync(() async {
        database.dispose();
        databaseDisposed = true;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });

      await tester.pumpWidget(
        buildApp(
          _NavigateToLauncher(
            date: date,
            readingPlanId: planId,
            messenger: messenger,
          ),
        ),
      );
      await tester.tap(find.text('Open activity'));
      await waitFor(tester, () => messenger.messages.isNotEmpty);
      await tester.pumpAndSettle();

      expect(find.byType(DayActivityLogPanel), findsNothing);
      expect(find.text('Open activity'), findsOneWidget);

      final l10n = AppLocalizations.of(
        tester.element(find.text('Open activity')),
      )!;
      expect(find.text(l10n.errorLoadingContent), findsOneWidget);
      expect(messenger.messages.single.text, l10n.errorLoadingContent);

      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'navigateTo uses the registered messenger when none is provided',
      (tester) async {
        registerRealDependencies();
        getIt.registerSingleton<MessengerViewModel>(messenger);
        await tester.runAsync(() async {
          database.dispose();
          databaseDisposed = true;
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });

        await tester.pumpWidget(
          buildApp(_NavigateToLauncher(date: date, readingPlanId: planId)),
        );
        await tester.tap(find.text('Open activity'));
        await waitFor(tester, () => messenger.messages.isNotEmpty);
        await tester.pumpAndSettle();

        expect(find.byType(DayActivityLogPanel), findsNothing);
        final l10n = AppLocalizations.of(
          tester.element(find.text('Open activity')),
        )!;
        expect(messenger.messages.single.text, l10n.errorLoadingContent);

        await tester.pump(const Duration(seconds: 8));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('navigateTo opens the panel for the requested day', (
      tester,
    ) async {
      await tester.runAsync(
        () => seedSession(
          startTime: DateTime(2026, 11, 17, 9, 5),
          readSeconds: 300,
          verses: 2,
        ),
      );
      registerRealDependencies();

      await tester.pumpWidget(
        buildApp(
          _NavigateToLauncher(
            date: date,
            readingPlanId: planId,
            messenger: messenger,
          ),
        ),
      );
      await tester.tap(find.text('Open activity'));
      await waitFor(
        tester,
        () => find.byType(DayActivityLogPanel).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();

      expect(find.byType(DayActivityLogPanel), findsOneWidget);
      expect(find.text('Nov 17, 2026'), findsOneWidget);
      expect(find.text('09:05'), findsOneWidget);
      expect(find.text('5 min • 2 verses'), findsNWidgets(2));
      expect(messenger.messages, isEmpty);
    });

    testWidgets('navigateTo disposes the view model when context unmounts', (
      tester,
    ) async {
      registerRealDependencies();
      late BuildContext staleContext;

      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) {
              staleContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpWidget(buildApp(const SizedBox.shrink()));
      await tester.runAsync(
        () => DayActivityLogPanel.navigateTo(
          staleContext,
          date,
          readingPlanId: planId,
          messenger: messenger,
        ),
      );

      expect(find.byType(DayActivityLogPanel), findsNothing);
      expect(messenger.messages, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}

class _ActivityLogLauncher extends StatelessWidget {
  const _ActivityLogLauncher({required this.viewModel, this.messenger});

  final DayActivityLogViewModel viewModel;
  final FakeMessengerViewModel? messenger;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DayActivityLogPanel(
                  viewModel: viewModel,
                  messenger: messenger,
                ),
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
  const _NavigateToLauncher({
    required this.date,
    required this.readingPlanId,
    this.messenger,
  });

  final DateTime date;
  final int readingPlanId;
  final FakeMessengerViewModel? messenger;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await DayActivityLogPanel.navigateTo(
              context,
              date,
              readingPlanId: readingPlanId,
              messenger: messenger,
            );
          },
          child: const Text('Open activity'),
        ),
      ),
    );
  }
}
