import 'dart:async';
import 'package:flutter/gestures.dart';
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

  // Pinch to zoom font scaling
  static const double _baseFontSize = 20.0;
  double _baseScale = 1.0;
  double _gestureScale = 1.0;
  bool get _isScaling => _gestureScale != 1.0;

  @override
  void initState() {
    super.initState();
    manager.init();
    manager.onTextUpdated = _scrollToTop;
    _baseScale = manager.getFontScale();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_estimatedPopupHeight());
    }
  }

  double _estimatedPopupHeight() {
    final popupFontSize = _baseFontSize * _baseScale;
    return popupFontSize * 2;
  }

  void _ensurePopupIsVisible(Rect popupRect) {
    if (!mounted || !_scrollController.hasClients) return;

    final topSafeArea = MediaQuery.of(context).padding.top;
    final appBarHeight = AppBar().preferredSize.height;
    final topBarHeight = topSafeArea + appBarHeight;

    if (popupRect.top < topBarHeight) {
      // Amount the popup is obscured by the app bar and safe area.
      final scrollAmount = topBarHeight - popupRect.top;
      // We scroll down, which means decreasing the scroll offset.
      final newOffset = (_scrollController.offset - scrollAmount).clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );

      // Scroll a little bit more to have some padding.
      final finalOffset = (newOffset - 10.0).clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );

      _scrollController.animateTo(
        finalOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
          RawGestureDetector(
            gestures: {
              CustomScaleGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    CustomScaleGestureRecognizer
                  >(() => CustomScaleGestureRecognizer(), (
                    CustomScaleGestureRecognizer instance,
                  ) {
                    instance
                      ..onStart = (details) {
                        _gestureScale = 1.0;
                      }
                      ..onUpdate = (details) {
                        setState(() {
                          _gestureScale = details.scale.clamp(0.5, 3.0);
                        });
                      }
                      ..onEnd = (details) {
                        setState(() {
                          _baseScale = (_baseScale * _gestureScale).clamp(
                            0.5,
                            3.0,
                          );
                          _gestureScale = 1.0;
                          manager.saveFontScale(_baseScale);
                        });
                      };
                  }),
            },
            behavior: HitTestBehavior.translucent,
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                child: Transform.scale(
                  scale: _isScaling ? _gestureScale : 1.0,
                  alignment: Alignment.topCenter,
                  child: Column(
                    children: [
                      SizedBox(height: _estimatedPopupHeight()),
                      ValueListenableBuilder(
                        valueListenable: manager.textNotifier,
                        builder: (context, words, child) {
                          return HebrewGreekText(
                            words: words,
                            textDirection:
                                manager.currentChapterIsRtl
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                            textStyle: TextStyle(
                              fontFamily: 'sbl',
                              fontSize: _baseFontSize * _baseScale,
                            ),
                            verseNumberStyle: TextStyle(
                              fontFamily: 'sbl',
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: _baseFontSize * _baseScale * 0.7,
                            ),
                            popupBackgroundColor: Colors.amber,
                            popupTextStyle: TextStyle(
                              fontFamily: 'sbl',
                              fontSize: _baseFontSize * _baseScale,
                            ),
                            popupWordProvider: (wordId) {
                              return manager.getPopupTextForId(wordId);
                            },
                            onPopupShown: _ensurePopupIsVisible,
                          );
                        },
                      ),
                      const SizedBox(height: 300.0),
                    ],
                  ),
                ),
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
}

/// Custom recognizer that listens only for scaling (pinch) gestures
class CustomScaleGestureRecognizer extends ScaleGestureRecognizer {
  CustomScaleGestureRecognizer({super.debugOwner});

  @override
  void rejectGesture(int pointer) {
    // Don't reject just because another gesture (e.g., scroll) won
    acceptGesture(pointer);
  }
}
