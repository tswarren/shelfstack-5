# POS Printing — Fact-Source and Schema-Gap Matrix

**Status:** Draft
**Scope:** MVP POS printed-document planning
**Parent specifications:**

* [Common Document Contract and Taxonomy](common-document-contract-and-taxonomy.md)
* [Customer Receipts](customer-receipts.md)

---

## 1. Purpose

This document maps each planned printed fact to its authoritative ShelfStack source and identifies whether the current application requires:

* no change;
* derivation from existing records;
* a presentation or renderer change;
* a workflow or service change;
* a configuration addition;
* a database schema addition;
* a later decision.

The purpose is to prevent Receipt and document implementation from introducing unnecessary snapshots, duplicate financial data, or premature printer infrastructure.

---

## 2. Status classifications

| Status              | Meaning                                                                                                                  |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Available           | The current authoritative record directly provides the fact.                                                             |
| Derived             | The fact can be calculated or presented from existing authoritative records without consulting current commercial rules. |
| Presentation gap    | The data exists, but the current template or renderer does not present it correctly.                                     |
| Workflow gap        | The data exists, but routes, permissions, or workflow context do not yet distinguish the required behavior.              |
| Configuration gap   | The document needs a configurable value that does not currently exist.                                                   |
| Schema gap          | A new persisted business or operational fact is required.                                                                |
| Optional / deferred | Not required for the agreed MVP document contract.                                                                       |
| Decision pending    | The need or exact implementation should be settled in a document-specific specification.                                 |

---

# 3. Overall assessment

## 3.1 Existing data is sufficient for most documents

The current model already supports reconstruction of:

* Customer Receipts;
* Return-only Receipts;
* mixed sale-and-return Receipts;
* Post-Void Receipts;
* reprints of Post-Voided original Transactions;
* brief Gift Receipts;
* Stored-Value Activity Slips;
* Credit Vouchers;
* Cash Movement Slips;
* Session X Reports;
* Session Z Reports;
* Business-Day Z Reports.

No complete Receipt snapshot is required.

## 3.2 Definite MVP schema addition

Add:

```text
stores.gift_receipt_footer :text
```

This is the only definite schema addition identified by the present document contract.

## 3.3 Principal delivery work

Most MVP work belongs in:

* structured document builders;
* workflow-owned original/reprint context;
* dedicated document routes;
* browser-print layouts;
* barcode generation;
* masking and omission rules;
* Post-Void and `VOIDED` presentation;
* document-specific tests.

## 3.4 Items that should not be added for MVP

Do not add:

* serialized Receipt snapshots;
* stored HTML;
* stored PDFs;
* stored printer byte streams;
* historical Store header/footer snapshots;
* historical Tax-name snapshots;
* Gift Receipt tokens;
* Gift Receipt entitlement records;
* browser print-event audit records;
* separate Gift Receipt Numbers;
* card fields solely for Receipt presentation;
* a Stored-Value balance snapshot solely for printing;
* a generic persisted `document_type` on POS Transactions.

---

# 4. Common document facts

| Document fact           | Current source                                          | Status                                  | MVP treatment                                                        |
| ----------------------- | ------------------------------------------------------- | --------------------------------------- | -------------------------------------------------------------------- |
| Store name              | Current Store                                           | Available                               | Use current value.                                                   |
| Organization name       | Current Organization                                    | Available                               | Use current value where configured for display.                      |
| Store legal name        | Current Store                                           | Available                               | Use only where required by document policy.                          |
| Address                 | Current Store                                           | Available                               | Use current address.                                                 |
| Phone                   | Current Store                                           | Available                               | Use current phone.                                                   |
| Email                   | Current Store                                           | Available                               | Optional.                                                            |
| Standard Receipt header | `stores.receipt_header`                                 | Available                               | Use current value.                                                   |
| Standard Receipt footer | `stores.receipt_footer`                                 | Available                               | Use current value.                                                   |
| Gift Receipt footer     | None                                                    | Configuration and schema gap            | Add `stores.gift_receipt_footer`.                                    |
| Credit Voucher terms    | None dedicated                                          | Presentation decision                   | Use fixed ShelfStack wording for MVP unless later made configurable. |
| Cash Movement footer    | None dedicated                                          | Presentation decision                   | Use fixed wording and signature labels for MVP.                      |
| Document title          | Derived from document kind and source                   | Derived                                 | Builder determines title.                                            |
| `REPRINT` banner        | Workflow context                                        | Workflow gap                            | Must not be controlled only by a query parameter.                    |
| `VOIDED` banner         | Original Transaction’s completed Post-Void relationship | Available                               | Builder determines current correction status.                        |
| Print timestamp         | Current time when document is rendered                  | Available                               | Presentation fact, not historical source fact.                       |
| Currency                | Store currency                                          | Available                               | Use Store operating currency.                                        |
| Locale                  | Application or Store presentation policy                | Available                               | MVP uses the application’s supported locale.                         |
| Barcode                 | Public source reference                                 | Renderer gap                            | Add barcode renderer; no business schema required.                   |
| Human-readable number   | Existing public source reference                        | Available for Receipts and Stored Value | Always print beneath barcode.                                        |
| Physical print success  | Browser/printer environment                             | Unavailable by design                   | Do not track for browser printing.                                   |
| Browser print audit     | None                                                    | Not required                            | Explicitly omitted for MVP.                                          |

