import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studyapp/common/bible_navigation.dart';
import 'package:studyapp/l10n/book_names.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

enum ReferenceInputMode { none, book, chapter, verse }

class ReferenceChooser extends StatefulWidget {
  final String currentBookName;
  final int currentBookId;
  final int currentChapter;
  final int currentVerse;
  final Function(int bookId) onBookSelected;
  final Function(int chapter) onChapterSelected;
  final Function(int verse) onVerseSelected;
  final ValueChanged<ReferenceInputMode> onInputModeChanged;

  const ReferenceChooser({
    super.key,
    required this.currentBookName,
    required this.currentBookId,
    required this.currentChapter,
    required this.currentVerse,
    required this.onBookSelected,
    required this.onChapterSelected,
    required this.onVerseSelected,
    required this.onInputModeChanged,
  });

  @override
  State<ReferenceChooser> createState() => ReferenceChooserState();
}

class ReferenceChooserState extends State<ReferenceChooser> {
  final _bookFocus = FocusNode();
  final _chapterFocus = FocusNode();
  final _verseFocus = FocusNode();

  final _chapterController = TextEditingController();
  final _verseController = TextEditingController();

  ReferenceInputMode _currentMode = ReferenceInputMode.none;

  @override
  void initState() {
    super.initState();
    _chapterController.text = widget.currentChapter.toString();
    _verseController.text = widget.currentVerse.toString();

    // We only listen to focus to detect when the user taps "Done" or clicks outside
    _bookFocus.addListener(_onFocusChange);
    _chapterFocus.addListener(_onFocusChange);
    _verseFocus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant ReferenceChooser oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep controllers in sync if external props change (e.g. user scrolled)
    if (widget.currentChapter != oldWidget.currentChapter &&
        _currentMode != ReferenceInputMode.chapter) {
      _chapterController.text = widget.currentChapter.toString();
    }
    if (widget.currentVerse != oldWidget.currentVerse &&
        _currentMode != ReferenceInputMode.verse) {
      _verseController.text = widget.currentVerse.toString();
    }
  }

