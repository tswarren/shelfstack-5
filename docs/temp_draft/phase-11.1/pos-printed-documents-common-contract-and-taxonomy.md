# POS Printed Documents — Common Contract and Taxonomy

**Status:** Draft
**Scope:** POS-generated customer and operational documents
**Related domains:** Point of Sale, Stored Value, Reporting and Reconciliation, Authorization

---

## 1. Purpose

This specification defines the common meaning, lifecycle, presentation rules, and taxonomy for documents that ShelfStack may display or print from POS activity.

It governs:

* Customer Receipts;
* Gift Receipts;
* Post-Void Receipts;
* Stored-Value Activity Slips;
* Credit Vouchers;
* Cash Movement Slips;
* X and Z reports;
* other POS operational records that may require printable output.

Document-specific specifications may add fields and rules, but must follow this common contract.

---

## 2. Governing principle

A printed document is a **presentation of authoritative ShelfStack records**. It is not itself the financial, inventory, Stored-Value, cash-accountability, reporting, or correction record.

```text
Completed or posted facts
+ current presentation configuration
+ document-specific rules
= structured document
→ browser, PDF, or printer rendering
```

Printing does not:

* complete a POS Transaction;
* post a Cash Movement;
* create or adjust Stored Value;
* reverse a Transaction;
* change Inventory;
* authorize a Return;
* create a reporting fact;
* establish whether a domain operation succeeded.

A printer or rendering failure must not roll back or invalidate successfully posted activity.

---

## 3. Scope

### 3.1 In scope

This contract governs documents produced from:

* completed POS Transactions;
* Customer Returns;
* Post-Void Transactions;
* completed Stored-Value Entries and Accounts;
* posted Cash Movements;
* POS Sessions;
* Business Days;
* cash counts and reconciliation records;
* No Sale events;
* suspended Transactions where a claim or recall slip is supported.

### 3.2 Out of scope

The following are not POS documents under this specification:

* standalone payment-terminal receipts;
* Product price or shelf labels;
* Purchase Orders;
* Receiving documents;
* Returns to Vendor;
* kitchen or café routing tickets;
* Buyback documents before the Buyback domain is specified;
* layaway, deposit, or installment documents before those capabilities exist.

Standalone card-terminal output remains a separate processor or terminal document. ShelfStack must not imply that it captured processor facts that were never entered into ShelfStack.

---

## 4. Terminology

### Document

A structured customer-facing or operational presentation derived from authoritative ShelfStack records.

### Source record

The completed or posted record from which a document is generated, such as a POS Transaction, Stored-Value Entry, Stored-Value Account, Cash Movement, POS Session, or Business Day.

### Original

A document printed or displayed from the immediate workflow that created or completed its source record.

For a completed POS Transaction, the immediate Receipt workspace is the original-document context.

### Reprint

A document printed after its source record has been retrieved through historical access, including:

* Receipt Lookup;
* Transaction history;
* Customer history;
* reporting;
* audit or administrative access;
* another later workflow that opens previously completed activity.

### Copy

An additional physical or electronic rendering of the same document.

For MVP, multiple copies printed from the immediate completion workspace may all remain unmarked originals.

### Activity slip

An informational document describing a completed posting, such as a Stored-Value issuance, reload, redemption, refund, or reversal.

### Credit Voucher

A credential-bearing document that contains a redeemable Stored-Value Account identifier. A Credit Voucher is a bearer instrument and is materially different from an informational activity slip.

### Renderer

A presentation adapter that converts the structured document into browser HTML, PDF, ESC/POS, or another output format.

---

## 5. Core invariants

1. Documents are generated only from completed, posted, or otherwise authoritative records.

2. Historical commercial and settlement facts are never recalculated from current configuration.

3. Documents do not become authoritative records merely because they are printed.

4. Printing occurs after the source operation succeeds.

5. Print failure does not reverse or modify the source operation.

6. Original versus reprint status is determined by workflow context, not by whether paper was physically produced.

7. ShelfStack does not need to determine whether the user completed, cancelled, or redirected a browser print dialog.

8. Reprints create no new commercial, Inventory, Tender, tax, Stored-Value, or cash-accountability activity.

