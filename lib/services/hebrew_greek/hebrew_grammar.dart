library;

String? parseHebrewGrammar(String code) {
  final trimmed = code.trim();
  if (trimmed.isEmpty) return null;

  final parts = trimmed.split('-');
  final head = _heads[parts.first];

  // A bare pronominal suffix, e.g. "3ms".
  if (head == null) {
    return _describeInflection(parts.first);
  }

  final descriptors = <String>[];
  for (final part in parts.skip(1)) {
    final descriptor = _describeFeature(part);
    if (descriptor == null) return null;
    descriptors.add(descriptor);
  }

  if (descriptors.isEmpty) return head;
  return '$head: ${descriptors.join(', ')}';
}

/// Expands one `-`-separated feature token, or returns `null` if unknown.
String? _describeFeature(String token) {
  final prefix = _prefixes[token];
  if (prefix != null) return prefix;

  final stem = _stems[token];
  if (stem != null) return stem;

  final conjugation = _conjugations[token];
  if (conjugation != null) return conjugation;

  final feature = _featureLabels[token];
  if (feature != null) return feature;

  return _describeInflection(token);
}

final _personPattern = RegExp(r'^([123])([mfc])([sp])(e?)(2?)$');
final _inflectionPattern = RegExp(r'^(g|o)?([mfc])([spdb]?)([cd])?$');

/// Expands a person/gender/number suffix (e.g. `3ms`) or a
/// gender/number/state ending (e.g. `msc`), or returns `null`.
String? _describeInflection(String token) {
  final person = _describePerson(token);
  if (person != null) return person;

  final match = _inflectionPattern.firstMatch(token);
  if (match == null) return null;

  final qualifier = match.group(1);
  final parts = <String>[
    if (qualifier != null) _featureLabels[qualifier]!,
    _genders[match.group(2)]!,
    if (match.group(3)!.isNotEmpty) _numbers[match.group(3)]!,
    if (match.group(4) != null) _states[match.group(4)]!,
  ];
  return parts.join(' ');
}

/// Expands a person/gender/number suffix (e.g. `3ms`), or returns `null`.
String? _describePerson(String token) {
  final match = _personPattern.firstMatch(token);
  if (match == null) return null;

  final buffer = StringBuffer()
    ..write(_persons[match.group(1)]!)
    ..write(' ')
    ..write(_genders[match.group(2)]!)
    ..write(' ')
    ..write(_numbers[match.group(3)]!);
  if (match.group(4) == 'e') buffer.write(', emphatic');
  if (match.group(5) == '2') buffer.write(' (suffix-type 2)');
  return buffer.toString();
}

const Map<String, String> _heads = {
  'N': 'noun',
  'V': 'verb',
  'Adj': 'adjective',
  'Adv': 'adverb',
  'Art': 'article',
  'Conj': 'conjunction',
  'Prep': 'preposition',
  'Pro': 'pronoun',
  'Number': 'number',
  'DirObj': 'direct-object marker',
  'DirObjM': 'direct-object marker with maqqēf',
  'Interjection': 'interjection',
  'Interrog': 'interrogative',
  // Rare particle markers found in the source data.
  'Pr': 'relative particle',
  'Pn': 'paragogic nun',
  'Pd': 'particle',
  'Pg': 'particle',
  'Pi': 'particle',
};

const Map<String, String> _prefixes = {
  'w': 'prefix waw ("and")',
  'b': 'prefix beth ("in, with, by")',
  'k': 'prefix kaf ("like, as")',
  'l': 'prefix lamed ("to, for")',
  'm': 'prefix mem ("from")',
  'r': 'relative particle',
};

const Map<String, String> _stems = {
  'Qal': 'Qal stem (simple active)',
  'Nifal': 'Nifal stem (simple passive)',
  'Piel': 'Piel stem (intensive active)',
  'Pual': 'Pual stem (intensive passive)',
  'Hifil': 'Hifil stem (causative active)',
  'Hofal': 'Hofal stem (causative passive)',
  'Hitpael': 'Hitpael stem (intensive reflexive)',
  'Nithpael': 'Nithpael stem (reflexive intensive passive)',
  'QalPass': 'Qal passive',
  'Poel': 'Poel stem (emphatic active)',
  'Tiftl': 'Tif‘al stem (rare reflexive/causative)',
};

const Map<String, String> _conjugations = {
  'Perf': 'perfect',
  'Imperf': 'imperfect',
  'Imperf.Jus': 'imperfect jussive',
  'Imperf.Cohort': 'imperfect cohortative',
  'Imperf.h': 'imperfect with paragogic ה',
  'ConsecImperf': 'consecutive imperfect',
  'ConjImperf': 'conjunctive (waw-) imperfect',
  'ConjImperf.Jus': 'conjunctive imperfect jussive',
  'ConjImperf.Cohort': 'conjunctive imperfect cohortative',
  'ConjImperf.h': 'conjunctive imperfect with paragogic ה',
  'ConjPerf': 'conjunctive (waw-) perfect',
  'Imp': 'imperative',
  'Inf': 'infinitive',
  'InfAbs': 'infinitive absolute',
  'Prtcpl': 'participle',
  'QalPassPrtcpl': 'Qal passive participle',
};

const Map<String, String> _featureLabels = {
  'g': 'gentilic',
  'o': 'ordinal',
  'proper': 'proper name',
  'NegPrt': 'negative particle',
};

const Map<String, String> _persons = {
  '1': 'first-person',
  '2': 'second-person',
  '3': 'third-person',
};

const Map<String, String> _genders = {
  'm': 'masculine',
  'f': 'feminine',
  'c': 'common',
};

const Map<String, String> _numbers = {
  's': 'singular',
  'p': 'plural',
  'd': 'dual',
  'b': 'both',
};

const Map<String, String> _states = {
  'c': 'construct',
  'd': 'determined',
};
