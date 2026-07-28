# POS Printing — X and Z Reports

**Status:** Draft
**Scope:** Printable Session X Reports, Session Z Reports, and Business-Day Z Reports
**Parent specification:** [Common Document Contract and Taxonomy](common-document-contract-and-taxonomy.md)
**Related domains:** Reporting and Reconciliation, Point of Sale, Cash Accountability, Stored Value, Authorization

---

## 1. Purpose

This specification defines the printable operational reports used to review and close ShelfStack POS activity:

1. **Session X Report** — an interim view of a currently open POS Session.
2. **Session Z Report** — the final accountability report for one closed POS Session.
3. **Business-Day Z Report** — the final consolidated report for one closed Store Business Day.

These reports share a common vocabulary and presentation system, but differ materially in scope and finality.

```text
Session X
→ current interim calculation
→ open Session
→ may be generated repeatedly
→ does not close or persist a final report

Session Z
→ final persisted report
→ one closed Session
→ generated once at Session close
→ later copies are reprints

Business-Day Z
→ final persisted report
→ one closed Store Business Day
→ consolidates all Sessions and Store-level activity
→ later copies are reprints
```

---

## 2. Governing principles

1. X and Z Reports are internal operational and financial documents.

2. Printing a report does not create, complete, reverse, reconcile, or modify POS activity.

3. A Session X Report is an interim projection of posted facts available at generation time.

4. Generating or printing a Session X Report does not close the Session.

5. Generating an X Report does not reset counters, totals, or accountability.

6. A Session Z Report is generated as part of successfully closing a POS Session.

7. A Business-Day Z Report is generated as part of successfully closing a Business Day.

8. A final Z Report is persisted and generated only once for its source Session or Business Day.

9. Z Report reprints use the persisted report payload and must not recalculate the closed period from current master data.

10. X Reports use current posted facts and current presentation labels at generation time.

11. Open, suspended, cancelled, or failed Transactions do not contribute completed commercial activity.

12. Completed activity belongs to the Session and Business Day in which completion occurred.

13. Cash Movements contribute according to their posted Session, Store, direction, and Movement Type.

14. Stored-Value issuance, reload, redemption, refund, adjustment, and reversal remain distinct from ordinary sales and Tenders.

15. Price Override variance is not reported as a Discount.

16. Tax is reported separately from merchandise sales and Returns.

17. Printing or rendering failure does not reopen or invalidate a closed Session or Business Day.

18. Report content is subject to field-level permissions for cash, cost, margin, and other sensitive facts.

19. Original versus reprint status applies to persisted Z Reports, not to live X Reports.

20. Historical Z Report amounts and classifications must remain reproducible after configuration changes.

---

# 3. Report taxonomy

## 3.1 Session X Report

An interim operational report for one open POS Session.

It answers:

> What posted activity and cash accountability does this Session currently contain?

A Session X Report may be generated any number of times while the Session remains open.

It is not a closing record.

## 3.2 Session Z Report

The final persisted accountability report for one closed POS Session.

It answers:

> What completed activity belongs to this Session, what cash was expected and counted, and what variance was recorded when the Session closed?

One Session produces at most one Session Z Report.

## 3.3 Business-Day Z Report

The final persisted Store-wide report for one closed Business Day.

It answers:

> What completed activity belongs to this Store Business Day across all Sessions, and how was the day closed and reconciled?

One Business Day produces at most one Business-Day Z Report.

---

# 4. Report scope

## 4.1 Session scope

Session X and Session Z Reports include activity assigned to one POS Session.

This includes:

* completed POS Transactions;
* completed Sale and Return Lines;
* completed Discounts;
* completed Tax Components;
* completed Tenders;
* completed Stored-Value activity associated with those Transactions;
* posted Session Cash Movements;
* No Sale Events;
* Session Cash Counts;
* Post-Void activity completed in the Session;
* applicable card-reconciliation evidence;
* reconciliation adjustments associated with the Session.

The report does not include:

* another Session’s activity;
* open or suspended Transaction estimates;
* removed Lines;
* unresolved Tenders;
* failed payment attempts;
* unposted Cash Movements.

## 4.2 Business-Day scope

The Business-Day Z Report includes:

* every completed Transaction assigned to the Business Day;
* every closed Session assigned to the Business Day;
* all posted Cash Movements within the Business Day;
* all Session Z summaries;
* Store-level card evidence;
* Store-level reconciliation adjustments;
* Business-Day close facts;
* Store-wide accountability and variance.

