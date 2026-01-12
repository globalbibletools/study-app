import 'dart:developer';
import 'dart:ui';

import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/services/download/download.dart';
import 'package:studyapp/services/files/file_service.dart';
import 'package:studyapp/services/gloss/english_database.dart';
import 'package:studyapp/services/gloss/gloss_database.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/user_settings.dart';

class GlossService {
  final _settings = getIt<UserSettings>();
  final _downloadService = getIt<DownloadService>();

  final _englishGlossDb = EnglishDatabase();
  final _glossDb = GlossDatabase(); // Note: GlossDatabase is now much lighter

  // Base URL for gloss repositories
  static const _baseUrl =
      'https://github.com/globalbibletools/study-app/raw/refs/heads/main/temp';

  Future<void> init() async {
    await _englishGlossDb.init();
    final langCode = _settings.locale.languageCode;
    if (langCode != 'en') {
      await _glossDb.initDb(langCode);
    }
  }

  /// Downloads the gloss database for the given locale.
  Future<void> downloadGlosses(Locale locale) async {
    final langCode = locale.languageCode;
    final filename = _glossDb.getDbFilename(langCode); // e.g., 'spa.db'

    // Construct URL: e.g., .../temp/spa.db.zip
    final url = '$_baseUrl/$filename.zip';

    log('Downloading glosses for $langCode from $url');

    try {
      await _downloadService.downloadFile(
        url: url,
        type: FileType.gloss, // This ensures it goes to sqflite's folder
        relativePath: filename, // The final filename we want
        isZip: true, // DownloadService handles the unzipping
      );

      // Initialize immediately after download so it's ready to use
      await _glossDb.initDb(langCode);
      log('Gloss download and initialization successful.');
    } catch (e) {
      log('Gloss download failed for $langCode: $e');
      rethrow; // Pass error up to UI
    }
  }

  Future<String?> glossForId({
    required Locale locale,
    required int wordId,
    void Function(Locale)? onDatabaseMissing,
  }) async {
    final glossLocale = _settings.locale;

    // 1. If English, use English DB directly
    if (!_isDownloadableLanguage(glossLocale)) {
      return await _englishGlossDb.getGloss(wordId);
    }

    final langCode = glossLocale.languageCode;

    // 2. Check if localized DB exists
    final dbExists = await _glossDb.glossDbExists(langCode);

    if (dbExists) {
      // 3. Try to get localized gloss
      final localizedGloss = await _glossDb.getGloss(langCode, wordId);
      // Fallback to English if the specific word is missing in the localized DB
      return localizedGloss ?? await _englishGlossDb.getGloss(wordId);
    } else {
      // 4. Trigger UI callback to prompt download
      onDatabaseMissing?.call(Locale(langCode));
      // Fallback to English while waiting
      return await _englishGlossDb.getGloss(wordId);
    }
  }

  bool _isDownloadableLanguage(Locale locale) {
    if (locale.languageCode == 'en') return false;
    return AppLocalizations.supportedLocales.any(
      (l) => l.languageCode == locale.languageCode,
    );
  }

  Future<bool> glossesExists(Locale selectedLocale) async {
    final langCode = selectedLocale.languageCode;
    if (langCode == 'en') return true;
    return await _glossDb.glossDbExists(langCode);
  }
}