---

# 5. Customer Receipt fact-source matrix

## 5.1 Receipt identity

| Receipt fact                  | Authoritative source                | Status    | Required work                                         |
| ----------------------------- | ----------------------------------- | --------- | ----------------------------------------------------- |
| Receipt Number                | `pos_transactions.receipt_number`   | Available | None.                                                 |
| Receipt sequence              | `pos_transactions.receipt_sequence` | Available | Internal; normally do not print separately.           |
| Original completion timestamp | `pos_transactions.completed_at`     | Available | None.                                                 |
| Register                      | `completed_pos_session.pos_device`  | Available | Use current Device name, falling back to stable code. |
| Cashier                       | `pos_transactions.cashier_user`     | Available | Use current display label.                            |
| Store                         | `pos_transactions.store`            | Available | Use current Store presentation fields.                |
| Customer                      | `pos_transactions.customer`         | Available | Print masked Customer Number only.                    |
| Receipt barcode value         | Receipt Number                      | Available | Add barcode rendering.                                |
| Reprint timestamp             | Current rendering time              | Available | Add only for historical route/context.                |

### Finding

No Receipt-identity schema change is required.

---

## 5.2 Original versus reprint

| Requirement                                             | Current state                                                                     | Status       | Required work                                                            |
| ------------------------------------------------------- | --------------------------------------------------------------------------------- | ------------ | ------------------------------------------------------------------------ |
| Immediate post-completion print is original             | Receipt route accepts a caller-supplied `reprint` parameter                       | Workflow gap | Establish server-owned completion context.                               |
| Historical lookup print is reprint                      | Caller currently supplies `reprint=true`                                          | Workflow gap | Use a dedicated historical reprint route or server-owned context.        |
| Refresh immediate completion screen remains original    | Not durably represented in workflow                                               | Workflow gap | Retain immediate Receipt context in the User session.                    |
| Additional print from immediate screen remains original | Possible, but caller controls marker                                              | Workflow gap | Builder receives trusted `original` context.                             |
| Reprint permission applies only to historical copies    | Current Receipt action applies reprint permission to the Receipt action generally | Workflow gap | Separate immediate Receipt access from historical reprint authorization. |
| Reprint retains Receipt Number                          | Current record already does                                                       | Available    | None.                                                                    |

### Recommended MVP workflow

On successful completion:

```text
session[:pos_original_receipt_transaction_id] = completed_transaction.id
```

The immediate completed-Transaction Receipt workspace may request an original document only while that context matches.

Clear or replace the context when the cashier:

* chooses Next Transaction;
* returns to Ready and begins new work;
* completes another Transaction;
* signs out;
* changes Store or Session.

Historical access uses a dedicated reprint path and never depends on that immediate context.

Suggested routes:

```text
GET /pos_transactions/:id/customer_receipt
  immediate original context only

GET /pos_transactions/:id/customer_receipt/reprint
  historical access; requires receipt-reprint permission
```

An equivalent server-owned routing design is acceptable. A user-controlled `reprint=false` parameter is not sufficient.

No database schema is required.

---

## 5.3 Customer presentation

| Fact                         | Current source              | Status                              | Required work                       |
| ---------------------------- | --------------------------- | ----------------------------------- | ----------------------------------- |
| Customer Number              | `customers.customer_number` | Available                           | Mask all but final four characters. |
| Customer name                | Current Customer            | Available but intentionally omitted | Remove from MVP Receipt.            |
| Full Customer Number         | Current Customer            | Available but prohibited            | Do not print.                       |
| Customer contact information | Current Customer            | Available but prohibited            | Do not print.                       |

### Finding

No schema change is required.

The current Receipt template’s Customer presentation must be replaced with:

```text
Customer **** 4837
```

---

# 6. Customer Receipt line facts

## 6.1 Description and identifiers

