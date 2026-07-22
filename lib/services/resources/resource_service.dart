import 'dart:developer';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gbt/services/bible/bible_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/download/cancel_token.dart';
import 'package:gbt/services/download/download.dart';
import 'package:gbt/services/resources/remote_asset_service.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

enum ResourceType {
  Gloss
}

class ResourceTypeConfig {
  final String localPathTemplate;
  final String? prebundledPathTemplate;

  const ResourceTypeConfig({
    required this.localPathTemplate,
    this.prebundledPathTemplate = null,
  });
}

class Resource {
    final String id;
    final String name;

    const Resource({
      required this.id,
      required this.name,
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
      prebundledPathTemplate: 'databases/{id}.db',
    ),
  };
  static const List<Resource> glossResources = [
    Resource(name: 'English', id: 'eng'),
    Resource(name: 'Español', id: 'spa'),
    Resource(name: 'Français', id: 'fra'),
    Resource(name: 'Português', id: 'por'),
    Resource(name: 'العربية', id: 'are'),
  ];

  final _downloadService = getIt<DownloadService>();
  final _assetService = getIt<RemoteAssetService>();

  Future<List<Resource>> getResourcesByType(ResourceType resourceType) async {
      return glossResources;
  }

  Future<bool> resourceExists(
    ResourceType resourceType,
    String id,
  ) async {
    final filePath = await _resolveLocalFilePath(resourceType, id);
    return await File(filePath).exists();
  }

  Future<String> getResourceLocalPath(
    ResourceType resourceType,
    String id,
  ) async {
    final filePath = await _resolveLocalFilePath(resourceType, id);

    final fileExists = await File(filePath).exists();
    if (!fileExists) {
      throw ResourceMissingException(resourceType, id);
    }

    final config = resourceConfigs[resourceType];
    if (config == null) {
        throw Exception('Config not found for resource ${resourceType.name}');
    }

    return filePath;
  }

  Future<void> downloadResource(
    ResourceType resourceType,
    String id, {
    ValueChanged<double>? onProgress,
    required CancelToken cancelToken,
  }) async {
    final asset = _assetService.getGlossAsset(id);

    log('Downloading glosses for $id from ${asset.remoteUrl}');

    try {
      await _downloadService.downloadAsset(
        asset: asset,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );

      log('Gloss download successful.');
    } catch (e) {
      log('Gloss download failed for $id', error: e);
      rethrow;
    }
  }

  Future<void> seedBundledResource(
    ResourceType resourceType,
    String id,
  ) async {
    final filePath = await _resolveLocalFilePath(resourceType, id);
    final exists = await File(filePath).exists();
    if (exists) return;

    final config = resourceConfigs[resourceType];
    if (config == null) {
        throw Exception('Config not found for resource ${resourceType.name}');
    }

    final prebundledPathTemplate = config.prebundledPathTemplate;
    if (prebundledPathTemplate == null) {
        throw Exception('Config for resource ${resourceType.name} does not support prebundled resources');
    }

    final srcRelativePath = prebundledPathTemplate.replaceAll('{id}', id);

    final directory = Directory(dirname(filePath));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    try {
      final data = await rootBundle.load('assets/databases/$srcRelativePath');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await File(filePath).writeAsBytes(bytes, flush: true);
      log('Seeded file at $filePath from assets/databases/$srcRelativePath');
    } catch (e, s) {
      log(
        'Failed to seed file at $filePath from assets/databases/$srcRelativePath',
        error: e,
        stackTrace: s
      );
    }
  }

  Future<String> _resolveLocalFilePath(
    ResourceType resourceType,
    String id,
  ) async {
    final config = resourceConfigs[resourceType];
    if (config == null) {
        throw Exception('Config not found for resource ${resourceType.name}');
    }

    final relativePath = config.localPathTemplate.replaceAll('{id}', id);
    final docDir = await getApplicationDocumentsDirectory();
    return join(docDir.path, relativePath);
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