A Business-Day Z Report is not merely a concatenation of printed Session Z Reports.

It is a consolidated report generated from the authoritative Business-Day facts and persisted report payload.

---

# 5. Source and persistence contract

## 5.1 Session X

The Session X Report is built from current authoritative records at generation time.

Recommended service:

```ruby
Reporting::BuildSessionXReport
```

Input:

```ruby
pos_session:
actor:
```

Output:

```ruby
Reporting::ReportDocument
```

The result is not required to be persisted for MVP.

The report should record within the document:

* generation timestamp;
* source cutoff timestamp;
* Session status;
* generating User.

## 5.2 Session Z

The Session Z Report is generated during Session close and persisted.

The persisted report must include:

* Session;
* Store;
* Business Date;
* Z Number;
* generation timestamp;
* generating User;
* source cutoff timestamp;
* report-definition version;
* final report payload;
* expected cash;
* counted cash;
* cash variance.

Later rendering uses the persisted payload.

## 5.3 Business-Day Z

The Business-Day Z Report is generated during Business-Day close and persisted.

The persisted report must include:

* Business Day;
* Store;
* Business Date;
* Z Number;
* generation timestamp;
* generating User;
* source cutoff timestamp;
* report-definition version;
* final consolidated payload.

Later rendering uses the persisted payload.

---

# 6. Report identity

## 6.1 Session X identity

A Session X Report does not receive a permanent Report Number.

It is identified by:

* Store;
* Register or POS Device;
* Session;
* Session opening timestamp;
* report generation timestamp.

Example:

```text
SESSION X REPORT
Store MAIN · Register 02
Session opened Jul 27, 2026 9:01 AM
Generated Jul 27, 2026 2:16 PM
```

## 6.2 Session Z identity

A Session Z Report receives a Store-scoped Session Z Number.

Example:

```text
SESSION Z REPORT
Session Z 000184
Store MAIN · Register 02
Business date Jul 27, 2026
```

The Z Number:

* is assigned only when Session close succeeds;
* is immutable;
* is unique within the Store’s Session Z namespace;
* is not reused;
* does not change on reprint.

## 6.3 Business-Day Z identity

A Business-Day Z Report receives a Store-scoped Business-Day Z Number.

Example:

```text
BUSINESS-DAY Z REPORT
Business-Day Z 000042
Store MAIN
Business date Jul 27, 2026
```

Session and Business-Day Z Numbers use separate namespaces.

---

# 7. Common report structure

A printed report should use this general order:

1. Store header;
2. report title and status banner;
3. report identity and scope;
4. time range and source cutoff;
5. Transaction activity;
6. sales and Return totals;
7. Discount and Price Override summaries;
8. Tax summary;
9. Tender summary;
10. Stored-Value summary;
11. Cash Movement summary;
12. cash accountability;
13. corrections and control activity;
14. exceptions or reconciliation adjustments;
15. close and generation facts;
16. signature or review block;
17. report footer.

Sections with no activity may be:

* omitted; or
* shown with a zero total where their absence could be ambiguous.

The approach should remain consistent within each report type.

---

# 8. Store header

Reports use the current Store header.

The header may include:

* Store name;
* Organization name;
* Store address;
* Store code or number;
* phone number.

A later Z Report reprint may use updated Store contact information.

Historical report amounts, scope, dates, classifications, and control totals remain sourced from the persisted report.

---

# 9. Time and cutoff presentation

Every report must state its reporting interval.

## 9.1 Session X

```text
Session opened: Jul 27, 2026 9:01 AM
Through:        Jul 27, 2026 2:16 PM
```

The `Through` timestamp is the source cutoff.

## 9.2 Session Z

```text
Session opened: Jul 27, 2026 9:01 AM
Session closed: Jul 27, 2026 5:14 PM
Source cutoff:  Jul 27, 2026 5:14 PM
```

## 9.3 Business-Day Z

```text
Business date:  Jul 27, 2026
Day opened:     Jul 27, 2026 8:42 AM
Day closed:     Jul 28, 2026 12:18 AM
Source cutoff:  Jul 28, 2026 12:18 AM
```

The Business Date is an operational reporting date and may differ from the calendar date at close.

---

# 10. Transaction counts

Reports should include counts that assist operational review.

Recommended counts:

```text
Completed Transactions                  84
Sale-only Transactions                  67
Return-only Transactions                 5
Mixed sale/return Transactions           8
Post-Void Transactions                   2
Stored-Value-only Transactions           2
Cancelled Transactions                   4
No Sale Events                           3
```

