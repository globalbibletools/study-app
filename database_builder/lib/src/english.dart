import 'dart:convert';
import 'dart:io';

import 'package:database_builder/src/book_id.dart';

import 'database_helper.dart';

Future<void> populateEnglishTable(DatabaseHelper dbHelper) async {
  int glossCount = 0;
  for (final fileName in bookFileNames) {
    final file = File('../../data/eng/$fileName');
    final jsonData = await file.readAsString();
    print('Processing $fileName');
    final glosses = extractWords(jsonData);
    print('glosses: ${glosses.length}');
    glossCount += glosses.length;
    dbHelper.addGlosses(glosses);
  }
  print('Total English glosses: $glossCount');
}

List<Gloss> extractWords(String jsonString) {
  final Map<String, dynamic> data = jsonDecode(jsonString);
  final List<dynamic> chapters = data['chapters'];

  final List<Gloss> words = [];

  for (var chapter in chapters) {
    final List<dynamic> verses = chapter['verses'];
    for (var verse in verses) {
      final List<dynamic> wordList = verse['words'];
      for (var word in wordList) {
        words.add(Gloss.fromJson(word));
      }
    }
  }

  return words;
}
