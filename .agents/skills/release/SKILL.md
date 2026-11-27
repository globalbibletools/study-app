---
name: release
description: Prepare, verify, and tag a Global Bible Tools Study App release (YY.MM.C or YY.MM.C-betaN), including optional localized in-app changelog notes, using the tested CLI at tool/release/release.dart. Use when starting a beta or public release, writing release notes, or tagging an already-merged release PR.
---

# Release

Use this skill to prepare a release branch, add in-app changelog notes, verify
a release, or tag a merged release PR for the Global Bible Tools Study App.

The repository guidance still applies: read `AGENTS.md` and verify changes
with the commands in `docs/DEVELOPMENT.md`.

## Read first

- `references/versioning.md` — the version algorithm, command details, and tag
  guardrails.
- `references/changelog.md` — the localized changelog format, the note input
  format, and the translation workflow.
- `docs/RELEASING.md` — the human-facing version of this workflow.

## Non-negotiable rules

- Never calculate a version by hand. Run `next` from
  `tool/release/release.dart`; it is the source of truth.
- Always use the current date for `YY.MM`. Never continue an older month's
  line.
- `pubspec.yaml` must carry the version without a `+build` suffix. CI owns the
  store build number.
- Changelog entries are optional and apply only to public releases. A public
  release with no user-facing changes uses `--no-changelog` and only updates
  `pubspec.yaml`.
- Never rewrite, reorder, or remove existing changelog entries. A release
  appends exactly one entry per locale.
- Never merge the release PR and never push a tag while preparing a release.
  Tag only after a human has merged the PR.
- Never force-push, delete, or reuse a tag. Use lightweight tags.

## Prepare a release

1. Confirm a clean branch based on `main` and fetch tags:

   ```
   git fetch --tags origin
   git status
   ```

2. Ask the human which kind of release this is and whether it has
   user-facing changes. Determine the version with the tool:

   ```
   dart run tool/release/release.dart next --kind beta
   dart run tool/release/release.dart next --kind public
   ```

3. If there are user-facing changes, follow the note workflow in
   `references/changelog.md`:
   - Draft the notes in English.
   - Propose `major` (what's-new dialog) or `minor` (changelog list only).
   - Wait for the human to confirm the English notes and the type.
   - Translate the approved notes into every existing app locale.
   - Write the input file and pass it to `prepare`.

   ```
   dart run tool/release/release.dart prepare \
     --kind public \
     --version <public-version> \
     --changelog <path-to-notes.json>
   ```

4. If there are no user-facing changes, prepare the public release without a
   changelog, or prepare a beta (betas never add changelog entries):

   ```
   dart run tool/release/release.dart prepare \
     --kind public \
     --version <public-version> \
     --no-changelog

   dart run tool/release/release.dart prepare \
     --kind beta \
     --version <beta-version>
   ```

5. Inspect the diff. `pubspec.yaml` must have the prepared version with no
   build suffix. Every locale changelog must gain the same version, type, and
   date, with translated note text. A re-run with identical input is safe and
   must not duplicate entries.

6. Verify the release, commit, push the branch, and open a PR:

   ```
   dart run tool/release/release.dart verify --tag <tag>
   flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test
   git add ...
   git commit -m "..."
   git push -u origin <branch>
   gh pr create ...
   ```

   The human reviews the translations in the PR. Do not merge.

## Tag a merged release

Only after a human says the PR is merged:

```
dart run tool/release/release.dart tag --tag <tag> --pr <number>
```

The `tag` command refuses to proceed unless the PR is merged, `origin/main`
contains the release commit, the worktree is clean, the release commit's
`pubspec.yaml` matches the tag, and the tag is absent locally and remotely.
It then pushes a lightweight tag. It does not merge anything.

Pushing the tag starts CI. A suffix-free tag is promoted to production; a
`-betaN` tag is a prerelease. CI derives the build number.

## Reporting

When finished, report the version, the PR URL, the changelog locales touched,
and the verification commands and results. If a guard fails, stop and report
it instead of working around it.
