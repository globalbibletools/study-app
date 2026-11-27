import 'dart:convert';
import 'dart:io';

final RegExp _versionPattern = RegExp(
  r'^(\d{2})\.(\d{2})\.(\d+)(?:-beta([1-9]\d*))?$',
);
final RegExp _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final RegExp _arbFilePattern = RegExp(
  r'^app_([a-z]{2,3}(?:_[A-Za-z0-9]+)?)\.arb$',
);
final RegExp _changelogFilePattern = RegExp(
  r'^changelog_([a-z]{2,3}(?:_[A-Za-z0-9]+)?)\.json$',
);

const String usage = '''
Usage:
  dart run tool/release/release.dart next --kind beta|public [--date YYYY-MM-DD] [--json]
  dart run tool/release/release.dart prepare --kind beta|public --version VERSION [--date YYYY-MM-DD] [--changelog PATH | --no-changelog]
  dart run tool/release/release.dart verify --tag TAG
  dart run tool/release/release.dart tag --tag TAG [--pr NUMBER]

Options:
  --root PATH  Operate on another checkout (default: current directory).
  --help       Show this help.
''';

class ReleaseException implements Exception {
  ReleaseException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UsageException implements Exception {
  UsageException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum ReleaseKind {
  beta('beta'),
  public('public');

  const ReleaseKind(this.cliName);

  final String cliName;

  static ReleaseKind parse(String value) {
    for (final kind in values) {
      if (kind.cliName == value) {
        return kind;
      }
    }
    throw ReleaseException(
      'Unknown release kind "$value". Expected "beta" or "public".',
    );
  }
}

class ReleaseVersion implements Comparable<ReleaseVersion> {
  const ReleaseVersion({
    required this.year,
    required this.month,
    required this.patch,
    this.beta,
  });

  final int year;
  final int month;
  final int patch;
  final int? beta;

  static ReleaseVersion parse(String value) {
    final match = _versionPattern.firstMatch(value);
    if (match == null) {
      throw ReleaseException(
        'Invalid version "$value": expected YY.MM.C or YY.MM.C-betaN.',
      );
    }
    final month = int.parse(match.group(2)!);
    if (month < 1 || month > 12) {
      throw ReleaseException(
        'Invalid version "$value": month must be between 01 and 12.',
      );
    }
    final beta = match.group(4);
    return ReleaseVersion(
      year: int.parse(match.group(1)!),
      month: month,
      patch: int.parse(match.group(3)!),
      beta: beta == null ? null : int.parse(beta),
    );
  }

  bool get isBeta => beta != null;

  String get baseName => '${_twoDigits(year)}.${_twoDigits(month)}.$patch';

  String get name => isBeta ? '$baseName-beta$beta' : baseName;

  ReleaseVersion get base =>
      ReleaseVersion(year: year, month: month, patch: patch);

  ReleaseVersion withPatch(int value) =>
      ReleaseVersion(year: year, month: month, patch: value);

  ReleaseVersion withBeta(int? value) =>
      ReleaseVersion(year: year, month: month, patch: patch, beta: value);

  @override
  int compareTo(ReleaseVersion other) {
    if (year != other.year) {
      return year.compareTo(other.year);
    }
    if (month != other.month) {
      return month.compareTo(other.month);
    }
    if (patch != other.patch) {
      return patch.compareTo(other.patch);
    }
    if (beta == other.beta) {
      return 0;
    }
    if (beta == null) {
      return 1;
    }
    if (other.beta == null) {
      return -1;
    }
    return beta!.compareTo(other.beta!);
  }

  @override
  bool operator ==(Object other) =>
      other is ReleaseVersion &&
      year == other.year &&
      month == other.month &&
      patch == other.patch &&
      beta == other.beta;

  @override
  int get hashCode => Object.hash(year, month, patch, beta);

  @override
  String toString() => name;
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

DateTime parseReleaseDate(String value) {
  final match = _datePattern.firstMatch(value);
  if (match == null) {
    throw ReleaseException('Invalid date "$value": expected YYYY-MM-DD.');
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    throw ReleaseException('Invalid date "$value".');
  }
  return date;
}

String formatReleaseDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${_twoDigits(date.month)}-${_twoDigits(date.day)}';

List<ReleaseVersion> parseReleaseTags(Iterable<String> tags) => [
  for (final tag in tags)
    if (_versionPattern.hasMatch(tag.trim())) ReleaseVersion.parse(tag.trim()),
];

class ReleasePlan {
  ReleasePlan({
    required this.date,
    required this.highestPublic,
    required this.highestBeta,
    required this.activeBeta,
    required this.publicBase,
    required this.nextBeta,
    required this.nextPublic,
  });

  final DateTime date;
  final ReleaseVersion? highestPublic;
  final ReleaseVersion? highestBeta;
  final bool activeBeta;
  final ReleaseVersion publicBase;
  final ReleaseVersion nextBeta;
  final ReleaseVersion nextPublic;

  ReleaseVersion nextFor(ReleaseKind kind) =>
      kind == ReleaseKind.beta ? nextBeta : nextPublic;

  Map<String, Object?> toJson(ReleaseKind kind) => {
    'kind': kind.cliName,
    'version': nextFor(kind).name,
    'date': formatReleaseDate(date),
    'month': '${_twoDigits(date.year % 100)}.${_twoDigits(date.month)}',
    'activeBeta': activeBeta,
    'publicBase': publicBase.name,
    'nextBeta': nextBeta.name,
    'nextPublic': nextPublic.name,
  };
}

ReleasePlan computeNextRelease({
  required DateTime date,
  required Iterable<String> tags,
}) {
  final currentMonth = parseReleaseTags(tags)
      .where((tag) => tag.year == date.year % 100 && tag.month == date.month)
      .toList();
  final publics = currentMonth.where((tag) => !tag.isBeta).toList()..sort();
  final betas = currentMonth.where((tag) => tag.isBeta).toList()..sort();

  final highestPublic = publics.isEmpty ? null : publics.last;
  final highestBeta = betas.isEmpty ? null : betas.last;
  final activeBeta =
      highestBeta != null &&
      (highestPublic == null || highestBeta.compareTo(highestPublic) > 0);

  final ReleaseVersion publicBase;
  if (activeBeta) {
    publicBase = highestBeta.base;
  } else if (highestPublic != null) {
    publicBase = highestPublic.withPatch(highestPublic.patch + 1);
  } else {
    publicBase = ReleaseVersion(
      year: date.year % 100,
      month: date.month,
      patch: 0,
    );
  }

  final nextBeta = activeBeta
      ? highestBeta.withBeta(highestBeta.beta! + 1)
      : publicBase.withBeta(1);
  final nextPublic = activeBeta ? highestBeta.base : publicBase;

  return ReleasePlan(
    date: date,
    highestPublic: highestPublic,
    highestBeta: highestBeta,
    activeBeta: activeBeta,
    publicBase: publicBase,
    nextBeta: nextBeta,
    nextPublic: nextPublic,
  );
}

class ChangelogEntry {
  ChangelogEntry({
    required this.version,
    required this.date,
    required this.type,
    required List<String> changes,
  }) : changes = List.unmodifiable(changes);

  final ReleaseVersion version;
  final String date;
  final String type;
  final List<String> changes;

  Map<String, Object?> toJson() => {
    'version': version.name,
    'date': date,
    'type': type,
    'changes': changes,
  };

  static ChangelogEntry fromJson(Object? value, String source) {
    if (value is! Map<String, dynamic>) {
      throw ReleaseException('$source must be a JSON object.');
    }

    final versionValue = value['version'];
    if (versionValue is! String) {
      throw ReleaseException('$source needs a string "version".');
    }
    final ReleaseVersion version;
    try {
      version = ReleaseVersion.parse(versionValue);
    } on ReleaseException catch (error) {
      throw ReleaseException('$source: ${error.message}');
    }
    if (version.isBeta) {
      throw ReleaseException(
        '$source: changelog versions must be public releases, '
        'not "${version.name}".',
      );
    }

    final dateValue = value['date'];
    if (dateValue is! String) {
      throw ReleaseException('$source needs a string "date".');
    }
    try {
      parseReleaseDate(dateValue);
    } on ReleaseException catch (error) {
      throw ReleaseException('$source: ${error.message}');
    }

    final typeValue = value['type'];
    if (typeValue != 'major' && typeValue != 'minor') {
      throw ReleaseException('$source: "type" must be "major" or "minor".');
    }

    final changesValue = value['changes'];
    if (changesValue is! List || changesValue.isEmpty) {
      throw ReleaseException('$source needs a non-empty "changes" array.');
    }
    final changes = <String>[];
    for (final change in changesValue) {
      if (change is! String || change.trim().isEmpty) {
        throw ReleaseException(
          '$source: every change must be a non-empty string.',
        );
      }
      changes.add(change);
    }

    return ChangelogEntry(
      version: version,
      date: dateValue,
      type: typeValue as String,
      changes: changes,
    );
  }
}

List<ChangelogEntry> parseChangelog(String content, {required String source}) {
  Object? decoded;
  try {
    decoded = jsonDecode(content);
  } on FormatException catch (error) {
    throw ReleaseException('$source is not valid JSON: ${error.message}');
  }
  if (decoded is! List) {
    throw ReleaseException('$source must contain a JSON array.');
  }

  final entries = [
    for (var index = 0; index < decoded.length; index++)
      ChangelogEntry.fromJson(decoded[index], '$source entry ${index + 1}'),
  ];
  for (var index = 1; index < entries.length; index++) {
    final previous = entries[index - 1].version;
    final current = entries[index].version;
    if (current.compareTo(previous) <= 0) {
      throw ReleaseException(
        '$source: versions must be unique and increasing '
        '(entry ${index + 1} is ${current.name}, previous is '
        '${previous.name}).',
      );
    }
  }
  return entries;
}

class ChangelogFile {
  ChangelogFile({
    required this.locale,
    required this.relativePath,
    required this.content,
    required this.entries,
  });

  final String locale;
  final String relativePath;
  final String content;
  final List<ChangelogEntry> entries;
}

class ChangelogSet {
  ChangelogSet(this.files);

  final List<ChangelogFile> files;

  List<String> get locales => [for (final file in files) file.locale];

  static ChangelogSet load(Directory root, {List<String>? locales}) {
    final resolved = locales ?? discoverLocales(root);
    final files = <ChangelogFile>[];
    for (final locale in resolved) {
      final relativePath = 'assets/l10n/changelog_$locale.json';
      final file = File(_join(root, relativePath));
      if (!file.existsSync()) {
        throw ReleaseException(
          'Missing changelog file for locale "$locale": $relativePath.',
        );
      }
      final content = file.readAsStringSync();
      files.add(
        ChangelogFile(
          locale: locale,
          relativePath: relativePath,
          content: content,
          entries: parseChangelog(content, source: relativePath),
        ),
      );
    }

    final reference = files.first;
    for (final file in files.skip(1)) {
      _checkSequence(reference, file);
    }
    return ChangelogSet(files);
  }
}

void _checkSequence(ChangelogFile reference, ChangelogFile other) {
  if (reference.entries.length != other.entries.length) {
    throw ReleaseException(
      '${other.relativePath} has ${other.entries.length} entries; '
      '${reference.relativePath} has ${reference.entries.length}.',
    );
  }
  for (var index = 0; index < reference.entries.length; index++) {
    final expected = reference.entries[index];
    final actual = other.entries[index];
    if (expected.version != actual.version ||
        expected.type != actual.type ||
        expected.date != actual.date) {
      throw ReleaseException(
        '${other.relativePath} entry ${index + 1} does not match '
        '${reference.relativePath} '
        '(${actual.version.name}/${actual.type}/${actual.date} vs '
        '${expected.version.name}/${expected.type}/${expected.date}).',
      );
    }
  }
}

class ChangelogInput {
  ChangelogInput({required this.type, required this.changes});

  final String type;
  final Map<String, List<String>> changes;

  static ChangelogInput parse(String content, {required String source}) {
    Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException catch (error) {
      throw ReleaseException('$source is not valid JSON: ${error.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw ReleaseException('$source must contain a JSON object.');
    }

    const expectedKeys = {'type', 'changes'};
    final unknown = decoded.keys.toSet().difference(expectedKeys);
    if (unknown.isNotEmpty) {
      throw ReleaseException(
        '$source has unknown key(s): ${unknown.join(', ')}.',
      );
    }

    final typeValue = decoded['type'];
    if (typeValue != 'major' && typeValue != 'minor') {
      throw ReleaseException('$source: "type" must be "major" or "minor".');
    }

    final changesValue = decoded['changes'];
    if (changesValue is! Map<String, dynamic> || changesValue.isEmpty) {
      throw ReleaseException(
        '$source needs a non-empty "changes" object keyed by locale.',
      );
    }

    final changes = <String, List<String>>{};
    for (final entry in changesValue.entries) {
      final value = entry.value;
      if (value is! List || value.isEmpty) {
        throw ReleaseException(
          '$source: changes for "${entry.key}" must be a non-empty array.',
        );
      }
      final notes = <String>[];
      for (final note in value) {
        if (note is! String || note.trim().isEmpty) {
          throw ReleaseException(
            '$source: every change for "${entry.key}" must be a '
            'non-empty string.',
          );
        }
        notes.add(note);
      }
      changes[entry.key] = List.unmodifiable(notes);
    }

    return ChangelogInput(
      type: typeValue as String,
      changes: Map.unmodifiable(changes),
    );
  }
}

class ChangelogWrite {
  ChangelogWrite({
    required this.file,
    required this.content,
    required this.changed,
  });

  final ChangelogFile file;
  final String content;
  final bool changed;
}

String appendChangelogEntryText(String source, ChangelogEntry entry) {
  final decoded = jsonDecode(source);
  if (decoded is! List) {
    throw ReleaseException('Changelog source must contain a JSON array.');
  }

  final entryText = const JsonEncoder.withIndent(
    '  ',
  ).convert(entry.toJson()).split('\n').map((line) => '  $line').join('\n');

  final trimmed = source.replaceFirst(RegExp(r'\s+$'), '');
  final trailing = source.substring(trimmed.length);
  final closeIndex = trimmed.lastIndexOf(']');
  if (closeIndex < 0) {
    throw ReleaseException('Changelog source is missing its closing bracket.');
  }
  final head = trimmed
      .substring(0, closeIndex)
      .replaceFirst(RegExp(r'\s+$'), '');

  final body = decoded.isEmpty ? '[\n$entryText\n]' : '$head,\n$entryText\n]';
  return '$body$trailing';
}

List<ChangelogWrite> planChangelogAppend(
  ChangelogSet set, {
  required ReleaseVersion version,
  required DateTime date,
  required ChangelogInput input,
}) {
  if (version.isBeta) {
    throw ReleaseException(
      'Changelog entries must use a public version, not "${version.name}".',
    );
  }

  final locales = set.locales.toSet();
  final missing = locales.difference(input.changes.keys.toSet()).toList()
    ..sort();
  final extra = input.changes.keys.toSet().difference(locales).toList()..sort();
  if (missing.isNotEmpty) {
    throw ReleaseException(
      'Changelog input is missing locale(s): ${missing.join(', ')}.',
    );
  }
  if (extra.isNotEmpty) {
    throw ReleaseException(
      'Changelog input has locale(s) without an app locale: '
      '${extra.join(', ')}.',
    );
  }

  final dateText = formatReleaseDate(date);
  final writes = <ChangelogWrite>[];
  for (final file in set.files) {
    final changes = input.changes[file.locale]!;
    final previous = file.entries.isEmpty ? null : file.entries.last;
    if (previous != null && previous.version == version) {
      final same =
          previous.date == dateText &&
          previous.type == input.type &&
          _sameStrings(previous.changes, changes);
      if (!same) {
        throw ReleaseException(
          '${file.relativePath} already has a different entry for '
          '${version.name}; refusing to rewrite history.',
        );
      }
      writes.add(
        ChangelogWrite(file: file, content: file.content, changed: false),
      );
      continue;
    }
    if (previous != null && version.compareTo(previous.version) < 0) {
      throw ReleaseException(
        '${file.relativePath} ends with ${previous.version.name}; '
        '${version.name} is not newer.',
      );
    }

    final entry = ChangelogEntry(
      version: version,
      date: dateText,
      type: input.type,
      changes: changes,
    );
    writes.add(
      ChangelogWrite(
        file: file,
        content: appendChangelogEntryText(file.content, entry),
        changed: true,
      ),
    );
  }
  return writes;
}

bool _sameStrings(List<String> a, List<String> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) {
      return false;
    }
  }
  return true;
}

class PrepareResult {
  PrepareResult({
    required this.version,
    required this.updatedFiles,
    required this.changelogLocales,
  });

  final ReleaseVersion version;
  final List<String> updatedFiles;
  final List<String> changelogLocales;
}

PrepareResult prepareRelease({
  required Directory root,
  required ReleaseKind kind,
  required String version,
  required DateTime date,
  String? changelogPath,
  bool noChangelog = false,
  List<String>? tags,
}) {
  if (version.contains('+')) {
    throw ReleaseException(
      'Version "$version" must omit the build number; CI owns it.',
    );
  }
  final parsedVersion = ReleaseVersion.parse(version);

  if (parsedVersion.isBeta != (kind == ReleaseKind.beta)) {
    throw ReleaseException(
      kind == ReleaseKind.beta
          ? 'A beta release version must end with -betaN.'
          : 'A public release version must not have a suffix.',
    );
  }

  final knownTags = tags ?? readLocalTags(root);
  final plan = computeNextRelease(date: date, tags: knownTags);
  final expected = plan.nextFor(kind);
  if (parsedVersion != expected) {
    throw ReleaseException(
      'Version ${parsedVersion.name} is not the next ${kind.cliName} '
      'release; expected ${expected.name}.',
    );
  }

  if (changelogPath != null && noChangelog) {
    throw ReleaseException(
      'Pass either --changelog or --no-changelog, not both.',
    );
  }
  if (kind == ReleaseKind.beta && changelogPath != null) {
    throw ReleaseException(
      'Changelog entries apply only to public releases; beta releases '
      'must not add one.',
    );
  }
  if (kind == ReleaseKind.public && changelogPath == null && !noChangelog) {
    throw ReleaseException(
      'A public release needs --changelog <path> or --no-changelog.',
    );
  }

  final pubspecFile = File(_join(root, 'pubspec.yaml'));
  if (!pubspecFile.existsSync()) {
    throw ReleaseException('Missing pubspec.yaml in ${root.path}.');
  }
  final pubspec = pubspecFile.readAsStringSync();
  final updatedPubspec = _withPubspecVersion(pubspec, parsedVersion);

  final writes = <ChangelogWrite>[];
  if (changelogPath != null) {
    final inputFile = File(changelogPath);
    if (!inputFile.existsSync()) {
      throw ReleaseException('Missing changelog input file: $changelogPath.');
    }
    final set = ChangelogSet.load(root);
    final input = ChangelogInput.parse(
      inputFile.readAsStringSync(),
      source: changelogPath,
    );
    writes.addAll(
      planChangelogAppend(
        set,
        version: parsedVersion,
        date: date,
        input: input,
      ),
    );
  }

  final updatedFiles = <String>[];
  for (final write in writes) {
    if (!write.changed) {
      continue;
    }
    File(_join(root, write.file.relativePath)).writeAsStringSync(write.content);
    updatedFiles.add(write.file.relativePath);
  }
  if (updatedPubspec != pubspec) {
    pubspecFile.writeAsStringSync(updatedPubspec);
    updatedFiles.add('pubspec.yaml');
  }

  return PrepareResult(
    version: parsedVersion,
    updatedFiles: updatedFiles,
    changelogLocales: [for (final write in writes) write.file.locale],
  );
}

class VerifyResult {
  VerifyResult({
    required this.version,
    required this.pubspecVersion,
    required this.locales,
  });

  final ReleaseVersion version;
  final ReleaseVersion pubspecVersion;
  final List<String> locales;
}

VerifyResult verifyRelease({
  required Directory root,
  required String tag,
  List<String>? localTags,
  List<String>? remoteTags,
  String? pubspecContent,
}) {
  final ReleaseVersion version;
  try {
    version = ReleaseVersion.parse(tag);
  } on ReleaseException catch (error) {
    throw ReleaseException('Invalid tag "$tag": ${error.message}');
  }

  final local = localTags ?? readLocalTags(root);
  final remote = remoteTags ?? readRemoteTags(root);
  if (local.contains(tag)) {
    throw ReleaseException('Tag $tag already exists locally.');
  }
  if (remote.contains(tag)) {
    throw ReleaseException('Tag $tag already exists on origin.');
  }

  final knownTags = <String>{...local, ...remote};
  for (final known in parseReleaseTags(knownTags)) {
    if (known.compareTo(version) >= 0) {
      throw ReleaseException(
        'Tag $tag must be newer than existing tag ${known.name}.',
      );
    }
  }

  final pubspec =
      pubspecContent ?? File(_join(root, 'pubspec.yaml')).readAsStringSync();
  final ReleaseVersion pubspecVersion;
  try {
    pubspecVersion = readPubspecVersion(pubspec);
  } on ReleaseException catch (error) {
    throw ReleaseException('pubspec.yaml: ${error.message}');
  }
  if (pubspecVersion != version) {
    throw ReleaseException(
      'pubspec.yaml version ${pubspecVersion.name} does not match tag '
      '$tag.',
    );
  }

  final set = ChangelogSet.load(root);
  return VerifyResult(
    version: version,
    pubspecVersion: pubspecVersion,
    locales: set.locales,
  );
}

class TagResult {
  TagResult({required this.tag, required this.commit, required this.pr});

  final String tag;
  final String commit;
  final int pr;
}

TagResult tagRelease({required Directory root, required String tag, int? pr}) {
  final status = _run([
    'git',
    'status',
    '--porcelain',
  ], workingDirectory: root.path);
  if (status.trim().isNotEmpty) {
    throw ReleaseException('Worktree is not clean:\n${status.trim()}');
  }

  _run([
    'git',
    'fetch',
    'origin',
    'main',
    '--tags',
  ], workingDirectory: root.path);

  final localTags = readLocalTags(root);
  final remoteTags = readRemoteTags(root);
  verifyRelease(
    root: root,
    tag: tag,
    localTags: localTags,
    remoteTags: remoteTags,
  );

  final Map<String, dynamic> pullRequest;
  if (pr != null) {
    pullRequest = _ghJson(root, [
      'pr',
      'view',
      '$pr',
      '--json',
      'number,state,mergeCommit,headRefName',
    ]);
  } else {
    final branch = _run([
      'git',
      'rev-parse',
      '--abbrev-ref',
      'HEAD',
    ], workingDirectory: root.path).trim();
    if (branch == 'HEAD') {
      throw ReleaseException(
        'Detached HEAD; pass --pr <number> to select the release PR.',
      );
    }
    final output = _run([
      'gh',
      'pr',
      'list',
      '--head',
      branch,
      '--state',
      'merged',
      '--limit',
      '1',
      '--json',
      'number,state,mergeCommit,headRefName',
    ], workingDirectory: root.path);
    final decoded = jsonDecode(output);
    if (decoded is! List || decoded.isEmpty) {
      throw ReleaseException(
        'No merged PR found for branch "$branch"; pass --pr <number>.',
      );
    }
    final first = decoded.first;
    if (first is! Map<String, dynamic>) {
      throw ReleaseException('Unexpected gh pr list output.');
    }
    pullRequest = first;
  }

  if (pullRequest['state'] != 'MERGED') {
    throw ReleaseException('PR #${pullRequest['number']} is not merged.');
  }
  final mergeCommit = pullRequest['mergeCommit'];
  final commit = mergeCommit is Map<String, dynamic>
      ? mergeCommit['oid'] as String?
      : null;
  if (commit == null || commit.isEmpty) {
    throw ReleaseException('PR #${pullRequest['number']} has no merge commit.');
  }

  final ancestor = Process.runSync('git', [
    'merge-base',
    '--is-ancestor',
    commit,
    'origin/main',
  ], workingDirectory: root.path);
  if (ancestor.exitCode != 0) {
    throw ReleaseException(
      'origin/main does not contain release commit $commit.',
    );
  }

  final committedPubspec = _run([
    'git',
    'show',
    '$commit:pubspec.yaml',
  ], workingDirectory: root.path);
  final ReleaseVersion committedVersion;
  try {
    committedVersion = readPubspecVersion(committedPubspec);
  } on ReleaseException catch (error) {
    throw ReleaseException('Release commit pubspec.yaml: ${error.message}');
  }
  if (committedVersion.name != tag) {
    throw ReleaseException(
      'Release commit pubspec.yaml has ${committedVersion.name}, '
      'not $tag.',
    );
  }

  _run([
    'git',
    'push',
    'origin',
    '$commit:refs/tags/$tag',
  ], workingDirectory: root.path);
  _run(['git', 'tag', tag, commit], workingDirectory: root.path);

  return TagResult(tag: tag, commit: commit, pr: pullRequest['number'] as int);
}

ReleaseVersion readPubspecVersion(String source) {
  final match = RegExp(
    r'^version:[ \t]*(\S+)[ \t]*\r?$',
    multiLine: true,
  ).firstMatch(source);
  if (match == null) {
    throw ReleaseException('No version: line found.');
  }
  final raw = match.group(1)!;
  if (raw.contains('+')) {
    throw ReleaseException(
      'Version "$raw" must omit the build number; CI owns it.',
    );
  }
  return ReleaseVersion.parse(raw);
}

String _withPubspecVersion(String source, ReleaseVersion version) {
  final pattern = RegExp(r'^version:[ \t]*(\S+)[ \t]*\r?$', multiLine: true);
  final match = pattern.firstMatch(source);
  if (match == null) {
    throw ReleaseException('pubspec.yaml has no version: line.');
  }
  final carriageReturn = match.group(0)!.endsWith('\r') ? '\r' : '';
  return source.replaceRange(
    match.start,
    match.end,
    'version: ${version.name}$carriageReturn',
  );
}

List<String> discoverLocales(Directory root) {
  final appLocales = _localesIn(
    Directory(_join(root, 'lib/l10n')),
    _arbFilePattern,
  );
  if (appLocales.isEmpty) {
    throw ReleaseException('No lib/l10n/app_<locale>.arb files found.');
  }
  final changelogLocales = _localesIn(
    Directory(_join(root, 'assets/l10n')),
    _changelogFilePattern,
  );

  final missing = appLocales.difference(changelogLocales).toList()..sort();
  final extra = changelogLocales.difference(appLocales).toList()..sort();
  if (missing.isNotEmpty) {
    throw ReleaseException(
      'Missing changelog file(s) for locale(s): ${missing.join(', ')}.',
    );
  }
  if (extra.isNotEmpty) {
    throw ReleaseException(
      'Changelog file(s) without a matching app locale: '
      '${extra.join(', ')}.',
    );
  }
  return appLocales.toList()..sort();
}

Set<String> _localesIn(Directory directory, RegExp pattern) {
  if (!directory.existsSync()) {
    throw ReleaseException('Missing directory ${directory.path}.');
  }
  final locales = <String>{};
  for (final entity in directory.listSync()) {
    if (entity is! File) {
      continue;
    }
    final match = pattern.firstMatch(_basename(entity.path));
    if (match != null) {
      locales.add(match.group(1)!);
    }
  }
  return locales;
}

String _basename(String path) {
  final index = path.lastIndexOf(RegExp(r'[/\\]'));
  return index < 0 ? path : path.substring(index + 1);
}

String _join(Directory root, String relative) {
  if (relative.startsWith('/') ||
      RegExp(r'^[A-Za-z]:[\\/]').hasMatch(relative)) {
    return relative;
  }
  return '${root.path}${Platform.pathSeparator}$relative';
}

List<String> readLocalTags(Directory root) {
  final output = _run(['git', 'tag', '--list'], workingDirectory: root.path);
  return [
    for (final line in LineSplitter().convert(output))
      if (line.trim().isNotEmpty) line.trim(),
  ];
}

List<String> readRemoteTags(Directory root) {
  final output = _run([
    'git',
    'ls-remote',
    '--tags',
    'origin',
  ], workingDirectory: root.path);
  final tags = <String>[];
  for (final line in LineSplitter().convert(output)) {
    final tab = line.indexOf('\t');
    if (tab < 0) {
      continue;
    }
    final ref = line.substring(tab + 1).trim();
    if (!ref.startsWith('refs/tags/')) {
      continue;
    }
    final tag = ref.substring('refs/tags/'.length);
    if (!tag.endsWith('^{}')) {
      tags.add(tag);
    }
  }
  return tags;
}

Map<String, dynamic> _ghJson(Directory root, List<String> arguments) {
  final output = _run(['gh', ...arguments], workingDirectory: root.path);
  final decoded = jsonDecode(output);
  if (decoded is! Map<String, dynamic>) {
    throw ReleaseException('Unexpected gh output.');
  }
  return decoded;
}

String _run(List<String> command, {required String workingDirectory}) {
  final result = Process.runSync(
    command.first,
    command.sublist(1),
    workingDirectory: workingDirectory,
  );
  if (result.exitCode != 0) {
    final error = (result.stderr as String).trim();
    throw ReleaseException(
      'Command failed (${command.join(' ')}): '
      '${error.isEmpty ? 'exit code ${result.exitCode}' : error}',
    );
  }
  return result.stdout as String;
}

int runRelease(List<String> arguments) {
  if (arguments.isEmpty) {
    stdout.write(usage);
    return 2;
  }
  if (arguments.first == 'help' ||
      arguments.first == '--help' ||
      arguments.first == '-h') {
    stdout.write(usage);
    return 0;
  }
  if (arguments.contains('--help') || arguments.contains('-h')) {
    stdout.write(usage);
    return 0;
  }

  final command = arguments.first;
  final commandArguments = arguments.sublist(1);
  switch (command) {
    case 'next':
      return _runNext(commandArguments);
    case 'prepare':
      return _runPrepare(commandArguments);
    case 'verify':
      return _runVerify(commandArguments);
    case 'tag':
      return _runTag(commandArguments);
    default:
      throw UsageException('Unknown command "$command".');
  }
}

int _runNext(List<String> arguments) {
  final flags = _parseFlags(
    arguments,
    command: 'next',
    values: {'kind', 'date', 'root'},
    switches: {'json'},
  );
  final kind = ReleaseKind.parse(_required(flags, 'kind', 'next'));
  final plan = computeNextRelease(
    date: _date(flags),
    tags: readLocalTags(_root(flags)),
  );
  if (flags.containsKey('json')) {
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert(plan.toJson(kind)),
    );
  } else {
    stdout.writeln(plan.nextFor(kind).name);
  }
  return 0;
}

int _runPrepare(List<String> arguments) {
  final flags = _parseFlags(
    arguments,
    command: 'prepare',
    values: {'kind', 'version', 'date', 'changelog', 'root'},
    switches: {'no-changelog'},
  );
  final result = prepareRelease(
    root: _root(flags),
    kind: ReleaseKind.parse(_required(flags, 'kind', 'prepare')),
    version: _required(flags, 'version', 'prepare'),
    date: _date(flags),
    changelogPath: flags['changelog'],
    noChangelog: flags.containsKey('no-changelog'),
  );

  stdout.writeln('Prepared ${result.version.name}.');
  for (final file in result.updatedFiles) {
    stdout.writeln('Updated $file.');
  }
  if (result.updatedFiles.any(
    (file) => file.startsWith('assets/l10n/changelog_'),
  )) {
    stdout.writeln(
      'Appended changelog entry to: ${result.changelogLocales.join(', ')}.',
    );
  }
  if (result.updatedFiles.isEmpty) {
    stdout.writeln('Nothing changed.');
  }
  return 0;
}

int _runVerify(List<String> arguments) {
  final flags = _parseFlags(
    arguments,
    command: 'verify',
    values: {'tag', 'root'},
  );
  final result = verifyRelease(
    root: _root(flags),
    tag: _required(flags, 'tag', 'verify'),
  );
  stdout.writeln(
    'Verified tag ${result.version.name}: pubspec.yaml matches and '
    '${result.locales.length} changelog locale(s) are consistent.',
  );
  return 0;
}

int _runTag(List<String> arguments) {
  final flags = _parseFlags(
    arguments,
    command: 'tag',
    values: {'tag', 'pr', 'root'},
  );
  int? pr;
  final prValue = flags['pr'];
  if (prValue != null) {
    pr = int.tryParse(prValue);
    if (pr == null || pr < 1) {
      throw ReleaseException('--pr must be a positive number.');
    }
  }
  final result = tagRelease(
    root: _root(flags),
    tag: _required(flags, 'tag', 'tag'),
    pr: pr,
  );
  stdout.writeln(
    'Pushed tag ${result.tag} at ${result.commit} (PR #${result.pr}).',
  );
  return 0;
}

Directory _root(Map<String, String> flags) {
  final path = flags['root'] ?? Directory.current.path;
  final directory = Directory(path).absolute;
  if (!directory.existsSync()) {
    throw ReleaseException('Directory $path does not exist.');
  }
  return directory;
}

DateTime _date(Map<String, String> flags) {
  final value = flags['date'];
  return value == null ? DateTime.now() : parseReleaseDate(value);
}

String _required(Map<String, String> flags, String name, String command) {
  final value = flags[name];
  if (value == null) {
    throw UsageException('Missing --$name for $command.');
  }
  return value;
}

Map<String, String> _parseFlags(
  List<String> arguments, {
  required String command,
  required Set<String> values,
  Set<String> switches = const {},
}) {
  final flags = <String, String>{};
  var index = 0;
  while (index < arguments.length) {
    final argument = arguments[index];
    if (!argument.startsWith('--')) {
      throw UsageException('Unexpected argument "$argument" for $command.');
    }

    var name = argument.substring(2);
    String? value;
    final equals = name.indexOf('=');
    if (equals >= 0) {
      value = name.substring(equals + 1);
      name = name.substring(0, equals);
    }
    if (flags.containsKey(name)) {
      throw UsageException('Duplicate option --$name.');
    }

    if (switches.contains(name)) {
      if (value != null) {
        throw UsageException('Option --$name does not take a value.');
      }
      flags[name] = 'true';
    } else if (values.contains(name)) {
      if (value == null) {
        index++;
        if (index >= arguments.length) {
          throw UsageException('Option --$name needs a value.');
        }
        value = arguments[index];
      }
      if (value.isEmpty) {
        throw UsageException('Option --$name needs a value.');
      }
      flags[name] = value;
    } else {
      throw UsageException('Unknown option --$name for $command.');
    }
    index++;
  }
  return flags;
}

void main(List<String> arguments) {
  try {
    exitCode = runRelease(arguments);
  } on UsageException catch (error) {
    stderr.writeln('error: ${error.message}');
    stderr.write(usage);
    exitCode = 2;
  } on ReleaseException catch (error) {
    stderr.writeln('error: ${error.message}');
    exitCode = 1;
  }
}
