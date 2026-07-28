Draft for `docs/design/pos-printing/customer-receipts.md`:

# POS Printing — Customer Receipts

**Status:** Draft
**Scope:** Customer-facing Receipts generated from completed POS Transactions
**Parent specification:** [Common Document Contract and Taxonomy](common-document-contract-and-taxonomy.md)
**Related domains:** Point of Sale, Stored Value, Tax, Authorization
**Related decisions:** Immutable completed activity; explicit corrections; functional reprints; browser-printable MVP output

---

## 1. Purpose

This specification defines the customer-facing Receipt produced from a completed ShelfStack POS Transaction.

A Customer Receipt explains:

* what was sold or returned;
* the completed prices and Discounts;
* how tax was applied;
* the final Transaction total;
* how the Transaction was settled;
* how the Transaction may be retrieved later.

It also defines the customer-facing presentation of:

* sale-only Transactions;
* return-only Transactions;
* mixed sale-and-return Transactions;
* Post-Void Transactions;
* reprints;
* reprints of Transactions that were later Post-Voided.

A Receipt is a presentation of completed facts. It is not the authoritative Transaction record and does not create, modify, or reverse activity.

---

## 2. Governing rules

1. A Customer Receipt may be generated only from a completed POS Transaction.

2. The Receipt is reconstructed from completed Transaction, Line, Discount, Tax, Tender, Stored-Value, and correction records.

3. ShelfStack does not preserve a complete Receipt snapshot, rendered HTML document, PDF, or printer byte stream for MVP.

4. Historical commercial and settlement facts must come from completed records.

5. Current Store information, customer-facing labels, header, footer, and visual template may be applied at print time.

6. Current Pricing, Promotion, Tax calculation, classification, or Return-policy services must not recalculate completed Transaction facts.

7. Printing or displaying a Receipt does not alter the Transaction.

8. Printer or rendering failure does not invalidate completion.

9. Original versus reprint status is determined by workflow context.

10. Price Overrides are hidden from the customer-facing Receipt.

11. Discounts are shown as explicit reductions.

12. Receipt barcodes must be accompanied by the corresponding human-readable Receipt Number.

13. Customer identity is limited to a masked Customer Number.

14. A reprint of a Transaction that has since been Post-Voided must be visibly marked `VOIDED` and identify the reversing Receipt.

---

## 3. Source records

A Customer Receipt may use the following authoritative records:

```text
POS Transaction
├── completed POS Line Items
├── completed Discount Allocations
├── completed Tax Components
├── completed Tenders
├── related Stored-Value Entries
├── Customer reference
├── completion POS Session and Device
├── reversing or reversed Transaction relationship
└── related public Receipt Numbers
```

The Receipt builder may also use current presentation configuration:

```text
Current Store
├── Store and Organization display names
├── address and contact information
├── Receipt header
├── Receipt footer
├── customer-facing Tax labels
├── customer-facing Tender labels
└── Receipt layout configuration
```

---

## 4. Historical fact-source contract

