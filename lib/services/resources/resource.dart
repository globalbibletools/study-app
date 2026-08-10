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

class InstallableDetails {
  final ServerState serverState;
  final String serverUpdatedAt;
  final String sha256;
  final int size;
  final String url;
  final InstallState installState;
  final String? localUpdatedAt;

  const InstallableDetails({
    required this.serverState,
    required this.serverUpdatedAt,
    required this.sha256,
    required this.size,
    required this.url,
    required this.installState,
    this.localUpdatedAt,
  });
}

class Resource {
  String id;
  ResourceType type;
  String resourceName;
  String? creatorName;
  InstallableDetails? installableDetails;

  Resource({
    this.id = '',
    required this.type,
    this.resourceName = '',
    this.creatorName,
    this.installableDetails,
  });

  factory Resource.fromJson(dynamic json, {required ResourceType type}) {
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

    // Leaf vs. group: all or none of the installable fields must be present.
    final installableFields = [updatedAt, sha256, size, url];
    final hasAll = installableFields.every((v) => v != null);
    final hasAny = installableFields.any((v) => v != null);
    if (hasAny && !hasAll) {
      throw FormatException(
        "Manifest resource '$id' must have either all or none of "
        "'updatedAt'/'sha256'/'size'/'url' (leaf vs. group); got a mix.",
      );
    }

    final installableDetails = hasAll
        ? InstallableDetails(
            serverState: ServerState.Available,
            serverUpdatedAt: updatedAt as String,
            sha256: sha256 as String,
            size: size as int,
            url: url as String,
            installState: InstallState.NotInstalled,
          )
        : null;

    return Resource(
      id: id,
      type: type,
      resourceName: resourceName,
      creatorName: creatorName,
      installableDetails: installableDetails,
    );
  }

  Map<String, Object?> toMap() {
    final d = installableDetails;
    return <String, Object?>{
      'id': id,
      'resource_type': type,
      'server_state': d?.serverState,
      'server_updated_at': d?.serverUpdatedAt,
      'local_updated_at': d?.localUpdatedAt,
      'sha_256': d?.sha256,
      'size': d?.size,
      'url': d?.url,
      'resource_name': resourceName,
      'creator_name': creatorName,
      'install_state': d?.installState,
    };
  }
}

