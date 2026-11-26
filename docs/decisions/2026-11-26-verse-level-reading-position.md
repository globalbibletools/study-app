# Verse-Level Reading Position Persistence

- Date: 2026-11-26
- Status: In Review
- Supersedes: None
- Superseded By: None

# Context

The reader previously persisted only the last book and chapter. Restoring the
app therefore always opened at the top of the saved chapter, even when the
reader had stopped in the middle of it. The verse was already available at
every persistence point: panel reports (`reportPosition`) carry a display
`Reference` resolved from the scroll geometry, and navigation/seek/audio
updates carry a full `Reference`.

Persisting the verse is not merely a convenience for restoration. Code that
depends on the reading position, such as word-study return and session
handling, already works from `NavigationViewModel.currentReference`, which
includes the verse. Persisting it keeps the stored position consistent with the
in-memory one.

The navigation `anchor` used to drive panel rebuilds is a separate concern. It
is deliberately chapter-scoped, and moving it to verse granularity would cause
panels to rebuild on every verse crossing.

# Decisions

- **Store the verse alongside book and chapter in `UserSettings`.** The
  `currentVerse` shared-preferences key defaults to 1, and the reading position
  is read and written as a `Reference` through `currentReference` /
  `setCurrentReference`.
- **No settings migration is required.** A missing `currentVerse` means the
  chapter top, which is exactly the old behavior. Existing installs therefore
  keep their saved book and chapter and simply start at verse 1.
- **Keep the navigation anchor chapter-scoped.** `NavigationViewModel` writes
  the anchor with `verse: 1`; the persisted reading position keeps the real
  verse. This avoids rebuilding panels on every verse change while still
  restoring the verse for display.
- **Dedupe writes per verse.** The view model skips a settings write when the
  book, chapter, and verse are unchanged. There is no debounce or throttle yet;
  scrolling across verses may write several times. Verse-level dedupe is
  enough for this change, and it can be revisited if write frequency becomes a
  problem.
- **Restore seeks like an explicit verse seek.** The constructor applies the
  restored position with `isSeek: true`, so a restored verse greater than 1
  gets the same small top offset as an explicit seek.

# Implementation Notes

- `UserSettings.currentReference` reads `currentBookId`, `currentChapter`, and
  `currentVerse`, defaulting each to 1.
- `NavigationViewModel._lastSavedReference` is seeded from the restored
  reference so restoring does not immediately rewrite settings.
- `reportPosition`, `navigateTo`, `seekTo`, audio-driven seeks, and
  `persistCurrentChapter` all persist full references including the verse.
- `_writeChapterAnchor` (formerly `_writeAnchor`) intentionally ignores the
  reference's verse and writes `verse: 1`. `reanchorToCurrentReference` also
  produces a verse-1 anchor.

# Alternatives

- **Persist the verse in a separate settings key and keep the tuple API.**
  Discarded: one `Reference` is the natural shape at every call site and keeps
  the book/chapter/verse write atomic from the caller's perspective.
- **Use the reading reference as the navigation anchor.** Discarded: panel
  rebuilds are keyed on chapter, so verse-level anchors would rebuild panels on
  every verse crossing.
- **Debounce settings writes.** Deferred: it adds timing semantics and test
  complexity. Per-verse dedupe already collapses the common case of repeated
  reports within one verse.

# References

- `lib/services/settings/user_settings.dart`
- `lib/ui/home/common/navigation_view_model.dart`
- `lib/ui/home/panel_area/common/verse_sync_layout.dart`
- [Serialized View Model Commands](2026-11-25-serialized-view-model-commands.md)
