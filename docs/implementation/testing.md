# Testing Conventions

**Status:** Project mechanics  
**Purpose:** ShelfStack-specific test practice beyond the principles in [AGENTS.md](../../AGENTS.md) §9 and §14.6

Do not restate AGENTS testing categories here. This file answers *how* we build and run tests in this repository.

## Stack

- Minitest
- Rails fixtures for stable master data
- Capybara / Selenium for system tests (explicit; not part of `bin/ci` today)
- Prefer `bin/rails test` and Docker-wrapped variants from AGENTS

## Fixtures vs builders

**Default:** Rails fixtures for organizations, stores, roles, permissions, departments, tax categories, merchandise classes, and other slowly changing masters.

**Operational graphs** (open business day, session, reserved lines, adjustments, completions): use explicit test helper / builder methods that call application services where possible, rather than inserting half-valid rows.

**Do not introduce `factory_bot`** unless fixtures become demonstrably unmanageable for a phase. If introduced, document the reason in this file.

## Naming

```text
test/models/...
test/services/...
test/controllers/... or test/integration/...
test/system/...
test/concurrency/...   # optional folder for multi-connection cases
```

Test method names describe the behavior and outcome:

```text
test "posting opening adjustment increases on_hand and writes ledger"
test "duplicate completion idempotency key returns existing receipt without second movement"
```

## Service tests

- Prefer exercising the public service API.
- May load fixtures for masters.
- Assert DB outcomes (balances, ledger rows, statuses) and returned result objects.
- For money, compare integer cents.

## Idempotency tests

Pattern:

1. Perform the operation with a fixed idempotency key.
2. Capture resulting ids / receipt number / ledger count.
3. Repeat with the same key.
4. Assert no duplicate side effects and same business result returned.

## Concurrency tests

- Use separate database connections (or threads with checked-out connections) against PostgreSQL.
- Contended resources: stock balances, unit reservations, receipt sequence, completion idempotency, stored-value balance (later phases).
- Assert one winner / one failure or serialized success per invariant — never silent double-spend.
- Document helper: e.g. `ConcurrencyHelper.with_connection` (to be added when Phase 3 lands).

## Transactional tests

- Default Rails transactional fixtures/tests are fine for most model/service tests.
- Disable transactional tests only when the scenario requires visible commits across connections (typical concurrency cases). Restore cleanup explicitly.

## Snapshot / historical integrity tests

When a phase completes POS or inventory history:

- Change a master (department name, tax rate, product description, price).
- Assert completed line snapshots and reports still reflect original values.

## Atomicity failure tests

Force a failure after a mid-step (stub/raise inside the service) and assert:

- no inventory movement without completed POS;
- no receipt number consumed;
- no partial tender finalization;
- reservations not left converted if completion rolls back.

## System tests

Mandatory when changing end-to-end cashier or receiving browser paths. Not required for pure service/model work already covered by focused tests.

Run explicitly:

```bash
bin/rails test:system
# or Docker equivalent from AGENTS.md
```

## Commands

Follow [AGENTS.md](../../AGENTS.md) §14.6–14.9. Prefer focused files during development; `bin/ci` before completing a phase slice.

## Phase expectations

| Phase | Extra emphasis |
| --- | --- |
| 1 | Permission evaluation; membership effective dates |
| 2 | Identifier normalization vectors; sale eligibility |
| 3 | Concurrent adjust/reserve; negative available warning path; ledger-only on_hand changes |
| 4c | Idempotent completion; atomicity failure matrix; receipt sequence |
| 4d | Concurrent unit reserve |
| 5+ | Allocation caps; receipt multi-PO line linkage |

## Related

- [AGENTS.md](../../AGENTS.md)
- [open-decisions.md](open-decisions.md)
- [service-catalog.md](service-catalog.md)