| Receipt fact                       | Authoritative source                                   | Current configuration permitted?  |
| ---------------------------------- | ------------------------------------------------------ | --------------------------------- |
| Receipt Number                     | Completed POS Transaction                              | No                                |
| Completion date and time           | Completed POS Transaction                              | No                                |
| Original or reversing relationship | Completed POS Transaction relationship                 | No                                |
| Register                           | Completion POS Session or Device                       | Label may use current Device name |
| Cashier                            | Completed Transaction or Session User reference        | Current display name permitted    |
| Customer Number                    | Customer attached to completed Transaction             | Masking only                      |
| Item description                   | Completed Line snapshot                                | No                                |
| Item identifier                    | Completed Line snapshot                                | No                                |
| Quantity                           | Completed Line                                         | No                                |
| Printed unit price                 | Completed selling price                                | No                                |
| Discount amount                    | Completed Discount Allocation                          | No                                |
| Discount label                     | Completed Discount metadata or safe current label      | Yes, label only                   |
| Tax rate, base, and amount         | Completed Tax Component                                | No                                |
| Tax label                          | Current Tax configuration or fallback                  | Yes                               |
| Transaction total                  | Completed POS Transaction                              | No                                |
| Tender amount and direction        | Completed Tender                                       | No                                |
| Tender name                        | Current Tender Type or fallback                        | Yes                               |
| Card brand and last four           | Completed Tender metadata                              | No                                |
| Cash tendered and change           | Completed Tender                                       | No                                |
| Stored-Value amount                | Completed Tender or Line                               | No                                |
| Historical Stored-Value balance    | Completed Stored-Value posting result, where available | No                                |
| Store header and footer            | Current Store configuration                            | Yes                               |
| Barcode value                      | Completed Receipt Number                               | No                                |
| `VOIDED` state                     | Reversing Transaction relationship                     | No                                |

A missing or deactivated current configuration record must not prevent the Receipt from rendering. The builder must provide safe fallback labels.

---

## 5. Receipt presentation classification

The Receipt title and banners are derived from completed Transaction contents.

| Completed contents                                | Customer-facing presentation                     |
| ------------------------------------------------- | ------------------------------------------------ |
| Sale Lines only                                   | `RECEIPT`, generally without a large banner      |
| Return Lines only                                 | `RETURN RECEIPT`                                 |
| Sale and Return Lines                             | `RECEIPT`, with Return Lines individually marked |
| Full administrative reversal                      | `POST-VOID`                                      |
| Historically retrieved document                   | `REPRINT` modifier                               |
| Historically retrieved original later Post-Voided | `REPRINT` and `VOIDED` modifiers                 |

These are presentation classifications. They do not create separate POS Transaction types.

A mixed sale-and-return Transaction must not be labeled `RETURN RECEIPT` merely because it contains one or more Return Lines.

---

## 6. Common Receipt structure

A Customer Receipt should render sections in this order:

1. Store header;
2. document-status banners;
3. Receipt identity;
4. Transaction context;
5. masked Customer Number, when present;
6. merchandise and Return Lines;
7. totals and tax;
8. Tenders and refund methods;
9. correction references;
10. Receipt barcode and human-readable number;
11. Store footer.

The exact spacing and typography belong to the renderer.

---

## 7. Store header

The Store header may include:

* Store name;
* Organization name;
* Store address;
* phone number;
* website;
* current configured Receipt header;
* logo, where supported.

The MVP Receipt uses current Store configuration at print time.

A later reprint may therefore display a corrected Store address or updated contact information.

The Store header is not a historical legal facsimile of what appeared on the original paper.

---

## 8. Document banners

Banners must be prominent and appear near the top.

Supported banners include:

```text
RETURN RECEIPT
POST-VOID
REPRINT
VOIDED
```

More than one banner may apply.

Examples:

```text
REPRINT
```

```text
REPRINT
VOIDED
```

```text
REPRINT
POST-VOID
```

An ordinary original sale Receipt does not require a `RECEIPT` banner when the document is otherwise clear.

---

## 9. Receipt identity

Required identity fields:

* human-readable Receipt Number;
* completion date and time;
* Register or POS Device label;
* cashier display label;
* Receipt Number barcode.

Example:

```text
Receipt 01-00018425
Jul 27, 2026  3:42 PM
Register 02   Cashier: Jordan
```

The Receipt Number remains the same on every reprint.

A reprint must also display the reprint date and time:

```text
Reprinted Jul 28, 2026  10:16 AM
```

Internal Transaction UUIDs, database IDs, POS Session IDs, and Cash Drawer IDs do not print.

---

## 10. Customer presentation

Where a Customer was attached to the completed Transaction, the Receipt may display the masked Customer Number:

```text
Customer **** 4837
```

The masking format should retain only the final four characters unless the Customer Number format requires another safe convention.

