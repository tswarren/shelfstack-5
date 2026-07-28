# POS Printing — Stored-Value Activity Slips and Credit Vouchers

**Status:** Draft
**Scope:** Customer-facing documents generated from Stored-Value Accounts and Ledger Entries
**Parent specification:** [Common Document Contract and Taxonomy](common-document-contract-and-taxonomy.md)
**Related specification:** [Customer Receipts](customer-receipts.md)
**Related domains:** Stored Value, Point of Sale, Authorization

---

## 1. Purpose

This specification defines two distinct Stored-Value documents:

1. **Stored-Value Activity Slip** — an informational record of one completed Stored-Value Ledger Entry.
2. **Credit Voucher** — a bearer instrument containing the redeemable credential for one Stored-Value Account.

The distinction is fundamental:

```text
Activity Slip
→ documents one historical event
→ masks the Account credential
→ shows the historical balance after that event

Credit Voucher
→ represents the Account credential
→ exposes the canonical Account Number
→ shows the current balance at print time
```

Both documents are projections of authoritative Stored-Value records. Printing them does not create, transfer, increase, decrease, suspend, or otherwise modify value.

---

## 2. Stored-Value foundation

ShelfStack supports these Stored-Value Account types:

```text
gift_card
store_credit
trade_credit
```

Every Account has:

* an immutable canonical Account Number;
* an Account Type;
* an active or suspended status;
* a cached current balance;
* an append-only Ledger of Stored-Value Entries.

The Ledger remains authoritative.

The Account’s cached current balance is an operational projection of that Ledger.

---

## 3. Governing rules

1. Activity Slips and Credit Vouchers are separate document types.

2. An Activity Slip is generated from one completed Stored-Value Entry.

3. A Credit Voucher is generated from one Stored-Value Account.

4. Printing does not post another Ledger Entry.

5. Printing multiple Credit Vouchers does not create additional value.

6. Activity Slips mask the Account Number.

7. Activity Slips do not contain a redeemable barcode.

8. Credit Vouchers expose the full canonical Account Number.

9. Credit Vouchers encode the canonical Account Number as an EAN-13 barcode.

10. Alternate identifiers do not print on customer-facing Stored-Value documents.

11. Activity Slips show the historical balance immediately after the selected Entry.

12. Credit Vouchers show the current Account balance at print time.

13. A Voucher’s printed balance does not guarantee that the same balance will remain available later.

14. The current ShelfStack Account balance and status control redemption.

15. Active zero-balance Accounts may be printed as Credit Vouchers.

16. Suspended Accounts may have historical Activity Slips printed.

17. Suspended Accounts may not be printed as ordinary redeemable Credit Vouchers.

18. Original versus reprint status is determined by workflow context.

19. Voucher printing requires dedicated authority because the document exposes a bearer credential.

20. Printer or rendering failure does not alter the Account, Ledger, Transaction, or Tender.

---

# 4. Document taxonomy

## 4.1 Stored-Value Activity Slip

An informational document describing one completed Ledger Entry.

Examples:

* Gift Card issued;
* Gift Card reloaded;
* Gift Card redeemed;
* refund to Store Credit;
* Trade Credit redeemed;
* manual adjustment;
* reversal.

An Activity Slip answers:

> What Stored-Value activity occurred, and what was the balance immediately afterward?

## 4.2 Credit Voucher

A redeemable paper representation of a Stored-Value Account credential.

A Credit Voucher answers:

> Which Stored-Value Account may the bearer present, and what is its current balance?

All supported Account Types may be printed as Credit Vouchers:

* Gift Card;
* Store Credit;
* Trade Credit.

## 4.3 Balance Inquiry Slip

A separate informational balance-only document is deferred.

The Credit Voucher and Activity Slip cover the required MVP use cases.

---

# 5. Common terminology

### Account

A `StoredValueAccount` representing Gift Card, Store Credit, or Trade Credit value.

### Ledger Entry

An append-only `StoredValueEntry` representing one increase, decrease, adjustment, or reversal.

### Canonical Account Number

The immutable ShelfStack-generated namespace-21 EAN-13 identifier.

### Alternate identifier

