import 'package:gbt/services/download/download.dart';
import 'package:gbt/services/resources/manifest_resource.dart';
import 'package:gbt/services/resources/remote_asset_service.dart';
import 'package:gbt/services/resources/resource.dart';
import 'package:gbt/services/resources/resource_manager_database.dart';
import 'package:gbt/services/service_locator.dart';

class ResourceManager {
  static const _typeToPathSegment = {
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

  Future<List<ManifestResource>> checkUpdates({
    required String type,
    required int typeVersion,
  }) async {
    final entries = await fetchManifest(
        resourceType: type,
        typeVersion: typeVersion
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
    required int typeVersion,
  }) {
    final pathSegment = _typeToPathSegment[resourceType] ?? resourceType;
    return _downloadService.getJsonl(
      '${_remoteAssetService.baseHost}/$pathSegment/v$typeVersion/manifest.jsonl',
      convert: ManifestResource.fromJson,
    );
  }

  void dispose() {
    _database.dispose();
  }
}
