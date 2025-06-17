import 'dart:async';
// import 'dart:math';

// import 'package:database_builder/database_builder.dart';
import 'package:flutter/material.dart';
import 'package:studyapp/home/hebrew_greek_text.dart';

import 'book_chooser.dart';
import 'chapter_chooser.dart';
import 'home_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final manager = HomeManager();
  final _scrollController = ScrollController();
  // OverlayEntry? _overlayEntry;
  // Timer? _glossTimer;
  // List<GlobalKey> _wordKeys = [];

  // static const double _baseFontSize = 20.0;
  // double _currentScale = 1.0;
  // double _previousScale = 1.0;

  @override
  void initState() {
    super.initState();
    manager.init();
    manager.onTextUpdated = _scrollToTop;
    // _currentScale = manager.getFontScale();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    // _removeGlossOverlay();
    _scrollController.dispose();
    super.dispose();
  }

  // void _showGlossOverlay(String word, GlobalKey key) {
  //   _removeGlossOverlay();

  //   final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
  //   if (renderBox == null) return;

  //   final size = renderBox.size;
  //   final position = renderBox.localToGlobal(Offset.zero);
  //   final fontSize = _baseFontSize * _currentScale * 0.8;

  //   final theme = Theme.of(context);

  //   // Measure the width of the popup text
  //   final textSpan = TextSpan(
  //     text: word,
  //     style: theme.textTheme.bodyMedium!.copyWith(fontSize: fontSize),
  //   );
  //   final textPainter = TextPainter(
  //     text: textSpan,
  //     textDirection: TextDirection.rtl,
  //   );
  //   textPainter.layout();

  //   const horizontalPadding = 8.0;
  //   const verticalPadding = 4.0;
  //   final popupWidth = textPainter.width + (horizontalPadding * 2);
  //   final screenSize = MediaQuery.sizeOf(context);
  //   double left = position.dx + size.width / 2 - popupWidth / 2;
  //   final verticalOffset = max(30, 30 * _currentScale);
  //   final top = position.dy - verticalOffset;

  //   // Adjust if going off screen
  //   const edgePadding = 8.0;
  //   if (left < 0) {
  //     left = edgePadding;
  //   } else if (left + popupWidth > screenSize.width) {
  //     left = screenSize.width - popupWidth - edgePadding;
  //   }

  //   _overlayEntry = OverlayEntry(
  //     builder:
  //         (context) => Positioned(
  //           top: top,
  //           left: left,
  //           child: Container(
  //             padding: const EdgeInsets.symmetric(
  //               horizontal: horizontalPadding,
  //               vertical: verticalPadding,
  //             ),
  //             decoration: BoxDecoration(
  //               color: theme.textTheme.bodyMedium!.color,
  //               borderRadius: BorderRadius.circular(4),
  //               boxShadow: [
  //                 BoxShadow(
  //                   color: Colors.black,
  //                   blurRadius: 4.0,
  //                   offset: Offset(0, 2),
  //                 ),
  //               ],
  //             ),
  //             child: Text(
  //               word,
  //               style: theme.textTheme.bodyMedium!.copyWith(
  //                 color: Colors.black87,
  //                 fontSize: fontSize,
  //               ),
  //             ),
  //           ),
  //         ),
  //   );
  //   Overlay.of(context).insert(_overlayEntry!);

  //   _glossTimer = Timer(const Duration(milliseconds: 3000), () {
  //     _removeGlossOverlay();
  //   });
  // }

  // void _removeGlossOverlay() {
  //   _glossTimer?.cancel();
  //   _overlayEntry?.remove();
  //   _overlayEntry = null;
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            OutlinedButton(
              child: ValueListenableBuilder<String>(
                valueListenable: manager.currentBookNotifier,
                builder: (context, value, child) {
                  return Text(value);
                },
              ),
              onPressed: () {
                // _removeGlossOverlay();
                _showBookChooserDialog();
              },
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              child: ValueListenableBuilder(
                valueListenable: manager.currentChapterNotifier,
                builder: (context, value, child) {
                  return Text('$value');
                },
              ),
              onPressed: () {
                // _removeGlossOverlay();
                manager.showChapterChooser();
              },
            ),
          ],
        ),
      ),
      // drawer: Drawer(
      //   child: ListView(
      //     padding: EdgeInsets.zero,
      //     children: [
      //       const DrawerHeader(child: Text('Drawer Header')),
      //       ListTile(
      //         title: const Text('Settings'),
      //         onTap: () {
      //           Navigator.pop(context);
      //         },
      //       ),
      //       ListTile(
      //         title: const Text('About'),
      //         onTap: () {
      //           Navigator.pop(context);
      //         },
      //       ),
      //     ],
      //   ),
      // ),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0),
              child: Column(
                children: [
                  ValueListenableBuilder(
                    valueListenable: manager.textNotifier,
                    builder: (context, words, child) {
                      return HebrewGreekText(
                        words: words,
                        textDirection:
                            manager.currentChapterIsRtl
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                      );
                      // _wordKeys = List.generate(
                      //   words.length,
                      //   (_) => GlobalKey(),
                      // );
                      // final textWidgets = _createTextWidgets(words);
                      // return Wrap(
                      //   textDirection:
                      //       manager.currentChapterIsRtl
                      //           ? TextDirection.rtl
                      //           : TextDirection.ltr,
                      //   children: textWidgets,
                      // );
                    },
                  ),
                  const SizedBox(height: 300.0),
                ],
              ),
            ),
          ),
          ValueListenableBuilder<int?>(
            valueListenable: manager.chapterCountNotifier,
            builder: (context, chapterCount, child) {
              if (chapterCount == null) {
                return const SizedBox();
              }
              return ChapterChooser(
                chapterCount: chapterCount,
                onChapterSelected: manager.onChapterSelected,
              );
            },
          ),
        ],
      ),
    );
  }

  // static const maqaph = '־';

  // List<Widget> _createTextWidgets(List<HebrewGreekWord> words) {
  //   final textWidgets = List.generate(words.length, (index) {
  //     final word = words[index];
  //     final verse = _extractVerse(word);
  //     final space = (word.text.endsWith(maqaph)) ? '' : ' ';
  //     final wordText =
  //         (verse == null) ? '${word.text}$space' : '$verse ${word.text}$space';
  //     final key = _wordKeys[index];
  //     return GestureDetector(
  //       key: key,
  //       onTap: () async {
  //         final gloss = await manager.lookupGlossForId(word.id);
  //         _showGlossOverlay(gloss, key);
  //       },
  //       child: Text(
  //         wordText,
  //         textDirection:
  //             manager.currentChapterIsRtl
  //                 ? TextDirection.rtl
  //                 : TextDirection.ltr,
  //         style: TextStyle(
  //           fontFamily: 'sbl',
  //           fontSize: _baseFontSize * _currentScale,
  //         ),
  //       ),
  //     );
  //   });
  //   return textWidgets;
  // }

  Future<void> _showBookChooserDialog() async {
    manager.chapterCountNotifier.value = null;
    final selectedIndex = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return const BookChooser();
      },
    );

    manager.onBookSelected(selectedIndex);
  }

  // int? _extractVerse(HebrewGreekWord word) {
  //   // last two digits are the word number
  //   final wordNumber = word.id % 100;
  //   if (wordNumber > 1) return null;
  //   // the next three digits are the verse number
  //   return (word.id ~/ 100) % 1000;
  // }
}
