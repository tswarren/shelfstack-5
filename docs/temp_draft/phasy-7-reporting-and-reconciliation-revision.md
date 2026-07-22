# Phase 7 — Reporting and Reconciliation

**Status:** Not started
**Depends on:** Phases 4c–6 for complete coverage; report contracts may be designed before Phase 6 is finished
**Unlocks:** dependable operational review, financial control, audit review, and later accounting exports
**Governing docs:** [reporting-and-reconciliation](../../domains/reporting-and-reconciliation.md); [architectural-locks](../architectural-locks.md)

## Goal

Produce reproducible operational and financial reports from completed transactions, posted ledgers, persisted close records, and current operational records.

Reporting must preserve the distinction between:

* historical completed activity;
* current operational state;
* append-only movement history;
* close snapshots;
* external reconciliation evidence.

Reports must not rewrite source records or reinterpret completed history using current master data.

## Governing principles

### Posted facts are authoritative

Historical financial reporting uses:

* completed POS line snapshots;
* completed discount allocations;
* completed tax components;
* completed tenders;
* posted inventory movements;
* posted stored-value entries;
* posted cash movements;
* persisted counts and close records.

Current product, department, merchandise-class, tax, price, cost, tender, or policy configuration must not alter completed historical reporting.

### Historical and operational reports are different

Historical reports use immutable completed or posted records.

Operational reports use current records and are expected to change as workflows progress.

Examples:

* completed sales report: historical;
* stored-value ledger activity: historical movement;
* open purchase-order report: current operational state;
* active reservation report: current operational state;
* current stock balance report: current state supported by ledger history.

### Corrective activity reports in its own period

Returns, post-voids, refunds, stored-value reversals, inventory corrections, and other corrective records report under the business day or posting period in which the corrective activity completes.

The original activity remains in its original period.

Corrective reports retain references to the original records.

### Closing and reconciliation are separate

Closing records that operational activity for a session or business day has ended.

Reconciliation records that expected totals were compared with counted or external evidence.

A session or business day may close with a documented variance and be reconciled later.

### Internal consistency is not reconciliation

Internal system totals must satisfy defined invariants.

Examples include:

* transaction line totals equal transaction totals;
* completed tender net equals completed transaction net;
* session totals equal included completed session activity;
* business-day totals equal included session activity;
* stored-value cached balances equal ledger balances;
* inventory balances are explainable by posted movements;
* post-void records exactly reverse their referenced source activity.

An internal inconsistency is a system exception. It must not be resolved merely by entering a reconciliation variance.

### Reconciliation does not replace domain corrections

A reconciliation record documents a difference between ShelfStack and independently observed evidence.

When an actual operational balance requires correction, the resolution must use the owning domain’s correction mechanism, such as:

* cash-movement correction;
* inventory adjustment;
* stored-value manual adjustment;
* tender or processor correction;
* another explicit reversing or adjusting record.

The reconciliation record may reference the corrective record but does not itself mutate operational balances.

## Report contracts

Each report implemented in this phase must define:

* purpose;
* report grain;
* authoritative sources;
* reporting-date attribution;
* available filters;
* dimensions;
* measures;
* sign conventions;
* inclusion and exclusion rules;
* correction treatment;
* expected subtotals and tie-outs;
* access permissions;
* print and export behavior;
* freshness or source cutoff;
* whether the report is live, recomputed, or persisted.

Shared report terminology and formulas must be defined once and reused across reports.

## Reporting sources

| Report class                                                      | Primary authority                                                           |
| ----------------------------------------------------------------- | --------------------------------------------------------------------------- |
| Historical sales, returns, tax, classifications, cost, and margin | Completed POS snapshots                                                     |
| Discounts and price-override variance                             | Completed POS lines, discounts, and allocations                             |
| Tender activity                                                   | Completed POS tenders                                                       |
| Inventory quantities and movement valuation                       | Inventory ledger and current stock balances                                 |
| Individually tracked inventory                                    | Inventory units and inventory ledger                                        |
| Stored-value history and liability                                | Stored-value ledger and account balance cache                               |
| Open ordering and receiving operations                            | Current purchase orders, purchase-order lines, receipts, and receipt lines  |
| Active and stale holds                                            | Current reservation records and their source records                        |
| Cash accountability                                               | Sessions, completed cash tenders, cash movements, counts, and business days |
| Approvals and exceptions                                          | Approval, audit, correction, and exception records                          |
| Session and business-day close                                    | Completed activity plus persisted Z-report snapshots                        |