9. Documents may use current Store information, labels, policy text, and templates.

10. Current configuration must not be used to alter historical amounts, tax treatment, balances, correction effects, or other completed facts.

11. Sensitive internal identifiers and authorization credentials do not print.

12. Document labels are derived presentations and do not impose rigid domain record types.

13. A barcode is accompanied by its human-readable public reference.

14. Price Overrides are not identified on customer-facing Receipts.

15. Discounts remain visible as explicit reductions.

---

## 6. Historical facts and current presentation

ShelfStack does not preserve a complete Receipt snapshot, rendered document, PDF, HTML file, or printer byte stream for MVP.

Documents are reconstructed from authoritative records and current presentation configuration.

### 6.1 Historical transaction and posting facts

The following must come from completed or posted records:

* Receipt Number;
* Transaction Number or other public Transaction reference;
* completion or posting timestamp;
* original and reversing Transaction relationships;
* Store and POS Session association;
* Register or POS Device used;
* cashier or performing User;
* completed line descriptions and identifiers;
* quantities;
* completed selling prices;
* Discounts and allocations;
* completed tax rates, bases, treatments, and amounts;
* exemption results retained on completed activity;
* Transaction totals;
* completed Tender direction and amount;
* cash tendered and change;
* captured card brand and masked reference data;
* completed Stored-Value Entry amount;
* Stored-Value balance immediately after a historical Entry, when displayed on an Activity Slip;
* Return source and linkage;
* Post-Void relationships;
* posted Cash Movement amount, direction, reason, and reference;
* Session and Business-Day report facts.

These values must not be recalculated from current Product, Pricing, Tax, Tender, or Store policy configuration.

### 6.2 Price Overrides

Price Overrides remain distinct internal commercial facts but are hidden from customer-facing Receipts.

The completed overridden selling price is printed as the item’s ordinary unit price.

The Receipt does not print:

* the pre-override regular price;
* an `Override` label;
* the Override reason;
* the User who authorized the Override;
* the difference between regular and overridden price.

Example:

```text
THE LEFT HAND OF DARKNESS
1 × $19.99                         $19.99
```

The Receipt does not show:

```text
Regular $24.99 → Override $19.99
```

Discounts remain separately visible:

```text
THE LEFT HAND OF DARKNESS
1 × $19.99                         $19.99
Member discount                    -$2.00
```

The resulting Receipt must reconcile to completed Transaction totals.

### 6.3 Current presentation configuration

The following may be resolved at display or print time for MVP:

* Store name;
* Organization name;
* Store address;
* phone number;
* website;
* Receipt header and footer;
* Gift Receipt footer;
* logo;
* tax display names;
* Tender display names;
* customer-facing Stored-Value type names;
* generic Return-policy wording;
* thank-you text;
* section labels;
* document layout;
* font and character width;
* barcode presentation;
* printer encoding and cutting behavior.

A later reprint may therefore show an updated Store address, corrected tax label, or revised footer without changing historical monetary facts.

### 6.4 Historical claims

Current configuration must not be used to generate a historical claim unsupported by completed data.

Examples include:

* a historical Return deadline;
* final-sale status;
* historical tax exemption;
* Stored-Value balance after an earlier Entry;
* original approval status;
* historical promotional eligibility.

Where the necessary historical fact is unavailable, use generic wording rather than inferring it from current policy.

Acceptable:

```text
Returns subject to current Store policy and verification
of the original Transaction.
```

Not acceptable:

```text
Returnable through August 26, 2026
```

when that date was derived only from a current Return Policy.

### 6.5 Missing current configuration

A document must remain printable when a current configuration record has been renamed, deactivated, or removed.

Renderers must provide safe fallback labels such as:

```text
Tax 6.00%
Card
Stored Value
Cash Movement
```

The absence of a current customer-facing label must not prevent reconstruction of historical activity.

---

## 7. Common document structure

A structured document should support the following conceptual sections:

```text
document
  metadata
  issuer
  source references
  parties
  detail lines
  totals or accountability summary
  settlement or movement summary
  policy and instructions
  machine-readable references
  rendering hints
```

This is a presentation contract, not a required database schema.

