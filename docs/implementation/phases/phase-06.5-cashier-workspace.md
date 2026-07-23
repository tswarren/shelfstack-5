# Phase 6.5 — Cashier Workspace

**Status:** Draft — not started; begins only after Phase 6 merge hardening ([#36](https://github.com/tswarren/shelfstack-5/issues/36)) closes  
**Depends on:** Phase 6 gates 6a–6e landed; Phase 4f UX Baseline patterns  
**Chronologically follows:** Phase 6 — Corrections and Stored Value  
**Unlocks:** operable register UX before Phase 7 reporting; does **not** gate Phase 7 domain work technically  
**Governing docs:** [pos-register-ui.md](../../design/pos-register-ui.md); [scanner-and-hotkeys.md](../../design/scanner-and-hotkeys.md); [accessibility.md](../../design/accessibility.md); [application-shell.md](../../design/application-shell.md); [point-of-sale](../../domains/point-of-sale.md); ADR-0009; ADR-0011; [ADR-0016](../../adr/0016-treat-standalone-credit-card-activity.md)  
**Source drafts (non-governing):** [phase-6.5-cashier-workflow-ux.md](../../temp_draft/phase-6.5-cashier-workflow-ux.md); [phase-6.5-ideas_1.md](../../temp_draft/phase-6.5-ideas_1.md); [phase-6.5-ideas_2.md](../../temp_draft/phase-6.5-ideas_2.md)

## Characterization

Phase 6.5 is a **cashier interaction gate**, not a domain-expansion phase.

ShelfStack already has the POS records and application services needed for ordinary sale, mixed sale/return, discounts and approvals, tenders (including stored-value and standalone card), suspend/recall, complete, and post-void. Phase 4f established the two-panel register shell and shared patterns. The remaining gap is that the cashier still experiences those capabilities as many nested forms and always-visible payment controls rather than one guided operational path.

**Phase 6.5 should deliver:** a coherent cashier workspace over capabilities ShelfStack already possesses.

**It should not deliver:** new commercial behavior, new posting models, new hardware integrations, or generalized reporting and administration systems.

This phase reorganizes the register UI around a cashier-facing interaction contract. It must **not**:

- invent deferred capabilities ([deferred-capabilities.md](../deferred-capabilities.md));
- rewrite POS application services except where a thin adapter is required for readiness projection or scan-to-start;
- introduce Node.js, a JS bundler, ViewComponent, or an SPA;
- treat UI state as a substitute for server authority;
- create a second JavaScript eligibility / tax / pricing / tender-sufficiency engine;
- invent new blocker rules solely for the UI.

## Goal

Make the ordinary path feel like:

```text
Ready → scan → Transaction (item added) → Tender → Complete → Receipt → Ready
```

while keeping exceptional work (returns, stored value, open ring, discounts, approvals, recovery) as resumable interruptions inside one persistent checkout workspace.

**Next transaction** returns the register to **Ready** without creating an empty transaction. A merchandise scan from Ready opens the next transaction automatically (scan-to-start).

## Visible cashier states

Adopt the simplified model from the Phase 6.5 ideas draft. Do **not** require a separate Review screen for every sale.

**These are presentation states. They do not require corresponding database status values.** Do not propose persisted transaction statuses such as `processing`, `receipt`, or `recovery`.

| State | Cashier meaning | Notes |
| --- | --- | --- |
| **Ready** | Register waiting | Session/day/device/cashier context; start or scan-to-start; recall; optional receipt lookup |
| **Transaction** | Adding or correcting lines | Default sale intent; inline readiness (warnings / approvals / blockers) |
| **Tender** | Collecting or refunding money | Commercial line editing locked while unresolved tenders exist |
| **Processing** | Completion request in flight | Ephemeral UI only — see below |
| **Receipt** | Transaction succeeded | Receipt number; **Next transaction** → Ready |
| **Recovery** | Failure needs a specific action | Closed list of existing outcomes — see below |

### Processing (ephemeral)

**Processing** means: completion request submitted; duplicate controls disabled; current idempotency key retained; response pending.

It must **not** become a persisted transaction state, background job, polling workflow, or asynchronous posting queue. Atomic completion (ADR-0009) remains authoritative.

### Recovery (closed list for this phase)

Present known completion-related outcomes cleanly. Do not build a generalized exception-management system. Phase 6.5 recovery cases are existing POS-reachable outcomes, including:

- validation failed before posting;
- duplicate or already-completed submission (idempotent success);
- standalone card approved but internal completion failed;
- `void_required` (ADR-0016);
- transaction / session / business day no longer valid;
- stale or invalid reservation;
- stored-value balance changed / redemption blocked.

New recovery categories discovered during implementation are **triaged** — not automatically absorbed into scope.

Review readiness lives **inside Transaction** (and gates entry to Tender / Complete):

- informational messages;
- non-blocking warnings (for example negative available);
- approvals still required;
- blockers with a direct jump to the affected line or field.

**The server determines readiness; the interface presents it.** Source of truth remains `Pos::ValidateCompletionReadiness` and existing recalculation / eligibility services. The UI may normalize service results for presentation; it does not invent a parallel rule set.

These presentation states refine the Phase 4 POS workspace vocabulary in [pos-register-ui.md](../../design/pos-register-ui.md). Update that design doc in the same change set when the contract lands.

## Entry intents vs register utilities

### Transaction entry intents (required)

Within **Transaction**, temporary intents change how the entry field is interpreted:

```text
Sale (default)
Return
Stored value
Open ring
```

After the subtask finishes or is cancelled (`Escape` where implemented), return to Sale intent. A completed transaction may still contain sale, return, open-ring, and stored-value activity together — intents never permanently classify the transaction.

### Register utility (optional / stretch)

**Receipt lookup** is a Ready-state register utility, not an entry intent equal to Sale/Return/SV/Open ring. It may begin a return or expose existing corrective actions, but it does not reinterpret ordinary merchandise scans inside an open transaction the same way intents do.

## Layout contract

One persistent workspace with stable regions (non-negotiable):

```text
Header: store · device · session · cashier · transaction status
Entry:  scan / identifier / search          [ current intent ]
Lines:  transaction lines (selection)    | Summary: totals + readiness
Action: selected-line or transaction actions     [ dynamic primary CTA ]
```

### Primary action rules

| Situation | Primary action |
| --- | --- |
| Empty transaction | Continue scanning (focus entry) |
| Valid, unpaid | **Tender $X** |
| Blockers present | **Resolve N blockers** |
| Tender, balance remaining | Add / apply payment (amount-aware) |
| Fully settled | **Complete transaction** |
| Completed | **Next transaction** (→ Ready, no empty txn) |
| Recoverable failure | Explicit recovery (retry / void card / etc.) |

Avoid generic **Continue** / **Submit** / **Save** as the dominant control.

### Focus-management contract

Document and implement in 6.5a / enforce through 6.5d (not later polish):

- opening a transaction focuses the entry field;
- completing a selected-line action restores entry focus unless another required task remains;
- cancelling an intent restores Sale intent and entry focus;
- closing an approval prompt returns to the affected action or line;
- returning from tender restores the previously selected line or entry field;
- validation failure moves focus to the first resolvable blocker;
- Receipt state focuses the **Next transaction** action;
- Recovery state focuses the primary recovery control.

### Confirmation standards

Confirm when the action is hard to reverse or abandons money/context. Do **not** confirm ordinary reversible edits.

Likely confirmations:

- cancel transaction;
- remove an approved standalone-card tender;
- leave tender with unresolved activity (when allowed at all);
- discard pending work;
- suspend when material warnings apply;
- begin a post-void;
- replace current work by recalling another transaction.

### Accessibility baseline (in-phase)

Apply [accessibility.md](../../design/accessibility.md) while restructuring the workspace:

- real button and form semantics;
- keyboard reachability for every cashier action that has a visible control;
- visible focus indicators;
- status announcements for scan results and completion outcomes;
- warnings / severity not by color alone;
- modal or drawer focus containment;
- logical tab order;
- labels for intent and readiness states.

### Supported register viewport

Declare in the interaction contract (6.5a):

- intended register resolution;
- minimum usable width for the persistent shell;
- whether the summary remains fixed at that width;
- how drawers/panels overlay the workspace;
- that touch-first / phone-width POS is **explicitly unsupported** in 6.5 (consistent with 4f).

A complete responsive redesign remains deferred; an undefined supported viewport is not acceptable.

### Stale-context presentation

Services already protect records. 6.5d must present existing failures intelligibly when, for example:

- a suspended transaction was recalled elsewhere;
- a line reservation is no longer valid;
- a session closed in another process;
- a business day changed;
- an exact unit became unavailable;
- the same completion request is retried.

No new domain behavior — only clear presentation of existing service errors.

## Scope summary

### In scope (core)

1. **Cashier interaction contract** — presentation states, entry intents, focus ownership, scanner ownership, selected-line behavior, warning/blocker/approval behavior, confirmation standards, accessibility baseline, supported viewport, closed recovery list, primary-action rules — in [pos-register-ui.md](../../design/pos-register-ui.md) (and scanner/accessibility docs as needed).
2. **Persistent POS shell** — header, entry, lines, summary, action region; dynamic primary CTA; hide exceptional forms behind intents / transaction-actions rather than permanent `<details>` stacks.
3. **Scan-to-start from Ready** — scanning merchandise while Ready opens a transaction and adds the line (same services as today); part of the ordinary path (6.5b).
4. **Selected-line action panel** — reorganize existing qty / remove / discount / price override / exact unit / return fields into one contextual area; do not redesign policies or services.
5. **Inline readiness** — project existing warnings, approvals, and blockers into the summary.
6. **Focused tender mode** — amount due or refund due; tender entries; remaining balance; tender methods; external card approval state; visible edit lock; safe return to editing; amount-aware primary actions. No new tender types, processor integration, refund policy, payment-attempt domain, or terminal communication.
7. **Completion recovery** — present the closed recovery list above (completed? receipt assigned? card approved? postings? void required? next action?). No broad reconciliation or exception-management system.
8. **Receipt stage** — in-app receipt summary; **Next transaction** → Ready without creating an empty transaction; post-void remains secondary where an existing path already exists.
9. **Exception entry intents** — Return, Stored value, Open ring; approval interruption; suspend/recall presentation.
10. **Progressive keyboard** — dedicated scan field remains baseline; scan-to-start included; visible browser-safe shortcuts may be added; no global body capture or mandatory full keyboard matrix.

### Optional / stretch (6.5e — not required for ordinary-path success)

**Narrow Ready receipt lookup:** search completed transactions at the **active store** using identifiers already supported by the application; open the **existing** completed-transaction view; expose **existing** eligible linked-return and post-void actions.

Do **not** build a generalized transaction-search subsystem (arbitrary filters, customer/card-reference search, gift-receipt behavior, new authorization models, redesigned eligibility).

Post-void from lookup may only:

- expose the existing action;
- improve discoverability;
- preserve context;
- present existing eligibility failures.

It must **not** redesign post-void eligibility, reversal construction, card-terminal policy, stored-value reversal rules, or downstream-activity detection.

### Out of scope (defer past Phase 7 / Phase 8)

| Deferred | Reason |
| --- | --- |
| Receipt printer / printer queue / reprint beyond incidental browser print | Deferred from 4f; no printer stack |
| Gift receipt / electronic receipt delivery | Deferred |
| Global body-capture scanner / full hotkey matrix / PWA / offline POS | Progressive later; not adopted architecture |
| Customizable per-store hotkey layouts; configurable cashier layouts | Not needed to prove the model |
| Touch-first or mobile-specific POS | Explicitly unsupported in 6.5 |
| New `POSWorkspaceState` anti-corruption command API | Existing `Pos::*` services are the commands |
| Coupons, promotions, loyalty | Deferred capabilities |
| Rich customer CRM | Opaque `customer_reference` only |
| Session X / business-day Z report generation | Phase 7 |
| Stored-value account suspend/unsuspend / SV administration UI | Deferred past Gate 6d |
| Integrated payment processing; cash-drawer / customer-display hardware | ADR-0016 / deferred |
| UI telemetry, cashier productivity analytics, saved cashier preferences | Not required |
| Multi-register real-time presence indicators | Not required |
| Animated / highly polished transition systems | Polish later |
| App-wide visual redesign outside the POS layout | Cross-cutting later |
| New schema introduced solely to support presentation | Forbidden |
| Mandatory separate Review stage every sale | Rejected; inline readiness only |
| Closing OD-009 / OD-010 / OD-013 | Unrelated open decisions |

## Delivery gates

| Gate | Focus | Required for core gate? |
| --- | --- | --- |
| **6.5a** | Interaction contract: presentation states, entry intents, selected-object rules, focus ownership, scanner ownership, warning/blocker behavior, confirmation standards, accessibility baseline, supported viewport, closed recovery cases | Yes |
| **6.5b** | Persistent shell + ordinary sale: Ready, **scan-to-start**, sale add, selected-line navigation, summary, primary CTA, cash tender, complete, Receipt, **Next transaction → Ready** | Yes |
| **6.5c** | Existing exception entry: Return / SV / open-ring intents; qty/removal; discount; price override; exact-unit; approval interruption; suspend/recall presentation | Yes |
| **6.5d** | Settlement, readiness, recovery: readiness projection; tender edit lock; cash/card/SV tender presentation; payment/refund state; stale-context handling; idempotent retry presentation; standalone-card recovery; a11y/keyboard hardening | Yes |
| **6.5e** | Optional register utilities + hardening: narrow receipt lookup; existing return/post-void exposure from lookup; full walkthrough; system tests; retire/archive superseded temp drafts | **No** — removable without undermining the core cashier-workspace goal |

Gates may land as sequential short-lived PRs. Prefer finishing 6.5b before deep exception polish. **6.5e may ship later or be deferred** without failing the ordinary-path gate.

## Implementation order

1. Close Phase 6 [#36](https://github.com/tswarren/shelfstack-5/issues/36); do not start 6.5 product PRs while Phase 6 merge hardening is open.
2. **6.5a** — Update governing design docs; lock presentation states, focus, confirmations, viewport, recovery list.
3. **6.5b** — Persistent shell + ordinary path including scan-to-start and Next → Ready.
4. **6.5c** — Exception intents and selected-line reorganization of existing actions.
5. **6.5d** — Readiness, tender focus, recovery, stale-context presentation, a11y hardening.
6. **6.5e** (optional) — Narrow receipt lookup; walkthrough extras; draft cleanup.

## Schema and services

**Expected schema change:** none for the core gate. Do not introduce schema solely for presentation.

**Allowed thin service/controller adapters:**

- Ready-state scan that opens a transaction then adds a line (compose `Pos::OpenTransaction` + existing add/resolve path);
- Read-only readiness projection for the summary (call existing `ValidateCompletionReadiness` / recalculation without posting);
- Narrow completed-transaction lookup by already-supported identifiers at the active store (6.5e only).

Do not add speculative POS tables, statuses, or a parallel client-side cart model. Server remains authoritative for eligibility, reservation, price, tax, tender sufficiency, posting, receipt numbers, and completion idempotency.

## Exit criteria

### Core gate (required)

Proven by focused request/system tests and a manual walkthrough unless noted:

- [ ] Cashier-facing **presentation** states Ready / Transaction / Tender / Processing / Receipt / Recovery are documented and reflected in the POS UI without new persisted statuses
- [ ] Ordinary path: Ready → scan-to-start → tender → complete → **Next transaction → Ready** (no empty transaction created)
- [ ] Entry intents (Sale / Return / Stored value / Open ring) change scan/entry interpretation without separate transaction types or modules
- [ ] Selected-line actions are available from one contextual panel; pending removed lines are not cashier-managed as CRUD records
- [ ] Summary distinguishes warnings, approvals, and blockers; blockers disable Tender/Complete with a path to resolve; no client-side eligibility engine
- [ ] Tender mode locks commercial line editing while unresolved tenders exist; remaining amount / refund due is prominent
- [ ] Closed recovery list cases that are reachable in tests present an explicit message (completed? receipt? external approval? void required? next action?)
- [ ] Receipt stage primary action is **Next transaction** → Ready; completed transactions do not expose ordinary edit/tender controls
- [ ] Focus restoration follows the documented contract; all core actions are keyboard reachable; status is not communicated by color alone
- [ ] Supported register viewport is documented; phone-width POS remains unsupported
- [ ] No new deferred capability scaffolds (print, promotions, CRM, PWA, processor integration, presentation-only schema)
- [ ] `bin/ci` green; system coverage for scan-to-start, ordinary sale → next, tender focus, and at least one recovery path

### Stretch (6.5e — not required for ordinary-path gate)

- [ ] Where existing completed-transaction lookup and corrective services support it, Ready receipt lookup opens the existing completed view and exposes existing linked-return and post-void entry actions. Eligibility and immutability remain server-enforced. This is **not** required for the ordinary cashier-path gate.

## Manual walkthrough

### Required for core merge

1. Ready scan-to-start → tender cash → complete → Next → Ready (no empty txn)
2. Sale + linked return (intent switch) → net tender → complete
3. Gift-card issue line → card tender → complete (standalone confirmation)
4. Blocker or approval path → resolve → tender → complete
5. Failed completion or `void_required` recovery → safe next action
6. Suspend → Ready → recall → complete
7. Keyboard-oriented pass (dedicated scan field + visible shortcuts + focus restoration)

### Optional (6.5e)

8. Narrow Ready receipt lookup → existing return or post-void entry (eligible case only)

## Relationship to Phase 7

Phase 7 (Reporting and Reconciliation) does **not** hard-depend on Phase 6.5 for schema or posting correctness. Delivery preference is **6 → 6.5 → 7** so cashiers can operate the register before report work dominates. If schedule pressure requires it, Phase 7 may start after Phase 6 while 6.5 continues in parallel — but 6.5 must not invent reporting behavior, and Phase 7 must not invent cashier UX.

Session X / business-day Z **generation** remains Phase 7 even though the cashier workflow map mentions them.

## Related

- [../roadmap.md](../roadmap.md)
- [../current-phase.md](../current-phase.md)
- [phase-04f-ux-baseline.md](phase-04f-ux-baseline.md)
- [phase-06-corrections-and-stored-value.md](phase-06-corrections-and-stored-value.md)
- [phase-07-reporting-and-reconciliation.md](phase-07-reporting-and-reconciliation.md)
- [../../design/pos-register-ui.md](../../design/pos-register-ui.md)
- [../../design/accessibility.md](../../design/accessibility.md)
