# Correction Integrity Design Packet (DWR-004 / DWR-005 / DWR-006)

**Status:** Parallel design scratch — **not** Phase 11 implementation  
**Register:** DWR-004, DWR-005, DWR-006  
**Rule:** Phase 11 must not invent or implement these algorithms. Implementation begins only after this packet is accepted.

## Purpose

Produce one coherent correction design that preserves:

* completed POS immutability;
* inventory and stored-value historical integrity;
* auditable reversing / adjusting records;
* clear separation from interim OD-014 post-void blocks.

## Scope

| ID | Topic | Outcome of this packet |
| --- | --- | --- |
| DWR-004 | Posted-receipt correction | Proposed workflow ownership, documents, permissions, inventory/cost effects |
| DWR-005 | Post-settlement post-void | Replacement for OD-014 interim block; eligibility, approvals, cross-domain reversals |
| DWR-006 | Return-containing post-void | Eligibility and reversal path when the original sale already has returns |

## Non-goals

* Implementing services, migrations, or UI during Phase 11.
* Integrated payment chargebacks / processor settlement.
* Soft-editing completed sale lines.

## Required packet contents (acceptance checklist)

1. **Terminology** — correction vs post-void vs return vs adjustment.
2. **Trigger matrix** — which operational mistakes each workflow covers.
3. **Eligibility rules** — business day/session state, tender types, SV/returns interaction.
4. **Record model** — new documents vs reversing lines; no mutation of completed sources.
5. **Inventory effects** — movements only; reservations; individual units.
6. **Stored-value / tender effects** — append-only ledger; original-tender policy.
7. **Authorization** — permissions, numeric authority, approvals (not role names).
8. **Idempotency / concurrency** — duplicate submit and concurrent correction attempts.
9. **Reporting** — how corrections appear on X/Z and historical reports.
10. **Migration from interim blocks** — how OD-014 and return-txn blocks lift.
11. **Open decisions** — any remaining OD that must close before coding.
12. **Test plan** — success/failure/concurrency/reversal cases for the future implementation phase.

## Working notes (to flesh out)

### Shared invariants

```text
Completed POS transactions and completed lines are immutable.
Corrections create new linked records.
Historical reports use completed snapshots, not current master data.
```

### Sequencing preference (not a hard dependency)

```text
Accept this packet
  → Correction workflows implementation phase
  → Reporting / reconciliation hardening (may proceed earlier if design stalls)
```

### References

* [current-phase.md](../../implementation/current-phase.md) program spine
* [phase-06-inventory-correction-and-od-014.md](../../implementation/decisions/phase-06-inventory-correction-and-od-014.md)
* [phase-06-post-void-eligibility-and-cross-domain-reversal.md](../../implementation/decisions/phase-06-post-void-eligibility-and-cross-domain-reversal.md)
* [deferred-work-register.md](../../implementation/deferred-work-register.md) DWR-004–006
* Inventory costing design note under `docs/implementation/design-notes/inventory-costing/`

## Disposition

When accepted, promote binding decisions into:

* an accepted decision note or superseding ADR as needed;
* Domain Spec / Schema / workflow updates;
* a scheduled implementation phase (not Phase 11).

Until then, retain OD-014 interim post-void blocks and keep `inventory.receipt.correct` unseeded.