| Line fact                    | Current source                        | Status    | Required work                                                 |
| ---------------------------- | ------------------------------------- | --------- | ------------------------------------------------------------- |
| Completed description        | `pos_line_items.description_snapshot` | Available | Builder must use snapshot only for completed Lines.           |
| Completed identifier         | `pos_line_items.identifier_snapshot`  | Available | Print when useful.                                            |
| Quantity                     | `pos_line_items.quantity`             | Available | None.                                                         |
| Selling unit price           | `pos_line_items.unit_price_cents`     | Available | Print as ordinary item price.                                 |
| Extended amount              | Quantity × unit price                 | Derived   | Builder applies direction.                                    |
| Sale or Return direction     | `pos_line_items.direction`            | Available | Presentation determines sign and Return marker.               |
| Line kind                    | `pos_line_items.line_kind`            | Available | Distinguish merchandise, Open Ring, and Stored Value.         |
| Original sale-line reference | `original_pos_line_item_id`           | Available | Use to display original Receipt reference for linked Returns. |
| Post-Void line reference     | `reverses_pos_line_item_id`           | Available | Use for Post-Void projection.                                 |

### Completion behavior

Completion already fills missing Product Line description and identifier snapshots where older entry paths left them blank.

The document builder must not fall back to current Product data for completed Receipts after those snapshots are available.

---

## 6.2 Variant, format, and condition details

| Fact                         | Current source                             | Status                                              | MVP treatment                                                       |
| ---------------------------- | ------------------------------------------ | --------------------------------------------------- | ------------------------------------------------------------------- |
| Variant name                 | Current Product Variant relation           | Not historical                                      | Omit unless included in `description_snapshot`.                     |
| Product format               | Current Product or Variant relations       | Not snapshotted on the actual Line schema           | Omit for MVP.                                                       |
| Product condition            | Current Inventory Unit or Variant relation | Not reliably snapshotted                            | Omit unless included in the completed description.                  |
| Exact-unit public identifier | Inventory Unit relation                    | Available, but may not be a completed line snapshot | Print only where a stable completed identifier is already retained. |

### Finding

This is not an MVP schema gap.

Receipt implementation should not add live Product, Variant, format, or condition lookup merely for richer formatting.

A later enhancement may add explicit completed presentation snapshots if the business requires them.

---

# 7. Price Override matrix

| Fact                    | Current source                            | Status                | Receipt treatment                 |
| ----------------------- | ----------------------------------------- | --------------------- | --------------------------------- |
| Completed selling price | `pos_line_items.unit_price_cents`         | Available             | Print as the ordinary unit price. |
| Override occurred       | `price_overridden_at` and actor reference | Available             | Do not print.                     |
| Original regular price  | Not required for Receipt                  | Intentionally omitted | Do not retrieve or print.         |
| Override reason         | Internal audit fields                     | Available             | Do not print.                     |
| Approver                | Approval and User records                 | Available             | Do not print.                     |

### Finding

No schema or calculation change is required.

The builder must deliberately ignore Override audit data when creating the customer-facing line.

---

# 8. Discount matrix

| Fact                            | Current source                          | Status                | Required work                                 |
| ------------------------------- | --------------------------------------- | --------------------- | --------------------------------------------- |
| Discount total                  | `pos_transactions.discount_total_cents` | Available             | None.                                         |
| Discount record                 | `pos_discounts`                         | Available             | Use completed record.                         |
| Line allocation                 | `pos_discount_allocations`              | Available             | Use for itemized Discount presentation.       |
| Discount reason                 | `discount_reason` relation              | Available             | Use current customer-facing name or fallback. |
| Method and rate                 | `pos_discounts`                         | Available             | Optional customer-friendly label.             |
| Transaction Discount allocation | Completed allocations                   | Available             | Do not recalculate.                           |
| Promotion internals             | Not needed                              | Intentionally omitted | Do not print allocation mechanics.            |

### Finding

No schema change is required.

### MVP recommendation

Print completed Discount Allocations beneath each affected Line.

This:

* matches completed tax mathematics;
* supports partial Returns;
* avoids inventing a second allocation presentation;
* keeps item and Transaction Discounts reconcilable.

The label may be resolved from the current Discount Reason name, with fallback `Discount`.

---

# 9. Tax matrix

| Tax fact               | Current source                             | Status                            | Required work                                   |
| ---------------------- | ------------------------------------------ | --------------------------------- | ----------------------------------------------- |
| Taxable amount         | `pos_line_item_taxes.taxable_amount_cents` | Available                         | None.                                           |
| Historical rate        | `pos_line_item_taxes.rate`                 | Available                         | None.                                           |
| Historical amount      | `pos_line_item_taxes.amount_cents`         | Available                         | None.                                           |
| Treatment              | `treatment_snapshot`                       | Available                         | Use for Tax markers and exemption distinctions. |
| Tax receipt code       | `receipt_code_snapshot`                    | Available                         | Use where line markers are enabled.             |
| Compounding            | `compounds_on_prior_tax_snapshot`          | Available                         | Internal calculation fact; usually omit.        |
| Display order          | `position`                                 | Available                         | Preserve completed order.                       |
| Tax name               | Current `store_tax_rate.name`              | Available as current presentation | Use current name or fallback.                   |
| Tax exemption coverage | `pos_tax_exemptions.coverage`              | Available                         | MVP supports whole Transaction.                 |
| Exemption type         | `pos_tax_exemptions.exemption_type`        | Available                         | May show generic exemption indication.          |
| Certificate number     | Not present in current delivered schema    | Unavailable                       | Omit for MVP.                                   |

