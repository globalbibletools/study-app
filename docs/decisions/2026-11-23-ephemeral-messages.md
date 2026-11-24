# App-Level Ephemeral Messages

- Date: 2026-11-23
- Status: In Review
- Supersedes: None
- Superseded By: None

# Context

The app needs to tell the user that a short-lived thing happened — a verse was
copied, a backup succeeded, an export failed. These notices must keep working
while the user navigates, open a sheet, or has a dialog on screen. They must not
be owned by a page that can disappear underneath them.

`ScaffoldMessenger` and `showSnackBar` are page/Scaffold-scoped: a notice shown
from a route dies with that route, snackbars animate in at the bottom where they
compete with the app's bottom navigation and audio controls, and the API has no
shared queue or priority. The existing ReadingSheet had to nest a second
`ScaffoldMessenger` just to get a snackbar to appear inside a modal sheet — a
workaround that reveals the placement problem rather than solving it.

We also have two kinds of emitters. Widgets emit directly from gestures, and
view models emit after async work completes. Both need the same behavior and the
same single visible notice, without passing a `BuildContext` or a `GlobalKey`
below the widget layer.

# Decisions

**One app-level renderer above the Navigator.** A single `MessengerHost` is
installed through `MaterialApp.builder`, wrapping the app's `Navigator`:

```dart
builder: (context, child) => MessengerHost(
  messenger: getIt<MessengerViewModel>(),
  child: child ?? const SizedBox.shrink(),
),
```

Because the host is a sibling painted after the Navigator (and therefore above
its routes and overlays), messages survive navigation and render above dialogs,
modal bottom sheets, and nested navigators. The host uses a
`Stack(fit: StackFit.expand)` with a `Positioned` banner at the top and
`SafeArea`, so only the message card intercepts pointers.

**A global view model, not widget-tree state.** `MessengerViewModel` is a
`ChangeNotifier` registered as a lazy singleton in the service locator. Widgets
and view models emit through its `showInfo` / `showSuccess` / `showWarning` /
`showError` methods. No `InheritedWidget`/scope is introduced: the state is
process-wide by design, not scoped to a subtree. `MessengerHost` receives the
view model through its constructor and never resolves it itself.

**One visible message plus a priority queue.** At most one message is visible.
Pending messages are ordered by severity, highest first
(`error > warning > success > info`), and FIFO within a severity. A newly
arrived higher-priority message does **not** preempt the visible one; it is
inserted ahead of lower-priority pending messages and appears when the current
message dismisses. This keeps reading from being interrupted mid-sentence while
still ensuring errors surface next.

**Every message has its own lifecycle.** Only the visible message owns a timer;
queued messages have none, so their full duration starts when they appear.
Durations are three seconds for success/info, five for warning, and eight for
error. Every message also has a close control for early dismissal. Dismissal by
timer or by the user advances the queue. Messages outlive the route that emitted
them because they are not tied to a page.

**Coalescing.** Messages are identical when severity and text match. Identical
messages never duplicate: if the match is visible, its timer restarts so the
user gets the full reading time; if it is queued, the existing entry is kept in
its current position (the queue "refreshes" when it becomes visible with a full
duration). No second entry is created either way.

**Content is text plus severity only.** No title, detail, actions, markdown, or
arbitrary widgets. Call sites pass already-localized strings; the messaging
slice does not localize content. Severity selects an icon and colors that are
readable in both light and dark themes. The message text is exposed as a live
region and the dismiss control is labeled from existing localization strings.

# Implementation Notes

- Slice files: `lib/ui/messaging/ephemeral_message.dart`,
  `messenger_view_model.dart`, and `messenger_host.dart`, with tests mirroring
  the path under `test/ui/messaging/`.
- Migration from `ScaffoldMessenger` is incremental: snackbar call sites emit
  through the global messenger. Dialog-based flows (confirmations, download
  progress, the audio-error alert) are not messages and keep their APIs.
- Capture the global view model before an `await` when a call site needs it
  afterwards; the notice no longer depends on a still-mounted `BuildContext`.
- The host uses an `AnimatedSwitcher` for enter/exit and an `IgnorePointer`
  over the banner area when nothing is visible, so the empty host is
  transparent to taps.
- Do not resolve services from this slice's widgets. Emitting is allowed from
  widgets and view models only through the registered global view model.
- The nested `ScaffoldMessenger` in `ReadingSheet` was only there to make
  snackbars appear above the sheet; the app-level host makes it obsolete.

# Alternatives

- **`ScaffoldMessenger` / `SnackBar` globally.** Discarded: snackbars are
  bottom-anchored, page-scoped in practice, and have no shared priority queue;
  the ReadingSheet workaround demonstrates the placement mismatch.
- **Overlay entries inserted from call sites.** Discarded: every caller would
  need a `BuildContext`/`Overlay`, entries would not share ordering or
  coalescing, and view models cannot own overlay entries without knowing the
  widget tree.
- **An `InheritedWidget`/scope for the messenger.** Discarded for now: the
  state is process-wide and legitimately global, so a scope adds lookup
  plumbing and a widget-tree lifetime to something that must outlive pages.
  This can be revisited if messaging ever needs per-subtree isolation.
- **Preempting the visible message with higher priority.** Discarded: notices
  would flicker away mid-read, and users would lose the context they were
  already reading. Queuing preserves both ordering and readability.
- **Stacking multiple messages at once.** Discarded: it competes for the same
  top area, obscures content, and requires layout decisions the app does not
  need. One at a time with a queue is predictable.
- **Titles, actions, or arbitrary widget content.** Discarded: these are
  dialogs or inline UI, not transient notices. Keeping messages to text plus
  severity keeps every emission cheap and consistent.

# References

- `docs/ARCHITECTURE.md` — layers, global view models, and vertical slices
- [Four-Layer Architecture](2026-11-18-four-layer-architecture.md)
- [Dependency Injection](2026-11-18-dependency-injection.md)
- [Reactivity Patterns](2026-11-18-reactivity-patterns.md)
- [Vertical Slices](2026-11-19-vertical-slices.md)