The Receipt does not print:

* full Customer Number;
* Customer name for MVP;
* address;
* phone number;
* email address;
* internal Customer ID.

---

## 11. Merchandise lines

### 11.1 Required line facts

Each completed merchandise or Open-Ring Line should show:

* effective completed description;
* useful completed identifier, where available;
* meaningful Variant or condition description, where available;
* quantity;
* completed selling unit price;
* extended amount;
* Return direction;
* completed Discounts.

Example:

```text
THE LEFT HAND OF DARKNESS
ISBN 9780441478125
1 × $24.99                         $24.99
Member discount                    -$2.50
```

### 11.2 Descriptions

Use the completed Line description snapshot.

Do not retrieve a current Product name when the completed snapshot exists.

Long descriptions may wrap to additional lines.

### 11.3 Identifiers

The Receipt may print a completed:

* ISBN;
* UPC;
* EAN;
* SKU;
* meaningful exact-unit identifier.

Identifiers should print only when useful for customer understanding or future Return lookup.

Internal Product Variant IDs and Inventory Unit database IDs never print.

### 11.4 Quantities

The default format is:

```text
2 × $3.25                           $6.50
```

Quantity and unit price should always print when quantity is greater than one.

A renderer may omit `1 ×` in an especially compact profile, but the standard 80 mm profile should remain consistent and print it.

### 11.5 Amount direction

Stored amounts remain positive internally. Receipt presentation applies customer-facing direction.

Sale Line:

```text
1 × $24.99                         $24.99
```

Return Line:

```text
RETURN
1 × $24.99                        -$24.99
```

---

## 12. Price Overrides

Price Overrides are retained and audited internally but hidden from the customer-facing Receipt.

The completed overridden selling price prints as the item’s ordinary price.

Example completed facts:

```text
Regular price: $24.99
Override selling price: $19.99
```

Customer Receipt:

```text
THE LEFT HAND OF DARKNESS
1 × $19.99                         $19.99
```

The Receipt must not print:

* the original regular price;
* an `Override` label;
* the Override reason;
* the approving User;
* the amount of the Override variance.

Price Override reporting remains separate from customer Receipt presentation.

---

## 13. Discounts

Discounts must appear as explicit reductions.

Examples include:

```text
Member discount                    -$2.50
Promotion                          -$5.00
Coupon                             -$3.00
Employee discount                  -$4.25
```

Discount labels should be customer-friendly.

Internal allocation details do not print. Where one Transaction Discount is allocated across multiple Lines, the Receipt may:

* print each completed Line allocation under the affected Line; or
* show a transaction-level Discount summary when the completed presentation remains mathematically reconcilable.

The chosen presentation must reconcile to the completed Discount total.

### 13.1 Return of a discounted Line

A Return Line should reverse the completed net commercial effect.

Example:

```text
RETURN — THE LEFT HAND OF DARKNESS
1 × $24.99                        -$24.99
Member discount                     $2.50
Net Return                         -$22.49
```

The positive Discount reversal indicates that the original reduction is being reversed as part of the Return calculation.

The renderer may use clearer customer-facing wording where needed, but must preserve the completed mathematics.

---

## 14. Tax presentation

### 14.1 Governing rule

Tax amounts, rates, bases, treatments, and exemption results come from completed Tax Components.

Current Tax services must not recalculate the Transaction.

### 14.2 Tax labels

Customer-facing Tax names may come from current configuration.

Example:

```text
State Tax 6.00%                     $1.74
Food Tax 1.25%                      $0.08
```

If the current Tax configuration is unavailable, use a fallback:

```text
Tax 6.00%                           $1.74
```

### 14.3 Tax markers

Line-level Tax markers are optional for simple Tax configurations.

Where needed, markers should describe completed Tax treatment rather than merely the current Tax Category.

Possible presentation codes:

```text
A  State tax
B  State and food tax
X  Exemption applied
Z  Zero-rated
N  No tax applied
```

