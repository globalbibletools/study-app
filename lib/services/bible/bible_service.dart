import 'package:flutter/foundation.dart';
import 'package:scripture/scripture.dart';
import 'package:gbt/services/bible/bible_database.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';

typedef BibleResourceChangeListener = void Function(String bibleId);

class BibleService {
  final _settings = getIt<UserSettings>();
  final _resourceService = getIt<ResourceService>();

  BibleDatabase? _db;
  String? currentBibleId;

  final List<BibleResourceChangeListener> _resourceChangeListeners = [];

  BibleService() {
    _resourceService.addResourceChangeListener(
      ResourceType.bible,
      _onBibleResourceChanged,
    );
  }

  void addBibleResourceChangeListener(BibleResourceChangeListener listener) {
    _resourceChangeListeners.add(listener);
  }

  void removeBibleResourceChangeListener(BibleResourceChangeListener listener) {
    _resourceChangeListeners.remove(listener);
  }

  void _onBibleResourceChanged(ResourceType type, String id) {
    // Only the currently-open bible's cache can be stale.
    if (currentBibleId == null || id != currentBibleId) return;

    _close();

    for (final listener in _resourceChangeListeners) {
      try {
        listener(id);
      } catch (e, stackTrace) {
        debugPrint('Bible resource change listener threw: $e\n$stackTrace');
      }
    }
  }

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
    final path = await _resourceService.getResourceLocalPath(
      ResourceType.bible,
      bibleId,
    );

    await _close();

    _db = await BibleDatabase.open(path);
    currentBibleId = bibleId;
  }

  Future<void> _close() async {
    final db = _db;
    _db = null;
    currentBibleId = null;
    if (db != null) {
      await db.close();
    }
  }
}
