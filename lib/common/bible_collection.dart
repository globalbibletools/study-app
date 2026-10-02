import 'package:flutter/widgets.dart';
import 'package:gbt/l10n/app_localizations.dart';

class BibleCollection {
  final int id;
  final String name;
  final List<int> books;

  BibleCollection(this.id, this.name, this.books);

  @override
  String toString() => name;
}

class BibleCollections {
  static final List<BibleCollection> collections = [
    BibleCollection(1, "Whole Bible", _wholeBibleCollection),
    BibleCollection(2, "Old Testament", _oldTestamentBibleCollection),
    BibleCollection(3, "New Testament", _newTestamentBibleCollection),
    BibleCollection(4, "Torah", _torahBibleCollection),
    BibleCollection(5, "Prophets", _prophetsBibleCollection),
    BibleCollection(6, "Writings", _writingsBibleCollection),
    BibleCollection(7, "Gospels", _gospelsBibleCollection),
    BibleCollection(8, "Pauline Epistles", _paulineEpistlesBibleCollection),
    BibleCollection(9, "Psalms", _psalmsBibleCollection),
  ];

  static BibleCollection fromId(int id) {
    return collections[id - 1];
  }

  static String localizedName(
    BuildContext context,
    BibleCollection collection,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return switch (collection.id) {
      1 => l10n.wholeBible,
      2 => l10n.oldTestament,
      3 => l10n.newTestament,
      4 => l10n.torah,
      5 => l10n.prophets,
      6 => l10n.writings,
      7 => l10n.gospels,
      8 => l10n.paulineEpistles,
      9 => l10n.bookPsalms,
      _ => collection.name,
    };
  }

  static final List<int> _oldTestamentBibleCollection = [
    for (int i = 1; i <= 39; i++) i,
  ];

  static final List<int> _newTestamentBibleCollection = [
    for (int i = 40; i <= 66; i++) i,
  ];

  static final List<int> _wholeBibleCollection = [
    for (int i = 1; i <= 66; i++) i,
  ];

  static final List<int> _torahBibleCollection = [
    1, // Genesis
    2, // Exodus
    3, // Leviticus
    4, // Numbers
    5, // Deuteronomy
  ];

  static final List<int> _prophetsBibleCollection = [
    6, // Joshua
    7, // Judges
    9, // 1 Samuel
    10, // 2 Samuel
    11, // 1 Kings
    12, // 2 Kings
    23, // Isaiah
    24, // Jeremiah
    26, // Ezekiel
    28, // Hosea
    29, // Joel
    30, // Amos
    31, // Obadiah
    32, // Jonah
    33, // Micah
    34, // Nahum
    35, // Habakkuk
    36, // Zephaniah
    37, // Haggai
    38, // Zechariah
    39, // Malachi
  ];

  static final List<int> _writingsBibleCollection = [
    19, // Psalms
    20, // Proverbs
    18, // Job
    22, // Song of Solomon
    21, // Ecclesiastes
    25, // Lamentations
    17, // Esther
    27, // Daniel
    15, // Ezra
    16, // Nehemiah
    13, // 1 Chronicles
    14, // 2 Chronicles
  ];

  static final List<int> _gospelsBibleCollection = [
    40, // Matthew
    41, // Mark
    42, // Luke
    43, // John
  ];

  static final List<int> _paulineEpistlesBibleCollection = [
    45, // Romans
    46, // 1 Corinthians
    47, // 2 Corinthians
    48, // Galatians
    49, // Ephesians
    50, // Philippians
    51, // Colossians
    52, // 1 Thessalonians
    53, // 2 Thessalonians
    54, // 1 Timothy
    55, // 2 Timothy
    56, // Titus
    57, // Philemon
  ];

  static final List<int> _psalmsBibleCollection = [
    19, // Psalms
  ];
}
