# Reactive Utilities

## Overview
Provides reactive stream synchronization utilities for Dart and Flutter. Features multi-stream combination routines that coordinate multiple asynchronous event sources, buffering latest values and emitting combined states upon updates once all source streams are active.

## Interface
- [combine_streams.dart:combineStreams3]: Combines three asynchronous streams (`Stream<A>`, `Stream<B>`, `Stream<C>`) into a single broadcast `Stream<R>` using a caller-provided combination function.

## Invariants
- `combineStreams3` will not emit until every input stream has emitted at least once (`hasA && hasB && hasC`).
- Following initial synchronization, an event from any input stream triggers an immediate emission using the latest value from each stream.
- The first stream to complete triggers completion of the combined broadcast stream and closes all inner subscriptions.
- Errors emitted by any input stream are piped directly to the output stream controller via `controller.addError`.
- Listener cancellation on the broadcast stream cancels all active underlying stream subscriptions.

## Side Effects
- Subscribes to input streams and cancels active stream subscriptions upon completion or downstream listener cancellation.
- Allocates and manages the lifecycle of a broadcast `StreamController`.

## Verification
- Run: `flutter test`
