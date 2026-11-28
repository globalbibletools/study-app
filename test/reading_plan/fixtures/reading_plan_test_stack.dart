import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_queries.dart';
import 'package:gbt/reading_plan/data_access/rs_database.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/reading_session_service.dart';
import 'package:gbt/reading_plan/ui/reading_session_view_model.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/home/common/navigation_view_model.dart';
import 'package:gbt/ui/messaging/messenger_view_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/bible_navigation_fixture.dart';
import '../../fixtures/fake_messenger_view_model.dart';
import '../../fixtures/fake_navigation_view_model.dart';

class ReadingPlanTestStack {
  ReadingPlanTestStack._({
    required this.database,
    required this.planService,
    required this.sessionService,
    required this.sessionViewModel,
    required this.navigation,
    required this.messenger,
    required this.bibleNavigation,
  });

  static Future<ReadingPlanTestStack> create() async {
    await getIt.reset();

    final bibleNavigation = createTestBibleNavigation();
    getIt.registerSingleton<BibleNavigation>(bibleNavigation);

    final database = ReadingSessionDatabase(
      databasePath: inMemoryDatabasePath,
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    await database.init();
    getIt.registerSingleton<ReadingSessionDatabase>(database);

    final planService = ReadingPlanService();
    final sessionService = ReadingSessionService();
    final navigation = FakeNavigationViewModel();
    final messenger = FakeMessengerViewModel();

    getIt.registerSingleton<ReadingPlanQueries>(database.queries);
    getIt.registerSingleton<ReadingPlanService>(planService);
    getIt.registerSingleton<ReadingSessionService>(sessionService);
    getIt.registerSingleton<NavigationViewModel>(navigation);
    getIt.registerSingleton<MessengerViewModel>(messenger);

    final sessionViewModel = ReadingSessionViewModel();
    getIt.registerSingleton<ReadingSessionViewModel>(sessionViewModel);

    return ReadingPlanTestStack._(
      database: database,
      planService: planService,
      sessionService: sessionService,
      sessionViewModel: sessionViewModel,
      navigation: navigation,
      messenger: messenger,
      bibleNavigation: bibleNavigation,
    );
  }

  final ReadingSessionDatabase database;
  final ReadingPlanService planService;
  final ReadingSessionService sessionService;
  final ReadingSessionViewModel sessionViewModel;
  final FakeNavigationViewModel navigation;
  final FakeMessengerViewModel messenger;
  final BibleNavigation bibleNavigation;

  bool _databaseDisposed = false;
  bool _sessionViewModelDisposed = false;

  void disposeDatabase() {
    if (_databaseDisposed) return;
    database.dispose();
    _databaseDisposed = true;
  }

  void disposeSessionViewModel() {
    if (_sessionViewModelDisposed) return;
    sessionViewModel.dispose();
    _sessionViewModelDisposed = true;
  }

  Future<void> dispose() async {
    disposeSessionViewModel();
    messenger.dispose();
    disposeDatabase();
    await getIt.reset();
  }
}