## 10.1 Counting rules

* A completed mixed Transaction counts once as a completed Transaction.
* Presentation classifications do not create additional Transaction records.
* A Post-Void is a new completed reversing Transaction.
* The original Post-Voided Transaction remains part of historical gross activity.
* The reversing Post-Void is separately identified so net results reconcile.
* Cancelled Transactions may be reported as operational counts but contribute no completed sales or Tender totals.
* Suspended Transactions may be shown as current operational counts on an X Report but do not contribute completed amounts.
* A Business-Day Z may include the number of Transactions still suspended at the end of the day only if Store policy permits such carryover.

---

# 11. Sales and Return summary

## 11.1 Gross sales

Gross Sales equal completed Sale-Line extended selling prices before Discounts and Tax.

Stored-Value issuance is excluded from Gross Sales.

Price Overrides are already reflected in the completed selling price.

Example:

```text
Gross Sales                         $4,820.50
Customer Returns                     -$318.75
Net Merchandise / Services          $4,501.75
```

## 11.2 Returns

Customer Returns report the completed merchandise or service Return values separately from Tax refunds.

Return amounts should be presented as negative amounts in financial summaries.

## 11.3 Stored-Value issuance

Gift Card, Store Credit, and Trade Credit issuance do not increase Gross Sales.

They belong in the Stored-Value liability section.

## 11.4 Open Ring

Open-Ring Lines are included in sales or Returns according to:

* Line direction;
* completed Department snapshot;
* completed Tax treatment;
* completed amount.

They may be summarized under the appropriate Department.

---

# 12. Department summary

Reports should summarize completed commercial activity by completed Department snapshot.

Example:

```text
DEPARTMENT ACTIVITY

Books
  Gross Sales                     $3,420.00
  Returns                           -$210.00
  Discounts                         -$145.25
  Net Sales                        $3,064.75

Gifts & Stationery
  Gross Sales                       $820.50
  Returns                            -$48.75
  Discounts                          -$21.00
  Net Sales                          $750.75

Café
  Gross Sales                       $580.00
  Returns                            -$60.00
  Discounts                          -$18.50
  Net Sales                          $501.50
```

Historical activity must not be reclassified from current Product or Department configuration.

Use the completed posting Department retained on the POS Line.

Current Department names may be used where the historical relationship still resolves, but rows must not be merged, moved, or recalculated based on current Product defaults.

A stable fallback should be used where a current label is unavailable.

---

# 13. Discounts and Price Overrides

## 13.1 Discounts

Discounts include:

* Line Discounts;
* allocated Transaction Discounts;
* coupons;
* Promotions;
* employee Discounts;
* membership Discounts.

Example:

```text
DISCOUNTS

Member Discounts                    $82.50
Promotions                           $64.25
Coupons                              $21.00
Employee Discounts                   $17.00
Total Discounts                     $184.75
```

Discounts are reported as positive reduction amounts in a Discount section, even though they reduce Net Sales.

## 13.2 Price Overrides

Price Overrides are not Discounts.

Report separately:

```text
PRICE OVERRIDES

Lines overridden                         7
Regular-price variance              -$46.25
```

The variance compares the completed regular-price basis and completed overridden selling price where those facts are available.

Price Override reason and approving User may appear in detailed administrative reports but are not required on the standard X or Z summary.

## 13.3 No reinterpretation

Current prices must not be used to calculate historical Override variance.

---

# 14. Tax summary

Tax must be reported separately from merchandise and service activity.

Example:

```text
TAX SUMMARY

State Sales Tax 6.00%
  Taxable sales                  $3,480.00
  Tax collected                    $208.80
  Tax refunded                     -$14.40
  Net tax                          $194.40

Food/Beverage Tax 1.25%
  Taxable sales                    $420.00
  Tax collected                      $5.25
  Tax refunded                      -$0.75
  Net tax                            $4.50

TOTAL NET TAX                     $198.90
```

## 14.1 Source rules

Use completed Tax Components for:

* Taxable base;
* rate;
* treatment;
* amount;
* direction;
* exemption result.

Do not recalculate from current Tax Rules.

## 14.2 Treatments

Where useful, include:

```text
Taxable activity                  $3,900.00
Zero-rated activity                 $125.00
Exempt activity                     $310.00
Not-applicable activity              $88.50
```

Non-collecting treatments remain distinct.

## 14.3 Labels

Current customer-facing Tax labels may be used, but:

* completed components must not be regrouped incorrectly;
* stable receipt codes or fallback labels must remain available;
* historical rates and amounts remain unchanged.

---

# 15. Tender summary

Tender activity should distinguish received and refunded amounts.

Example:

```text
TENDER SUMMARY

Cash
  Received                        $1,840.00
  Refunded                          -$92.50
  Net                             $1,747.50

Card
  Received                        $2,610.65
  Refunded                         -$186.20
  Net                             $2,424.45

Gift Card
  Redeemed                          $146.75
  Refunded                           $18.75
  Net                               $128.00

Store Credit
  Redeemed                           $84.50
  Refunded                           $65.00
  Net                                $19.50
```

## 15.1 Completed Tenders only

Include only completed Tenders.

Do not include:

* pending;
* authorized but unresolved;
* removed;
* voided;
* `void_required`;
* failed attempts.

## 15.2 Direction

Tender received and refunded remain separate even where the report also shows a net amount.

## 15.3 Card details

The report may group card activity by configured Tender Type.

Do not claim processor settlement details that ShelfStack did not capture.

External terminal or batch evidence belongs in the card-reconciliation section.

---

# 16. Stored-Value summary

Stored Value must be reported separately from sales.

Recommended section:

```text
STORED VALUE

Gift Cards
  Issued                          $250.00
  Reloaded                         $75.00
  Redeemed                        -$146.75
  Refunded                         $18.75
  Reversed                        -$25.00
  Net liability increase          $171.00

Store Credit
  Issued / Refunded                $65.00
  Redeemed                         -$84.50
  Adjustments                       $5.00
  Reversals                          $0.00
  Net liability change            -$14.50

Trade Credit
  Issued                           $40.00
  Redeemed                         -$12.00
  Net liability increase           $28.00
```

## 16.1 Signed ledger facts

The summary is derived from completed Stored-Value Entries.

The report renderer may present positive issuance and negative redemption while retaining the signed Ledger semantics internally.

## 16.2 Liability versus Tender

A Stored-Value redemption may appear in both:

* Tender activity; and
* Stored-Value liability movement.

These are different analytical views of the same completed posting and must not be added together as revenue.

---

# 17. Cash Movement summary

Summarize posted Cash Movements by Movement Type and direction.

Example:

```text
CASH MOVEMENTS

Cash In
  Till Loans                       $200.00
  Paid In                           $35.00
  Total Cash In                    $235.00

Cash Out
  Cash Drops                      -$900.00
  Paid Out                         -$48.75
  Total Cash Out                  -$948.75

Net Cash Movements               -$713.75
```

The report may also include counts:

```text
Cash Drops                              3
Paid Outs                               2
Till Loans                              1
```

Cash Movement details remain available through Cash Movement history and individual slips.

The standard X or Z need not list every Movement Number unless:

* a reconciliation exception exists;
* the Store requests a detailed appendix;
* the movement is unusually large or requires review.

---

# 18. Cash accountability

## 18.1 Expected cash formula

At the Session level:

```text
Opening Cash
+ Cash Tenders Received
- Cash Refunds
+ Cash-In Movements
- Cash-Out Movements
= Expected Cash
```

Cash change is already part of the completed Cash Tender effect and must not be subtracted a second time.

Example:

```text
CASH ACCOUNTABILITY

Opening Cash                       $200.00
Cash Received                    $1,840.00
Cash Refunded                      -$92.50
Cash In Movements                  $235.00
Cash Out Movements                -$948.75
EXPECTED CASH                    $1,233.75
```

## 18.2 Session Z count

A Session Z adds:

```text
Counted Cash                     $1,228.75
CASH VARIANCE                       -$5.00
```

Variance:

```text
Counted Cash - Expected Cash
```

A negative variance is Cash Short.

A positive variance is Cash Over.

## 18.3 Non-cash Sessions

A card-only Session may have:

* no Cash Drawer;
* no Opening Cash;
* no Cash count;
* no Cash variance.

The report should state:

```text
Cash accountability: Not applicable
```

rather than rendering misleading zero-value Drawer sections.

---

# 19. Blind count behavior

Store policy may require blind closing counts.

## 19.1 Before count submission

Where blind counting applies, the cashier must not see expected cash before submitting the closing count.

This affects:

* Session close screens;
* Session X access;
* any report preview available to the counting cashier.

## 19.2 Session X

A User permitted to view cash may see expected cash only when:

* Store policy allows it; and
* their authority permits it.

Otherwise print:

```text
Expected cash: Restricted
```

or omit the amount.

## 19.3 Session Z

After the closing count is submitted and Session close succeeds, the persisted Session Z may show:

* expected cash;
* counted cash;
* variance;

subject to the viewer’s permissions.

Generating the final Z must not reveal expected cash before the count is committed.

---

# 20. Card reconciliation evidence

Where standalone terminals are used, ShelfStack Tender totals and terminal evidence remain separate.

The report may show:

```text
CARD RECONCILIATION

ShelfStack net card activity      $2,424.45
Terminal batch net                $2,424.45
Difference                            $0.00
Batch reference                    B104882
Evidence status                    Recorded
```

Where evidence is unavailable:

```text
Terminal evidence                  Unavailable
Reason                             Terminal report unavailable
```

A report must not treat absence of terminal evidence as zero processor activity.

Session-level or Business-Day-level card evidence follows the Store’s configured reconciliation grain.

---

# 21. Corrections and control activity

Recommended section:

```text
CORRECTIONS AND CONTROLS

Customer Return Transactions             5
Mixed Transactions                       8
Post-Voids                               2
Post-Void amount                   -$84.25
No Sale Events                           3
Tax Exempt Transactions                  4
Price Override Lines                     7
Approved Discount Actions               12
```

The report may include more detail for exceptions, but standard X and Z reports should remain readable.

Post-Void amounts must be identifiable separately so Gross Sales and net activity can both be understood.

---

# 22. Reconciliation adjustments

Where recorded, report reconciliation adjustments separately.

Example:

```text
RECONCILIATION ADJUSTMENTS

Cash Short                         -$5.00
Card Timing Difference             $12.50
Tender Misclassification            $0.00

Net Reconciliation Adjustment       $7.50
```

Adjustments must not rewrite the underlying Transaction, Tender, or Cash Movement facts.

They explain or resolve reconciliation differences.

---

# 23. Session X Report

## 23.1 Title and warning

The Session X Report must clearly indicate that it is interim.

```text
************ SESSION X REPORT ***********
             INTERIM — NOT FINAL
```

## 23.2 Eligibility

A Session X Report may be generated only for an open Session.

Once the Session closes, use its persisted Session Z Report.

## 23.3 Repeated generation

Every X generation is a new current view.

An X Report is not classified as:

* original;
* copy;
* reprint.

It does not display `REPRINT`.

## 23.4 Content

The Session X should normally include:

* Session identity;
* source cutoff;
* completed Transaction counts;
* sales and Returns;
* Discounts;
* Tax;
* Tenders;
* Stored Value;
* Cash Movements;
* expected cash where permitted;
* operational control counts;
* current exceptions.

It does not include:

* final counted cash unless a permitted interim count exists;
* final variance;
* Z Number;
* final close timestamp;
* final close signatures.

## 23.5 Sample summary

```text
************ SESSION X REPORT ***********
             INTERIM — NOT FINAL

Store MAIN · Register 02
Session opened Jul 27, 2026 9:01 AM
Through Jul 27, 2026 2:16 PM
Cashier Jordan

Completed Transactions                 42

Gross Sales                      $2,418.50
Returns                           -$124.75
Discounts                          -$92.25
Net Tax                            $108.44
Net Transaction Activity        $2,309.94

Cash Net                         $1,042.50
Card Net                         $1,128.69
Stored Value Net                  $138.75

Expected Cash                    $1,196.25

INTERIM REPORT — SESSION REMAINS OPEN
```

---

# 24. Session Z Report

## 24.1 Generation

A Session Z Report is generated as part of the Session close operation.

The close operation must not be considered successful unless:

* required counts are submitted;
* required card evidence is recorded or marked unavailable;
* required reconciliation conditions are satisfied;
* the Z payload is persisted;
* the Session is marked closed.

The report’s physical printing may fail without reversing the successful close.

## 24.2 Finality

The persisted Session Z is final.

Later:

* User-label changes;
* Product changes;
* Tax Rule changes;
* Tender configuration changes;
* report-code changes;

must not alter its historical amounts or classifications.

## 24.3 Original print

Printing from the successful Session-close confirmation is an original.

Retries and additional copies from that immediate workflow remain originals.

## 24.4 Reprint

Printing from Session history is a reprint.

A reprint displays:

```text
REPRINT

Session Z 000184
Originally generated Jul 27, 2026 5:14 PM
Reprinted Jul 28, 2026 9:12 AM
```

It retains the same Z Number.

