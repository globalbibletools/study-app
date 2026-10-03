enum ResourceLanguageTextDirection {
  ltr,
  rtl;
}

class ResourceLanguage {
  String code;
  String name;
  ResourceLanguageTextDirection textDirection;

  ResourceLanguage({
    required this.code,
    required this.name,
    required this.textDirection,
  });

  factory ResourceLanguage.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw FormatException(
        'language must be a JSON object, got ${json.runtimeType}',
      );
    }

    final code = json['code'];
    final name = json['name'];
    final textDirection = json['textDirection'];

    if (code is! String) {
      throw FormatException(
        "Manifest language field 'code' must be a String, "
        "got ${code.runtimeType}",
      );
    }
    if (name is! String) {
      throw FormatException(
        "Manifest language field 'name' must be a String, "
        "got ${name.runtimeType}",
      );
    }

    final direction = ResourceLanguageTextDirection.values.firstWhere(
      (d) => d.name == textDirection,
      orElse: () => throw FormatException(
        "Manifest language field 'textDirection' must be one of "
        "${ResourceLanguageTextDirection.values.map((d) => d.name).join(', ')}, "
        "got '$textDirection'",
      ),
    );

    return ResourceLanguage(
      code: code,
      name: name,
      textDirection: direction,
    );
  }
}
