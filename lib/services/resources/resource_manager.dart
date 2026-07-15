import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gbt/services/download/cancel_token.dart';
import 'package:gbt/services/download/download.dart';
import 'package:gbt/services/resources/manifest_resource.dart';
import 'package:gbt/services/resources/remote_asset_service.dart';
import 'package:gbt/services/resources/resource.dart';
import 'package:gbt/services/resources/resource_manager_database.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class ResourceManager {
  static const _typeToURLPrefix = {
    'bible': 'bibles/v1',
    'gloss': 'glosses/v1',
    'audio': 'audio',
  };
  static const _typeToLocalPrefix = {
    'bible': 'bibles',
    'gloss': 'glosses',
    'audio': 'audio',
  };

  final DownloadService _downloadService;
  final RemoteAssetService _remoteAssetService;
  final ResourceManagerDatabase _database;

  ResourceManager({
    DownloadService? downloadService,
    RemoteAssetService? remoteAssetService,
    ResourceManagerDatabase? database,
  })  : _downloadService = downloadService ?? getIt<DownloadService>(),
        _remoteAssetService =
            remoteAssetService ?? getIt<RemoteAssetService>(),
        _database = database ?? ResourceManagerDatabase();

  Future<void> init() => _database.init();

  Future<List<Resource>> getResources(String type) =>
      _database.getByType(type);

  Future<void> removeResource({
      required String type,
      required String id,
  }) async {
    final resource = await _database.getById(type, id);
    if (resource == null) {
        // TODO: throw an error here
        return;
    }

    final docDir = await getApplicationDocumentsDirectory();
    final localRelativePath = getLocalPathForType(resource.type, resource.id);
    final localPath = join(docDir.path, localRelativePath);

    final file = File(localPath);
    if (await file.exists()) {
      await file.delete();
    }

    resource.markRemoved();
    await _database.upsert(resource);
  }

  Future<void> downloadResource({
      required String type,
      required String id,
      ValueChanged<double>? onProgress,
      CancelToken? cancelToken,
  }) async {
    final resource = await _database.getById(type, id);
    if (resource == null) {
        // TODO: throw an error here
        return;
    }

    final localPath = getLocalPathForType(resource.type, resource.id);
    await _downloadService.getFile(
        url: '${_remoteAssetService.baseHost}/${resource.url}',
        localRelativePath: localPath,
        onProgress: onProgress,
        cancelToken: cancelToken,
    );

    resource.markInstalled();
    await _database.upsert(resource);
  }

  String getLocalPathForType(String type, String id) {
      switch (type) {
          case "gloss": {
              return 'glosses/$id.db';
          }
          default: {
              throw Exception('Cannot get local path for type $type');
          }
      }
  }

  Future<List<ManifestResource>> checkUpdates({
    required String type,
  }) async {
    final entries = await fetchManifest(
        resourceType: type,
    );

    for (final entry in entries) {
      final existing = await _database.getById(type, entry.id);
      if (existing == null) {
        await _database.upsert(
          Resource.fromManifest(type: type, manifest: entry),
        );
      } else {
        existing.updateFromManifest(entry);
        await _database.upsert(existing);
      }
    }

    return entries;
  }

  Future<List<ManifestResource>> fetchManifest({
    required String resourceType,
  }) {
    final pathPrefix = _typeToURLPrefix[resourceType];
    return _downloadService.getJsonl(
      '${_remoteAssetService.baseHost}/$pathPrefix/manifest.jsonl',
      convert: ManifestResource.fromJson,
    );
  }

  void dispose() {
    _database.dispose();
  }
}