### Finding

No Tax schema change is required for the agreed Receipt.

Do not add exemption certificate fields solely for Receipt output.

### Fallback behavior

Where a current Tax name is unavailable:

```text
Tax 6.00%
```

Where a Receipt code snapshot is available, it may also be used:

```text
Tax A 6.00%
```

---

# 10. Totals matrix

| Total                   | Current source                                       | Status                       | Required work                                                      |
| ----------------------- | ---------------------------------------------------- | ---------------------------- | ------------------------------------------------------------------ |
| Subtotal                | `pos_transactions.subtotal_cents`                    | Available                    | Use for simple sale Receipt.                                       |
| Discount total          | `discount_total_cents`                               | Available                    | None.                                                              |
| Tax total               | `tax_total_cents`                                    | Available                    | None.                                                              |
| Net total               | `net_total_cents`                                    | Available                    | None.                                                              |
| Gross sales subtotal    | Completed Sale Lines                                 | Derived                      | Sum completed Sale Line extended prices.                           |
| Gross Return subtotal   | Completed Return Lines                               | Derived                      | Sum completed Return Line extended prices and present as negative. |
| Discount reversal       | Completed allocations on Return Lines                | Derived from completed facts | Present with Return direction.                                     |
| Sale Tax and Return Tax | Completed line Tax Components separated by direction | Derived                      | Do not recalculate.                                                |

### Finding

No additional Transaction total columns are required.

Mixed and Return-only Receipt totals should be built from completed Lines, Allocations, and Tax Components.

---

# 11. Tender matrix

| Tender fact              | Current source               | Status      | Required work                                                     |
| ------------------------ | ---------------------------- | ----------- | ----------------------------------------------------------------- |
| Tender type              | `tender_type` relation       | Available   | Use current customer-facing name or fallback.                     |
| Tender category          | Current Tender Type          | Available   | Determine Cash, Card, Stored Value, etc.                          |
| Direction                | `pos_tenders.direction`      | Available   | Present received or refunded appropriately.                       |
| Settled amount           | `pos_tenders.amount_cents`   | Available   | Print completed Tenders only.                                     |
| Cash tendered            | `amount_tendered_cents`      | Available   | Print for Cash.                                                   |
| Change                   | `change_due_cents`           | Available   | Print for Cash.                                                   |
| Card authorization code  | `authorization_code`         | Available   | Normally omit.                                                    |
| Terminal reference       | `terminal_reference`         | Available   | Normally omit.                                                    |
| Card brand               | No dedicated delivered field | Unavailable | Use Tender Type name where it represents the Card type.           |
| Card last four           | No dedicated delivered field | Unavailable | Omit unless later captured under an accepted POS Tender contract. |
| Original Tender linkage  | `original_pos_tender_id`     | Available   | Useful for Return projection.                                     |
| Post-Void Tender linkage | `reverses_pos_tender_id`     | Available   | Use for Post-Void Receipt.                                        |
| Stored-Value Account     | `stored_value_account_id`    | Available   | Mask Account Number on ordinary Receipt.                          |

### Finding

Do not add Card brand or last-four columns solely to improve Receipt appearance.

For MVP, a Card Tender may print as:

```text
Visa                           $30.00
```

when `Visa` is the Tender Type name, or:

```text
Card                           $30.00
```

using a fallback.

ShelfStack must not present authorization or terminal references as though they were Card last-four digits.

---

# 12. Post-Void and correction matrix

| Fact                            | Current source                                       | Status    | Required work                |
| ------------------------------- | ---------------------------------------------------- | --------- | ---------------------------- |
| Reversing Transaction           | `reverses_pos_transaction_id`                        | Available | None.                        |
| Completed Post-Void of original | `post_void_transaction` association                  | Available | Use for `VOIDED` marker.     |
| Reversing Receipt Number        | Reversing Transaction                                | Available | None.                        |
| Original Receipt Number         | Original Transaction                                 | Available | None.                        |
| Post-Void reason                | Reversing Transaction                                | Available | Print only on internal copy. |
| Post-Void approval              | `post_void_pos_approval`                             | Available | Print only on internal copy. |
| Reversing Lines                 | `reverses_pos_line_item_id`                          | Available | None.                        |
| Reversing Tenders               | `reverses_pos_tender_id`                             | Available | None.                        |
| Stored-Value reversals          | Stored-Value Entries linked to reversing Transaction | Available | Present where relevant.      |

### Finding

No Post-Void schema change is required.

### Delivery requirements

The builder must support:

* original Post-Void Receipt;
* historical Post-Void reprint;
* historical reprint of the original Transaction after Post-Void;
* `VOIDED` marker;
* reversing Receipt reference;
* original completed facts remaining unchanged on the original reprint.

