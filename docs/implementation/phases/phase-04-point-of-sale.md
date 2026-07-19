# Phase 4 — Point of Sale

**Status:** Implemented on `phase/p4-point-of-sale` (4a–4e); not merged to `main` pending manual testing  
**Depends on:** Phase 3 (complete); [UX readiness gate](../../design/README.md) before 4a coding; store tax rates/rules before 4b  

**Unlocks:** Phase 5 foundational purchasing after 4c; complete 4d before individual-item Phase 5 work; 4e recommended before return-oriented fulfilment (see [roadmap.md](../roadmap.md))  
**Governing docs:** ADR-0008, ADR-0009, ADR-0010, ADR-0011, [ADR-0014](../../adr/0014-hybrid-transaction-component-tax-calculation.md); [point-of-sale](../../domains/point-of-sale.md); [architectural-locks](../architectural-locks.md); [phase-04-tax-schema.md](../phase-04-tax-schema.md); [pos-register-ui](../../design/pos-register-ui.md); [scanner-and-hotkeys](../../design/scanner-and-hotkeys.md)

## Goal

Deliver an inventory-aware POS path ending in atomic, idempotent completion for quantity-tracked and non-inventory Product lines, then extend to individual units and linked returns.

## UX readiness gate (prerequisite for 4a)

Phase 4a implementation may begin when POS workflow states, scan/focus rules, warning and blocker patterns, principal layout, and accessibility baseline are documented ([../../design/](../../design/README.md)), living prototypes are in place, and shared visual tokens/shell CSS exist in Rails. Visual polish is not a gate; inventing POS interaction ad hoc during 4a is.

Prototype JS and mockup calculations are non-authoritative. Server services own pricing, tax, reservation, tender, completion, and receipt numbering.

## Gates


| Gate | Name | First-sale path? |
| --- | --- | --- |
| 4a | Editable POS | Required |
| 4b | Price, tax, discounts, approvals | Required |
| 4c | Tender and atomic completion | Required — **first demo milestone** |
| 4d | Individually tracked inventory | After 4c |
| 4e | Simple linked returns | After 4c stable |

---

## Phase 4a — Editable POS

### Tables

- `business_days`
- `pos_sessions` — one open session per device; one active cash-enabled session per drawer
- `pos_session_cash_counts` (as needed for open/close prep)
- `pos_transactions` — full status enum at create: `open`, `suspended`, `completed`, `cancelled` (4a services never set `completed`)
- `pos_line_items` — full status enum at create: `pending`, `completed`, `removed`

### Line kinds and tracking

Line kinds implemented in 4a:

```text
product
open_ring
```

Product-line tracking modes supported through 4c:

```text
quantity
none
```

Individual tracking is added in 4d. Stored-value line kind is reserved for Phase 6.

`none` is an inventory-tracking mode on the Product Variant, not a POS line kind. A non-inventory service remains a Product line with Variant, Department, Tax Category, price, discounts, and returns, and creates no Inventory Reservation.

### Behavior

- Open business day with explicit `reporting_date` (see locks).
- Open POS session on device/drawer (device and drawer exclusivity).
- Open transaction; scan/search; resolve exact variant for Product lines.
- Open-Ring lines: postable Department and price; no Variant; no reservation; effective description defaults to Department name when blank; snapshot before completion.
- Provisional **quantity** reservations on Product lines with tracking mode `quantity`.
- Soft-remove lines (retain row as `removed`).
- Suspend, recall, cancel (cancel releases provisional effects; no completed posting).

### Exit

- [x] Suspended transaction retains reservations
- [x] Cancel releases reservations without inventory movement
- [x] No receipt number assigned
- [x] One open session per device enforced
- [x] Concurrent recall of the same suspended transaction has one winner

### UX acceptance (4a)

- [x] Register workspace follows [pos-register-ui](../../design/pos-register-ui.md) two-panel / session-context principles (coherent, not pixel-perfect)
- [x] Dedicated scan/search field with Enter handling and focus restore per [scanner-and-hotkeys](../../design/scanner-and-hotkeys.md) (plain form submit; `autofocus` restores focus after redirect)
- [x] Variant resolution UI distinguishes product vs variant; no sale without an exact variant
- [x] Warning vs blocker presentation for reservation / availability cases
- [x] Suspend / recall / cancel affordances match draft transaction states
- [x] Store, session, device/drawer, and cashier context remain visible
- [x] Open-Ring entry path resolves effective description from Department when blank

### Must not

- Complete transactions or assign receipt numbers
- Treat inventory-tracking mode as a POS line kind
- Casual Tax Category edits without `pos.tax_category.override` (override lands in 4b)

---

## Phase 4b — Price, tax, discounts, approvals


### Prerequisite

