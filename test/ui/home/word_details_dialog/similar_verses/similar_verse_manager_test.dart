import 'dart:ui' show TextDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/common/word.dart';
import 'package:gbt/services/hebrew_greek/database.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/ui/home/word_details_dialog/dialog_manager.dart';
import 'package:gbt/ui/home/word_details_dialog/similar_verses/similar_verse_manager.dart';
import 'package:gbt/ui/home/word_details_dialog/similar_verses/similar_verses_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeHebrewGreekDatabase implements HebrewGreekDatabase {
  @override
  Future<String?> strongsCodeRoot(String strongsCode) async => 'דּוֹד';

  @override
  Future<List<Reference>> allVersesForStrongsCode(String strongsCode) async => [
    const Reference(bookId: 8, chapter: 4, verse: 17),
    const Reference(bookId: 8, chapter: 4, verse: 22),
  ];

  @override
  Future<List<Reference>> searchExactMatchNoPunctuation(String word) async => [
    const Reference(bookId: 8, chapter: 4, verse: 17),
  ];

  @override
  Future<List<HebrewGreekWord>> wordsForVerse(
    Reference reference, {
    bool includeStrongs = false,
  }) async => [
    HebrewGreekWord(
      id: 'w1',
      reference: reference,
      text: 'דָּוִד',
      strongsCode: 'H1732',
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeResourceService implements ResourceService {
  @override
  Future<bool> resourceExists(ResourceType type, String id) async => false;

  @override
  Future<String> getResourceLocalPath(ResourceType type, String id) async =>
      '/mock/$id.db';

  @override
  void addResourceChangeListener(
    ResourceType type,
    void Function(ResourceType type, String id) listener,
  ) {}

  @override
  void removeResourceChangeListener(
    ResourceType type,
    void Function(ResourceType type, String id) listener,
  ) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserSettings settings;
  late SimilarVerseManager manager;

  const testWord = WordDetails(
    word: 'דָּוִד',
    gloss: 'David',
    glossIsAi: false,
    glossTextDirection: TextDirection.ltr,
    strongsCode: 'H1732',
    grammar: 'Np-ms',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();

    settings = UserSettings();
    await settings.init();
    getIt.registerSingleton<UserSettings>(settings);
    getIt.registerSingleton<HebrewGreekDatabase>(FakeHebrewGreekDatabase());
    getIt.registerSingleton<ResourceService>(FakeResourceService());

    manager = SimilarVerseManager();
  });

  tearDown(() {
    manager.dispose();
  });

  test('init searches by root and sets rootNotifier', () async {
    await manager.init(testWord);

    expect(manager.rootNotifier.value, 'דּוֹד');
    expect(manager.similarVersesNotifier.value.length, 2);
    expect(
      manager.similarVersesNotifier.value[0],
      const Reference(bookId: 8, chapter: 4, verse: 17),
    );
  });

  test('search with exact matches exact word without punctuation', () async {
    await manager.init(testWord);
    await manager.search(testWord, SearchType.exact);

    expect(manager.similarVersesNotifier.value.length, 1);
    expect(
      manager.similarVersesNotifier.value[0],
      const Reference(bookId: 8, chapter: 4, verse: 17),
    );
  });

  test('isWordHighlighted checks root or exact properly', () {
    final word = HebrewGreekWord(
      id: 'w1',
      reference: const Reference(bookId: 8, chapter: 4, verse: 17),
      text: 'דָּוִד',
      strongsCode: 'H1732',
    );

    expect(
      manager.isWordHighlighted(word, testWord, SearchType.root),
      isTrue,
    );
    expect(
      manager.isWordHighlighted(word, testWord, SearchType.exact),
      isTrue,
    );

    final otherWord = HebrewGreekWord(
      id: 'w2',
      reference: const Reference(bookId: 8, chapter: 4, verse: 17),
      text: 'שְׁלֹמֹה',
      strongsCode: 'H8010',
    );
    expect(
      manager.isWordHighlighted(otherWord, testWord, SearchType.root),
      isFalse,
    );
    expect(
      manager.isWordHighlighted(otherWord, testWord, SearchType.exact),
      isFalse,
    );
  });

  test('getParallelVersesFor returns empty when no parallel bibles selected', () {
    final verses = manager.getParallelVersesFor(
      const Reference(bookId: 8, chapter: 4, verse: 17),
    );
    expect(verses, isEmpty);
  });
}
