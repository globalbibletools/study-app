import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:gbt/services/resources/remote_asset_service.dart';
import 'package:gbt/services/download/cancel_token.dart';
import 'package:gbt/services/download/download.dart';
import 'package:gbt/services/gloss/gloss_database.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';

class GlossService {
  final _settings = getIt<UserSettings>();
  final _downloadService = getIt<DownloadService>();
  final _assetService = getIt<RemoteAssetService>();

  final _glossDb = GlossDatabase();

  /// The list of available gloss resources (languages).
  List<GlossResource> get glossResources => _glossDb.getGlossResources();

  Future<void> init() async {
    // English ships bundled in the app assets. Seed it into the same on-disk
    // location used for downloaded glosses so it's treated uniformly.
    await _glossDb.seedBundledGloss('eng');
    await _glossDb.initDb(_settings.glossLang);
  }

  Future<void> downloadGlosses(
    String langCode, {
    ValueChanged<double>? onProgress,
    CancelToken? cancelToken,
  }) async {
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
    required int wordId,
    void Function(String)? onDatabaseMissing,
  }) async {
    final langCode = _settings.glossLang;

    final dbExists = await _glossDb.glossDbExists(langCode);

    if (dbExists) {
      return await _glossDb.getGloss(langCode, wordId);
    } else {
      onDatabaseMissing?.call(langCode);
    }
  }

  Future<bool> glossesExists(String langCode) async {
    return await _glossDb.glossDbExists(langCode);
  }
}