Store tax rates and store tax rules with `treatment`, denormalized `store_id`, effective dates, taxable fraction, calculation order, compounding, component labels, overlap validation, and hybrid transaction-component rounding per [ADR-0014](../../adr/0014-hybrid-transaction-component-tax-calculation.md) and [phase-04-tax-schema.md](../phase-04-tax-schema.md). OD-004 / OD-005 are accepted.

**Landed** on `phase/p4-point-of-sale`: `store_tax_rates` / `store_tax_rules` schema and overlap/treatment validations, minimal admin CRUD under `classification.store_tax_rule.manage`, the pure `Tax::CalculateTransaction` calculation service, ADR-0014 fixtures/tests, demo `STATE6` + `FOOD125` seed matrix, and now the full 4b persistence/authorization slice: `pos_discounts`/`pos_discount_allocations`/`pos_line_item_taxes`/`pos_tax_exemptions`/`pos_approvals` schema; `pos.price.override`, `pos.discount.apply`, `pos.discount.approve`, `pos.tax.exempt`, `pos.tax_category.override` permissions; `Pos::AuthorizeAction`, `Pos::OverridePrice`, `Pos::ApplyDiscount`, `Pos::OverrideTaxCategory`, `Pos::ApplyTaxExemption`, `Pos::RecalculateTransaction`; recalculation wired into `AddLine`/`AddOpenRingLine`/`UpdateLineQty`/`RemoveLine`; and register UI for price override, discount apply, tax category override, and whole-transaction exemption (see [service-catalog.md](../service-catalog.md)). Completion-time revalidation of these blockers under a Transaction lock is 4c work.

### Tables / records

- `pos_discounts` (including `tax_treatment`), `pos_discount_allocations`
- `pos_line_item_taxes` (with ADR-0014 snapshots including `treatment_snapshot`)
- `pos_tax_exemptions` with coverage `whole_transaction` only
- Tax Category override audit fields on lines
- `pos_approvals`

### Behavior

- Price overrides distinct from discounts.
- Line and transaction discounts with deterministic allocations; ordinary discounts default to `reduces_taxable_base`.
- Tax: `Tax::CalculateTransaction` (pure) → `Pos::RecalculateTransaction` (persist pending); ADR-0014 largest-remainder hybrid model.
- Store Tax Rule `treatment` (`taxable` / `zero_rated` / `exempt`); Tax Category remains org-level description only.
- `pos.tax_category.override` for audited Tax Category changes; deny ordinary cashiers for Product-line category changes.
- Whole-transaction exemptions only; selected lines/components deferred.
- Approval records with requester, approver, reason, values, authority context.
- Historical snapshots on lines (product/variant, identifiers, effective description, department, merchandise class, tax category, return policy, prices, cost inputs as available).
- Completion blocked for missing/inactive/non-postable Department (validated when completion exists; provisional UI should surface early).

### Exit

- [x] Tax fixtures prove aggregation residual allocation, compounding, taxable fraction, and rule treatments (ADR-0014)
- [x] Discount allocation totals match line caches (`Pos::ApplyDiscount` largest-remainder allocation; `test/services/pos/apply_discount_test.rb`)
- [x] Missing store tax rule for a line's Tax Category blocks recalculation instead of implicit exemption (`Pos::RecalculateTransaction` blockers; `test/services/pos/recalculate_transaction_test.rb`). Completion-time revalidation under a Transaction lock is 4c.
- [x] `pos.tax_category.override` permission-denied path tested (`test/services/pos/override_tax_category_test.rb`)
- [x] Insufficient authority requires independent approver credentials (`Pos::AuthorizeAction`; `test/services/pos/authorize_action_test.rb`)

### UX acceptance (4b)

- [x] Price, discount, and tax components displayed from server-resolved values (not title-based tax) — transaction show page reads persisted `pos_discount_allocations` / `pos_line_item_taxes`, not client math
- [x] Approval UI supports independent approver credentials and retains requester/approver context — plain approver-username/PIN fields on each restricted-action form; `pos_approvals` retains requester/approver identity (a modal/drawer treatment per [pos-register-ui](../../design/pos-register-ui.md) is deferred polish, not a functional gap)
- [x] Snapshot-facing labels use merchandise class and tax category terminology
- [x] Tax Category override is distinct from ordinary line editing (`pos.tax_category.override`, dedicated action, audited)

---

## Phase 4c — Tender and atomic completion