The specific legend belongs to Store or jurisdictional presentation policy.

### 14.4 Tax exemptions

Where an exemption was applied, the Receipt may show:

```text
TAX EXEMPT
Certificate **** 4821
Tax                                $0.00
```

Complete certificate numbers should not print unless explicitly required.

---

## 15. Totals

### 15.1 Ordinary sale

```text
Merchandise                       $36.48
Discounts                         -$2.50
Net merchandise                   $33.98
State Tax                          $1.74
Food Tax                           $0.08
TOTAL                             $35.80
```

### 15.2 Return-only Transaction

```text
Returned merchandise             -$24.99
Discount reversal                  $2.50
Net merchandise                  -$22.49
Tax refunded                      -$1.35
REFUND TOTAL                     -$23.84
```

### 15.3 Mixed sale-and-return Transaction

```text
Sales                             $42.00
Discounts                         -$3.00
Returns                          -$14.99
Net merchandise                   $24.01
Tax                                $1.44
TOTAL                             $25.45
```

The Receipt total must equal the completed Transaction net total.

---

## 16. Tender presentation

Each completed Tender prints separately.

Unresolved, removed, `void_required`, or voided Tenders do not appear as settlement on the ordinary customer Receipt.

### 16.1 Cash

```text
Cash tendered                     $40.00
CHANGE                             $4.20
```

ShelfStack may retain amount presented, amount applied, and change internally. The customer Receipt does not need to print `Cash applied`.

### 16.2 Card

```text
Visa **** 4821                    $30.00
```

The Receipt may print:

* captured Card brand;
* masked last four;
* approved amount.

The Receipt does not normally print:

* full terminal reference;
* full authorization metadata;
* full Card number;
* processor claims not captured by ShelfStack.

The standalone terminal may produce a separate processor Receipt.

### 16.3 Stored Value

Redemption:

```text
Gift Card **** 9304               $12.50
Remaining balance                 $14.25
```

Refund:

```text
Refund to Store Credit            $18.75
Account **** 4418
New balance                       $18.75
```

A historical balance must come from the completed Stored-Value posting result, not from a later current Account lookup.

Where that historical post-entry balance is unavailable, omit the balance rather than printing a current value as though it were historical.

### 16.4 Refunded Tenders

Refund Tenders should use positive customer-facing refund amounts even though their direction is distinct internally:

```text
Refund to Visa **** 4821          $23.84
```

---

## 17. Ordinary sale Receipt

An ordinary sale Receipt contains:

* no large document banner;
* positive sale Lines;
* visible Discounts;
* tax;
* total;
* completed received Tenders;
* change where applicable;
* Receipt barcode and human-readable Receipt Number;
* current Store footer.

Example:

```text
             SHELFSTACK BOOKS
        123 Main Street, Anytown
           (555) 555-0142

Receipt 01-00018425
Jul 27, 2026  3:42 PM
Register 02   Cashier: Jordan
Customer **** 4837

THE LEFT HAND OF DARKNESS
ISBN 9780441478125
1 × $24.99                         $24.99
Member discount                    -$2.50

BLUEBERRY SCONE
2 × $3.25                           $6.50

Merchandise                       $31.49
Discounts                         -$2.50
Net merchandise                   $28.99
State Tax                          $1.74
Food Tax                           $0.08
TOTAL                             $30.81

Visa **** 4821                    $25.00
Cash tendered                     $10.00
CHANGE                             $4.19

[Receipt barcode]
01-00018425

Thank you for shopping with us.
```

---

## 18. Return-only Receipt

A completed Transaction containing only Return Lines uses the `RETURN RECEIPT` banner.

Required additions:

* `RETURN RECEIPT`;
* individual returned Lines;
* original Receipt references where available;
* refunded Tax;
* Refund Total;
* completed refunded Tenders.

Example:

```text
*********** RETURN RECEIPT ***********

Receipt 01-00018501
Jul 27, 2026  4:02 PM
Register 02   Cashier: Jordan

THE LEFT HAND OF DARKNESS
Original receipt 01-00017204
1 × $24.99                        -$24.99
Member discount reversal            $2.50

Returned merchandise             -$24.99
Discount reversal                  $2.50
Tax refunded                      -$1.35
REFUND TOTAL                     -$23.84

Refund to Visa **** 4821          $23.84

[Receipt barcode]
01-00018501
```

A Return Receipt receives its own Receipt Number because it represents a newly completed Transaction.

---

## 19. Mixed sale-and-return Receipt

A mixed Transaction uses the ordinary Receipt presentation.

Return Lines are individually marked.

Example:

```text
Receipt 01-00018510
Jul 27, 2026  4:26 PM

NEW BOOK
1 × $18.00                         $18.00

RETURN — USED BOOK
Original receipt 01-00017204
1 × $10.00                        -$10.00

Sales                             $18.00
Returns                          -$10.00
Tax                                $0.48
TOTAL                              $8.48

Cash tendered                     $10.00
CHANGE                             $1.52
```

A mixed Transaction is not labeled `EXCHANGE` for MVP.

---

## 20. Post-Void Receipt

A Post-Void is a new completed reversing Transaction and receives its own Receipt Number.

The customer-facing Post-Void Receipt must show:

* `POST-VOID` banner;
* reversing Receipt Number;
* original Receipt Number;
* original completion timestamp;
* reversal completion timestamp;
* reversing Lines;
* reversed Discounts;
* reversed Tax;
* reversed Tenders;
* relevant Stored-Value effects;
* Receipt barcode.

Example:

```text
************** POST-VOID **************

Receipt 01-00018502
Reverses receipt 01-00018425

Original completed:
Jul 27, 2026  3:42 PM

Reversed:
Jul 27, 2026  4:18 PM

THE LEFT HAND OF DARKNESS
1 × $24.99                        -$24.99
Member discount reversal            $2.50

Tax reversal                      -$1.35
REVERSAL TOTAL                   -$23.84

Card reversal **** 4821           $23.84

[Receipt barcode]
01-00018502
```

### 20.1 Post-Void internal facts

The ordinary customer copy omits:

* internal Post-Void reason;
* authority thresholds;
* approver credentials;
* internal eligibility checks;
* Inventory reversal details;
* Product Request reversal details.

A printable internal Post-Void record may include requester, approver, reason, external Card references, and linked operational facts.

---

## 21. Original Receipt context

The following are original Receipt contexts:

* automatic display or printing immediately after completion;
* printing from the completed Transaction’s Receipt workspace;
* refreshing that Receipt workspace;
* retrying a failed or cancelled browser print from that workspace;
* printing additional copies before leaving the completion workflow.

Multiple original copies may exist.

ShelfStack does not need to know whether the browser actually produced paper.

---

## 22. Reprint context

The following are reprint contexts:

* Receipt Lookup;
* Transaction history;
* Customer history;
* reporting;
* audit or administrative access;
* any later retrieval of a previously completed Transaction.

A reprint must display:

* `REPRINT`;
* original Receipt Number;
* original completion timestamp;
* reprint timestamp.

Example:

```text
**************** REPRINT **************

Receipt 01-00018425
Originally completed Jul 27, 2026 3:42 PM
Reprinted Jul 28, 2026 10:16 AM
```

A reprint does not receive a new Receipt Number and creates no financial activity.

---

## 23. Reprint of a Post-Voided original

When the original Transaction has since been Post-Voided, its reprint must include:

* `REPRINT`;
* `VOIDED`;
* original Receipt Number;
* reversing Receipt Number;
* reversal completion timestamp.

Example:

```text
**************** REPRINT **************
**************** VOIDED ***************

Receipt 01-00018425
Originally completed Jul 27, 2026 3:42 PM

Reversed by receipt 01-00018502
Reversal completed Jul 27, 2026 4:18 PM
```

