# Phase 4f — UX Baseline Gate

**Status:** Active on `phase/ux-baseline`  
**Branch starting SHA:** `a8b1304ba98ec1696a57a056d64e3c4faa937309` (recorded when `phase/ux-baseline` was cut from `main`)  
**Design authority:** [../../design/README.md](../../design/README.md)

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
    └── phase/ux-baseline-04-admin
```

Each milestone branch is cut from updated `phase/ux-baseline` after the preceding PR merges. PRs target `phase/ux-baseline`, not `main`.

| PR | Branch | Scope |
| --- | --- | --- |
| 1 | `…-01-foundation` | Layouts, sidebar, permission preload, CSS, helpers, Home, gallery, system harness |
| 2 | `…-02-pos` | Operational `pos` layout screens, two-panel workspace, currency mask, scan resolution, completion states |
| 3 | `…-03-catalog-inventory` | Products, stock, adjustments, reservations, units + Pagy |
| 4 | `…-04-admin` | Remaining route-backed admin/classification screens |

## Operational layout (`pos`)

Register landing; transaction show/index; business-day open/close forms; session open/close forms.

Business-day history lists use `application`.

## POS store-switch and sign-out

- Active store always visible in the POS header.
- Store switching is **not** offered while a transaction is active (open with or without unresolved tenders). Cashier must complete, suspend, or cancel first.
- Sign-out is **blocked** while the cashier controls an open transaction or the session has unresolved tender activity on an open transaction; prompt to complete, suspend, or cancel first.

## Gate criteria (merge `phase/ux-baseline` → `main`)

See the acceptance list in the UX Baseline Gate plan. Phase 5 must not start until:

- Shell, POS workspace, flash/forms/tables, money entry models, and system tests meet the gate
- Manual walkthrough below is signed off

### Manual walkthrough

Separate transactions for:

1. Scan → tender → complete
2. Scan → suspend → recall → cancel or complete

Also: failed/ambiguous scan; negative-availability warning; approval-required action; failed completion; cash session close; keyboard-only pass; narrow laptop back-office pass.

## Deferred UX

- Locally hosted Inter webfont
- Full modal approval dialog (inline disclosure is baseline)
- Phone-sized POS
- Tender / cash-movement type admin CRUD
- Pagination beyond Products/Stock unless needed
- Scan-resolution polish beyond the actionable baseline region
- Fixed-point currency mask outside POS/operational cash fields

## Gate status

Automated portions of the UX Baseline Gate are implemented on `phase/ux-baseline` (foundation → POS → catalog/inventory → admin).

**Merge to `main` requires manual walkthrough sign-off** (see Manual walkthrough above). Do not treat automated tests alone as gate completion.

After merge to `main`, update [../current-phase.md](../current-phase.md) toward Phase 5.
