class BibleSchema {
  // Bible table
  static const String bibleTextTable = "bible";

  // BSB column names
  static const String colId = '_id';
  static const String colVerseId = 'verse';
  static const String colText = 'text';
  static const String colType = 'type'; // ms, mr, d, s1, s2, qa, r, v
  static const String colFormat = 'format'; // m, q1, q2, pmo, li1, li2, pc, qr
  static const String colFootnote = 'footnote';

  // SQL statements
  static const String createBibleTextTable =
      '''
  CREATE TABLE IF NOT EXISTS $bibleTextTable (
    $colId INTEGER PRIMARY KEY AUTOINCREMENT,
    $colVerseId INTEGER NOT NULL,
    $colText TEXT NOT NULL,
    $colType INTEGER NOT NULL,
    $colFormat INTEGER,
    $colFootnote TEXT
  )
  ''';

  static const String insertLine =
      '''
  INSERT INTO ${BibleSchema.bibleTextTable} (
    ${BibleSchema.colVerseId},
    ${BibleSchema.colText},
    ${BibleSchema.colType},
    ${BibleSchema.colFormat},
    ${BibleSchema.colFootnote}
  ) VALUES (?, ?, ?, ?, ?)
  ''';
}

// colType values
enum TextType {
  /// Verse
  v(0),

  /// Descriptive Title (Psalms "Of David")
  d(1),

  /// Cross Reference
  r(2),

  /// Section Heading Level 1
  s1(3),

  /// Section Heading Level 2
  s2(4),

  /// major section (Psalms)
  ms(5),

  /// major section range (Psalms)
  mr(6),

  /// Acrostic Heading (Psalm 119)
  qa(7);

  /// The integer value of the enum, used for database storage.
  final int id;
  const TextType(this.id);

  static TextType fromString(String value) {
    return TextType.values.firstWhere((type) => type.name == value);
  }

  static TextType fromInt(int value) {
    return TextType.values.firstWhere((type) => type.id == value);
  }
}

enum Format {
  m(0), // margin, no indentation
  q1(1), // poetry indentation level 1
  q2(2), // poetry indentation level 2
  pmo(3), // Embedded text opening
  li1(4), // list item level 1
  li2(5), // list item level 2
  pc(6), // centered
  qr(7); // right aligned

  final int id;
  const Format(this.id);

  static Format fromString(String value) {
    return Format.values.firstWhere((format) => format.name == value);
  }

  static Format fromInt(int value) {
    return Format.values.firstWhere((format) => format.id == value);
  }
}
