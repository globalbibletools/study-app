# Reactivity Patterns

- Date: 2026-11-18
- Status: Accepted
- Supersedes: None
- Superseded By: None

# Context

Flutter offers many ways to propagate state changes (`setState`,
`ChangeNotifier`, `ValueNotifier`, `Stream`s, plus ecosystem options), and
picking one ad hoc per screen leads to inconsistent patterns and rebuild
storms. The tension: a rebuild costs `frequency x audience` (how often a
change fires times how much subtree rebuilds), but a pattern that minimizes
rebuilds at all costs spreads boilerplate across every screen. We need a
default that is ergonomic, with a sanctioned escape hatch when performance
demands it.

# Decisions

**Three tools, with clear roles:**

- **`ChangeNotifier`** is the default for view models: one notifier for a
  cohesive batch of state that changes together, one `ListenableBuilder` per
  screen region. For state that changes at human interaction frequency, not
  frame frequency.
- **`ValueNotifier`** is a per-field escape hatch *within* a view model, for
  a field that changes far more often than the rest (scroll sync, audio
  position). Its job is to shrink the audience to the subtree that cares.
- **`Stream`** is for events with no meaningful "now": subscribers only care
  about occurrences after they subscribe, not a current value. These should
  be less common than state notifiers.

**State vs. event discriminator:** if a late subscriber must see the current
value to render correctly, it is state — a notifier. If it only cares about
future occurrences, it is an event — a stream.

**Start boring, demote on evidence:**

1. Default the whole view model to `ChangeNotifier`.
2. Promote a field to `ValueNotifier` only when it starts changing at
   frame-ish rates, and shrink the surrounding builder to the smallest
   subtree.
3. Never promote speculatively — the split is justified by an observed
   rebuild storm, not a predicted one.

**Write rules:**

- View model state is written only by the view model, through its methods —
  that is where guards, persistence, and side effects live.
- Widgets are given `ValueListenable`, never `ValueNotifier`: the read side
  is public, the write side stays inside the view model.
- Guard every notification: `notifyListeners()` and `value =` fire only on
  an actual change (equality check for discrete values, tolerance for
  continuous ones).
- Widgets never subscribe to service streams directly; view models own their
  subscriptions and dispose them with themselves.

# Implementation Notes

- If one `ChangeNotifier` has listeners across many unrelated screens, that
  is a cohesion problem (split the view model) before a notifier-choice
  problem. Splitting fixes the audience; a per-field `ValueNotifier` only
  narrows one field.
- Services announce changes through streams rather than callback registries.
  View models may republish or map service streams; whether stream mapping
  should be the preferred pattern for database-originating changes is *not
  yet decided* — see `docs/ARCHITECTURE.md` "Streams across layers".
- There are known violations of "only the view model writes state" in the
  code today, to be addressed.
- `NavigationViewModel` guarding position updates within a tolerance is the
  canonical example of notification guarding.
- These tools govern state exposure and events. Asynchrony and ordering in view
  models are governed by [Serialized View Model
  Commands](2026-11-25-serialized-view-model-commands.md): mutating work runs
  through `SerialQueue`, and cancellation is reserved for read-only
  latest-wins work.

# Alternatives

- **`setState` everywhere:** Discarded. Data changes would propagate through
  the widget tree, making widgets own state and rebuilding large audiences.
- **Per-field `ValueNotifier` for everything:** Discarded. Minimal rebuilds
  in theory, but boilerplate per field and no cohesion signal; also hides
  the "several unrelated kinds of state" smell that a split view model
  would reveal.
- **BLoC / Rx-style event pipelines:** Discarded. Heavier machinery for the
  same three roles; the three built-in tools already cover state-batch,
  state-field, and event cases with less ceremony.

# References

- `docs/ARCHITECTURE.md` — the reactivity model in full
- [Serialized View Model Commands](2026-11-25-serialized-view-model-commands.md)
- [Four-Layer Architecture](2026-11-18-four-layer-architecture.md)
