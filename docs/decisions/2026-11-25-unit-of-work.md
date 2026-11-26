# Unit-of-Work Pattern for Database Transactions

- Date: 2026-11-25
- Status: In Review
- Supersedes: None
- Superseded By: None

# Context

Services that need several repository writes to succeed or fail together used
sqflite transactions directly. Each service opened its own
`Database.transaction`, and every repository method took an optional
`executor:` parameter so callers could redirect it into that transaction.
Atomicity was therefore opt-in per call site: forgetting to pass the executor
silently wrote outside the transaction, and validation reads that happened
before the transaction could disagree with the state the writes saw.

Threading `executor:` through every call was boilerplate with no type-level
guarantee that a repository was used inside the transaction it was meant for.
The repositories themselves also opened transactions in some paths (for
example `DaySummaryRepository.upsert` when called without an executor), which
made transaction ownership ambiguous.

# Decisions

**A closure-scoped unit of work on the database:**

```dart
Future<T> unitOfWork<T>(Future<T> Function(UnitOfWork uow) action);
```

It runs `action` inside one sqflite transaction. Success commits; any throw
rolls back. There is intentionally no `commit()` API.

**`UnitOfWork` binds repositories to the transaction executor.** The class
lives in `lib/reading_plan/data_access/unit_of_work.dart` and exposes the five
repositories — `session`, `sessionLog`, `verseState`, `daySummary`, and
`readingPlans` — constructed against the executor for that closure.

**Repositories are executor-free.** Each repository takes its
`DatabaseExecutor` in its constructor and no method accepts an `executor:`
parameter. Repositories never open transactions; atomicity belongs to the unit
of work. The database still exposes repositories bound to its raw connection
for simple reads and tests, but services use the unit of work.

**Services own one scope per operation.** Every service method that touches a
repository does its whole body inside exactly one `unitOfWork`, including
validation reads. Helpers such as `_requireSession` and `_requireReadingPlan`
take the unit-of-work repository as a parameter, closing races between
validation and write. The backup service's export and import paths use the
same mechanism; there is no privileged raw-transaction path.

**Units of work never nest.** Sqflite has no nested transactions. A
`unitOfWork` call inside another, or a service calling another service's
unit-of-work methods while already inside one, is a bug. This rule is stated
in the `unitOfWork` dartdoc.

**Scope.** The pattern currently applies to `ReadingSessionDatabase` only.
`ReadingPlanQueries` backs view models and stays as it is; other databases will
adopt the pattern in later changes.

# Implementation Notes

- `ReadingSessionDatabase.transaction()` was removed once its production
  callers moved to `unitOfWork`.
- The schema `onCreate`/`onUpgrade` code constructs `VerseStateRepository`
  directly against the open-helper database, matching the new constructor
  shape.
- Tests assert both guarantees directly: a successful closure commits all
  repository writes, and a throw rolls all of them back.
- `UnitOfWork.executor` is exposed as a low-level escape hatch for raw queries
  (schema checks and test seeding), not as a reason to bypass the repositories
  in production.

# Alternatives

- **Manual `commit()` / `rollback()` API.** Discarded: callers can forget to
  commit or commit twice, and exceptions between writes would leave the
  transaction open. The closure makes the lifetime unambiguous.
- **Keep `executor:` threading.** Discarded: it is the boilerplate this change
  removes, and it makes atomicity opt-in at every call site rather than the
  default shape of a service operation.
- **Ambient or reentrant transactions.** Discarded: implicit transaction
  discovery across calls hides which operations are actually atomic, and
  sqflite cannot nest transactions anyway. A unit of work is explicit at the
  operation boundary.
- **Repositories opening their own transactions.** Discarded: it makes a
  repository call implicitly atomic, preventing a service from grouping
  several repository calls into one larger transaction and giving transaction
  ownership to the wrong layer.

# References

- `docs/ARCHITECTURE.md` — Database layer
- [Four-Layer Architecture](2026-11-18-four-layer-architecture.md)
- [Dependency Injection](2026-11-18-dependency-injection.md)
