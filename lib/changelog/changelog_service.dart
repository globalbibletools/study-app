import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:gbt/changelog/changelog_entry.dart';
import 'package:gbt/services/logging/log.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';

typedef ChangelogAssetLoader = Future<String> Function(String path);

class ChangelogService {
  final _settings = getIt<UserSettings>();

  ChangelogService({ChangelogAssetLoader? assetLoader})
    : _loadAsset = assetLoader ?? rootBundle.loadString;

  final ChangelogAssetLoader _loadAsset;

  String? _cachedLanguageCode;
  Future<List<ChangelogEntry>>? _cachedEntries;

  Future<List<ChangelogEntry>> loadEntries(Locale locale) {
    final languageCode = locale.languageCode;
    final cached = _cachedEntries;
    if (cached != null && _cachedLanguageCode == languageCode) {
      return cached;
    }

    final future = _loadCached(languageCode);
    _cachedLanguageCode = languageCode;
    _cachedEntries = future;
    return future;
  }

  Future<bool> shouldShowUpdateDialog(Locale locale) async {
    final entries = await loadEntries(locale);
    if (_settings.lastSeenChangelogVersion == null) {
      await markLatestSeen();
      return false;
    }

    return hasUnseenMajor(entries);
  }

  List<ChangelogEntry> unseenEntries(List<ChangelogEntry> entries) {
    final lastSeen = _settings.lastSeenChangelogVersion;
    if (lastSeen == null) return const [];

    final lastSeenIndex = entries.indexWhere(
      (entry) => entry.version == lastSeen,
    );
    if (lastSeenIndex == -1) return const [];

    return entries.sublist(lastSeenIndex + 1);
  }

  bool hasUnseenMajor(List<ChangelogEntry> entries) {
    return unseenEntries(
      entries,
    ).any((entry) => entry.type == ChangelogEntryType.major);
  }

  Future<void> markLatestSeen() async {
    final entries = await _cachedEntries;
    if (entries == null || entries.isEmpty) return;

    final latestVersion = entries.last.version;
    if (_settings.lastSeenChangelogVersion == latestVersion) return;

    await _settings.setLastSeenChangelogVersion(latestVersion);
    info('Set latest changelog version to $latestVersion');
  }

  Future<List<ChangelogEntry>> _loadCached(String languageCode) async {
    try {
      return await _load(languageCode);
    } catch (_) {
      if (_cachedLanguageCode == languageCode) {
        _cachedLanguageCode = null;
        _cachedEntries = null;
      }
      rethrow;
    }
  }

  Future<List<ChangelogEntry>> _load(String languageCode) async {
    var json = await _tryLoad('assets/l10n/changelog_$languageCode.json');
    if (json == null) {
      warn(
        'Missing changelog asset for $languageCode. Falling back to English',
      );

      json = await _tryLoad('assets/l10n/changelog_en.json');
      if (json == null) {
        error('Missing English fallback changelog asset for $languageCode.');
        throw StateError('Missing changelog asset for $languageCode.');
      }
    }

    try {
      return ChangelogEntry.fromJsonArray(json);
    } catch (err, stack) {
      error(
        'Changelog file for $languageCode is invalid',
        error: err,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<String?> _tryLoad(String path) async {
    try {
      return await _loadAsset(path);
    } catch (_) {
      return null;
    }
  }
}