### 7.1 Metadata

Common metadata may include:

* `document_kind`;
* derived document title;
* status banner;
* original or reprint context;
* source record type;
* source public reference;
* source completion or posting timestamp;
* display or print timestamp;
* locale and currency.

### 7.2 Issuer

Issuer information may include:

* Store name;
* Organization name;
* address;
* phone;
* website;
* configured header text.

### 7.3 Source references

Documents should display appropriate public references, such as:

* Receipt Number;
* Transaction Number;
* original Receipt Number;
* reversing Receipt Number;
* Stored-Value Account Number;
* Cash Movement reference;
* Session number;
* Z-Report Number.

Internal database IDs must not be displayed.

### 7.4 Parties

Where appropriate, a document may identify:

* cashier;
* performing User;
* approver;
* Customer;
* recipient;
* collector;
* source or destination location.

Customer and User information must be limited to what the document’s business purpose requires.

### 7.5 Machine-readable references

Where lookup or redemption benefits from scanning, the document should include:

* a barcode; and
* the same public reference in human-readable form.

A barcode may represent:

* Receipt or Transaction lookup information;
* a Stored-Value Account credential;
* a Cash Movement reference;
* a report lookup reference.

Raw database IDs must not be encoded.

Gift Receipts do not use separate secure tokens.

---

## 8. Original and reprint rules

### 8.1 Original context

The following are originals for MVP:

* an automatic print immediately after completion;
* printing from the completed Transaction’s Receipt workspace;
* retrying a failed or cancelled print while still on that workspace;
* printing additional copies before leaving the completion workflow;
* printing a Gift Receipt from the immediate completion workflow;
* printing a Stored-Value Activity Slip or Credit Voucher from the immediate completion workflow;
* printing a Cash Movement Slip immediately after posting the movement;
* printing a Session or Business-Day report from the workflow that closes it.

Original status does not mean that only one physical copy may exist.

### 8.2 Reprint context

The following are reprints:

* printing after Receipt Lookup;
* printing after retrieving a completed Transaction from history;
* printing from Customer history;
* printing from reporting or audit access;
* printing after returning to an earlier Transaction through another workflow;
* printing a Gift Receipt from a historically retrieved Transaction;
* printing an earlier Cash Movement from movement history;
* printing a previously completed report from history.

### 8.3 Visible reprint marking

Reprints must be clearly marked near the top.

```text
REPRINT

Receipt 01-00018425
Originally completed Jul 27, 2026 3:42 PM
Reprinted Jul 28, 2026 10:16 AM
```

A reprint retains the original source reference. It does not receive another Receipt Number.

### 8.4 Server ownership

The server derives original or reprint status from the originating workflow.

A user-editable request parameter must not be the sole authority for suppressing a required `REPRINT` marker.

### 8.5 Refreshes and retries

Refreshing the immediate Receipt workspace remains original context.

A printer retry or additional copy from that workspace remains an original.

Once the cashier leaves the immediate completion workflow and later retrieves the source record, subsequent output is a reprint.

### 8.6 Reprints of Post-Voided Transactions

A reprint of an original Transaction that has since been Post-Voided must show a prominent `VOIDED` indication and reference the reversing Transaction.

```text
VOIDED

Receipt 01-00018425
Reversed by receipt 01-00018502
Reversal completed Jul 27, 2026 4:18 PM
```

The original Transaction facts remain unchanged. The notice communicates the current correction status without rewriting the original record.

---

## 9. Customer identity

Customer Receipts display only the masked Customer Number when a Customer is attached and Store policy permits it.

Example:

```text
Customer **** 4837
```

Customer Receipts do not normally print:

* full Customer Number;
* Customer address;
* email address;
* phone number;
* internal Customer ID.

Customer name may be considered later under Store configuration.

---

## 10. Security and privacy

Printed documents must not expose:

* full payment-card numbers;
* approval PINs or passwords;
* internal User authentication data;
* internal database IDs;
* private Transaction UUIDs not intended as public references;
* internal Inventory cost or margin;
* Department accounting mappings;
* internal tax calculation traces;
* internal promotion-allocation details;
* internal Return Disposition unless operationally required;
* Inventory warnings or Reservation state;
* authority thresholds;
* sensitive Customer contact information without a defined need.

