import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studyapp/common/bible_navigation.dart';

import 'book_selector.dart';
import 'number_selector.dart';

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
  final ValueChanged<Set<int>>? onAvailableDigitsChanged;

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
    this.onAvailableDigitsChanged,
  });

  @override
  State<ReferenceChooser> createState() => ReferenceChooserState();
}

class ReferenceChooserState extends State<ReferenceChooser> {
  final _bookFocus = FocusNode();
  late FocusNode _chapterFocus;
  late FocusNode _verseFocus;

  final _chapterController = TextEditingController();
  final _verseController = TextEditingController();

  ReferenceInputMode _currentMode = ReferenceInputMode.none;

  @override
  void initState() {
    super.initState();
    _chapterController.text = widget.currentChapter.toString();
    _verseController.text = widget.currentVerse.toString();

    _chapterFocus = FocusNode(onKeyEvent: _handlePhysicalKey);
    _verseFocus = FocusNode(onKeyEvent: _handlePhysicalKey);

    _chapterController.addListener(_updateAvailableDigits);
    _verseController.addListener(_updateAvailableDigits);
  }

  /// Intercepts physical keyboard events (MacOS/Windows/iPad)
  KeyEventResult _handlePhysicalKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // Handle Backspace
    if (key == LogicalKeyboardKey.backspace) {
      handleBackspace();
      return KeyEventResult.handled;
    }

