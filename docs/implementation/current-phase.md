# Current Phase

**Active delivery phase:** Phase 11 — POS Shell and Workspace Revamp  
**Status:** In progress — Gate 11A (Slices 1–3 in PRs [#139](https://github.com/tswarren/shelfstack-5/pull/139)–[#141](https://github.com/tswarren/shelfstack-5/pull/141))  
**Phase document:** [phases/phase-11-pos-shell-and-workspace-revamp.md](phases/phase-11-pos-shell-and-workspace-revamp.md)  
**Epic:** [#130](https://github.com/tswarren/shelfstack-5/issues/130)  
**Gates:** [#131](https://github.com/tswarren/shelfstack-5/issues/131) (11A) · [#132](https://github.com/tswarren/shelfstack-5/issues/132) (11B) · [#133](https://github.com/tswarren/shelfstack-5/issues/133) (11C) · [#134](https://github.com/tswarren/shelfstack-5/issues/134) (11D) · [#135](https://github.com/tswarren/shelfstack-5/issues/135) (11E)

**Last completed delivery phase:** Phase 10 — Product record and form workflow refinement (PR [#128](https://github.com/tswarren/shelfstack-5/pull/128))

**Phase 10 closed:** Gates 10a–10e delivered in PR [#128](https://github.com/tswarren/shelfstack-5/pull/128). Follow-on: DWR-066 (triggered invariant — revisit before roles grant receipt / purchasing / cost visibility independently of `stock_view`).

**Phase 9 closed:** Gates 9a–9d merged to `main` at `db6778d87f9e10b7890884dcd96437b85e211ec1` (PR [#122](https://github.com/tswarren/shelfstack-5/pull/122)); [ADR-0017](../adr/0017-customer-domain-and-namespace-22.md)

**Phase 8 closed:** Must gates 8a–8d complete ([#95](https://github.com/tswarren/shelfstack-5/issues/95)–[#98](https://github.com/tswarren/shelfstack-5/issues/98); Gate 8d PR [#118](https://github.com/tswarren/shelfstack-5/pull/118)). Should/Nice 8e–8g deferred (DWR-022 / DWR-023 / DWR-027 / DWR-065).

**Phase 7 merge:** `d27d6668312b19d0012fd8d370011c966838f895` (PR [#62](https://github.com/tswarren/shelfstack-5/pull/62)); core gate 7a–7d accepted; **7e partial** ([#94](https://github.com/tswarren/shelfstack-5/issues/94))  
**Phase 6.5 merge:** `bd7fb9d35469027a60c9d3277744fda0a0ed06d9` (PR [#54](https://github.com/tswarren/shelfstack-5/pull/54))  
**Phase 6 merge:** `853ae3b7a31b03960935bb14d8761b3fd19a0258` (PR [#39](https://github.com/tswarren/shelfstack-5/pull/39))

## Immediate next work

1. Start Gate 11A ([#131](https://github.com/tswarren/shelfstack-5/issues/131)) — stable register foundation (shell, Ready, core Transaction).
2. Optional independent maintenance (not a Phase 11 gate): DWR-028 ([#116](https://github.com/tswarren/shelfstack-5/issues/116)) and DWR-064 ([#120](https://github.com/tswarren/shelfstack-5/issues/120)) — brief under [temp_draft/phase-11/00-pre-phase-11-maintenance.md](../temp_draft/phase-11/00-pre-phase-11-maintenance.md).
3. Parallel design (not Phase 11 implementation): Correction Integrity Design Packet for DWR-004 / DWR-005 / DWR-006.
4. Conditional enablers only if a gate is blocked: DWR-001 / DWR-018 / DWR-019.
5. Triggered invariant: resolve DWR-066 before any role grants receipt / PO / cost visibility without `stock_view`.
6. Keep posted-receipt correction (`inventory.receipt.correct`) unseeded until a correction workflow is accepted.
7. Retain OD-014 interim post-void block until a full correction algorithm is accepted.
8. Do not open Phase 8.5 / multi-variant (DWR-021) until explicitly scheduled.
9. Full CRM beyond flat Customer v1 remains deferred (DWR-036).
10. Phase 7 follow-ups (#89–#94) and catalog Should/Nice remain register-tracked until pulled.

## Program spine (preference)

```text
Phase 11 (active)
  → Correction workflows (after DWR-004–006 design packet accepted)
  → Reporting / reconciliation hardening (DWR-015/016 may proceed earlier if design stalls)
```

Archived prioritization matrix: [../archive/phase-11-drafts-2026-07-26/00-pre-phase-11-prioritization.md](../archive/phase-11-drafts-2026-07-26/00-pre-phase-11-prioritization.md)

## Do not start yet

- Inventing deficit settlement beyond the accepted OD-014 Phase 5 decision.
- Implementing DWR-004–006 before the Correction Integrity Design Packet is accepted.
- Full CRM beyond flat Customer v1 (DWR-036 remainder).
- PWA / offline POS; integrated payments; full ESC/POS fleets.
- Scaffolding later_extensions from [deferred-capabilities.md](deferred-capabilities.md).

## Pointers

- Phase 11 plan: [phases/phase-11-pos-shell-and-workspace-revamp.md](phases/phase-11-pos-shell-and-workspace-revamp.md)
- Carry-forward backlog: [deferred-work-register.md](deferred-work-register.md)
- Master sequence: [roadmap.md](roadmap.md)
- Design: [../design/README.md](../design/README.md)
- Git workflow: [git-workflow.md](git-workflow.md)
- Active scratch: [../temp_draft/phase-11/](../temp_draft/phase-11/README.md)
- Phase 10 plan: [phases/phase-10-product-record-and-form-refinement.md](phases/phase-10-product-record-and-form-refinement.md)