**Landed** on `phase/p4-point-of-sale`: the D1 inventory sale bridge (`Inventory::PostLedgerEntry` / `Inventory::CalculateQuantityCost` extended for outbound `sale`, OD-014 provisional `moving_average`/`last_known`/`unknown` cost with zero/negative asset value; `Inventory::ConvertReservation` locking balance → reservation, verifying the source line, posting the sale, decrementing `reserved`, and marking the Reservation `converted` — never post-then-Release; deterministic `pos_line_item:<id>:sale` posting key; cost snapshot on the Line at conversion); the D2 completion schema (`stores.next_receipt_sequence`, `pos_tenders`, `pos_cash_movements`, completion fields on `pos_transactions`); the five 4c permission keys; the Tender-state lock (`PosTransaction#editable?`/`#unresolved_tenders?`, enforced with fresh post-lock rechecks in every 4a/4b commercial-editing service, `Pos::AddLine`/`Pos::AddOpenRingLine` transaction-locked against new lines); `Pos::AddCashTender`, `Pos::AddCardTender`, `Pos::RemoveTender`, `Pos::CreateCashMovement`; `Pos::CompleteTransaction` (atomic + idempotent per ADR-0009); `Pos::SuspendTransaction` and `Pos::CancelTransaction` hardened against unresolved Tenders; `Pos::CloseSession` blocked while it controls an open Transaction (which unresolved Tenders always imply); and register UI for the Tender panel, completion, commercial lock messaging, and receipt display (see [service-catalog.md](../service-catalog.md)).

### Tables

- Tender types (if not seeded earlier)
- `pos_tenders` (statuses include `pending`, `authorized`, `completed`, …)
- `pos_cash_movements` (as needed)
- Completion fields on `pos_transactions` (`receipt_number`, `completion_idempotency_key`, totals, `completed_pos_session_id`)

### Behavior

- Cash tender and standalone card stub; split tender.
- **Tender-state lock:** pending or authorized Tender locks commercial editing until tenders are removed or externally voided.
- Externally approved card stored as `authorized` with `authorization_code`, `terminal_reference`, `authorized_at` (optional `requires_reconciliation`); no separate exception table.
- Cash counts toward session close (full Z/reconciliation can mature in Phase 7).
- **Atomic idempotent completion** coordinates: final lines, discounts, tax, tenders, reservation conversion, inventory movements, cost snapshots, receipt-number assignment, transaction completion.
- Completion revalidates calculation under Transaction lock; completed Tender net equals final Transaction net.
- Concurrent completion vs recall/edit: only one succeeds.
- Receipt sequence: locked increment on store (v1 lock); assign only on success.
- Scope: Product-line tracking modes `quantity` and `none` only.

### First demo milestone

```text
opening inventory adjustment
→ reserve on POS line
→ tender
→ complete
→ inventory movement + cost snapshot + receipt number
```

Double-submit of the same completion request must not duplicate postings.

### Exit

- [x] Successful completion posts inventory and assigns receipt number (`test/services/pos/complete_transaction_test.rb`)
- [x] Failed completion leaves no partial inventory/tender/receipt effects (same file; tender-mismatch and department cases)
- [x] Idempotency key prevents duplicate completion (same file; replay + different-key-on-completed cases)
- [x] Quantity negative-sale warning path tested (same file; provisional `last_known` cost + `available` negative warning)
- [x] Tender lock blocks commercial edits while authorized/pending tender exists (same file; `RemoveLine` denial while pending, restored after `RemoveTender`)
- [x] Authorized card tender remains visible after failed internal completion (same file)
- [x] Concurrent completion vs edit/recall tested (`test/services/pos/concurrency_complete_vs_edit_test.rb`; Recall cannot race Complete because Suspend is itself blocked while an unresolved Tender exists — see file comment)

### UX acceptance (4c)

- [x] Tender panel and balance-due presentation; shortcuts request completion only (`app/views/pos_transactions/show.html.erb`)
- [x] Commercial fields locked while unresolved tenders exist; clear path to resume editing (warning banner + `Pos::RemoveTender` affordance)
- [x] Completion in-progress / failed / retry UI aligned with idempotency (no duplicate-submit ambiguity) (stable per-render `completion_idempotency_key` hidden field)
- [x] Receipt presentation after successful completion (receipt number/date/net banner on the transaction page)
- [ ] Critical browser paths covered by system tests (not pixel snapshots) — carried gap from 4a/4b; no `test/system` harness wired up yet in this repo

### Must not

- Post-void sophistication (Phase 6)
- Full stored-value issuance/redemption (Phase 6)
- Individual unit sales (Phase 4d)


---

## Phase 4d — Individually tracked inventory

