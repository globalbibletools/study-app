import 'package:scripture/scripture.dart';
import 'package:gbt/services/bible/bible_database.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';

class BibleService {
  final _settings = getIt<UserSettings>();
  final _resourceService = getIt<ResourceService>();

  BibleDatabase? _db;
  String? currentBibleId;

  Future<bool> bibleExists(String bibleId) async {
    return _resourceService.resourceExists(ResourceType.bible, bibleId);
  }

  Future<List<UsfmLine>> getChapter(
    int bookId,
    int chapter, {
    void Function(String bibleId)? onDatabaseMissing,
  }) async {
    final bibleId = _settings.currentBible;
    if (bibleId == null) return [];

    // Ensure the active database matches the current bible.
    if (currentBibleId != bibleId) {
      try {
        await _openForBible(bibleId);
      } on ResourceMissingException {
        onDatabaseMissing?.call(bibleId);
        return [];
      }
    }

    return _db!.getChapter(bookId, chapter);
  }

  Future<void> _openForBible(String bibleId) async {
    // Already the active database.
    if (currentBibleId == bibleId && _db != null) return;

    final path = await _resourceService.getResourceLocalPath(
      ResourceType.bible,
      bibleId,
    );

    if (_db != null) {
      await _db!.close();
      _db = null;
      currentBibleId = null;
    }

    _db = await BibleDatabase.open(path);
    currentBibleId = bibleId;
  }
}
