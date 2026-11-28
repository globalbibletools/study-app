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
missing locale file falls back to English, per file — never per entry. The
service caches only the active locale; when the locale changes it loads the
new locale and replaces the cache. Those assets cannot change until the app
is updated.

**Entries are an ordered array, oldest first, and new releases are appended
at the end.** "Last seen" is the version string stored in user settings
(`lastSeenChangelogVersion`), not an array offset. The service locates that
version in the current file, and everything after it is new. This keeps
persisted state independent of array length and layout, so the file can gain
structure or earlier entries without invalidating what the user has seen.
Entries are still never reordered or removed from the middle, because a
stored version that no longer appears in the file cannot be located; if that
happens, the service reports nothing unseen rather than announcing history.
No `PackageInfo` / semver comparison is needed for update detection: an
entry in the shipped file is by definition at or below the running version.

**Every locale file has the same number of entries with the same version
sequence.** Translation lag is handled per file (ship English copy in the
next release), not by letting locale arrays diverge in length, because a
stored version must be locatable in every locale file. A repo test asserts
this consistency. Release notes are optional for public releases and are
appended by the release tool; see
[Release Versioning](2026-11-27-release-versioning.md).

**Absence of the stored version means fresh install.** First run after this
feature ships (or any fresh install) writes the latest version silently and
notifies nothing, so existing users are not greeted by a modal announcing a
feature they can go find. A stored version that is not the latest version
means an update arrived. Loading entries never advances the marker: the
changelog page writes it after the page has loaded and been shown, so a mere
service read cannot mark unseen entries as seen.

**Each entry has a type: `major` or `minor`.** Unseen major entries trigger
a what's-new dialog; unseen minor entries only appear in the changelog
list. Dismissing the dialog (or reading the full changelog) advances the
stored version to the latest entry. The changelog page is the only place that
marks it seen outside of dialog dismissal, and it does so after its first
frame.

**Every `major` entry has a `summary`; `minor` entries have none.** The
summary is a short paragraph that introduces the release. The what's-new
dialog shows it as its body, with the entry's version as a subtitle near the
title, and the changelog page shows it as a lead paragraph between the
version/date header and the bullet list. Requiring it on major entries keeps
the dialog from ever appearing empty; forbidding it on minor entries keeps
the changelog list from growing a redundant paragraph where no dialog will
use it. The generic dialog message string is removed because the entry now
supplies the copy.

**A dialog, not an ephemeral message, for the what's-new notice.** The
what's-new notice needs actions ("read the changelog" / dismiss), and
ephemeral messages are text plus severity only by decision; the messenger
slice is explicitly not the vehicle for interactive flows.

**Slice layout: `lib/changelog/`.** `ChangelogService` (registered lazily)
loads, parses, and caches the active locale and exposes the seen-version
queries. `ChangelogView.navigateTo` loads the entries from the service before
navigation and hands them to the page together with the service, so the page
only opens with entries and has no loading or error state. The page state
holds those entries, renders them newest first, and marks the latest version
seen after it is shown. There is no view model: the page is a fixed,
already-loaded list with one command. The page never switches locales:
`MaterialApp.locale` comes from settings, which can only change on the
settings page, and that page cannot be open while the changelog is. Widgets
are `ChangelogView` (the page and card list) and, for the update notice,
`ChangelogDialog`.

# Alternatives

- **Storing the last-seen array index.** Discarded: offsets are tied to the
  current array layout, so inserting, pruning, or restructuring entries would
  invalidate persisted state. A version string stays meaningful across those
  changes.
- **Comparing versions with `PackageInfo` or a semver parser.** Discarded:
  locating the stored version in the ordered file needs no platform call and
  no semver parser. The append-only array remains a requirement because the
  stored version must stay present.
- **A per-version presence marker in settings.** Discarded: one string covers
  "everything up through here has been seen," which is all the product needs,
  and it survives any number of skipped releases.
- **Advancing the marker while loading entries.** Discarded: loading is not
  proof that the user saw anything. Only the page being shown, or dismissing
  the dialog, advances the marker.
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
