# In-App Changelog

- Date: 2026-11-26
- Status: In Review
- Supersedes: None
- Superseded By: None

# Context

The app ships release notes in three places today: the repo `CHANGELOG.md`,
per-store metadata, and nowhere in the app itself. Users learn what changed
only if they read the store listing. We want the app to render its own
changelog, per UI locale, and to tell the user when a new version arrives.

# Decisions

**The locale JSON files are the canonical source for in-app notes.**
One file per UI locale under `assets/l10n/changelog_<locale>.json`, following
the localized-asset convention of `LocalizedMarkdownViewer`
(`assets/l10n/<name>_<locale>.md`). Store metadata and `CHANGELOG.md` are
derived or copied from these files, not the other way around, so the five
locales do not drift between the store listings and the in-app list. A
missing locale file falls back to English, per file — never per entry.

**Entries are an ordered array, oldest first, and new releases are appended
at the end.** "Last seen" is therefore an array index stored in user
settings (`lastSeenChangelogIndex`), not a version string. Comparing indices
against the current file decides what is new. This also means no
`PackageInfo` / semver comparison is needed for update detection at all: an
entry in the shipped file is by definition at or below the running version.
The constraint this buys is that entries are never reordered or removed from
the middle; the array only grows at the end. If history is ever pruned, the
stored index must be re-baselined in a settings migration.

**Every locale file has the same number of entries with the same version
sequence.** Translation lag is handled per file (ship English copy in the
next release), not by letting locale arrays diverge in length, because
index comparison across divergent arrays is undefined. A repo test asserts
this consistency and that the current `pubspec.yaml` version has an entry,
so a release cannot ship without notes.

**Absence of the stored index means fresh install.** First run after this
feature ships (or any fresh install) writes the current last index silently
and notifies nothing, so existing users are not greeted by a modal
announcing a feature they can go find. A stored index lower than the last
index means an update arrived.

**Each entry has a type: `major` or `minor`.** Unseen major entries trigger
a what's-new dialog; unseen minor entries only appear in the changelog
list. Dismissing the dialog (or reading the full changelog) advances the
stored index to the latest entry.

**A dialog, not an ephemeral message, for the what's-new notice.** The
what's-new notice needs actions ("read the changelog" / dismiss), and
ephemeral messages are text plus severity only by decision; the messenger
slice is explicitly not the vehicle for interactive flows.

**Slice layout: `lib/changelog/`.** `ChangelogService` (registered lazily)
loads and parses the file and owns the seen-index logic; a page-scoped
`ChangelogViewModel` tames the async load for the changelog page; widgets
are `ChangelogView` (the page and card list) and, for the update notice,
`ChangelogDialog`.

# Alternatives

- **Version-string comparison with `PackageInfo`.** Discarded: the index
  scheme needs no platform call and no semver parser, at the cost of an
  append-only array — a cost we accept.
- **A per-version presence marker in settings.** Discarded: one integer
  covers "everything up to here has been seen," which is all the product
  needs, and it survives any number of skipped releases.
- **Bullets as markdown.** Discarded: `LocalizedMarkdownViewer` exists, but
  per-version cards need structure, and translators should not be writing
  markdown.
- **Renegotiating ephemeral messages to carry actions.** Discarded: one
  consumer does not justify reopening a decision with the messenger's
  scope.

# References

- `docs/ARCHITECTURE.md` — vertical slices, dependency injection
- [App-Level Ephemeral Messages](2026-11-23-ephemeral-messages.md)
- `CHANGELOG.md` — the historical notes to seed the JSON files from
