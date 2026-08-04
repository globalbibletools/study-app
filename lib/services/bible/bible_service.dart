import 'dart:developer';

import 'package:scripture/scripture.dart';
import 'package:gbt/services/bible/english_bible_database.dart';
import 'package:gbt/services/bible/localized_bible_database.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';

class BibleService {
  final _settings = getIt<UserSettings>();

  // The two data sources
  final _englishDb = EnglishBibleDatabase();
  final _localizedDb = LocalizedBibleDatabase();

  Future<void> init() async {
    await _englishDb.init();

    // Check if we need to init the localized DB immediately on startup
    final langCode = _settings.locale.languageCode;
    if (langCode != 'en') {
      await _localizedDb.initDb(langCode);
    }
  }

  /// Gets the chapter text.
  /// Uses Localized DB if available for current locale, otherwise falls back to English.
  Future<List<UsfmLine>> getChapter(int bookId, int chapter) async {
    final currentLocale = _settings.locale;
    final langCode = currentLocale.languageCode;

    // 1. If English, use English DB
    if (langCode == 'en') {
      return await _englishDb.getChapter(bookId, chapter);
    }

    // 2. Check if localized DB exists
    final dbExists = await _localizedDb.bibleDbExists(langCode);

    if (dbExists) {
      // 3. Try to get localized text
      final lines = await _localizedDb.getChapter(langCode, bookId, chapter);

      if (lines.isNotEmpty) {
        return lines;
      }
    }

    // 4. Fallback: If DB missing or chapter missing in DB, return English
    log('Fallback to English Bible for $langCode ($bookId:$chapter)');
    return await _englishDb.getChapter(bookId, chapter);
  }
}
