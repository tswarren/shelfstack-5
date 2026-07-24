# Deferred Work Register

**Status:** Authoritative consolidated backlog for carry-forward work after Phases 1–7  
**Purpose:** One register for open decisions, interim blocks, delivery debt, deferred capabilities, catalog/enrichment candidates, and documentation hygiene  
**Related:** [open-decisions.md](open-decisions.md); [deferred-capabilities.md](deferred-capabilities.md); [architectural-locks.md](architectural-locks.md); [current-phase.md](current-phase.md); [roadmap.md](roadmap.md); [git-workflow.md](git-workflow.md)

## Organization model

Use **both** the register and GitHub—with hard ownership—not one or the other.

```text
Governing docs           → what is true / forbidden / decided
Deferred Work Register   → what remains (index + disposition)
GitHub issues            → what someone can pull into a branch soon
current-phase.md         → what is active right now
```

Matches [git-workflow.md](git-workflow.md): roadmap phases are planning containers; **issues are units of work**; branches are short-lived vehicles.

Do **not** create one GitHub issue per deferred capability. That recreates a second roadmap and pressures premature scaffolding.

### Layer ownership

| Layer | Owns | Does not own |
| --- | --- | --- |
| [open-decisions.md](open-decisions.md) | OD status, needed-by, resolution links | Full backlog narrative |
| [deferred-capabilities.md](deferred-capabilities.md) | Short anti-invention list | Prerequisites, targets, issue links |
| This register | Consolidated DWR-* index, disposition, prerequisite, target, optional GitHub link | Implementation design; ADR text |
| GitHub issues | Actionable `delivery_debt` (and phase epics when useful) | Catalog of forever-deferred capabilities |
| [current-phase.md](current-phase.md) | Active phase focus + immediate next work | Full historical backlog |
| Phase plans / decision notes | Gate scope and accepted algorithms | Living backlog ranking |

### When to create a GitHub issue

Create or keep an issue **only when all** are true:

1. Disposition is `delivery_debt`, **or** an accepted design is ready to implement for an `interim_block` / `open_decision`.
2. Work is small enough to branch (`feat/<phase>-<issue>-…`) or is an explicit epic that will spawn child issues.
3. Someone could start within about one or two phases without inventing unresolved architecture.