## 24.5 Signature block

Recommended Session Z signature block:

```text
Counted by: __________________________

Closed by: ___________________________

Reviewed by: _________________________
```

Persisted User names may also appear in the report body:

```text
Counted by: Jordan
Closed by: Jordan
Manager recount by: Casey
```

The physical signatures are separate from the digital record.

---

# 25. Business-Day Z Report

## 25.1 Preconditions

A Business Day may close only after all its POS Sessions are closed.

The Business-Day Z is generated as part of successful Business-Day close.

## 25.2 Consolidation

The Business-Day Z consolidates:

* every Session;
* Store-wide completed Transactions;
* Store-level Cash Movements;
* Store-level card evidence;
* Stored-Value liability movement;
* reconciliation adjustments;
* Session variances;
* Business-Day close facts.

## 25.3 Session summary

Recommended section:

```text
SESSION SUMMARY

Z 000181 · Register 01
  Net activity                   $2,840.25
  Cash variance                      $0.00

Z 000182 · Register 02
  Net activity                   $2,309.94
  Cash variance                     -$5.00

Z 000183 · Card-only
  Net activity                     $684.50
  Cash accountability         Not applicable

Total Session Activity           $5,834.69
Total Cash Variance                 -$5.00
```

## 25.4 Original and reprint

Printing from the successful Business-Day-close confirmation is original.

Printing from Business-Day history is a reprint.

A reprint displays:

```text
REPRINT

Business-Day Z 000042
Originally generated Jul 28, 2026 12:18 AM
Reprinted Jul 28, 2026 9:24 AM
```

## 25.5 Signature block

Recommended:

```text
Day closed by: _______________________

Reviewed by: _________________________

Reconciled by: _______________________
```

The `Reconciled by` line may remain blank when reconciliation occurs after operational close.

---

# 26. Original and reprint context

## 26.1 X Reports

Original/reprint classification does not apply.

Every X Report is a fresh interim generation.

## 26.2 Z originals

These are original contexts:

* automatic display after successful close;
* printing from immediate close confirmation;
* retry from the same confirmation;
* additional copies before leaving the close workflow.

## 26.3 Z reprints

These are reprint contexts:

* Session history;
* Business-Day history;
* reporting archive;
* audit or administrative retrieval.

## 26.4 Server ownership

The server determines original or reprint status from the workflow.

A user-editable parameter must not suppress a required `REPRINT` marker.

---

# 27. Permissions and sensitive sections

Report access should support these distinct capabilities:

```text
reporting.view_session_x
reporting.view_session_z
reporting.view_business_day_z
reporting.view_cash
reporting.view_cost
reporting.view_margin
```

Equivalent existing permission names may be used.

## 27.1 Cash

Without Cash permission:

* expected cash;
* counted cash;
* Cash Movement values;
* variance;

must be hidden or replaced with `Restricted`.

## 27.2 Cost and margin

Cost and Margin sections appear only where the User has the corresponding authority.

A standard cashier Session Z does not need to show:

* Inventory cost;
* Cost of Goods Sold;
* Gross Margin;
* Margin percentage.

## 27.3 Tender and card evidence

Detailed card evidence may require Reporting or Reconciliation authority beyond basic Z access.

## 27.4 No privilege escalation through printing

A print route must apply the same sensitive-field permissions as the on-screen report.

Printing must not expose sections hidden from the viewing User.

---

# 28. Cost and margin sections

Where authorized, a Z Report may include:

```text
COST AND MARGIN

Net Merchandise Sales            $4,501.75
Cost of Goods Sold               $2,588.40
Gross Margin                     $1,913.35
Gross Margin %                       42.50%
```

Use completed historical cost snapshots.

Do not recalculate historical cost from current Product, Inventory, or moving-average balances.

Where cost quality is incomplete, the report must disclose that limitation.

Example:

```text
Cost coverage:
  Actual                            92.4%
  Estimated                          5.1%
  Unknown                            2.5%
```

X Reports may show interim cost and margin only to authorized Users and only from currently available completed facts.

---

# 29. Report labels and configuration changes

Current display labels may be used for:

* Store;
* Register;
* User;
* Department name;
* Tax name;
* Tender Type name;
* Cash Movement Type name.

Current labels must not:

* move historical amounts to another Department;
* combine historically separate Tax Components;
* change Tender direction or category;
* change Cash Movement direction;
* reinterpret Stored-Value Entry Types;
* alter report totals.

Persisted Z payloads should retain stable codes or source references sufficient to provide fallback labels.