The original Lines, prices, Discounts, Tax, and Tenders remain displayed as completed on the original Transaction.

They are not replaced by the reversing amounts.

The `VOIDED` notice communicates the current correction relationship without rewriting original history.

---

## 24. Barcode contract

Every Customer Receipt must include:

* a scannable barcode; and
* the Receipt Number in human-readable form.

For MVP, the barcode encodes the Receipt Number used by Receipt Lookup.

Example:

```text
[barcode]
01-00018425
```

The barcode must not encode:

* database IDs;
* private internal UUIDs;
* Customer identity;
* Tender details;
* Stored-Value Account credentials.

A later QR-based lookup mechanism may be added without changing the Receipt Number contract.

---

## 25. Receipt footer

The Receipt uses the current configured Store Receipt footer.

The footer may include:

* thank-you text;
* generic Return instructions;
* website;
* customer-service contact information;
* legal notices.

The footer must not infer historical item eligibility or Return deadlines from current policy.

Acceptable:

```text
Returns are subject to Store policy and
verification of the original Transaction.
```

The Gift Receipt footer is specified separately and is not reused automatically as the Customer Receipt footer.

---

## 26. Information omitted from Customer Receipts

Customer Receipts must not print:

* internal Transaction UUIDs;
* database IDs;
* POS Session IDs;
* Cash Drawer IDs;
* Product or Variant database keys;
* Inventory acquisition cost;
* gross margin;
* Department accounting mappings;
* Price Override reason or authorization;
* pre-override regular price;
* Approval credentials;
* internal Return Disposition;
* full payment-card numbers;
* full Stored-Value Account numbers unless producing a Credit Voucher;
* detailed Tax rounding traces;
* internal Promotion allocation logic;
* Inventory warnings;
* Reservation state;
* internal Post-Void eligibility checks;
* Product Request fulfilment details.

---

## 27. Error handling

Receipt generation or rendering failure must:

* leave the completed Transaction unchanged;
* display an actionable error;
* allow retry;
* avoid consuming another Receipt Number;
* avoid creating another Tender;
* avoid creating another Stored-Value Entry;
* avoid creating another reversing Transaction.

Missing current presentation data should degrade gracefully.

Examples:

* missing Tax name → `Tax 6.00%`;
* missing Tender label → `Card`;
* missing Register display name → stable Device code;
* unsupported character → safe substitution or transliteration.

The Receipt should fail only when authoritative completed facts required for a mathematically valid document are unavailable or inconsistent.

---

## 28. Permissions

Receipt access should distinguish:

* viewing the immediate completed Receipt;
* historical Receipt lookup;
* Receipt reprinting;
* viewing Customer-related Transaction history;
* viewing Post-Void details.

Printing must not expose source data the User is not permitted to view.

The current canonical permission for historical copies should remain the Receipt reprint permission.

---

## 29. MVP implementation contract

The recommended MVP application structure is:

```text
PosPrinting::BuildCustomerReceipt
  input:
    completed_pos_transaction
    document_context: original | reprint

  output:
    PosPrinting::Document
```

The builder owns:

* source validation;
* presentation classification;
* original versus reprint status;
* `VOIDED` state;
* Line direction;
* hidden Price Override presentation;
* Discount presentation;
* Tax and Tender projection;
* barcode value;
* fallback labels.

The renderer owns:

* HTML structure;
* typography;
* spacing;
* 80 mm print layout;
* barcode rendering;
* page-break behavior;
* browser-print controls.

Business semantics must not be embedded independently in each ERB template.

---

## 30. MVP acceptance scenarios

### 30.1 Ordinary sale

Given a completed sale Transaction:

* Receipt Number and completion time print;
* completed Lines print;
* completed selling prices print;
* Discounts print;
* Price Overrides are not identified;
* Tax reconciles;
* Tenders reconcile;
* barcode and human-readable Receipt Number print.

