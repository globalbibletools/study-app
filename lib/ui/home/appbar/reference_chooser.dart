import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studyapp/common/bible_navigation.dart';
import 'package:studyapp/l10n/book_names.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

class ReferenceChooser extends StatefulWidget {
  final String currentBookName;
  final int currentBookId;
  final int currentChapter;
  final int currentVerse;
  final Function(int bookId) onBookSelected;
  final Function(int chapter) onChapterSelected;
  final Function(int verse) onVerseSelected;

  const ReferenceChooser({
    super.key,
    required this.currentBookName,
    required this.currentBookId,
    required this.currentChapter,
    required this.currentVerse,
    required this.onBookSelected,
    required this.onChapterSelected,
    required this.onVerseSelected,
  });

  @override
  State<ReferenceChooser> createState() => _ReferenceChooserState();
}

class _ReferenceChooserState extends State<ReferenceChooser> {
  final FocusNode _bookFocus = FocusNode();
  final FocusNode _chapterFocus = FocusNode();
  final FocusNode _verseFocus = FocusNode();

  bool _isSelectingBook = false;
  bool _isSelectingChapter = false;
  bool _isSelectingVerse = false;

  @override
  void initState() {
    super.initState();
    _bookFocus.addListener(
      () => _handleFocusChange(_bookFocus, (val) => _isSelectingBook = val),
    );
    _chapterFocus.addListener(
      () =>
          _handleFocusChange(_chapterFocus, (val) => _isSelectingChapter = val),
    );
    _verseFocus.addListener(
      () => _handleFocusChange(_verseFocus, (val) => _isSelectingVerse = val),
    );
  }