Approver names may appear on internal accountability documents where required. Approval credentials never print.

A Credit Voucher intentionally exposes a redeemable Stored-Value Account identifier and must be treated as a bearer instrument.

---

## 11. Rendering contract

### 11.1 Shared structured source

Browser HTML, PDF, and future ESC/POS renderers should consume the same structured document facts.

Document semantics must not be reimplemented independently in each renderer.

### 11.2 Browser printing

Browser-printable HTML is the MVP rendering path.

ShelfStack generally cannot determine whether the user:

* completed the print dialog;
* cancelled it;
* selected a PDF destination;
* printed multiple copies;
* encountered a local printer failure.

Browser print initiation is not proof of physical print success.

### 11.3 Browser print auditing

ShelfStack does not persist browser print-view or print-command audit events for MVP.

Original versus reprint presentation is determined by workflow context.

Commercial and operational source records remain auditable independently of printing.

### 11.4 Thermal printer profile

A future thermal-printer profile may define:

* printable width;
* nominal columns;
* font size;
* bold or double-height support;
* supported encoding;
* transliteration or substitution behavior;
* barcode capabilities;
* logo support;
* automatic cutting;
* Drawer-pulse support.

These are renderer and device concerns, not document semantics.

### 11.5 Width

The default thermal target is 80 mm paper, commonly rendered around 42 monospaced characters.

This is a default printer profile, not a business invariant.

---

# 12. Document taxonomy

## 12.1 Customer and Transaction documents

| Document kind                    | Source                                    | Audience             | Purpose                                                        | MVP                                   |
| -------------------------------- | ----------------------------------------- | -------------------- | -------------------------------------------------------------- | ------------------------------------- |
| Customer Receipt                 | Completed POS Transaction                 | Customer             | Sale, Return, mixed activity, tax, and Tender summary          | Required                              |
| Return Receipt                   | Completed return-only POS Transaction     | Customer             | Customer Return and refund evidence                            | Derived Customer Receipt presentation |
| Mixed Transaction Receipt        | Completed sale-and-return POS Transaction | Customer             | Combined sales and Returns with net settlement                 | Derived Customer Receipt presentation |
| Post-Void Receipt                | Completed reversing POS Transaction       | Customer or internal | Evidence that a completed Transaction was fully reversed       | Required                              |
| Gift Receipt                     | Completed POS Transaction                 | Gift recipient       | Brief Transaction lookup summary without financial information | Required                              |
| Suspended Transaction Claim Slip | Suspended POS Transaction                 | Customer or cashier  | Recall reference without implying completion                   | Should                                |
| No Sale Slip                     | Posted No Sale event                      | Internal             | Drawer-opening reason and audit evidence                       | Optional                              |

`Return Receipt` and `Mixed Transaction Receipt` are derived presentations, not separate POS Transaction types.

## 12.2 Stored-Value documents

| Document kind              | Source                                                | Audience | Purpose                                                                    | MVP      |
| -------------------------- | ----------------------------------------------------- | -------- | -------------------------------------------------------------------------- | -------- |
| Stored-Value Activity Slip | Completed Stored-Value Entry and related POS activity | Customer | Issuance, reload, redemption, refund, adjustment, or reversal confirmation | Required |
| Credit Voucher             | Stored-Value Account                                  | Bearer   | Redeemable paper credential for any Stored-Value Account                   | Required |
| Stored-Value Balance Slip  | Stored-Value Account                                  | Customer | Informational current balance without bearer-voucher formatting            | Should   |

All Stored-Value Account types may be printed as Credit Vouchers:

* Gift Card;
* Store Credit;
* Trade Credit.

The voucher must identify the actual account type while using a common `CREDIT VOUCHER` document contract.

## 12.3 Cash-accountability documents

