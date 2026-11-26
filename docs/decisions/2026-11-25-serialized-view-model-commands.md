# Serialized View Model Commands

- Date: 2026-11-25
- Status: In Review
- Supersedes: [Cancel-and-Replace Cancellation](2026-11-18-cancel-and-replace.md)
- Superseded By: None

# Context

View models coordinate asynchronous work that mutates shared state and can be
invoked again before earlier work finishes. When those operations overlap:

- read-modify-write operations can lose updates;
- state transitions can interleave;
- operations that must follow earlier work can run out of order.

A boolean “request in progress” flag avoids overlap by dropping calls. That loses user intent and hides ordering. Cancellation is also insufficient for commands: it can stop a caller from observing a result, but it cannot undo a write already issued, and every accepted command’s effects may need to be observed.

The view model needs a general ordering mechanism for asynchronous work, independent of the domain and of where `await` happens to yield. Serializing commands fully replaces the earlier cancel-and-replace policy: cancellation is retired, and an operation that used to supersede an older invocation becomes a queued command, so the newest state wins by queue order rather than by discarding stale results.

# Decisions

1. **Serialize mutating view-model entry points through `SerialQueue`**, in
   `lib/asyncutils/serial_queue.dart`. The queue runs one task at a time in
   submission order and completes each task’s own future when it settles, so
   one failed task does not block the tasks behind it.
2. **Queue commands, not snapshots.** Every public method that mutates
   view-model state or a shared resource queues its body. A read that can be
   re-invoked before it finishes and publishes its result is also a command;
   serializing it is what replaces latest-wins cancellation. Pure reads that
   cannot overlap, and UI-only state changes, do not use the queue.
3. **Queue the command body directly in the public method.** Shared work stays
   in private, unqueued helpers. A queued body must not await another public
   queued method, or it deadlocks waiting on itself.
4. **Coalesce redundant periodic work.** Use `runCoalesced` so repeated requests
   for the same pending operation share one queued task instead of accumulating
   work. Commands should also be idempotent where repeating them adds no value.
5. **Commands decide their own validity when they run.** They read current
   state at execution time, not when they were submitted. A command made
   obsolete by an earlier queue entry becomes a no-op.
6. **Cancellation is retired.** `CancellationScope` and `CancelledError` are no
   longer part of the view-model asynchrony model. Do not add new uses. A
   re-invocation is serialized: the older invocation runs to completion, and the
   newer one wins by running later.
7. **Close the queue during disposal.** `SerialQueue.close()` blocks new work,
   drops pending work, and waits only for the in-flight action. Pending task
   futures complete with `SerialQueueClosed`; new work submitted after close
   fails the same way. `dispose()` starts the asynchronous close because
   `ChangeNotifier.dispose` is synchronous, then disposes notifiers, closes
   event streams, and calls `super.dispose()`.
8. **There is no supersession.** A running command finishes and a newer
   invocation waits its turn; the queue only controls what starts next. Public
   entry points are intentionally not guarded after disposal; callers must not
   submit commands to a disposed view model.

# Implementation Notes

Day-to-day conventions live in [ARCHITECTURE.md](../ARCHITECTURE.md), and
the queue’s API doc comments describe `run`, `runCoalesced`, and `runUnique`.
These notes cover what those sources do not.

- Coalescing uses intent keys (`'bookmark'`, `'submit'`, `'delete'`,
  `'deleteSession:<id>'`); data-carrying or cumulative commands (a manual
  session add, each month-navigation tap) never coalesce.
- Refreshes coalesce under the single constant key `'refresh'`, sound because
  every mutating command owns its post-write re-sync. Do not add epoch or
  version keys: they duplicate reads without making the shared refresh
  fresher.
- With `runUnique`, map `InFlightError` to the method’s no-op result. It
  rejects a duplicate; it does not supersede one.
- When a busy flag is warranted, set it in the public method before
  submitting (covering queued-not-yet-running work) and clear it when the
  returned future completes. Disposal sets the disposed flag before starting
  the asynchronous close; the completion callback must not touch a notifier
  once disposed.
- `dispose()` does not block. Tests and owners that need deterministic
  teardown can await the current command or the queue’s close future.
- Work that reschedules itself must check `SerialQueue.isClosed` so a
  finishing command cannot enqueue more work during shutdown.
- This serializes commands submitted through one view model. It does not make
  a shared service or persistence API safe for concurrent callers elsewhere;
  those paths still need their own ordering or atomic operations.
- **Migration: the audio player.** `AudioPlayerViewModel._reload` still relies
  on supersession so a new chapter load does not wait for the previous one.
  The target is one `SerialQueue` for every player-mutating entry point—public
  commands and stream/resource callbacks alike—so queue order alone decides
  the final state. Obsolete reloads will still execute, and the newest
  command will wait for the current one; that latency tradeoff is accepted
  for explicit ordering. After migrating, delete
  `lib/asyncutils/cancellation.dart`, the `CancelledError` handlers in
  `audio_player_view_model.dart` and `home_manager.dart`, and the global
  discard in `main.dart`.

# Alternatives

- **Keep a boolean lock and drop calls.** Simple, but silently loses accepted
  work.
- **Cancellation only.** The previous default; retired because it cannot order
  commands, and its latest-wins policy is replaced by serialization.
- **Queue in the service layer.** Moves serialization out of the view model, but
  obscures ordering from the caller and does not cover view-model state
  transitions that span multiple service calls.
- **Atomic and idempotent domain operations without a queue.** A good long-term
  direction, but it requires lower-layer changes before callers can safely
  issue concurrent mutations.

# References

- `lib/asyncutils/serial_queue.dart`
- `docs/ARCHITECTURE.md` — Asynchrony in view models
- `docs/decisions/2026-11-18-cancel-and-replace.md`
- `docs/decisions/2026-11-18-reactivity-patterns.md`