---

# 13. Gift Receipt matrix

The agreed Gift Receipt is a brief BookSense-style Transaction lookup summary.

| Gift Receipt fact            | Current source                    | Status                       | Required work                     |
| ---------------------------- | --------------------------------- | ---------------------------- | --------------------------------- |
| Store header                 | Current Store                     | Available                    | Reuse common header.              |
| `GIFT RECEIPT` title         | Fixed document semantics          | Available                    | Add template.                     |
| Receipt Number               | Completed Transaction             | Available                    | None.                             |
| Completion date and time     | Completed Transaction             | Available                    | None.                             |
| Store code                   | Current Store / Transaction Store | Available                    | None.                             |
| Register                     | Completed POS Session and Device  | Available                    | None.                             |
| Cashier                      | Completed Transaction cashier     | Available                    | Optional lookup context.          |
| Barcode                      | Receipt lookup reference          | Renderer gap                 | Add barcode support.              |
| Human-readable reference     | Receipt Number                    | Available                    | Print beneath barcode.            |
| Gift Receipt footer          | None                              | Configuration and schema gap | Add `stores.gift_receipt_footer`. |
| Items                        | Not required                      | Intentionally omitted        | Do not load.                      |
| Prices and totals            | Not required                      | Intentionally omitted        | Do not load.                      |
| Gift token                   | Not required                      | Intentionally omitted        | Do not add.                       |
| Gift Receipt model or number | Not required                      | Intentionally omitted        | Do not add.                       |

### Required schema migration

```ruby
add_column :stores, :gift_receipt_footer, :text
```

### Required delivery work

* Gift Receipt route;
* Gift Receipt document builder;
* Gift Receipt browser-print view;
* original/reprint workflow context;
* barcode;
* configuration editing support when Store settings UI is available.

Until configuration UI exists, the field may be managed through existing Store administration or seeded defaults.

---

# 14. Stored-Value Activity Slip matrix

| Activity Slip fact              | Current source                       | Status                         | Required work                                              |
| ------------------------------- | ------------------------------------ | ------------------------------ | ---------------------------------------------------------- |
| Account type                    | `stored_value_accounts.account_type` | Available                      | Map to customer-facing name.                               |
| Masked Account Number           | `account_number`                     | Available                      | Mask except final digits.                                  |
| Entry type                      | `stored_value_entries.entry_type`    | Available                      | Map to activity label.                                     |
| Entry amount                    | `amount_cents`                       | Available                      | Apply customer-facing direction.                           |
| Entry timestamp                 | `created_at`                         | Available                      | None.                                                      |
| Performing User                 | `created_by_user`                    | Available                      | Usually omit from customer copy.                           |
| Related Receipt                 | `pos_transaction.receipt_number`     | Available where POS-originated | None.                                                      |
| Reversed Entry                  | `reverses_entry_id`                  | Available                      | Use for reversal description.                              |
| Balance immediately after Entry | Not stored directly                  | Derived                        | Derive from append-only Ledger.                            |
| Current account balance         | Account cache                        | Available                      | Do not substitute for historical balance on Activity Slip. |

## 14.1 Historical balance derivation

No `balance_after_cents` column is required for MVP.

The balance after an Entry can be derived by summing all Ledger Entries for the same Account through the target Entry in authoritative Entry order.

Recommended service:

```text
StoredValue::BalanceAfterEntry
```

Input:

```text
stored_value_entry
```

Result:

```text
sum amount_cents
for the same stored_value_account
through the target ledger entry
```

Use a deterministic Entry order. The implementation should explicitly define and test that order rather than rely on an unordered association.

### Finding

No Stored-Value schema change is required.

A later cached `balance_after_cents` field may be considered for reporting performance, but it is not needed for document correctness.

---

# 15. Credit Voucher matrix

Every Stored-Value Account may be printed as a bearer Credit Voucher.

| Credit Voucher fact    | Current source                  | Status                     | Required work                                                                  |
| ---------------------- | ------------------------------- | -------------------------- | ------------------------------------------------------------------------------ |
| `CREDIT VOUCHER` title | Fixed semantics                 | Available                  | Add template.                                                                  |
| Account type           | Stored-Value Account            | Available                  | Print Gift Card, Store Credit, or Trade Credit.                                |
| Full Account Number    | `account_number`                | Available                  | Print because voucher is a bearer credential.                                  |
| EAN-13 barcode         | Account Number                  | Renderer gap               | Add barcode renderer.                                                          |
| Current balance        | `current_balance_cents`         | Available                  | Read at print time.                                                            |
| Balance-as-of time     | Current rendering time          | Available                  | Print.                                                                         |
| Account status         | `status`                        | Available                  | Block or clearly mark voucher when suspended according to later specification. |
| Related Receipt        | Related Entry’s POS Transaction | Available where applicable | Optional.                                                                      |
| Voucher terms          | No dedicated configuration      | Presentation decision      | Use fixed MVP wording.                                                         |
| Reprint marker         | Historical workflow context     | Workflow gap               | Use common reprint rules.                                                      |

