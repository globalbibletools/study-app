import 'package:database_builder/database_builder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/common/word.dart';
import 'package:gbt/services/bible/bible_database.dart';
import 'package:gbt/services/hebrew_greek/database.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/ui/common/resource_language_text_direction.dart';
import 'package:gbt/ui/common/verse_list_item.dart';
import 'package:gbt/ui/home/word_details_dialog/dialog_manager.dart';
import 'package:gbt/ui/home/word_details_dialog/similar_verses/similar_verses_page.dart';

class SimilarVerseManager {
  final _db = getIt<HebrewGreekDatabase>();
  final _settings = getIt<UserSettings>();
  final _resourceService = getIt<ResourceService>();

  final rootNotifier = ValueNotifier<String?>(null);
  final similarVersesNotifier = ValueNotifier<List<Reference>>([]);
  final parallelVersesRevisionNotifier = ValueNotifier<int>(0);

  final Map<String, BibleDatabase> _translationDbs = {};
  final Map<String, Map<Reference, String>> _parallelVerseCache = {};
  final Map<String, TextDirection> _translationDirections = {};

  Future<void> init(WordDetails word) async {
    rootNotifier.value = await _db.strongsCodeRoot(word.strongsCode);
    await search(word, SearchType.root);
  }

  Future<void> search(WordDetails word, SearchType searchType) async {
    List<Reference> references;
    if (searchType == SearchType.root) {
      references = await _db.allVersesForStrongsCode(word.strongsCode);
    } else {
      references = await _db.searchExactMatchNoPunctuation(word.word);
    }
    similarVersesNotifier.value = references;
    await reloadParallelVerses();
  }

  Future<void> reloadParallelVerses() async {
    final selectedBibles = _settings.occurrenceParallelBibles;

    // Close and remove databases no longer selected
    final removedBibles = _translationDbs.keys
        .where((id) => !selectedBibles.contains(id))
        .toList();
    for (final id in removedBibles) {
      await _translationDbs[id]?.close();
      _translationDbs.remove(id);
      _parallelVerseCache.remove(id);
      _translationDirections.remove(id);
    }

    final references = similarVersesNotifier.value;
    if (references.isEmpty) {
      parallelVersesRevisionNotifier.value++;
      return;
    }

    // Load verses for each selected bible
    for (final bibleId in selectedBibles) {
      try {
        if (!_translationDbs.containsKey(bibleId)) {
          if (await _resourceService.resourceExists(
            ResourceType.bible,
            bibleId,
          )) {
            final path = await _resourceService.getResourceLocalPath(
              ResourceType.bible,
              bibleId,
            );
            _translationDbs[bibleId] = await BibleDatabase.open(path);
          }
        }

        if (!_translationDirections.containsKey(bibleId)) {
          final language = await _resourceService.getLanguageForResource(
            ResourceType.bible,
            bibleId,
          );
          _translationDirections[bibleId] =
              language?.textDirection.toTextDirection ?? TextDirection.ltr;
        }

        final db = _translationDbs[bibleId];
        if (db != null) {
          final versesMap = await db.getVerses(references);
          _parallelVerseCache[bibleId] = versesMap;
        }
      } catch (e) {
        debugPrint('Error loading parallel verses for $bibleId: $e');
      }
    }

    parallelVersesRevisionNotifier.value++;
  }

  String _getBadge(String bibleId) {
    final parts = bibleId.split('_');
    if (parts.length > 1) {
      return parts.last.toUpperCase();
    }
    return bibleId.toUpperCase();
  }

  List<ParallelVerseData> getParallelVersesFor(Reference reference) {
    final selectedBibles = _settings.occurrenceParallelBibles;
    final result = <ParallelVerseData>[];

    for (final bibleId in selectedBibles) {
      final text = _parallelVerseCache[bibleId]?[reference];
      if (text != null && text.isNotEmpty) {
        result.add(
          ParallelVerseData(
            bibleId: bibleId,
            badge: _getBadge(bibleId),
            text: text,
            textDirection:
                _translationDirections[bibleId] ?? TextDirection.ltr,
          ),
        );
      }
    }

    return result;
  }

  Future<List<HebrewGreekWord>> getVerseWords(Reference reference) {
    return _db.wordsForVerse(reference, includeStrongs: true);
  }

  bool isWordHighlighted(
    HebrewGreekWord word,
    WordDetails pressedWord,
    SearchType searchType,
  ) {
    if (searchType == SearchType.exact) {
      return removePunctuation(word.text) ==
          removePunctuation(pressedWord.word);
    } else {
      return word.strongsCode == pressedWord.strongsCode;
    }
  }

  Future<TextSpan> getVerseContent(
    Reference reference,
    WordDetails word,
    SearchType searchType,
    Color highlightColor,
    double fontSize,
  ) async {
    final List<HebrewGreekWord> words = await getVerseWords(reference);
    return _formatVerse(words, word, searchType, highlightColor, fontSize);
  }

  static const maqaph = '־';

  TextSpan _formatVerse(
    List<HebrewGreekWord> words,
    WordDetails pressedWord,
    SearchType searchType,
    Color highlightColor,
    double fontSize,
  ) {
    final spans = <TextSpan>[];
    for (final word in words) {
      final color = isWordHighlighted(word, pressedWord, searchType)
          ? highlightColor
          : null;

      final text = word.text.endsWith(maqaph) ? word.text : '${word.text} ';
      spans.add(
        TextSpan(
          text: text,
          style: TextStyle(color: color, fontSize: fontSize),
        ),
      );
    }
    return TextSpan(children: spans);
  }

  void dispose() {
    for (final db in _translationDbs.values) {
      db.close();
    }
    _translationDbs.clear();
    _parallelVerseCache.clear();
    _translationDirections.clear();
    rootNotifier.dispose();
    similarVersesNotifier.dispose();
    parallelVersesRevisionNotifier.dispose();
  }
}
