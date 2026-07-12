import 'package:gbt/services/download/download.dart';
import 'package:gbt/services/resources/manifest_resource.dart';
import 'package:gbt/services/resources/remote_asset_service.dart';
import 'package:gbt/services/service_locator.dart';

/// Fetches and parses server-published resource manifests.
///
/// Per `context/resource-manager/design.md` §1–§2, one manifest exists per
/// `(resourceType, typeVersion)` pair. It is a newline-delimited JSON
/// document (`.jsonl`) where each line is a single [ManifestResource] entry.
/// `type`/`typeVersion` are implied by which manifest the entry came from,
/// so they are not stored per entry.
///
/// This class is a thin wrapper over [DownloadService.getJsonl] and
/// [ManifestResource.fromJson]; it owns the URL construction and the
/// `convert` wiring so callers don't have to.
class ManifestSource {
  final DownloadService _downloadService;
  final RemoteAssetService _remoteAssetService;

  ManifestSource({
    DownloadService? downloadService,
    RemoteAssetService? remoteAssetService,
  })  : _downloadService = downloadService ?? getIt<DownloadService>(),
        _remoteAssetService =
            remoteAssetService ?? getIt<RemoteAssetService>();

  /// Fetches the manifest for `(resourceType, typeVersion)` and returns the
  /// parsed entries in stream order.
  ///
  /// Throws [HttpException] on a non-200 response (e.g. 404 when the server
  /// no longer publishes the type version this app understands — see §2
  /// "Update detection") and [FormatException] on a malformed line.
  Future<List<ManifestResource>> fetchManifest({
    required String resourceType,
    required int typeVersion,
  }) {
    return _downloadService.getJsonl(
      '${_remoteAssetService.baseHost}/$resourceType/v$typeVersion/manifest.jsonl',
      convert: ManifestResource.fromJson,
    );
  }
}
