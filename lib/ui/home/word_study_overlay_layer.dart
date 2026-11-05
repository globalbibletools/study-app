import 'package:flutter/material.dart';
import 'package:gbt/ui/home/home_manager.dart';
import 'package:gbt/ui/home/word_details_dialog/word_details_dialog.dart';

class _WordStudyNavigatorObserver extends NavigatorObserver {
  final VoidCallback onRootRoutePopped;

  _WordStudyNavigatorObserver(this.onRootRoutePopped);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute == null) {
      onRootRoutePopped();
    }
  }
}

class WordStudyOverlayLayer extends StatefulWidget {
  const WordStudyOverlayLayer({
    super.key,
    required this.session,
    required this.manager,
  });

  final WordStudySession session;
  final HomeManager manager;

  @override
  State<WordStudyOverlayLayer> createState() => _WordStudyOverlayLayerState();
}

class _WordStudyOverlayLayerState extends State<WordStudyOverlayLayer> {
  late final _WordStudyNavigatorObserver _observer;

  @override
  void initState() {
    super.initState();
    _observer = _WordStudyNavigatorObserver(() {
      widget.manager.dismissWordStudySession(keepCurrentLocation: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.session.isOverlayVisible,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final navState = widget.session.navigatorKey.currentState;
        if (navState != null && navState.canPop()) {
          navState.pop();
        } else {
          widget.manager.dismissWordStudySession(keepCurrentLocation: false);
        }
      },
      child: Navigator(
        key: widget.session.navigatorKey,
        observers: [_observer],
        onGenerateRoute: (settings) {
          return DialogRoute(
            context: context,
            settings: settings,
            barrierDismissible: true,
            barrierColor: Colors.black54,
            builder: (context) => WordDetailsDialog(
              wordId: widget.session.wordId,
              isRtl: widget.session.isRtl,
            ),
          );
        },
      ),
    );
  }
}
