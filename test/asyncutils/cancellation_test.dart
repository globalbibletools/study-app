import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/asyncutils/cancellation.dart';

void main() {
  test('guard returns the awaited value when the run is current', () async {
    final scope = CancellationScope();
    Object? result;
    await scope.run((guard) async {
      result = await guard(Future.value(42));
    });
    expect(result, 42);
  });

  test('guard rethrows the original error when the run is current', () async {
    final scope = CancellationScope();
    await expectLater(
      scope.run((guard) async {
        await guard(Future<int>.error(StateError('boom')));
      }),
      throwsStateError,
    );
  });

  test('guard throws when the run was already cancelled', () async {
    final scope = CancellationScope();
    var reached = false;
    await scope.run((guard) async {
      scope.cancelAll();
      await guard(Future.value(1));
      reached = true;
    });
    expect(reached, false);
  });

  test('guard cancels a stale success', () async {
    final scope = CancellationScope();
    final chapterData = Completer<int>();
    var result = -1;

    final superseded = scope.run((guard) async {
      result = await guard(chapterData.future);
    });
    await scope.run((_) async {});
    chapterData.complete(42);

    await superseded;
    expect(result, -1, reason: 'a stale result must not be consumed');
  });

  test('a stale failure is reported as cancellation, not an error', () async {
    final scope = CancellationScope();
    final chapterData = Completer<int>();
    var handledRealError = false;

    final superseded = scope.run((guard) async {
      try {
        await guard(chapterData.future);
      } on CancelledError {
        rethrow;
      } catch (e) {
        handledRealError = true;
      }
    });
    await scope.run((_) async {});
    chapterData.completeError(StateError('boom'));

    await superseded;
    expect(handledRealError, false);
  });

  test('a guard captured by a superseded run keeps throwing', () async {
    final scope = CancellationScope();
    final gate = Completer<void>();
    var result = -1;

    final superseded = scope.run((guard) async {
      await gate.future;
      result = await guard(Future.value(42));
    });
    await scope.run((_) async {});
    gate.complete();

    await superseded;
    expect(result, -1);
  });

  test('errors from the current run propagate', () async {
    final scope = CancellationScope();
    await expectLater(
      scope.run((guard) async {
        throw StateError('boom');
      }),
      throwsStateError,
    );
  });

  test("run rethrows cancellations it does not own", () async {
    final owner = CancellationScope();
    final other = CancellationScope();
    final ownerGate = Completer<void>();
    Guard? ownerGuard;
    final ownerRun = owner.run((guard) async {
      ownerGuard = guard;
      await ownerGate.future;
    });
    owner.cancelAll();

    await expectLater(
      other.run((_) async {
        await ownerGuard!(Future.value(1));
      }),
      throwsA(isA<CancelledError>()),
    );

    ownerGate.complete();
    await ownerRun;
  });

  test('a completed run does not cancel the next', () async {
    final scope = CancellationScope();
    var result = 0;
    await scope.run((guard) async {
      result = await guard(Future.value(1));
    });
    await scope.run((guard) async {
      result = await guard(Future.value(2));
    });
    expect(result, 2);
  });

  test('cancel is idempotent', () async {
    final token = CancellationToken();
    token.cancel('first');
    token.cancel('second');
    expect(token.isCancelled, isTrue);

    final errors = <Object>[];
    try {
      await token.guard(Future.value(1));
    } on CancelledError catch (e) {
      errors.add(e);
    }
    expect((errors.single as CancelledError).reason, 'first');
  });
}