## Commercial reporting

### Sales activity

Provide summary and detail reporting for:

* gross sales;
* discounts;
* price-override variance;
* customer returns;
* post-void commercial reversals;
* net sales;
* units sold;
* units returned;
* units reversed;
* net units;
* cost of goods sold;
* gross margin.

Gross sales are completed sale-line extended selling prices before discounts and tax.

Gross sales exclude stored-value issuance.

Price-override variance is reported separately from discounts.

Returns and post-voids remain separate measures even when both reduce net activity.

### Classification reporting

Historical commercial reports use snapshotted:

* department;
* merchandise class where captured;
* product and variant identifiers;
* description;
* tax category;
* inventory-tracking mode;
* other completed classifications required by the report.

Current master-data names may be used for navigation or optional current-state analysis, but they must not replace historical snapshots.

### Margin reporting

Margin is based on completed POS cost snapshots.

Reports must distinguish:

* confirmed zero cost;
* missing or unavailable cost;
* ordinary quantity-tracked cost;
* exact individually tracked cost;
* cost reversed by returns;
* cost reversed by post-voids.

Tax and stored-value activity are excluded from merchandise margin.

## Discount and price-control reporting

Provide reporting for:

* line discounts;
* transaction discounts and their line allocations;
* promotions;
* coupons;
* employee or membership discounts;
* manual discounts;
* regular price;
* approved selling price;
* price-override variance;
* requesting user;
* approving user;
* reason;
* authority used.

Discounts, price overrides, returns, tax exemptions, and stored-value redemption must remain separate report classifications.

## Tax reporting

Tax reporting must be available by store, business day, tax component, jurisdiction, tax category, and department snapshot.

Reports should distinguish:

* taxable sales basis;
* exempt sales basis;
* zero-rated sales basis where applicable;
* discounts reducing taxable basis;
* tax collected;
* taxable return basis;
* tax refunded;
* post-void adjustments;
* net taxable basis;
* net tax liability.

Completed tax components and exemption snapshots are authoritative.

Current tax rates and rules must not be used to recalculate historical activity.

## Tender reporting

Tender reports must show separately:

* amounts received;
* amounts refunded;
* net tender activity;
* cash presented;
* cash applied;
* change given;
* card tender references;
* stored-value redemption;
* checks or other tender categories;
* original-tender restoration;
* non-original refund exceptions.

Tender reports must not present only a net amount when received and refunded activity occurred.

Stored-value redemption is tender activity, not a discount or reduction of sales.

## Session and business-day reporting

### Session X report

A Session X report is a live, non-closing snapshot of an open session.

It:

* recalculates from current posted session activity;
* does not close or reconcile the session;
* does not assign a session Z number;
* does not modify operational records.

### Session Z report

A Session Z report is generated when a session closes.

It includes:

* sales;
* returns;
* post-voids;
* discounts;
* price-override variance;
* tax;
* tenders received;
* tenders refunded;
* stored-value activity;
* cash received;
* cash refunded;
* change given;
* cash movements;
* opening cash;
* expected cash;
* recorded counts;
* variance;
* operational exceptions.

The original Session Z result is persisted and immutable.

### Business-day X report

A Business-day X report consolidates current business-day activity without closing the business day.

It retains session-level breakdowns.

### Business-day Z report

A Business-day Z report is generated when the business day closes.

It:

* consolidates all sessions belonging to the business day;
* retains session-level breakdowns;
* receives the business-day Z number;
* is persisted as an immutable close result;
* may be reconciled later without being rewritten.

A business day cannot close while any session remains open.

### Z-report persistence

Persisted Z reports should retain:

* report scope and source record;
* business date;
* Z number;
* generation timestamp;
* generating user;
* report-definition version;
* source cutoff;
* generated totals;
* session breakdown where applicable.

Reprints reproduce the original persisted result.

## Cash accountability

Expected cash must be derived from explicit cash activity, including:

* opening cash;
* cash tenders received;
* cash refunds;
* change given;
* additional float;
* paid-ins;
* paid-outs;
* safe drops;
* pickups;
* transfers;
* posted cash corrections.

Cash counts are append-only.

A recount creates another count record and does not overwrite the original count.

Cash variance is:

`counted cash - expected cash`

Reports must retain:

* original count;
* later recounts;
* responsible user;
* count time;
* variance;
* explanation;
* reviewer or approver;
* resolution.

## Reconciliation

### Reconciliation scopes

Initial reconciliation scopes are:

