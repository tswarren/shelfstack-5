# Phase 4f — UX Baseline Gate

**Status:** Complete — manually accepted and ready for merge (PR #30)  
**Branch starting SHA:** `a8b1304ba98ec1696a57a056d64e3c4faa937309` (recorded when `phase/ux-baseline` was cut from `main`)  
**Design authority:** [../../design/README.md](../../design/README.md)  
**Walkthrough:** Accepted 2026-07-20. Expected-cash correction and Docker Chromium system-test support landed on `phase/ux-baseline` before merge.

## Purpose

Establish a reusable presentation layer and POS register workspace **before Phase 5**. New Phase 5 screens must use the record-list, record-detail, document-workspace, or work-queue patterns from this gate.

## Non-goals

- ViewComponent / SPA
- Payment integration or new domain features
- Rewriting POS application services
- Phone-width full register layout
- Tender Type / Cash Movement Type admin CRUD (no routes today)
- External Inter font CDN / dependency

## Money and rate entry

| Surface | Model |
| --- | --- |
| POS cash, tenders, refunds, open-ring, price override, amount discounts, opening/closing cash, cash movements | Fixed-point digit mask (`1200` → `$12.00`) → integer cents |
| Catalog, inventory, tax %, authority limits, department margins | Explicit decimal / percent fields |

Domain storage remains cents / existing rate representations. Server parse is authoritative.

## Delivery topology

```text
main
└── phase/ux-baseline
    ├── phase/ux-baseline-01-foundation
    ├── phase/ux-baseline-02-pos
    ├── phase/ux-baseline-03-catalog-inventory
    ├── phase/ux-baseline-04-admin
    ├── phase/ux-baseline-05-review-fixes
    ├── phase/ux-baseline-06-p0-gate
    └── phase/ux-baseline-07-p1-labels
```

Each milestone branch is cut from updated `phase/ux-baseline` after the preceding PR merges. PRs target `phase/ux-baseline`, not `main`.

| PR | Branch | Scope |
| --- | --- | --- |
| 1 | `…-01-foundation` | Layouts, sidebar, permission preload, CSS, helpers, Home, gallery, system harness |
| 2 | `…-02-pos` | Operational `pos` layout screens, two-panel workspace, currency mask, scan resolution, completion states |
| 3 | `…-03-catalog-inventory` | Products, stock, adjustments, reservations, units + Pagy |
| 4 | `…-04-admin` | Remaining route-backed admin/classification screens |
| 5 | `…-05-review-fixes` | Store-switch guard, named currency fields, percent parsing, scan preserve, ARIA |
| 6 | `…-06-p0-gate` | Store-local time, approval PIN admin, Register CTA hierarchy, Main workspace, balance/change, receipt return lookup |
| 7 | `…-07-p1-labels` | Variant labels, hierarchy paths, name-first codes, effective defaults display, open-ring order, tax-rule summaries |

## Operational layout (`pos`)

Register landing; transaction show/index; business-day open/close forms; session open/close forms.

Business-day history lists use `application`.

## POS store-switch and sign-out

- Active store always visible in the POS header.
- Store switching is **not** offered while a transaction is active (open with or without unresolved tenders). Cashier must complete, suspend, or cancel first.
- Sign-out is **blocked** while the cashier controls an open transaction or the session has unresolved tender activity on an open transaction; prompt to complete, suspend, or cancel first.

## Gate acceptance criteria

Merge `phase/ux-baseline` → `main` only when automated coverage and the manual walkthrough below are signed off.

### P0 correctness / usability

- [x] Store-local calendar date and display time use the store time zone (business-day default, midnight/DST covered by tests)
- [x] User admin can set/reset an Approval PIN (4–8 digits; blank on edit preserves; status only, never display the PIN)
- [x] Register shows one dominant primary CTA (open day / open session / Resume transaction / New transaction)
- [x] POS header **Main workspace** navigates to the home workspace; open-transaction indicator remains
- [x] Payment panel shows tendered, remaining balance or refund due, and change due; completed summary has no dead Print control; **Back to register** is the next action
- [x] Linked returns start from receipt-number lookup with selectable returnable lines (no raw line-ID entry)

### P1 presentation / comprehension

- [x] Variant selects and key inventory lists use shared Product — Variant · SKU labels
- [x] Department / merchandise-class selectors show hierarchy path labels; related selectors are name-first with codes secondary
- [x] Product show displays Configured / Effective / Source classification defaults via shared resolver
- [x] Open-ring fields order: Department → Price → Quantity → Description
- [x] Store tax rules index/form use treatment labels, name-first category, and a per-rule summary sentence

### Manual walkthrough

**Accepted 2026-07-20.** Separate transactions for:

1. Scan → tender → complete
2. Scan → suspend → recall → cancel or complete

Also: failed/ambiguous scan; negative-availability warning; approval-required action; failed completion; cash session close; keyboard-only pass; narrow laptop back-office pass.

Walkthrough follow-up validated before merge: over-tender with change, cash refund, and session-close expected cash (service tests + `bin/ci` + Docker `test:system`).

## Deferred UX

| Deferred | Note |
| --- | --- |
| Searchable record-picker / combobox | **Phase 5 entry prerequisite** |
| Live effective-default recomputation while editing | After static display on show |
| Modal dialog conversion | Keep `<details>`; one shared dialog primitive later |
| Comprehensive hotkey framework | Keep Ctrl/Cmd+Enter complete; Enter on completed → register; scanner Enter |
| Advanced returns | Scan-in-receipt, no-receipt, gift, multi-receipt |
| Receipt printing | Summary only; no dead Print control |
| Tax-rule matrix / visual builder | Beyond comprehension baseline |
| Self-service PIN change | Admin setup is enough for 4f |
| Locally hosted Inter webfont | External Inter dependency remains deferred |
| Phone-sized POS | Out of gate scope |
| Tender / cash-movement type admin CRUD | No routes today |
| Fixed-point currency mask outside POS/operational cash fields | Catalog uses explicit decimal entry |
| Pagination beyond Products/Stock unless needed | — |

## Gate status

**Manually accepted and ready for merge** via PR #30 (`phase/ux-baseline` → `main`). After merge, record the merge SHA here and in [../current-phase.md](../current-phase.md); next delivery phase is [phase-04g-test-hardening.md](phase-04g-test-hardening.md) (integrity gate before substantive Phase 5).

Automated portions landed on `phase/ux-baseline` (foundation → POS → catalog/inventory → admin → review/observation fixes → expected-cash / Docker system-test follow-up).

### Review fixes (pre-merge)

Follow-up work addressed merge-blocking review findings and walkthrough cash accounting:

* Server-side store-switch guard shared with sign-out (`Pos::CurrentOpenTransaction`); POS header hides Switch store when `@open_transaction` is set
* Named currency fields submit decimal dollars; server parses to cents (JS mask enhances only)
* Percent UI always percentage points (`0.5` → 0.5% / 50 bps); invalid money/percent rejected instead of cleared
* Ambiguous scan preserves quantity with a slim session payload; failed scans keep the query via explicit `scan_outcome`
* Form error summary IDs, field ARIA, store `currency_code`, POS percent/qty CSS
* Browser system coverage for store-switch, currency, scan, tender/complete, and keyboard disclosure
* Expected cash = opening + amount tendered − change − refunds ± movements; close form shows the breakdown
* Docker Chromium + `shm_size` so Compose can run `test:system`
