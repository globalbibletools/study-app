# Bible Chooser as a Function Seam

- Date: 2026-11-26
- Status: In Review
- Supersedes: None
- Superseded By: None

# Context

The reader settings sheet (see `docs/plans/reader-settings-panel.md`) has a
parallel-Bible toggle whose "on" command must run the Bible chooser dialog
when no Bible is selected, then persist the outcome. The command is issued
from `ReaderSettingsViewModel`, but view models must not know
`BuildContext`, and `chooseBible` needs one to show its dialog.

The pre-sheet code (`HomeManager.togglePanelState`) dodged this by living in
the manager and taking a `BuildContext`, which is why it could not be called
from a view model at all.

# Decisions

`HomeManager.setParallelBibleEnabled` takes the Bible chooser as a
`Future<bool> Function()` parameter (`pickBible`) instead of a
`BuildContext`. The sheet panel supplies `() => chooseBible(context)` from
its own context; the view model forwards it through its serialized command.

This is the function-seam approach from
[Dependency Injection](2026-11-18-dependency-injection.md): a dependency
that would cross a layer boundary becomes a narrow function so the fake is a
one-line lambda, and the view model stays context-free.

# Implementation Notes

- If the toggle is turned on while `currentBible == null`, HomeManager runs
  the seam and keeps the panel off when it returns false (chooser cancelled).
- Tests inject `pickBible: () async => false` to cover the revert path
  without pumping the dialog; one widget test exercises the real
  `chooseBible` dialog end-to-end.
- When chunk 3 replaces the chooser with the resource picker sheet, the seam
  is retargeted in one place (the panel widget).

# Alternatives

- Keep a `BuildContext`-taking method and call it from the panel widget
  directly: splits the command out of the view model, so it escapes the
  `SerialQueue` and the view model no longer reflects the resulting state.
- Pass the context into the view model: violates the view model layer rules
  in `docs/ARCHITECTURE.md`.

# References

- `docs/plans/reader-settings-panel.md` (Chunk 1)
- `lib/ui/home/home_manager.dart` (`setParallelBibleEnabled`)
- `lib/ui/home/settings/reader_settings_view_model.dart`
- `lib/ui/home/settings/reader_settings_panel.dart`
