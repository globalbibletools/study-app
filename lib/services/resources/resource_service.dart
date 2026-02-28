import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:studyapp/services/bible/bible_service.dart';
import 'package:studyapp/services/gloss/gloss_service.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/download/cancel_token.dart';

class ResourceService {
  final _bibleService = getIt<BibleService>();
  final _glossService = getIt<GlossService>();

  Future<bool> areResourcesDownloaded(Locale locale) async {
    if (locale.languageCode == 'en') return true;
    final bibleExists = await _bibleService.bibleExists(locale);
    final glossExists = await _glossService.glossesExists(locale);
    return bibleExists && glossExists;
  }

  Future<void> downloadResources(
    Locale locale, {
    required ValueNotifier<double> progressNotifier,
    required CancelToken cancelToken,
  }) async {
    final needGloss = !await _glossService.glossesExists(locale);
    final needBible = !await _bibleService.bibleExists(locale);

    double tasksToRun = (needGloss ? 1.0 : 0.0) + (needBible ? 1.0 : 0.0);
    double tasksCompleted = 0;

    void updateProgress(double fileProgress) {
      if (tasksToRun == 0) {
        progressNotifier.value = 1.0;
        return;
      }
      progressNotifier.value =
          (tasksCompleted / tasksToRun) + (fileProgress / tasksToRun);
    }

    if (needGloss) {
      await _glossService.downloadGlosses(
        locale,
        cancelToken: cancelToken,
        onProgress: updateProgress,
      );
      tasksCompleted++;
    }

    if (needBible) {
      updateProgress(0.0);
      await _bibleService.downloadBible(
        locale,
        cancelToken: cancelToken,
        onProgress: updateProgress,
      );
      tasksCompleted++;
    }
    progressNotifier.value = 1.0;
  }
}
