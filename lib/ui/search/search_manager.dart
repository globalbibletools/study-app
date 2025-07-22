import 'package:flutter/foundation.dart';
import 'package:studyapp/services/hebrew_greek/database.dart';
import 'package:studyapp/services/service_locator.dart';

class SearchPageManager {
  final resultsNotifier = ValueNotifier<List<String>>([]);
  final _hebrewGreekDb = getIt<HebrewGreekDatabase>();

  Future<void> search(String prefix) async {
    print('searching for $prefix');
    final results = await _hebrewGreekDb.getWordsStartingWith(prefix);
    print('results: $results');
    resultsNotifier.value = results;
  }
}