### Finding

No schema change is required.

Printing multiple vouchers does not create additional value because every copy resolves to the same Stored-Value Account.

### Pending document-specific policy

The Credit Voucher specification must decide whether a suspended Account:

* may be printed with a prominent `SUSPENDED` banner;
* may be printed only by authorized staff;
* may not be printed at all.

---

# 16. Cash Movement Slip matrix

| Cash Movement fact            | Current source                    | Status           | Required work                                            |
| ----------------------------- | --------------------------------- | ---------------- | -------------------------------------------------------- |
| Movement Type                 | `cash_movement_type`              | Available        | Use current name.                                        |
| Cash direction                | Movement Type direction           | Available        | Present as Cash In or Cash Out.                          |
| Amount                        | `pos_cash_movements.amount_cents` | Available        | None.                                                    |
| Store                         | Movement Store                    | Available        | None.                                                    |
| POS Session                   | `pos_session`                     | Available        | None.                                                    |
| Register                      | Session POS Device                | Available        | None.                                                    |
| Timestamp                     | `created_at`                      | Available        | None.                                                    |
| Performing User               | `created_by_user`                 | Available        | Print.                                                   |
| Approving User                | `approved_by_user` or Approval    | Available        | Print where present.                                     |
| Reason                        | `reason`                          | Available        | Print where present.                                     |
| Reference                     | `reference`                       | Available        | Print where present or required.                         |
| Signature fields              | Fixed presentation                | Presentation gap | Include on every movement.                               |
| Stable public Movement Number | None                              | Decision pending | See below.                                               |
| Movement barcode              | No public number currently        | Decision pending | Not required until a public Movement Number is accepted. |
| Original/reprint context      | Immediate posting versus history  | Workflow gap     | Use common context rules.                                |

## 16.1 Public Cash Movement Number

The current Cash Movement record has no stable human-facing generated number.

This does not prevent an MVP slip from printing. A slip can be identified by:

* Store;
* Register;
* timestamp;
* Movement Type;
* amount;
* entered reference.

However, a generated Movement Number would improve:

* historical lookup;
* reprint identification;
* safe verbal references;
* signature and chain-of-custody workflows;
* future barcode lookup.

### Recommendation

Do not add the number in the common foundation automatically.

Settle it in the Cash Movement Slip specification.

If accepted, use an explicit Store-scoped sequence rather than exposing a database ID.

Possible schema:

```text
stores.next_cash_movement_sequence
pos_cash_movements.movement_sequence
pos_cash_movements.movement_number
```

Possible presentation:

```text
MAIN-CM-000184
```

This is a pending operational-identity decision, not a blocker for the Customer Receipt or Gift Receipt work.

---

# 17. Session X Report matrix

| X Report fact           | Current source                     | Status           | Required work                                     |
| ----------------------- | ---------------------------------- | ---------------- | ------------------------------------------------- |
| Session                 | POS Session                        | Available        | None.                                             |
| Store                   | POS Session Store                  | Available        | None.                                             |
| Register                | POS Device                         | Available        | None.                                             |
| Responsible cashier     | Session cashier                    | Available        | None.                                             |
| Current totals          | `Reporting::BuildSessionTotals`    | Available        | Existing reporting service.                       |
| Expected cash           | Session totals and Cash Movements  | Available        | Existing reporting behavior.                      |
| Cost and margin         | Reporting service with permissions | Available        | Respect permissions.                              |
| Report timestamp        | Current generation time            | Available        | Print.                                            |
| Persisted report number | None                               | Not required     | X Report is a current interim view.               |
| Reprint status          | Not applicable                     | Derived behavior | Each X Report is a new current-generation report. |

### Finding

An X Report is not a historical reprint because it is not a closed, immutable report snapshot.

Every generation reflects the current open Session.

No schema change is required.

---

# 18. Session Z Report matrix

| Z Report fact             | Current source                   | Status       | Required work                                 |
| ------------------------- | -------------------------------- | ------------ | --------------------------------------------- |
| Z Number                  | `pos_session_z_reports.z_number` | Available    | Print.                                        |
| Session                   | `pos_session_id`                 | Available    | Print Register and Session context.           |
| Business date             | `business_date`                  | Available    | Print.                                        |
| Generated timestamp       | `generated_at`                   | Available    | Print.                                        |
| Generated by              | `generated_by_user_id`           | Available    | Print where required.                         |
| Expected cash             | Persisted report                 | Available    | Print according to permission.                |
| Counted cash              | Persisted report                 | Available    | Print according to permission.                |
| Cash variance             | Persisted report                 | Available    | Print according to permission.                |
| Financial sections        | Persisted `payload`              | Available    | Use payload, not current recalculation.       |
| Report definition version | Persisted                        | Available    | Internal; optional on print.                  |
| Reprint state             | Historical access                | Workflow gap | Historical Z access should display `REPRINT`. |

