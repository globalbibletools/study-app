enum ResourceType {
  Gloss,
  bible,
  audio;

  @override
  String toString() => name;
}

enum ServerState {
  Available,
  Removed;

  @override
  String toString() => name;
}

enum InstallState {
  NotInstalled,
  Installed;

  @override
  String toString() => name;
}

class OutdatedResourceCounts {
  final int total;
  final Map<ResourceType, int> byType;

  const OutdatedResourceCounts({this.total = 0, this.byType = const {}});

  int of(ResourceType type) => byType[type] ?? 0;
}

class Resource {
  String id;
  ResourceType type;
  ServerState serverState;
  String? serverUpdatedAt;
  String? sha256;
  int? size;
  String? url;
  String resourceName;
  String? creatorName;
  InstallState installState;
  String? localUpdatedAt;

  Resource({
    this.id = '',
    required this.type,
    this.serverState = ServerState.Available,
    this.serverUpdatedAt,
    this.sha256,
    this.size,
    this.url,
    this.resourceName = '',
    this.creatorName,
    this.installState = InstallState.NotInstalled,
    this.localUpdatedAt,
  });

  ResourceView toView() => ResourceView(
        id: id,
        resourceName: resourceName,
        creatorName: creatorName,
        size: size,
        installState: installState,
        serverUpdatedAt: serverUpdatedAt,
        localUpdatedAt: localUpdatedAt,
      );

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'resource_type': type,
      'server_state': serverState,
      'server_updated_at': serverUpdatedAt,
      'local_updated_at': localUpdatedAt,
      'sha_256': sha256,
      'size': size,
      'url': url,
      'resource_name': resourceName,
      'creator_name': creatorName,
      'install_state': installState,
    };
  }
}

class ResourceView {
  final String id;
  final String resourceName;
  final String? creatorName;
  final int? size;
  final InstallState installState;
  final String? serverUpdatedAt;
  final String? localUpdatedAt;

  const ResourceView({
    required this.id,
    required this.resourceName,
    this.serverUpdatedAt,
    this.size,
    this.creatorName,
    this.installState = InstallState.NotInstalled,
    this.localUpdatedAt,
  });
}