An optional lookup alias. It is not the canonical Voucher credential and does not print by default.

### Bearer instrument

A document whose possession may permit use of the represented Account credential.

### Historical balance

The Account balance immediately after a selected Ledger Entry.

### Current balance

The authoritative Account balance at the time a Credit Voucher is generated.

---

# 6. Common source records

```text
Stored-Value Account
├── Account Type
├── canonical Account Number
├── status
├── current balance
└── Ledger Entries

Stored-Value Entry
├── Entry Type
├── signed amount
├── posting timestamp
├── related POS Transaction
├── related POS Line
├── related Tender
├── reversing Entry relationship
├── creating User
└── Approval or Adjustment Reason where applicable
```

Current Store presentation configuration may supply:

* Store name;
* Organization name;
* address;
* contact information;
* Receipt header;
* current customer-facing labels;
* document layout;
* fixed or configured footer wording.

---

# 7. Customer-facing Account Type labels

Use the actual Account Type in customer-facing text.

| Stored value type | Customer-facing label |
| ----------------- | --------------------- |
| `gift_card`       | Gift Card             |
| `store_credit`    | Store Credit          |
| `trade_credit`    | Trade Credit          |

Avoid a generic `Stored Value` label where the Account Type is known.

Examples:

```text
GIFT CARD ISSUED
STORE CREDIT REFUND
TRADE CREDIT REDEMPTION
```

A Credit Voucher retains the common document title while identifying the specific Account Type:

```text
CREDIT VOUCHER
Account type: Store Credit
```

---

# 8. Stored-Value Activity Slip

## 8.1 Purpose

An Activity Slip documents one completed Stored-Value Ledger Entry.

It is evidence of an event, not a redeemable credential.

## 8.2 Required content

An Activity Slip must include:

1. Store header;
2. activity-specific title;
3. original or reprint banner where applicable;
4. Entry timestamp;
5. related Receipt Number where applicable;
6. customer-facing Account Type;
7. masked canonical Account Number;
8. activity amount;
9. historical balance immediately after the Entry;
10. current informational footer.

Example:

```text
             SHELFSTACK BOOKS
        123 Main Street, Anytown
           (555) 555-0142

******** STORE CREDIT REFUND ********

Receipt MAIN-000184
Jul 27, 2026  3:42 PM

Account type: Store Credit
Account **** 6789

Refund amount                     $18.75
Balance after refund              $31.20

This slip records completed activity.
The Stored-Value Ledger is authoritative.
```

---

## 8.3 Activity titles

The title should describe both the Account Type and completed activity.

### Issuance

```text
GIFT CARD ISSUED
STORE CREDIT ISSUED
TRADE CREDIT ISSUED
```

### Reload

```text
GIFT CARD RELOAD
STORE CREDIT RELOAD
TRADE CREDIT RELOAD
```

Reload may be uncommon or disallowed for some Account Types under business policy, but the printing contract does not independently determine that policy.

### Redemption

```text
GIFT CARD REDEMPTION
STORE CREDIT REDEMPTION
TRADE CREDIT REDEMPTION
```

### Refund

```text
GIFT CARD REFUND
STORE CREDIT REFUND
TRADE CREDIT REFUND
```

### Manual adjustment

```text
GIFT CARD ADJUSTMENT
STORE CREDIT ADJUSTMENT
TRADE CREDIT ADJUSTMENT
```

### Reversal

```text
GIFT CARD REVERSAL
STORE CREDIT REVERSAL
TRADE CREDIT REVERSAL
```

---

## 8.4 Entry amount presentation

Stored-Value Ledger amounts are signed internally.

Customer-facing Activity Slips should use a positive amount with a directional activity label.

Examples:

```text
Reload amount                     $25.00
```

```text
Redeemed amount                   $12.50
```

```text
Refund amount                     $18.75
```

```text
Adjustment increase                $5.00
```

```text
Adjustment decrease                $5.00
```

```text
Reversed amount                   $25.00
```

Do not rely on a negative sign alone to explain what happened.

---

## 8.5 Masked Account Number

The Activity Slip must mask the canonical Account Number.

Recommended format:

```text
Account **** 6789
```

The Activity Slip must not include:

