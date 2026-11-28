# Releasing

Release mechanics are defined once, in the release skill and its tested CLI.
This page is the human checklist: the decisions and reviews a release needs
from a person. Agents should load the skill rather than working from this page
alone.

## Source of truth

- [Release skill](../.agents/skills/release/SKILL.md) — agent workflow and
  non-negotiable rules.
- [Versioning](../.agents/skills/release/references/versioning.md) — version
  calculation, command flags, and verification/tag checks.
- [Changelog](../.agents/skills/release/references/changelog.md) — optional
  notes, the `--changelog` input format, and the translation workflow.
- [Release CLI](../tool/release/release.dart) — the tested implementation. Do
  not compute versions or edit release state by hand.
- [Release versioning decision](decisions/2026-11-27-release-versioning.md) —
  why this process exists.

## What humans decide

- Whether the release has user-facing changes.
- The final English notes and whether the entry is `major` or `minor`.
- The translations for every app locale.
- When the release PR is ready to merge.
- When a merged release may be tagged.

## Workflow at a glance

1. **Prepare.** On a short-lived branch from `main`, fetch tags and run the
   release commands described in the skill. If notes are needed, settle the
   English draft, the type, and (for majors) the summary with the agent before
   it translates them. If not, the release uses `--no-changelog`.
2. **Review.** The agent opens the release PR. A human checks the list below
   and reviews the translations.
3. **Merge.** A human merges the release PR. The agent never merges it.
4. **Tag.** Only after the merge, the agent or a human verifies and tags the
   merged release. Tagging starts CI and must never happen during
   preparation.

The four commands, with details in the skill:

```
dart run tool/release/release.dart next --kind beta|public
dart run tool/release/release.dart prepare ...
dart run tool/release/release.dart verify --tag <tag>
dart run tool/release/release.dart tag --tag <tag> --pr <number>
```

## Review checklist

- `pubspec.yaml` has the prepared version with no `+build` suffix.
- Each locale changelog has at most one new final entry, with the same
  version, type, and date across locales, and the translated `changes` have
  been reviewed.
- A `major` entry has a translated `summary` in every locale; a `minor` entry
  has no `summary`.
- Existing changelog entries are unchanged and `CHANGELOG.md` is untouched.
- No release tag exists yet and no agent merged the PR.
- The release branch passes
  `flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test`.
