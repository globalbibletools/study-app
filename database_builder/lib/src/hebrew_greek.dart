import 'dart:convert';
import 'dart:io';

import 'package:database_builder/src/book_id.dart';

import 'database_helper.dart';

Future<void> populateHebrewGreekTable(DatabaseHelper dbHelper) async {
  int wordCount = 0;
  for (final fileName in bookFileNames) {
    final file = File('../../data/hbo+grc/$fileName');
    final jsonData = await file.readAsString();
    print('Processing $fileName');
    final words = extractWords(jsonData);
    print('words: ${words.length}');
    wordCount += words.length;
    dbHelper.addHebrewGreekWords(words);
  }
  print('Total Hebrew/Greek words: $wordCount');
}

List<HebrewGreekWord> extractWords(String jsonString) {
  final Map<String, dynamic> data = jsonDecode(jsonString);
  final List<dynamic> chapters = data['chapters'];

  final List<HebrewGreekWord> words = [];

  for (var chapter in chapters) {
    final List<dynamic> verses = chapter['verses'];
    for (var verse in verses) {
      final List<dynamic> wordList = verse['words'];
      for (var word in wordList) {
        words.add(HebrewGreekWord.fromJson(word));
      }
    }
  }

  return words;
}