    // Handle Enter
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      handleSubmit();
      return KeyEventResult.handled;
    }

    // Handle Digits (0-9 and Numpad 0-9)
    int? digit;
    if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
      digit = 0;
    } else if (key == LogicalKeyboardKey.digit1 ||
        key == LogicalKeyboardKey.numpad1) {
      digit = 1;
    } else if (key == LogicalKeyboardKey.digit2 ||
        key == LogicalKeyboardKey.numpad2) {
      digit = 2;
    } else if (key == LogicalKeyboardKey.digit3 ||
        key == LogicalKeyboardKey.numpad3) {
      digit = 3;
    } else if (key == LogicalKeyboardKey.digit4 ||
        key == LogicalKeyboardKey.numpad4) {
      digit = 4;
    } else if (key == LogicalKeyboardKey.digit5 ||
        key == LogicalKeyboardKey.numpad5) {
      digit = 5;
    } else if (key == LogicalKeyboardKey.digit6 ||
        key == LogicalKeyboardKey.numpad6) {
      digit = 6;
    } else if (key == LogicalKeyboardKey.digit7 ||
        key == LogicalKeyboardKey.numpad7) {
      digit = 7;
    } else if (key == LogicalKeyboardKey.digit8 ||
        key == LogicalKeyboardKey.numpad8) {
      digit = 8;
    } else if (key == LogicalKeyboardKey.digit9 ||
        key == LogicalKeyboardKey.numpad9) {
      digit = 9;
    }

    if (digit != null) {
      handleDigit(digit);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  void didUpdateWidget(covariant ReferenceChooser oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 1. Update Chapter Controller only if value changed externally
    // AND we aren't currently editing it.
    final chapterStr = widget.currentChapter.toString();
    if (_chapterController.text != chapterStr &&
        _currentMode != ReferenceInputMode.chapter) {
      _chapterController.text = chapterStr;
    }

    // 2. Update Verse Controller only if value changed externally
    // AND we aren't currently editing it.
    final verseStr = widget.currentVerse.toString();
    if (_verseController.text != verseStr &&
        _currentMode != ReferenceInputMode.verse) {
      _verseController.text = verseStr;
    }

    // 3. If book or chapter changed, recalculate allowed digits for the virtual keyboard
    if (widget.currentBookId != oldWidget.currentBookId ||
        widget.currentChapter != oldWidget.currentChapter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateAvailableDigits();
      });
    }
  }

  void _activateMode(ReferenceInputMode mode) {
    if (_currentMode == mode) return;

    setState(() {
      _currentMode = mode;
    });
    widget.onInputModeChanged(mode);

    if (mode == ReferenceInputMode.chapter) {
      _chapterController.clear();
      _chapterFocus.requestFocus();
    }
    if (mode == ReferenceInputMode.verse) {
      _verseController.clear();
      _verseFocus.requestFocus();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateAvailableDigits();
    });
  }

  void _resetAllInternal() {
    if (!mounted) return;
    setState(() {
      _currentMode = ReferenceInputMode.none;
    });
    widget.onInputModeChanged(ReferenceInputMode.none);
    widget.onAvailableDigitsChanged?.call({0, 1, 2, 3, 4, 5, 6, 7, 8, 9});
  }

  void _updateAvailableDigits() {
    if (widget.onAvailableDigitsChanged == null || !mounted) return;

    // 1. Calculate the allowed digits (this part is fine to do sync)
    final Set<int> allowed;

    if (_currentMode == ReferenceInputMode.none ||
        _currentMode == ReferenceInputMode.book) {
      allowed = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};
    } else {
      int maxValue;
      String currentText;

      if (_currentMode == ReferenceInputMode.chapter) {
        maxValue = BibleNavigation.getChapterCount(widget.currentBookId);
        currentText = _chapterController.text;
      } else {
        maxValue = BibleNavigation.getVerseCount(
          widget.currentBookId,
          widget.currentChapter,
        );
        currentText = _verseController.text;
      }

      final Set<int> result = {};
      for (int i = 0; i <= 9; i++) {
        String potential = currentText + i.toString();
        int? val = int.tryParse(potential);
        if (val != null && val <= maxValue && val > 0) {
          result.add(i);
        }
      }
      allowed = result;
    }

    // 2. Schedule the notification for the NEXT frame.
    // This prevents the "setState() called during build" error.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onAvailableDigitsChanged?.call(allowed);
      }
    });
  }

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

  void handleDigit(int digit) {
    TextEditingController? activeController;
    int maxValue = 999;

    if (_currentMode == ReferenceInputMode.chapter) {
      activeController = _chapterController;
      maxValue = BibleNavigation.getChapterCount(widget.currentBookId);
    } else if (_currentMode == ReferenceInputMode.verse) {
      activeController = _verseController;
      maxValue = BibleNavigation.getVerseCount(
        widget.currentBookId,
        widget.currentChapter,
      );
    }

    if (activeController != null) {
      String newText = activeController.text + digit.toString();
      int? newValue = int.tryParse(newText);

      if (newValue != null && newValue <= maxValue && newValue > 0) {
        setState(() {
          activeController!.text = newText;
        });

        if (_currentMode == ReferenceInputMode.chapter) {
          widget.onChapterSelected(newValue);
        } else if (_currentMode == ReferenceInputMode.verse) {
          widget.onVerseSelected(newValue);
        }

        bool canAppend = false;
        for (int i = 0; i <= 9; i++) {
          int? nextVal = int.tryParse(newText + i.toString());
          if (nextVal != null && nextVal <= maxValue && nextVal > 0) {
            canAppend = true;
            break;
          }
        }

        if (!canAppend) {
          handleSubmit();
        }
      }
    }
  }

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
        setState(() {
          activeController!.text = text.substring(0, text.length - 1);
        });

        if (activeController.text.isNotEmpty) {
          int? val = int.tryParse(activeController.text);
          if (val != null) {
            if (_currentMode == ReferenceInputMode.chapter) {
              widget.onChapterSelected(val);
            } else if (_currentMode == ReferenceInputMode.verse) {
              widget.onVerseSelected(val);
            }
          }
        }
      } else {
        if (_currentMode == ReferenceInputMode.verse) {
          _activateMode(ReferenceInputMode.chapter);
        } else if (_currentMode == ReferenceInputMode.chapter) {
          _activateMode(ReferenceInputMode.book);
        }
      }
    }
  }

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
        Flexible(
          fit: FlexFit.loose,
          child: BookSelector(
            currentBookName: widget.currentBookName,
            currentBookId: widget.currentBookId,
            isActive: _currentMode == ReferenceInputMode.book,
            focusNode: _bookFocus,
            onTap: () => _activateMode(ReferenceInputMode.book),
            onChanged: widget.onBookSelected,
            onSubmitted: (id) {
              widget.onBookSelected(id);

              int chapterCount = BibleNavigation.getChapterCount(id);
              if (chapterCount == 1) {
                widget.onChapterSelected(1);
                _activateMode(ReferenceInputMode.verse);
              } else {
                _activateMode(ReferenceInputMode.chapter);
              }
            },
            onCancel: resetAll,
          ),
        ),
        const SizedBox(width: 8),
        NumberSelector(
          controller: _chapterController,
          currentValue: widget.currentChapter,
          isActive: _currentMode == ReferenceInputMode.chapter,
          focusNode: _chapterFocus,
          enableSwipe: true,
          onTap: () => _activateMode(ReferenceInputMode.chapter),
          onKeyEvent: (event) => _handlePhysicalKey(_chapterFocus, event),
          onPeekNext: () {
            final maxChapters = BibleNavigation.getChapterCount(
              widget.currentBookId,
            );
            if (widget.currentChapter < maxChapters) {
              return (widget.currentChapter + 1).toString();
            }
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
            if (widget.currentChapter > 1) {
              return (widget.currentChapter - 1).toString();
            }
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
        NumberSelector(
          controller: _verseController,
          currentValue: widget.currentVerse,
          isActive: _currentMode == ReferenceInputMode.verse,
          focusNode: _verseFocus,
          enableSwipe: false,
          onTap: () => _activateMode(ReferenceInputMode.verse),
          onKeyEvent: (event) => _handlePhysicalKey(_verseFocus, event),
          onPeekNext: () => null,
          onNextInvoked: () {},
          onPeekPrevious: () => null,
          onPreviousInvoked: () {},
        ),
      ],
    );
  }
}
