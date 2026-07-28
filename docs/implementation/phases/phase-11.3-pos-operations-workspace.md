# Phase 11.3 — POS Operations Workspace

**Status:** Scheduled (not active) — after Phase 11.2  
**Depends on:** Phase 11.2 (reuse contextual approval / interaction patterns)  
**Epic:** [#165](https://github.com/tswarren/shelfstack-5/issues/165)  
**Source design packet:** [phase-11.12-14-draft-scope.md](../../temp_draft/phase-11.12-14/phase-11.12-14-draft-scope.md) (§ Phase 11.3) — background; this plan is authoritative when active  
**Wireframes:** [wireframes.md](../../design/pos/wireframes.md) — Phase 11.3 section (Ops chrome, Register Ops, Store Ops, open-txn navigation)  
**Governing docs:** [point-of-sale.md](../../domains/point-of-sale.md); ADR-0009; ADR-0011; [phase-07-reporting-and-reconciliation.md](phase-07-reporting-and-reconciliation.md)

Gate issues will be opened when Phase 11.2 nears exit.

---

## 1. Goal

Create a coherent POS-adjacent **Operations** workspace and distinguish:

* **Register Operations** — current POS session, workstation, and drawer  
* **Store Operations** — current business day and activity across the store  

Clarify navigation among **Register**, **Operations**, and **Store Workspace** (return label to normal ShelfStack).

Do not rename the normal application layout to “Store Workspace” persistently; that label is the POS-side return destination.

---

## 2. Characterization

Today Store Operations sits next to Register in the focused POS shell, but one page mixes current-session, drawer, all-store sessions, business-day controls, and X/Z reports. Phase 11.3 formalizes and separates those responsibilities without rewriting posting/close services.

---

## 3. MVP scope (summary)

* Sibling Register / Operations workspaces in the POS environment  
* Register Operations: session open/close, drawer, cash movements / no-sale with clear quick-action vs history boundary, Session X/Z  
* Store Operations: business-day open/close, all store sessions, Day X/Z, surface reconciliation status/links without duplicating full ShelfStack reconciliation  
* Shared operating context (store, business day, session, device, drawer, user, open-transaction status)  
* Explicit open-transaction navigation rules ([OD-P11-03](../decisions/phase-11.3-operations-workspace-boundaries.md))  
* Permissions gate which scopes and actions a user may access  

Detail and acceptance criteria: draft §11.3; promote into gate issues at activation.

---

## 4. Accepted decisions governing this phase

| ID | Topic | Resolution |
| --- | --- | --- |
| OD-P11-02 | Register quick actions vs Operations history | [phase-11.3-operations-workspace-boundaries.md](../decisions/phase-11.3-operations-workspace-boundaries.md) |
| OD-P11-03 | Open-transaction workspace navigation | same decision note |
| OD-P11-04 | Reconciliation placement in Operations | same decision note |

Check refund treatment (OD-P11-01) is accepted for Phase **11.4** — [phase-11.4-check-refund-treatment.md](../decisions/phase-11.4-check-refund-treatment.md).

---

## 5. Out of scope

* Full reconciliation product rewrite (remains ShelfStack reporting)  
* Integrated payments / offline POS  
* Absorbing unbounded Phase 11.4 hardening work  

---

## 6. Phase exit (preview)

Register and Operations are sibling workspaces; Store Workspace is the return label; Register Ops vs Store Ops scopes are clear; context preserved; open-txn rules explicit; permissions enforced. Full criteria in draft § Phase 11.3 acceptance criteria.
