import 'package:flutter/material.dart';
import 'package:studyapp/l10n/book_names.dart';
import 'package:studyapp/ui/home/audio/audio_manager.dart';
import 'package:studyapp/ui/home/audio/audio_player.dart';
import 'package:studyapp/ui/home/bible_panel/bible_panel.dart';
import 'package:studyapp/ui/home/appbar/drawer.dart';
import 'package:studyapp/ui/home/hebrew_greek_panel/panel.dart';

import 'appbar/appbar.dart';
import 'common/scroll_sync_controller.dart';
import 'home_manager.dart';

enum DownloadDialogChoice { useEnglish, download }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final manager = HomeManager();
  final syncController = ScrollSyncController();

  // "Panel" State: Triggers infinite scroll reset only when explicitly changed by User
  late int panelBookId;
  late int panelChapter;

  // "Display" State: Updates freely while scrolling or selecting
  late int displayBookId;
  late int displayChapter;
  int displayVerse = 1;

  @override
  void initState() {
    super.initState();

    final (initialBook, initialChapter) = manager.getInitialBookAndChapter();
    // Initialize both sets of state
    panelBookId = initialBook;
    panelChapter = initialChapter;

    displayBookId = initialBook;
    displayChapter = initialChapter;

    // Listen to scroll updates
    syncController.addListener(_onScrollUpdate);

    // audio syncing
    manager.setSyncController(syncController);
  }

  void _onScrollUpdate() {
    final newBook = syncController.bookId;
    final newChapter = syncController.chapter;

    if (newBook == null || newChapter == null) return;

    final newVerse = syncController.verse ?? displayVerse;

    final hasChanged =
        newBook != displayBookId ||
        newChapter != displayChapter ||
        newVerse != displayVerse;

    if (!hasChanged) return;

    if (newBook != displayBookId || newChapter != displayChapter) {
      manager.saveBookAndChapter(newBook, newChapter);
    }

    setState(() {
      displayBookId = newBook;
      displayChapter = newChapter;
      displayVerse = newVerse;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    manager.init(context);
  }

  @override
  void dispose() {
    syncController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HomeAppBar(
        displayBookId: displayBookId,
        displayChapter: displayChapter,
        displayVerse: displayVerse,
        onBookSelected: (bookId) async {
          _onUserNavigation(bookId, 1, 1);
        },
        onChapterSelected: (newChapter) {
          _onUserNavigation(displayBookId, newChapter, 1);
        },
        onVerseSelected: (verse) {
          _scrollToVerse(verse);
        },
        onTogglePanel: () {
          manager.togglePanelState();
          _syncManagerToDisplay();
          _requestText();
        },
        onPlayAudio: () {
          _onPlayAudio(context);
        },
      ),
      drawer: AppDrawer(
        onSettingsClosed: () {
          setState(() {
            // _fontScale = manager.getFontScale();
          });
        },
      ),
      body: SafeArea(
        child: Listener(
          onPointerDown: (_) {
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Stack(
            children: [
              // The main content (Bible Panels)
              ValueListenableBuilder<bool>(
                valueListenable: manager.isSinglePanelNotifier,
                builder: (context, isSinglePanel, _) {
                  return Column(
                    children: [
                      Expanded(
                        child: HebrewGreekPanel(
                          bookId: panelBookId,
                          chapter: panelChapter,
                          syncController: syncController,
                        ),
                      ),
                      if (!isSinglePanel) ...[
                        const SizedBox(height: 16),
                        Expanded(
                          child: BiblePanel(
                            bookId: panelBookId,
                            chapter: panelChapter,
                            syncController: syncController,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),

              // The Audio Player sliding up from the bottom
              Align(
                alignment: Alignment.bottomCenter,
                child: ValueListenableBuilder<bool>(
                  valueListenable: manager.audioManager.isVisibleNotifier,
                  builder: (context, isVisible, _) {
                    // Change 2: Use AnimatedSlide to move it in/out
                    return AnimatedSlide(
                      offset: isVisible ? Offset.zero : const Offset(0, 1),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: BottomAudioPlayer(
                        audioManager: manager.audioManager,
                        currentBookId: displayBookId,
                        currentChapter: displayChapter,
                        currentBookName: bookNameFromId(context, displayBookId),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handles explicit user navigation (selecting from menus)
  void _onUserNavigation(int bookId, int chapter, int verse) {
    manager.saveBookAndChapter(bookId, chapter);

    setState(() {
      // 1. Update Display
      displayBookId = bookId;
      displayChapter = chapter;
      displayVerse = verse;

      // 2. Update Panel (Forces reset/jump)
      panelBookId = bookId;
      panelChapter = chapter;
    });

    // 3. Update Manager (for single panel mode fetching)
    manager.onBookSelected(context, bookId);
    manager.currentChapterNotifier.value = chapter;

    // 4. Fetch
    _requestText();
  }

  void _syncManagerToDisplay() {
    if (manager.currentBookId != displayBookId) {
      manager.onBookSelected(context, displayBookId);
    }
    manager.currentChapterNotifier.value = displayChapter;
  }

  void _requestText() {
    if (manager.isSinglePanelNotifier.value) return;
    manager.requestText();
  }

  void _scrollToVerse(int verse) {
    syncController.jumpToVerse(displayBookId, displayChapter, verse);
  }

  Future<void> _onPlayAudio(BuildContext context) async {
    if (manager.audioManager.isVisibleNotifier.value) {
      manager.audioManager.stopAndClose();
      return;
    }

    try {
      await manager.playAudioForCurrentChapter(
        bookNameFromId(context, displayBookId),
        displayChapter,
      );
    } on AudioMissingException catch (_) {
      // Catch the specific missing audio error
      if (context.mounted) {
        _showDownloadAudioDialog(context);
      }
    } catch (e) {
      // Handle other errors
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _showDownloadAudioDialog(BuildContext context) async {
    // Determine what we are downloading
    final bookName = bookNameFromId(context, displayBookId);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Download Audio"),
          content: Text(
            "Audio for $bookName $displayChapter is not on your device.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _performDownload(bookOnly: false);
              },
              child: const Text("Download Chapter"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _performDownload(bookOnly: true);
              },
              child: const Text("Download Book"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performDownload({required bool bookOnly}) async {
    // Show a snackbar or loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Downloading audio..."),
        duration: Duration(days: 1),
      ),
    );

    try {
      if (bookOnly) {
        await manager.downloadAudioForBook(displayBookId);
      } else {
        await manager.downloadAudioForChapter(displayBookId, displayChapter);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        // Auto-play after download success
        _onPlayAudio(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Download failed: $e")));
      }
    }
  }
}
