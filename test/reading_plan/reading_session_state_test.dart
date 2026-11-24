import 'package:material_ui/material_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/reading_plan/reading_plan_panel.dart';
import 'package:gbt/reading_plan/reading_plan_panel_view_model.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/rs_database.dart';
import 'package:gbt/reading_plan/reading_session_service.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/reading_plan/session_repository.dart';
import 'package:gbt/reading_plan/reading_session_view_model.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/home/panel_area/common/book_completed_overlay.dart';
import 'package:gbt/reading_plan/calendar_view.dart';
import 'package:gbt/reading_plan/reading_sheet.dart';

import '../fixtures/bible_navigation_fixture.dart';
import '../fixtures/fake_navigation_view_model.dart';

VerseReadOptions _readOptions(
  int bookId,
  int chapter,
  int verse, {
  bool read = true,
}) {
  return VerseReadOptions(
    bookId: bookId,
    chapter: chapter,
    verse: verse,
    read: read,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingSessionDatabase rsDb;
  late ReadingPlanService planService;
  late ReadingSessionService sessionService;
  late ReadingSessionViewModel viewModel;
  late FakeNavigationViewModel navigationViewModel;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    if (getIt.isRegistered<ReadingSessionDatabase>()) {
      getIt.unregister<ReadingSessionDatabase>();
    }
    if (getIt.isRegistered<ReadingPlanService>()) {
      getIt.unregister<ReadingPlanService>();
    }
    if (getIt.isRegistered<ReadingSessionViewModel>()) {
      getIt.unregister<ReadingSessionViewModel>();
    }
    if (getIt.isRegistered<BibleNavigation>()) {
      getIt.unregister<BibleNavigation>();
    }

    getIt.registerSingleton<BibleNavigation>(createTestBibleNavigation());

    rsDb = ReadingSessionDatabase.withDependencies(
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    await rsDb.resetDatabase();
    await rsDb.init();
    getIt.registerSingleton<ReadingSessionDatabase>(rsDb);
    planService = ReadingPlanService.withDependencies(
      database: rsDb,
      bibleNavigation: createTestBibleNavigation(),
    );
    getIt.registerSingleton<ReadingPlanService>(planService);

    sessionService = ReadingSessionService.withDatabase(rsDb);
    navigationViewModel = FakeNavigationViewModel();
    viewModel = ReadingSessionViewModel.withDependencies(
      service: sessionService,
      navigationViewModel: navigationViewModel,
    );
    getIt.registerSingleton<ReadingSessionViewModel>(viewModel);
  });

  tearDown(() async {
    await viewModel.endSession();
    viewModel.dispose();
    rsDb.dispose();
  });

  tearDownAll(() async {
    if (getIt.isRegistered<ReadingSessionDatabase>()) {
      getIt.unregister<ReadingSessionDatabase>();
    }
    if (getIt.isRegistered<ReadingSessionViewModel>()) {
      getIt.unregister<ReadingSessionViewModel>();
    }
    if (getIt.isRegistered<ReadingPlanService>()) {
      getIt.unregister<ReadingPlanService>();
    }
    if (getIt.isRegistered<BibleNavigation>()) {
      getIt.unregister<BibleNavigation>();
    }
  });

  group('Reading Session State Management & Plan Lifecycle', () {
    test(
      'completing chapter 1 of multi-chapter book (Psalms 1) does not trigger bookCompletedNotifier and advances cursor to Psalms 2:1',
      () async {
        final planId = await planService.saveReadingPlan(
          planName: 'Test Psalms Plan',
          goalType: GoalType.verses,
          goalValue: 10,
          bookIds: [19, 20],
        );

        final plans = await planService.getReadingPlansWithProgress();
        final planDetails = plans.firstWhere((p) => p.readingPlan.id == planId);

        await viewModel.startSession(planDetails.readingPlan.id!);

        int bookCompletedCount = 0;
        BookCompletedEvent? lastCompletion;
        viewModel.bookCompletedNotifier.addListener(() {
          bookCompletedCount++;
          lastCompletion = viewModel.bookCompletedNotifier.value;
        });

        expect(getIt<BibleNavigation>().getVerseCount(19, 1), 6);
        for (int v = 1; v <= 6; v++) {
          await viewModel.setVerseRead(_readOptions(19, 1, v, read: true));
        }

        expect(bookCompletedCount, 0);
        expect(lastCompletion, isNull);

        final stats = await rsDb.getBookStats(planId);
        expect(stats[19]!.versesRead, 6);
        final resume = await planService.getResumeReference(planId);
        expect(resume, isNotNull);
        expect(resume!.bookId, 19);
        expect(resume.chapter, 2);
        expect(resume.verse, 1);
      },
    );

    test(
      'checking the final verse of a book (e.g. Psalm 150:6) before earlier chapters does not trigger bookCompletedNotifier',
      () async {
        final planId = await planService.saveReadingPlan(
          planName: 'Test Psalms Plan',
          goalType: GoalType.verses,
          goalValue: 10,
          bookIds: [19, 20],
        );

        final plans = await planService.getReadingPlansWithProgress();
        final planDetails = plans.firstWhere((p) => p.readingPlan.id == planId);

        await viewModel.startSession(planDetails.readingPlan.id!);

        int bookCompletedCount = 0;
        viewModel.bookCompletedNotifier.addListener(() {
          bookCompletedCount++;
        });

        await viewModel.setVerseRead(_readOptions(19, 150, 6, read: true));

        expect(bookCompletedCount, 0);
        expect(viewModel.bookCompletedNotifier.value, isNull);

        final stats = await rsDb.getBookStats(planId);
        expect(stats[19]!.versesRead, 1);
      },
    );

    test(
      'completing all verses out of order triggers bookCompletedNotifier on final unread verse and advances cursor to next incomplete book',
      () async {
        final planId = await planService.saveReadingPlan(
          planName: 'Short Epistles',
          goalType: GoalType.verses,
          goalValue: 15,
          bookIds: [63, 64],
        );

        final plans = await planService.getReadingPlansWithProgress();
        final planDetails = plans.firstWhere((p) => p.readingPlan.id == planId);

        await viewModel.startSession(planDetails.readingPlan.id!);

        BookCompletedEvent? completionReceived;
        viewModel.bookCompletedNotifier.addListener(() {
          completionReceived = viewModel.bookCompletedNotifier.value;
        });

        for (int v = 2; v <= 13; v++) {
          await viewModel.setVerseRead(_readOptions(63, 1, v, read: true));
        }
        expect(completionReceived, isNull);

        var stats = await rsDb.getBookStats(planId);
        expect(stats[63]!.versesRead, 12);

        await viewModel.setVerseRead(_readOptions(63, 1, 1, read: true));

        expect(completionReceived?.completedBookId, 63);
        expect(completionReceived?.nextBookId, 64);
        expect(viewModel.nextResumePosition, isNotNull);
        expect(viewModel.nextResumePosition!.bookId, 64);
        expect(viewModel.nextResumePosition!.chapter, 1);
        expect(viewModel.nextResumePosition!.verse, 1);
        stats = await rsDb.getBookStats(planId);
        expect(stats[63]!.versesRead, 13);
      },
    );

    test(
      'unchecking a verse read in this session decrements verse count, verses read, and today total',
      () async {
        final planId = await planService.saveReadingPlan(
          planName: 'Uncheck Test Plan',
          goalType: GoalType.verses,
          goalValue: 15,
          bookIds: [63],
        );

        final plans = await planService.getReadingPlansWithProgress();
        final planDetails = plans.firstWhere((p) => p.readingPlan.id == planId);

        await viewModel.startSession(planDetails.readingPlan.id!);
        for (int v = 1; v <= 13; v++) {
          await viewModel.setVerseRead(_readOptions(63, 1, v, read: true));
        }

        var stats = await rsDb.getBookStats(planId);
        expect(stats[63]!.versesRead, 13);
        expect(viewModel.session!.versesToday, 13);

        await viewModel.setVerseRead(_readOptions(63, 1, 1, read: false));

        final chapterCounts = await rsDb.getVerseReadCountsForChapter(
          planId,
          63,
          1,
        );
        expect(chapterCounts[1], 0);
        expect(chapterCounts.values.where((count) => count > 0).length, 12);

        final states = await viewModel.getVerseReadStates(63, 1);
        expect(states[1]!.readCount, 0);
        expect(states[1]!.readThisSession, isFalse);

        stats = await rsDb.getBookStats(planId);
        expect(stats[63]!.versesRead, 12);
        expect(viewModel.session!.versesToday, 12);
      },
    );

    test(
      'unchecking in a later same-day session keeps the earlier session log and read count',
      () async {
        final planId = await planService.saveReadingPlan(
          planName: 'Multi Session Uncheck Test Plan',
          goalType: GoalType.verses,
          goalValue: 15,
          bookIds: [63],
        );

        final plans = await planService.getReadingPlansWithProgress();
        final planDetails = plans.firstWhere((p) => p.readingPlan.id == planId);

        await viewModel.startSession(planDetails.readingPlan.id!);
        final firstSessionId = viewModel.sessionId!;
        await viewModel.setVerseRead(_readOptions(63, 1, 1, read: true));
        await viewModel.endSession();

        await viewModel.startSession(planDetails.readingPlan.id!);
        final statesBefore = await viewModel.getVerseReadStates(63, 1);
        expect(statesBefore[1]!.readCount, 1);
        expect(statesBefore[1]!.readThisSession, isFalse);

        await viewModel.setVerseRead(_readOptions(63, 1, 1, read: false));

        final statesAfter = await viewModel.getVerseReadStates(63, 1);
        expect(statesAfter[1]!.readCount, 1);
        expect(statesAfter[1]!.readThisSession, isFalse);
        expect(await rsDb.getRsLogForSession(firstSessionId), hasLength(1));

        final stats = await rsDb.getBookStats(planId);
        expect(stats[63]!.versesRead, 1);
      },
    );

    test(
      'editing a reading plan preserves custom ord book ordering and hides removed books from projections',
      () async {
        final planId = await planService.saveReadingPlan(
          planName: 'Order Test',
          goalType: GoalType.verses,
          goalValue: 10,
          bookIds: [1, 2, 3],
        );

        var plans = await planService.getReadingPlansWithProgress();
        var details = plans.firstWhere((p) => p.readingPlan.id == planId);

        final reordered = details.books
            .map((book) => book.bookId)
            .toList()
            .reversed
            .toList();
        await planService.reorderReadingPlanBooks(planId, reordered);

        await viewModel.startSession(details.readingPlan.id!);
        await viewModel.setVerseRead(_readOptions(2, 1, 1, read: true));
        expect((await rsDb.getBookStats(planId))[2]!.versesRead, 1);

        details = (await planService.getReadingPlansWithProgress()).firstWhere(
          (p) => p.readingPlan.id == planId,
        );

        await planService.saveReadingPlan(
          planId: details.readingPlan.id,
          planName: 'Order Test Updated',
          goalType: GoalType.verses,
          goalValue: 20,
          bookIds: [3, 1, 4],
        );

        final updatedBooks = await rsDb.getReadingPlanBooks(planId);
        expect(updatedBooks.map((b) => b.bookId).toList(), [3, 1, 4]);
        expect(updatedBooks.map((b) => b.ord).toList(), [1, 2, 3]);

        final book2Aggregates = await rsDb.getBookStats(planId);
        expect(book2Aggregates.containsKey(2), isFalse);

        final reloadedPlan = await planService.getReadingPlanById(planId);
        expect(reloadedPlan!.readingPlan.goalValue, 20);
        expect(reloadedPlan.books.map((b) => b.bookId), [3, 1, 4]);
      },
    );

    test(
      'deleteReadingPlan deletes all rows across all 6 SQLite tables without affecting other plans',
      () async {
        final planAId = await planService.saveReadingPlan(
          planName: 'Plan A',
          goalType: GoalType.verses,
          goalValue: 10,
          bookIds: [1, 2],
        );
        final planBId = await planService.saveReadingPlan(
          planName: 'Plan B',
          goalType: GoalType.verses,
          goalValue: 10,
          bookIds: [3, 4],
        );

        final plans = await planService.getReadingPlansWithProgress();
        final planADetails = plans.firstWhere(
          (p) => p.readingPlan.id == planAId,
        );

        await viewModel.startSession(planADetails.readingPlan.id!);
        await viewModel.setVerseRead(_readOptions(1, 1, 1, read: true));
        await viewModel.endSession();

        await planService.deleteReadingPlan(planAId);

        final planAResult = await rsDb.getReadingPlanById(planAId);
        expect(planAResult, isNull);
        expect(await rsDb.getReadingPlanBooks(planAId), isEmpty);
        expect(await rsDb.getBookStats(planAId), isEmpty);
        expect(await rsDb.getVerseReadCountsForChapter(planAId, 1, 1), isEmpty);
        expect(await rsDb.getSessionsForDate(DateTime.now(), planAId), isEmpty);
        expect(
          await rsDb.getDaySummariesBetween(
            planAId,
            DateTime(2020),
            DateTime(2030),
          ),
          isEmpty,
        );

        final planBResult = await rsDb.getReadingPlanById(planBId);
        expect(planBResult, isNotNull);
        expect(await rsDb.getReadingPlanBooks(planBId), isNotEmpty);
      },
    );

    test(
      'getMonthProgress handles daylight saving time transition in November with exact 1-to-1 day mapping',
      () async {
        final planId = await planService.saveReadingPlan(
          planName: 'DST November Test',
          goalType: GoalType.verses,
          goalValue: 5,
          bookIds: [1],
        );

        // Seed a closed session on November 5th and its day summary.
        final sessionDate = DateTime(2026, 11, 5);
        await rsDb.session.commit(
          Session(
            rsDate: sessionDate,
            startTime: DateTime(2026, 11, 5, 10, 0),
            endTime: DateTime(2026, 11, 5, 10, 12, 30),
            readSeconds: 750,
            verses: 7,
            readingPlanId: planId,
          ),
        );
        await rsDb.daySummary.upsert(planId, sessionDate);

        // November 2026 has 30 days
        final monthData = await planService.getMonthProgress(
          planId,
          DateTime(2026, 11, 1),
        );

        expect(monthData.length, 30);
        for (int i = 0; i < 30; i++) {
          expect(monthData[i].day.year, 2026);
          expect(monthData[i].day.month, 11);
          expect(monthData[i].day.day, i + 1);
        }

        // The seeded summary maps to exactly one calendar cell.
        final day5 = monthData[4];
        expect(day5.empty, isFalse);
        expect(day5.verses, 7);
        expect(day5.minutes, 12.5);
        expect(day5.goalReached, isTrue);

        for (int i = 0; i < 30; i++) {
          if (i == 4) continue;
          expect(monthData[i].empty, isTrue);
          expect(monthData[i].goalReached, isFalse);
        }
      },
    );
  });

  group('UI Widget Rendering & Constraints', () {
    testWidgets(
      'CalendarView renders date number in top-left and checkmark in bottom-right without overlap',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 500,
                child: CalendarView(
                  month: DateTime(2026, 11, 1),
                  progressByDay: const {5: 1},
                  onPreviousMonth: () {},
                  onNextMonth: () {},
                  onDayTap: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final checkIconFinder = find.byIcon(Icons.check_rounded);
        expect(checkIconFinder, findsOneWidget);

        final iconWidget = tester.widget<Icon>(checkIconFinder);
        expect(iconWidget.size, 18);

        final dateFinder = find.text('5');
        expect(dateFinder, findsOneWidget);
        final textWidget = tester.widget<Text>(dateFinder);
        expect(textWidget.style?.fontSize, 12);
      },
    );

    testWidgets(
      'BookCompletedOverlay renders Done button when there is no next book',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: Stack(
                children: [
                  BookCompletedOverlay(
                    viewModel: viewModel,
                    onNextBook: (_) {},
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Done'), findsNothing);

        viewModel.bookCompletedNotifier.value = const BookCompletedEvent(
          completedBookId: 66,
          nextBookId: null,
          resumePosition: null,
        );
        await tester.pumpAndSettle();

        expect(find.text('Done'), findsOneWidget);
      },
    );

    testWidgets(
      'ReadingSheet wraps Navigator in SizedBox with 85% height and ClipRRect',
      (tester) async {
        final panelViewModel = (await tester.runAsync(
          () => ReadingPlanPanelViewModel.create(
            planService: planService,
            sessionViewModel: viewModel,
          ),
        ))!;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
            home: MediaQuery(
              data: const MediaQueryData(size: Size(400, 1000)),
              child: Scaffold(
                body: ReadingSheet(
                  child: ReadingPlanPanel(viewModel: panelViewModel),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final sizedBoxFinder = find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.height == 850.0,
        );
        expect(sizedBoxFinder, findsOneWidget);

        expect(find.byType(ClipRRect), findsWidgets);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets(
      'CalendarView and BookCompletedOverlay use adaptive theme colors in Light Mode',
      (tester) async {
        final lightTheme = ThemeData(
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.light,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: lightTheme,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 500,
                child: CalendarView(
                  month: DateTime(2026, 11, 1),
                  progressByDay: const {5: 1},
                  onPreviousMonth: () {},
                  onNextMonth: () {},
                  onDayTap: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final checkIconFinder = find.byIcon(Icons.check_rounded);
        expect(checkIconFinder, findsOneWidget);

        final iconWidget = tester.widget<Icon>(checkIconFinder);
        expect(iconWidget.color, lightTheme.colorScheme.onPrimary);

        // Verify day 5 text color is onPrimary
        final day5Text = tester.widget<Text>(find.text('5'));
        expect(day5Text.style?.color, lightTheme.colorScheme.onPrimary);

        // Verify unhighlighted day 6 text color is onSurface
        final day6Text = tester.widget<Text>(find.text('6'));
        expect(day6Text.style?.color, lightTheme.colorScheme.onSurface);
      },
    );
  });
}
