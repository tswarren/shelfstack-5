# Phase 11.4 — POS Policy and Lifecycle Hardening

**Status:** Scheduled (not active) — after Phase 11.3  
**Depends on:** Phase 11.2 and Phase 11.3  
**Epic:** [#166](https://github.com/tswarren/shelfstack-5/issues/166)  
**Source design packet:** [phase-11.12-14-draft-scope.md](../../temp_draft/phase-11.12-14/phase-11.12-14-draft-scope.md) (§ Phase 11.4) — background; this plan is authoritative when active  
**Governing docs:** [point-of-sale.md](../../domains/point-of-sale.md); [authorization-permissions.md](../../domains/authorization-permissions.md); ADR-0009; ADR-0011; ADR-0012; ADR-0016

Gate issues will be opened when Phase 11.3 nears exit. Before implementation, convert remaining gaps into a **closed inventory** (not an open cleanup bucket).

---

## 1. Goal

Close a predefined inventory of known POS policy, lifecycle, permission, terminology, and integration gaps after Register and Operations workflows have been refined.

Phase 11.4 is integration and hardening. It must not become an unlimited miscellaneous cleanup phase. New requests that do not satisfy an existing Phase 11 contract should be deferred.

---

## 2. Work themes (closed list at activation)

From draft §11.4 (record concrete items in gate issues at start):

* **11.4.1** Approval consistency across Register and Operations  
* **11.4.2** Tender lifecycle consistency (edit/remove/void/recovery terminology and behavior)  
* **11.4.3** Return and refund policy reconciliation (implement accepted [check refund treatment](../decisions/phase-11.4-check-refund-treatment.md) / OD-P11-01)  
* **11.4.4** Session and business-day lifecycle review  
* **11.4.5** Permissions and role boundaries  
* **11.4.6** Terminology and navigation cleanup  
* **11.4.7** Reporting and reconciliation integration checks  
* **11.4.11** Regression and acceptance testing for Phase 11 exit  

Include defects discovered during 11.1–11.3 and tests/docs required for Phase 11 exit.

---

## 3. Accepted decisions needed by this phase

| ID | Topic | Resolution |
| --- | --- | --- |
| OD-P11-01 | Check refund treatment | [phase-11.4-check-refund-treatment.md](../decisions/phase-11.4-check-refund-treatment.md); [architectural-locks.md](../architectural-locks.md#check-refund-treatment-mvp) |

Phase 11.3 Operations boundaries (OD-P11-02–04) are already accepted — [phase-11.3-operations-workspace-boundaries.md](../decisions/phase-11.3-operations-workspace-boundaries.md).

---

## 4. Out of scope

* Inventing deferred capabilities (offline POS, integrated payments, full CRM, store-configurable check-refund policy / DWR-068, etc.)  
* Reopening settled architectural locks (including SV-first refund allocation and check→store-credit default) without a superseding decision  
* Expanding into later_extensions from [deferred-capabilities.md](../deferred-capabilities.md)

---

## 5. Phase exit (preview)

Known Phase 11 gaps are resolved or explicitly deferred; approvals/tenders/returns/ops behave consistently; permissions and terminology are coherent; regression suite covers the ordinary operating lifecycle from business-day open through reconciliation. See draft § Phase 11.4 acceptance criteria and § Phase 11 exit condition.
