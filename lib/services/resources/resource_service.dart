import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/download/cancel_token.dart';
import 'package:gbt/services/download/download.dart';
import 'package:gbt/services/resources/remote_asset_service.dart';
import 'package:gbt/services/resources/resource.dart';
import 'package:gbt/services/resources/resource_database.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

export 'package:gbt/services/resources/resource.dart';
export 'package:gbt/services/resources/resource_database.dart' show PathMatcher;

typedef ResourceChangeListener = void Function(ResourceType type);
typedef ResourceTypeChangeListener = void Function(ResourceType type, String id);

class ResourceTypeConfig {
  final String localPathTemplate;
  final String urlTemplate;
  final String? streamingUrlTemplate;
  final String? prebundledPathTemplate;
  final String manifestPath;

  const ResourceTypeConfig({
    required this.localPathTemplate,
    required this.urlTemplate,
    required this.manifestPath,
    this.streamingUrlTemplate,
    this.prebundledPathTemplate,
  });

  String manifestUrl(String baseHost) => '$baseHost/$manifestPath';
}

class ResourceMissingException implements Exception {
  final ResourceType resourceType;
  final String id;

  ResourceMissingException(
    this.resourceType,
    this.id
  );

  @override
  String toString() => 'ResourceMissingException: resourceType=$resourceType, id=$id';
}

class ResourceService {
  static const Map<ResourceType, ResourceTypeConfig> resourceConfigs = {
    ResourceType.gloss: ResourceTypeConfig(
      localPathTemplate: 'glosses/{id}.db',
      urlTemplate: 'glosses/v1/{id}.db.zip',
      prebundledPathTemplate: 'databases/{id}.db',
      manifestPath: 'glosses/v1/manifest.jsonl',
    ),
    ResourceType.bible: ResourceTypeConfig(
      localPathTemplate: 'bibles/{id}.db',
      urlTemplate: 'bibles/v1/{id}.db.zip',
      prebundledPathTemplate: 'databases/{id}.db',
      manifestPath: 'bibles/v1/manifest.jsonl',
    ),
    ResourceType.audio: ResourceTypeConfig(
      localPathTemplate: 'audio/{id}',
      urlTemplate: 'audio/v1/{id}.zip',
      streamingUrlTemplate: 'audio/v1/{id}',
      manifestPath: 'audio/v1/manifest.jsonl',
    ),
  };

  final _downloadService = getIt<DownloadService>();
  final _assetService = getIt<RemoteAssetService>();

  final ResourceDatabase _resourceDatabase = ResourceDatabase();

  final outdatedResourceCounts =
      ValueNotifier<OutdatedResourceCounts>(const OutdatedResourceCounts());

  final Map<ResourceType, ResourceTypeListenerGroup> _listeners = {
    for (final type in ResourceType.values) type: ResourceTypeListenerGroup(),
  };

  void addResourceTypeChangeListener(
    ResourceType type,
    ResourceChangeListener listener,
  ) {
    _listeners[type]?.addTypeListener(listener);
  }

  void removeResourceTypeChangeListener(
    ResourceType type,
    ResourceChangeListener listener,
  ) {
    _listeners[type]?.removeTypeListener(listener);
  }

  void addResourceChangeListener(
    ResourceType type,
    ResourceTypeChangeListener listener,
  ) {
    _listeners[type]?.addResourceListener(listener);
  }

  void removeResourceChangeListener(
    ResourceType type,
    ResourceTypeChangeListener listener,
  ) {
    _listeners[type]?.removeResourceListener(listener);
  }

  Future<void> _recomputeOutdatedCounts() async {
    final byType = await _resourceDatabase.countOutdatedResourcesByType();
    final total = byType.values.fold(0, (sum, n) => sum + n);
    outdatedResourceCounts.value =
        OutdatedResourceCounts(total: total, byType: byType);
  }

  void _notifyTypeResourceChange(ResourceType type) {
    _recomputeOutdatedCounts();
    _listeners[type]?.notifyTypeListeners(type);
  }

  void _notifyResourceChange(ResourceType type, String id) {
    _listeners[type]?.notifyResourceListeners(type, id);
  }

  ResourceService() {
    _recomputeOutdatedCounts();
  }

  Future<List<Resource>> getResourcesByType(ResourceType resourceType) async {
      return _resourceDatabase.getAllForType(resourceType);
  }

