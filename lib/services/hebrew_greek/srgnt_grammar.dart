library;

final RegExp _srgntPattern = RegExp(
  r'^[NVAESRCDPTI][IMSONP.][PIFAELU.][AMP.][123.][NVAGD.][MFN.][SP.]$',
);

String? parseSrgntGrammar(String code) {
  if (!_srgntPattern.hasMatch(code)) return null;

  final role = _roles[code[0]];
  if (role == null) return null;

  final descriptors = <String>[];
  _add(descriptors, _tenses[code[2]]);
  _add(descriptors, _moods[code[1]]);
  _add(descriptors, _voices[code[3]]);
  _add(descriptors, _persons[code[4]]);
  _add(descriptors, _cases[code[5]]);
  _add(descriptors, _genders[code[6]]);
  _add(descriptors, _numbers[code[7]]);

  if (descriptors.isEmpty) return role;
  return '$role: ${descriptors.join(' ')}';
}

void _add(List<String> list, String? value) {
  if (value != null) list.add(value);
}

const Map<String, String> _roles = {
  'N': 'noun',
  'V': 'verb',
  'A': 'adjective',
  'S': 'substantive',
  'E': 'article',
  'R': 'pronoun',
  'C': 'conjunction',
  'D': 'adverb',
  'P': 'preposition',
  'T': 'particle',
  'I': 'interjection',
};

const Map<String, String> _moods = {
  'I': 'indicative',
  'M': 'imperative',
  'S': 'subjunctive',
  'O': 'optative',
  'N': 'infinitive',
  'P': 'participle',
};

const Map<String, String> _tenses = {
  'P': 'present',
  'I': 'imperfect',
  'F': 'future',
  'A': 'aorist',
  'E': 'perfect',
  'L': 'pluperfect',
  /// `U` is an anomaly in the source data (a single occurrence at Hebrews 8:11,
  /// εἰδήσουσίν, which is future) and is treated as future.
  'U': 'future',
};

const Map<String, String> _voices = {
  'A': 'active',
  'M': 'middle',
  'P': 'passive',
};

const Map<String, String> _persons = {
  '1': 'first-person',
  '2': 'second-person',
  '3': 'third-person',
};

const Map<String, String> _cases = {
  'N': 'nominative',
  'V': 'vocative',
  'A': 'accusative',
  'G': 'genitive',
  'D': 'dative',
};

const Map<String, String> _genders = {
  'M': 'masculine',
  'F': 'feminine',
  'N': 'neuter',
};

const Map<String, String> _numbers = {
  'S': 'singular',
  'P': 'plural',
};
