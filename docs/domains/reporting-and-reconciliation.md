# Reporting and Reconciliation Domain

**Status:** Consolidated specification  
**Domain owner:** Reproducible operational reports, close reports, exception reporting, and Reconciliation

## Governing ADRs

All accepted ADRs affect reporting because this domain consumes posted results from every operational domain.

The most direct are:

- [ADR-0008: Keep Completed POS Transactions Immutable and Use Explicit Corrections](../adr/0008-immutable-pos-transactions.md)
- [ADR-0010: Distinguish Business Days, Sessions, Devices, Drawers, and Z Reports](../adr/0010-business-days-sessions-and-z-reports.md)
- [ADR-0012: Govern Stored Value Through Independent Accounts and an Append-Only Ledger](../adr/0012-stored-value-ledger.md)
- [ADR-0013: Govern Quantity-Tracked Inventory Cost Through Moving Weighted Average and Explicit Cost Provenance](../adr/0013-govern-quantity-tracked-inventory-cost.md)

## Purpose

This domain turns completed and posted operational records into reproducible business information.

It reports sales and Customer Returns, Price Overrides and Discounts, tax, Tenders, cash, Stored Value, units, cost and margin, inventory and expected supply, Product Requests, Approvals and exceptions, POS Session and Business-Day activity, and Reconciliation.

It does not alter source records.

## Ownership boundary

### Owns

- report definitions;
- reporting projections and exports;
- Session X and Z Reports;
- Business-Day X and Z Reports;
- Reconciliation (comparisons, findings, resolutions; close-time external evidence records);
- exception and audit report definitions;
- future accounting-export batches.

Phase 7 does **not** own a generic balance-changing Reconciliation Adjustment. See [phase-07-reporting-and-reconciliation-v1.md](../implementation/decisions/phase-07-reporting-and-reconciliation-v1.md).

### Consumes but does not own

- completed POS Transactions, Lines, Discounts, taxes, and Tenders;
- cash movements and counts;
- Business Days and POS Sessions;
- Inventory Ledger Entries and Stock Balances;
- Inventory Reservations;
- Purchase Orders, Allocations, and Receipts;
- Product Requests;
- Stored-Value Entries;
- Approvals and audit events.

## Reporting period

Completed activity reports under the Business Day in which it completes.

```text
Suspended Monday, completed Wednesday → Wednesday
Monday sale returned Wednesday → Return reports Wednesday
Monday sale Post-Voided Wednesday → reversal reports Wednesday
```

Corrective records retain their link to the original activity.

## Historical attribution

Reports use completed snapshots of Product and Variant, identifiers and descriptions, Merchandise Class, Department, Tax Category, price, Discount, tax, cost, Tender metadata, and Approval context.

Current master-data changes do not reinterpret completed history.

## Sales definitions

### Gross Sales

Completed sale-line Selling Prices extended by quantity before Discount and tax.

Gross Sales exclude Stored-Value issuance.

### Price-Override Variance

```text
Regular Price - Selling Price
```

Reported separately from Discounts.

### Discounts

Includes line and allocated transaction Discounts, Promotions, coupons, and other realized reductions.

Excludes Price Overrides, tax exemptions, Returns, and Stored-Value redemption.

### Customer Returns

Reports merchandise or service amount reversed through Customer Return lines.

Tax reversal and Tender refund remain separate dimensions.

### Post-Voids

Reported separately from Customer Returns while contributing their exact reversing effect to net results.

### Net Sales

```text
Gross Sales
- Discounts
- Customer Returns
± Post-Void commercial effects
```

Tax and Stored-Value issuance are excluded.

## Tender and cash reporting

Tender reports show received, refunded, and net.

Cash reports additionally distinguish cash received, cash refunded, change, opening cash, paid-ins and paid-outs, safe drops and pickups, expected cash, counted cash, and variance.

## Stored-Value reporting

Reports distinguish account type and Entry type.

Issuance and reload create liability activity. Redemption consumes liability as Tender.

## Tax reporting

Tax reports use completed tax components.

They may show taxable sales, exempt sales, taxable Returns, Discounts reducing taxable base, tax collected, tax refunded, Post-Void adjustments, and net liability by component or jurisdiction.

## Unit, cost, and margin reporting

Unit reporting distinguishes units sold, returned, reversed, and net units.

```text
Gross Margin = net merchandise sales - COGS
```

Returns and Post-Voids reverse original cost.

Missing cost remains distinct from confirmed zero cost.

Actual, estimated, mixed, and unknown inventory valuation remain distinguishable. Totals containing estimated value are labeled as containing estimates. Unknown-cost quantity makes valuation incomplete; reports must not present incomplete valuation as complete. Later cost variances (when introduced under OD-014) report in their posting/settlement period. Completed POS cost snapshots are not restated when later supply or corrections arrive.

