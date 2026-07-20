# Phase 4g — Test Hardening

**Status:** Ready to start after PR #30 merges  
**Depends on:** Phase 4f UX Baseline Gate accepted and merged to `main`  
**Governing docs:** [../testing/test-review-2026-07-19.md](../testing/test-review-2026-07-19.md), [../testing.md](../testing.md), [AGENTS.md](../../../AGENTS.md) §9

## Characterization

Phase 4g is a **post-merge hardening milestone**. It does not reopen Phase 4 product scope. Its integrity, security/scoping, and critical browser-path work gates substantive Phase 5 implementation. Broader controller and model coverage remains an ongoing test-quality backlog and may continue alongside Phase 5.

## Goal

Close high-risk coverage gaps identified in the 2026-07-19 test review without inventing domain behavior. Fix bugs only when new tests reveal them.

## Delivery order

```text
4g-1  Completion integrity          → Phase 5 principal risk gate
4g-2  Critical endpoint security    → auth, scoping, permission seed-drift
4g-3  Critical system workflows     → register / suspend-recall / recovery
4g-4  High-integrity model/DB tests → focused invariants only
4g-5  Broader backlog               → may run alongside Phase 5
```

### 4g-1 — Completion integrity

- Atomicity failure matrix: receipt-number allocation, cost snapshot, reservation conversion, inventory posting, tender finalization — assert no partial completed state
- Concurrent completion: one winner, one receipt, one sequence increment, one inventory movement set
- Immutability: completed lines, discounts, taxes, tenders; reject cancel/suspend/recall/commercial edits
- Historical snapshots: product, department, tax, tender type, cost unchanged after master edits

### 4g-2 — Critical endpoint authorization and scoping

POS lines, tenders, suspend/recall/cancel/complete, sessions, cash movements, business days, inventory reservation release, stock balances (including cost visibility).

Per endpoint: permission allowed/denied; cross-store rejected; cross-org rejected where relevant; non-editable/completed rejected.

Include permission seed-drift coverage (every enforced key seeded; administrator sync grants them).

### 4g-3 — Critical system workflows

Extend existing Phase 4f system coverage (do not duplicate completed-screen Enter / summary tests):

- scan/add → tender → complete
- suspend → leave → recall → complete or cancel
- validation or failed completion → correct → complete
- one keyboard-only path

### 4g-4 — High-integrity model / DB invariants

`BusinessDay`, `PosSession`, `PosTender`, `PosDiscount`, `PosDiscountAllocation`, `PosCashMovement`, `InventoryReservation`, `StockBalance` (and optionally `PosApproval`, `PosTaxExemption`). Prefer unique indexes, check constraints, FK restrictions, status transitions — not presence-only lookup tests.

### 4g-5 — Broader backlog (alongside Phase 5)

Classification CRUD request coverage; static lookup models; administrative create/update services; broad active/inactive behavior; import-helper test-or-remove; remaining audit items.

## Phase 5 gate

Phase 5 docs, schema exploration, and prototypes may overlap 4g.

**The first substantive Phase 5 migration or domain PR must not merge until:**

- [ ] Concurrent POS completion is covered
- [ ] Completion rollback/atomicity matrix is covered
- [ ] Completed transaction mutation endpoints are rejected
- [ ] Core POS endpoints reject cross-store access
- [ ] Permission seed-drift coverage exists
- [ ] Historical snapshot regression coverage exists
- [ ] Suspend/recall system workflow passes
- [ ] Failed-completion recovery system workflow passes
- [ ] `bin/ci` passes
- [ ] `test:system` passes

That is approximately **4g-1 through 4g-3**.

### Required to begin Phase 5 implementation

Completion atomicity; completion concurrency; completed-record immutability; historical snapshots; critical endpoint auth/scoping; permission drift; core system workflows; green `bin/ci` + `test:system`.

### May remain tracked after Phase 5 begins

Exhaustive admin CRUD; every static lookup model test; all admin service tests; broad active/inactive coverage; import-helper cleanup; minor admin system tests.

## Out of scope

- Reopening Phase 4 product features
- Making `test:system` part of `bin/ci` (optional later)
- Removing existing tests that already align with architectural risk
