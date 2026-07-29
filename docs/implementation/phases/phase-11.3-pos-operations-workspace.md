# Phase 11.3 — POS Operations Workspace

**Status:** Active — after Phase 11.2 close  
**Depends on:** Phase 11.2 complete on `main` (reuse contextual approval / interaction patterns)  
**Primary register items:** Sibling Register / Operations workspaces; Register Ops vs Store Ops scopes; open-transaction navigation; recon status/links  
**Source design packet:** [phase-11.12-14-draft-scope.md](../../temp_draft/phase-11.12-14/phase-11.12-14-draft-scope.md) (§ Phase 11.3) — background only; this plan is authoritative  
**Wireframes:** [wireframes.md](../../design/pos/wireframes.md) — Phase 11.3 section  
**Governing docs:** [point-of-sale.md](../../domains/point-of-sale.md); ADR-0009; ADR-0011; [phase-07-reporting-and-reconciliation.md](phase-07-reporting-and-reconciliation.md); [phase-11.3-operations-workspace-boundaries.md](../decisions/phase-11.3-operations-workspace-boundaries.md); [architectural-locks.md](../architectural-locks.md#phase-113-operations-workspace-boundaries)  
**Epic:** [#165](https://github.com/tswarren/shelfstack-5/issues/165)  
**Gate issues:** [#169](https://github.com/tswarren/shelfstack-5/issues/169) (11.3A) · [#170](https://github.com/tswarren/shelfstack-5/issues/170) (11.3B) · [#171](https://github.com/tswarren/shelfstack-5/issues/171) (11.3C) · [#172](https://github.com/tswarren/shelfstack-5/issues/172) (11.3D) · [#173](https://github.com/tswarren/shelfstack-5/issues/173) (11.3E)

---

## 1. Characterization

Phase 11.3 creates a coherent POS-adjacent **Operations** workspace and distinguishes:

* **Register Operations** — current POS session, workstation, and drawer  
* **Store Operations** — current business day and activity across the store  

**Store Workspace** is the return label from the focused POS shell to normal ShelfStack — not a persistent rename of the back-office app.

It does **not** rewrite close, cash-movement, report, or reconciliation posting services. Work is UI/navigation reorganization plus explicit open-transaction leave rules (OD-P11-03).

---

## 2. Goal

* Sibling Register / Operations workspaces in the focused POS environment  
* Clear Register Ops vs Store Ops scopes (no mixed page without hierarchy)  
* Cash Movement / No Sale quick actions on Register Ready; authoritative history in Register Ops (OD-P11-02)  
* Active transactions stay in Register until complete / explicit suspend / explicit cancel (OD-P11-03)  
* Operations surfaces reconciliation status and permission-gated links only (OD-P11-04)  

---

## 3. Code reality (do not treat as greenfield)

| Area | Today (pre-11.3) |
| --- | --- |
| Ops page | Mixed `GET /register/store_operations` — session close, cash history, all-day sessions, day open/close |
| Header | “Store Operations” link; no Operations sibling / Store Workspace label |
| Cash Movement / No Sale | Ready overlays; history only on mixed ops page |
| Open day / session | Ready next-required actions when missing |
| Leave-Register | Store-switch / sign-out guarded; Operations navigation not |
| Recon | Links on Session/Day Z and Reports; not on ops page |

---

## 4. Scope by gate

### 11.3A — Operations chrome and sibling shell ([#169](https://github.com/tswarren/shelfstack-5/issues/169))

* Header: `[Register] [Operations]` + `[Store Workspace]`  
* Operations chrome: scope tabs Register Operations | Store Operations + shared context strip  
* Routes: `/register/operations` (default Register Ops) + Store Ops scope; redirect old `store_operations`  
* Reuse POS shell layout  

### 11.3B — Register Operations content ([#170](https://github.com/tswarren/shelfstack-5/issues/170))

Current session / device / drawer only:

* Session identity and opening facts; Close Session first-level  
* Session X/Z (permission-gated)  
* Cash-movement and no-sale history (no create quick-action strip)  
* Session recon status / blockers + links  
* Close blockers visible/actionable  

### 11.3C — Store Operations content ([#171](https://github.com/tswarren/shelfstack-5/issues/171))

Business day and all store sessions:

* Open / Close Business Day; all sessions table  
* Day X/Z; day close blockers  
* Day recon status / sessions awaiting recon + links  
* No current-session cash history in this scope  

### 11.3D — Open-transaction navigation ([#172](https://github.com/tswarren/shelfstack-5/issues/172))

OD-P11-03:

* Guard Operations and Store Workspace navigation  
* Interrupt: Suspend and continue / Cancel and continue / Return to Register  
* Hard-block Recovery / unsafe tender  
* Ready / suspended / Receipt navigate freely; preserve context  
* Never silent suspend/cancel/abandon  

### 11.3E — Ready boundary and phase exit ([#173](https://github.com/tswarren/shelfstack-5/issues/173))

* Cash Movement / No Sale only on Ready  
* Open day/session from Ready use Operations-oriented components  
* Permissions gate scopes/actions  
* Phase exit docs + CI  

---

## 5. Accepted decisions governing this phase

| ID | Topic | Resolution |
| --- | --- | --- |
| OD-P11-02 | Register quick actions vs Operations history | [phase-11.3-operations-workspace-boundaries.md](../decisions/phase-11.3-operations-workspace-boundaries.md) |
| OD-P11-03 | Open-transaction workspace navigation | same decision note |
| OD-P11-04 | Reconciliation placement in Operations | same decision note |

Check refund treatment (OD-P11-01) is accepted for Phase **11.4** — [phase-11.4-check-refund-treatment.md](../decisions/phase-11.4-check-refund-treatment.md).

---

## 6. Out of scope

* Full reconciliation product rewrite (remains ShelfStack reporting)  
* Integrated payments / offline POS  
* Check-refund policy implementation (Phase 11.4)  
* Absorbing unbounded Phase 11.4 hardening work  
* Rewriting `CloseSession` / `CloseBusinessDay` / cash-movement / recon posting services  

---

## 7. Delivery gates

| Gate | Outcome | Issue |
| --- | --- | --- |
| **11.3A** | Operations chrome and sibling shell | [#169](https://github.com/tswarren/shelfstack-5/issues/169) |
| **11.3B** | Register Operations content | [#170](https://github.com/tswarren/shelfstack-5/issues/170) |
| **11.3C** | Store Operations content | [#171](https://github.com/tswarren/shelfstack-5/issues/171) |
| **11.3D** | Open-transaction navigation | [#172](https://github.com/tswarren/shelfstack-5/issues/172) |
| **11.3E** | Ready boundary and phase exit | [#173](https://github.com/tswarren/shelfstack-5/issues/173) |

Recommended implementation order: **A → B → C → D → E**.

---

## 8. Phase exit

Phase 11.3 is complete when:

* Register and Operations are sibling workspaces; Store Workspace is the return label only  
* The mixed Store Operations page is reorganized into scoped Ops  
* Register Ops covers current session/device/drawer; Store Ops covers business day and all sessions  
* Session X/Z and Day X/Z appear in the correct scopes  
* Cash Movement / No Sale quick actions stay on Ready; history lives in Register Ops  
* Close blockers are visible and actionable  
* Reconciliation status/links only — full recon remains ShelfStack  
* Open-transaction rules are enforced and tested; operating context is preserved  
* Permissions gate which scopes, sessions, reports, and actions a user may access  

---

## 9. Related

* Prior: [phase-11.2-register-workflow-refinement.md](phase-11.2-register-workflow-refinement.md)  
* Follow-on: [phase-11.4-pos-policy-and-lifecycle-hardening.md](phase-11.4-pos-policy-and-lifecycle-hardening.md)  
* [current-phase.md](../current-phase.md), [roadmap.md](../roadmap.md)  