**Landed** on `phase/p4-point-of-sale`: `inventory_units` schema (generated `27` Unit Identifier; `available`/`reserved`/`sold` baseline statuses plus `inspection`/`damaged`/`discarded` and deferred-capable `rtv`/`in_transfer` reserved in the check constraint without an implemented workflow — see [deferred-capabilities.md](../deferred-capabilities.md); exact `acquisition_cost_cents`; optional `unit_price_cents` override; `product_condition`; free-text `description`/`internal_notes`; a `acquisition_source_type`/`acquisition_source_id` tag pair (`receipt_line`/`return_line`/`buyback`/`adjustment`/`other` — a label only, since none of those sources exist as real polymorphic targets yet); `created_by_user`; `acquired_at`/`sold_at`/`sold_pos_line_item_id`) plus `inventory_unit_id` FKs on `inventory_reservations` (unique active-reservation-per-unit index, quantity pinned to 1) and `pos_line_items` (quantity pinned to 1); the `InventoryUnit` model (organization match, individual-tracking-mode-only, namespace-27 validation, sold-state/`sold_pos_line_item` consistency); `Inventory::CreateInventoryUnit` (Phase 4d's bootstrap mechanism, parallel to Phase 3's opening-inventory-adjustment bootstrap, since receiving is not implemented until Phase 5; enforces `inventory.unit.manage` internally); `Inventory::Reserve`/`Inventory::ReleaseReservation`/`Inventory::ConvertReservation` extended to branch on tracking mode and lock the exact unit row (never the aggregate balance) for individual lines, snapshotting `sold_pos_line_item_id` at conversion; `Pos::AddLine` resolving an exact unit for individually tracked variants and never overselling past `available`; `Pos::UpdateLineQty` rejecting quantity changes on unit-backed lines; `Pos::ResolveScan` resolving a scanned `27` identifier straight to its unit; the `inventory.unit.manage` permission with a minimal admin UI (`InventoryUnitsController`, index/show/new/create) for direct unit creation. See [service-catalog.md](../service-catalog.md).

**Open follow-up:** `acquisition_source_type` includes `buyback`, and the status enum includes `inspection`/`damaged`/`discarded`, ahead of any buyback, inspection, or disposition workflow actually being designed (buyback is an explicitly deferred capability per [deferred-capabilities.md](../deferred-capabilities.md)). No service in this codebase sets those values yet — they are inert labels on the check constraint/enum, not implemented behavior — but a future ADR or deferred-capabilities update should either formally accept them as reserved-ahead-of-design or narrow the enum back down when those workflows are actually scoped.

### Tables

- `inventory_units` (`27` identifiers)
- Reservation and line FKs to exact units

### Behavior

- Unit create/lookup; status transitions; one active reservation per unit.
- Exact acquisition cost; exact-unit completion.
- Never oversell an individual unit.

### Exit

- [x] Exact-unit sale completes and marks unit sold (`test/services/pos/individual_unit_completion_test.rb`)
- [x] Concurrent reserve of same unit fails safely (`test/services/inventory/concurrency_reserve_unit_test.rb`)

---

## Phase 4e — Simple linked returns

**Landed** on `phase/p4-point-of-sale` (working tree / phase branch): return `direction` + original-line link + reason/disposition on `pos_line_items`; `pos.return.create`; `Pos::AddLinkedReturnLine` (historical price/discount/tax/cost; INV-RET-004), `Pos::AddCashRefundTender`, `Inventory::PostCustomerReturn`; recalculate/complete return branches; register UI.

### Behavior

- Return lines linked to original completed sale lines.
- Use original completed commercial values (price, Discount allocations, tax components, Department, cost).
- Return reason and disposition; inventory effects per disposition:
  - `return_to_stock` → on_hand + qty (sellable)
  - `inspection_required` / `damaged` / `return_to_vendor` → on_hand + qty and unavailable + qty (OD-010 still open for per-status buckets; aggregate `unavailable` is used)
  - `discard` → customer_return inbound then quantity_adjustment outbound
  - `non_inventory` → no stock effect when tracking mode is `none`
- Only after 4c is stable.

### Exit

- [x] Linked return completes without mutating the original sale line (`test/services/pos/linked_return_test.rb`)
- [x] Inventory disposition posts through ledger services (`Inventory::PostCustomerReturn` → `customer_return` movement via `PostLedgerEntry` for `return_to_stock`; other dispositions warn and do not restore sellable stock)

---

## Out of scope for Phase 4

- Vendors, purchase orders, receipts, product requests (Phase 5)
- Post-void and full stored value (Phase 6)
- Advanced promotions, offline POS, integrated payments, selected-line tax exemptions, tax-inclusive pricing ([deferred](../deferred-capabilities.md))

## Related

- [phase-03-quantity-inventory-bootstrap.md](phase-03-quantity-inventory-bootstrap.md)
- [phase-04-tax-schema.md](../phase-04-tax-schema.md)
- [../architectural-locks.md](../architectural-locks.md)
- [../../design/README.md](../../design/README.md)
- [../../design/prototypes/ui_mockup/](../../design/prototypes/ui_mockup/)
