# Current Phase

**Last completed delivery phase:** Phase 10 — Product record and form workflow refinement  
**Status:** Fully complete — Gates 10a–10e accepted (PR [#128](https://github.com/tswarren/shelfstack-5/pull/128))  
**Phase document:** [phases/phase-10-product-record-and-form-refinement.md](phases/phase-10-product-record-and-form-refinement.md)

**Next delivery phase:** Unscheduled. Candidate sequencing and POS shell revamp stub live under [temp_draft/phase-11/](../temp_draft/phase-11/README.md) (DWR-067) — not governing until promoted.

**Phase 10 closed:** Gates 10a–10e delivered in PR [#128](https://github.com/tswarren/shelfstack-5/pull/128). Follow-on: DWR-066 (rail capability decoupling — revisit before roles grant receipt / purchasing / cost visibility independently of `stock_view`).

**Phase 9 closed:** Gates 9a–9d merged to `main` at `db6778d87f9e10b7890884dcd96437b85e211ec1` (PR [#122](https://github.com/tswarren/shelfstack-5/pull/122)); [ADR-0017](../adr/0017-customer-domain-and-namespace-22.md)

**Phase 8 closed:** Must gates 8a–8d complete ([#95](https://github.com/tswarren/shelfstack-5/issues/95)–[#98](https://github.com/tswarren/shelfstack-5/issues/98); Gate 8d PR [#118](https://github.com/tswarren/shelfstack-5/pull/118)). Should/Nice 8e–8g deferred (DWR-022 / DWR-023 / DWR-027 / DWR-065).

**Phase 7 merge:** `d27d6668312b19d0012fd8d370011c966838f895` (PR [#62](https://github.com/tswarren/shelfstack-5/pull/62)); core gate 7a–7d accepted; **7e partial** ([#94](https://github.com/tswarren/shelfstack-5/issues/94))  
**Phase 6.5 merge:** `bd7fb9d35469027a60c9d3277744fda0a0ed06d9` (PR [#54](https://github.com/tswarren/shelfstack-5/pull/54))  
**Phase 6 merge:** `853ae3b7a31b03960935bb14d8761b3fd19a0258` (PR [#39](https://github.com/tswarren/shelfstack-5/pull/39))

## Immediate next work

1. Schedule the next delivery phase when ready — candidate: DWR-067 POS shell / workspace revamp ([phase-11 drafts](../temp_draft/phase-11/README.md)).
2. Before splitting receipt / purchasing / cost visibility from `stock_view` in roles, resolve DWR-066.
3. Phase 8 deferred Should/Nice remain register-tracked until pulled back (DWR-022 / DWR-023 / DWR-027 / DWR-065).
4. Phase 7 follow-ups remain deferred (`phase-7` + `deferred`); canonical list in [deferred-work-register.md](deferred-work-register.md).
5. Keep posted-receipt correction (`inventory.receipt.correct`) unseeded until a correction workflow is accepted.
6. Retain OD-014 interim post-void block until a full correction algorithm PR is accepted.
7. Do not pull customer-receipt product design or hardware printing into near-term work except as staged under DWR-067 Gate D (DWR-017).
8. Do not open Phase 8.5 / multi-variant (DWR-021) until explicitly scheduled.
9. Full CRM beyond flat Customer v1 remains deferred (DWR-036).
10. Leave DWR-029 (request-coverage extraction from product hub) unscheduled.

## Do not start yet

- Inventing deficit settlement beyond the accepted OD-014 Phase 5 decision.
- Full CRM beyond flat Customer v1 (DWR-036 remainder).
- PWA / offline POS; integrated payments; full ESC/POS fleets.
- Fat POS shell revamp until DWR-067 is promoted to a governing phase plan.
- Scaffolding later_extensions from [deferred-capabilities.md](deferred-capabilities.md).

## Pointers

- Phase 10 plan: [phases/phase-10-product-record-and-form-refinement.md](phases/phase-10-product-record-and-form-refinement.md)
- Post–Phase 10 sequencing (draft): [../temp_draft/phase-11/](../temp_draft/phase-11/README.md)
- Carry-forward backlog: [deferred-work-register.md](deferred-work-register.md)
- Master sequence: [roadmap.md](roadmap.md)
- Design: [../design/README.md](../design/README.md)
- Git workflow: [git-workflow.md](git-workflow.md)
- Phase 9 plan: [phases/phase-09-customer-records.md](phases/phase-09-customer-records.md)
- Customers domain: [../domains/customers.md](../domains/customers.md)
