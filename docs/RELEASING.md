# Releasing

How a release is prepared, reviewed, merged, and tagged. Agents should also
load [`.agents/skills/release/SKILL.md`](../.agents/skills/release/SKILL.md),
which carries the same rules in agent-facing form, and use the tested tool in
`tool/release/release.dart` for every version calculation.

## Version scheme

Releases are tagged `YY.MM.C` or `YY.MM.C-betaN`, for example `26.10.0` and
`26.11.0-beta3`.

- `YY.MM` is the month of the release and always comes from the current date.
  A release never continues an older month's line.
- `C` is a patch counter that starts at `0` in each month.
- `N` starts at `1` and increases within one beta base.
- A suffix-free tag is a production release. A `-betaN` tag is a prerelease.

The exact calculation is in
[`references/versioning.md`](../.agents/skills/release/references/versioning.md).
Do not compute versions by hand; run:

```
dart run tool/release/release.dart next --kind beta
dart run tool/release/release.dart next --kind public
```

With the tags at the time of writing (`26.10.0` public and `26.11.0-beta3` in
November 2026), those commands print `26.11.0-beta4` and `26.11.0`.

`pubspec.yaml` carries the release version without a `+build` suffix. CI
derives the app version from the tag and owns the store build number.

## In-app changelog

The localized files `assets/l10n/changelog_<locale>.json` are the canonical
notes the app shows. They are append-only: a release appends one entry to
every locale file and never edits or removes earlier entries. `CHANGELOG.md`
is historical and is not updated by this workflow.

Changelog entries are optional. A release with no user-facing changes uses
`--no-changelog` and only updates `pubspec.yaml`. A published entry always
uses the public base version (`26.11.0`, never `26.11.0-beta4` and never a
build number) and the release date in `YYYY-MM-DD` form.

The entry type is `major` or `minor`. Unseen `major` entries trigger the
what's-new dialog; `minor` entries only appear in the changelog list.

The complete note format and translation workflow are in
[`references/changelog.md`](../.agents/skills/release/references/changelog.md).

## Preparation workflow

Do all of this on a short-lived branch. The release PR is reviewed and merged
by a human.

1. Fetch tags and confirm you are on a clean branch from `main`:
   `git fetch --tags origin`.
2. Ask whether the release has user-facing changes. If it does, draft the
   notes in English, propose `major` or `minor`, and wait for a human to
   confirm the notes and type.
3. Translate the approved notes into every app locale. The set of locales
   comes from `lib/l10n/app_*.arb`; every one must have a translation and a
   matching `assets/l10n/changelog_<locale>.json`. The human reviews the
   translations in the PR.
4. Write the changelog input file (format below) and run `prepare`. If there
   are no user-facing changes, run `prepare` with `--no-changelog` instead.

```
dart run tool/release/release.dart prepare \
  --kind public \
  --version 26.11.0 \
  --changelog /tmp/26.11.0-notes.json
```

```
dart run tool/release/release.dart prepare \
  --kind beta \
  --version 26.11.0-beta4
```

`prepare` validates the version against the current tags, refuses build
metadata, updates `pubspec.yaml`, and appends the changelog entry to every
locale. It never rewrites existing entries. Re-running it with identical
input is safe.

5. Inspect `git diff`: `pubspec.yaml` must have the expected version with no
   build suffix, and each locale file must gain exactly one entry with the
   same version, type, and date.
6. Commit, push, and open a PR. Do not merge it and do not push a tag from
   the preparation branch.

```
dart run tool/release/release.dart verify --tag 26.11.0
```

`verify` checks the tag format, that the tag is absent locally and on
`origin`, that the version is newer than existing tags, that `pubspec.yaml`
matches, and that every locale changelog has a consistent version/type/date
sequence.

## Changelog input format

JSON with exactly two keys: `type` and `changes`. `changes` maps every app
locale to its non-empty list of notes.

```json
{
  "type": "minor",
  "changes": {
    "en": [
      "Logs can now be exported for troubleshooting.",
      "Fixed audio playback when changing chapters or audio sources."
    ],
    "es": [
      "Ahora se pueden exportar los registros para solucionar problemas.",
      "Se corrigió la reproducción de audio al cambiar de capítulo o de fuente de audio."
    ],
    "fr": [
      "Les journaux peuvent désormais être exportés pour le dépannage.",
      "Correction de la lecture audio lors du changement de chapitre ou de source audio."
    ],
    "pt": [
      "Agora é possível exportar os registros para solução de problemas.",
      "Corrigida a reprodução de áudio ao mudar de capítulo ou de fonte de áudio."
    ],
    "ar": [
      "أصبح من الممكن تصدير السجلات لحل المشكلات.",
      "تم إصلاح تشغيل الصوت عند تغيير الإصحاح أو مصدر الصوت."
    ]
  }
}
```

The tool rejects unknown locales, missing locales, empty note lists, empty
strings, beta versions, and dates that are not real ISO dates.

## Tagging

Only tag after the release PR has been merged into `main`. `tag` never
merges a PR. It verifies that the PR is merged, that `origin/main` contains
the release commit, that the worktree is clean, that the release commit's
`pubspec.yaml` matches the tag, and that the tag does not exist locally or
remotely. Only then does it push a lightweight tag.

```
dart run tool/release/release.dart tag --tag 26.11.0 --pr 203
```

Without `--pr`, the tool looks for the merged PR for the current branch. If
that is ambiguous, pass the PR number explicitly.

Pushing the tag starts CI. A suffix-free tag is promoted to the production
store tracks; a `-betaN` tag stays prerelease. CI computes the store build
number, so no build number is committed.

Never force-push, delete, or reuse a tag. If a tag push fails, stop and
resolve it with a human instead of retrying with force.

## Month boundaries

If `next` is run in a new month, the version moves to that month even if the
previous month's betas were never promoted. If a release was prepared near
the end of a month and is merged after the month changes, re-run `next` and
prepare a new version for the current month rather than tagging the old
month's line.