  Future<List<Resource>> getResourcesByPath(
    ResourceType resourceType,
    List<PathMatcher> path,
  ) async {
    return _resourceDatabase.queryByPath(resourceType, path);
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

    final pathType = await FileSystemEntity.type(filePath);
    if (pathType == FileSystemEntityType.notFound) {
      throw ResourceMissingException(resourceType, id);
    }

    return filePath;
  }

  Future<String> getResourceStreamingUrl(
    ResourceType resourceType,
    String id,
  ) async {
    final config = resourceConfigs[resourceType];
    if (config == null) {
        throw Exception('Config not found for resource ${resourceType.name}');
    }

    final template = config.streamingUrlTemplate;
    if (template == null) {
        throw Exception("Config for resource ${resourceType.name} does not support streaming");
    }

    final path = template.replaceAll('{id}', id);
    return "${_assetService.baseHost}/$path";
  }

  Future<void> deleteResource(
    ResourceType resourceType,
    String id,
  ) async {
    await _resourceDatabase.setInstallState(id, InstallState.notInstalled);

    final filePath = await _resolveLocalFilePath(resourceType, id);
    switch (await FileSystemEntity.type(filePath)) {
      case FileSystemEntityType.file:
        await File(filePath).delete();
      case FileSystemEntityType.directory:
        await Directory(filePath).delete(recursive: true);
      default:
        break;
    }

    _notifyTypeResourceChange(resourceType);
    _notifyResourceChange(resourceType, id);
  }

  Future<void> downloadResource(
    ResourceType resourceType,
    String id, {
    ValueChanged<double>? onProgress,
    required CancelToken cancelToken,
  }) async {
    final filePath = await _resolveLocalFilePath(resourceType, id);

    final remoteUrl = await _resolveUrl(resourceType, id);
    final version = await _resourceDatabase.getResourceVersion(resourceType, id);

    var url = Uri.parse(remoteUrl);
    if (version != null) {
      url = url.replace(
        queryParameters: {
          ...url.queryParameters,
          'v': version,
        },
      );
    }

    log('Downloading glosses for $id from $remoteUrl');

    try {
      await _downloadService.downloadZip(
        url: url.toString(),
        localPath: filePath,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );

      await _resourceDatabase.setInstallState(id, InstallState.installed);

      log('Gloss download successful.');
      _notifyTypeResourceChange(resourceType);
      _notifyResourceChange(resourceType, id);
    } catch (e) {
      log('Gloss download failed for $id', error: e);
      rethrow;
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

  Future<String> _resolveUrl(
    ResourceType resourceType,
    String id,
  ) async {
    final config = resourceConfigs[resourceType];
    if (config == null) {
        throw Exception('Config not found for resource ${resourceType.name}');
    }

    final path = config.urlTemplate.replaceAll('{id}', id);
    return "${_assetService.baseHost}/$path";
  }

  Future<void> refreshResources() async {
    for (final type in ResourceType.values) {
      try {
          final config = resourceConfigs[type];
          if (config == null) continue;

          final manifestUrl = config.manifestUrl(_assetService.baseHost);
          log('Refreshing ${type.name} resources from $manifestUrl');

          final entries = await _downloadService.getJsonl(
            manifestUrl,
            convert: (json) => Resource.fromJson(json, type: type),
          );

          debugPrint('${type.name} manifest contained ${entries.length} entries');

          await _resourceDatabase.updateResourcesFromManifest(type, entries);
          _notifyTypeResourceChange(type);
      } catch (error) {
          debugPrint('${type.name} manifest update error: $error');
      }
    }
  }
}

class ResourceTypeListenerGroup {
    final List<ResourceChangeListener> typeListeners = [];
    final List<ResourceTypeChangeListener> resourceListeners = [];

    void notifyTypeListeners(ResourceType type) {
        final listeners = typeListeners;

        for (final listener in listeners) {
          try {
            listener(type);
          } catch (e, stackTrace) {
            log('Resource change listener threw', error: e, stackTrace: stackTrace);
          }
        }
    }

    void notifyResourceListeners(ResourceType type, String id) {
        final listeners = resourceListeners;

        for (final listener in listeners) {
          try {
            listener(type, id);
          } catch (e, stackTrace) {
            log('Resource change listener threw', error: e, stackTrace: stackTrace);
          }
        }
    }

    void addTypeListener(ResourceChangeListener listener) {
        typeListeners.add(listener);
    }

    void removeTypeListener(ResourceChangeListener listener) {
        typeListeners.remove(listener);
    }

    void addResourceListener(ResourceTypeChangeListener listener) {
        resourceListeners.add(listener);
    }

    void removeResourceListener(ResourceTypeChangeListener listener) {
        resourceListeners.remove(listener);
    }
}
