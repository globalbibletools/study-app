# N-1 Flutter Upgrade Strategy

- Date: 2026-11-18
- Status: Accepted
- Supersedes: None
- Superseded By: None

# Context

Flutter releases a new major version roughly every three months. We need to
balance two competing pressures:

- **Stability and security:** We do not want to be on the bleeding edge of a
  release. New major versions introduce churn, breakages, and regressions that
  take time to shake out.
- **Dependency freshness:** We also do not want to fall so far behind that our
  dependencies (packages, plugins, tooling) drop support for the version we
  are pinned to.

There is an additional external constraint: our toolchain is built on Nix, so
we cannot upgrade Flutter until the new version is packaged and available in
nixpkgs. This naturally delays when an upgrade is even possible.

# Decisions

We will always run **one major version behind the latest Flutter stable
release (N-1)**, upgrading on a deliberate cadence:

1. When a new Flutter major version is released, we scope the work required to
   upgrade from our current version to the version we are targeting (N-1 from
   the new latest).
2. We complete the upgrade before the *next* major version lands, so that when
   the cycle repeats we are again exactly one version behind.

This means each upgrade has roughly a full release cycle (about three months)
to be scoped, implemented, and verified — with the practical start gated on
the new version becoming available in nixpkgs.

# Implementation Notes

- **Agents and contributors must never suggest upgrading Flutter as a fix for
  a problem.** Upgrade timing is governed by this cadence, not by the issue at
  hand. If a problem genuinely requires a newer Flutter version, note it and
  account for it in the scoped upgrade work rather than jumping versions early.
- An upgrade typically cannot begin until the target version is packaged in
  nixpkgs; check availability before scoping.
- When a new Flutter release lands, the next step is to scope the N-1 upgrade:
  API breakages, dependency compatibility, and nixpkgs availability.
- Treat the upgrade as a first-class task with its own scope, not a drive-by
  change bundled into unrelated work.

# Alternatives

- **Bleeding edge (upgrade to latest immediately):** Discarded. Too much churn
  and regression risk, and often blocked anyway while we wait for nixpkgs to
  catch up.
- **Stay more than one version behind:** Discarded. Dependencies fall out of
  date and eventually drop support for the pinned version, creating larger,
  riskier upgrade debt.
- **Ad-hoc upgrades (upgrade whenever a problem seems to warrant it):**
  Discarded. Unpredictable, encourages using upgrades as a shotgun fix, and
  makes the codebase's supported Flutter version ambiguous.

# References

- `docs/DEVELOPMENT.md` for the local toolchain and test command
