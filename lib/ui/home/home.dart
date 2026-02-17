import 'package:flutter/material.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/l10n/book_names.dart';
import 'package:studyapp/services/download/cancel_token.dart';
import 'package:studyapp/ui/common/download_progress_dialog.dart';
import 'package:studyapp/ui/home/appbar/reference_chooser/reference_chooser.dart';
import 'package:studyapp/ui/home/appbar/reference_chooser/numeric_keypad.dart';
import 'package:studyapp/ui/home/audio/audio_logic.dart';
import 'package:studyapp/ui/home/audio/audio_manager.dart';
import 'package:studyapp/ui/home/audio/audio_player.dart';
import 'package:studyapp/ui/home/bible_panel/bible_panel.dart';
import 'package:studyapp/ui/home/appbar/drawer.dart';
import 'package:studyapp/ui/home/hebrew_greek_panel/chapter.dart';
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
  final _hebrewGreekPanelKey = GlobalKey<HebrewGreekPanelState>();
  final _biblePanelKey = GlobalKey<BiblePanelState>();
  final GlobalKey<ReferenceChooserState> _chooserKey = GlobalKey();
  ReferenceInputMode _inputMode = ReferenceInputMode.none;
  Set<int> _enabledKeypadDigits = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};

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
        referenceChooserKey: _chooserKey,
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
        onInputModeChanged: (mode) {
          setState(() {
            _inputMode = mode;
          });
        },
        onTogglePanel: () {
          manager.togglePanelState();
          _syncManagerToDisplay();
          _requestText();
        },
        onPlayAudio: () {
          _onPlayAudio(context);
        },
        onAvailableDigitsChanged: (digits) {
          // Use addPostFrameCallback to avoid setState during build
          if (mounted) {
            setState(() {
              _enabledKeypadDigits = digits;
            });
          }
        },
      ),
      drawer: AppDrawer(
        onSettingsClosed: () {
          _hebrewGreekPanelKey.currentState?.refreshFromSettings();
          _biblePanelKey.currentState?.refreshFromSettings();
        },
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // The main content (Bible Panels)
            Listener(
              onPointerDown: (_) {
                FocusManager.instance.primaryFocus?.unfocus();
                if (_inputMode != ReferenceInputMode.none) {
                  _chooserKey.currentState?.resetAll();
                }
              },
              behavior: HitTestBehavior.translucent,
              child: NotificationListener<VerseNumberTapNotification>(
                onNotification: (notification) {
                  if (manager.audioManager.isVisibleNotifier.value) {
                    manager.audioManager.play(
                      checkBookId: notification.bookId,
                      checkChapter: notification.chapter,
                      checkBookName: bookNameFromId(
                        context,
                        notification.bookId,
                      ),
                      startVerse: notification.verse,
                    );
                  }
                  return true;
                },
                child: ValueListenableBuilder<bool>(
                  valueListenable: manager.isSinglePanelNotifier,
                  builder: (context, isSinglePanel, _) {
                    return Column(
                      children: [
                        Expanded(
                          child: HebrewGreekPanel(
                            key: _hebrewGreekPanelKey,
                            bookId: panelBookId,
                            chapter: panelChapter,
                            syncController: syncController,
                          ),
                        ),
                        if (!isSinglePanel) ...[
                          const Divider(height: 0, indent: 8, endIndent: 8),
                          Expanded(
                            child: BiblePanel(
                              key: _biblePanelKey,
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
              ),
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
                      currentVerse: displayVerse,
                      currentBookName: bookNameFromId(context, displayBookId),
                      onAudioMissing: () => _showDownloadAudioDialog(context),
                    ),
                  );
                },
              ),
            ),

            // The Numeric Keypad
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedSlide(
                offset:
                    (_inputMode == ReferenceInputMode.chapter ||
                        _inputMode == ReferenceInputMode.verse)
                    ? Offset.zero
                    : const Offset(0, 1),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: Material(
                  elevation: 16, // Add shadow so it stands out
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: NumericKeypad(
                    isLastInput: _inputMode == ReferenceInputMode.verse,
                    enabledDigits: _enabledKeypadDigits,
                    onDigit: (d) => _chooserKey.currentState?.handleDigit(d),
                    onBackspace: () =>
                        _chooserKey.currentState?.handleBackspace(),
                    onSubmit: () => _chooserKey.currentState?.handleSubmit(),
                  ),
                ),
              ),
            ),
          ],
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
    // If already open, close it (Toggle behavior)
    if (manager.audioManager.isVisibleNotifier.value) {
      manager.audioManager.stopAndClose();
      return;
    }

    // Check if audio is actually available for this book/chapter
    if (!AudioLogic.isAudioAvailable(displayBookId, displayChapter)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.audioNotAvailable),
        ),
      );
      return;
    }

    try {
      await manager.playAudioForCurrentChapter(
        bookNameFromId(context, displayBookId),
        displayChapter,
        startVerse: displayVerse,
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
    final bookName = bookNameFromId(context, displayBookId);
    final l10n = AppLocalizations.of(context)!;

    // 1. Ask for confirmation
    final shouldDownload = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.downloadAudio),
          content: Text(l10n.audioNotDownloaded(bookName, displayChapter)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.download),
            ),
          ],
        );
      },
    );

    if (shouldDownload != true) return;

    // Check mounted before showing the next dialog
    if (!mounted) return;

    try {
      // 2. Show Progress Dialog (Auto-closes on success)
      await DownloadProgressDialog.show(
        context: context,
        task: (progress, cancelToken) {
          return manager.downloadAudioForChapter(
            displayBookId,
            displayChapter,
            progress,
            cancelToken,
          );
        },
      );

      // Check mounted again after the async dialog closes
      if (!mounted) return;

      // 3. Play audio (No Snackbar)
      // We pass the context here, but since we checked !mounted above, it's safe.
      _onPlayAudio(context);
    } catch (e) {
      if (!mounted) return;

      // Ignore cancel exceptions, show errors for everything else
      if (e is! DownloadCanceledException) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Download error: $e")));
      }
    }
  }
}
