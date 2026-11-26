# Cancel-and-Replace Cancellation

- Date: 2026-11-18
- Status: Superseded
- Supersedes: None
- Superseded By: [Serialized View Model Commands](2026-11-25-serialized-view-model-commands.md)

> Superseded as the general view-model asynchrony policy. New work that mutates
> state or must happen in order uses `SerialQueue`. `CancellationScope` remains
> available for read-only latest-wins reads; this record preserves the original
> policy and its mechanics.

# Context

Operations triggered by user actions routinely await I/O and get
re-invoked before they finish: navigation, playback, downloads. When a
second call starts while the first is in flight, the newest call must win.

Any solution must satisfy:

- A superseded invocation must stop touching shared state — including in
  its error handling, where a stale failure (logging, resetting, surfacing
  an error) would clobber the newer invocation.
- The newest invocation must not wait out the older one's I/O.
- Staleness must be checked in one place, not sprinkled after every
  `await`; the checks that matter most are in catch blocks, which are the
  easiest to forget and the most damaging to miss.

The audio player's chapter reload was the motivating case.

# Decisions

1. **Handle re-invocation with a shared cancellation utility**,
   `lib/asyncutils/cancellation.dart`, rather than per-operation staleness
   checks.
2. **The newest call wins.** A new invocation cancels the in-flight one
   instead of queueing behind it.
3. **A superseded invocation must not observe the outcome of any await,
   successful or failed** — stale results are not consumed, and stale
   errors never reach its error handling.
4. **Supersession propagates as `CancelledError`.** `run` returns the
   action's value and throws `CancelledError` when its run was
   superseded. Callers handle it where they can act on it — normally an
   early return, since a newer invocation owns the state — and
   catch-alls that await a run must let it escape before their generic
   `catch`, or they will treat abandonment as failure. Unhandled ones
   are expected, not bugs: the app's global error handler discards them,
   because they are control flow, not failures.
5. **Apply this when the operation awaits I/O, can be re-invoked before it
   completes, and writes state the newer invocation also touches.**

# Implementation Notes

The utility: `run(action)` starts a run, cancels the scope's previous
one, returns the action's value, and throws `CancelledError` when the
run is superseded; the action receives a `Guard` for its awaits.
`cancelAll()` abandons the active run. `CancelledError` is the
control-flow exception.

```dart
final scope = CancellationScope();

Future<void> load(Ref ref) => scope.run((guard) async {
  final data = await guard(fetch(ref));
  await guard(apply(data));
});

try {
  await load(ref);
} on CancelledError {
  return; // a newer invocation owns the state
}

@override
Future<void> dispose() async {
  scope.cancelAll();
  // ...
}
```

- Every `await` in a run goes through its guard, including awaits of your
  own helpers — pass `guard` as a parameter rather than capturing the
  scope, so the cancellation dependency is visible in signatures.
- Guards are bound to their run: a guarded future that settles after
  supersession throws `CancelledError`, whether it settled with a value
  or an error; otherwise the result or error passes through unchanged.
- Catch blocks inside a run must let `CancelledError` escape — `on
  CancelledError { rethrow; }` before any generic `catch`; typed clauses
  don't need this. This convention is documented only in this record —
  the code is comment-free.
- If a command must not even be *issued* by a superseded run, guard the
  await immediately before it: the guard's check on resume is the last
  check before the next statement runs.
- One scope per operation, owned by the object whose state the operation
  mutates. The operation's entry point starts the run and contains its
  whole body.
- Call `cancelAll()` in `dispose()` so an in-flight run cannot touch a
  disposed object.
- Handle `CancelledError` where the caller can act on it — normally an
  early return, since a newer invocation owns the state. Fire-and-forget
  call sites may leave it unhandled: the app's global error handler
  (`PlatformDispatcher.instance.onError` in `main.dart`) discards it
  without logging; real unhandled errors are logged there.
- The utility's semantics are pinned by
  `test/asyncutils/cancellation_test.dart`; extend those tests when
  changing the utility.

# Alternatives

- **Generation counter with per-await checks** — manual and scattered, catch
  blocks easy to miss.
- **Prepare/commit split** — double the code for the same guarantee.
- **Outcome-returning runs (`RunOutcome<T>`)** — honest completion
  without exceptions, but the union type colors every honest function up
  the call chain.
- **Boundary-settling `launch` (the returned future completes when the
  scope settles on the newest request)** — hides cancellation, but settles on
  requests the awaiter didn't make and cannot say whose work completed.
- **Mutex/queue** — delays the newest call behind stale I/O.

# References

- `lib/asyncutils/cancellation.dart`
- `test/asyncutils/cancellation_test.dart`
- `lib/audio/audio_player_view_model.dart`