  void _onFocusChange() {
    // If we lost all focus (user tapped outside), reset mode
    if (!_bookFocus.hasFocus &&
        !_chapterFocus.hasFocus &&
        !_verseFocus.hasFocus) {
      // Small delay to allow focus to move between our own fields
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted &&
            !_bookFocus.hasFocus &&
            !_chapterFocus.hasFocus &&
            !_verseFocus.hasFocus) {
          _resetAllInternal();
        }
      });
    }
  }

  void _activateMode(ReferenceInputMode mode) {
    if (_currentMode == mode) return;

    setState(() {
      _currentMode = mode;
    });
    widget.onInputModeChanged(mode);

    // Auto-clear logic when entering a mode
    if (mode == ReferenceInputMode.chapter) _chapterController.clear();
    if (mode == ReferenceInputMode.verse) _verseController.clear();

    // NOTE: We rely on 'autofocus: true' in the child widgets to grab focus
    // once the UI rebuilds with the active TextField.
  }

  void _resetAllInternal() {
    if (!mounted) return;
    setState(() {
      _currentMode = ReferenceInputMode.none;
    });
    widget.onInputModeChanged(ReferenceInputMode.none);
  }

  // PUBLIC: Called by HomeScreen to close keypad
  void resetAll() {
    FocusManager.instance.primaryFocus?.unfocus();
    _resetAllInternal();
  }

  @override
  void dispose() {
    _bookFocus.dispose();
    _chapterFocus.dispose();
    _verseFocus.dispose();
    _chapterController.dispose();
    _verseController.dispose();
    super.dispose();
  }

  // PUBLIC: Called by HomeScreen Keypad
  void handleDigit(int digit) {
    TextEditingController? activeController;
    int maxValue = 999;

    if (_currentMode == ReferenceInputMode.chapter) {
      activeController = _chapterController;
      maxValue = BibleNavigation.getChapterCount(widget.currentBookId);
    } else if (_currentMode == ReferenceInputMode.verse) {
      activeController = _verseController;
      maxValue = 200;
    }

    if (activeController != null) {
      String newText = activeController.text + digit.toString();
      int? newValue = int.tryParse(newText);

      // Simple validation
      if (newValue != null && newValue <= maxValue * 10) {
        activeController.text = newText;
        // Live update for chapters (so panels scroll while typing)
        if (_currentMode == ReferenceInputMode.chapter) {
          widget.onChapterSelected(newValue);
        }
      }
    }
  }

  // PUBLIC: Called by HomeScreen Keypad
  void handleBackspace() {
    TextEditingController? activeController;
    if (_currentMode == ReferenceInputMode.chapter) {
      activeController = _chapterController;
    } else if (_currentMode == ReferenceInputMode.verse) {
      activeController = _verseController;
    }

    if (activeController != null) {
      final text = activeController.text;
      if (text.isNotEmpty) {
        activeController.text = text.substring(0, text.length - 1);

        // If chapter, update live view if valid
        if (activeController.text.isNotEmpty &&
            _currentMode == ReferenceInputMode.chapter) {
          int? val = int.tryParse(activeController.text);
          if (val != null) widget.onChapterSelected(val);
        }
      } else {
        // Text is empty, navigate back
        if (_currentMode == ReferenceInputMode.verse) {
          _activateMode(ReferenceInputMode.chapter);
        } else if (_currentMode == ReferenceInputMode.chapter) {
          _activateMode(ReferenceInputMode.book);
        }
      }
    }
  }

  // PUBLIC: Called by HomeScreen Keypad
  void handleSubmit() {
    if (_currentMode == ReferenceInputMode.chapter) {
      int val = int.tryParse(_chapterController.text) ?? 1;
      widget.onChapterSelected(val);
      _activateMode(ReferenceInputMode.verse);
    } else if (_currentMode == ReferenceInputMode.verse) {
      int val = int.tryParse(_verseController.text) ?? 1;
      widget.onVerseSelected(val);
      resetAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        // --- BOOK SELECTOR ---
        Flexible(
          fit: FlexFit.loose,
          child: _BookSelector(
            currentBookName: widget.currentBookName,
            currentBookId: widget.currentBookId,
            isActive: _currentMode == ReferenceInputMode.book,
            focusNode: _bookFocus,
            onTap: () => _activateMode(ReferenceInputMode.book),
            onChanged: widget.onBookSelected,
            onSubmitted: (id) {
              widget.onBookSelected(id);
              _activateMode(ReferenceInputMode.chapter);
            },
            onCancel: resetAll,
          ),
        ),

        const SizedBox(width: 8),

        // --- CHAPTER SELECTOR ---
        _NumberSelector(
          controller: _chapterController,
          currentValue: widget.currentChapter,
          isActive: _currentMode == ReferenceInputMode.chapter,
          focusNode: _chapterFocus,
          enableSwipe: true,
          onTap: () => _activateMode(ReferenceInputMode.chapter),
          onPeekNext: () {
            final maxChapters = BibleNavigation.getChapterCount(
              widget.currentBookId,
            );
            if (widget.currentChapter < maxChapters)
              return (widget.currentChapter + 1).toString();
            if (widget.currentBookId < 66) return "1";
            return null;
          },
          onNextInvoked: () {
            final maxChapters = BibleNavigation.getChapterCount(
              widget.currentBookId,
            );
            if (widget.currentChapter < maxChapters) {
              widget.onChapterSelected(widget.currentChapter + 1);
            } else if (widget.currentBookId < 66) {
              widget.onBookSelected(widget.currentBookId + 1);
              widget.onChapterSelected(1);
            }
          },
          onPeekPrevious: () {
            if (widget.currentChapter > 1)
              return (widget.currentChapter - 1).toString();
            if (widget.currentBookId > 1) {
              final prev = widget.currentBookId - 1;
              return BibleNavigation.getChapterCount(prev).toString();
            }
            return null;
          },
          onPreviousInvoked: () {
            if (widget.currentChapter > 1) {
              widget.onChapterSelected(widget.currentChapter - 1);
            } else if (widget.currentBookId > 1) {
              final prev = widget.currentBookId - 1;
              widget.onBookSelected(prev);
              widget.onChapterSelected(BibleNavigation.getChapterCount(prev));
            }
          },
        ),

        const SizedBox(width: 8),

        // --- VERSE SELECTOR ---
        _NumberSelector(
          controller: _verseController,
          currentValue: widget.currentVerse,
          isActive: _currentMode == ReferenceInputMode.verse,
          focusNode: _verseFocus,
          enableSwipe: false,
          onTap: () => _activateMode(ReferenceInputMode.verse),
          onPeekNext: () => null,
          onNextInvoked: () {},
          onPeekPrevious: () => null,
          onPreviousInvoked: () {},
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// SWIPEABLE BUTTON WIDGET
// -----------------------------------------------------------------------------

class _SwipeableSelectorButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool enableSwipe; // Controls if gesture is detected
  final String? Function() onPeekNext;
  final String? Function() onPeekPrevious;
  final VoidCallback onNextInvoked;
  final VoidCallback onPreviousInvoked;

  const _SwipeableSelectorButton({
    required this.label,
    required this.onTap,
    this.enableSwipe = true,
    required this.onPeekNext,
    required this.onPeekPrevious,
    required this.onNextInvoked,
    required this.onPreviousInvoked,
  });

  @override
  State<_SwipeableSelectorButton> createState() =>
      _SwipeableSelectorButtonState();
}

class _SwipeableSelectorButtonState extends State<_SwipeableSelectorButton>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _currentTextSlide;
  late Animation<Offset> _incomingTextSlide;

  late AnimationController _bounceController;
  late Animation<Offset> _bounceAnimation;

  String? _incomingLabel;
  String? _animatingCurrentLabel;
  bool _isSwipingUp = true;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _currentTextSlide = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(_slideController);
    _incomingTextSlide = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(_slideController);

    // Initial placeholder
    _bounceAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(_bounceController);

    _slideController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onSlideComplete();
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _handleSwipeUp() {
    if (!widget.enableSwipe) return;
    if (_slideController.isAnimating || _bounceController.isAnimating) return;

    final nextLabel = widget.onPeekNext();
    if (nextLabel != null) {
      setState(() {
        _isSwipingUp = true;
        _animatingCurrentLabel = widget.label;
        _incomingLabel = nextLabel;
      });

      _currentTextSlide =
          Tween<Offset>(begin: Offset.zero, end: const Offset(0, -1)).animate(
            CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
          );

      _incomingTextSlide =
          Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
            CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
          );

      _slideController.forward(from: 0);
    } else {
      _triggerBounce(const Offset(0, -0.2));
    }
  }

  void _handleSwipeDown() {
    if (!widget.enableSwipe) return;
    if (_slideController.isAnimating || _bounceController.isAnimating) return;

    final prevLabel = widget.onPeekPrevious();
    if (prevLabel != null) {
      setState(() {
        _isSwipingUp = false;
        _animatingCurrentLabel = widget.label;
        _incomingLabel = prevLabel;
      });

      _currentTextSlide =
          Tween<Offset>(begin: Offset.zero, end: const Offset(0, 1)).animate(
            CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
          );

      _incomingTextSlide =
          Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
            CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
          );

      _slideController.forward(from: 0);
    } else {
      _triggerBounce(const Offset(0, 0.2));
    }
  }

  void _triggerBounce(Offset targetOffset) {
    _bounceController.reset();

    _bounceAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset.zero,
          end: targetOffset,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: targetOffset,
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 65,
      ),
    ]).animate(_bounceController);

    _bounceController.forward(from: 0);
  }

  void _onSlideComplete() {
    if (_isSwipingUp) {
      widget.onNextInvoked();
    } else {
      widget.onPreviousInvoked();
    }
    _slideController.reset();
    setState(() {
      _incomingLabel = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textStyle = theme.textTheme.labelLarge?.copyWith(
      color: colorScheme.primary,
    );

    final currentText = _slideController.isAnimating
        ? (_animatingCurrentLabel ?? widget.label)
        : widget.label;

    return GestureDetector(
      onTap: widget.onTap,
      // If swipe is disabled, pass null to prevent gesture capture
      onVerticalDragEnd: widget.enableSwipe
          ? (details) {
              if (details.primaryVelocity! < 0) {
                _handleSwipeUp();
              } else if (details.primaryVelocity! > 0) {
                _handleSwipeDown();
              }
            }
          : null,
      child: Container(
        constraints: const BoxConstraints(minWidth: 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
          color: Colors.transparent,
        ),
        child: ClipRect(
          child: Stack(
            alignment: Alignment.center,
            children: [
              SlideTransition(
                position: _slideController.isAnimating
                    ? _currentTextSlide
                    : _bounceAnimation,
                child: Text(
                  currentText,
                  style: textStyle,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (_slideController.isAnimating && _incomingLabel != null)
                SlideTransition(
                  position: _incomingTextSlide,
                  child: Text(
                    _incomingLabel!,
                    style: textStyle,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// BOOK SELECTOR WIDGET
// -----------------------------------------------------------------------------

class _BookSelector extends StatefulWidget {
  final String currentBookName;
  final int currentBookId;
  final bool isActive;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final Function(int) onChanged;
  final Function(int) onSubmitted;
  final VoidCallback onCancel;

  const _BookSelector({
    required this.currentBookName,
    required this.currentBookId,
    required this.isActive,
    required this.focusNode,
    required this.onTap,
    required this.onChanged,
    required this.onSubmitted,
    required this.onCancel,
  });

  @override
  State<_BookSelector> createState() => _BookSelectorState();
}

class _BookSelectorState extends State<_BookSelector> {
  final TextEditingController _controller = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<_BookSearchModel> _allBooks = [];
  List<_BookSearchModel> _filteredBooks = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadBookData();
  }

  @override
  void didUpdateWidget(covariant _BookSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive && oldWidget.isActive) {
      _controller.clear();
      _removeOverlay();
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (widget.focusNode.hasFocus) {
      _showOverlay();
    } else {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !widget.focusNode.hasFocus) {
          _removeOverlay();
        }
      });
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _loadBookData() {
    _allBooks = List.generate(66, (index) {
      final id = index + 1;
      final name = bookNameFromId(context, id);

      return _BookSearchModel(
        id: id,
        displayName: name,
        searchKey: SearchUtilities.normalize(name),
      );
    });
    _filteredBooks = List.from(_allBooks);
  }

  void _onTextChanged() {
    final input = SearchUtilities.normalize(_controller.text);
    setState(() {
      _filteredBooks = _filter(input);
    });
    _overlayEntry?.markNeedsBuild();

    if (_filteredBooks.length == 1) {
      final match = _filteredBooks.first;
      _selectBook(match.id);
    }
  }

  List<_BookSearchModel> _filter(String normalizedInput) {
    if (normalizedInput.isEmpty) return _allBooks;
    int minScore = 999999;
    List<_BookSearchModel> bestMatches = [];

    for (var book in _allBooks) {
      final searchKey = book.searchKey;
      if (!searchKey.startsWith(normalizedInput[0])) continue;
      int currentScore = 0;
      int lastIndex = -1;
      bool isMatch = true;

      for (int i = 0; i < normalizedInput.length; i++) {
        final char = normalizedInput[i];
        final index = searchKey.indexOf(char, lastIndex + 1);
        if (index == -1) {
          isMatch = false;
          break;
        }
        currentScore += index;
        lastIndex = index;
      }

      if (isMatch) {
        if (currentScore < minScore) {
          minScore = currentScore;
          bestMatches = [book];
        } else if (currentScore == minScore) {
          bestMatches.add(book);
        }
      }
    }
    return bestMatches;
  }

  void _selectBook(int id) {
    _removeOverlay();
    _controller.clear();
    widget.onSubmitted(id);
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 200,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 5),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _filteredBooks.length,
                itemBuilder: (context, index) {
                  final book = _filteredBooks[index];
                  return ListTile(
                    title: Text(book.displayName),
                    onTap: () => _selectBook(book.id),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: widget.isActive
          ? SizedBox(
              width: 100,
              child: TextField(
                controller: _controller,
                focusNode: widget.focusNode,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  if (_filteredBooks.isNotEmpty) {
                    _selectBook(_filteredBooks.first.id);
                  } else {
                    widget.onCancel();
                  }
                },
              ),
            )
          : _SwipeableSelectorButton(
              label: widget.currentBookName,
              onTap: widget.onTap,
              enableSwipe: true,
              onPeekNext: () {
                if (widget.currentBookId >= 66) return null;
                return bookNameFromId(context, widget.currentBookId + 1);
              },
              onNextInvoked: () => widget.onChanged(widget.currentBookId + 1),
              onPeekPrevious: () {
                if (widget.currentBookId <= 1) return null;
                return bookNameFromId(context, widget.currentBookId - 1);
              },
              onPreviousInvoked: () =>
                  widget.onChanged(widget.currentBookId - 1),
            ),
    );
  }
}

// -----------------------------------------------------------------------------
// NUMBER SELECTOR WIDGET (Stateless - Driven by Parent Controller)
// -----------------------------------------------------------------------------

class _NumberSelector extends StatelessWidget {
  final TextEditingController controller;
  final int currentValue;
  final bool isActive;
  final FocusNode focusNode;
  final bool enableSwipe;
  final VoidCallback onTap;

  // Swipe callbacks
  final String? Function() onPeekNext;
  final VoidCallback onNextInvoked;
  final String? Function() onPeekPrevious;
  final VoidCallback onPreviousInvoked;

  // Unused but kept for swipe logic or future expansion
  final int? maxValue;
  final Function(int)? onSubmitted;
  final VoidCallback? onCancel;
  final VoidCallback? onBackspaceWhenEmpty;
  final Function(int)? onValueChanged;

  const _NumberSelector({
    required this.controller,
    required this.currentValue,
    required this.isActive,
    required this.focusNode,
    required this.enableSwipe,
    required this.onTap,
    required this.onPeekNext,
    required this.onNextInvoked,
    required this.onPeekPrevious,
    required this.onPreviousInvoked,
    // Optional parameters (nullable)
    this.maxValue,
    this.onSubmitted,
    this.onCancel,
    this.onBackspaceWhenEmpty,
    this.onValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (isActive) {
      return SizedBox(
        width: 50,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: true,
          // MAGIC SAUCE: ReadOnly + ShowCursor prevents system keyboard
          readOnly: true,
          showCursor: true,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            border: OutlineInputBorder(),
          ),
        ),
      );
    }

    return _SwipeableSelectorButton(
      label: currentValue.toString(),
      onTap: onTap,
      enableSwipe: enableSwipe,
      onPeekNext: onPeekNext,
      onNextInvoked: onNextInvoked,
      onPeekPrevious: onPeekPrevious,
      onPreviousInvoked: onPreviousInvoked,
    );
  }
}

class _BookSearchModel {
  final int id;
  final String displayName;
  final String searchKey;

  _BookSearchModel({
    required this.id,
    required this.displayName,
    required this.searchKey,
  });
}

class SearchUtilities {
  static final _combiningMarks = RegExp(r'[\u0300-\u036f]');

  static String normalize(String input) {
    if (input.isEmpty) return '';
    String normalized = unorm.nfd(input);
    normalized = normalized.replaceAll(_combiningMarks, '');
    normalized = normalized.toLowerCase();
    return normalized;
  }
}
