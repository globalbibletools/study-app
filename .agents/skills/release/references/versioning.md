# Versioning

The release CLI lives at `tool/release/release.dart` and uses only
`dart:io` and `dart:convert`. Run it from the repository root with Dart from
the project toolchain (`dart run ...` or `fvm dart run ...`).

## Tag format

New tags match exactly:

```
^(\d{2})\.(\d{2})\.(\d+)(?:-beta([1-9]\d*))?$
```

Examples: `26.10.0`, `26.11.0-beta3`, `26.11.0-beta10`.

- `YY` and `MM` are two digits. `MM` must be `01` through `12`.
- `C` is a non-negative integer.
- `-betaN` starts at `1`; leading zeroes and `beta0` are invalid.
- A tag without a suffix is public. A tag with `-betaN` is a beta
  prerelease.
- Build metadata (`+44`) is never part of a version or tag.

Historical tags such as `26.9.0` predate the zero-padded month scheme and do
not match the pattern. The comparison logic ignores non-matching historical
tags; every tag created or verified by the tool must match the pattern.

## Calculation

Inputs:

- `today` is the release date. It defaults to the current local date; pass
  `--date YYYY-MM-DD` to be explicit.
- Only tags whose `YY.MM` equals `today`'s `YY.MM` participate. Tags from
  another month are irrelevant, even if they are numerically newer.
- `Pm` is the highest public tag in the current month, or none.
- `Bm` is the highest beta tag in the current month, or none.

Ordering within a month is by `C`, then public over beta with the same base,
then beta number. So `26.11.0 > 26.11.0-beta9` and
`26.11.1-beta1 > 26.11.0`.

```
activeBeta = Bm exists and (Pm is none or Bm > Pm)
publicBase = activeBeta ? Bm.base
           : Pm exists  ? today.(Pm.C + 1)
           :              today.0
next beta  = activeBeta ? Bm.base-beta(Bm.N + 1) : publicBase-beta1
next public = activeBeta ? Bm.base : publicBase
```

`C` resets to `0` in each month. `N` starts at `1`.

Examples (dates are explicit):

| Date | Existing tags in that month | Next beta | Next public |
| --- | --- | --- | --- |
| 2026-11-27 | `26.10.0` (October), `26.11.0-beta3` | `26.11.0-beta4` | `26.11.0` |
| 2026-12-15 | `26.10.0`, `26.11.0-beta1..3` | `26.12.0-beta1` | `26.12.0` |
| 2026-11-27 | `26.11.0`, `26.11.0-beta3` | `26.11.1-beta1` | `26.11.1` |
| 2026-11-27 | `26.11.1`, `26.11.2-beta2` | `26.11.2-beta3` | `26.11.2` |
| 2026-11-27 | none in November | `26.11.0-beta1` | `26.11.0` |

The October tags in the first row do not participate: they are a different
`YY.MM` line, and a new version never chains off an older month.

## Commands

```
dart run tool/release/release.dart next --kind beta|public [--date YYYY-MM-DD] [--json]
dart run tool/release/release.dart prepare --kind beta|public --version VERSION [--date YYYY-MM-DD] [--changelog PATH | --no-changelog]
dart run tool/release/release.dart verify --tag TAG
dart run tool/release/release.dart tag --tag TAG [--pr NUMBER]
```

All commands accept an optional `--root PATH` for operating on another
checkout; the default is the current directory. The CLI uses local tags for
`next`; run `git fetch --tags origin` first so the calculation is current.

### `next`

Prints only the version by default. With `--json` it prints:

```json
{
  "kind": "beta",
  "version": "26.11.0-beta4",
  "date": "2026-11-27",
  "month": "26.11",
  "activeBeta": true,
  "publicBase": "26.11.0",
  "nextBeta": "26.11.0-beta4",
  "nextPublic": "26.11.0"
}
```

### `prepare`

- Validates that the supplied version is the exact next version for the kind
  and date. A stale or invented version is rejected.
- Rejects a beta version for `--kind public`, a public version for
  `--kind beta`, and any `+build` metadata.
- Rewrites `pubspec.yaml` to the version with no build suffix.
- For public releases, requires exactly one of `--changelog PATH` or
  `--no-changelog`. Betas must not add a changelog entry.
- Discovers app locales from `lib/l10n/app_<locale>.arb` and requires a
  matching `assets/l10n/changelog_<locale>.json` for each, with no extra
  changelog files. It validates that every locale has the same
  version/type/date sequence and that entries are well formed.
- Appends one entry per locale. It refuses to rewrite an existing entry. If
  the same entry already exists it is left untouched, so re-running an
  identical preparation is safe.
- Validates everything before writing files, so a bad input does not leave a
  half-prepared version.

`pubspec.yaml` never carries a store build number. CI creates the build
number from the workflow run and derives the app version from the tag.

### `verify`

Reads local and remote tags and refuses if the tag:

- does not match the tag format;
- already exists locally or on `origin`;
- is not newer than every existing canonical tag;
- does not match `pubspec.yaml` (including a pubspec with `+build`);
- would ship with inconsistent locale changelogs.

Changelog entry presence is not required: a public release may legitimately
have no user-facing notes.

### `tag`

Refuses to proceed unless:

- the PR is merged (`--pr` or the merged PR for the current branch);
- `origin/main` contains the PR's merge commit (fetched first);
- the worktree is clean;
- the release commit's `pubspec.yaml` matches the tag and has no build
  suffix;
- `verify` passes, including local and remote tag absence.

It then creates and pushes a lightweight tag at the merge commit, in that
order: push the remote ref, then create the local tag. It never merges a PR,
never force-pushes, and never deletes or reuses a tag.

## Month boundaries

`next` always uses the current month. If a release prepared in November is
still unmerged in December, do not tag the November version. Re-run `next`,
prepare the December version, and reopen the release PR. Do not chain a new
release off an older month.