* full canonical Account Number;
* alternate identifier;
* redeemable barcode;
* QR code that exposes the credential;
* internal Account ID.

The Activity Slip should not become an accidental bearer instrument.

---

## 8.6 Historical balance

The Activity Slip displays the balance immediately after the selected Entry.

Example:

```text
Reload amount                     $25.00
Balance after reload              $42.50
```

A later reprint of the same Activity Slip must continue to show `$42.50`, even if the Account has since been redeemed, reloaded, adjusted, or suspended.

The Activity Slip must not substitute the current Account balance for the historical post-Entry balance.

---

# 9. Deriving balance after Entry

## 9.1 MVP approach

ShelfStack does not need to add `balance_after_cents` to each Stored-Value Entry for MVP.

The historical balance may be derived from the append-only Ledger:

```text
Sum all Entries for the same Account
through and including the selected Entry
```

## 9.2 Deterministic ordering

Use the Account Ledger’s authoritative posting order.

For the current model, the explicit deterministic order should be:

```text
created_at ASC, id ASC
```

The selected Entry is included in the sum.

Recommended service:

```ruby
StoredValue::BalanceAfterEntry.call(entry:)
```

Possible result:

```ruby
StoredValue::BalanceAfterEntry::Result.new(
  entry: entry,
  balance_cents: 4_250
)
```

## 9.3 Restrictions

The derivation must:

* use only persisted Ledger Entries;
* include reversal Entries according to their signed amount;
* avoid the Account’s current balance cache;
* avoid current POS Transaction calculations;
* avoid updating any Ledger or Account record;
* use deterministic ordering;
* be covered by tests for Entries sharing the same timestamp.

## 9.4 Future optimization

A persisted post-Entry balance may be considered later for reporting or high-volume performance.

It is not required for MVP document correctness.

---

# 10. Activity Slip Entry mappings

| Entry Type                   | Amount direction | Suggested title             | Balance label            |
| ---------------------------- | ---------------: | --------------------------- | ------------------------ |
| `issued`                     |         Positive | `[ACCOUNT TYPE] ISSUED`     | Balance after issuance   |
| `reloaded`                   |         Positive | `[ACCOUNT TYPE] RELOAD`     | Balance after reload     |
| `redeemed`                   |         Negative | `[ACCOUNT TYPE] REDEMPTION` | Balance after redemption |
| `refunded`                   |         Positive | `[ACCOUNT TYPE] REFUND`     | Balance after refund     |
| `manual_adjustment` positive |         Positive | `[ACCOUNT TYPE] ADJUSTMENT` | Balance after adjustment |
| `manual_adjustment` negative |         Negative | `[ACCOUNT TYPE] ADJUSTMENT` | Balance after adjustment |
| `reversal`                   |           Either | `[ACCOUNT TYPE] REVERSAL`   | Balance after reversal   |

The title and amount label explain the effect without exposing internal signed-ledger mechanics.

---

# 11. Related Receipt and POS activity

Where an Entry was created through a completed POS Transaction, the Activity Slip should show the related Receipt Number.

Example:

```text
Receipt MAIN-000184
```

The Receipt Number must come from the completed related Transaction.

The Activity Slip does not need to repeat:

* merchandise Lines;
* Transaction subtotal;
* Tax;
* all Tenders;
* Customer identity;
* Return Disposition;
* internal Posting Key.

Where an Entry was created administratively without a POS Transaction, omit the Receipt Number and use the Entry timestamp and masked Account reference.

---

# 12. Manual adjustments

Manual Adjustment Activity Slips may be printed.

The customer-facing version should include:

* Account Type;
* masked Account Number;
* adjustment increase or decrease;
* resulting historical balance;
* timestamp;
* neutral customer-facing description where appropriate.

The customer-facing Activity Slip should normally omit:

* internal Adjustment Reason code;
* authority limits;
* approver credentials;
* Approval PIN;
* internal investigation notes;
* internal Posting Key.

An internal administrative view may display those facts separately.

---

# 13. Reversal Activity Slips

A reversal is a new append-only Ledger Entry.

The reversal Activity Slip should show:

* Account Type;
* masked Account Number;
* reversal amount;
* balance after reversal;
* reversal timestamp;
* related Receipt Number where applicable;
* original activity reference where useful.

Example:

```text
******** GIFT CARD REVERSAL ********

Receipt MAIN-000205
Jul 27, 2026  4:18 PM

Account **** 6789

Reversed amount                   $25.00
Balance after reversal             $0.00
```

Do not edit or replace the original Activity Slip.

A historical reprint of the original Activity Slip may optionally indicate that the Entry was later reversed:

```text
ENTRY REVERSED
Reversed Jul 27, 2026 4:18 PM
```

That indication is a current relationship notice. The original Entry amount and historical post-Entry balance remain unchanged.

---

# 14. Credit Voucher

## 14.1 Purpose

A Credit Voucher is a bearer instrument representing one Stored-Value Account credential.

It may be printed for:

* Gift Card;
* Store Credit;
* Trade Credit.

It intentionally exposes the complete canonical Account Number.

## 14.2 Required content

A Credit Voucher must include:

1. Store header;
2. `CREDIT VOUCHER` title;
3. original or reprint banner where applicable;
4. Account Type;
5. current Account balance;
6. balance-as-of timestamp;
7. full canonical Account Number;
8. EAN-13 barcode;
9. human-readable Account Number;
10. bearer warning;
11. statement that the current ShelfStack balance and status control redemption.

Example:

```text
             SHELFSTACK BOOKS
        123 Main Street, Anytown
           (555) 555-0142

************ CREDIT VOUCHER ***********

Account type: Store Credit

Current balance                   $18.75
Balance as of Jul 27, 2026 4:18 PM

Account 2100123456789

[EAN-13 BARCODE]

2100123456789

Treat this voucher like cash.
Possession may permit use of the associated
Stored-Value Account.

The current ShelfStack balance and Account
status control redemption.
```

---

## 14.3 Canonical credential

The Voucher must print and encode the immutable canonical Account Number.

It must not use the alternate identifier as the primary printed credential.

The human-readable Account Number must appear beneath or immediately adjacent to the barcode.

Example:

```text
[EAN-13 BARCODE]
2100123456789
```

The Voucher must not encode:

* internal database ID;
* Ledger Entry ID;
* POS Transaction UUID;
* Customer ID;
* alternate identifier by default.

---

## 14.4 Barcode

Because the canonical Account Number is a valid EAN-13 identifier, the standard Voucher barcode is EAN-13.

Barcode requirements:

* encode the complete canonical Account Number;
* display the human-readable number;
* fit the configured 80 mm print profile;
* remain clear enough for POS scanning;
* use no additional Gift Receipt-style token;
* use no current-balance information in the barcode.

The barcode identifies the Account, not a printed copy.

---

# 15. Voucher balance semantics

## 15.1 Current balance

A Credit Voucher shows the current Account balance at the time the Voucher is generated.

Example:

```text
Current balance                   $18.75
Balance as of Jul 27, 2026 4:18 PM
```

The balance is sourced from the authoritative current Stored-Value state.

## 15.2 Printed balance is informational

The printed amount does not reserve or guarantee value.

The Account may later be:

* redeemed;
* reloaded;
* adjusted;
* reversed;
* suspended.

Every Voucher must include wording such as:

```text
The current ShelfStack balance and Account
status control redemption.
```

## 15.3 Multiple copies

Multiple printed copies reference the same Account.

Example:

```text
Voucher copy A ─┐
Voucher copy B ─┼─→ Stored-Value Account 2100123456789
Voucher copy C ─┘
```

There is only one authoritative balance.

Printing another copy must not:

* create another Account;
* duplicate the balance;
* post an Entry;
* reserve funds;
* change the Account status.

---

# 16. Zero-balance Accounts

An active Account with a zero balance may be printed as a Credit Voucher.

Example:

```text
Current balance                    $0.00
```

This is permitted because:

* the Account remains valid;
* the Account may later be reloaded;
* the credential remains unchanged;
* zero balance is not the same as suspension.

The Voucher must not imply that positive value is available.

No special `DEPLETED` status is persisted solely for printing.

---

# 17. Suspended Accounts

