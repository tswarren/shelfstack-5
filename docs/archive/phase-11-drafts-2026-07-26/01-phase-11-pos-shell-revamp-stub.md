# Phase 11 — POS Shell and Workspace Revamp (stub)

**Status:** Proposed — not yet scheduled; expand and promote when next delivery phase is scheduled  
**Depends on:** Phase 10 fully complete (Gates 10a–10e, PR [#128](https://github.com/tswarren/shelfstack-5/pull/128)); Phase 6.5 cashier workspace on `main`; Phase 9 Customer v1  
**Chronologically follows:** Phase 10 — Product record and form workflow refinement  
**Register:** [DWR-067](../../implementation/deferred-work-register.md)  
**Governing docs (at promotion):** [pos-register-ui.md](../../design/pos-register-ui.md); [scanner-and-hotkeys.md](../../design/scanner-and-hotkeys.md); [accessibility.md](../../design/accessibility.md); [point-of-sale](../../domains/point-of-sale.md); ADR-0009; ADR-0011; [ADR-0016](../../adr/0016-treat-standalone-credit-card-activity.md); [ADR-0017](../../adr/0017-customer-domain-and-namespace-22.md)  
**Source drafts (non-governing until promoted):**

- [pos_revamp/00-pos-shell-and-workspace-overview.md](../pos_revamp/00-pos-shell-and-workspace-overview.md) — workspace contract
- [pos_revamp/01-pos-shell-workspace-support-domains.md](../pos_revamp/01-pos-shell-workspace-support-domains.md) — supporting lookups / documents
- [pos_revamp/03-pos-shell-and-workspaec-recommended-milestones.md](../pos_revamp/03-pos-shell-and-workspaec-recommended-milestones.md) — slices 1–12 and gates A–E

> **Naming note:** Delivery Phase 11 is the POS shell revamp. System-overview “later operational extensions” remain [deferred-capabilities.md](../../implementation/deferred-capabilities.md), not this phase.

## 1. Characterization

Phase 11 is a **cashier workspace product phase**. It upgrades the register from the Phase 6.5 interaction gate into the dedicated shell described in the POS revamp drafts: authoritative Ready / Transaction / Tender / Recovery / Receipt presentations, scan-to-start without empty transactions, POS-native supporting lookups, and hardened keyboard / focus behavior.

It builds on capabilities ShelfStack already has (sale, return, open ring, SV, tenders, suspend/recall, complete, post-void eligibility, Customer v1 attach). It is **not** a domain-expansion phase for payments, offline, or full receipt hardware fleets.

It must **not**:

- invent deferred capabilities ([deferred-capabilities.md](../../implementation/deferred-capabilities.md));
- treat browser UI state as authoritative presentation;
- create empty transactions from navigation, staging a Customer, or selecting an entry intent;
- introduce Node.js, a JS bundler, ViewComponent, or an SPA;
- build Register Lock, session takeover, acting-user switching, or cross-device control (explicitly deferred in the workspace overview §14);
- invent integrated payment-terminal automation (ADR-0016 standalone card remains);
- absorb posted-receipt correction or post-settlement post-void algorithms (DWR-004–DWR-006 stay design-first elsewhere).

## 2. Goal

Make the ordinary path feel like one continuous register:

```text
Ready → scan → Transaction → Tender → Complete → Receipt → Ready
```

with Recovery reserved for uncertain financial conditions (initially `void_required`), and supporting Product / Customer / Stored Value / Receipt / Pickup work inside the shell.

## 3. Delivery gates (from milestone slices)

Promote the twelve vertical slices into five exit gates. Each gate ships domain/service/UI/tests together — not models-first then screens.

| Gate | Slices | Cashier outcome |
| --- | --- | --- |
| **A — Stable register foundation** | 1–3 | Enter register; scan/build ordinary sale; suspend/cancel; restore after refresh |
| **B — Complete transaction entry** | 4–7 | Product lookup; Customer stage/attach; returns; Open Ring; pickup; SV issue/reload |
| **C — Financial completion** | 8–9 | Cash then card/SV/split tender; atomic completion; safe return-to-Transaction |
| **D — Customer-facing completion** | 10 | Customer receipt, gift receipt, SV slip, reprint, Receipt Lookup (DWR-017 staged here) |
| **E — Release readiness** | 11–12 | Narrow Recovery (`void_required`); keyboard/scanner/a11y matrix (absorbs **DWR-010** / #51) |

Suggested dependency order (detail in milestones draft):

```text
1 Shell/resolver → 2 Ready/first sale → 3 Core Transaction
        → 4 Product lookup ∥ 5 Customer
        → 6 Return/Open Ring → 7 Pickup/SV lines
        → 8 Cash tender → 9 Card/SV/split
        → 10 Receipt docs → 11 Recovery → 12 Hardening
```

Customer records (Slice 5) are largely delivered by Phase 9; Phase 11 consumes them inside the shell rather than re-scoping the Customer domain.

## 4. Register and issue mapping

| Carry-forward | Phase 11 disposition |
| --- | --- |
| DWR-067 | This phase epic |
| DWR-010 (#51) | Gate E — close when keyboard/scanner matrix accepted |
| DWR-017 | Gate D product scope; ESC/POS fleets / advanced print infra stay later_extensions |
| DWR-020 | POS-native lookup may adopt shared picker patterns; keep PO/receipt nested-line follow-on separate |

**File GitHub issues only when this stub is promoted** (register organization model): prefer one epic + gate issues, or slice issues under Gate A–E — not one issue per deferred capability.

## 5. Optional enablers (not Phase 11 exit)

Pull only if they block Gate A/D UX:

- OD-009 / DWR-019 — store settings home (receipt header/footer, card grain, cash-drop thresholds)
- DWR-018 — control-master admin CRUD

Otherwise leave on the register for a thin ops-settings gate or a later phase.

## 6. Explicit non-goals (this phase)

- Register Lock / session takeover / acting-user switching
- Integrated card-terminal control; processor settlement
- Offline POS / PWA
- Posted-receipt correction; post-settlement and return-containing post-void algorithms
- Full CRM beyond Customer v1; loyalty; promotions
- Multi-variant unlock (DWR-021)
- Accounting export; multi-tenant

## 7. Exit criteria (draft)

Phase 11 exits when Gates A–E are accepted and:

1. Presentation is always derived from persisted business facts; refresh never mutates transactions.
2. First valid customer work creates the transaction atomically; failed first actions leave no empty transaction.
3. Tender locks commercial editing; return to Transaction is allowed only when tender state is safe.
4. Completion remains atomic and idempotent (ADR-0009); print failure does not reverse completion.
5. Recovery is a closed list starting with `void_required` (ADR-0016); ordinary validation stays inline.
6. Keyboard/scanner/focus/live-region contract passes the Gate E journey matrix (includes DWR-010).
7. Design docs (`pos-register-ui.md`, `scanner-and-hotkeys.md`) are updated to match shipped behavior.
8. DWR-067 marked resolved (or residual explicitly re-registered); #51 closed or re-homed with cause.

## 8. Bookkeeping at scheduling time

1. Rename/expand this stub into `docs/implementation/phases/phase-11-pos-shell-and-workspace-revamp.md` (final title TBD).
2. Add Phase 11 row to [roadmap.md](../../implementation/roadmap.md); set [current-phase.md](../../implementation/current-phase.md).
3. Update DWR-067 target to Phase 11; link epic/issues.
4. Point DWR-010 / DWR-017 rows at Gates E / D.
5. Keep correction design (DWR-004–006) listed as parallel non-blocking work in `current-phase.md`.