| Document kind        | Source                              | Audience | Purpose                                 | MVP                                                 |
| -------------------- | ----------------------------------- | -------- | --------------------------------------- | --------------------------------------------------- |
| Cash Movement Slip   | Posted Cash Movement                | Internal | Evidence of Cash In or Cash Out         | Required for every Cash Movement                    |
| Cash Transfer Slip   | Paired or referenced Cash Movements | Internal | Chain-of-custody evidence               | Deferred until transfer workflow is fully specified |
| Cash Count Record    | Session count                       | Internal | Counted cash and denominations          | Should                                              |
| Cash Variance Record | Session close or reconciliation     | Internal | Expected, counted, variance, and review | Should                                              |

Every posted Cash Movement produces or offers an immediate printable Cash Movement Slip.

Every Cash Movement Slip includes signature fields.

## 12.4 Reporting documents

| Document kind         | Source                   | Audience | Purpose                                   | MVP                         |
| --------------------- | ------------------------ | -------- | ----------------------------------------- | --------------------------- |
| Session X Report      | Current open POS Session | Internal | Interim activity and expected-cash review | Required reporting document |
| Session Z Report      | Closed POS Session       | Internal | Final Session accountability              | Required reporting document |
| Business-Day Z Report | Closed Business Day      | Internal | Consolidated Store-wide day close         | Required reporting document |
| Reconciliation Record | Finalized reconciliation | Internal | Resolution and signoff evidence           | Should                      |

## 12.5 Future or domain-owned documents

| Document kind                       | Owning area                | Status   |
| ----------------------------------- | -------------------------- | -------- |
| Product Request acknowledgement     | Product Requests / POS     | Later    |
| Pickup acknowledgement              | Product Requests / POS     | Later    |
| Buyback receipt or seller statement | Future Buyback domain      | Deferred |
| Kitchen or preparation ticket       | Future café routing        | Deferred |
| Integrated payment receipt          | Future payment integration | Deferred |
| Layaway or deposit receipt          | Future sales capability    | Deferred |

---

# 13. Document-specific minimum contracts

## 13.1 Customer Receipt

Minimum content:

* Store header;
* Receipt or Transaction Number in human-readable form;
* Receipt barcode;
* completion timestamp;
* Register and cashier labels;
* masked Customer Number, where applicable;
* completed merchandise and Return lines;
* quantities;
* completed selling prices;
* Discounts;
* tax summary;
* Transaction total;
* completed Tenders and refunds;
* cash change;
* original Receipt references where applicable;
* current Store Receipt footer.

Price Overrides are not identified. The completed overridden price appears as the ordinary item price.

Discounts are shown as explicit reductions.

A mixed Transaction marks individual Return lines rather than placing a `RETURN` banner over the entire document.

## 13.2 Gift Receipt

A Gift Receipt is a brief, price-suppressed Transaction lookup summary modeled on the BookSense workflow described for ShelfStack.

It is not:

* an itemized Receipt;
* a line-scoped Return authorization;
* a separate Gift Receipt record;
* a bearer credential;
* a tokenized Return instrument.

Its purpose is to provide the information needed to retrieve the original completed Transaction.

Minimum content:

* Store header;
* `GIFT RECEIPT` title;
* Receipt or Transaction Number;
* completion date and time;
* Store identifier, where needed for lookup;
* Register or POS Device identifier;
* cashier or other lookup context where operationally useful;
* barcode containing the Transaction lookup reference;
* the same reference in human-readable form;
* configured Gift Receipt footer.

A Gift Receipt omits:

* item lines;
* prices;
* Discounts;
* Transaction totals;
* tax;
* Tenders;
* purchaser payment information;
* Customer identity;
* Return eligibility;
* separate Gift Receipt Number;
* secure Gift Receipt token.

Example:

```text
           SHELFSTACK BOOKS
        123 Main Street, Anytown
           (555) 555-0142

************ GIFT RECEIPT ************

Receipt 01-00018425
Jul 27, 2026 3:42 PM
Store MAIN · Register 02
Cashier Jordan

[receipt lookup barcode]
01-00018425

This Gift Receipt may be used to locate
the original Transaction. Returns remain
subject to Store policy and verification.
```

A Gift Receipt printed from the immediate completion workflow is an original.

A Gift Receipt generated after retrieving the historical Transaction is marked `REPRINT`.

No Gift Receipt table, line entitlement record, token digest, revocation state, or token-expiration policy is required for MVP.