### Finding

No schema change is required.

The persisted Z payload is already the appropriate immutable report source.

---

# 19. Business-Day Z Report matrix

| Z Report fact             | Current source                    | Status       | Required work                         |
| ------------------------- | --------------------------------- | ------------ | ------------------------------------- |
| Z Number                  | `business_day_z_reports.z_number` | Available    | Print.                                |
| Business Day              | `business_day_id`                 | Available    | Print.                                |
| Business date             | `business_date`                   | Available    | Print.                                |
| Store                     | `store_id`                        | Available    | Print.                                |
| Generated timestamp       | `generated_at`                    | Available    | Print.                                |
| Generated by              | `generated_by_user_id`            | Available    | Print where appropriate.              |
| Financial sections        | Persisted `payload`               | Available    | Use persisted payload.                |
| Source cutoff             | `source_cutoff_at`                | Available    | Internal or audit presentation.       |
| Report definition version | Persisted                         | Available    | Internal or footer presentation.      |
| Reprint state             | Historical access                 | Workflow gap | Historical access displays `REPRINT`. |

### Finding

No schema change is required.

---

# 20. Barcode capability matrix

| Document                   | Barcode value                                   | Symbology considerations                               | Schema required? |
| -------------------------- | ----------------------------------------------- | ------------------------------------------------------ | ---------------- |
| Customer Receipt           | Store-scoped Receipt Number                     | Must support letters and hyphens; Code 128 is suitable | No               |
| Gift Receipt               | Same Transaction lookup reference               | Same as Customer Receipt                               | No               |
| Post-Void Receipt          | Reversing Receipt Number                        | Same as Customer Receipt                               | No               |
| Credit Voucher             | Canonical 13-digit Account Number               | EAN-13                                                 | No               |
| Stored-Value Activity Slip | Usually masked Account Number; barcode optional | Do not expose credential unless intended               | No               |
| Cash Movement Slip         | Future public Movement Number                   | Pending public-number decision                         | Possibly         |
| Session Z Report           | Z Number or report lookup reference             | Optional                                               | No               |
| Business-Day Z Report      | Z Number or report lookup reference             | Optional                                               | No               |

## 20.1 Implementation gap

The application currently has no identified barcode-generation capability.

Required delivery work:

* select a server-side barcode library or renderer;
* support Code 128 for Receipt references;
* support EAN-13 for Stored-Value Account Numbers;
* generate accessible SVG or raster output suitable for browser printing;
* print the human-readable value beneath every barcode;
* test barcode dimensions on the 80 mm profile.

This is a dependency and rendering gap, not a database gap.

---

# 21. Permission and route gaps

| Document                   | Immediate/original access                         | Historical/reprint access                                               | Additional permission concern                       |
| -------------------------- | ------------------------------------------------- | ----------------------------------------------------------------------- | --------------------------------------------------- |
| Customer Receipt           | POS access to just-completed Transaction          | Receipt-reprint permission                                              | Separate current Receipt permission behavior.       |
| Gift Receipt               | Immediate completion workspace                    | Receipt-reprint permission or dedicated Gift Receipt reprint permission | No token or separate Gift Receipt entity.           |
| Post-Void Receipt          | User completing or viewing Post-Void              | Receipt-reprint permission                                              | Internal copy may require Post-Void permission.     |
| Stored-Value Activity Slip | User authorized to perform/view activity          | Stored-Value Ledger view                                                | Customer copy omits internal Approval details.      |
| Credit Voucher             | Explicit Account view and voucher-print authority | Same authority for later prints                                         | Bearer credential warrants a dedicated permission.  |
| Cash Movement Slip         | User posting movement                             | Cash Movement history access                                            | Approver information may require internal access.   |
| Session X                  | Reporting X permission                            | Not applicable                                                          | Existing cash/cost/margin field permissions remain. |
| Session Z                  | Session Z view permission                         | Same permission                                                         | Reprint marker on historical access.                |
| Business-Day Z             | Business-Day Z view permission                    | Same permission                                                         | Reprint marker on historical access.                |

### Recommended permission addition

Consider:

```text
stored_value.voucher.print
```

This is preferable to treating a bearer credential as ordinary Account viewing.

The precise key should be confirmed against the authorization-permission naming contract.

---

# 22. Recommended MVP schema changes

## Required

```ruby
add_column :stores, :gift_receipt_footer, :text
```

## Pending Cash Movement specification

Potentially:

```ruby
add_column :stores, :next_cash_movement_sequence, :bigint,
           null: false, default: 1

add_column :pos_cash_movements, :movement_sequence, :bigint
add_column :pos_cash_movements, :movement_number, :string
```

