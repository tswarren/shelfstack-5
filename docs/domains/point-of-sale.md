# Point-of-Sale Domain

**Status:** Consolidated specification  
**Domain owner:** Store checkout, Business Days, Sessions, Transactions, pricing realization, tax, Tenders, cash, receipts, returns, and completed corrections

## Governing ADRs

- [ADR-0006: Use Explicit Inventory Quantities and Reservation Records](../adr/0006-inventory-quantities-and-reservation-records.md)
- [ADR-0008: Keep Completed POS Transactions Immutable and Use Explicit Corrections](../adr/0008-immutable-pos-transactions.md)
- [ADR-0009: Complete POS Transactions Atomically and Idempotently](../adr/0009-atomic-idempotent-pos-completion.md)
- [ADR-0010: Distinguish Business Days, Sessions, Devices, Drawers, and Z Reports](../adr/0010-business-days-sessions-and-z-reports.md)
- [ADR-0011: Separate Permissions, Numeric Authority, and Approval Events](../adr/0011-permissions-authority-and-approvals.md)
- [ADR-0012: Govern Stored Value Through Independent Accounts and an Append-Only Ledger](../adr/0012-stored-value-ledger.md)

## Purpose

The POS domain coordinates completion of retail activity across Catalog, Classification, Authorization, Inventory, Stored Value, and Reporting.

It records sales and Customer Returns, Open-Ring and Stored-Value lines, Price Overrides, Discounts, tax, Tenders and refunds, Business Days and POS Sessions, cash accountability, receipt identity, and completed corrections.

## Ownership boundary

### Owns

- Business Day;
- POS Session;
- POS Transaction;
- POS Line Item;
- POS Discount and Discount Allocation;
- completed tax component;
- POS Tender;
- cash movement and count;
- Receipt Number and print event;
- Customer Return records;
- Post-Void links;
- POS-specific workflow state.

### Coordinates but does not own

- User, Permission, authority, and Approval;
- Product and Product Variant;
- Merchandise Class, Department, Tax Category, and Tax Rules;
- Inventory Reservation and Inventory Movement;
- Stored-Value Account and Stored-Value Entry;
- report definition and Reconciliation.

## Core principles

- A POS Transaction is a checkout container, not a rigid sale-or-return type.
- Completed Transactions and Lines are immutable.
- Price Override, Discount, tax, Tender, inventory, and Stored Value remain distinct layers.
- Completion is atomic and idempotent.
- Historical values are snapshotted.
- Corrections create new linked records.

## Business Day

A Business Day is the Store-wide operating and reporting period.

Suggested attributes:

- Store;
- explicit Business Date;
- status;
- opened and closed timestamps and Users;
- reconciled timestamp and User;
- sequential Store Z-Report Number.

Statuses:

```text
open
closed
reconciled
```

Only one Business Day may be open per Store. The Business-Date assignment policy remains Open.

## POS Session

A POS Session is an accountability period within one Business Day.

Suggested attributes:

- Business Day;
- Store;
- POS Device;
- optional Cash Drawer;
- responsible User;
- status;
- open, close, and reconcile identity;
- opening, expected, and counted cash;
- Cash Variance;
- Session Z number.

A card-only Session may have no Drawer.

## POS Transaction

Suggested statuses:

```text
open
suspended
completed
cancelled
```

Allowed transitions:

```text
open → suspended
open → completed
open → cancelled
suspended → open
suspended → cancelled
```

A Completed Transaction does not transition.

Suggested attributes include public identifier, Store, origin/active/completion Session, Customer when applicable, cashier, salesperson, Receipt Number, timestamps, reversal references, monetary totals, and completion idempotency key.

A Transaction may open in one Session and complete in another.

## Suspended Transactions

Suspension retains Inventory Reservations, does not automatically expire, is limited to the same Store, requires no unresolved Tender activity, and may be actively recalled by one register at a time.

On recall, current prices, Promotions, tax, classification, and eligibility are refreshed. Material changes are shown to the cashier.

## POS Line Item

Directions:

```text
sale
return
```

Line kinds:

```text
product
open_ring
stored_value
```

`stored_value` is reserved for Phase 6 and is inactive until Stored Value delivery.

Statuses (full enum from table introduction):

```text
pending
completed
removed
```

Amounts and quantities remain positive; direction determines effect.

Inventory-tracking mode (`quantity`, `none`, `individual`) belongs to the Product Variant. It is not a POS line kind. A non-inventory service sold through catalog remains a Product line with Variant, Department, Tax Category, price, discounts, and returns, and creates no Inventory Reservation when tracking mode is `none`.

### Product Line