## 17.1 Activity Slips

Historical Activity Slips may be printed for suspended Accounts.

Where useful, a reprint may include a current-status notice:

```text
ACCOUNT CURRENTLY SUSPENDED
```

This notice must be distinct from the historical Entry facts.

The historical amount and balance after the Entry remain unchanged.

## 17.2 Credit Vouchers

An ordinary redeemable Credit Voucher must not be printed for a suspended Account.

The application should display:

```text
This Stored-Value Account is suspended and
cannot be printed as a redeemable Credit Voucher.
```

Reasons:

* the Account cannot currently be redeemed;
* a newly printed bearer instrument would be misleading;
* a `SUSPENDED` Voucher would create conflicting customer expectations.

## 17.3 Existing paper Vouchers

Existing paper copies cannot be physically recalled.

Redemption remains controlled by the Account’s authoritative current status.

Scanning a Voucher for a suspended Account must not permit redemption.

---

# 18. Original and reprint rules

## 18.1 Original Activity Slip

An Activity Slip is original when printed from the immediate workflow that posted the Entry, including:

* immediate POS completion workspace;
* immediate manual adjustment confirmation;
* retry from the same workflow;
* additional copies before leaving that workflow.

## 18.2 Activity Slip reprint

An Activity Slip is a reprint when printed after retrieving:

* a previous POS Transaction;
* Stored-Value Account history;
* Stored-Value Entry history;
* administrative activity history.

A reprint displays:

```text
REPRINT
```

It retains:

* the original Entry timestamp;
* original Entry amount;
* historical balance after Entry.

It may also display the reprint timestamp.

## 18.3 Original Credit Voucher

A Credit Voucher is original when printed from the immediate workflow associated with:

* Account issuance;
* refund to a new Account;
* immediate Account creation;
* another authorized immediate Stored-Value workflow.

Reload and redemption workflows may offer a Voucher, but a newly printed copy still represents the existing Account rather than the specific Ledger Entry.

## 18.4 Credit Voucher reprint

A Voucher is a reprint when printed from:

* Receipt history;
* Stored-Value Account history;
* Stored-Value administration;
* another later retrieval workflow.

A reprinted Voucher displays:

```text
REPRINT
```

The reprint:

* retains the same Account Number;
* displays the current balance at reprint time;
* displays the current Account status;
* remains a representation of the same bearer credential.

The `REPRINT` marker does not invalidate an active Account.

---

# 19. Relationship to Customer Receipts

The ordinary Customer Receipt and Stored-Value documents serve different purposes.

## 19.1 Issuance

Customer Receipt:

```text
Gift Card                         $25.00
```

Available document actions:

```text
Print Activity Slip
Print Credit Voucher
```

## 19.2 Reload

Customer Receipt:

```text
Gift Card reload                  $25.00
```

Available document actions:

```text
Print Activity Slip
Print Credit Voucher
```

Printing the Voucher is optional because the customer may already possess the original physical credential.

## 19.3 Redemption

Customer Receipt:

```text
Gift Card **** 6789               $12.50
```

Available document action:

```text
Print Activity Slip
```

A Credit Voucher need not be promoted automatically after ordinary redemption, but authorized staff may print one from the Account where appropriate.

## 19.4 Refund to Store Credit

Customer Receipt:

```text
Refund to Store Credit            $18.75
Account **** 6789
```

Available document actions:

```text
Print Activity Slip
Print Credit Voucher
```

The Credit Voucher is particularly important where the Store Credit has no separate physical card.

## 19.5 Post-Void

A Post-Void Receipt may show the Stored-Value reversal effect.

A separate reversal Activity Slip may also be printed for the affected Account.

The Post-Void does not invalidate all prior Vouchers automatically. The Account’s resulting current balance and status remain authoritative.

---

# 20. Immediate workflow actions

The post-completion Receipt workspace should offer Stored-Value actions only where relevant.

Example:

```text
Print Receipt

Stored Value
├── Print Gift Card Activity Slip
├── Print Gift Card Credit Voucher
├── Print Store Credit Activity Slip
└── Print Store Credit Credit Voucher
```

Where multiple Stored-Value Accounts were affected, the User must be able to identify the Account and activity before printing.

