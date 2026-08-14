import 'dart:async';

Stream<R> combineStreams3<A, B, C, R>(
  Stream<A> a,
  Stream<B> b,
  Stream<C> c,
  R Function(A a, B b, C c) combine,
) {
  late StreamController<R> controller;

  A? latestA;
  B? latestB;
  C? latestC;
  var hasA = false;
  var hasB = false;
  var hasC = false;

  final List<StreamSubscription> subscriptions = [];

  var closed = false;

  void emit() {
    if (hasA && hasB && hasC) {
      controller.add(combine(latestA as A, latestB as B, latestC as C));
    }
  }

  Future<void> done() async {
      if (closed) return;
      closed = true;
      for (final sub in subscriptions) {
          await sub.cancel();
      }
      await controller.close();
  }

  controller = StreamController<R>.broadcast(
    onListen: () {
      subscriptions.addAll([
          a.listen(
            (value) {
              latestA = value;
              hasA = true;
              emit();
            },
            onError: controller.addError,
            onDone: done,
          ),
          b.listen(
            (value) {
              latestB = value;
              hasB = true;
              emit();
            },
            onError: controller.addError,
            onDone: done,
          ),
          c.listen(
            (value) {
              latestC = value;
              hasC = true;
              emit();
            },
            onError: controller.addError,
            onDone: done,
          )
      ]);
    },
    onCancel: () async {
        closed = true;
        for (final sub in subscriptions) {
            await sub.cancel();
        }
    },
  );

  return controller.stream;
}
