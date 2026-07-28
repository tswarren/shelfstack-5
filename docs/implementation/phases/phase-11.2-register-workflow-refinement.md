# Phase 11.2 — Register Workflow Refinement

**Status:** Active — scheduled after Phase 11.1 close  
**Depends on:** Phase 11 closed; Phase 11.1 printed documents complete on `main`  
**Primary register items:** Contextual approval UX; tender settlement polish; guided returns; refund recommendation UX  
**Source design packet:** [phase-11.12-14-draft-scope.md](../../temp_draft/phase-11.12-14/phase-11.12-14-draft-scope.md) (§ Phase 11.2) — background only; this plan is authoritative  
**Wireframes:** [wireframes.md](../../design/pos/wireframes.md) — Phase 11.2 section (approval interrupt, Start Return, linked multi-select, unlinked steps, refund plan, tender polish)  
**Governing docs:** [point-of-sale.md](../../domains/point-of-sale.md); [authorization-permissions.md](../../domains/authorization-permissions.md); ADR-0009; ADR-0011; ADR-0012; ADR-0016; [phase-11.2-refund-allocation-sv-first.md](../decisions/phase-11.2-refund-allocation-sv-first.md); [architectural-locks.md](../architectural-locks.md#refund-allocation-priority-v1)  
**Epic:** [#158](https://github.com/tswarren/shelfstack-5/issues/158)  
**Gate issues:** [#159](https://github.com/tswarren/shelfstack-5/issues/159) (11.2A) · [#160](https://github.com/tswarren/shelfstack-5/issues/160) (11.2B) · [#161](https://github.com/tswarren/shelfstack-5/issues/161) (11.2C) · [#162](https://github.com/tswarren/shelfstack-5/issues/162) (11.2D) · [#163](https://github.com/tswarren/shelfstack-5/issues/163) (11.2E) · [#164](https://github.com/tswarren/shelfstack-5/issues/164) (11.2F)

---

## 1. Characterization

Phase 11.2 refines cashier-facing **transaction** workflows so the ordinary path is simple and exceptional complexity appears only when required.

It does **not** replace POS posting services, invent new financial records, or rebuild the Phase 11 L3 tender workspace from scratch. Tender work is **incremental polish** on the existing method-selector workspace.

Three major areas:

1. Contextual, exception-driven approvals  
2. Tender settlement clarity (and refund recommendations under locked SV-first policy)  
3. Guided linked and unlinked returns

Follow-on Operations workspace split is **Phase 11.3**. Policy/lifecycle hardening is **Phase 11.4**.

---

## 2. Goal

Preserve accepted financial and posting rules while replacing form-driven exception UX with guided workflows:

* Approvals appear only after ShelfStack detects an authority exception.  
* Tender settlement state is obvious; remove vs void terminology matches tender lifecycle.  
* Linked returns support multi-line selection from a receipt.  
* Unlinked / open-ring returns use stepped guidance.  
* Refund recommendations are visible and editable before recording, under **stored-value first** allocation.

---

## 3. Code reality (do not treat as greenfield)

| Area | Today |
| --- | --- |
| Approvals | Contextual interrupt via `Pos::PendingApprovalAction` + `#pos_overlay`; ordinary forms no longer show preemptive `_approval_fields` |
| Tender | L3 method selector with settlement hierarchy + Remove/Void labels; refund plan summary when net refund due |
| Linked returns | Multi-select batch via `Pos::AddLinkedReturnLines` |
| Unlinked returns | Guided wizard steps + searchable department list; cost-review retained |
| Refund policy | `Pos::RefundAllocationPolicy` SV-first; `Pos::ProposeRefundPlan` / Accept plan UX |

---

## 4. Scope by gate

### 11.2A — Contextual approval interrupt ([#159](https://github.com/tswarren/shelfstack-5/issues/159))

Reusable interrupt after server-side evaluation:

* Explain action, boundary, material values, and effect.  
* Bind approval to one line, tender, transaction, session, or business-day action.  
* Invalidate on material change (amount, method, line, disposition, etc.).  
* Generalize post-void’s approve-then-act pattern.  
* Register workflows use it first; Phase 11.3 may reuse for session/day exceptions.

### 11.2B — Retire preemptive approval fields ([#160](https://github.com/tswarren/shelfstack-5/issues/160))

Remove always-visible approver username/PIN from ordinary forms (price/discount/tax, cash movement, no-receipt return, refund exception). Wire callers through 11.2A.

### 11.2C — Tender settlement polish ([#161](https://github.com/tswarren/shelfstack-5/issues/161))

Incremental on L3 (not a stacked-form rewrite):

* Emphasize total, recorded settlement, remaining balance, change due, blockers.  
* Primary action by settlement state (Add tender / Add refund tender / Complete / resolve blocker).  
* Recorded-tender actions use correct lifecycle terms: edit/remove vs void vs view-only.  
* Preserve split tender, card void/recovery, stored-value tender, and completion readiness rules.

Focused modal entry may refine the current active-form pattern; do not regress L3 settlement behavior.

### 11.2D — Receipt-linked multi-line return selector ([#162](https://github.com/tswarren/shelfstack-5/issues/162))

After valid receipt lookup: select multiple returnable lines with qty / reason / disposition (shared defaults with per-line override). Use original commercial facts. Add selected lines via existing linked-return services.

### 11.2E — Guided unlinked / open-ring returns ([#163](https://github.com/tswarren/shelfstack-5/issues/163))

Replace the single large unlinked form with steps: identify → confirm → qty/price → reason/disposition → tax/policy → contextual approval when required. Keep cost-review. Open-ring returns use a searchable department selector.

### 11.2F — Refund recommendation UX ([#164](https://github.com/tswarren/shelfstack-5/issues/164))

When a net refund is due, present an editable **proposed** refund plan before recording tenders. Ordering and validation follow [SV-first lock](../decisions/phase-11.2-refund-allocation-sv-first.md). Proposed lines are not tenders until confirmed. Deviations use existing exception approval.

---

## 5. Out of scope

* Integrated card processing / terminal automation  
* Offline POS  
* Phase 11.3 Operations workspace split  
* Phase 11.4 closed hardening inventory  
* New approval policy unrelated to an implemented action  
* Changing `RefundAllocationPolicy` away from stored-value first  

---

## 6. Delivery gates

| Gate | Outcome | Issue |
| --- | --- | --- |
| **11.2A** | Reusable contextual approval interrupt | [#159](https://github.com/tswarren/shelfstack-5/issues/159) |
| **11.2B** | Preemptive approval fields retired | [#160](https://github.com/tswarren/shelfstack-5/issues/160) |
| **11.2C** | Tender settlement polish on L3 | [#161](https://github.com/tswarren/shelfstack-5/issues/161) |
| **11.2D** | Linked multi-line return selector | [#162](https://github.com/tswarren/shelfstack-5/issues/162) |
| **11.2E** | Guided unlinked / open-ring returns | [#163](https://github.com/tswarren/shelfstack-5/issues/163) |
| **11.2F** | Refund recommendation UX (SV-first) | [#164](https://github.com/tswarren/shelfstack-5/issues/164) |

Recommended implementation order: **A → B → C → D → E → F**.

---

## 7. Phase exit

Phase 11.2 is complete when:

* Ordinary workflows no longer expose unused approval fields.  
* Approval prompts appear only after an authority exception; approvals bind to the exact action and invalidate on material change.  
* Tender screen clearly communicates settlement state; remove/void terminology is correct.  
* Linked returns support receipt lookup and multi-line selection.  
* Unlinked / open-ring returns are guided steps.  
* Refund recommendations are visible/editable under SV-first policy.  
* Existing posting, inventory, tender, stored-value, and historical-integrity rules remain intact.

---

## 8. Related

* Follow-on: [phase-11.3-pos-operations-workspace.md](phase-11.3-pos-operations-workspace.md), [phase-11.4-pos-policy-and-lifecycle-hardening.md](phase-11.4-pos-policy-and-lifecycle-hardening.md)  
* Prior: [phase-11-pos-shell-and-workspace-revamp.md](phase-11-pos-shell-and-workspace-revamp.md), [phase-11.1-pos-printed-documents-v1.md](phase-11.1-pos-printed-documents-v1.md)  
* [current-phase.md](../current-phase.md), [roadmap.md](../roadmap.md)
