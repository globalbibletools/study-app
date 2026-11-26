import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/asyncutils/serial_queue.dart';

void main() {
  group('run', () {
    test('runs actions in submission order without overlapping', () async {
      final queue = SerialQueue();
      final releaseFirst = Completer<void>();
      final events = <String>[];

      final first = queue.run(() async {
        events.add('first start');
        await releaseFirst.future;
        events.add('first end');
      });
      final second = queue.run(() async {
        events.add('second');
      });

      await Future<void>.delayed(Duration.zero);
      expect(events, ['first start']);

      releaseFirst.complete();
      await Future.wait([first, second]);

      expect(events, ['first start', 'first end', 'second']);
    });

    test('a failed action does not block later actions', () async {
      final queue = SerialQueue();

      final failed = queue.run<void>(() async {
        throw StateError('boom');
      });
      final after = queue.run(() async => 42);

      await expectLater(failed, throwsStateError);
      expect(await after, 42);
    });

    test('idle waits for work submitted so far', () async {
      final queue = SerialQueue();
      var completed = false;

      queue.run(() async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        completed = true;
      });

      await queue.idle;
      expect(completed, isTrue);
    });
  });

  group('runCoalesced', () {
    test('shares one queued task per key', () async {
      final queue = SerialQueue();
      final release = Completer<void>();
      var calls = 0;

      final first = queue.runCoalesced('flush', () async {
        calls++;
        await release.future;
      });
      final second = queue.runCoalesced('flush', () async {
        calls++;
      });

      expect(identical(first, second), isTrue);

      release.complete();
      await Future.wait([first, second]);
      expect(calls, 1);

      await queue.runCoalesced('flush', () async {
        calls++;
      });
      expect(calls, 2);
    });

    test('different keys run as separate tasks', () async {
      final queue = SerialQueue();
      final events = <String>[];

      await Future.wait([
        queue.runCoalesced('a', () async {
          events.add('a');
        }),
        queue.runCoalesced('b', () async {
          events.add('b');
        }),
      ]);

      expect(events, ['a', 'b']);
    });

    test(
      'errors complete the shared future and later work continues',
      () async {
        final queue = SerialQueue();

        final coalesced = queue.runCoalesced('flush', () async {
          throw StateError('boom');
        });
        final after = queue.run(() async => 42);

        await expectLater(coalesced, throwsStateError);
        expect(await after, 42);
      },
    );
  });

  group('close', () {
    test('waits for current work and drops pending work', () async {
      final queue = SerialQueue();
      final release = Completer<void>();
      var currentFinished = false;
      var pendingRan = false;

      final current = queue.run(() async {
        await release.future;
        currentFinished = true;
      });
      final pending = queue.run(() async {
        pendingRan = true;
      });

      final closing = queue.close();
      expect(queue.isClosed, isTrue);

      await expectLater(pending, throwsA(isA<SerialQueueClosed>()));

      release.complete();
      await current;
      await closing;

      expect(currentFinished, isTrue);
      expect(pendingRan, isFalse);
      await expectLater(
        queue.run(() async => pendingRan = true),
        throwsA(isA<SerialQueueClosed>()),
      );
    });

    test('drops pending coalesced work', () async {
      final queue = SerialQueue();
      final release = Completer<void>();
      var coalescedRan = false;

      final current = queue.run(() async {
        await release.future;
      });
      final pending = queue.runCoalesced('flush', () async {
        coalescedRan = true;
      });

      final closing = queue.close();
      await expectLater(pending, throwsA(isA<SerialQueueClosed>()));

      release.complete();
      await current;
      await closing;

      expect(coalescedRan, isFalse);
    });

    test('is idempotent', () async {
      final queue = SerialQueue();

      final first = queue.close();
      final second = queue.close();

      expect(identical(first, second), isTrue);
      await first;
      await second;
    });
  });
}
