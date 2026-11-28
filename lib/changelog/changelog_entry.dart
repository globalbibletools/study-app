import 'dart:convert';

enum ChangelogEntryType { major, minor }

class ChangelogEntry {
  const ChangelogEntry({
    required this.version,
    required this.date,
    required this.type,
    required this.changes,
    this.summary,
  });

  factory ChangelogEntry.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    if (version is! String) {
      throw const FormatException('Changelog version must be a string.');
    }

    final date = json['date'];
    if (date is! String) {
      throw const FormatException('Changelog date must be a string.');
    }
    final parsedDate = DateTime.tryParse(date);
    if (parsedDate == null) {
      throw FormatException('Invalid changelog date: $date');
    }

    final type = json['type'];
    if (type is! String) {
      throw const FormatException('Changelog type must be a string.');
    }
    final parsedType = switch (type) {
      'major' => ChangelogEntryType.major,
      'minor' => ChangelogEntryType.minor,
      _ => throw FormatException('Unknown changelog entry type: $type'),
    };

    final summaryValue = json['summary'];
    final String? summary;
    switch (parsedType) {
      case ChangelogEntryType.major:
        if (summaryValue is! String || summaryValue.trim().isEmpty) {
          throw const FormatException(
            'Major changelog entries require a non-empty summary.',
          );
        }
        summary = summaryValue;
      case ChangelogEntryType.minor:
        if (json.containsKey('summary')) {
          throw const FormatException(
            'Minor changelog entries must not have a summary.',
          );
        }
        summary = null;
    }

    final changes = json['changes'];
    if (changes is! List) {
      throw const FormatException('Changelog changes must be a list.');
    }
    final parsedChanges = <String>[];
    for (final change in changes) {
      if (change is! String) {
        throw const FormatException('Each changelog change must be a string.');
      }
      parsedChanges.add(change);
    }

    return ChangelogEntry(
      version: version,
      date: parsedDate,
      type: parsedType,
      summary: summary,
      changes: parsedChanges,
    );
  }

  static List<ChangelogEntry> fromJsonArray(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! List) {
      throw const FormatException('Changelog file must contain an array.');
    }

    final entries = <ChangelogEntry>[];
    for (var index = 0; index < decoded.length; index++) {
      final entry = decoded[index];
      if (entry is! Map<String, dynamic>) {
        throw FormatException(
          'Changelog entry at index $index must be an object.',
        );
      }
      entries.add(ChangelogEntry.fromJson(entry));
    }
    return entries;
  }

  final String version;
  final DateTime date;
  final ChangelogEntryType type;
  final String? summary;
  final List<String> changes;
}