Requires Product Variant, postable Department, Tax Category, and exact Inventory Unit where individual tracking applies.

Product lines use the Tax Category resolved from catalog defaults unless an authorized Tax Category override is recorded.

### Open-Ring Line

Requires an effective description, postable Department, Tax Category, and price. It references no Product Variant and creates no Inventory Reservation.

User-entered description may be blank during entry. The line must always resolve an effective description; if blank, effective description defaults to the selected Department name. The effective description is snapshotted before Completion.

Tax Category initially defaults from the selected Department. Selecting a different Tax Category at create, or changing Tax Category after the line exists, is an audited Tax Category override (`pos.tax_category.override`), not ordinary line editing.

### Stored-Value Line

Represents issuance or reload and does not create ordinary merchandise inventory or revenue.

## Reservations

Adding a Product Line with quantity or individual tracking creates an Inventory Reservation. Product lines with tracking mode `none` do not.

- quantity tracking reserves quantity;
- individual tracking reserves exact Unit;
- removal or Cancellation releases;
- suspension retains;
- Completion converts to Inventory Movement.

Quantity-tracked sale may create negative inventory after warning where policy permits.

## Pricing and Discounts

```text
Regular Price
→ Selling Price after Price Override
→ Gross Amount
→ Discount
→ Net Amount
→ Tax
→ Total Amount
```

Price Override is distinct from Discount.

Transaction Discounts must be allocated deterministically among eligible lines. Allocations are stored for tax, returns, and reporting.

Advanced Promotion definitions remain Deferred.

## Tax

Tax calculation is governed by [ADR-0014](../adr/0014-hybrid-transaction-component-tax-calculation.md).

Tax is calculated after Discount allocation. Only Discounts with `tax_treatment = reduces_taxable_base` reduce the taxable merchandise amount.

ShelfStack uses a hybrid model:

1. resolve taxability, Tax Category, Store Tax Rule treatment, taxable fraction, exemptions, and taxable merchandise amount per line;
2. aggregate and round once per transaction tax component and line direction;
3. allocate rounded taxable base and tax amounts back to lines with largest remainder;
4. store completed line tax-component records that reconcile to each line’s Tax Amount.

Sale and return directions are calculated separately. Removed lines and Stored-Value lines do not participate in ordinary merchandise tax calculations.

Final tax rules use the store-local calendar date at Completion, not the Business Day `reporting_date`. Open and recalled Transactions display current provisional calculations; Completion re-resolves and validates that applicable rules remain current.

Completed line tax components retain taxable amount, rate, allocated tax amount, component order, compounding behavior, treatment, receipt code, Tax Category, Store Tax Rule, and Store Tax Rate used (when applicable).

Linked Returns and Post-Voids reverse stored tax components exactly rather than recalculating current tax.

### Tax Category override

Changing the effective Tax Category on a POS line is a restricted, audited action (`pos.tax_category.override`). Ordinary cashiers must not change Product-line Tax Categories through ordinary line edit. Override records retain original Tax Category, override reason, actor, and timestamp.

### Tax Exemptions

Initial transaction Tax Exemptions use coverage `whole_transaction`: the exemption applies to all otherwise taxable qualifying lines and components in that Transaction.

Deferred:

* `selected_lines`;
* `selected_tax_components`;
* a later `pos_tax_exemption_applications` table binding exemption to specific lines or component identities.

Reusable exemption masters remain Deferred. Completed activity snapshots the exemption evidence and coverage used.

### Recalculation ownership

One service owns provisional recalculation order for an editable Transaction:

```text
resolve prices
→ allocate discounts
→ calculate tax
→ calculate transaction totals
```

Changes to line quantity, selling price, Price Override, Discount or allocation, Department where it affects Tax Category, Tax Category, Tax Exemption, effective Store Tax Rules, or line removal/restoration invalidate and recalculate totals. Controllers must not update cached totals independently of that ownership.

Service boundary:

* `Tax::CalculateTransaction` — deterministic calculation (bases, components, warnings, blockers, metadata);
* `Pos::RecalculateTransaction` — persists pending allocations and tax records for an editable Transaction;
* `Pos::CompleteTransaction` — revalidates under lock and finalizes atomically.

## Tenders

Tender directions:

```text
received
refunded
```

Only completed Tenders settle a Transaction.

```text
completed received Tenders
- completed refunded Tenders
= Transaction net total
```

### Tender-state lock

Once a pending or authorized Tender exists:

* line additions, removals, quantities, prices, Discounts, Tax Categories, exemptions, and other tax-affecting fields are locked;
* the cashier must remove the Tender or confirm the required external void before commercial editing may resume;
* changing an authorized standalone-card amount requires voiding or reprocessing it externally.

