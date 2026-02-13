import 'dart:developer';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/services/assets/remote_asset_service.dart';
import 'package:studyapp/services/download/cancel_token.dart';
import 'package:studyapp/services/download/download.dart';
import 'package:studyapp/services/gloss/english_database.dart';
import 'package:studyapp/services/gloss/gloss_database.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/settings/user_settings.dart';

class GlossService {
  final _settings = getIt<UserSettings>();
  final _downloadService = getIt<DownloadService>();
  final _assetService = getIt<RemoteAssetService>();

  final _englishGlossDb = EnglishDatabase();
  final _glossDb = GlossDatabase();

  Future<void> init() async {
    await _englishGlossDb.init();
    final langCode = _settings.locale.languageCode;
    if (langCode != 'en') {
      await _glossDb.initDb(langCode);
    }
  }

  /// Downloads the gloss database for the given locale.
  Future<void> downloadGlosses(
    Locale locale, {
    ValueChanged<double>? onProgress,
    CancelToken? cancelToken,
  }) async {
    final langCode = locale.languageCode;
    final asset = _assetService.getGlossAsset(langCode);

    log('Downloading glosses for $langCode from ${asset.remoteUrl}');

    try {
      await _downloadService.downloadAsset(
        asset: asset,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );

      await _glossDb.initDb(langCode);
      log('Gloss download and initialization successful.');
    } catch (e) {
      log('Gloss download failed for $langCode: $e');
      rethrow;
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
