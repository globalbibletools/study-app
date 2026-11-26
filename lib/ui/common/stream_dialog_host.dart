import 'dart:async';

import 'package:flutter/widgets.dart';

typedef StreamDialogBuilder<T> =
    Widget Function(BuildContext context, T event, VoidCallback dismiss);

class StreamDialogHost<T> extends StatefulWidget {
  const StreamDialogHost({
    super.key,
    required this.stream,
    required this.builder,
  });

  final Stream<T> stream;
  final StreamDialogBuilder<T> builder;

  @override
  State<StreamDialogHost<T>> createState() => _StreamDialogHostState<T>();
}

class _StreamDialogHostState<T> extends State<StreamDialogHost<T>> {
  StreamSubscription<T>? _subscription;
  T? _event;
  bool _hasEvent = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant StreamDialogHost<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream) {
      _subscription?.cancel();
      _event = null;
      _hasEvent = false;
      _subscribe();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _subscribe() {
    _subscription = widget.stream.listen((event) {
      if (!mounted) return;

      setState(() {
        _event = event;
        _hasEvent = true;
      });
    });
  }

  void _dismiss() {
    if (!_hasEvent) return;

    setState(() {
      _event = null;
      _hasEvent = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasEvent) return const SizedBox.shrink();

    return widget.builder(context, _event as T, _dismiss);
  }
}