`CompleteTransaction` revalidates the current calculation under Transaction lock and requires completed Tender net to equal the final Transaction net.

### Cash

Records amount presented, amount applied, and change.

### Card

MVP uses standalone terminals. ShelfStack stores no full card number. An externally approved card Tender is stored as `status: authorized` with fields such as `authorization_code`, `terminal_reference`, and `authorized_at` before internal Completion. If Completion fails, that authorized Tender remains visible and unsettled for operational follow-up. A separate exception table is not required for Phase 4c.

### Stored Value

Redemption is a received Tender and posts through the Stored Value domain.

## Customer Returns

Return sources may include:

```text
linked_sale
external_receipt
gift_receipt
no_receipt
```

Linked Return references the original completed sale line and uses historical price, Discount, tax, Department, cost, and eligibility.

Unlinked Return requires explicit Product or Variant, source, Refund Basis, Return Reason, Return Disposition, tax treatment, and Approval where required.

Return Reason and Disposition remain separate.

## Cancellation

Cancellation applies before Completion.

It releases provisional Reservations and creates no completed sale, Return, Tender, inventory, tax, cost, or Stored-Value effect.

## Post-Void

Post-Void is a new Completed Transaction fully reversing an original Completed Transaction.

It receives its own Receipt Number, uses original historical values, reverses lines, tax, cost, inventory, Tenders, and Stored Value, and may be blocked when full reversal is no longer possible.

Partial correction uses Customer Return or another explicit correction.

## Cash accountability

Cash movements may include:

```text
additional_float
safe_drop
cash_pickup
paid_in
paid_out
correction
transfer_in
transfer_out
```

No-sale Drawer openings require reason and audit.

Closing counts and later recounts remain separate records.

```text
Cash Variance = counted cash - expected cash
```

## Completion workflow

Before Completion validate Transaction, Business Day and Session, sale eligibility, exact Units, Reservations, prices and classifications, postable Departments, Discounts and tax, Return Approvals and Dispositions, exact Tender settlement, Stored-Value balance, card confirmation, and idempotency.

Completion blocks when the resolved Department on a contributing line is missing, inactive, or non-postable (`postable = false`).

Within one database transaction:

1. lock Transaction;
2. lock inventory and Stored-Value records;
3. finalize Lines, Discounts, and tax;
4. snapshot classification and cost;
5. convert Reservations and post Inventory Movements;
6. update Unit statuses;
7. post Stored-Value Entries;
8. finalize Tenders;
9. obtain Receipt sequence;
10. assign Receipt Number;
11. mark Lines and Transaction completed;
12. store final totals;
13. commit.

## Permissions

The `pos.*` permission set covers access, Transaction lifecycle, line removal, Discounts and Price Overrides, Returns, Tender exceptions, tax exemptions, Session and Business-Day control, cash movements, variance review, receipt reprint, Post-Void, Approval, and Reconciliation Adjustment.

Exact codes are maintained in [authorization-permissions.md](authorization-permissions.md).

## Audit requirements

Audit Transaction lifecycle, line removal, Price Override, Discount, tax exemption, Customer Return and Disposition, Tender activity, Session and Business-Day control, cash movements and counts, Post-Void, receipt reprint, and Approvals.

## Invariants

- Completed Transactions and Lines are immutable.
- Receipt Number is assigned only at successful Completion.
- A Completed Transaction has one Store-unique Receipt Number.
- Product Lines resolve exact Variants.
- Individually tracked Lines resolve exact Units.
- Removed Lines create no completed effect.
- Tender net equals Transaction net.
- Discount Allocations reconcile.
- Tax components reconcile.
- Pending or authorized Tenders lock commercial editing until cleared.
- Linked Returns do not exceed remaining quantity.
- Customer Return does not alter original Line.
- Post-Void is a new full reversing Transaction.
- Completion is atomic and idempotent.
- Business Day cannot close with an open Session.
- Closing and Reconciliation remain separate.

## Open and deferred questions

- Business / reporting-date assignment for v1 is accepted (OD-001); later policy refinements remain possible without rewriting history.
- Which advanced Promotion strategies are required?
- What is the final reusable Tax-Exemption model? (transaction-scoped exemptions may exist earlier; ADR-0014)
- Tax-inclusive pricing and jurisdiction-configurable line-level rounding remain Deferred (ADR-0014).
- When will integrated payment processing be introduced?
- What offline POS behavior is required?
- Are café routing, tips, weighted merchandise, layaway, and installments needed?
- When should Suspended Transactions expire, if ever?
