import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/asyncutils/cancellation.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/reading_plan/data_access/day_summary_repository.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_queries.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_read_models.dart';
import 'package:gbt/reading_plan/data_access/rs_database.dart';
import 'package:gbt/reading_plan/data_access/session_log_repository.dart';
import 'package:gbt/reading_plan/data_access/session_repository.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/reading_session_service.dart';
import 'package:gbt/reading_plan/ui/day_activity_log_panel.dart';
import 'package:gbt/reading_plan/ui/edit_reading_plan_panel.dart';
import 'package:gbt/reading_plan/ui/reading_plan_detail_panel.dart';
import 'package:gbt/reading_plan/ui/reading_plan_detail_view_model.dart';
import 'package:gbt/reading_plan/ui/reading_session_view_model.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/messaging/messenger_host.dart';
import 'package:gbt/ui/messaging/messenger_view_model.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/bible_navigation_fixture.dart';
import '../../fixtures/fake_messenger_view_model.dart';
import '../../fixtures/fake_navigation_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingSessionDatabase database;
  late ReadingPlanService planService;
  late ReadingSessionViewModel sessionViewModel;
  late FakeNavigationViewModel navigationViewModel;
  late FakeMessengerViewModel messenger;
  late DateTime today;
  late DateTime currentMonth;
  var databaseDisposed = false;
  var sessionViewModelDisposed = false;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    databaseDisposed = false;
    sessionViewModelDisposed = false;
    today = dateOnly(DateTime.now());
    currentMonth = monthStart(today);
    messenger = FakeMessengerViewModel();
    database = ReadingSessionDatabase.withDependencies(
      databasePath: inMemoryDatabasePath,
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    await database.init();
    planService = ReadingPlanService.withDependencies(database: database);

    navigationViewModel = FakeNavigationViewModel();
    sessionViewModel = ReadingSessionViewModel.withDependencies(
      service: ReadingSessionService.withDatabase(database),
      queries: database.queries,
      navigationViewModel: navigationViewModel,
    );

    getIt.registerSingleton<ReadingPlanQueries>(database.queries);
    getIt.registerSingleton<ReadingPlanService>(planService);
    getIt.registerSingleton<ReadingSessionViewModel>(sessionViewModel);
    getIt.registerSingleton<MessengerViewModel>(messenger);
    getIt.registerSingleton<BibleNavigation>(createTestBibleNavigation());
  });

  tearDown(() async {
    if (!sessionViewModelDisposed) sessionViewModel.dispose();
    messenger.dispose();
    if (!databaseDisposed) database.dispose();
    await getIt.reset();
  });

  Future<ReadingPlanDetailViewModel> newViewModel(int planId) {
    return ReadingPlanDetailViewModel.create(
      planId: planId,
      queries: database.queries,
      planService: planService,
      sessionViewModel: sessionViewModel,
    );
  }

  Future<ReadingPlanDetailViewModel> newDirectViewModel(int planId) async {
    final viewModel = await newViewModel(planId);
    addTearDown(viewModel.dispose);
    return viewModel;
  }

  Future<int> createPlan({
    String name = 'Ruth Plan',
    GoalType goalType = GoalType.verses,
    int goalValue = 10,
    List<int> bookIds = const [8],
  }) {
    return planService.saveReadingPlan(
      planName: name,
      goalType: goalType,
      goalValue: goalValue,
      bookIds: bookIds,
    );
  }

  Future<void> seedDayProgress(
    int planId,
    DateTime date, {
    required int verses,
    num minutes = 0,
  }) async {
    final day = dateOnly(date);
    final seconds = (minutes * 60).round();
    final start = DateTime(day.year, day.month, day.day, 9);
    await database.session.commit(
      Session(
        rsDate: day,
        startTime: start,
        endTime: start.add(Duration(seconds: seconds)),
        readSeconds: seconds,
        verses: verses,
        readingPlanId: planId,
      ),
    );
    await database.daySummary.upsert(planId, day);
  }

  Future<void> seedVerseReads(
    int planId,
    int bookId, {
    required int count,
  }) async {
    final inventory = createTestVerseInventory(bookIds: {bookId});
    var remaining = count;
    for (final entry in inventory.entries) {
      for (final verse in entry.value) {
        if (remaining == 0) return;
        await database.verseState.markRead(planId, bookId, entry.key.$2, verse);
        remaining--;
      }
    }
  }

  Future<void> seedDaySummary(
    int planId,
    DateTime date, {
    required int verses,
    required num minutes,
    required DailyGoal goal,
    required bool goalReached,
  }) async {
    await database.unitOfWork((uow) async {
      await uow.executor.insert(
        'rs_day_summary',
        DaySummary(
          readingPlanId: planId,
          rsDate: dateOnly(date),
          rsSeconds: (minutes * 60).round(),
          rsVerses: verses,
          goalType: goal.type,
          goalValue: goal.value,
          goalReached: goalReached,
        ).toMap(),
      );
    });
  }

  Future<void> seedSessionLog(
    int planId,
    int bookId,
    int chapter,
    int verse,
  ) async {
    final at = DateTime(2026, 11, 17, 9);
    final session = await database.session.commit(
      Session(
        rsDate: dateOnly(at),
        startTime: at,
        endTime: at,
        readSeconds: 0,
        verses: 0,
        readingPlanId: planId,
      ),
    );
    await database.sessionLog.append(
      SessionLogEntry(
        sessionId: session.id!,
        readingPlanId: planId,
        bookId: bookId,
        chapter: chapter,
        verse: verse,
        dateTime: at,
      ),
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
      await tester.pump(const Duration(milliseconds: 20));
    }
    fail('Timed out waiting for the widget to update.');
  }

  Future<ReadingPlanDetailViewModel> pumpDetail(
    WidgetTester tester,
    int planId,
  ) async {
    final viewModel = (await tester.runAsync(() => newViewModel(planId)))!;
    await tester.pumpWidget(buildApp(_DetailLauncher(viewModel: viewModel)));
    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();
    return viewModel;
  }

  group('layout', () {
    testWidgets('renders the plan summary and today\'s progress', (
      tester,
    ) async {
      final planId = (await tester.runAsync(() => createPlan()))!;
      await tester.runAsync(
        () => seedDayProgress(planId, today, verses: 3, minutes: 7),
      );

      await pumpDetail(tester, planId);

      expect(find.text('Ruth Plan'), findsOneWidget);
      expect(find.text('Start at Ruth 1:1'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.text('Total Progress'), findsOneWidget);
      expect(find.text("Today's Progress"), findsOneWidget);
      expect(find.text('0 of 1 books'), findsOneWidget);
      expect(find.textContaining('days remaining'), findsOneWidget);
      expect(find.text('Ruth'), findsOneWidget);
    });

    testWidgets('falls back to Genesis when the plan has no books', (
      tester,
    ) async {
      final planId = (await tester.runAsync(
        () => createPlan(bookIds: const []),
      ))!;

      await pumpDetail(tester, planId);

      expect(find.text('Start at Genesis 1:1'), findsOneWidget);
      expect(find.text('Ruth'), findsNothing);
    });

    testWidgets('shows the complete state when every verse is read', (
      tester,
    ) async {
      final planId = (await tester.runAsync(() => createPlan()))!;
      await tester.runAsync(() => seedVerseReads(planId, 8, count: 85));

      await pumpDetail(tester, planId);

      expect(find.text('Plan complete!'), findsOneWidget);
      expect(find.text('1 of 1 books'), findsOneWidget);
      expect(find.text('Resume at Ruth 1:1'), findsOneWidget);
      expect(find.text('100%'), findsNWidgets(2));
    });

    test('estimates completion for a minutes goal', () async {
      final planId = await createPlan(goalType: GoalType.minutes, goalValue: 5);
      final viewModel = await newDirectViewModel(planId);

      expect(viewModel.hasEstimate, isTrue);
      expect(viewModel.estimatedDays, 4);
    });

    test('has no estimate when the goal cannot make progress', () async {
      final planId = await createPlan(goalValue: 0);
      final viewModel = await newDirectViewModel(planId);

      expect(viewModel.hasEstimate, isFalse);
      expect(viewModel.estimatedDays, 0);
    });
  });

  group("today's progress", () {
    testWidgets('shows verse and time progress toward a verse goal', (
      tester,
    ) async {
      final planId = (await tester.runAsync(() => createPlan()))!;
      await tester.runAsync(
        () => seedDayProgress(planId, today, verses: 3, minutes: 7),
      );

      await pumpDetail(tester, planId);

      expect(find.text('3/10 verses'), findsOneWidget);
      expect(find.text('7 minutes'), findsOneWidget);
      expect(find.text('30%'), findsNWidgets(2));
    });

    testWidgets('rounds minutes to the nearest tenth', (tester) async {
      final planId = (await tester.runAsync(() => createPlan()))!;
      await tester.runAsync(
        () => seedDayProgress(planId, today, verses: 3, minutes: 7.46),
      );

      await pumpDetail(tester, planId);

      expect(find.text('7.5 minutes'), findsOneWidget);
    });

    testWidgets('omits the verse target for a minutes goal', (tester) async {
      final planId = (await tester.runAsync(
        () => createPlan(goalType: GoalType.minutes, goalValue: 20),
      ))!;
      await tester.runAsync(
        () => seedDayProgress(planId, today, verses: 3, minutes: 7),
      );

      await pumpDetail(tester, planId);

      expect(find.text('3 verses'), findsOneWidget);
      expect(find.text('7/20 minutes'), findsOneWidget);
      expect(find.text('35%'), findsNWidgets(2));
    });

    test('reports no goal progress when the goal is zero', () async {
      final planId = await createPlan(goalValue: 0);
      await seedDaySummary(
        planId,
        today,
        verses: 3,
        minutes: 7,
        goal: const DailyGoal(GoalType.verses, 0),
        goalReached: false,
      );
      final viewModel = await newDirectViewModel(planId);

      expect(viewModel.goalValue, 0);
      expect(viewModel.todaysProgress.verses, 3);
      expect(viewModel.todaysGoalProgress, 0);
    });

    test('uses the stored goal snapshot for calendar fractions', () async {
      final planId = await createPlan(goalValue: 20);
      await seedDaySummary(
        planId,
        today,
        verses: 3,
        minutes: 2,
        goal: const DailyGoal(GoalType.verses, 5),
        goalReached: false,
      );
      final viewModel = await newDirectViewModel(planId);

      expect(viewModel.calendarProgress[today.day], closeTo(0.6, 1e-9));
      expect(viewModel.todaysGoalProgress, closeTo(0.6, 1e-9));
      expect(viewModel.dayProgress(today.day)!.verses, 3);
    });

    test('clamps calendar progress above the stored goal', () async {
      final planId = await createPlan(goalValue: 20);
      await seedDaySummary(
        planId,
        today,
        verses: 20,
        minutes: 10,
        goal: const DailyGoal(GoalType.verses, 10),
        goalReached: false,
      );
      final viewModel = await newDirectViewModel(planId);

      expect(viewModel.calendarProgress[today.day], 1);
    });
  });

  group('bookmark', () {
    testWidgets('toggles the bookmark and persists each state', (tester) async {
      final planId = (await tester.runAsync(() => createPlan()))!;

      await pumpDetail(tester, planId);

      await tester.tap(find.byIcon(Icons.bookmark_border));
      await waitFor(
        tester,
        () => find.byIcon(Icons.bookmark).evaluate().isNotEmpty,
      );

      var plan = await tester.runAsync(
        () => database.readingPlans.getById(planId),
      );
      expect(plan!.isBookmarked, isTrue);
      expect(find.byIcon(Icons.bookmark_border), findsNothing);

      await tester.tap(find.byIcon(Icons.bookmark));
      await waitFor(
        tester,
        () => find.byIcon(Icons.bookmark_border).evaluate().isNotEmpty,
      );

      plan = await tester.runAsync(() => database.readingPlans.getById(planId));
      expect(plan!.isBookmarked, isFalse);
      expect(find.byIcon(Icons.bookmark), findsNothing);
    });

    test('keeps the old bookmark state when persistence fails', () async {
      final planId = await createPlan();
      final viewModel = await newDirectViewModel(planId);
      database.dispose();
      databaseDisposed = true;
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await expectLater(viewModel.toggleBookmark(), throwsA(isA<Object>()));

      expect(viewModel.isBookmarked, isFalse);
    });
  });

  group('edit plan', () {
    testWidgets('opens the real edit panel and refreshes on return', (
      tester,
    ) async {
      final planId = (await tester.runAsync(() => createPlan()))!;

      await pumpDetail(tester, planId);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await waitFor(
        tester,
        () => find.byType(EditReadingPlanPanel).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        final plan = await database.readingPlans.getById(planId);
        await database.readingPlans.commit(
          plan!.copyWith(planName: 'Renamed Plan'),
        );
      });
      await tester.tap(
        find.descendant(
          of: find.byType(EditReadingPlanPanel),
          matching: find.byIcon(Icons.arrow_back),
        ),
      );
      await waitFor(
        tester,
        () => find.text('Renamed Plan').evaluate().isNotEmpty,
      );

      expect(find.text('Renamed Plan'), findsOneWidget);
    });
  });

  group('books list', () {
    testWidgets('renders books in order without reorder handles', (
      tester,
    ) async {
      final planId = (await tester.runAsync(
        () => createPlan(bookIds: const [8, 20]),
      ))!;

      await pumpDetail(tester, planId);

      expect(find.text('Ruth'), findsOneWidget);
      expect(find.text('Proverbs'), findsOneWidget);
      expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);
      expect(find.byType(ReorderableListView), findsNothing);
      expect(
        tester.getTopLeft(find.text('Ruth')).dy,
        lessThan(tester.getTopLeft(find.text('Proverbs')).dy),
      );
    });

    testWidgets('renders total and per-book progress for plan books', (
      tester,
    ) async {
      final planId = (await tester.runAsync(
        () => createPlan(bookIds: const [63, 64]),
      ))!;
      await tester.runAsync(() async {
        await seedVerseReads(planId, 63, count: 13);
        await seedVerseReads(planId, 64, count: 5);
      });

      await pumpDetail(tester, planId);

      expect(find.text('1 of 2 books'), findsOneWidget);
      expect(find.text('64%'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('33%'), findsOneWidget);
    });

    test('reports zero progress for books without stats', () async {
      final planId = await createPlan(bookIds: const [8, 999]);
      final viewModel = await newDirectViewModel(planId);

      expect(viewModel.bookStats.keys, [8, 999]);
      expect(viewModel.progressForBook(8), 0);
      expect(viewModel.progressForBook(999), 0);
      expect(viewModel.progressForBook(12345), 0);
      expect(viewModel.totalVerses, 85);
    });
  });

  group('session start', () {
    testWidgets('starts a real session and closes the detail routes', (
      tester,
    ) async {
      final planId = (await tester.runAsync(() => createPlan()))!;

      await pumpDetail(tester, planId);

      await tester.tap(find.text('Start at Ruth 1:1'));
      await waitFor(
        tester,
        () => find.byType(ReadingPlanDetailPanel).evaluate().isEmpty,
      );

      expect(find.byType(ReadingPlanDetailPanel), findsNothing);
      expect(find.text('Open detail'), findsOneWidget);
      expect(sessionViewModel.hasActiveSession, isTrue);

      final sessions = await tester.runAsync(
        () => database.session.listForDate(today, planId),
      );
      expect(sessions, hasLength(1));
      expect(sessions!.single.verses, 0);

      sessionViewModel.dispose();
      sessionViewModelDisposed = true;
    });

    testWidgets('shows resume wording once reading has started', (
      tester,
    ) async {
      final planId = (await tester.runAsync(() => createPlan()))!;
      await tester.runAsync(() => seedVerseReads(planId, 8, count: 1));

      await pumpDetail(tester, planId);

      expect(find.text('Resume at Ruth 1:1'), findsOneWidget);
      expect(find.text('Start at Ruth 1:1'), findsNothing);
    });

    testWidgets('uses the next unread book as the resume target', (
      tester,
    ) async {
      final planId = (await tester.runAsync(
        () => createPlan(bookIds: const [8, 20]),
      ))!;
      await tester.runAsync(() async {
        await seedSessionLog(planId, 8, 4, 22);
        await database.verseState.markRead(planId, 8, 4, 22);
      });

      await pumpDetail(tester, planId);

      expect(find.text('Resume at Proverbs 1:1'), findsOneWidget);
    });

    test('startReadingSession throws when the plan is gone', () async {
      final planId = await createPlan();
      final viewModel = await newDirectViewModel(planId);
      await planService.deleteReadingPlan(planId);

      await expectLater(
        viewModel.startReadingSession(),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('month progress', () {
    testWidgets('navigates between months and loads their progress', (
      tester,
    ) async {
      final planId = (await tester.runAsync(() => createPlan()))!;
      final nextMonth = DateTime(currentMonth.year, currentMonth.month + 1);
      await tester.runAsync(
        () => seedDayProgress(
          planId,
          DateTime(nextMonth.year, nextMonth.month, 1),
          verses: 5,
          minutes: 5,
        ),
      );

      await pumpDetail(tester, planId);

      final context = tester.element(find.byType(ReadingPlanDetailPanel));
      final localizations = MaterialLocalizations.of(context);

      expect(
        find.text(localizations.formatMonthYear(currentMonth)),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.chevron_right));
      await waitFor(
        tester,
        () => find
            .text(localizations.formatMonthYear(nextMonth))
            .evaluate()
            .isNotEmpty,
      );

      expect(find.text('50%'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await waitFor(
        tester,
        () => find
            .text(localizations.formatMonthYear(currentMonth))
            .evaluate()
            .isNotEmpty,
      );

      expect(
        find.text(localizations.formatMonthYear(currentMonth)),
        findsOneWidget,
      );
    });

    testWidgets('shows checked days from the visible month progress', (
      tester,
    ) async {
      final planId = (await tester.runAsync(() => createPlan(goalValue: 3)))!;
      await tester.runAsync(
        () => seedDayProgress(planId, today, verses: 3, minutes: 1),
      );

      await pumpDetail(tester, planId);

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    test(
      'a newer month navigation cancels the in-flight one and wins',
      () async {
        final planId = await createPlan();
        final viewModel = await newDirectViewModel(planId);
        final previousMonth = DateTime(
          currentMonth.year,
          currentMonth.month - 1,
        );

        final first = viewModel.showNextMonth();
        final second = viewModel.showPreviousMonth();

        await expectLater(first, throwsA(isA<CancelledError>()));
        await second;

        expect(viewModel.visibleMonth, previousMonth);
      },
    );

    test(
      'does not notify after dispose while a month load is in flight',
      () async {
        final planId = await createPlan();
        final viewModel = await ReadingPlanDetailViewModel.create(
          planId: planId,
          queries: database.queries,
          planService: planService,
          sessionViewModel: sessionViewModel,
        );
        var notifications = 0;
        viewModel.addListener(() => notifications++);

        final future = viewModel.showNextMonth();
        viewModel.dispose();

        await expectLater(future, throwsA(isA<CancelledError>()));
        expect(notifications, 0);
      },
    );

    test('propagates a month load error and keeps the visible month', () async {
      final planId = await createPlan();
      final viewModel = await newDirectViewModel(planId);
      database.dispose();
      databaseDisposed = true;
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await expectLater(viewModel.showNextMonth(), throwsA(isA<Object>()));

      expect(viewModel.visibleMonth, currentMonth);
    });
  });

  group('day activity log', () {
    testWidgets('opens the real log for the selected day and plan', (
      tester,
    ) async {
      final planId = (await tester.runAsync(() => createPlan()))!;
      await tester.runAsync(
        () => seedDayProgress(planId, today, verses: 3, minutes: 7),
      );

      await pumpDetail(tester, planId);

      await tester.tap(find.byKey(ValueKey('calendar-day-${today.day}')));
      await waitFor(
        tester,
        () => find.byType(DayActivityLogPanel).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();

      expect(find.byType(DayActivityLogPanel), findsOneWidget);
      expect(find.text('7 min • 3 verses'), findsNWidgets(2));
      expect(find.text('No verses read'), findsOneWidget);
    });

    testWidgets('opens the real log for an empty day', (tester) async {
      final planId = (await tester.runAsync(() => createPlan()))!;
      final emptyDay = today.day == 1 ? 2 : 1;

      await pumpDetail(tester, planId);

      await tester.tap(find.byKey(ValueKey('calendar-day-$emptyDay')));
      await waitFor(
        tester,
        () => find.byType(DayActivityLogPanel).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();

      expect(find.byType(DayActivityLogPanel), findsOneWidget);
      expect(find.text('0 min • 0 verses'), findsOneWidget);
    });

    testWidgets('refreshes the detail when the real log returns', (
      tester,
    ) async {
      final planId = (await tester.runAsync(() => createPlan()))!;

      await pumpDetail(tester, planId);

      await tester.tap(find.byKey(ValueKey('calendar-day-${today.day}')));
      await waitFor(
        tester,
        () => find.byType(DayActivityLogPanel).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        final plan = await database.readingPlans.getById(planId);
        await database.readingPlans.commit(
          plan!.copyWith(planName: 'Refreshed Plan'),
        );
      });
      await tester.tap(
        find.descendant(
          of: find.byType(DayActivityLogPanel),
          matching: find.byIcon(Icons.arrow_back),
        ),
      );
      await waitFor(
        tester,
        () => find.text('Refreshed Plan').evaluate().isNotEmpty,
      );

      expect(find.text('Refreshed Plan'), findsOneWidget);
    });

    testWidgets('ignores a second day tap while the log is opening', (
      tester,
    ) async {
      final planId = (await tester.runAsync(() => createPlan()))!;

      await pumpDetail(tester, planId);

      final dayFinder = find.byKey(ValueKey('calendar-day-${today.day}'));
      await tester.tap(dayFinder);
      await tester.tap(dayFinder);
      await waitFor(
        tester,
        () => find.byType(DayActivityLogPanel).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();

      expect(find.byType(DayActivityLogPanel), findsOneWidget);
    });
  });

  group('refresh', () {
    test('a newer refresh cancels the in-flight one and wins', () async {
      final planId = await createPlan(name: 'Concurrent Plan');
      final viewModel = await newDirectViewModel(planId);

      final first = viewModel.refresh();
      final second = viewModel.refresh();

      await expectLater(first, throwsA(isA<CancelledError>()));
      await second;

      expect(viewModel.planName, 'Concurrent Plan');
      expect(viewModel.totalVerses, 85);
      expect(viewModel.bookStats[8]!.totalVerses, 85);
    });

    test(
      'does not notify after dispose while a refresh is in flight',
      () async {
        final planId = await createPlan(name: 'Dispose Plan');
        final viewModel = await ReadingPlanDetailViewModel.create(
          planId: planId,
          queries: database.queries,
          planService: planService,
          sessionViewModel: sessionViewModel,
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
        final planId = await createPlan();
        final viewModel = await newDirectViewModel(planId);
        database.dispose();
        databaseDisposed = true;
        await Future<void>.delayed(const Duration(milliseconds: 100));

        await expectLater(viewModel.refresh(), throwsA(isA<Object>()));

        expect(viewModel.planName, 'Ruth Plan');
        expect(viewModel.totalVerses, 85);
      },
    );

    test(
      'updates today\'s progress without resetting the visible month',
      () async {
        final planId = await createPlan(name: 'Month Refresh Plan');
        final viewModel = await newDirectViewModel(planId);
        final nextMonth = DateTime(currentMonth.year, currentMonth.month + 1);

        await viewModel.showNextMonth();
        expect(viewModel.visibleMonth, nextMonth);

        await seedDayProgress(planId, today, verses: 5, minutes: 9);
        await viewModel.refresh();

        expect(viewModel.visibleMonth, nextMonth);
        expect(viewModel.todaysProgress.verses, 5);
        expect(viewModel.todaysProgress.minutes, 9);
      },
    );
  });

  group('navigation helper', () {
    test('create throws when the plan is missing', () async {
      await expectLater(newViewModel(999999), throwsA(isA<StateError>()));
    });

    testWidgets('back closes the panel', (tester) async {
      final planId = (await tester.runAsync(() => createPlan()))!;

      await pumpDetail(tester, planId);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(ReadingPlanDetailPanel), findsNothing);
      expect(find.text('Open detail'), findsOneWidget);
    });

    testWidgets('navigateTo opens the panel for the plan', (tester) async {
      final planId = (await tester.runAsync(() => createPlan()))!;

      await tester.pumpWidget(
        buildApp(
          _NavigateToDetailLauncher(planId: planId, messenger: messenger),
        ),
      );
      await tester.tap(find.text('Open detail'));
      await waitFor(
        tester,
        () => find.byType(ReadingPlanDetailPanel).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();

      expect(find.byType(ReadingPlanDetailPanel), findsOneWidget);
      expect(find.text('Ruth Plan'), findsOneWidget);
      expect(messenger.messages, isEmpty);
    });

    testWidgets('shows an error and stays closed when loading fails', (
      tester,
    ) async {
      final planId = (await tester.runAsync(() => createPlan()))!;
      await tester.runAsync(() async {
        database.dispose();
        databaseDisposed = true;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });

      await tester.pumpWidget(
        buildApp(
          _NavigateToDetailLauncher(planId: planId, messenger: messenger),
        ),
      );
      await tester.tap(find.text('Open detail'));
      await waitFor(tester, () => messenger.messages.isNotEmpty);
      await tester.pumpAndSettle();

      expect(find.byType(ReadingPlanDetailPanel), findsNothing);
      expect(find.text('Open detail'), findsOneWidget);

      final l10n = AppLocalizations.of(
        tester.element(find.text('Open detail')),
      )!;
      expect(find.text(l10n.errorLoadingContent), findsOneWidget);
      expect(messenger.messages.single.text, l10n.errorLoadingContent);

      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'navigateTo uses the registered messenger when none is provided',
      (tester) async {
        final planId = (await tester.runAsync(() => createPlan()))!;
        await tester.runAsync(() async {
          database.dispose();
          databaseDisposed = true;
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });

        await tester.pumpWidget(
          buildApp(_NavigateToDetailLauncher(planId: planId)),
        );
        await tester.tap(find.text('Open detail'));
        await waitFor(tester, () => messenger.messages.isNotEmpty);
        await tester.pumpAndSettle();

        expect(find.byType(ReadingPlanDetailPanel), findsNothing);
        final l10n = AppLocalizations.of(
          tester.element(find.text('Open detail')),
        )!;
        expect(messenger.messages.single.text, l10n.errorLoadingContent);

        await tester.pump(const Duration(seconds: 8));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('navigateTo disposes the view model when context unmounts', (
      tester,
    ) async {
      final planId = (await tester.runAsync(() => createPlan()))!;
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
        () => ReadingPlanDetailPanel.navigateTo(
          staleContext,
          planId,
          messenger: messenger,
        ),
      );

      expect(find.byType(ReadingPlanDetailPanel), findsNothing);
      expect(messenger.messages, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}

class _NavigateToDetailLauncher extends StatelessWidget {
  const _NavigateToDetailLauncher({required this.planId, this.messenger});

  final int planId;
  final FakeMessengerViewModel? messenger;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => ReadingPlanDetailPanel.navigateTo(
            context,
            planId,
            messenger: messenger,
          ),
          child: const Text('Open detail'),
        ),
      ),
    );
  }
}

class _DetailLauncher extends StatelessWidget {
  const _DetailLauncher({required this.viewModel});

  final ReadingPlanDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReadingPlanDetailPanel(viewModel: viewModel),
              ),
            );
          },
          child: const Text('Open detail'),
        ),
      ),
    );
  }
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime monthStart(DateTime value) => DateTime(value.year, value.month);
