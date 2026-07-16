import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:gbt/services/bible/bible_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/download/cancel_token.dart';

class ResourceService {
  final _bibleService = getIt<BibleService>();

  Future<bool> areResourcesDownloaded(Locale locale) async {
    if (locale.languageCode == 'en') return true;
    return await _bibleService.bibleExists(locale);
  }

  Future<void> downloadResources(
    Locale locale, {
    required ValueNotifier<double> progressNotifier,
    required CancelToken cancelToken,
  }) async {
    final needBible = !await _bibleService.bibleExists(locale);

    if (!needBible) {
      progressNotifier.value = 1.0;
      return;
    }

    void updateProgress(double fileProgress) {
      progressNotifier.value = fileProgress;
    }

    updateProgress(0.0);
    await _bibleService.downloadBible(
      locale,
      cancelToken: cancelToken,
      onProgress: updateProgress,
    );
    progressNotifier.value = 1.0;
  }
}