Accounting journal patterns, clearing accounts, and export batch protocol remain open. See [inventory cost reporting and accounting design note](../implementation/design-notes/inventory-costing/inventory_cost_reporting_accounting_note.md).

## Inventory and purchasing reporting

Initial reports should include:

- Store stock by Variant;
- On Hand, Reserved, Unavailable, and Available;
- negative inventory;
- individually tracked Units by status;
- old Reservations;
- inventory cost and value;
- open Purchase Orders;
- On Order;
- allocated and unallocated future supply;
- partially received orders;
- expected receipts;
- last ordered and last received dates;
- Receipt discrepancies.

## Product Request reporting

Reports may include open Customer Requests, Staff Suggestions, physically Reserved quantity, allocated On-Order quantity, unfulfilled buyer-review quantity, ageing, and fulfilled, declined, and cancelled Requests.

## Operational exception reporting

Detailed electronic reports include cancelled Transactions, removed Lines, old Suspended Transactions, stale Reservations, Post-Voids, no-receipt Returns, Approvals and overrides, no-sale Drawer openings, cash variances, manual card confirmation, receipt reprints, Inventory Adjustments, and Stored-Value manual adjustments.

Not every exception belongs on a compact printed Z Report.

## X and Z Reports

### Session X

Non-closing snapshot of an open POS Session.

### Session Z

Close report for one POS Session, including sales, Returns, Discounts, tax, Tenders, Stored Value, cash, counts, variance, and exceptions.

### Business-Day X

Non-closing Store-wide snapshot retaining Session detail.

### Business-Day Z

Close report consolidating all Session Z Reports while retaining their breakdown.

A Business Day cannot close while a Session remains open.

## Reconciliation

Close and Reconciliation are distinct.

Close may collect and persist accountability evidence (cash counts; optional session merchant-slip card totals; business-day machine/batch card totals). Reconciliation later reviews those persisted expected-versus-observed variances. A difference does not rewrite source activity.

Standalone-card evidence distinguishes:

- **Merchant-slip / merchant-receipt totals** — cashier accountability for a session when store `card_reconciliation_grain` is `session`;
- **Terminal / machine batch totals** — device settlement for the business day.

These are separate comparison types. Phase 7 delivery detail: [phase-07-reporting-and-reconciliation.md](../implementation/phases/phase-07-reporting-and-reconciliation.md).

### Reconciliation records

Phase 7 does not introduce a generic balance-changing reconciliation adjustment. Use:

- comparisons (expected, observed or unavailable, variance when numeric, external reference);
- findings (reason/category, explanation);
- resolutions (`explained_no_correction`, `accepted_variance`, `linked_domain_correction`, `unresolved`).

Operational balance corrections use the owning domain’s correction mechanism and may be linked from a resolution. Card close evidence may be multi-row with precision `net_only` or `received_and_refunded`. Missing evidence uses `evidence_unavailable` rather than a fabricated observed amount.

Accepted v1 detail: [phase-07-reporting-and-reconciliation-v1.md](../implementation/decisions/phase-07-reporting-and-reconciliation-v1.md).

## Permissions

Exact codes are maintained in [authorization-permissions.md](authorization-permissions.md). Reporting owns view/export and reconcile/resolution keys under `reporting.*`. Session and business-day **close** remain `pos.session.close` / `pos.business_day.close`.

Cost, margin, and audit access may be more restricted than ordinary sales reporting.

## Audit requirements

Audit Session and Business-Day close, Reconciliation (including finalization), reopening where permitted, reconciliation resolutions, significant report generation, export batches, and report-definition or configuration changes.

## Invariants

- Reports use completed or posted source records.
- Reporting does not modify source records.
- Historical attribution uses snapshots.
- Tender remains separate from revenue.
- Stored-Value issuance remains liability activity.
- Customer Returns and Post-Voids remain distinct.
- Received and refunded Tenders remain separately reportable.
- Corrections report in their completion period.
- Missing cost differs from zero cost.
- Inventory valuation provenance (actual / estimated / mixed / unknown) remains reportable.
- Corrective cost variances report in their own period; historical POS cost is not restated.
- Reconciliation does not rewrite operations.
- Session and Business-Day reports remain reproducible.

## Open questions

Phase 7 v1 operational questions are accepted in [phase-07-reporting-and-reconciliation-v1.md](../implementation/decisions/phase-07-reporting-and-reconciliation-v1.md) (reports, print/export, card grain/evidence, taxonomy, reopen, classification views, MVP profile).

Still open beyond Phase 7 core:

- How is dated inventory valuation calculated?
- Which accounting integration is required?
