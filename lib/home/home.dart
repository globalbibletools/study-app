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

  @override
  void initState() {
    super.initState();
    manager.init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            OutlinedButton(
              child: ValueListenableBuilder(
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
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0),
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  ValueListenableBuilder(
                    valueListenable: manager.textNotifier,
                    builder: (context, text, child) {
                      _scrollController.jumpTo(0);
                      return Text(
                        text,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(fontFamily: 'sbl'),
                        textDirection:
                            manager.currentChapterIsRtl
                                ? TextDirection.rtl
                                : TextDirection.ltr,
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
