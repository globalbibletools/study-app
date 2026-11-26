# Serialized View Model Commands

- Date: 2026-11-25
- Status: In Review
- Supersedes: [Cancel-and-Replace Cancellation](2026-11-18-cancel-and-replace.md)
- Superseded By: None

# Context

View models coordinate asynchronous work that mutates shared state and can be invoked again before earlier work finishes. When those operations overlap:

- read-modify-write operations can lose updates;
- state transitions can interleave;
- operations that must follow earlier work can run out of order.

A boolean “request in progress” flag avoids overlap by dropping calls. That loses user intent and hides ordering. Cancellation is also insufficient for commands: it can stop a caller from observing a result, but it cannot undo a write already issued, and every accepted command’s effects may need to be observed.

The view model needs a general ordering mechanism for mutating work, independent of the domain and of where `await` happens to yield. This replaces the earlier cancel-and-replace policy as the default model for view-model asynchrony. Cancellation remains a shared primitive for read-only latest-wins work, but it is no longer the way view-model commands are ordered.

# Decisions

1. **Serialize mutating view-model entry points through `SerialQueue`**, in
   `lib/asyncutils/serial_queue.dart`. The queue runs one task at a time in
   submission order and completes each task’s own future when it settles, so
   one failed task does not block the tasks behind it.
2. **Queue commands, not snapshots.** Every public method that mutates
   view-model state or a shared resource queues its body. Pure reads and
   UI-only state changes do not use the queue.
3. **Queue the command body directly in the public method.** Shared work stays
   in private, unqueued helpers. A queued body must not await another public
   queued method, or it deadlocks waiting on itself.
4. **Coalesce redundant periodic work.** Use `runCoalesced` so repeated requests
   for the same pending operation share one queued task instead of accumulating
   work. Commands should also be idempotent where repeating them adds no value.
5. **Commands decide their own validity when they run.** They read current
   state at execution time, not when they were submitted. A command made
   obsolete by an earlier queue entry becomes a no-op.
6. **`CancellationScope` remains reserved for read-only latest-wins work**, not
   for ordered commands. If an operation writes shared state, it belongs on the
   queue.
7. **Close the queue during disposal.** `SerialQueue.close()` blocks new work,
   drops pending work, and waits only for the in-flight action. Pending task
   futures complete with `SerialQueueClosed`; new work submitted after close
   fails the same way. `dispose()` starts the asynchronous close because
   `ChangeNotifier.dispose` is synchronous, then disposes notifiers, closes
   event streams, and calls `super.dispose()`.
8. **The queue is not cancellation.** A running command finishes; the queue only
   controls what starts next. Public entry points are intentionally not guarded
   after disposal; callers must not submit commands to a disposed view model.

# Implementation Notes

- `SerialQueue.run` returns the task’s future, so callers can await completion
  or ignore it for fire-and-forget commands.
- `SerialQueue.runCoalesced(key, action)` shares one future per pending key.
- The queue never completes its internal tail with an error; task errors go only
  to that task’s returned future.
- `dispose()` does not block. Tests and owners that need deterministic teardown
  can await the current command or the queue’s close future.
- Work that reschedules itself must check `SerialQueue.isClosed` so a finishing
  command cannot enqueue more work during shutdown.
- This serializes commands submitted through one view model. It does not make a
  shared service or persistence API safe for concurrent callers elsewhere;
  those paths still need their own ordering or atomic operations.

# Alternatives

- **Keep a boolean lock and drop calls.** Simple, but silently loses accepted
  work.
- **Cancellation only.** The previous default. Suitable for latest-wins reads,
  but not for commands with side effects that must be observed.
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