### 30.2 Price Override

Given a Line with a completed Price Override:

* the overridden selling price prints as the ordinary unit price;
* the pre-override price does not print;
* no `Override` label prints;
* any separate Discount still prints.

### 30.3 Discounted sale

Given completed Discount Allocations:

* customer-friendly Discount labels print;
* Discount amounts reconcile to the completed Discount total;
* Receipt total equals completed Transaction total.

### 30.4 Return-only Transaction

Given only completed Return Lines:

* `RETURN RECEIPT` prints;
* original Receipt references print where available;
* returned merchandise and refunded Tax are negative;
* Refund Tenders print;
* the new Return Transaction Receipt Number prints.

### 30.5 Mixed Transaction

Given completed Sale and Return Lines:

* the document remains an ordinary Receipt;
* Return Lines are individually marked;
* Sales, Returns, Tax, and total reconcile;
* only net settlement Tenders print.

### 30.6 Post-Void

Given a completed Post-Void:

* `POST-VOID` prints;
* both original and reversing Receipt Numbers print;
* reversal timestamps print;
* reversing amounts reconcile;
* reversing Tenders print.

### 30.7 Original copy

Given printing from the immediate Receipt workspace:

* no `REPRINT` banner appears;
* refreshing or printing another copy remains original context.

### 30.8 Historical reprint

Given printing after Receipt Lookup or historical retrieval:

* `REPRINT` appears;
* the original Receipt Number remains;
* original and reprint timestamps appear;
* no new financial record is created.

### 30.9 Voided original reprint

Given historical retrieval of a Transaction that has since been Post-Voided:

* `REPRINT` appears;
* `VOIDED` appears;
* the reversing Receipt Number appears;
* the original completed facts remain displayed.

### 30.10 Masked Customer Number

Given an attached Customer:

* only the masked Customer Number prints;
* Customer name and contact information do not print.

### 30.11 Missing current label

Given a removed or unavailable current Tax or Tender label:

* the Receipt uses a safe fallback;
* historical amounts remain printable;
* the Receipt does not invoke current calculation services.

### 30.12 Rendering failure

Given a browser or renderer failure:

* the Transaction remains completed;
* its Receipt Number remains unchanged;
* retry remains possible;
* no additional posting occurs.

---

## 31. MVP boundaries

### Required

* browser-printable HTML;
* ordinary sale Receipt;
* return-only presentation;
* mixed sale-and-return presentation;
* Post-Void Receipt;
* original and reprint context;
* `VOIDED` notice on reversed-original reprints;
* barcode plus human-readable Receipt Number;
* masked Customer Number;
* hidden Price Override presentation;
* visible Discounts;
* Tax and Tender summaries;
* current Store header and footer;
* safe fallback labels.

### Deferred

* managed printer queue;
* direct ESC/POS output;
* physical print-success tracking;
* stored Receipt snapshots;
* stored rendered documents;
* facsimile historical reproduction;
* email or SMS delivery;
* configurable Receipt section ordering;
* QR-based online Receipt portal;
* jurisdiction-specific advanced tax layouts;
* Customer name printing;
* Receipt print-event persistence for browser printing.

---

## 32. Remaining document-specific decisions

The following may be refined during implementation:

1. Exact masking format for Customer Numbers shorter than four characters.

2. Whether the standard Receipt always prints an item identifier or only when configured.

3. Whether transaction-level Discounts print under each allocated Line or in a separate summary.

4. Whether Tax markers print on every Line or only for complex Tax configurations.

5. Whether Post-Void customer and internal copies use separate routes or one permission-aware template.

6. Which Store Receipt elements remain fixed ShelfStack semantics versus configurable Store policy.

These decisions should not change the completed-fact and reconstruction rules established by this specification.

The next planning artifact should be the **fact-source and schema-gap matrix**. That will identify exactly what the present models already support and what small additions are needed before implementation.