Do not add these until the Cash Movement Slip specification confirms that a generated public Movement Number is part of MVP.

## Not recommended

Do not add:

```text
pos_transactions.receipt_snapshot
pos_transactions.receipt_html
pos_transactions.receipt_template_version
pos_receipt_print_events
gift_receipts
gift_receipt_tokens
gift_receipt_lines
stored_value_entries.balance_after_cents
pos_tenders.card_brand
pos_tenders.masked_last_four
pos_transactions.document_type
```

These are either unnecessary under the accepted functional-reprint model or belong to broader capabilities rather than printing.

---

# 23. Recommended non-schema services

```text
PosPrinting::Document
PosPrinting::BuildCustomerReceipt
PosPrinting::BuildGiftReceipt
PosPrinting::BuildPostVoidReceipt
PosPrinting::BuildStoredValueActivitySlip
PosPrinting::BuildCreditVoucher
PosPrinting::BuildCashMovementSlip
PosPrinting::BuildSessionX
PosPrinting::BuildSessionZ
PosPrinting::BuildBusinessDayZ
StoredValue::BalanceAfterEntry
PosPrinting::Barcode
```

## 23.1 Builder responsibility

Builders own:

* selecting authoritative source facts;
* source validation;
* derived document classification;
* original/reprint status;
* correction banners;
* masking;
* omission of sensitive data;
* amount direction;
* Discount presentation;
* Tax and Tender summaries;
* barcode values;
* fallback labels.

## 23.2 Renderer responsibility

Renderers own:

* HTML structure;
* typography;
* spacing;
* wrapping;
* amount alignment;
* barcode image generation;
* signature lines;
* print-only CSS;
* paper width;
* page breaks;
* browser controls.

---

# 24. Required tests by gap type

## 24.1 Historical reconstruction

* Current Product name changes do not alter completed Line descriptions.
* Current prices do not alter completed selling prices.
* Current Tax configuration does not alter rate, base, treatment, or amount.
* Current Tender label changes affect only the label.
* Current Store header/footer changes affect later prints.
* No current commercial calculation service runs during print generation.

## 24.2 Original and reprint context

* Immediate Receipt route produces no `REPRINT`.
* Refreshing immediate Receipt remains original.
* Historical Receipt route produces `REPRINT`.
* Caller cannot suppress `REPRINT` through a query parameter.
* Immediate Receipt does not require historical reprint permission.
* Historical Receipt requires reprint permission.
* Beginning another Transaction clears the immediate original context.

## 24.3 Price Override and Discount

* Overridden selling price prints normally.
* Regular pre-override price does not print.
* Override reason and approver do not print.
* Completed Discounts print.
* Discount total reconciles.

## 24.4 Corrections

* Post-Void Receipt prints original and reversing Receipt Numbers.
* Reprint of original after Post-Void shows `VOIDED`.
* Reprint identifies the reversing Receipt.
* Original completed facts remain unchanged.
* Internal Post-Void facts do not leak to customer copy.

## 24.5 Gift Receipt

* Contains Store header, Transaction lookup data, barcode, human-readable Receipt Number, and Gift Receipt footer.
* Contains no item Lines.
* Contains no prices, totals, Tax, Tenders, Customer identity, or Gift token.
* Historical copy shows `REPRINT`.

## 24.6 Stored Value

* Activity Slip derives balance after Entry from Ledger.
* Activity Slip does not substitute current balance for historical balance.
* Credit Voucher prints full Account Number and current balance.
* Multiple voucher prints do not change balance.
* Suspended-account handling follows the later Voucher specification.

## 24.7 Cash Movements

* Every posted movement offers a printable slip.
* Slip includes all applicable facts and signature fields.
* Printing does not post another movement.
* Historical access displays `REPRINT`.
* Movement Number behavior follows the Cash Movement specification.

## 24.8 Reports

* X Report reflects current Session facts.
* X Report does not claim to be a reprint.
* Z Reports use persisted report payloads.
* Historical Z output displays `REPRINT`.
* Field-level reporting permissions remain enforced.

---

# 25. Planning conclusion

The agreed MVP printed-document contract does not require a broad schema expansion.

The implementation can proceed with:

1. one definite configuration migration for `gift_receipt_footer`;
2. a structured document foundation;
3. server-owned original/reprint workflow context;
4. Customer Receipt refactoring;
5. barcode support;
6. Gift Receipt and Post-Void templates;
7. Stored-Value builders;
8. a Cash Movement specification that settles public movement identity;
9. X/Z print integration.

The next specification should be:

```text
docs/design/pos-printing/gift-receipts.md
```

It is small, has a clearly settled contract, and will validate the shared header, workflow-context, barcode, and footer components before the more complex Stored-Value and Cash Movement documents are implemented.