Return lookup and remaining-returnable-quantity rules remain authoritative in the ordinary Return workflow.

## 13.3 Post-Void Receipt

Post-Voids are printable.

Minimum content:

* `POST-VOID` title;
* reversing Receipt Number;
* barcode and human-readable reversing Receipt Number;
* original Receipt Number;
* original completion timestamp;
* reversal completion timestamp;
* reversing merchandise lines;
* reversed Discounts;
* reversed tax;
* reversed Tenders;
* relevant Stored-Value effects;
* current Store footer.

The customer copy generally omits:

* internal Post-Void reason;
* authority thresholds;
* approval credentials;
* internal eligibility checks.

An internal printable copy may additionally include:

* requester;
* approver;
* Post-Void reason;
* external Card-reversal references;
* affected Stored-Value Accounts;
* other linked correction references.

## 13.4 Stored-Value Activity Slip

Minimum content:

* customer-facing Stored-Value type;
* masked Account Number;
* activity type;
* activity amount;
* balance immediately after the Entry;
* related Receipt Number where applicable;
* Entry timestamp.

Examples of activity types:

* Gift Card issued;
* Gift Card reloaded;
* Gift Card redeemed;
* refund to Store Credit;
* Trade Credit redeemed;
* Stored-Value adjustment;
* Stored-Value activity reversed.

An Activity Slip is informational and does not need to expose the complete redeemable account credential.

## 13.5 Credit Voucher

Every Stored-Value Account may be printed as a Credit Voucher.

A Credit Voucher is a bearer instrument. Possession of the printed credential may permit redemption.

Minimum content:

* `CREDIT VOUCHER` title;
* actual account type:

  * Gift Card;
  * Store Credit;
  * Trade Credit;
* full redeemable Account Number;
* Account Number barcode;
* current Account balance;
* balance-as-of timestamp;
* related Receipt Number where applicable;
* Store header;
* configured voucher terms;
* bearer-instrument warning.

Example:

```text
************ CREDIT VOUCHER ***********

Account type: Store Credit
Balance:                         $18.75
Balance as of Jul 27, 2026 4:18 PM

Account 2100123456789
[EAN-13 barcode]
2100123456789

Treat this voucher like cash.
The Stored-Value Account balance is
authoritative and may change after use.
```

The balance shown on a Credit Voucher is the current Account balance at print time.

The Stored-Value ledger and cached Account balance remain authoritative. Printing multiple copies does not create additional value.

A reprinted Credit Voucher must be marked `REPRINT`, but remains a valid representation of the same underlying Account credential unless the Account is suspended or otherwise unavailable.

## 13.6 Cash Movement Slip

Every posted Cash Movement has a printable Cash Movement Slip.

Minimum content:

* Cash Movement Type;
* Cash In or Cash Out;
* amount;
* Store;
* Register or Session label;
* timestamp;
* performing User;
* reason;
* reference, where applicable;
* approving User, where applicable;
* barcode and human-readable movement reference, where a public reference exists;
* signature fields.

Every Cash Movement Slip includes:

```text
Prepared by: __________________________

Approved by: __________________________

Received by: __________________________
```

Labels may be adapted to the movement type, but the signature area remains present.

Type-specific documents may additionally include:

* bag or envelope reference;
* payee;
* source;
* destination;
* collector;
* transfer reference;
* correction reference.

## 13.7 X and Z reports

Minimum content follows the Reporting and Reconciliation specification.

The common document contract additionally requires:

* clear report title;
* Store;
* Session or Business Day;
* report number where applicable;
* generation or close timestamp;
* responsible User;
* original or reprint marker;
* barcode and human-readable report reference where lookup is supported;
* no recalculation of historical closed-period facts from current configuration.

---

# 14. Permissions

Document display and printing must respect access to the underlying source record.

Likely permission areas include:

* Customer Receipt view;
* Receipt reprint;
* Gift Receipt printing;
* Stored-Value Account and ledger view;
* Credit Voucher printing;
* Cash Movement creation and view;
* X-Report access;
* Session and Business-Day close;
* Z-Report access;
* Post-Void access;
* audit and reconciliation access.