The interface should not silently combine unrelated Accounts into one Activity Slip or Voucher.

---

# 21. Historical workflow actions

## 21.1 Transaction history

Where a completed POS Transaction affected Stored Value:

```text
Reprint Receipt
Reprint Stored-Value Activity Slip
Print Current Credit Voucher
```

`Print Current Credit Voucher` is a reprint of the Account credential even though its current balance may differ from the original Transaction.

## 21.2 Account history

A Stored-Value Account page may offer:

```text
Print Credit Voucher
View Activity History
Reprint Activity Slip
```

## 21.3 Entry history

A Stored-Value Entry page may offer:

```text
Reprint Activity Slip
View Related Receipt
View Account
```

A Ledger Entry is not the source of the Voucher. The Account is.

---

# 22. Permissions

Activity Slips and Credit Vouchers should not share identical authority.

Recommended permissions:

```text
stored_value.activity.view
stored_value.activity.print
stored_value.voucher.print
```

At minimum, MVP should establish a dedicated Voucher permission:

```text
stored_value.voucher.print
```

Voucher-print authority is separate because the document exposes a redeemable bearer credential.

## 22.1 Immediate Activity Slip

May be printed by a User authorized to complete or perform the related Stored-Value activity.

## 22.2 Historical Activity Slip

Requires authority to view the Account or Ledger Entry and print Stored-Value activity.

## 22.3 Credit Voucher

Requires:

* access to the Stored-Value Account; and
* `stored_value.voucher.print`.

Ordinary Receipt-reprint permission alone must not authorize Voucher reproduction.

## 22.4 Suspended Account

Even an authorized Voucher printer may not produce an ordinary redeemable Voucher while the Account is suspended.

Administrative override of suspension belongs to the Stored-Value domain, not the printing feature.

---

# 23. Sensitive information

## 23.1 Activity Slip omissions

Activity Slips must not print:

* full Account Number;
* alternate identifier;
* Account database ID;
* full Approval details;
* PINs or credentials;
* authorization limits;
* internal Posting Key;
* internal adjustment codes unless intentionally made customer-facing;
* Customer contact information;
* internal notes.

## 23.2 Credit Voucher omissions

Credit Vouchers must not print:

* alternate identifier by default;
* Account database ID;
* Ledger Entry IDs;
* internal Approval details;
* internal Posting Keys;
* Customer contact information;
* Account ownership claims not supported by the Stored-Value model.

The canonical Account Number is intentionally exposed because the document is a bearer instrument.

---

# 24. Structured document contracts

## 24.1 Activity Slip builder

Recommended service:

```ruby
PosPrinting::BuildStoredValueActivitySlip
```

Input:

```ruby
stored_value_entry:
document_context: :original | :reprint
```

Output:

```ruby
PosPrinting::Document
```

The builder owns:

* source Entry validation;
* Account Type label;
* activity title;
* amount-direction wording;
* masked Account Number;
* historical balance derivation;
* related Receipt Number;
* reversal notice;
* current Account-status notice;
* original/reprint status;
* omission of sensitive information.

## 24.2 Credit Voucher builder

Recommended service:

```ruby
PosPrinting::BuildCreditVoucher
```

Input:

```ruby
stored_value_account:
document_context: :original | :reprint
```

Output:

```ruby
PosPrinting::Document
```

The builder owns:

* Account validation;
* active/suspended eligibility;
* Account Type label;
* current balance;
* balance-as-of timestamp;
* canonical Account Number;
* EAN-13 barcode value;
* original/reprint status;
* bearer warning;
* safe omission of internal information.

---

# 25. Rendering contract

The browser-print renderer owns:

* Store header layout;
* document title and banners;
* amount alignment;
* Account masking;
* EAN-13 barcode rendering;
* human-readable Account Number;
* footer wrapping;
* 80 mm print styling;
* page-break behavior;
* hiding interactive controls during printing.

The renderer must not:

* calculate Account balances;
* choose Account eligibility;
* determine whether an Account is suspended;
* reconstruct Ledger order;
* load unrelated POS commercial data.

Those responsibilities belong to the builders and Stored-Value services.

