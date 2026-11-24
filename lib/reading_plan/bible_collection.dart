/// Preset sets of books a reading plan can cover.
///
/// The ordered book list on a reading plan is the source of truth; a plan's
/// collection is derived by comparing that list against these presets. A list
/// that matches no preset is [custom], whose [books] are empty because its
/// contents live only in the edit view model until the plan is saved.
enum BibleCollection {
  wholeBible(books: [..._oldTestament, ..._newTestament]),
  oldTestament(books: _oldTestament),
  newTestament(books: _newTestament),
  torah(books: _torah),
  prophets(books: _prophets),
  writings(books: _writings),
  gospels(books: _gospels),
  paulineEpistles(books: _paulineEpistles),
  psalms(books: _psalms),
  custom(books: []);

  const BibleCollection({required this.books});

  /// The books in this collection, in canonical reading order.
  final List<int> books;

  /// The full canonical book list, Genesis through Revelation.
  static const List<int> allBooks = [..._oldTestament, ..._newTestament];

  /// Returns the preset whose book list exactly equals [bookIds], or null.
  ///
  /// [custom] is never returned: it has no predefined books.
  static BibleCollection? matchingCollection(List<int> bookIds) {
    for (final collection in values) {
      if (collection == custom) continue;
      if (_sameBooks(collection.books, bookIds)) return collection;
    }
    return null;
  }

  static bool _sameBooks(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

const List<int> _oldTestament = [
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  11,
  12,
  13,
  14,
  15,
  16,
  17,
  18,
  19,
  20,
  21,
  22,
  23,
  24,
  25,
  26,
  27,
  28,
  29,
  30,
  31,
  32,
  33,
  34,
  35,
  36,
  37,
  38,
  39,
];

const List<int> _newTestament = [
  40,
  41,
  42,
  43,
  44,
  45,
  46,
  47,
  48,
  49,
  50,
  51,
  52,
  53,
  54,
  55,
  56,
  57,
  58,
  59,
  60,
  61,
  62,
  63,
  64,
  65,
  66,
];

const List<int> _torah = [
  1, // Genesis
  2, // Exodus
  3, // Leviticus
  4, // Numbers
  5, // Deuteronomy
];

const List<int> _prophets = [
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

const List<int> _writings = [
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

const List<int> _gospels = [
  40, // Matthew
  41, // Mark
  42, // Luke
  43, // John
];

const List<int> _paulineEpistles = [
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

const List<int> _psalms = [
  19, // Psalms
];
