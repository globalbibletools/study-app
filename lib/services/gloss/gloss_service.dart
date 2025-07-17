import 'dart:developer';
import 'dart:ui';

import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/services/gloss/english_database.dart';
import 'package:studyapp/services/gloss/gloss_database.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/user_settings.dart';

/// This is the communication interface for the rest of the app when anyone
/// wants a gloss. No one else but this class should know anything about
/// English vs. localized gloss databases.
class GlossService {
  final _settings = getIt<UserSettings>();
  final _englishGlossDb = EnglishDatabase();
  final _glossDb = GlossDatabase();

  Future<void> init() async {
    await _englishGlossDb.init();
    final langCode = _settings.locale.languageCode;
    await _glossDb.initDb(langCode);
  }

  Future<void> downloadGlosses(Locale locale) async {
    try {
      await _glossDb.downloadAndInstallGlossDb(locale.languageCode);
      await _glossDb.initDb(locale.languageCode);
    } catch (e) {
      log('Gloss download failed for ${locale.languageCode}: $e');
      rethrow;
    }
  }

  Future<String?> glossForId({
    required Locale uiLocale,
    required int wordId,
    void Function(Locale)? onDatabaseMissing,
  }) async {
    final glossLocale = _settings.locale ?? uiLocale;

    if (!_isDownloadableLanguage(glossLocale)) {
      return await _englishGlossDb.getGloss(wordId);
    }

    final langCode = glossLocale.languageCode;
    final dbExists = await _glossDb.glossDbExists(langCode);
    if (dbExists) {
      final localizedGloss = await _glossDb.getGloss(langCode, wordId);
      return localizedGloss ?? await _englishGlossDb.getGloss(wordId);
    } else {
      onDatabaseMissing?.call(Locale(langCode));
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
