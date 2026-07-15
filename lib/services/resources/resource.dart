import 'package:gbt/services/resources/manifest_resource.dart';

class Resource {
  final String type;
  final String id;
  String? serverUpdatedAt;
  String? sha256;
  int? size;
  String? url;
  String? resourceName;
  String? creatorName;
  String? localUpdatedAt;

  Resource({
    required this.type,
    required this.id,
    this.serverUpdatedAt,
    this.sha256,
    this.size,
    this.url,
    this.resourceName,
    this.creatorName,
    this.localUpdatedAt,
  });

  static Resource fromManifest({
    required String type,
    required ManifestResource manifest,
  }) {
    return Resource(
      type: type,
      id: manifest.id,
      serverUpdatedAt: manifest.updatedAt,
      sha256: manifest.sha256,
      size: manifest.size,
      url: manifest.url,
      resourceName: manifest.resourceName,
      creatorName: manifest.creatorName,
      localUpdatedAt: null,
    );
  }

  void updateFromManifest(ManifestResource manifest) {
    serverUpdatedAt = manifest.updatedAt;
    sha256 = manifest.sha256;
    size = manifest.size;
    url = manifest.url;
    resourceName = manifest.resourceName;
    creatorName = manifest.creatorName;
  }

  void markInstalled() {
    localUpdatedAt = serverUpdatedAt;
  }

  Map<String, Object?> toMap() => {
        'type': type,
        'id': id,
        'server_updated_at': serverUpdatedAt,
        'sha256': sha256,
        'size': size,
        'url': url,
        'resource_name': resourceName,
        'creator_name': creatorName,
        'local_updated_at': localUpdatedAt,
      };

  static Resource fromMap(Map<String, Object?> map) {
    return Resource(
      type: map['type'] as String,
      id: map['id'] as String,
      serverUpdatedAt: map['server_updated_at'] as String?,
      sha256: map['sha256'] as String?,
      size: map['size'] as int?,
      url: map['url'] as String?,
      resourceName: map['resource_name'] as String?,
      creatorName: map['creator_name'] as String?,
      localUpdatedAt: map['local_updated_at'] as String?,
    );
  }
}
