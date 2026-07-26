# Post–Phase 10 sequencing (candidate)

**Status:** Proposed planning note — not governing  
**Date:** 2026-07-26  
**Related:** [deferred-work-register.md](../../implementation/deferred-work-register.md); [deferred-capabilities.md](../../implementation/deferred-capabilities.md); [roadmap.md](../../implementation/roadmap.md); [01-phase-11-pos-shell-revamp-stub.md](01-phase-11-pos-shell-revamp-stub.md)

## Purpose

Rank carry-forward work after Phase 10 core for the next delivery phases. Respect POS-forward delivery, the register’s disposition model, and the anti-invention list in `deferred-capabilities.md`.

## Ranking lens

```text
cashier / ops risk
  → unlocks other work
  → already issue-tracked and small
  → design-ready phase candidate
  → later_extensions (no scaffolding)
```

## Clusters

### A — POS shell / cashier product (candidate Phase 11)

| Item | Notes |
| --- | --- |
| **DWR-067** POS shell / workspace revamp | Promote `docs/temp_draft/pos_revamp` → phase plan; see stub |
| DWR-010 keyboard / scanner (#51) | Absorb into Phase 11 Gate E; do not ship a parallel path |
| DWR-017 customer receipt product | Stage into Phase 11 Gate D; full ESC/POS / printer fleets remain later |
| DWR-020 POS lookup adoption | Reuse Gate 8a picker patterns inside POS-native lookup |

### B — Correction integrity (design packet → later phase)

| Item | Notes |
| --- | --- |
| DWR-004 posted-receipt correction | Design first; then seed `inventory.receipt.correct` |
| DWR-005 post-settlement post-void | Replaces OD-014 interim block |
| DWR-006 return-containing post-void | Needs append-only request fulfilment restoration |
| DWR-011 / DWR-012 | After owning-domain correction contracts stabilize |

Run **design in parallel** with Phase 11. Do **not** implement until algorithms are accepted.

### C — Ops settings & control surface (optional thin gate)

| Item | Notes |
| --- | --- |
| DWR-001 OD-009 | Store configuration home |
| DWR-019 | Org / store settings UI |
| DWR-018 | Control-master admin CRUD |
| DWR-003 OD-013 | Authority defaults (may trail OD-009) |
| DWR-007 | Negative-inventory hard block (after OD-009) |

Pull only if receipt header/footer, card grain, or cash-drop thresholds block Phase 11. Otherwise schedule after Gate A or as a short intervening phase.

### D — Reconciliation / reporting carry-forward

| Order | Item |
| --- | --- |
| 1 | DWR-015 org-scoped SV liability (#93) |
| 2 | DWR-016 Phase 7e report pack (#94) |
| 3 | DWR-013 session card grain (#91) |
| 4 | DWR-014 directional / multi-terminal card evidence (#92) |

Good side track while Phase 11 design is accepted, or a short phase after Phase 11 Gate C.

### E — Catalog follow-on (park unless product pressure)

| Prefer if needed | Keep parked |
| --- | --- |
| DWR-022 enrich-existing (#100) | DWR-021 multi-variant / 8.5 |
| DWR-065 vendor-source linking (#99) | DWR-023 / DWR-027 images / BISAC |
| Small folds: DWR-028, DWR-064, DWR-066 | DWR-024 / DWR-025 / DWR-026 / DWR-029 |

### F — Later extensions

DWR-030–DWR-052 = [deferred-capabilities.md](../../implementation/deferred-capabilities.md). No phase until a design packet exists. Soft eventual order: inventory ops (counts → transfers → RTV) → supply chain → commerce policy → platform (payments / offline / accounting) → CRM platform beyond Customer v1.

## Recommended sequence

```text
Phase 10 fully complete (10a–10e, PR #128)
        │
        ├─► optional thin: Ops settings (OD-009 + DWR-018/019)
        │
        ▼
Phase 11 — POS shell / workspace revamp     ← DWR-067
   Gates A–E; absorb DWR-010; stage DWR-017 into Gate D
        │
        ├─► parallel design: Correction integrity (DWR-004/005/006)
        │
        ▼
Phase 12 — Correction workflows (after design accepted)
   then DWR-011 / DWR-012
        │
        ▼
Phase 13 — Reconciliation / reporting hardening
   DWR-015, DWR-016, then DWR-013 / DWR-014
        │
        ▼
Phase 14+ — Catalog Should/Nice or first later-extension design
   (one of enrich-existing / vendor-source / counts — by product pressure)
```

## Decision checkpoints before locking Phase 11+

1. Is the next **user-visible** bet the register shell? → Schedule Phase 11; keep catalog/reporting as side work.
2. Does OD-009 block cash-drop / receipt chrome? → Thin settings gate first.
3. Is correction pain already biting ops? → Prioritize DWR-004–006 design even while Phase 11 Gate A is in flight.
4. Merchant pressure on enrichment or vendor sources? → Pull one catalog DWR; otherwise leave parked.

## Bookkeeping when Phase 11 is scheduled

1. Expand [01-phase-11-pos-shell-revamp-stub.md](01-phase-11-pos-shell-revamp-stub.md) into `docs/implementation/phases/phase-11-…`.
2. Set DWR-067 target to Phase 11; file GitHub issues per gate (or epic + children).
3. Point DWR-010 and DWR-017 at Phase 11 gates; close #51 against Gate E when done.
4. Update `roadmap.md`, `current-phase.md`, and the register bucket summary.
5. Archive or supersede this `temp_draft/phase-11/` folder (same pattern as Phase 10 drafts).