* POS session;
* business day;
* tender category within a session or business day.

### Reconciliation comparison

Each reconciliation comparison records:

* expected ShelfStack amount;
* independently observed amount;
* calculated variance;
* evidence or external reference;
* explanation;
* responsible user;
* reviewer or approver;
* status;
* resolution;
* related domain correction where applicable.

Examples include:

* expected cash versus drawer count;
* ShelfStack card tenders versus standalone terminal total;
* ShelfStack checks versus checks physically present;
* business-day external tender totals versus processor totals.

### Reconciliation findings

A reconciliation finding documents an unexplained or explained variance.

Suggested states are:

* open;
* explained;
* correction_required;
* resolved;
* accepted_variance.

Final status names may be adjusted during schema design.

### Reconciliation resolutions

A resolution may:

* explain a timing difference;
* document an external terminal error;
* accept an authorized cash overage or shortage;
* link to a cash correction;
* link to a tender correction;
* link to a stored-value adjustment;
* link to another domain-owned corrective record.

A reconciliation resolution does not edit the original completed transaction, tender, ledger entry, count, or Z report.

## Inventory reporting

Initial inventory reports include:

* current stock by store and variant;
* on hand;
* reserved;
* unavailable;
* available;
* on order;
* negative availability;
* inventory movements;
* movement quantity and cost;
* individually tracked units by status;
* stale reservations;
* inspection inventory;
* damaged inventory;
* RTV-held inventory;
* current inventory valuation;
* missing-cost exceptions;
* balance-to-ledger integrity exceptions.

Current inventory valuation must define its cost basis explicitly.

Historical margin uses completed POS cost snapshots and must not be recalculated from current inventory cost.

Arbitrary historical inventory valuation is included only when the ledger and costing implementation can reproduce it reliably.

## Purchasing and receiving reporting

Initial operational reports include:

* open purchase orders;
* purchase-order lines with remaining quantity;
* partially received orders;
* overdue expected receipts;
* cancelled and closed order quantities;
* on-order quantity by store and variant;
* purchase-order allocations;
* receipts by vendor and date;
* delivered, accepted, rejected, damaged, and inspection quantities where supported;
* expected versus actual cost;
* receiving discrepancies;
* unlinked receipt lines;
* last ordered date;
* last received date.

These reports read current purchasing records and posted receiving records rather than completed POS snapshots.

## Stored-value reporting

Stored-value reports distinguish:

* gift card;
* store credit;
* trade credit.

Activity reports distinguish:

* issuance;
* reload;
* redemption;
* refund to account;
* issuance reversal;
* redemption reversal where supported;
* manual adjustment.

Provide a liability roll-forward:

`opening liability`
`+ issuance`
`+ reloads`
`+ refunds to stored value`
`+ positive adjustments`
`- redemptions`
`- reversals`
`- negative adjustments`
`= closing liability`

Reports must support:

* activity by account type;
* activity by store and business day where applicable;
* account-level ledger history;
* closing liability by account type;
* ledger-to-cached-balance integrity checks;
* manual-adjustment and approval review.

Stored-value issuance is excluded from ordinary sales revenue.

## Exception and approval reporting

Initial exception and approval reports include:

* post-voids;
* blocked post-void attempts where retained;
* no-receipt returns;
* non-original tender refunds;
* cash refund exceptions;
* price overrides;
* discount overrides;
* tax-exemption overrides;
* manual tax adjustments;
* stored-value adjustments;
* inventory adjustments;
* cash variances;
* paid-outs;
* no-sale drawer openings;
* removed pending lines;
* cancelled transactions;
* stale suspended transactions;
* manual card confirmations;
* receipt reprints;
* manual reservation releases;
* negative-inventory activity;
* missing-cost activity;
* requester, approver, reason, and authority snapshot.

Compact Z reports may summarize exceptions. Detailed electronic reports retain complete records.

## Filters and dimensions

Reports should use consistent filters where applicable:

* organization;
* store;
* business date;
* calendar timestamp range;
* session;
* cashier;
* salesperson;
* department snapshot;
* merchandise-class snapshot where available;
* tax category;
* tax component;
* tender type;
* product;
* variant;
* vendor;
* stored-value account type;
* correction type;
* approval type.

Business date and calendar timestamp must remain distinct.

## Access control

Reporting permissions should be separated at least into:

* sales reporting;
* tax reporting;
* tender reporting;
* cash reporting;
* inventory reporting;
* purchasing and receiving reporting;
* stored-value reporting;
* cost reporting;
* margin reporting;
* approval and exception reporting;
* reconciliation;
* audit reporting.

