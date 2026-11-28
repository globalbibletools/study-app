# Release Versioning

- Date: 2026-11-27
- Status: In Review
- Supersedes: None
- Superseded By: None

# Context

The app is released from tags, and `.github/workflows/build.yml` derives the
app version from the tag. A suffix-free tag is promoted to production; a tag
with a suffix is a prerelease. Store build numbers come from the CI run.

Version selection was previously manual. `pubspec.yaml` had drifted from the
release tags and carried a store build number (`26.10.0+44`), even though CI
owns that number. Choosing the next beta or public version required knowing
which tags belonged to the current month and how a public tag outranks a beta
with the same base. That is easy to get wrong, especially across a month
boundary or after a public release follows a beta line.

The in-app changelog was also required to have an entry for the current
`pubspec.yaml` version, so even a release with no user-facing changes could
not ship without inventing notes. The release process itself lived in
individuals' heads and was not available to agents working in parallel.

# Decisions

**Versions are calendar versions: `YY.MM.C` or `YY.MM.C-betaN`.** `YY.MM`
always comes from the current date; a new release never chains off an older
month. Only tags in the current `YY.MM` line participate in the calculation.
`C` is the patch counter and resets to `0` each month. `N` starts at `1`,
increments within a beta base, and a public tag outranks a beta with the same
base. The exact algorithm, with the `Pm`/`Bm`/`activeBeta` definitions, is
implemented in `tool/release/release.dart` and documented in
`.agents/skills/release/references/versioning.md`.

**One tested CLI is the source of truth for release mechanics.** The
standalone Dart program at `tool/release/release.dart` uses only `dart:io`
and `dart:convert` and exposes `next`, `prepare`, `verify`, and `tag`.
Agents and humans do not compute versions by hand. Table-driven tests with
explicit dates and synthetic tag lists keep the calculation independent of
the repository's real tags.

**`pubspec.yaml` never carries a store build number.** It contains the
release version with no `+build` suffix. CI derives the build name from the
tag and the build number from the workflow run. `prepare` sets the version,
and `verify` and `tag` reject a pubspec with metadata or a mismatched
version. The current file is synced to `26.10.0`.

**Changelog entries are optional and belong to public releases only.**
`prepare` can update only `pubspec.yaml` with `--no-changelog`. Beta releases
never add an entry. When there are user-facing changes, the agent drafts
English notes, proposes `major` versus `minor`, and waits for human
confirmation. It then translates the notes into every app locale and supplies
all locales to `prepare`; the human reviews the translations in the release
PR. Entries always use the public base version, an ISO date, and the
localized `assets/l10n/changelog_<locale>.json` files, and are appended
without rewriting history. `CHANGELOG.md` is not modified.

The changelog consistency and well-formedness tests remain. The test that
required an entry for the current `pubspec.yaml` version is removed, because
notes are optional and the release tool now owns the relationship between the
version and the entries.

**Release preparation and tagging are separate human-gated steps.** The
agent prepares a branch, verifies it, and opens a PR. The human merges it. The
`tag` command runs only after that merge and checks that the PR is merged,
`origin/main` contains the release commit, the worktree is clean, the release
commit's `pubspec.yaml` matches the tag, and the tag is absent locally and
remotely. It then pushes a lightweight tag. It never merges a PR, never
force-pushes, and never deletes or reuses a tag. The tag push starts CI,
which promotes suffix-free tags to production and keeps `-betaN` tags as
prereleases.

**The process is available to any Agent Skills-compatible agent.** The skill
lives at `.agents/skills/release/SKILL.md` with detailed rules in
`references/versioning.md` and `references/changelog.md`. The human-facing
workflow is in `docs/RELEASING.md`. Nothing in the skill depends on a
specific agent harness.

# Implementation Notes

- `next` reads local tags; fetch tags first so the calculation is current.
  Historical tags such as `26.9.0` predate the zero-padded month scheme and
  are ignored by comparison. Every new or verified tag must match the strict
  pattern.
- `prepare` validates the requested version against the exact next version
  for the kind and date, validates every locale changelog and the whole note
  input before writing, and treats an identical existing entry as already
  applied so a retry does not duplicate it.
- `verify` reports invalid format, duplicate tags, ordering violations,
  pubspec mismatches, build metadata, and locale sequence inconsistencies.
  It does not require changelog notes for a public release.
- `tag` creates the remote tag from the merge commit and then creates the
  local lightweight tag. If any check fails, nothing is pushed.

# Alternatives

- **Continue selecting versions manually.** Discarded: the month and beta
  rules are mechanical, and manual selection already let the pubspec drift
  and left agents without a reliable rule.
- **Adopt semantic versioning.** Discarded: the project releases monthly and
  the existing tags and CI already use `YY.MM.C[-betaN]`. SemVer would add a
  migration without changing what users see.
- **Keep a build number in `pubspec.yaml`.** Discarded: CI owns store build
  numbers, and a committed build number is stale as soon as another build
  runs.
- **Require changelog notes for every release.** Discarded: it forces
  meaningless notes for maintenance or infrastructure releases. Optional,
  public-only notes keep the in-app changelog honest.
- **Let each agent or CI job compute the next version inline.** Discarded:
  duplicating the month/beta/public rules invites divergence and makes them
  hard to test.
- **Make the instructions pi-specific.** Discarded: the skill lives in the
  cross-agent `.agents/skills/` location and uses only standard Agent Skills
  frontmatter and relative references.

# References

- [In-App Changelog](2026-11-26-changelog.md) — canonical localized notes,
  entry ordering, and `major`/`minor` behavior
- `.github/workflows/build.yml` — tag-derived version, prerelease promotion,
  CI-owned build number
- `docs/RELEASING.md` — human-facing release workflow
- `.agents/skills/release/SKILL.md`,
  `.agents/skills/release/references/versioning.md`,
  `.agents/skills/release/references/changelog.md`
- `tool/release/release.dart` and `test/tool/release_version_test.dart`
