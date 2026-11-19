import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/ui/home/common/navigation_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await getIt.reset();
  });

  // Mirrors the settings -> navigation view model chain registered in
  // `setupServiceLocator`. The full locator cannot be exercised in a unit
  // test because the database and logger factories need platform channels.
  test('the settings and view model singletons initialize through the locator '
      'and await in order', () async {
    SharedPreferences.setMockInitialValues({
      'currentBookId': 19,
      'currentChapter': 23,
    });

    getIt.registerSingletonAsync<UserSettings>(() async {
      final settings = UserSettings();
      await settings.init();
      return settings;
    });
    getIt.registerSingletonAsync<NavigationViewModel>(
      () async => NavigationViewModel(await getIt.getAsync<UserSettings>()),
    );

    await getIt.allReady();

    expect(getIt<UserSettings>().currentBookChapter, (19, 23));

    final viewModel = getIt<NavigationViewModel>();
    expect(
      viewModel.anchor.value,
      const Reference(bookId: 19, chapter: 23, verse: 1),
    );
    expect(
      viewModel.displayReference,
      const Reference(bookId: 19, chapter: 23, verse: 1),
    );
    expect(viewModel.position, isNotNull);
  });
}