**Always issue-tracked today:** DWR-010–DWR-016 ([#51](https://github.com/tswarren/shelfstack-5/issues/51), [#89](https://github.com/tswarren/shelfstack-5/issues/89)–[#94](https://github.com/tswarren/shelfstack-5/issues/94)).

**Issue when pulled into a phase plan (not before):** interim blocks (receipt correction, post-settlement post-void, return-containing post-void), OD-009/010/013 once a decision is proposed, control-master admin CRUD, org/store settings UI, catalog Phase 8 gates.

**Never issue-tracked as open work items:** raw `deferred_capability` rows (buyback, transfers, offline POS, multi-tenant, etc.). Keep them here and in [deferred-capabilities.md](deferred-capabilities.md) until a design packet exists; then promote to `delivery_debt` / a phase plan and **then** file issues.

### Register maintenance rules

1. This register is the **index**; duplicate prose only by link.
2. Every open GitHub delivery-debt issue that is carry-forward must appear as a DWR row with a GitHub column link.
3. Closing an issue updates the DWR row (mark resolved / remove after note) in the same PR when practical.
4. Filing a new carry-forward issue adds or updates the DWR row in the same PR or immediately after.
5. [current-phase.md](current-phase.md) lists only active-phase items; it points here for the rest.
6. Issue labels: `deferred` + domain + originating `phase-N`. No parallel backlog label scheme.
7. GitHub column is a real issue link or `—` — never phantom numbers.
8. Do not file issues for `doc_hygiene` unless multi-PR tracking is required; fix drift in the PR that notices it.
9. Do not make GitHub Projects or milestones the system of record for architecture (repo docs remain authoritative).

### Operating cadence

```text
New gap
  → classify disposition
  → add/update DWR row
  → if open_decision: update open-decisions.md
  → if deferred_capability: update deferred-capabilities.md
  → if ready to implement soon (delivery_debt): create GitHub issue, link in DWR,
    pull into phase plan / current-phase, branch from issue; PR updates docs
  → otherwise: leave register-only until promoted
```

## How to use

1. Prefer this register for “what remains after Phases 1–7?” questions.
2. Keep durable architecture in ADRs / Domain Specs; keep accepted delivery locks in [architectural-locks.md](architectural-locks.md).
3. Keep the short capability list in [deferred-capabilities.md](deferred-capabilities.md) as the anti-invention list; this register adds disposition, prerequisites, and targets.
4. When an item lands or is rejected, update disposition and link the resolution (ADR, decision note, issue close, or phase exit).
5. Do not invent tables/services for `deferred_capability` rows until designed.
6. Follow the [Organization model](#organization-model) for GitHub vs register ownership.

### Disposition values

```text
open_decision      — tracked in open-decisions.md; needs accepted disposition
deferred_decision  — in the OD queue but explicitly deferred (not actively blocking)
interim_block      — temporary product block until an accepted algorithm lands
delivery_debt      — known incomplete delivery; issue-tracked when practical
deferred_capability — explicitly out of scope until designed (see deferred-capabilities.md)
catalog_candidate  — proposed for catalog refinement / enrichment (Phase 8 candidate)
doc_hygiene        — documentation status drift only
```

### Target phase

Use a delivery phase number, `unscheduled`, or `later_extensions` (formerly the Phase 8 catch-all for deferred capabilities). Proposed catalog refinement may claim delivery Phase 8; if so, deferred capabilities move to `later_extensions` / Phase 9+.

---

## Register

| ID | Item | Originating phase | Disposition | Governing decision / doc | Prerequisite | Target phase | GitHub |
| --- | --- | --- | --- | --- | --- | --- | --- |
| DWR-001 | OD-009 — Store configuration home (columns vs `store_configurations` vs policy tables; behavioral thresholds/defaults) | 4a | open_decision | [open-decisions.md](open-decisions.md) OD-009; Phase 7 `card_reconciliation_grain` does **not** settle this | None | unscheduled | — |
| DWR-002 | OD-010 — Unavailable inventory by status (aggregate vs status balances; unit-status / reporting interaction) | 3–5 | open_decision | [open-decisions.md](open-decisions.md) OD-010; [phase-06 inventory / OD-014](decisions/phase-06-inventory-correction-and-od-014.md) | Do not close when adding aggregate `unavailable_delta` | unscheduled | — |
| DWR-003 | OD-013 — Role and store authority defaults (inheritance, admin UI, role-template seeds, one-role-per-membership) | 4b | deferred_decision | [open-decisions.md](open-decisions.md) OD-013; ADR-0011; related to DWR-001 for store defaults | Membership fail-closed interim remains | unscheduled | — |
| DWR-004 | Posted-receipt correction workflow | 5–6 | interim_block | [current-phase.md](current-phase.md); OD-014 non-goals; [inventory costing design note](design-notes/inventory-costing/inventory_workflow_costing_design_note.md) | Accepted correction design (reversing receipts, PO fulfilment, valuation, deficit settlement, allocations/reservations, audit/approval) | unscheduled | — |
| DWR-005 | Post-settlement post-void correction (replace OD-014 interim block) | 6 | interim_block | [phase-06-inventory-correction-and-od-014.md](decisions/phase-06-inventory-correction-and-od-014.md) | Accepted algorithm that safely reverses after later deficit activity | unscheduled | — |
| DWR-006 | Return-containing post-void | 6 | interim_block | [phase-06-post-void-eligibility-and-cross-domain-reversal.md](decisions/phase-06-post-void-eligibility-and-cross-domain-reversal.md) | Append-only Product Request fulfilment restoration | unscheduled | — |
| DWR-007 | Negative-inventory store blocking policy (stricter than sell-after-warning) | 3–4 | deferred_capability | [architectural-locks.md](architectural-locks.md#negative-inventory) | DWR-001 (store config home) | later_extensions | — |
| DWR-010 | 6.5e — Keyboard and scanner stabilization | 6.5 | delivery_debt | [phase-06.5-cashier-workspace.md](phases/phase-06.5-cashier-workspace.md) | None | unscheduled | [#51](https://github.com/tswarren/shelfstack-5/issues/51) |
| DWR-011 | Linked domain correction resolutions | 7 | delivery_debt | [phase-07…](phases/phase-07-reporting-and-reconciliation.md); decision v1 | Stable correction linking contract from owning domains | unscheduled | [#89](https://github.com/tswarren/shelfstack-5/issues/89) |
| DWR-012 | Resolution superseding / post-finalization policy | 7 | delivery_debt | Phase 7 MVP immutability | MVP finalize freeze remains binding | unscheduled | [#90](https://github.com/tswarren/shelfstack-5/issues/90) |
| DWR-013 | Session card grain / merchant-slip close | 7 | delivery_debt | Phase 7a decision note; store `card_reconciliation_grain` | DWR-001 helpful for editable grain | unscheduled | [#91](https://github.com/tswarren/shelfstack-5/issues/91) |
| DWR-014 | Directional / multi-terminal card evidence | 7 | delivery_debt | Phase 7 MVP net-only card comparison | DWR-013 for session grain paths | unscheduled | [#92](https://github.com/tswarren/shelfstack-5/issues/92) |
| DWR-015 | Org-scoped stored-value liability and cache integrity | 7 | delivery_debt | Phase 7e partial; store-scoped SV activity shipped | None | unscheduled | [#93](https://github.com/tswarren/shelfstack-5/issues/93) |
| DWR-016 | Complete Phase 7e report pack | 7 | delivery_debt | [phase-07…](phases/phase-07-reporting-and-reconciliation.md) exit criteria | Core 7a–7d merged (PR [#62](https://github.com/tswarren/shelfstack-5/pull/62)) | unscheduled | [#94](https://github.com/tswarren/shelfstack-5/issues/94) |
| DWR-017 | Customer receipt product (templates, gift receipts, ESC/POS / printer queues) | 7 park | delivery_debt | [phase-7-optional-receipt-printing.md](../temp_draft/phase-7-optional-receipt-printing.md) (non-governing) | Explicit product design; not Phase 7 core | later_extensions | — |
| DWR-018 | Admin CRUD for seed-only control masters (`tender_types`, `cash_movement_types`, `stored_value_adjustment_reasons`) | 4f / 6 | delivery_debt | [phase-04f-ux-baseline.md](phases/phase-04f-ux-baseline.md) Deferred UX | Classification manage permissions pattern | unscheduled | — |
| DWR-019 | Organization / store settings UI gap (address, SAN, receipt header/footer, card grain, org defaults) | 1 / 7 | delivery_debt | Store schema + `StoresController` strong params; no org UI | DWR-001 for behavioral settings home | unscheduled | — |
| DWR-020 | Searchable record-picker / nested combobox (shared linking UX) | 4f | delivery_debt | Phase 8 gate 8a; [phase-08…v1](decisions/phase-08-catalog-refinement-and-enrichment-v1.md) | Design-system Stimulus/Turbo pattern | Phase 8 | [#95](https://github.com/tswarren/shelfstack-5/issues/95) |
| DWR-021 | Multi-variant unlock (`single` / `named`) | 2 | catalog_candidate | OD-P8-07 accepted direction; delivery deferred — [phase-08…v1](decisions/phase-08-catalog-refinement-and-enrichment-v1.md) | Phase 8.5 cross-domain packet before schema unlock | Phase 8.5 | — |
| DWR-022 | Bibliographic enrichment (ISBNdb / Google Books create + enrich-existing) | — | delivery_debt | OD-P8-01, 04, 09, 10 accepted — [phase-08…v1](decisions/phase-08-catalog-refinement-and-enrichment-v1.md); plan [phase-08…](phases/phase-08-catalog-refinement-and-enrichment.md) | Provider credentials; Gates 8b–8c / 8f | Phase 8 | [#96](https://github.com/tswarren/shelfstack-5/issues/96), [#97](https://github.com/tswarren/shelfstack-5/issues/97), [#100](https://github.com/tswarren/shelfstack-5/issues/100) |
| DWR-023 | Creators (core) + product images (8g) | — | delivery_debt | Creators OD-P8-02; images OD-P8-03 — [phase-08…v1](decisions/phase-08-catalog-refinement-and-enrichment-v1.md) | Creators before create-from-ISBN; images only when `remote_display_permitted`+ | Phase 8 | [#96](https://github.com/tswarren/shelfstack-5/issues/96) (creators), [#101](https://github.com/tswarren/shelfstack-5/issues/101) (images) |
| DWR-024 | Publisher/manufacturer party model vs string field | proforma | deferred_decision | OD-P8-06 deferred — [phase-08…v1](decisions/phase-08-catalog-refinement-and-enrichment-v1.md) | ONIX / publisher feeds / multi-role party need | later_extensions | — |
| DWR-025 | Product merge / canonical identifier correction workflows | 2 | catalog_candidate | Catalog permissions foreshadow; out of Phase 8 core | Controlled process design | unscheduled | — |
| DWR-026 | Store-specific pricing | catalog | catalog_candidate | [catalog-and-products.md](../domains/catalog-and-products.md) open questions | Price-resolution service boundary | later_extensions | — |
| DWR-027 | BISAC / external subject → merchandise class mapping | — | delivery_debt | OD-P8-05 accepted — [phase-08…v1](decisions/phase-08-catalog-refinement-and-enrichment-v1.md) | Optional Gate 8g | Phase 8 | [#101](https://github.com/tswarren/shelfstack-5/issues/101) |
| DWR-030 | Detailed buyback | — | deferred_capability | [deferred-capabilities.md](deferred-capabilities.md) | Dedicated acquisition design | later_extensions | — |
| DWR-031 | Inventory counts | — | deferred_capability | deferred-capabilities | Count document design | later_extensions | — |
| DWR-032 | Inter-store transfers | — | deferred_capability | deferred-capabilities | Transfer ownership workflow | later_extensions | — |
| DWR-033 | Complete RTV | — | deferred_capability | deferred-capabilities; reserved unit statuses | RTV documents | later_extensions | — |
| DWR-034 | Optional shelf-location tracking | — | deferred_capability | deferred-capabilities | Must not fragment store inventory | later_extensions | — |
| DWR-035 | Weighted / decimal quantities | — | deferred_capability | deferred-capabilities | Explicit quantity model change | later_extensions | — |
| DWR-036 | Full customer CRM | 5 | deferred_capability | OD-006 v1 opaque `customer_reference` | Customer domain design | later_extensions | — |
| DWR-037 | Customer notifications platform | — | deferred_capability | deferred-capabilities | After customer domain | later_extensions | — |
| DWR-038 | Richer customer holds / special orders beyond requests | 5 | deferred_capability | deferred-capabilities | Extend Product Requests carefully | later_extensions | — |
| DWR-039 | Loyalty | — | deferred_capability | deferred-capabilities | Separate domain | later_extensions | — |
| DWR-040 | Automated replenishment / forecasting | 5 | deferred_capability | deferred-capabilities | Manual replenishment in Phase 5 | later_extensions | — |
| DWR-041 | Full frontlist / ONIX campaign management | 5 | deferred_capability | deferred-capabilities; Phase 5 ordering boundaries | Campaign tooling design | later_extensions | — |
| DWR-042 | Vendor EDI / acknowledgements / cascading | 5 | deferred_capability | [phase-05-ordering-scope…](phase-05-ordering-scope-and-future-lifecycle-boundaries.md) | Lifecycle design | later_extensions | — |
| DWR-043 | Reusable tax exemptions | 4b | deferred_capability | ADR-0014; deferred-capabilities | Exemption master design | later_extensions | — |
| DWR-044 | Selected-line / selected-component tax exemptions | 4b | deferred_capability | deferred-capabilities (`whole_transaction` only today) | `pos_tax_exemption_applications` design | later_extensions | — |
| DWR-045 | Tax-inclusive pricing | 4b | deferred_capability | ADR-0014 | Pricing policy | later_extensions | — |
| DWR-046 | Jurisdiction-configurable line-level tax rounding | 4b | deferred_capability | ADR-0014 hybrid v1 | Rounding policy ADR | later_extensions | — |
| DWR-047 | Advanced promotions | — | deferred_capability | deferred-capabilities | Promotion definitions | later_extensions | — |
| DWR-048 | Stored-value replacement, transfer, expiration | 6 | deferred_capability | ADR-0012; stored-value v1 policy | Ledger baseline first | later_extensions | — |
| DWR-049 | Integrated payments; processor settlement; chargebacks; external discrepancy reconciliation | 6–7 | deferred_capability | ADR-0016 standalone card | Processor integration design | later_extensions | — |
| DWR-050 | Offline POS | — | deferred_capability | deferred-capabilities | Dedicated architecture | later_extensions | — |
| DWR-051 | Accounting export batches | — | deferred_capability | deferred-capabilities; OD-008 GL codes provisional | Target accounting system | later_extensions | — |
| DWR-052 | Multi-tenant SaaS | — | deferred_capability | INV-ORG-001 single-org install | Platform redesign | later_extensions | — |
| DWR-060 | Phase 7 phase-doc status header drift | 7 | doc_hygiene | Resolved 2026-07-23 — phase-07 status aligned with current-phase | Re-sync on each status change | — | — |
| DWR-061 | Roadmap Phase 5 follow-up #33 stale after close | 5 | doc_hygiene | Resolved 2026-07-23 — roadmap marks [#33](https://github.com/tswarren/shelfstack-5/issues/33) closed | — | — | — |
| DWR-062 | Phase 4f deferred UX partly addressed in 6.5; reclassify remainder | 4f / 6.5 | doc_hygiene | Resolved 2026-07-23 — 4f Deferred UX table points at this register | Keep remainder rows (DWR-010, DWR-017–DWR-020) current | — | — |
| DWR-063 | Roadmap Phase 8 label vs catalog-refinement candidate | 8 | doc_hygiene | Resolved 2026-07-24 — Phase 8 is catalog refinement; deferred capabilities are later extensions | Promote temp draft to `phases/phase-08-…` when scoping accepted | Phase 8 | — |

---

## Bucket summary

```text
Open / deferred decisions:     DWR-001 … DWR-003 (+ DWR-007 near OD-009)
Interim correction blocks:     DWR-004 … DWR-006
Phase 6.5 / 7 carry-forward:   DWR-010 … DWR-019
Catalog / Phase 8:            DWR-020 … DWR-027 (021 → 8.5; 024 deferred)
Later extensions:              DWR-030 … DWR-052  (= deferred-capabilities.md)
Doc hygiene:                   DWR-060 … DWR-063
```

## Phase 8 naming

Delivery Phase 8 is **Catalog refinement & enrichment** ([roadmap.md](roadmap.md); [phase plan](phases/phase-08-catalog-refinement-and-enrichment.md)). [deferred-capabilities.md](deferred-capabilities.md) is **later extensions** (not Phase 8).

- treat catalog rows (`catalog_candidate`) as Phase 8 scope candidates;
- treat `deferred_capability` rows as `later_extensions`;
- promote the temp draft to `phases/phase-08-…` before implementation branches.

## Maintenance

When closing a GitHub issue or accepting an OD:

1. Update the register row (disposition → resolved note, or remove after archive).
2. Update [open-decisions.md](open-decisions.md) or [deferred-capabilities.md](deferred-capabilities.md) if that file still lists the item.
3. Reflect active work in [current-phase.md](current-phase.md).
