import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:gbt/services/resources/remote_asset_service.dart';
import 'package:gbt/services/download/cancel_token.dart';
import 'package:gbt/services/download/download.dart';
import 'package:gbt/services/gloss/gloss_database.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/services/resources/resource_service.dart';

class GlossService {
  final _settings = getIt<UserSettings>();
  final _downloadService = getIt<DownloadService>();
  final _assetService = getIt<RemoteAssetService>();
  final _resourceService = getIt<ResourceService>();

  final _glossDb = GlossDatabase();

  Future<void> init() async {
    // English ships bundled in the app assets. Seed it into the same on-disk
    // location used for downloaded glosses so it's treated uniformly.
    await _resourceService.seedBundledResource(ResourceType.Gloss, 'eng');

    final langCode = _settings.glossLang;
    if (langCode != null) {
      await _glossDb.initDb(langCode);
    }
  }

  Future<String?> glossForId({
    required int wordId,
    void Function(String)? onDatabaseMissing,
  }) async {
    final langCode = _settings.glossLang;

    // No gloss language chosen yet — there is nothing to look up.
    if (langCode == null) return null;

    final dbExists = await _glossDb.glossDbExists(langCode);

    if (dbExists) {
      return await _glossDb.getGloss(langCode, wordId);
    } else {
      onDatabaseMissing?.call(langCode);
      return null;
    }
  }

  Future<bool> glossesExists(String langCode) async {
    return await _glossDb.glossDbExists(langCode);
  }
}
