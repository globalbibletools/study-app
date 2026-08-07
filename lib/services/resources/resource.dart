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

  factory Resource.fromJson(ResourceType type, dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw FormatException(
        'Manifest resource must be a JSON object, got ${json.runtimeType}',
      );
    }

    final id = json['id'];
    final updatedAt = json['updatedAt'];
    final sha256 = json['sha256'];
    final size = json['size'];
    final url = json['url'];
    final resourceName = json['resourceName'];
    final creatorName = json['creatorName'];

    if (id is! String) {
      throw FormatException(
        "Manifest resource field 'id' must be a String, got ${id.runtimeType}",
      );
    }
    if (updatedAt != null && updatedAt is! String) {
      throw FormatException(
        "Manifest resource field 'updatedAt' must be a String or null, "
        "got ${updatedAt.runtimeType}",
      );
    }
    if (sha256 != null && sha256 is! String) {
      throw FormatException(
        "Manifest resource field 'sha256' must be a String or null, "
        "got ${sha256.runtimeType}",
      );
    }
    if (size != null && size is! int) {
      throw FormatException(
        "Manifest resource field 'size' must be an int or null, "
        "got ${size.runtimeType}",
      );
    }
    if (url != null && url is! String) {
      throw FormatException(
        "Manifest resource field 'url' must be a String or null, "
        "got ${url.runtimeType}",
      );
    }
    if (resourceName is! String) {
      throw FormatException(
        "Manifest resource field 'resourceName' must be a String, "
        "got ${resourceName.runtimeType}",
      );
    }
    if (creatorName != null && creatorName is! String) {
      throw FormatException(
        "Manifest resource field 'creatorName' must be a String, "
        "got ${creatorName.runtimeType}",
      );
    }

    final hasAll = sha256 != null && size != null && url != null;
    final hasAny = sha256 != null || size != null || url != null;
    if (hasAny && !hasAll) {
      throw FormatException(
        "Manifest resource '$id' must have either all or none of "
        "'sha256'/'size'/'url' (leaf vs. group); got a mix.",
      );
    }

    return Resource(
      id: id,
      type: type,
      serverUpdatedAt: updatedAt,
      sha256: sha256,
      size: size,
      url: url,
      resourceName: resourceName,
      creatorName: creatorName,
    );
  }

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

