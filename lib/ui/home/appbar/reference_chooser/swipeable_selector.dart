import 'package:flutter/material.dart';

class SwipeableSelectorButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool enableSwipe;
  final String? Function() onPeekNext;
  final String? Function() onPeekPrevious;
  final VoidCallback onNextInvoked;
  final VoidCallback onPreviousInvoked;

  const SwipeableSelectorButton({
    super.key,
    required this.label,
    required this.onTap,
    this.enableSwipe = true,
    required this.onPeekNext,
    required this.onPeekPrevious,
    required this.onNextInvoked,
    required this.onPreviousInvoked,
  });

  @override
  State<SwipeableSelectorButton> createState() =>
      _SwipeableSelectorButtonState();
}

class _SwipeableSelectorButtonState extends State<SwipeableSelectorButton>
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
    final textStyle = theme.textTheme.bodyLarge?.copyWith(
      color: colorScheme.primary,
    );

    final currentText = _slideController.isAnimating
        ? (_animatingCurrentLabel ?? widget.label)
        : widget.label;

    return GestureDetector(
      onTap: widget.onTap,
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
