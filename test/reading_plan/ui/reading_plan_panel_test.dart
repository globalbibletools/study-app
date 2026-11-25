import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/asyncutils/cancellation.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_queries.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_read_models.dart';
import 'package:gbt/reading_plan/data_access/rs_database.dart';
import 'package:gbt/reading_plan/data_access/session_repository.dart';
import 'package:gbt/reading_plan/model.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/reading_session_service.dart';
import 'package:gbt/reading_plan/ui/edit_reading_plan_panel.dart';
import 'package:gbt/reading_plan/ui/progress_circle.dart';
import 'package:gbt/reading_plan/ui/reading_plan_card.dart';
import 'package:gbt/reading_plan/ui/reading_plan_detail_panel.dart';
import 'package:gbt/reading_plan/ui/reading_plan_panel.dart';
import 'package:gbt/reading_plan/ui/reading_plan_panel_view_model.dart';
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
  late BibleNavigation bibleNavigation;
  late FakeMessengerViewModel messenger;
  late DateTime today;
  var databaseDisposed = false;
  var sessionViewModelDisposed = false;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    databaseDisposed = false;
    sessionViewModelDisposed = false;
    today = DateTime.now();
    messenger = FakeMessengerViewModel();
    bibleNavigation = createTestBibleNavigation();
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

    for (final plan in await database.readingPlans.list()) {
      await planService.deleteReadingPlan(plan.id);
    }

    getIt.registerSingleton<ReadingPlanQueries>(database.queries);
    getIt.registerSingleton<ReadingPlanService>(planService);
    getIt.registerSingleton<ReadingSessionViewModel>(sessionViewModel);
    getIt.registerSingleton<BibleNavigation>(bibleNavigation);
    getIt.registerSingleton<MessengerViewModel>(messenger);
  });

  tearDown(() async {
    if (!sessionViewModelDisposed) sessionViewModel.dispose();
    messenger.dispose();
    if (!databaseDisposed) database.dispose();
    await getIt.reset();
  });

  Future<int> createPlan({
    String name = 'Ruth',
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
    int planId, {
    int verses = 0,
    num minutes = 0,
    DateTime? date,
  }) async {
    final day = dateOnly(date ?? today);
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

  Future<ReadingPlanPanelViewModel> newViewModel() {
    return ReadingPlanPanelViewModel.create(
      queries: database.queries,
      sessionViewModel: sessionViewModel,
    );
  }

  Future<ReadingPlanPanelViewModel> newDirectViewModel() async {
    final viewModel = await newViewModel();
    addTearDown(viewModel.dispose);
    return viewModel;
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

  Future<ReadingPlanPanelViewModel> pumpPanel(WidgetTester tester) async {
    final viewModel = (await tester.runAsync(newViewModel))!;
    await tester.pumpWidget(
      buildApp(Scaffold(body: ReadingPlanPanel(viewModel: viewModel))),
    );
    await tester.pumpAndSettle();
    return viewModel;
  }

  Future<List<String>> planNames() async {
    return [
      for (final plan in await database.readingPlans.list()) plan.planName,
    ];
  }

  group('rendering', () {
    testWidgets('shows the empty state and create button without plans', (
      tester,
    ) async {
      await pumpPanel(tester);

      expect(find.text('No reading plans.'), findsOneWidget);
      expect(find.text('Create your first plan below.'), findsOneWidget);
      expect(find.text('Create New Plan'), findsOneWidget);
      expect(find.byType(ReadingPlanCard), findsNothing);
    });

    testWidgets('shows one card per plan', (tester) async {
      await tester.runAsync(() async {
        await createPlan(name: 'Ruth');
        await createPlan(name: 'Psalms', bookIds: const [19]);
      });

      await pumpPanel(tester);

      expect(find.byType(ReadingPlanCard), findsNWidgets(2));
      expect(find.text('Ruth'), findsOneWidget);
      expect(find.text('Psalms'), findsOneWidget);
    });

    testWidgets('shows the bookmark ribbon only for bookmarked plans', (
      tester,
    ) async {
      final bookmarkedId = (await tester.runAsync(
        () => createPlan(name: 'Bookmarked'),
      ))!;
      final plainId = (await tester.runAsync(
        () => createPlan(name: 'Plain', bookIds: const [19]),
      ))!;
      await tester.runAsync(
        () => planService.setReadingPlanBookmark(bookmarkedId, true),
      );

      await pumpPanel(tester);

      expect(
        find.byKey(ValueKey('plan-bookmark-ribbon-$bookmarkedId')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('plan-bookmark-ribbon-$plainId')),
        findsNothing,
      );
    });

    testWidgets('shows the remaining verses for today', (tester) async {
      final planId = (await tester.runAsync(() => createPlan()))!;
      await tester.runAsync(() => seedDayProgress(planId, verses: 3));

      await pumpPanel(tester);

      expect(find.text('7 verses left today'), findsOneWidget);
    });

    testWidgets('shows the remaining minutes for today', (tester) async {
      final planId = (await tester.runAsync(
        () => createPlan(goalType: GoalType.minutes, goalValue: 30),
      ))!;
      await tester.runAsync(() => seedDayProgress(planId, minutes: 18));

      await pumpPanel(tester);

      expect(find.text('12 minutes left today'), findsOneWidget);
    });

    testWidgets('shows a check and completion label when the goal is reached', (
      tester,
    ) async {
      final planId = (await tester.runAsync(() => createPlan()))!;
      await tester.runAsync(() => seedDayProgress(planId, verses: 12));

      await pumpPanel(tester);

      final label = find.byKey(ValueKey('plan-daily-goal-$planId'));
      expect(label, findsOneWidget);
      expect(find.text('Daily Goal Reached'), findsOneWidget);
      expect(
        find.descendant(of: label, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
    });

    testWidgets('shows overall progress and read over total verses', (
      tester,
    ) async {
      final planId = (await tester.runAsync(() => createPlan()))!;
      await tester.runAsync(() => seedVerseReads(planId, 8, count: 66));

      await pumpPanel(tester);

      final card = find.byType(ReadingPlanCard);
      final circle = tester.widget<ProgressCircle>(
        find.descendant(of: card, matching: find.byType(ProgressCircle)),
      );
      expect(circle.percent, closeTo(66 / 85, 1e-9));
      expect(circle.size, 32);
      expect(find.text('66/85 verses'), findsOneWidget);
    });

    testWidgets('shows edit but no delete action', (tester) async {
      await tester.runAsync(() => createPlan());

      await pumpPanel(tester);

      final card = find.byType(ReadingPlanCard);
      expect(
        find.descendant(of: card, matching: find.byIcon(Icons.edit_outlined)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.byIcon(Icons.delete_outline_rounded),
        ),
        findsNothing,
      );
    });
  });

  group('refresh', () {
    test('create propagates a load error from a closed database', () async {
      database.dispose();
      databaseDisposed = true;
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await expectLater(newViewModel(), throwsA(isA<Object>()));
    });

    test('replaces the plan list with the latest database state', () async {
      await createPlan(name: 'First');
      final viewModel = await newDirectViewModel();
      expect(viewModel.plans.map((plan) => plan.planName), ['First']);

      await createPlan(name: 'Second', bookIds: const [19]);
      await viewModel.refresh();

      expect(
        viewModel.plans.map((plan) => plan.planName),
        containsAll(['First', 'Second']),
      );
    });

    test('a newer refresh cancels the in-flight one and wins', () async {
      await createPlan(name: 'Concurrent');
      final viewModel = await newDirectViewModel();

      final first = viewModel.refresh();
      final second = viewModel.refresh();

      await expectLater(first, throwsA(isA<CancelledError>()));
      await second;

      expect(viewModel.plans.single.planName, 'Concurrent');
    });

    test(
      'does not notify after dispose while a refresh is in flight',
      () async {
        await createPlan(name: 'Dispose');
        final viewModel = await ReadingPlanPanelViewModel.create(
          queries: database.queries,
          sessionViewModel: sessionViewModel,
        );
        var notifications = 0;
        viewModel.addListener(() => notifications++);

        final future = viewModel.refresh();
        final notificationsBeforeDispose = notifications;
        viewModel.dispose();

        await expectLater(future, throwsA(isA<CancelledError>()));
        expect(notifications, notificationsBeforeDispose);
      },
    );
  });

  group('edit', () {
    testWidgets('creates a real plan and refreshes the list', (tester) async {
      await pumpPanel(tester);

      await tester.tap(find.text('Create New Plan'));
      await waitFor(
        tester,
        () => find.byType(EditReadingPlanPanel).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();

      final editor = tester.widget<EditReadingPlanPanel>(
        find.byType(EditReadingPlanPanel),
      );
      editor.viewModel.setBooks([8]);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'New Plan');
      await tester.tap(find.text('Save Reading Plan'));
      await waitFor(
        tester,
        () =>
            find.byType(EditReadingPlanPanel).evaluate().isEmpty &&
            find.text('New Plan').evaluate().isNotEmpty,
      );

      expect(find.text('New Plan'), findsOneWidget);
      expect(await tester.runAsync(planNames), contains('New Plan'));
    });

    testWidgets('edits a real plan and refreshes the list', (tester) async {
      await tester.runAsync(() => createPlan(name: 'Ruth'));
      await pumpPanel(tester);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await waitFor(
        tester,
        () => find.byType(EditReadingPlanPanel).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'Edited Ruth');
      await tester.tap(find.text('Update Reading Plan'));
      await waitFor(
        tester,
        () =>
            find.byType(EditReadingPlanPanel).evaluate().isEmpty &&
            find.text('Edited Ruth').evaluate().isNotEmpty,
      );

      expect(find.text('Edited Ruth'), findsOneWidget);
      expect(await tester.runAsync(planNames), contains('Edited Ruth'));
    });
  });

  group('view plan', () {
    testWidgets('opens the real detail panel and refreshes on return', (
      tester,
    ) async {
      final planId = (await tester.runAsync(() => createPlan(name: 'Ruth')))!;
      await pumpPanel(tester);

      await tester.tap(find.text('Ruth'));
      await waitFor(
        tester,
        () => find.byType(ReadingPlanDetailPanel).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      expect(find.byType(ReadingPlanDetailPanel), findsOneWidget);

      await tester.runAsync(() async {
        final plan = await database.readingPlans.getById(planId);
        await database.readingPlans.commit(
          plan!.copyWith(planName: 'Renamed Ruth'),
        );
      });
      await tester.tap(
        find.descendant(
          of: find.byType(ReadingPlanDetailPanel),
          matching: find.byIcon(Icons.arrow_back),
        ),
      );
      await waitFor(
        tester,
        () => find.text('Renamed Ruth').evaluate().isNotEmpty,
      );

      expect(find.text('Renamed Ruth'), findsOneWidget);
    });
  });

  group('resume', () {
    testWidgets('starts a real session and closes the panel', (tester) async {
      final planId = (await tester.runAsync(() => createPlan()))!;
      final viewModel = (await tester.runAsync(newViewModel))!;

      await tester.pumpWidget(buildApp(_PanelLauncher(viewModel: viewModel)));
      await tester.tap(find.text('Open plans'));
      await tester.pumpAndSettle();

      final resumeButton = find.byKey(ValueKey('plan-resume-$planId'));
      expect(resumeButton, findsOneWidget);
      expect(
        find.descendant(of: resumeButton, matching: find.text('Ruth 1:1')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: resumeButton,
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsOneWidget,
      );

      final buttonRect = tester.getRect(resumeButton);
      await tester.tapAt(Offset(buttonRect.center.dx, buttonRect.bottom - 2));
      await waitFor(
        tester,
        () => find.byType(ReadingPlanPanel).evaluate().isEmpty,
      );

      expect(find.text('Open plans'), findsOneWidget);
      expect(sessionViewModel.hasActiveSession, isTrue);

      final sessions = await tester.runAsync(
        () => database.session.listForDate(dateOnly(today), planId),
      );
      expect(sessions, hasLength(1));

      sessionViewModel.dispose();
      sessionViewModelDisposed = true;
    });

    test('startReadingSession throws when the plan is gone', () async {
      final planId = await createPlan();
      final viewModel = await newDirectViewModel();
      final plan = viewModel.plans.single;
      await planService.deleteReadingPlan(planId);

      await expectLater(
        viewModel.startReadingSession(plan),
        throwsA(isA<StateError>()),
      );
    });
  });
}

class _PanelLauncher extends StatelessWidget {
  const _PanelLauncher({required this.viewModel});

  final ReadingPlanPanelViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    Scaffold(body: ReadingPlanPanel(viewModel: viewModel)),
              ),
            );
          },
          child: const Text('Open plans'),
        ),
      ),
    );
  }
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
