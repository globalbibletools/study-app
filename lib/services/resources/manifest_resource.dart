class ManifestResource {
  final String id;
  final String updatedAt;
  final String sha256;
  final int size;
  final String url;
  final String resourceName;
  final String creatorName;

  ManifestResource({
    required this.id,
    required this.updatedAt,
    required this.sha256,
    required this.size,
    required this.url,
    required this.resourceName,
    required this.creatorName,
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
    if (updatedAt is! String) {
      throw FormatException(
        "Manifest resource field 'updatedAt' must be a String, "
        "got ${updatedAt.runtimeType}",
      );
    }
    if (sha256 is! String) {
      throw FormatException(
        "Manifest resource field 'sha256' must be a String, "
        "got ${sha256.runtimeType}",
      );
    }
    if (size is! int) {
      throw FormatException(
        "Manifest resource field 'size' must be an int, "
        "got ${size.runtimeType}",
      );
    }
    if (url is! String) {
      throw FormatException(
        "Manifest resource field 'url' must be a String, "
        "got ${url.runtimeType}",
      );
    }
    if (resourceName is! String) {
      throw FormatException(
        "Manifest resource field 'resourceName' must be a String, "
        "got ${resourceName.runtimeType}",
      );
    }
    if (creatorName is! String) {
      throw FormatException(
        "Manifest resource field 'creatorName' must be a String, "
        "got ${creatorName.runtimeType}",
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
