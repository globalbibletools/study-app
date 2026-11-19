import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/asyncutils/cancellation.dart';

void main() {
  test('run returns the action value when current', () async {
    final scope = CancellationScope();
    final value = await scope.run(
      (guard) async => await guard(Future.value(42)),
    );
    expect(value, 42);
  });

  test('run throws CancelledError when superseded', () async {
    final scope = CancellationScope();
    final chapterData = Completer<int>();

    final superseded = scope.run(
      (guard) async => await guard(chapterData.future),
    );
    await scope.run((_) async {});
    chapterData.complete(42);

    await expectLater(superseded, throwsA(isA<CancelledError>()));
  });

  test(
    'a run cancelled before its first guard throws CancelledError',
    () async {
      final scope = CancellationScope();
      await expectLater(
        scope.run((guard) async {
          scope.cancelAll();
          await guard(Future.value(1));
        }),
        throwsA(isA<CancelledError>()),
      );
    },
  );

  test('guard rethrows the original error when the run is current', () async {
    final scope = CancellationScope();
    await expectLater(
      scope.run((guard) async {
        await guard(Future<int>.error(StateError('boom')));
      }),
      throwsStateError,
    );
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
      return 0;
    });
    await scope.run((_) async {});
    chapterData.completeError(StateError('boom'));

    await expectLater(superseded, throwsA(isA<CancelledError>()));
    expect(handledRealError, false);
  });

  test('a guard captured by a superseded run keeps throwing', () async {
    final scope = CancellationScope();
    final gate = Completer<void>();

    final superseded = scope.run((guard) async {
      await gate.future;
      return await guard(Future.value(42));
    });
    await scope.run((_) async {});
    gate.complete();

    await expectLater(superseded, throwsA(isA<CancelledError>()));
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
    final first = await scope.run((guard) async {
      return await guard(Future.value(1));
    });
    final second = await scope.run((guard) async {
      return await guard(Future.value(2));
    });
    expect(first, 1);
    expect(second, 2);
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
