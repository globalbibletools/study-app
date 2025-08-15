import 'package:database_builder/database_builder.dart';
import 'package:flutter/widgets.dart';
import 'package:studyapp/l10n/book_names.dart';
// import 'package:studyapp/services/bible/bible_database.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/services/user_settings.dart';

typedef TextParagraph = List<(TextSpan, TextType, Format?)>;

class HomeManager {
  final currentBookNotifier = ValueNotifier<String>('');
  final currentChapterNotifier = ValueNotifier<int>(1);
  final isSinglePanelNotifier = ValueNotifier(true);
  final textParagraphNotifier = ValueNotifier<TextParagraph>([]);

  // final _bibleDb = getIt<BibleDatabase>();
  final _settings = getIt<UserSettings>();

  Future<void> init(BuildContext context) async {
    final (bookId, chapter) = _settings.currentBookChapter;
    _updateUiForBook(context, bookId, chapter);
  }

  void _updateUiForBook(BuildContext context, int bookId, int chapter) {
    currentBookNotifier.value = bookNameFromId(context, bookId);
    currentChapterNotifier.value = chapter;
  }

  (int, int) getInitialBookAndChapter() {
    return _settings.currentBookChapter;
  }

  void togglePanelState() {
    isSinglePanelNotifier.value = !isSinglePanelNotifier.value;
  }

  // Future<void> downloadBible() async {
  //   await _downloadService.download(
  //     url: 'https://assets.globalbibletools.com/bibles/eng_bsb/eng_bsb.db.zip',
  //     downloadTo: 'bibles',
  //     onProgress: (progress) {
  //       print('progress: ${progress.toStringAsFixed(2)}');
  //       // goes from 0 to 1
  //       downloadProgressNotifier.value = progress;
  //     },
  //   );
  //   print('Download is done');
  //   bibleExists = true;
  //   downloadProgressNotifier.value = null;
  // }

  Future<void> requestText({
    required Color textColor,
    required Color footnoteColor,
  }) async {
    //   final content = await _bibleDb.getChapter(
    //     _currentBookId,
    //     currentChapterNotifier.value,
    //   );
    //   final formattedContent = formatVerses(
    //     verseLines: content,
    //     baseFontSize: 20,
    //     textColor: textColor,
    //     verseNumberColor: footnoteColor,
    //     showSectionTitles: false,
    //   );
    //   textParagraphNotifier.value = formattedContent;
  }
}