  void _handleFocusChange(FocusNode node, Function(bool) setter) {
    if (!node.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !node.hasFocus) {
          setState(() {
            setter(false);
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _bookFocus.dispose();
    _chapterFocus.dispose();
    _verseFocus.dispose();
    super.dispose();
  }

  void _resetAll() {
    setState(() {
      _isSelectingBook = false;
      _isSelectingChapter = false;
      _isSelectingVerse = false;
    });
    FocusManager.instance.primaryFocus?.unfocus();
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
            isActive: _isSelectingBook,
            focusNode: _bookFocus,
            onTap: () {
              setState(() {
                _isSelectingBook = true;
                _isSelectingChapter = false;
                _isSelectingVerse = false;
              });
            },
            onChanged: (id) => widget.onBookSelected(id),
            onSubmitted: (id) {
              widget.onBookSelected(id);
              setState(() {
                _isSelectingBook = false;
                _isSelectingChapter = true;
              });
              _chapterFocus.requestFocus();
            },
            onCancel: _resetAll,
          ),
        ),

        const SizedBox(width: 8),

        // --- CHAPTER SELECTOR ---
        _NumberSelector(
          currentValue: widget.currentChapter,
          isActive: _isSelectingChapter,
          focusNode: _chapterFocus,
          maxValue: BibleNavigation.getChapterCount(widget.currentBookId),
          enableSwipe: true, // Enabled
          onTap: () {
            setState(() {
              _isSelectingBook = false;
              _isSelectingChapter = true;
              _isSelectingVerse = false;
            });
          },
          // --- CHAPTER SWIPE LOGIC (With Book Overflow) ---
          onPeekNext: () {
            final maxChapters = BibleNavigation.getChapterCount(
              widget.currentBookId,
            );
            if (widget.currentChapter < maxChapters) {
              return (widget.currentChapter + 1).toString();
            } else if (widget.currentBookId < 66) {
              return "1"; // Next Book, Chapter 1
            }
            return null; // End of Bible
          },
          onNextInvoked: () {
            final maxChapters = BibleNavigation.getChapterCount(
              widget.currentBookId,
            );
            if (widget.currentChapter < maxChapters) {
              widget.onChapterSelected(widget.currentChapter + 1);
            } else if (widget.currentBookId < 66) {
              // Overflow to next book
              widget.onBookSelected(widget.currentBookId + 1);
              widget.onChapterSelected(1);
            }
          },
          onPeekPrevious: () {
            if (widget.currentChapter > 1) {
              return (widget.currentChapter - 1).toString();
            } else if (widget.currentBookId > 1) {
              // Previous Book, Last Chapter
              final prevBookId = widget.currentBookId - 1;
              return BibleNavigation.getChapterCount(prevBookId).toString();
            }
            return null; // Start of Bible
          },
          onPreviousInvoked: () {
            if (widget.currentChapter > 1) {
              widget.onChapterSelected(widget.currentChapter - 1);
            } else if (widget.currentBookId > 1) {
              // Overflow to previous book
              final prevBookId = widget.currentBookId - 1;
              widget.onBookSelected(prevBookId);
              widget.onChapterSelected(
                BibleNavigation.getChapterCount(prevBookId),
              );
            }
          },
          // --- TEXT INPUT LOGIC ---
          onValueChanged: (val) {
            widget.onChapterSelected(val);
          },
          onSubmitted: (val) {
            widget.onChapterSelected(val);
            setState(() {
              _isSelectingChapter = false;
              _isSelectingVerse = true;
            });
            _verseFocus.requestFocus();
          },
          onBackspaceWhenEmpty: () {
            // Go back to book selector
            setState(() {
              _isSelectingChapter = false;
              _isSelectingBook = true;
            });
            _bookFocus.requestFocus();
          },
          onCancel: _resetAll,
        ),

        const SizedBox(width: 8),

        // --- VERSE SELECTOR ---
        _NumberSelector(
          currentValue: widget.currentVerse,
          isActive: _isSelectingVerse,
          focusNode: _verseFocus,
          maxValue: 200, // Safe upper bound for text input
          enableSwipe: false, // DISABLED for Verse
          onTap: () {
            setState(() {
              _isSelectingBook = false;
              _isSelectingChapter = false;
              _isSelectingVerse = true;
            });
          },
          // Callbacks are ignored when enableSwipe is false, but required by constructor
          onPeekNext: () => null,
          onNextInvoked: () {},
          onPeekPrevious: () => null,
          onPreviousInvoked: () {},
          // --- TEXT INPUT LOGIC ---
          onSubmitted: (val) {
            widget.onVerseSelected(val);
            _resetAll();
          },
          onBackspaceWhenEmpty: () {
            // Go back to chapter selector
            setState(() {
              _isSelectingVerse = false;
              _isSelectingChapter = true;
            });
            _chapterFocus.requestFocus();
          },
          onCancel: _resetAll,
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
// NUMBER SELECTOR WIDGET
// -----------------------------------------------------------------------------

class _NumberSelector extends StatefulWidget {
  final int currentValue;
  final bool isActive;
  final FocusNode focusNode;
  final int maxValue;
  final bool enableSwipe;
  final VoidCallback onTap;
  final String? Function() onPeekNext;
  final String? Function() onPeekPrevious;
  final VoidCallback onNextInvoked;
  final VoidCallback onPreviousInvoked;
  final Function(int) onSubmitted;
  final VoidCallback onCancel;

  /// Called when the user presses backspace/delete on an empty field.
  final VoidCallback? onBackspaceWhenEmpty;

  /// Called each time the typed value changes (before auto-submit).
  /// Allows progressive navigation (e.g. load Psalm 8 while still typing).
  final Function(int)? onValueChanged;

  const _NumberSelector({
    required this.currentValue,
    required this.isActive,
    required this.focusNode,
    required this.maxValue,
    required this.onTap,
    required this.enableSwipe,
    required this.onPeekNext,
    required this.onPeekPrevious,
    required this.onNextInvoked,
    required this.onPreviousInvoked,
    required this.onSubmitted,
    required this.onCancel,
    this.onBackspaceWhenEmpty,
    this.onValueChanged,
  });

  @override
  State<_NumberSelector> createState() => _NumberSelectorState();
}

class _NumberSelectorState extends State<_NumberSelector> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    widget.focusNode.onKeyEvent = _onKeyEvent;
  }

  @override
  void didUpdateWidget(covariant _NumberSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive && oldWidget.isActive) {
      _controller.clear();
    }
    // Re-attach in case the focus node was replaced
    widget.focusNode.onKeyEvent = _onKeyEvent;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controller.text.isEmpty) {
      widget.onBackspaceWhenEmpty?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onTextChanged() {
    final text = _controller.text;
    if (text.isEmpty) return;
    final value = int.tryParse(text);
    if (value == null) return;

    // Report the current value for progressive navigation
    widget.onValueChanged?.call(value);

    bool shouldAutoSubmit = false;
    if (value == widget.maxValue) {
      shouldAutoSubmit = true;
    } else if (value * 10 > widget.maxValue) {
      shouldAutoSubmit = true;
    }

    if (shouldAutoSubmit) {
      _submit(value);
    }
  }

  void _submit(int value) {
    _controller.clear();
    widget.onSubmitted(value);
  }

  @override
  Widget build(BuildContext context) {
    return widget.isActive
        ? SizedBox(
            width: 50,
            child: TextField(
              controller: _controller,
              focusNode: widget.focusNode,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (val) {
                final intVal = int.tryParse(val);
                if (intVal != null) {
                  _submit(intVal);
                } else {
                  widget.onCancel();
                }
              },
            ),
          )
        : _SwipeableSelectorButton(
            label: widget.currentValue.toString(),
            onTap: widget.onTap,
            enableSwipe: widget.enableSwipe,
            onPeekNext: widget.onPeekNext,
            onNextInvoked: widget.onNextInvoked,
            onPeekPrevious: widget.onPeekPrevious,
            onPreviousInvoked: widget.onPreviousInvoked,
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