---

# 30. Barcode and human-readable references

## 30.1 Session X

No barcode is required.

## 30.2 Session Z

A barcode is optional for MVP.

Where supported later, Code 128 may encode a stable Session Z lookup reference.

The human-readable Z Number must remain visible.

## 30.3 Business-Day Z

A barcode is optional for MVP.

Where supported later, Code 128 may encode a stable Business-Day Z lookup reference.

No database ID should be encoded.

---

# 31. Footers

## 31.1 Session X

Required warning:

```text
INTERIM REPORT — SESSION REMAINS OPEN
Totals may change as additional activity posts.
```

## 31.2 Session Z

Recommended:

```text
FINAL SESSION REPORT
Generated from posted Session facts.
```

## 31.3 Business-Day Z

Recommended:

```text
FINAL BUSINESS-DAY REPORT
Generated from persisted close facts.
```

A dedicated configurable report footer is not required for MVP.

---

# 32. Structured report documents

Recommended common structure:

```ruby
Reporting::ReportDocument
```

Conceptual fields:

```text
kind
title
status_banners
scope
report_number
business_date
opened_at
closed_at
generated_at
source_cutoff_at
generated_by
identity_rows
sections
control_totals
exceptions
signature_rows
footer
```

Builders:

```ruby
Reporting::BuildSessionXReport
Reporting::BuildSessionZDocument
Reporting::BuildBusinessDayZDocument
```

The X builder reads current authoritative records.

The Z document builders read persisted report records and payloads.

---

# 33. Renderer responsibilities

The renderer owns:

* browser-printable HTML;
* typography;
* section spacing;
* tabular alignment;
* page breaks;
* repeated headers for multi-page reports;
* hiding interactive controls;
* 80 mm or full-page profile selection;
* signature-line presentation.

The renderer does not:

* calculate financial totals;
* determine report scope;
* derive expected cash;
* apply field permissions;
* determine finality;
* recalculate Z payloads.

---

# 34. Paper profile

X and Z Reports may exceed a practical thermal-paper length.

MVP should support:

1. **80 mm thermal profile** for Register printing; and
2. **standard browser page profile** for office printing or PDF output.

The same structured report document should feed both profiles.

The thermal profile may:

* use compact section summaries;
* wrap labels;
* omit decorative whitespace;
* page-break only where the browser requires it.

It must not omit required financial or accountability facts solely to fit one sheet.

---

# 35. Error handling

## 35.1 Session X

If X generation fails:

* the Session remains open;
* no final report is created;
* no activity changes;
* retry remains possible.

## 35.2 Session Z

If Session close and Z persistence succeed but rendering fails:

* the Session remains closed;
* the persisted Z remains authoritative;
* printing may be retried;
* no second Z is generated.

If Z persistence fails within Session close:

* Session close must fail atomically;
* the Session remains open;
* no Z Number should be consumed unless the existing numbering contract explicitly permits a gap.

## 35.3 Business-Day Z

If Business-Day close and Z persistence succeed but rendering fails:

* the Business Day remains closed;
* the persisted Z remains authoritative;
* printing may be retried.

If report generation or persistence fails before close commits:

* Business-Day close fails;
* no partial final report remains.

## 35.4 Missing labels

Use stable fallback labels.

Examples:

```text
Department BOOKS
Tax A 6.00%
Tender CARD
Cash Movement CASH_DROP
Register POS-02
```

## 35.5 Payload inconsistency

Do not silently recalculate a persisted Z to repair an inconsistent payload.

Display an error and require investigation.

---

# 36. No separate print-event persistence

MVP does not require:

```text
x_report_print_events
z_report_print_events
rendered_report_documents
stored_report_pdfs
stored_report_html
```

Persisted Z Report records and administrative report-view audit events provide the authoritative report history.

Browser print success remains unknowable.

---

# 37. MVP acceptance scenarios

## 37.1 Session X generation

Given an open Session:

* an X Report can be generated;
* it shows `INTERIM — NOT FINAL`;
* generation time and source cutoff print;
* no Z Number is assigned;
* the Session remains open.

## 37.2 Repeated X generation

Given additional posted activity after an earlier X:

* a later X includes the newer activity;
* the earlier print is not called a reprint;
* no final report record is created.

## 37.3 Open activity

Given open or suspended Transactions:

* they do not contribute completed sales, Tax, or Tender amounts;
* optional operational counts may identify them separately.

## 37.4 Session Z close