Printing must not grant access to source facts the User could not otherwise view.

Credit Voucher printing should require explicit access to the Stored-Value Account because the document exposes a redeemable bearer credential.

---

# 15. Error handling

A document-generation failure must:

* leave the source record unchanged;
* present a visible and actionable error;
* allow retry;
* avoid creating duplicate commercial activity;
* avoid consuming another Receipt Number;
* avoid creating another Stored-Value Entry;
* avoid posting another Cash Movement.

A missing logo, unavailable current display label, or unsupported character must degrade gracefully.

The renderer should substitute a safe label or printable character rather than fail the source workflow.

---

# 16. MVP boundaries

## 16.1 Required for MVP

* browser-printable Customer Receipts;
* original and reprint context;
* visible `REPRINT` marker;
* barcode plus human-readable Receipt or Transaction Number;
* masked Customer Number;
* hidden Price Override presentation;
* visible Discounts;
* Return and mixed-Transaction presentation;
* printable Post-Void Receipts;
* `VOIDED` notice on reprints of reversed original Transactions;
* brief non-itemized Gift Receipts;
* Gift Receipt footer;
* Stored-Value Activity Slips;
* printable Credit Vouchers for all Stored-Value Account types;
* bearer-instrument warnings;
* Cash Movement Slips for every Cash Movement;
* signature fields on every Cash Movement Slip;
* X and Z report printing;
* reconstruction from authoritative records;
* current Store header, footer, labels, and template;
* safe omission of sensitive data.

## 16.2 Not required for MVP

* complete Receipt snapshots;
* stored rendered HTML;
* stored PDFs;
* stored ESC/POS byte streams;
* historical Store header or footer snapshots;
* historical tax-name snapshots;
* historical template snapshots;
* Gift Receipt tokens;
* Gift Receipt line-entitlement records;
* separate Gift Receipt Numbers;
* browser print-command auditing;
* managed printer queues;
* reliable physical print-success detection;
* printer fleet administration;
* facsimile reproduction of original paper;
* every optional POS operational slip.

---

# 17. Acceptance criteria

The common contract is satisfied when:

1. A completed Transaction can be rendered without consulting current Pricing or Tax calculation services.

2. Changing the current Store header, footer, address, or display labels changes later presentation without changing historical monetary facts.

3. A reprint retains the original Receipt Number.

4. Printing from the immediate completion Receipt workspace is not marked `REPRINT`.

5. Printing after historical retrieval is marked `REPRINT`.

6. Multiple prints from the immediate completion workspace may remain originals.

7. A printer or rendering failure does not alter the completed source record.

8. A Customer Receipt displays a barcode and human-readable Receipt or Transaction Number.

9. A Customer Receipt displays a masked Customer Number where applicable.

10. A Price Override is not identified on the Customer Receipt.

11. The completed overridden selling price appears as the ordinary item price.

12. Discounts appear as explicit reductions.

13. A Post-Void Receipt shows both original and reversing Receipt Numbers.

14. A reprint of a Post-Voided original Transaction is marked `VOIDED` and identifies the reversing Receipt.

15. A Gift Receipt contains only Store header, lookup information, barcode, human-readable reference, and Gift Receipt footer.

16. A Gift Receipt contains no item lines, financial details, Customer identity, or token.

17. A Stored-Value Activity Slip shows the balance immediately after the relevant Entry.

18. A Credit Voucher shows the current Account balance and full redeemable Account credential.

19. Printing multiple Credit Vouchers does not change Stored-Value balance.

20. Every Cash Movement has a printable slip.

21. Every Cash Movement Slip includes signature fields.

22. A Cash Movement Slip is derived from the posted movement and does not create another movement.

23. Sensitive internal identifiers and credentials do not appear except where a Credit Voucher intentionally exposes its bearer credential.

24. Missing current presentation configuration uses safe fallback labels.

25. The same structured document facts can support multiple renderers without redefining business semantics.

---

# 18. Remaining open decision

The remaining common-contract decision is:

> Which document elements belong to configurable Store policy, and which labels and behaviors are fixed ShelfStack document semantics?

This decision should be refined while drafting the individual document specifications. It does not need to block the common taxonomy.
