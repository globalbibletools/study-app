enum ResourceType {
  Gloss;

  @override
  String toString() => name;
}

enum ServerState {
  Available,
  Removed;

  @override
  String toString() => name;
}

class Resource {
  String id;
  ResourceType type;
  ServerState serverState;
  String serverUpdatedAt;
  String sha256;
  int size;
  String url;
  String resourceName;
  String? creatorName;

  Resource({
    this.id = '',
    this.type = ResourceType.Gloss,
    this.serverState = ServerState.Available,
    this.serverUpdatedAt = '',
    this.sha256 = '',
    this.size = 0,
    this.url = '',
    this.resourceName = '',
    this.creatorName,
  });

  ResourceView toView() => ResourceView(
        id: id,
        resourceName: resourceName,
        creatorName: creatorName,
        size: size,
      );

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'resource_type': type,
      'server_state': serverState,
      'server_updated_ at': serverUpdatedAt,
      'sha_256': sha256,
      'size': size,
      'url': url,
      'resource_name': resourceName,
      'creator_name': creatorName,
    };
  }
}

class ResourceView {
  final String id;
  final String resourceName;
  final String? creatorName;
  final int size;

  const ResourceView({
    required this.id,
    required this.resourceName,
    required this.size,
    this.creatorName,
  });
}

