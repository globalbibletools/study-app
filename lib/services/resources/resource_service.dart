import 'dart:developer';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gbt/services/bible/bible_service.dart';
import 'package:gbt/services/files/file_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/download/cancel_token.dart';
import 'package:gbt/services/download/download.dart';
import 'package:gbt/services/resources/manifest_resource.dart';
import 'package:gbt/services/resources/remote_asset_service.dart';
import 'package:gbt/services/resources/resource.dart';
import 'package:gbt/services/resources/resource_database.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

export 'package:gbt/services/resources/resource.dart';

typedef ResourceChangeListener = void Function(ResourceType type);

class ResourceTypeConfig {
  final String localPathTemplate;
  final String? prebundledPathTemplate;

  const ResourceTypeConfig({
    required this.localPathTemplate,
    this.prebundledPathTemplate = null,
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
    ResourceType.bible: ResourceTypeConfig(
      localPathTemplate: 'bibles/{id}.db',
      prebundledPathTemplate: 'databases/{id}.db',
    ),
  };

  final _downloadService = getIt<DownloadService>();
  final _assetService = getIt<RemoteAssetService>();

  final ResourceDatabase _resourceDatabase = ResourceDatabase();

  final outdatedResourceCounts =
      ValueNotifier<OutdatedResourceCounts>(const OutdatedResourceCounts());

  final Map<ResourceType, List<ResourceChangeListener>> _listeners = {
    for (final type in ResourceType.values) type: <ResourceChangeListener>[],
  };

  void addResourceChangeListener(
    ResourceType type,
    ResourceChangeListener listener,
  ) {
    _listeners[type]?.add(listener);
  }

  void removeResourceChangeListener(
    ResourceType type,
    ResourceChangeListener listener,
  ) {
    _listeners[type]?.remove(listener);
  }

  Future<void> _recomputeOutdatedCounts() async {
    final byType = await _resourceDatabase.countOutdatedResourcesByType();
    final total = byType.values.fold(0, (sum, n) => sum + n);
    outdatedResourceCounts.value =
        OutdatedResourceCounts(total: total, byType: byType);
  }

  void _notifyResourceChange(ResourceType type) {
    _recomputeOutdatedCounts();

    final listeners = _listeners[type];
    if (listeners == null) return;
    for (final listener in listeners) {
      try {
        listener(type);
      } catch (e, stackTrace) {
        log('Resource change listener threw', error: e, stackTrace: stackTrace);
      }
    }
  }

  ResourceService() {
    seedBundledResource(ResourceType.Gloss, 'eng').catchError((e) {
        log("Error copying bundled glosses to resource manager", error: e);
    });
    seedBundledResource(ResourceType.bible, 'eng_bsb').catchError((e) {
        log("Error copying bundled bible to resource manager", error: e);
    });

    _recomputeOutdatedCounts();
  }

  Future<List<ResourceView>> getResourcesByType(ResourceType resourceType) async {
      return _resourceDatabase.getResourceViews(resourceType);
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

  Future<void> deleteResource(
    ResourceType resourceType,
    String id,
  ) async {
    await _resourceDatabase.setInstallState(id, InstallState.NotInstalled);

    final filePath = await _resolveLocalFilePath(resourceType, id);
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
      log('Deleted resource file at $filePath');
    }

    _notifyResourceChange(resourceType);
  }

  Future<void> downloadResource(
    ResourceType resourceType,
    String id, {
    ValueChanged<double>? onProgress,
    required CancelToken cancelToken,
  }) async {
    final filePath = await _resolveLocalFilePath(resourceType, id);

    final asset = resourceType == ResourceType.Gloss ? 
        RemoteAsset(
          remoteUrl: '${_assetService.baseHost}/glosses/v1/$id.db.zip',
          localRelativePath: filePath,
          fileType: FileType.gloss,
          isZip: true,
        ) : 
        RemoteAsset(
          remoteUrl: '${_assetService.baseHost}/bibles/v1/$id.db.zip',
          localRelativePath: filePath,
          fileType: FileType.bible,
          isZip: true,
        );
    final version = await _resourceDatabase.getResourceVersion(resourceType, id);

    log('Downloading glosses for $id from ${asset.remoteUrl}');

    try {
      await _downloadService.downloadAsset(
        asset: asset,
        version: version,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );

      await _resourceDatabase.setInstallState(id, InstallState.Installed);

      log('Gloss download successful.');
      _notifyResourceChange(resourceType);
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

  Future<void> refreshResources() async {
    final manifestUrl = '${_assetService.baseHost}/glosses/v1/manifest.jsonl';
    log('Refreshing gloss resources from $manifestUrl');

    final entries = await _downloadService.getJsonl(
      manifestUrl,
      convert: ManifestResource.fromJson,
    );

    debugPrint('Gloss manifest contained ${entries.length} entries');

    await _resourceDatabase.updateResourcesFromManifest(ResourceType.Gloss, entries);
    _notifyResourceChange(ResourceType.Gloss);
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
