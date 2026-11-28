# Architecture Decision Records

* 2026-11-27 [Design Token Mechanism](2026-11-27-design-token-mechanism.md) [In Review]
* 2026-11-27 [Shared Design Foundation](2026-11-27-shared-design-foundation.md) [In Review]
* 2026-11-27 [Single-Constructor Dependency Resolution](2026-11-27-single-constructor-resolution.md) [In Review]
* 2026-11-27 [Release Versioning](2026-11-27-release-versioning.md) [In Review]
* 2026-11-26 [In-App Changelog](2026-11-26-changelog.md) [In Review]
* 2026-11-25 [Serialized View Model Commands](2026-11-25-serialized-view-model-commands.md) [In Review]
* 2026-11-25 [Unit-of-Work Pattern for Database Transactions](2026-11-25-unit-of-work.md) [In Review]
* 2026-11-23 [App-Level Ephemeral Messages](2026-11-23-ephemeral-messages.md) [In Review]
* 2026-11-19 [Vertical Slices](2026-11-19-vertical-slices.md) [In Review]
* 2026-11-18 [Cancel-and-Replace Cancellation](2026-11-18-cancel-and-replace.md) [Superseded]
* 2026-11-18 [Four-Layer Architecture](2026-11-18-four-layer-architecture.md) [Accepted]
* 2026-11-18 [Reactivity Patterns](2026-11-18-reactivity-patterns.md) [Accepted]
* 2026-11-18 [Dependency Injection](2026-11-18-dependency-injection.md) [Superseded]
* 2026-11-18 [N-1 Flutter Upgrade Strategy](2026-11-18-flutter-upgrade-strategy.md) [Accepted]

## Scope

Decision records are for **app-wide architecture decisions only**: patterns,
conventions, or trade-offs that apply across multiple domains/slices or that
someone must understand before working anywhere in the codebase.

## Guidelines

- One decision per file.
- Use the template.md as the decision template
- Name the file timestamp-decision-name.md
- Never silently rewrite an accepted decision.
- Supersede decisions rather than deleting them.
- Reference related decisions.
- Decisions start out as in review until they have been approved
- List decisions in the index from newest to oldest
