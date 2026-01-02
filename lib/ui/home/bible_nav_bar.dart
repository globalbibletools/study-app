import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studyapp/common/bible_navigation.dart';
import 'package:studyapp/l10n/book_names.dart'; // Ensure this import exists in your project

class BibleNavBar extends StatefulWidget {
  final String currentBookName;
  final int currentBookId;
  final int currentChapter;
  final Function(int bookId) onBookSelected;
  final Function(int chapter) onChapterSelected;
  final Function(int verse) onVerseSelected;

  const BibleNavBar({
    super.key,
    required this.currentBookName,
    required this.currentBookId,
    required this.currentChapter,
    required this.onBookSelected,
    required this.onChapterSelected,
    required this.onVerseSelected,
  });

  @override
  State<BibleNavBar> createState() => _BibleNavBarState();
}

class _BibleNavBarState extends State<BibleNavBar> {
  // Focus Nodes to manage navigation flow
  final FocusNode _bookFocus = FocusNode();
  final FocusNode _chapterFocus = FocusNode();
  final FocusNode _verseFocus = FocusNode();

  // Active state trackers
  bool _isSelectingBook = false;
  bool _isSelectingChapter = false;
  bool _isSelectingVerse = false;

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
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        // --- BOOK SELECTOR ---
        _BookSelector(
          currentBookName: widget.currentBookName,
          isActive: _isSelectingBook,
          focusNode: _bookFocus,
          onTap: () {
            setState(() {
              _isSelectingBook = true;
              _isSelectingChapter = false;
              _isSelectingVerse = false;
            });
          },
          onBookSelected: (id) {
            widget.onBookSelected(id);
            // Auto-focus chapter after book selection
            setState(() {
              _isSelectingBook = false;
              _isSelectingChapter = true;
            });
            _chapterFocus.requestFocus();
          },
          onCancel: _resetAll,
        ),

        const SizedBox(width: 8),

        // --- CHAPTER SELECTOR ---
        _NumberSelector(
          label: '${widget.currentChapter}',
          isActive: _isSelectingChapter,
          focusNode: _chapterFocus,
          maxValue: BibleNavigation.getChapterCount(widget.currentBookId),
          onTap: () {
            setState(() {
              _isSelectingBook = false;
              _isSelectingChapter = true;
              _isSelectingVerse = false;
            });
          },
          onValueChanged: (val) {
            widget.onChapterSelected(val);
            // Auto-focus verse after chapter selection?
            // Usually simpler to stay on chapter until explicit move,
            // but prompt implied flow. Let's strictly follow prompt logic:
            // "Disambiguated -> immediately selected".
          },
          onDisambiguated: () {
            // Optional: Move to verse automatically when chapter is done
            // setState(() {
            //   _isSelectingChapter = false;
            //   _isSelectingVerse = true;
            // });
            // _verseFocus.requestFocus();

            // For now, just close input as per standard "Selection" behavior
            _resetAll();
          },
          onCancel: _resetAll,
        ),

        const SizedBox(width: 8),

