# POS register UI

**Status:** Governing for Phase 4 POS workspace interaction  
**Prototype reference:** [prototypes/ui_mockup/pos.html](prototypes/ui_mockup/pos.html)  
**Workflows:** POS transaction/completion docs under `docs/workflows/` as they land  
**Domain:** [point-of-sale](../domains/point-of-sale.md)

## Layout principles

Two-panel register workspace:

```text
[ session context strip: store · register/device · drawer · cashier · session ]
[ sale panel: scan + lines ]     [ pay panel: totals · tender · complete ]
```

- Scan entry is primary; retain focus after successful add where safe.
- Totals and tender controls stay visible.
- Product / Product Variant / Inventory Unit remain distinguishable in resolution UI.
- Labels may be cashier-friendly (for example “Register 2”) while the system records POS device and drawer separately.

## Terminology (UI vs domain)

| Prefer in UI | Domain meaning |
| --- | --- |
| Merchandise class | Hierarchical merchandise class (not a separate display category) |
| Product request | Customer/staff demand — not an inventory reservation |
| POS device / drawer | Distinct from session and business day |
| Tax category / store tax rules | Taxability — never inferred from item title text |

Stored-value redemption is tender, not a discount. Issuance is non-revenue liability activity.

## POS workspace states

Define UI behavior from states, not from ad hoc buttons:

```text
no_transaction
empty_open_transaction
active_transaction
item_resolution_required
variant_selection_required
exact_unit_selection_required   # Phase 4d
warning_present
blocker_present
approval_required               # Phase 4b+
tendering                       # Phase 4c
ready_to_complete
completion_in_progress
completion_failed
completed
suspended
recalled
cancelled
```

For each state, specify: what is visible, primary action, disabled actions, keyboard focus, what is provisional, and failure/retry behavior.

## Warnings, blockers, and approvals

| Kind | Meaning | UI |
| --- | --- | --- |
| Warning | Proceed allowed after acknowledgment (for example negative available per policy) | Non-blocking alert; retain ability to continue |
| Blocker | Cannot proceed until resolved | Disable completion / add; clear message |
| Approval | Independent approver credentials required | Modal/drawer; requester and approver distinct |

Never present a shortcut as bypassing validation. A shortcut may **request** completion; the server may reject it.

## Phase 4 gate focus

| Gate | UI must support | Defer |
| --- | --- | --- |
| 4a | Scan/search, variant resolve, lines, qty, suspend/recall/cancel, reservation feedback, session context | Receipt, tender polish |
| 4b | Price/tax/discount display, approval pattern | Exhaustive promotion UX |
| 4c | Tender entry, completion progress/failure/retry, receipt presentation | Animation, PWA, offline |

## Server authority

Client may preview totals and keep focus. Server owns eligibility, reservation, price, tax, tender sufficiency, posting, receipt numbers, and completion idempotency. Prototype cart math is not a contract.
