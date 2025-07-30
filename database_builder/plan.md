# Plan

## Overview

We want to create a builder that will take the json data from these two files:

- lib/src/lexicon/data/hebrew/UBSHebrewDic-v0.9.1-en.JSON
- lib/src/lexicon/data/greek/UBSGreekNTDic-v1.1-en.JSON

And extract the appropriate data into the following database structure:

```
CREATE TABLE lemmas (
    main_id INTEGER PRIMARY KEY,
    lemma_text TEXT NOT NULL
);

CREATE TABLE strongs_mapping (
    strong_code TEXT NOT NULL,
    lemma_id INTEGER NOT NULL,
    PRIMARY KEY (strong_code, lemma_id)
);

CREATE TABLE grammar_types (
    id INTEGER PRIMARY KEY,
    grammar_text TEXT NOT NULL UNIQUE
);

CREATE TABLE meanings (
    lex_id TEXT PRIMARY KEY,
    lemma_id INTEGER NOT NULL,
    grammar_id INTEGER NOT NULL,
    lex_entry_code TEXT,
    definition_short TEXT,
    comments TEXT,
    glosses TEXT NOT NULL,
    FOREIGN KEY(lemma_id) REFERENCES lemmas(main_id),
    FOREIGN KEY(grammar_id) REFERENCES grammar_types(id)
);
```

The first step is to fill out the LexiconSchema Dart class in `lib/src/lexicon/schema.dart`. You can use `lib/src/hebrew_greek/schema.dart` as an example.

The second step is to create a data extraction method for the JSON files. Then fill out `lib/src/lexicon/database.dart`. You can use `lib/src/hebrew_greek/database.dart` as an example.

You can also refer to this code, but it will probably have to be modified:

```
import 'dart:io';
import 'dart:convert';
import 'package:sqlite3/sqlite3.dart';

void main() async {
  final stopwatch = Stopwatch()..start();

  // --- Configuration ---
  const jsonInputPath = 'lexicon.json';
  const sqliteOutputPath = 'lexicon.db';

  // --- Setup ---
  print('Starting database creation...');
  final inputFile = File(jsonInputPath);
  if (!await inputFile.exists()) {
    print('Error: $jsonInputPath not found.');
    return;
  }

  // Delete old database file if it exists to start fresh
  final outputFile = File(sqliteOutputPath);
  if (await outputFile.exists()) {
    await outputFile.delete();
  }

  final db = sqlite3.open(sqliteOutputPath);
  final jsonData = jsonDecode(await inputFile.readAsString());

  // --- Step 1: Create Tables ---
  createTables(db);
  print('Tables created.');

  // --- Step 2: Pre-populate grammar_types and create in-memory map ---
  final grammarMap = populateGrammarTypes(db, jsonData);
  print('Grammar types populated: ${grammarMap.length} unique terms found.');

  // --- Step 3: Main Data Ingestion (in a single transaction for speed) ---
  print('Starting main data ingestion...');
  db.execute('BEGIN TRANSACTION');

  for (final lemmaObject in jsonData) {
    // Parse main_id to integer
    final mainId = int.tryParse(lemmaObject['MainId'] ?? '0') ?? 0;
    if (mainId == 0) continue; // Skip if ID is invalid

    // Insert into lemmas table
    db.prepare('INSERT INTO lemmas (main_id, lemma_text) VALUES (?, ?)')
      ..execute([mainId, lemmaObject['Lemma']]);

    // Insert into strongs_mapping table
    final strongsStmt = db.prepare('INSERT INTO strongs_mapping (strong_code, lemma_id) VALUES (?, ?)');
    for (final strongCode in lemmaObject['StrongCodes']) {
      strongsStmt.execute([strongCode, mainId]);
    }
    strongsStmt.dispose();

    // Insert into meanings table
    final meaningsStmt = db.prepare('''
      INSERT INTO meanings (lex_id, lemma_id, grammar_id, lex_entry_code, definition_short, comments, glosses)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    ''');
    for (final baseForm in lemmaObject['BaseForms']) {
      final grammarText = (baseForm['PartsOfSpeech'] as List).first ?? 'unknown';
      final grammarId = grammarMap[grammarText];
      if (grammarId == null) continue; // Skip if grammar not found

      for (final meaning in baseForm['LEXMeanings']) {
        final sense = (meaning['LEXSenses'] as List).first;
        final glosses = jsonEncode(sense['Glosses']); // Store glosses as a JSON string

        meaningsStmt.execute([
          meaning['LEXID'],
          mainId,
          grammarId,
          meaning['LEXEntryCode'],
          sense['DefinitionShort'],
          sense['Comments'],
          glosses,
        ]);
      }
    }
    meaningsStmt.dispose();
  }

  db.execute('COMMIT');
  print('Main data ingested.');
  
  // --- Step 4: Create Indexes ---
  createIndexes(db);
  print('Indexes created.');


  // --- Cleanup ---
  db.dispose();
  stopwatch.stop();
  print('✅ Success! Database "$sqliteOutputPath" created in ${stopwatch.elapsed.inSeconds} seconds.');
}

void createTables(Database db) {
  db.execute('''
    CREATE TABLE lemmas (
        main_id INTEGER PRIMARY KEY,
        lemma_text TEXT NOT NULL
    );
  ''');
  db.execute('''
    CREATE TABLE strongs_mapping (
        strong_code TEXT NOT NULL,
        lemma_id INTEGER NOT NULL,
        PRIMARY KEY (strong_code, lemma_id),
        FOREIGN KEY(lemma_id) REFERENCES lemmas(main_id)
    );
  ''');
  db.execute('''
    CREATE TABLE grammar_types (
        id INTEGER PRIMARY KEY,
        grammar_text TEXT NOT NULL UNIQUE
    );
  ''');
  db.execute('''
    CREATE TABLE meanings (
        lex_id TEXT PRIMARY KEY,
        lemma_id INTEGER NOT NULL,
        grammar_id INTEGER NOT NULL,
        lex_entry_code TEXT,
        definition_short TEXT,
        comments TEXT,
        glosses TEXT NOT NULL,
        FOREIGN KEY(lemma_id) REFERENCES lemmas(main_id),
        FOREIGN KEY(grammar_id) REFERENCES grammar_types(id)
    );
  ''');
}

Map<String, int> populateGrammarTypes(Database db, dynamic jsonData) {
  final grammarSet = <String>{};
  for (final lemma in jsonData) {
    for (final baseForm in lemma['BaseForms']) {
      final grammar = (baseForm['PartsOfSpeech'] as List).first;
      if (grammar != null) {
        grammarSet.add(grammar);
      }
    }
  }

  final grammarMap = <String, int>{};
  final stmt = db.prepare('INSERT INTO grammar_types (grammar_text) VALUES (?)');
  for (final grammarText in grammarSet) {
    stmt.execute([grammarText]);
    grammarMap[grammarText] = db.lastInsertRowId;
  }
  stmt.dispose();
  return grammarMap;
}

void createIndexes(Database db) {
  db.execute('CREATE INDEX idx_strongs_mapping_strong_code ON strongs_mapping(strong_code);');
  db.execute('CREATE INDEX idx_meanings_lemma_id ON meanings(lemma_id);');
}
```