---

# 26. Barcode failure

## 26.1 Activity Slip

Activity Slips do not require a redeemable barcode.

No barcode failure case applies unless a later non-credential lookup barcode is introduced.

## 26.2 Credit Voucher

A Credit Voucher depends on a scannable Account credential but must also show the full human-readable Account Number.

If barcode generation fails:

* the Voucher may still be displayed;
* the User must receive a visible warning;
* the full Account Number must remain prominent;
* the customer-facing printout need not include a technical error;
* the Account and Ledger remain unchanged.

The Voucher may print with:

```text
ACCOUNT NUMBER
2100123456789
```

However, Store policy may later require successful barcode generation for automatic Voucher printing.

For MVP, manual entry fallback is permitted.

---

# 27. Error handling

Document-generation failure must:

* leave the Account unchanged;
* leave the Ledger unchanged;
* leave the related Transaction unchanged;
* create no new Tender;
* create no new Stored-Value Entry;
* create no duplicate value;
* consume no Receipt Number;
* allow retry.

Examples:

### Missing related Receipt

Omit the Receipt Number and continue when the Entry is otherwise valid.

### Missing current Store phone

Omit the phone number.

### Missing Account Type label mapping

Use:

```text
Stored Value
```

while retaining the internal type for diagnostics.

### Historical balance inconsistency

Do not print an invented balance.

Return a visible error and surface the Ledger inconsistency for investigation.

### Suspended Account Voucher

Do not render an ordinary Voucher. Display an eligibility error.

---

# 28. Data and schema requirements

## 28.1 Existing data is sufficient

No Stored-Value schema addition is required for MVP printing.

Existing facts support:

* Account Type;
* canonical Account Number;
* active/suspended status;
* current balance;
* Entry Type;
* signed Entry amount;
* related POS Transaction;
* related POS Line;
* related Tender;
* reversal relationship;
* Entry timestamp;
* creating User;
* Approval and adjustment context.

## 28.2 No balance snapshot required

Do not add solely for MVP:

```text
stored_value_entries.balance_after_cents
```

Historical balance is derived from the append-only Ledger.

## 28.3 No Voucher persistence required

Do not add:

```text
stored_value_vouchers
stored_value_voucher_numbers
stored_value_voucher_tokens
stored_value_voucher_balances
stored_value_voucher_print_events
```

A Voucher is a presentation of the Account, not a separate value-bearing record.

## 28.4 No duplicate credential fields

Do not copy the Account Number onto a separate Voucher table.

The Account remains the credential authority.

---

# 29. MVP acceptance scenarios

## 29.1 Issuance Activity Slip

Given a completed issuance Entry:

* the appropriate Account Type title prints;
* the Account Number is masked;
* the issued amount prints;
* the historical balance after issuance prints;
* the related Receipt Number prints where available;
* no redeemable barcode prints.

## 29.2 Reload Activity Slip

Given a completed reload Entry:

* reload amount prints;
* historical balance after reload prints;
* a later Account redemption does not change the reprinted historical balance.

## 29.3 Redemption Activity Slip

Given a completed redemption Entry:

* the redeemed amount is described positively;
* the balance after redemption prints;
* the internal negative Ledger sign is not the sole explanation of direction.

## 29.4 Refund Activity Slip

Given a refund to Store Credit:

* `STORE CREDIT REFUND` prints;
* Account Number is masked;
* refund amount prints;
* historical balance after refund prints;
* related Receipt Number prints.

## 29.5 Manual adjustment

Given a completed manual adjustment:

* increase or decrease is clearly described;
* resulting historical balance prints;
* internal Approval credentials do not print.

## 29.6 Reversal

Given a completed reversal Entry:

* reversal title prints;
* reversed amount prints;
* balance after reversal prints;
* original Entry remains unchanged.

## 29.7 Original Activity Slip

Given immediate printing from the posting workflow:

* `REPRINT` does not appear;
* retries and additional copies remain original context.

## 29.8 Historical Activity Slip

Given printing from Account or Entry history:

* `REPRINT` appears;
* original Entry timestamp remains;
* historical balance after Entry remains;
* reprint timestamp may appear.

