# Unit-of-Work Pattern for Database Access

- Date: 2026-11-25
- Status: In Review
- Supersedes: None
- Superseded By: None

# Context

Services often need several repository reads and writes to succeed or fail
together. Letting each call site open a database transaction directly makes
atomicity opt-in: forgetting it silently writes outside the transaction, and
validation reads performed before the transaction can disagree with the state
the writes see.

Threading a transaction executor through repository calls has the same problem
from the other direction. Every method grows an optional `executor:` parameter,
callers must remember to pass it, and nothing in the type system guarantees a
repository call is actually running in the transaction it was meant for.
Repositories that open their own transactions make ownership even less clear.

# Decisions

**Use a closure-scoped unit of work as the standard way services get atomic
access to a database's repositories.** A database exposes:

```dart
Future<T> unitOfWork<T>(Future<T> Function(UnitOfWork uow) action);
```

It runs `action` inside one transaction. Success commits; any throw rolls back.
There is intentionally no manual `commit()` API.

**`UnitOfWork` binds repositories to the transaction executor.** It exposes the
database's repositories constructed against the executor for that closure, so
every operation made through it participates in the same transaction.

**Repositories are executor-free.** Each repository takes its
`DatabaseExecutor` in its constructor and no method accepts an `executor:`
parameter. Repositories never open transactions; atomicity belongs to the unit
of work. Simple reads may still use repositories bound to the database's raw
connection, but anything that must be atomic goes through a unit of work.

**Services own one scope per operation.** A service method that touches
repositories does its whole body inside exactly one `unitOfWork`, including
validation reads. Helpers that look up existing data take the unit-of-work
repository as a parameter, so validation and writes see the same transaction.
Multi-table operations such as backup export or restore use the same mechanism;
there is no privileged raw-transaction path.

**Units of work never nest.** Sqflite has no nested transactions. Opening a
unit of work inside another, or calling another service's unit-of-work methods
while already inside one, is a bug.

**Apply the pattern going forward.** New database operations use a unit of work,
and existing databases adopt it as they are worked on.

# Implementation Notes

- The unit of work keeps its transaction executor accessible for low-level
  queries and schema work, but production service code should use the bound
  repositories rather than bypassing them.
- Schema `onCreate`/`onUpgrade` code constructs repositories directly against
  the open-helper database, matching the repository constructor shape.
- Tests can use the still-exposed repositories bound to the raw connection for
  setup and simple assertions, or go through `unitOfWork` when they need an
  explicit transaction boundary.

# Alternatives

- **Manual `commit()` / `rollback()` API.** Discarded: callers can forget to
  commit or commit twice, and exceptions between writes would leave the
  transaction open. The closure makes the lifetime unambiguous.
- **Keep `executor:` threading.** Discarded: it is boilerplate, and it makes
  atomicity opt-in at every call site rather than the default shape of a
  service operation.
- **Ambient or reentrant transactions.** Discarded: implicit transaction
  discovery across calls hides which operations are actually atomic, and
  sqflite cannot nest transactions anyway. A unit of work is explicit at the
  operation boundary.
- **Repositories opening their own transactions.** Discarded: it makes a
  repository call implicitly atomic, preventing a service from grouping several
  repository calls into one larger transaction and giving transaction ownership
  to the wrong layer.

# References

- `docs/ARCHITECTURE.md` — Database layer
- [Four-Layer Architecture](2026-11-18-four-layer-architecture.md)
- [Dependency Injection](2026-11-18-dependency-injection.md)