        // --- VERSE SELECTOR ---
        _NumberSelector(
          label: 'Verse', // Or a specific icon/text
          isActive: _isSelectingVerse,
          focusNode: _verseFocus,
          // We assume a high number for max verses if we don't have exact data,
          // or pass 176 (longest psalm) as safe upper bound for scrolling logic.
          maxValue: 200,
          onTap: () {
            setState(() {
              _isSelectingBook = false;
              _isSelectingChapter = false;
              _isSelectingVerse = true;
            });
          },
          onValueChanged: (val) {
            widget.onVerseSelected(val);
          },
          onDisambiguated: _resetAll,
          onCancel: _resetAll,
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// BOOK SELECTOR WIDGET
// -----------------------------------------------------------------------------

class _BookSelector extends StatefulWidget {
  final String currentBookName;
  final bool isActive;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final Function(int) onBookSelected;
  final VoidCallback onCancel;

  const _BookSelector({
    required this.currentBookName,
    required this.isActive,
    required this.focusNode,
    required this.onTap,
    required this.onBookSelected,
    required this.onCancel,
  });

  @override
  State<_BookSelector> createState() => _BookSelectorState();
}

class _BookSelectorState extends State<_BookSelector> {
  final TextEditingController _controller = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  // Cache of all available books (Id, Name)
  List<MapEntry<int, String>> _allBooks = [];
  List<MapEntry<int, String>> _filteredBooks = [];

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

  void _loadBookData() {
    // Generate list from 1 to 66 using the helper from main context
    _allBooks = List.generate(66, (index) {
      final id = index + 1;
      // Note: Assuming bookNameFromId is globally available or passed down.
      // If it's strictly local to context, we assume this widget is in tree.
      return MapEntry(id, bookNameFromId(context, id));
    });
    _filteredBooks = List.from(_allBooks);
  }

  void _onFocusChanged() {
    if (widget.focusNode.hasFocus) {
      _showOverlay();
    } else {
      _removeOverlay();
      // If we lost focus and didn't select, cancel editing
      if (widget.isActive) {
        Future.delayed(const Duration(milliseconds: 100), () {
          // Delay to allow tap on dropdown item to register before closing
          if (!mounted) return;
          // If we aren't handling a selection, cancel.
          // Note: actual selection logic handles state update.
        });
      }
    }
  }

  void _onTextChanged() {
    final input = _controller.text.toLowerCase();
    setState(() {
      _filteredBooks = _filter(input);
    });

    _overlayEntry?.markNeedsBuild();

    // AUTO-ACCEPT LOGIC
    if (_filteredBooks.length == 1) {
      final match = _filteredBooks.first;
      // Only auto-accept if the input roughly matches length or user specifically typed enough
      // to distinguish. To be safe, we auto-accept immediately as requested.
      _selectBook(match.key);
    }
  }

  List<MapEntry<int, String>> _filter(String input) {
    if (input.isEmpty) return _allBooks;

    // We will track the best (lowest) score found so far.
    // Initialize with a high number.
    int minScore = 999999;
    List<MapEntry<int, String>> bestMatches = [];

    for (var entry in _allBooks) {
      final bookName = entry.value.toLowerCase();

      // Rule 1: The book must start with the first letter of the input.
      if (!bookName.startsWith(input[0])) {
        continue;
      }

      // Rule 2 & 3: Check for subsequence and calculate "closeness" score.
      int currentScore = 0;
      int lastIndex = -1; // To ensure we search forward in the string
      bool isMatch = true;

      for (int i = 0; i < input.length; i++) {
        final char = input[i];

        // Find the character in the book name, strictly AFTER the previous character's position
        // greedy matching (indexOf) ensures we find the earliest occurrence,
        // which helps the score be as low as possible.
        final index = bookName.indexOf(char, lastIndex + 1);

        if (index == -1) {
          isMatch = false;
          break; // Character not found in order
        }

        // Add the index to the score.
        // Example "gn":
        // Genesis:   'g' (0) + 'n' (2) = Score 2
        // Galatians: 'g' (0) + 'n' (7) = Score 7
        currentScore += index;
        lastIndex = index;
      }

      if (isMatch) {
        if (currentScore < minScore) {
          // We found a better match (closer to front).
          // Clear previous candidates and start a new list with this winner.
          minScore = currentScore;
          bestMatches = [entry];
        } else if (currentScore == minScore) {
          // We found a tie (same letters in same positions).
          // Add to the existing list of winners.
          bestMatches.add(entry);
        }
        // If currentScore > minScore, we ignore it because a better match already exists.
      }
    }

    print(bestMatches);

    return bestMatches;
  }

  void _selectBook(int id) {
    _removeOverlay();
    _controller.clear();
    widget.onBookSelected(id);
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 200, // Fixed width for dropdown or use size.width
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
                    dense: true,
                    title: Text(book.value),
                    onTap: () => _selectBook(book.key),
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

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We use a Stack to ensure the text field takes exactly the same space
    // as the button by rendering the button (invisible) to dictate size.
    // However, since book names vary wildly in length, a fixed width or
    // IntrinsicWidth is better.

    return CompositedTransformTarget(
      link: _layerLink,
      child: widget.isActive
          ? SizedBox(
              // Constraint width to prevent jumping, or use fixed reasonable width
              width: 140,
              child: TextField(
                controller: _controller,
                focusNode: widget.focusNode,
                autofocus: true,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(),
                  hintText: 'Book',
                ),
                onSubmitted: (_) => widget.onCancel(),
              ),
            )
          : OutlinedButton(
              onPressed: widget.onTap,
              child: Text(widget.currentBookName),
            ),
    );
  }
}

// -----------------------------------------------------------------------------
// NUMBER SELECTOR WIDGET (Chapter / Verse)
// -----------------------------------------------------------------------------

class _NumberSelector extends StatefulWidget {
  final String label;
  final bool isActive;
  final FocusNode focusNode;
  final int maxValue;
  final VoidCallback onTap;
  final Function(int) onValueChanged;
  final VoidCallback onDisambiguated;
  final VoidCallback onCancel;

  const _NumberSelector({
    required this.label,
    required this.isActive,
    required this.focusNode,
    required this.maxValue,
    required this.onTap,
    required this.onValueChanged,
    required this.onDisambiguated,
    required this.onCancel,
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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    if (text.isEmpty) return;

    final value = int.tryParse(text);
    if (value == null) return;

    // 1. Notify change (for Verse scrolling)
    widget.onValueChanged(value);

    // 2. Check logic for Auto-Accept (Disambiguation)
    bool shouldAccept = false;

    // Case A: Exact match of max value (e.g. max 50, typed 50)
    if (value == widget.maxValue) {
      shouldAccept = true;
    }
    // Case B: Typing next digit would exceed max
    // (e.g. max 50. Typed '6'. '60' > 50. So '6' is final)
    // (e.g. max 50. Typed '4'. '40' <= 50. Wait.)
    else if (value * 10 > widget.maxValue) {
      shouldAccept = true;
    }

    if (shouldAccept) {
      _controller.clear();
      widget.onDisambiguated();
    }
  }

  @override
  Widget build(BuildContext context) {
    // To match button width, we can use IntrinsicWidth or a specific box.
    // Buttons for chapters are usually small.
    return widget.isActive
        ? SizedBox(
            width: 60,
            child: TextField(
              controller: _controller,
              focusNode: widget.focusNode,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => widget.onCancel(),
            ),
          )
        : OutlinedButton(onPressed: widget.onTap, child: Text(widget.label));
  }
}
