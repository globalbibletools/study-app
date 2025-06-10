import 'package:database_builder/database_builder.dart';
import 'package:flutter/material.dart';

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
  OverlayEntry? _overlayEntry;
  List<GlobalKey> _wordKeys = [];

  @override
  void initState() {
    super.initState();
    manager.init();
    manager.onTextUpdated = _scrollToTop;
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _removeGlossOverlay();
    _scrollController.dispose();
    super.dispose();
  }

  void _showGlossOverlay(
    BuildContext context,
    HebrewGreekWord word,
    GlobalKey key,
  ) {
    _removeGlossOverlay();

    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);

    final overlayTop = position.dy - 28.0;
    final overlayLeft = position.dx;

    final theme = Theme.of(context);

    _overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            top: overlayTop,
            left: overlayLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4.0,
              ),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4.0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(word.lemma, style: theme.textTheme.bodyMedium),
            ),
          ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeGlossOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
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
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(child: Text('Drawer Header')),
            ListTile(
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: GestureDetector(
        onTap: _removeGlossOverlay,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0),
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    ValueListenableBuilder(
                      valueListenable: manager.textNotifier,
                      builder: (context, words, child) {
                        _wordKeys = List.generate(
                          words.length,
                          (_) => GlobalKey(),
                        );
                        final textWidgets = _createTextWidgets(words);
                        return Wrap(
                          spacing: 5,
                          textDirection:
                              manager.currentChapterIsRtl
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                          children: textWidgets,
                        );
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
      ),
    );
  }

  List<Widget> _createTextWidgets(List<HebrewGreekWord> words) {
    return List.generate(words.length, (index) {
      final word = words[index];
      final key = _wordKeys[index];
      return GestureDetector(
        key: key,
        onTap: () => _showGlossOverlay(context, word, key),
        child: Text(
          word.text,
          style: const TextStyle(fontFamily: 'sbl', fontSize: 20),
        ),
      );
    });
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
