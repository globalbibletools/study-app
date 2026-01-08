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
      // Delay reverting to button to allow taps (like picking a book) to finish
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
          onChanged: (val) {
            // Do NOTHING here. Changing the text should not load the chapter yet.
          },
          onSubmitted: (val) {
            // 1. Notify Parent to load text
            widget.onChapterSelected(val);

            // 2. Move to Verse Selection
            setState(() {
              _isSelectingChapter = false;
              _isSelectingVerse = true;
            });
            _verseFocus.requestFocus();
          },
          onCancel: _resetAll,
        ),

        const SizedBox(width: 8),

        // --- VERSE SELECTOR ---
        _NumberSelector(
          label: '${widget.currentVerse}',
          isActive: _isSelectingVerse,
          focusNode: _verseFocus,
          maxValue: 200, // Safe upper bound
          onTap: () {
            setState(() {
              _isSelectingBook = false;
              _isSelectingChapter = false;
              _isSelectingVerse = true;
            });
          },
          onChanged: (val) {
            // Verse changes trigger IMMEDIATE scrolling
            widget.onVerseSelected(val);
          },
          onSubmitted: (val) {
            // Pressing enter on verse just closes the inputs
            _resetAll();
          },
          onCancel: _resetAll,
        ),
      ],
    );
  }
}

class _CompactSelectorButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CompactSelectorButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        // Ensure text doesn't overflow internally
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.primary,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
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

  // Pre-calculate the search keys
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

  // Filter logic
  void _onTextChanged() {
    // Normalize user input (e.g., input "Ex" matches searchKey "exodo")
    final input = SearchUtilities.normalize(_controller.text);

    setState(() {
      _filteredBooks = _filter(input);
    });

    _overlayEntry?.markNeedsBuild();

    // Auto-accept if only 1 match remains
    if (_filteredBooks.length == 1) {
      final match = _filteredBooks.first;
      _selectBook(match.id);
    }
  }

  // Fuzzy matching algorithm using searchKey
  List<_BookSearchModel> _filter(String normalizedInput) {
    if (normalizedInput.isEmpty) return _allBooks;

    int minScore = 999999;
    List<_BookSearchModel> bestMatches = [];

    for (var book in _allBooks) {
      final searchKey = book.searchKey;

      // Rule 1: The book must start with the first letter of the input
      if (!searchKey.startsWith(normalizedInput[0])) {
        continue;
      }

      // Rule 2 & 3: Check for subsequence and calculate score
      int currentScore = 0;
      int lastIndex = -1;
      bool isMatch = true;

      for (int i = 0; i < normalizedInput.length; i++) {
        final char = normalizedInput[i];

        // Find char in searchKey after the previous char's position
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
    widget.onBookSelected(id);
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
          : _CompactSelectorButton(
              label: widget.currentBookName,
              onTap: widget.onTap,
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
  final Function(int) onChanged;
  final Function(int) onSubmitted;
  final VoidCallback onCancel;

  const _NumberSelector({
    required this.label,
    required this.isActive,
    required this.focusNode,
    required this.maxValue,
    required this.onTap,
    required this.onChanged,
    required this.onSubmitted,
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
  void didUpdateWidget(covariant _NumberSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive && oldWidget.isActive) {
      _controller.clear();
    }
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

    // 1. Report the change (e.g. for Verse scrolling)
    widget.onChanged(value);

    // 2. Disambiguation Logic (Auto-Submit)
    bool shouldAutoSubmit = false;

    // Case A: Exact match of max value (e.g. max 50, typed 50)
    if (value == widget.maxValue) {
      shouldAutoSubmit = true;
    }
    // Case B: Typing next digit would exceed max
    // (e.g. max 50. Typed '6'. '60' > 50. So '6' is final)
    else if (value * 10 > widget.maxValue) {
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
        : _CompactSelectorButton(label: widget.label, onTap: widget.onTap);
  }
}

/// A container to hold the book data and its pre-computed search key.
class _BookSearchModel {
  final int id;
  final String displayName;

  /// The normalized, lower-case, diacritic-free name
  final String searchKey;

  _BookSearchModel({
    required this.id,
    required this.displayName,
    required this.searchKey,
  });
}

/// Centralized logic for text normalization.
class SearchUtilities {
  // Unicode Block: Combining Diacritical Marks (U+0300 to U+036F)
  static final _combiningMarks = RegExp(r'[\u0300-\u036f]');

  static String normalize(String input) {
    if (input.isEmpty) return '';

    // 1. Decompose (NFD):
    //    "É" (U+00C9) -> "E" (U+0045) + "´" (U+0301)
    String normalized = unorm.nfd(input);

    // 2. Remove combining marks (accents)
    normalized = normalized.replaceAll(_combiningMarks, '');

    // 3. Lowercase
    normalized = normalized.toLowerCase();

    // 4. Future Extension:
    // if (isChinese(input)) { return PinyinHelper.convertToPinyin(input); }

    return normalized;
  }
}
