# POS layout completion checklist

**Status:** Active gate checklist for Phase 11 visual completion  
**Parent:** [README.md](README.md)  
**Authority:** [visual-contract.md](visual-contract.md) · [wireframes.md](wireframes.md) · [component-map.md](component-map.md) · [decisions.md](decisions.md)

## Purpose

Server presentation/state contracts from Phase 11 remain in force. This checklist governs the remaining work: make the cashier-facing UI match the accepted shell, hierarchy, and overlay model.

Do not mark layout complete because controller, service, or selector tests pass ([README completion standard](README.md#completion-standard)).

## Baseline (already shipped — preserve)

These are prerequisites, not layout acceptance:

| Capability | Evidence |
| --- | --- |
| Five presentation states | `Pos::WorkspacePresentation` |
| Ready does not open empty transactions | Scan-to-start / first-valid-work |
| Cancelled → Ready | Presentation redirect |
| Tender forced when unresolved tenders exist | Server presentation |
| Recovery for `void_required` | Structured recovery path |
| Browser-printable customer receipt | Separate print layout |
| Domain posting / reservation / completion | Existing Phase 6.5+ services |

Layout work must not regress these.

## Delivery order

Follow the package review sequence. Open decisions (POS-UI-030–037) may be confirmed with screenshots; they do not block Gate L0.

```text
L0  Shared shell geometry + Turbo boundaries
L1  Ready composition
L2  Transaction composition
L3  Tender composition
L4  Recovery composition
L5  Receipt composition
L6  Overlays (lookup / customer / editors)
L7  Viewport + scenario acceptance
```

---

## Gate L0 — Shared shell

**Goal:** One dedicated register workspace with recognizable regions at both supported viewports.  
**Wireframe:** [Shared shell](wireframes.md#shared-shell)  
**Decisions:** POS-UI-003, POS-UI-007, POS-UI-008, POS-UI-009

### Region → target mapping

| Wireframe region | Target (component-map) | Current treatment |
| --- | --- | --- |
| Compact register header | `pos/_register_header` via `pos/_shell` | `shared/app_header` + page subtitle — replace for interactive POS |
| Primary operational workspace | `pos_shell__workspace` primary column | Card / stacked panels in `register/show` and `pos_transactions/show` |
| Stable summary rail | Summary column in shell | Side panels exist but are not a fixed rail |
| Contextual command bar | Command row in shell | `_secondary_actions` / `_transaction_actions` / `<details>` — recompose |
| Authoritative workspace | `turbo_frame_tag "pos_workspace"` | Missing as consistency boundary |
| Overlay host | `turbo_frame_tag "pos_overlay"` + dialog | Missing |

### Exit criteria

- [x] `layouts/pos` hosts `pos_workspace` and `pos_overlay`; no presentation business markup in the layout
- [x] Interactive POS does not use the normal back-office page header / large page title pattern
- [x] Shell CSS implements bounded height (`100dvh` grid: header · workspace · command)
- [x] Summary rail and command bar remain visible while primary content scrolls internally
- [x] Empty / stub content in regions is acceptable in L0 if geometry matches the wireframe
- [ ] Screenshots at 1366×768 and 1024×768 attached for Ready stub and Transaction stub (manual review)

### Current → target (L0 focus)

| Current | Treatment |
| --- | --- |
| `layouts/pos` | Retain; add workspace + overlay frames; drop shared app header for POS |
| `register/show` | Begin reducing to Ready presentation render through shell |
| `pos_transactions/show` | Begin reducing to one presentation composition through shell |
| `_session_context` / `_transaction_status` | Fold identity into register header |

---

## Gate L1 — Ready

**Wireframe:** [Ready](wireframes.md#ready)  
**Decisions:** POS-UI-004, POS-UI-010, POS-UI-011

| Region | Must show | Must not show |
| --- | --- | --- |
| Primary | Scan-to-start (focus); Product lookup + Start return; supporting customer-work strip | Empty “New transaction”; Ready-level Sale; expanded day/session tables |
| Summary | Staged Customer, suspended preview (≤3 + View all), compact session | Sensitive cash / reconciliation totals |
| Command | Cash Movement, No Sale, Store Operations | Close Session / day tables on Ready; frequent actions in `<details>` |

### Exit criteria

- [ ] Matches Ready wireframe regions (not necessarily final typography)
- [ ] Sale / Return / Stored Value / Open Ring visible without opening disclosures (POS-UI-010)
- [ ] Product / Receipt / pickup lookups launch overlay or bounded panel (may stub in L1 if L6 not ready)
- [ ] Detailed business-day and cash-history tables are absent from ordinary Ready
- [ ] Pre-Ready (no day / no session) reuses shell with one clear prerequisite task
- [ ] Scenario 1 setup steps from [review-scenarios.md](review-scenarios.md) Accepted at both viewports

### Current → target

| Current | Treatment |
| --- | --- |
| Ready card + stacked `<details>` | `presentations/_ready` + `ready/*` start / intents / staged customer |
| Day and session details `<details>` | Move to Store Operations / secondary surface (POS-UI-037 open) |
| Suspended list in large panel | Compact summary-rail treatment (POS-UI-034 open) |

---

## Gate L2 — Transaction

**Wireframe:** [Transaction](wireframes.md#transaction)  
**Decisions:** POS-UI-004, POS-UI-009, POS-UI-012, POS-UI-025 (proposed)

| Region | Must show | Must not show |
| --- | --- | --- |
| Primary | Entry bar, line collection (visual center), selected-line context | Expanded tender forms |
| Summary | Customer, totals, readiness, sign-aware primary CTA | Orphaned duplicate titles |
| Command | Selected-line actions; Suspend; Cancel; More | Full-sized buttons for every rare action |

### Exit criteria

- [ ] Line collection is the only ordinary scrolling region
- [ ] Eight-line sale at 1366×768 requires no document scroll
- [ ] Totals + **Tender $X** / **Issue refund $X** / **Resolve N blockers** remain visible while lines scroll
- [ ] Selected-line commands live in a stable command-bar location
- [ ] Tender-entry forms are not expanded in Transaction
- [ ] Keyboard-selectable lines (not mouse-only)
- [ ] Review-scenarios ordinary sale / qty / suspend path Accepted

### Current → target

| Current | Treatment |
| --- | --- |
| `_entry_intents` + `_scan_form` | Compact Entry Bar; split scan / SV / Open Ring / return forms |
| `_line_items` / `_line_item` | Bounded central collection + refined selection |
| `_selected_line_actions` / `_line_actions` | Command-bar selected-line component |
| `_customer_panel` | Compact Customer summary + overlay launcher |
| `_totals` / `_readiness_summary` / `_primary_cta` | Summary-rail components with explicit locals |

---

## Gate L3 — Tender

**Wireframe:** [Tender — positive](wireframes.md#tender--positive-balance) · [settled](wireframes.md#tender--settled) · [net refund](wireframes.md#tender--net-refund)  
**Decisions:** POS-UI-005, POS-UI-012

| Region | Must show | Must not show |
| --- | --- | --- |
| Primary | Direction/balance, method selector, active form, recorded tenders | Editable commercial line entry |
| Summary | Customer/total/tendered/remaining, completion readiness | Former Transaction rail stretched to fill the screen alone |
| Command | Return to Transaction when safe; Complete when settled | Unsafe leave when forced Tender |

### Exit criteria

- [ ] Tender has intentional primary markup — not Transaction with left column hidden (POS-UI-005)
- [ ] Amount due / refund due and remaining balance are visually dominant
- [ ] Split settlement keeps recorded tenders visible
- [ ] Refund language is explicit (not only negative numbers)
- [ ] Complete Transaction visible when settled
- [ ] Tender contract scenarios from presentation matrix Accepted

### Current → target

| Current | Treatment |
| --- | --- |
| `_tender_entry` stacked `<details>` | `tender/_method_selector` + per-method forms |
| `_tenders` | Split collection + row |
| Tender via collapsed Transaction chrome | Dedicated `presentations/_tender` |

---

## Gate L4 — Recovery

**Wireframe:** [Recovery — void_required](wireframes.md#recovery--void_required)  
**Decisions:** POS-UI-006

### Exit criteria

- [ ] Recovery occupies the primary workspace
- [ ] Incident + numbered verification steps in operational language
- [ ] Affected tender/amount visible in summary
- [ ] Unsafe tender-entry controls absent (not merely muted)
- [ ] Closed-list permitted actions only; primary resolution focused
- [ ] `void_required` review scenario Accepted

### Current → target

| Current | Treatment |
| --- | --- |
| `_recovery_panel` / `_void_required_tenders` | Promote to `presentations/_recovery` + `recovery/*` |

---

## Gate L5 — Receipt

**Wireframe:** [Receipt](wireframes.md#receipt)  
**Decisions:** POS-UI-013

### Exit criteria

- [ ] Completion, receipt number, change, Print, Next Transaction dominate
- [ ] Next Transaction receives focus after completion announcement
- [ ] Linked return / post-void / detail are secondary
- [ ] Browser print remains on `layouts/pos_receipt` (separate document)
- [ ] Receipt scenarios Accepted at both viewports

### Current → target

| Current | Treatment |
| --- | --- |
| Completed branch of `pos_transactions/show` | `presentations/_receipt` + `receipt/*` |
| `customer_receipt` | Retain as print document only |

---

## Gate L6 — Overlays

**Wireframe:** [Product lookup](wireframes.md#product-lookup-overlay) · [Customer](wireframes.md#compact-customer-overlay)  
**Decisions:** POS-UI-008, POS-UI-011, POS-UI-026/027 (proposed)

### Exit criteria

- [x] One overlay host; supporting work does not leave the POS shell for ordinary paths
- [x] Focus trap, Escape (when permitted), restore focus to invoker (`pos-overlay` Stimulus + native `<dialog>`)
- [x] Successful state-changing action replaces workspace via `_top` navigation (overlay clears on turbo load)
- [x] Overlay never creates an empty transaction (Add still goes through ScanToStart)
- [x] Product lookup uses record picker interim (POS-UI-027 residual: rich result list when picker is insufficient)
- [x] Ready Product lookup is not buried in `<details>` (POS-UI-010)
- [ ] Screenshots / workflow review at both viewports (manual review)

### Current → target

| Current | Treatment |
| --- | --- |
| Inline Product lookup `<details>` + record picker | `overlays/_product_lookup` (rich list if needed) |
| Customer panel / new-customer link | `overlays/_customer_lookup` + compact create |
| Discount / override / cash movement forms | Overlay forms under `pos/overlays` / `pos/forms` |

---

## Gate L7 — Acceptance

**Inputs:** [review-scenarios.md](review-scenarios.md) · [visual-contract.md](visual-contract.md#visual-acceptance-checklist) · [screenshots/README.md](screenshots/README.md)

### Exit criteria

- [ ] Required presentation-matrix scenarios have Accepted compositions
- [ ] Visual acceptance checklist passes for Ready, Transaction, Tender, Recovery, Receipt
- [ ] Screenshots captured at 1366×768 and 1024×768 per screenshot matrix
- [ ] Component boundaries match [component-map.md](component-map.md) or an explicit recorded replacement in [decisions.md](decisions.md)
- [ ] Existing domain and server-authority tests still pass
- [ ] Open visual decisions either Accepted or deferred with register/OD note

---

## Suggested PR slices

Keep PRs short-lived and reviewable as compositions, not as “more POS features.”

**Process:** one PR per gate against `main` (`feat/phase-11-layout-l0` … `feat/phase-11-layout-l7`). After CI is green, pause for manual viewport review (1366×768 and 1024×768). Score **Accepted** / **Needs refinement** / **Fail** using [review-scenarios.md](review-scenarios.md). Do not open the next gate until the prior gate is Accepted (or Accepted with an explicit residual in [decisions.md](decisions.md)).

| PR | Gate | Scope |
| --- | --- | --- |
| Layout 0 | L0 | Shell geometry, register header, `pos_workspace` / `pos_overlay`, stub regions |
| Layout 1 | L1 | Ready composition through shell |
| Layout 2 | L2 | Transaction entry + lines + summary + command bar |
| Layout 3 | L3 | Tender dedicated composition |
| Layout 4 | L4 | Recovery dedicated composition |
| Layout 5 | L5 | Receipt completion composition |
| Layout 6 | L6 | Overlay host workflows |
| Layout 7 | L7 | Scenario walkthrough evidence + promote Proposed POS-UI decisions |

Mechanics from [#146](https://github.com/tswarren/shelfstack-5/pull/146) should not be re-litigated in these PRs unless a layout change forces a contract tweak.

## Explicit non-goals

- Inventing correction algorithms (DWR-004–006 design packet remains design-only)
- ESC/POS / hardware printer drivers
- Phone / touch-first POS
- Changing server readiness, tender sufficiency, or completion posting rules
- Accepting layout because partial file count matches the component map
