class ManifestResource {
  final String id;
  final String? updatedAt;
  final String? sha256;
  final int? size;
  final String? url;
  final String resourceName;
  final String? creatorName;

  bool get isLeaf => url != null;

  ManifestResource({
    required this.id,
    this.updatedAt,
    this.sha256,
    this.size,
    this.url,
    required this.resourceName,
    this.creatorName,
  });

  static ManifestResource fromJson(dynamic json) {
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

    // Leaf vs. group is a data property: a leaf carries all of
    // sha256/size/url; a group carries none. Mixed presence is invalid.
    final hasAll = sha256 != null && size != null && url != null;
    final hasAny = sha256 != null || size != null || url != null;
    if (hasAny && !hasAll) {
      throw FormatException(
        "Manifest resource '$id' must have either all or none of "
        "'sha256'/'size'/'url' (leaf vs. group); got a mix.",
      );
    }

    return ManifestResource(
      id: id,
      updatedAt: updatedAt,
      sha256: sha256,
      size: size,
      url: url,
      resourceName: resourceName,
      creatorName: creatorName,
    );
  }
}
