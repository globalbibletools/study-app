import 'dart:ui';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gbt/services/bible/bible_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/download/cancel_token.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

enum ResourceType {
  Gloss
}

class ResourceTypeConfig {
  final String localPathTemplate;

  const ResourceTypeConfig({
    required this.localPathTemplate,
  });
}

class ResourceMissingException implements Exception {
  final ResourceType resourceType;
  final String id;

  ResourceMissingException(
    ResourceType this.resourceType,
    String this.id
  );

  @override
  String toString() => 'ResourceMissingException: resourceType=$resourceType, id=$id';
}

class ResourceService {
  static const Map<ResourceType, ResourceTypeConfig> resourceConfigs = {
    ResourceType.Gloss: ResourceTypeConfig(
      localPathTemplate: 'glosses/{id}.db',
    ),
  };

  Future<String?> resourceExists(
    ResourceType resourceType,
    String id,
  ) async {
    final config = resourceConfigs[resourceType];
    if (config == null) {
        throw Exception('Config not found for resource ${resourceType.name}');
    }

    final relativePath = config.localPathTemplate.replaceAll('{id}', id);
    final docDir = await getApplicationDocumentsDirectory();
    final absolutePath = join(docDir.path, relativePath);

    return await File(absolutePath).exists();
  }

  Future<String?> getResourceLocalPath(
    ResourceType resourceType,
    String id,
  ) async {
    final config = resourceConfigs[resourceType];
    if (config == null) {
        throw Exception('Config not found for resource ${resourceType.name}');
    }

    final relativePath = config.localPathTemplate.replaceAll('{id}', id);
    final docDir = await getApplicationDocumentsDirectory();
    final absolutePath = join(docDir.path, relativePath);

    final fileExists = await File(absolutePath).exists();
    if (!fileExists) {
      throw ResourceMissingException(resourceType, id);
    }

    return absolutePath;
  }

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