Access to cost, margin, stored-value account details, cash counts, and audit records may be more restricted than access to ordinary sales totals.

## Presentation and export

Initial presentation requirements:

* printable Session X and Z reports;
* printable Business-day X and Z reports;
* screen-based summary and drill-down reports;
* CSV export for tabular reports;
* links from summaries to underlying source records where permitted;
* clear indication of report scope, business date, generation time, filters, and whether the report is live or persisted.

CSV report export is not an accounting export batch.

## Internal integrity checks

Phase 7 must provide detectable exceptions for at least:

* completed transaction totals not matching completed lines;
* completed tender net not matching transaction net;
* discount allocations not matching applied discounts;
* tax components not matching line tax totals;
* session totals not matching included transaction activity;
* business-day totals not matching included sessions;
* stored-value cached balances not matching ledger balances;
* inventory balances not explainable by posted movements;
* duplicate or incomplete post-void relationships;
* missing historical snapshots required by reports.

Internal integrity failures must not be hidden by reconciliation entries.

## Likely supporting records

Schema design should consider records equivalent to:

* persisted report snapshots for Session and Business-day Z reports;
* reconciliation headers;
* reconciliation comparison or finding lines;
* reconciliation evidence or references;
* reconciliation resolutions;
* links from reconciliation resolutions to domain-owned corrective records.

A generic reconciliation record must not act as an alternative financial, inventory, cash, or stored-value ledger.

## Exit criteria

* [ ] A completed sales report is unchanged after a product, department, merchandise class, tax category, or user-facing description is renamed.
* [ ] Returns and post-voids appear in the business day in which the corrective activity completes and retain links to their originals.
* [ ] Gross sales, discounts, returns, post-voids, net sales, tax, tenders, cost, and margin use documented shared definitions.
* [ ] Price-override variance is separate from discounts.
* [ ] Received and refunded tenders are separately reportable.
* [ ] Completed tender net ties to completed transaction net.
* [ ] Session totals tie to included completed session activity.
* [ ] Business-day totals tie to included session activity.
* [ ] A Session X report does not close, reconcile, or otherwise modify the session.
* [ ] A persisted Session Z report can be reproduced or reprinted without using current master data.
* [ ] A business day cannot close while any session remains open.
* [ ] Session close and session reconciliation are separate events.
* [ ] Business-day close and business-day reconciliation are separate events.
* [ ] Original and recount cash-count records are both retained.
* [ ] Cash variance is calculated from expected cash and the applicable persisted count.
* [ ] Card reconciliation can compare ShelfStack tender totals with manually entered standalone-terminal totals.
* [ ] A reconciliation finding does not alter any original POS transaction, tender, inventory movement, stored-value entry, cash movement, count, or Z report.
* [ ] An operational correction created during reconciliation uses the owning domain’s correction mechanism and is linked from the reconciliation record.
* [ ] Internal integrity failures cannot be cleared merely by entering an accepted reconciliation variance.
* [ ] Current inventory balances and movements can be reported by store and variant.
* [ ] Inventory balance-to-ledger inconsistencies are detectable.
* [ ] Historical margin uses completed cost snapshots rather than current inventory cost.
* [ ] The stored-value liability roll-forward ties to ledger activity.
* [ ] Stored-value cached-balance discrepancies are detectable.
* [ ] The open-PO report reads current purchasing records and changes when the order is received, cancelled, or closed.
* [ ] Cost and margin reports require their designated permissions.
* [ ] Core tabular reports can be exported to CSV without creating accounting entries.

## Out of scope

* accounting journal generation;
* accounting export batches;
* external bookkeeping integrations;
* rewriting completed history to use current classifications;
* generic user-defined report builders;
* business-intelligence dashboards;
* destructive reconciliation;
* editing persisted Z reports;
* replacing domain-specific corrections with generic reconciliation adjustments;
* processor settlement automation requiring integrated payments;
* arbitrary historical inventory valuation unless explicitly supported by the inventory ledger and costing implementation;
* restating historical sales under current catalog or department assignments.

## Related

* [../roadmap.md](../roadmap.md)
* [phase-04-point-of-sale.md](phase-04-point-of-sale.md)
* [phase-05-supply-and-demand.md](phase-05-supply-and-demand.md)
* [phase-06-corrections-and-stored-value.md](phase-06-corrections-and-stored-value.md)