Given a valid Session close:

* one Session Z is persisted;
* one Z Number is assigned;
* final payload and cash accountability are retained;
* the Session becomes closed.

## 37.5 Session Z original

Given printing from immediate close confirmation:

* `REPRINT` does not appear;
* additional copies remain original context.

## 37.6 Session Z reprint

Given printing from Session history:

* `REPRINT` appears;
* the original Z Number remains;
* original generation and reprint timestamps appear;
* persisted payload is used.

## 37.7 Business-Day close

Given all Sessions are closed:

* Business-Day close may generate one Business-Day Z;
* all applicable Sessions and Store-level facts are consolidated;
* the Business Day becomes closed.

## 37.8 Open Session blocker

Given one open Session:

* Business-Day close is denied;
* no Business-Day Z is generated.

## 37.9 Department history

Given a Product’s current Department has changed:

* a Z reprint retains the historical completed Department allocation;
* current Product defaults are not consulted.

## 37.10 Tax history

Given current Tax Rules have changed:

* Z reprints retain historical Tax bases, rates, treatments, and amounts;
* no Tax recalculation occurs.

## 37.11 Discounts and Overrides

Given both Discounts and Price Overrides:

* Discounts appear in the Discount section;
* Override variance appears separately;
* the Override is not added to Discount totals.

## 37.12 Stored Value

Given Gift Card issuance and redemption:

* issuance does not increase Gross Sales;
* redemption appears in Tender and liability views without being counted twice as revenue.

## 37.13 Expected cash

Given a Cash-enabled Session:

* expected cash follows the defined formula;
* cash change is not subtracted twice;
* Cash Movements affect expected cash according to direction.

## 37.14 Blind count

Given blind-count policy:

* expected cash is not shown to the counting cashier before count submission;
* final Z may show expected, counted, and variance after close, subject to permission.

## 37.15 Card-only Session

Given a Session without a Cash Drawer:

* cash accountability is marked `Not applicable`;
* no misleading zero variance is presented.

## 37.16 Field permissions

Given a User lacking Cash, Cost, or Margin access:

* restricted sections or amounts do not print;
* the printable report matches on-screen authorization.

## 37.17 Rendering failure

Given successful close followed by print failure:

* Session or Business Day remains closed;
* persisted Z remains available;
* retry creates no additional Z.

---

# 38. MVP boundaries

## Required

* live Session X Report;
* persisted Session Z Report;
* persisted Business-Day Z Report;
* clear interim versus final presentation;
* Store-scoped Z Numbers;
* Transaction counts;
* sales, Returns, Discounts, Price Overrides, and Tax;
* Tender summary;
* Stored-Value summary;
* Cash Movement summary;
* expected, counted, and variance presentation;
* card-evidence status;
* control and correction counts;
* field-level sensitive-data permissions;
* original/reprint context for Z Reports;
* browser-printable HTML;
* thermal and full-page print profiles;
* no Z recalculation on reprint.

## Deferred

* persisted X Report history;
* X Report Number;
* X Report print audit;
* direct ESC/POS output;
* managed printer queues;
* configurable report section ordering;
* configurable report footers;
* barcode-based report lookup;
* electronically captured signatures;
* signed-report attachment retention;
* scheduled report delivery;
* email distribution;
* comparative multi-day reporting;
* full accounting-export presentation.

---

# 39. Resolved MVP decisions

1. Session X is a live interim report and is not persisted for MVP.

2. X Reports do not use original/reprint classification.

3. Every X generation represents the current posted Session state.

4. Generating or printing an X Report does not close or reset the Session.

5. Session Z is generated once and persisted during Session close.

6. Business-Day Z is generated once and persisted during Business-Day close.

7. Z reprints use persisted payloads and do not recalculate history.

8. Session Z and Business-Day Z use separate Store-scoped number sequences.

9. Gross Sales exclude Stored-Value issuance.

10. Discounts and Price Override variance are reported separately.

11. Tax is reported from completed Tax Components.

12. Stored-Value liability movement is separate from sales and Tender totals.

13. Expected cash includes Opening Cash, net Cash Tenders, and net Cash Movements.

14. Cash change is not subtracted twice.

15. Blind-count rules restrict expected cash before count submission.

16. Card-only Sessions show Cash Accountability as not applicable.

17. Sensitive sections remain permission-gated in printed output.

18. Printing failure after successful close does not reopen the Session or Business Day.

19. A standard Z signature block is included.

20. Barcode support for X and Z Reports is deferred.