## 29.9 Credit Voucher

Given an active Stored-Value Account:

* `CREDIT VOUCHER` prints;
* actual Account Type prints;
* full canonical Account Number prints;
* EAN-13 barcode encodes the Account Number;
* current balance prints;
* balance-as-of timestamp prints;
* bearer warning prints.

## 29.10 Voucher copies

Given multiple Voucher prints:

* every copy contains the same Account Number;
* no Ledger Entry is created;
* Account balance is unchanged;
* no additional value is created.

## 29.11 Voucher reprint

Given historical Voucher printing:

* `REPRINT` appears;
* current balance at reprint time prints;
* the original issuance balance is not presented as current;
* the Account Number remains unchanged.

## 29.12 Zero balance

Given an active Account with zero balance:

* Voucher printing is permitted;
* `$0.00` prints;
* the document does not imply that positive value is available.

## 29.13 Suspended Account Activity Slip

Given a suspended Account:

* historical Activity Slips remain printable;
* a current `ACCOUNT CURRENTLY SUSPENDED` notice may print;
* historical Entry facts remain unchanged.

## 29.14 Suspended Account Voucher

Given a suspended Account:

* ordinary Credit Voucher printing is denied;
* no Voucher document is produced;
* no Account or Ledger change occurs.

## 29.15 Alternate identifier

Given an Account with an alternate identifier:

* Activity Slip does not print it;
* Credit Voucher does not print it by default;
* canonical Account Number remains the printed credential.

## 29.16 Permission enforcement

Given a User without Voucher-print authority:

* Activity Slip access follows activity permissions;
* Credit Voucher printing is denied;
* ordinary Receipt-reprint permission does not bypass the restriction.

## 29.17 Historical balance error

Given inconsistent Ledger data:

* Activity Slip generation fails visibly;
* no invented balance prints;
* Account and Ledger records remain unchanged.

---

# 30. MVP boundaries

## Required

* Activity Slip and Credit Voucher as separate documents;
* customer-facing Account Type labels;
* masked Account Number on Activity Slips;
* historical post-Entry balance;
* Ledger-based balance derivation;
* full canonical Account Number on Credit Vouchers;
* EAN-13 Voucher barcode;
* current balance and balance-as-of timestamp;
* bearer warning;
* original/reprint context;
* active zero-balance Voucher support;
* suspended Account Voucher restriction;
* dedicated Voucher-print permission;
* browser-printable HTML;
* 80 mm print styling;
* no Voucher persistence.

## Deferred

* separate Balance Inquiry Slip;
* direct ESC/POS output;
* printer queues;
* email or SMS Voucher delivery;
* online balance portal;
* Voucher cancellation independent of Account suspension;
* historical Voucher facsimiles;
* alternate-identifier printing;
* stored post-Entry balance snapshots;
* physical print-success tracking;
* browser print-event auditing;
* multilingual Voucher templates;
* Store-specific Voucher terms beyond fixed MVP wording.

---

# 31. Resolved decisions

The following decisions are locked for MVP:

1. Activity Slips and Credit Vouchers are distinct documents.
2. Activity Slips represent one Ledger Entry.
3. Activity Slips mask the Account Number.
4. Activity Slips contain no redeemable barcode.
5. Activity Slips show the historical balance immediately after the Entry.
6. Historical post-Entry balance is derived from the append-only Ledger.
7. Credit Vouchers represent the Stored-Value Account.
8. Every supported Account Type may be printed as a Credit Voucher.
9. Credit Vouchers expose the canonical full Account Number.
10. Credit Vouchers use an EAN-13 barcode.
11. Alternate identifiers do not print by default.
12. Credit Vouchers show the current balance at print time.
13. The current ShelfStack balance and status control redemption.
14. Multiple Voucher copies do not create multiple balances.
15. Suspended Accounts may have Activity Slips but not ordinary redeemable Credit Vouchers.
16. Active zero-balance Accounts may have Credit Vouchers.
17. Voucher printing requires dedicated permission.
18. Original and reprint status follow the common workflow-context rule.
19. A separate Balance Inquiry Slip is deferred.
20. No Stored-Value printing table or balance snapshot is required for MVP.
