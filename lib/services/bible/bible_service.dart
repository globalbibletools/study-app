import 'dart:developer';
import 'dart:ui';

import 'package:scripture/scripture.dart';
import 'package:studyapp/services/bible/english_bible_database.dart';
import 'package:studyapp/services/bible/localized_bible_database.dart';
import 'package:studyapp/services/download/download.dart';
import 'package:studyapp/services/files/file_service.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/user_settings.dart';

class BibleService {
  final _settings = getIt<UserSettings>();
  final _downloadService = getIt<DownloadService>();

  // The two data sources
  final _englishDb = EnglishBibleDatabase();
  final _localizedDb = LocalizedBibleDatabase();

  // Base URL for bible repositories (Update to your actual URL)
  static const _baseUrl =
      'https://github.com/globalbibletools/study-app/raw/refs/heads/main/temp';

  Future<void> init() async {
    await _englishDb.init();

    // Check if we need to init the localized DB immediately on startup
    final langCode = _settings.locale.languageCode;
    if (langCode != 'en') {
      await _localizedDb.initDb(langCode);
    }
  }

  /// Downloads the bible database for the given locale.
  Future<void> downloadBible(Locale locale) async {
    final langCode = locale.languageCode;
    final filename = _localizedDb.getDbFilename(langCode);

    final url = '$_baseUrl/$filename.zip';

    log('Downloading bible for $langCode from $url');

    try {
      await _downloadService.downloadFile(
        url: url,
        type: FileType.bible, // Ensure this exists in your FileType enum
        relativePath: filename,
        isZip: true,
      );

      // Initialize immediately after download
      await _localizedDb.initDb(langCode);
      log('Bible download and initialization successful.');
    } catch (e) {
      log('Bible download failed for $langCode: $e');
      rethrow;
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
