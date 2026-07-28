# POS Printing — Cash Movement Slips

**Status:** Draft
**Scope:** Internal accountability documents generated from posted POS Cash Movements
**Parent specification:** [Common Document Contract and Taxonomy](common-document-contract-and-taxonomy.md)
**Related domains:** Point of Sale, Cash Accountability, Authorization, Reporting and Reconciliation

---

## 1. Purpose

A Cash Movement Slip documents one completed movement of physical cash into or out of a POS Session or Cash Drawer.

Examples include:

* Paid In;
* Paid Out;
* Cash Drop;
* Till Loan;
* Till Replenishment;
* Safe Deposit;
* Safe Withdrawal;
* other configured Cash Movement Types.

A Cash Movement Slip answers:

> What cash moved, in which direction, for what reason, under whose authority, and who acknowledged custody?

The slip is an internal accountability document. It does not itself post, approve, reconcile, reverse, or transfer cash.

---

## 2. Governing rules

1. Every successfully posted Cash Movement has a printable Cash Movement Slip.

2. A slip is generated from one authoritative Cash Movement record.

3. Printing does not create another Cash Movement.

4. Printer or rendering failure does not reverse or invalidate the posted movement.

5. The slip must clearly identify whether cash moved in or out.

6. The configured Cash Movement Type must print.

7. The amount must print as a positive amount accompanied by an explicit direction.

8. The reason must print where recorded.

9. A required external or operational reference must print.

10. The performing User must print.

11. The approving User must print where approval was required or recorded.

12. Every Cash Movement Slip includes signature fields.

13. Original versus reprint status is determined by workflow context.

14. Historical reprints preserve the original movement facts.

15. Current Store, User, and Cash Movement Type labels may be used for presentation.

16. Current configuration must not alter the original amount, direction, reason, approval, Session, or timestamp.

17. Internal database IDs must not print.

18. A stable public Cash Movement Number should identify the movement.

19. The user-entered `reference` is not a substitute for the generated Cash Movement Number.

20. Corrections must not be performed by editing a previously posted movement or its printed slip.

---

# 3. Source record

The authoritative source is one posted POS Cash Movement.

```text id="bqfs44"
POS Cash Movement
├── Store
├── POS Session
├── Cash Drawer
├── Cash Movement Type
├── amount
├── reason
├── external or operational reference
├── performing User
├── approving User / Approval
├── posting timestamp
└── public Cash Movement Number
```

Current presentation configuration may supply:

* Store name and address;
* current Cash Movement Type name;
* current Register or Device name;
* current User display names;
* document labels;
* print layout.

The slip must not be reconstructed from reporting totals alone.

---

# 4. Cash Movement direction

Direction is supplied by the configured Cash Movement Type.

Supported presentation directions are:

```text id="plz2uc"
CASH IN
CASH OUT
```

The printed amount remains positive.

Correct:

```text id="odf72y"
Direction: CASH OUT
Amount:                       $125.00
```

Avoid relying on:

```text id="xgpwme"
Amount:                      -$125.00
```

A negative sign may be used in a reporting column, but the operational slip must state the physical direction explicitly.

---

# 5. Cash Movement Types

Each configured Cash Movement Type should have:

* stable internal code;
* customer- or staff-facing name;
* physical cash direction;
* Approval requirement;
* reference requirement;
* active state.

The slip prints the current display name and the authoritative recorded direction.

Examples:

| Type               | Direction | Typical purpose                      |
| ------------------ | --------- | ------------------------------------ |
| Paid In            | Cash In   | Miscellaneous cash added to Drawer   |
| Paid Out           | Cash Out  | Approved business expenditure        |
| Cash Drop          | Cash Out  | Excess Drawer cash moved to Safe     |
| Till Loan          | Cash In   | Cash supplied to a Drawer            |
| Till Replenishment | Cash In   | Additional change supplied           |
| Safe Deposit       | Cash Out  | Cash transferred from Drawer to Safe |
| Safe Withdrawal    | Cash In   | Cash transferred from Safe to Drawer |

The printing contract does not independently define which types the Store enables.

---

# 6. Required content

Every Cash Movement Slip must include:

1. Store header;
2. Cash Movement Type title;
3. `CASH IN` or `CASH OUT`;
4. original or reprint banner where applicable;
5. Cash Movement Number;
6. posting date and time;
7. Store;
8. Register or POS Device;
9. POS Session or Cash Drawer context;
10. amount;
11. reason;
12. external or operational reference where present;
13. performing User;
14. approving User where present;
15. signature fields;
16. current fixed footer or accountability wording.

Example:

```text id="r75u5v"
             SHELFSTACK BOOKS
        123 Main Street, Anytown

*************** PAID OUT **************
                CASH OUT

Movement MAIN-CM-000184
Jul 27, 2026  4:32 PM

Register 02
Drawer Front Register
Session opened Jul 27, 2026 9:01 AM

Amount                           $48.75

Reason:
Office supplies

Reference:
Invoice 10482

Recorded by: Jordan
Approved by: Casey

Released by: ______________________

Approved by: ______________________

Received by: ______________________
```

---

# 7. Public Cash Movement identity

## 7.1 Generated number

Every posted Cash Movement should receive a generated public Cash Movement Number.

Recommended format:

```text id="tzk9ux"
MAIN-CM-000184
```

Where:

* `MAIN` is the Store code;
* `CM` identifies a Cash Movement;
* `000184` is the Store-scoped sequence.

## 7.2 Purpose

The generated number supports:

* historical lookup;
* safe verbal and written reference;
* reprinting;
* attachment to envelopes, bags, invoices, or reimbursement records;
* reconciliation investigation;
* future barcode lookup;
* correction references.

## 7.3 Assignment

The Cash Movement Number should be assigned atomically when the Cash Movement is successfully posted.

A failed or rejected movement must not produce a printable Cash Movement Number.

The number:

* is unique within the Store;
* does not reset by Session or Business Day;
* is immutable;
* is not reused;
* remains unchanged on reprint.

## 7.4 Reference is separate

The existing user-entered reference remains a separate business field.

Example:

```text id="9m2d37"
Movement: MAIN-CM-000184
Reference: Invoice 10482
```

The reference may identify:

* invoice;
* receipt;
* deposit bag;
* envelope;
* payee;
* Safe transfer;
* external system record.

It may be blank where the Cash Movement Type does not require one.

---

# 8. Recommended schema additions

Add a Store-scoped sequence:

```ruby id="nl0dc4"
add_column :stores,
           :next_cash_movement_sequence,
           :bigint,
           null: false,
           default: 1
```

Add identity fields to Cash Movements:

```ruby id="x0ga00"
add_column :pos_cash_movements,
           :movement_sequence,
           :bigint

add_column :pos_cash_movements,
           :movement_number,
           :string
```

Add unique indexes:

```ruby id="0xcbjl"
add_index :pos_cash_movements,
          [:store_id, :movement_sequence],
          unique: true,
          where: "movement_sequence IS NOT NULL"

add_index :pos_cash_movements,
          [:store_id, :movement_number],
          unique: true,
          where: "movement_number IS NOT NULL"
```

Add positive sequence constraints where appropriate.

The implementation should follow the existing Store-scoped Receipt and Z-report numbering pattern.

---

# 9. Store header

The slip uses the current Store header.

It may include:

* Store name;
* Organization name;
* Store address;
* phone number;
* Store code;
* current configured Receipt header, if suitable.

A separate Cash Movement header configuration is not required for MVP.

The current Store identity may appear on a later reprint without changing the historical movement facts.

---

# 10. Timestamp

The slip prints the authoritative Cash Movement posting timestamp.

For the current immediate-posting model, this is the movement creation timestamp.

Example:

```text id="a3envd"
Jul 27, 2026  4:32 PM
```

If ShelfStack later distinguishes record creation from posting, the posted or occurred timestamp becomes authoritative.

A reprint also displays the reprint timestamp:

```text id="pt44dv"
Originally posted Jul 27, 2026 4:32 PM
Reprinted Jul 28, 2026 9:16 AM
```

---

# 11. Register, Session, and Drawer context

The slip should identify the physical and operational context.

Recommended presentation:

```text id="p9ak87"
Register 02
Drawer Front Register
Session opened Jul 27, 2026 9:01 AM
```

### Required

* Register or POS Device;
* POS Session.

### Required where applicable

* Cash Drawer.

A Cash Movement associated with a Cash-enabled Session should normally have a Cash Drawer.

Internal Session IDs and Drawer database IDs do not print.

Current display names may be used, falling back to stable codes when needed.

---

# 12. Amount presentation

The amount must be prominent.

Example:

```text id="iz4fin"
Amount                          $125.00
```

The amount:

* comes from the posted Cash Movement;
* is not recalculated from reporting totals;
* is not altered by current Cash Movement Type configuration;
* remains unchanged on reprint.

Direction is communicated separately through `CASH IN` or `CASH OUT`.

---

# 13. Reason

The slip prints the recorded reason.

Example:

```text id="mp1ig3"
Reason:
Emergency purchase of receipt paper
```

The reason should explain why the cash moved.

The reason is distinct from:

* Cash Movement Type;
* external reference;
* Approval reason;
* internal reconciliation note.

Where the movement has no separate reason, the renderer may omit the section rather than print a blank value.

Cash Movement policy may require a reason even when the database does not universally require one.

---

# 14. Reference

The slip prints the user-entered reference when present.

Example:

```text id="wk7g9y"
Reference:
Deposit bag 002841
```

The reference may be required by the configured Cash Movement Type.

The reference must not be confused with the generated Cash Movement Number.

If a configured type requires a reference, the movement should not post without one.

---

# 15. Performing User

The slip identifies the User who posted the movement.

Recommended display precedence:

1. first name, where available;
2. username as fallback.

Example:

```text id="o1mbqg"
Recorded by: Jordan
```

The slip does not print:

* internal User ID;
* User Number unless later required by policy;
* login credentials;
* PIN;
* authority limits.

---

# 16. Approval

Where approval was required or recorded, the slip includes:

* approving User’s customer- or staff-facing display name;
* approval timestamp where useful.

Example:

```text id="tla6u2"
Approved by: Casey
Approved Jul 27, 2026 4:31 PM
```

The slip must not print:

* Approval PIN;
* password;
* authorization limit;
* internal Approval ID;
* requested or approved numeric thresholds unless operationally necessary.

## 16.1 No approval required

Where the Cash Movement Type does not require Approval, the system-fact section may print:

```text id="jtx3zl"
Approval: Not required
```

The physical signature block still includes an Approval or verification line because all Cash Movement Slips require signature fields.

---

# 17. Signature block

Every Cash Movement Slip includes a signature block.

Default:

```text id="dl560f"
Released by: ______________________

Approved by: ______________________

Received by: ______________________
```

These lines provide physical custody evidence and are separate from digitally recorded User and Approval facts.

## 17.1 Label adaptation

Labels may be adapted to the movement type.

### Paid Out

```text id="e2c4rv"
Released by: ______________________
Approved by: ______________________
Received by: ______________________
```

### Paid In

```text id="nmyof4"
Provided by: ______________________
Accepted by: ______________________
Verified by: ______________________
```

### Cash Drop

```text id="h4wjf7"
Released by: ______________________
Verified by: ______________________
Accepted into Safe by: ___________
```

### Till Loan

```text id="kvaftf"
Released by: ______________________
Approved by: ______________________
Accepted by cashier: ______________
```

The renderer may select labels from fixed ShelfStack rules associated with the movement’s direction or Type code.

No configurable signature-template system is required for MVP.

## 17.2 Unused signature role

If a role does not apply, the line should remain present and may be marked:

```text id="kfi5rr"
Approved by: Not required
```

Do not omit the signature section entirely.

---

# 18. Cash Movement variants

## 18.1 Paid Out

Purpose:

* document cash removed to pay an expense or recipient.

Recommended additional facts:

* payee, where represented by the reference or reason;
* invoice or external receipt reference;
* recipient signature.

Example:

```text id="rmxhql"
*************** PAID OUT **************
                CASH OUT

Movement MAIN-CM-000184
Amount                           $48.75

Payee / reference:
Office Supply Company — Invoice 10482

Reason:
Receipt paper and register pens
```

A separate structured Payee field is not required for MVP. The reference and reason may carry this information.

---

## 18.2 Paid In

Purpose:

* document miscellaneous cash added to the Drawer.

Recommended additional facts:

* source;
* related reference;
* provider signature.

Example:

```text id="90k83t"
**************** PAID IN **************
                 CASH IN

Movement MAIN-CM-000185
Amount                          $100.00

Source / reference:
Manager change fund
```

---

## 18.3 Cash Drop

Purpose:

* remove excess cash from a Drawer and place it into a controlled destination.

Recommended additional facts:

* bag or envelope reference;
* destination;
* receiving or verifying signature.

Example:

```text id="j1hct6"
************** CASH DROP **************
                CASH OUT

Movement MAIN-CM-000186
Amount                          $500.00

Reference:
Deposit bag 002841

Reason:
Afternoon Drawer reduction
```

The slip documents the Drawer-side movement.

A future paired Safe-receipt or Bank-deposit workflow may create additional linked records. That is outside this MVP printing specification.

---

## 18.4 Till Loan or Replenishment

Purpose:

* add cash to a Drawer for operational use.

Recommended additional facts:

* source;
* denomination detail where available;
* issuing and receiving signatures.

Example:

```text id="jvx6p9"
*************** TILL LOAN *************
                 CASH IN

Movement MAIN-CM-000187
Amount                          $150.00

Source:
Main Safe

Reason:
Additional small bills and coins
```

Denomination detail is not required unless captured by the movement workflow.

---

## 18.5 Safe transfers

A Cash Movement Type may describe movement between a Drawer and Safe.

The current slip documents the posting associated with the POS Session.

A full chain-of-custody transfer may eventually require:

* paired source and destination records;
* a shared Transfer Number;
* acceptance at the destination;
* discrepancy handling.

That broader transfer workflow is deferred.

The MVP must not imply a completed two-sided transfer when ShelfStack has recorded only one Cash Movement.

---

# 19. Original Cash Movement Slip

A slip is original when printed from the immediate confirmation workflow after the movement posts.

Original context includes:

* automatic print initiation after posting;
* selecting `Print Cash Movement Slip` from the immediate confirmation;
* refreshing the confirmation;
* retrying a cancelled or failed browser print;
* printing additional copies before leaving that workflow.

Multiple original copies may exist.

Original copies do not display `REPRINT`.

---

# 20. Cash Movement reprint

A slip is a reprint when printed after retrieving the movement through:

* Cash Movement history;
* POS Session history;
* Business-Day activity;
* reporting;
* audit or administrative access.

A reprint must include:

* `REPRINT`;
* original Cash Movement Number;
* original posting timestamp;
* reprint timestamp.

Example:

```text id="b2jdet"
**************** REPRINT **************

Movement MAIN-CM-000184
Originally posted Jul 27, 2026 4:32 PM
Reprinted Jul 28, 2026 9:16 AM
```

The movement amount, direction, reason, reference, User, and Approval remain unchanged.

A reprint creates no Cash Movement and changes no accountability total.

---

# 21. Server-owned print context

Original versus reprint status must not be controlled solely by a user-editable parameter.

Recommended route separation:

```text id="g3ighr"
GET /pos_cash_movements/:id/slip
  immediate original context only

GET /pos_cash_movements/:id/slip/reprint
  historical reprint context
```

The immediate route verifies:

* the movement was successfully posted;
* the current User has access;
* the movement matches the trusted immediate-posting context.

The historical route:

* requires Cash Movement history or reprint authority;
* always displays `REPRINT`;
* ignores attempts to suppress the marker.

---

# 22. Workflow entry points

## 22.1 Posting workflow

After a movement posts:

```text id="or4v0l"
Cash Movement posted

Movement MAIN-CM-000184
Paid Out · $48.75

Print Cash Movement Slip
Return to Register
```

Every Cash Movement Type receives the same confirmation pattern.

Whether the browser print dialog opens automatically may be settled as a Store UX preference later.

MVP requires an immediate print action, not confirmed physical output.

## 22.2 Historical workflow

Cash Movement history may offer:

```text id="hwxcxh"
View Movement
Reprint Cash Movement Slip
View POS Session
View Approval
```

---

# 23. Permissions

Recommended permission areas:

```text id="139ddh"
pos.cash_movement.create
pos.cash_movement.view
pos.cash_movement.reprint
```

Existing permission names may be reused where equivalent.

## 23.1 Original slip

The User who successfully posts a movement may print the immediate original slip.

## 23.2 Historical reprint

Historical reprint requires authority to view the Cash Movement and reproduce accountability documents.

## 23.3 Approval details

A User may print the ordinary slip without access to sensitive Approval internals.

Only the approving User’s display label and approval timestamp appear.

## 23.4 Reporting access

Access to an X or Z report does not automatically grant access to every detailed Cash Movement Slip unless the User can view the underlying movements.

---

# 24. Corrections

A previously posted Cash Movement and its slip must not be edited to change:

* amount;
* direction;
* Type;
* reason;
* reference;
* performing User;
* Approval;
* timestamp.

If correction is required, ShelfStack should use a separate compensating or reversing Cash Movement with an explicit reference to the original.

A future correction workflow should support:

```text id="34tb8x"
Original movement MAIN-CM-000184
Corrected by movement MAIN-CM-000191
```

The correction relationship and exact schema are outside this printing specification.

A historical reprint of a corrected movement should eventually display a prominent correction notice, following the same principle used for Post-Voided Transactions.

Until Cash Movement correction is implemented, the slip must not imply that posted movements are editable.

---

# 25. Barcode

## 25.1 MVP requirement

A human-readable Cash Movement Number is required.

A barcode is optional for the initial MVP.

## 25.2 Later barcode support

Once Cash Movement lookup accepts scanning, a Code 128 barcode may encode the Movement Number:

```text id="6zo8jr"
[Code 128 barcode]
MAIN-CM-000184
```

The barcode must not encode:

* database ID;
* Approval credential;
* User identity;
* amount;
* reason;
* Cash Drawer ID.

Deferring the barcode does not affect the public-number contract.

---

# 26. Footer

The MVP may use fixed accountability wording:

```text id="fjcq93"
This slip documents a posted Cash Movement.
ShelfStack records and Session accountability
remain authoritative.
```

A dedicated configurable Cash Movement footer is not required.

The signature block follows the footer or appears immediately before it, depending on available paper space.

---

# 27. Sensitive information

Cash Movement Slips must not print:

* internal database IDs;
* POS Session database ID;
* Cash Drawer database ID;
* Approval PIN;
* User password or PIN;
* authority thresholds;
* authorization-limit snapshots;
* internal audit metadata;
* reconciliation-only notes;
* unrelated Session totals;
* expected Drawer balance;
* Customer information;
* Product, Tax, Tender, or Inventory details.

The slip may print the name of an approving User because that is part of its accountability purpose.

---

# 28. Structured document contract

Recommended builder:

```ruby id="q3lcy1"
PosPrinting::BuildCashMovementSlip
```

Input:

```ruby id="vb3bih"
pos_cash_movement:
document_context: :original | :reprint
```

Output:

```ruby id="i0x1z9"
PosPrinting::Document
```

The builder owns:

* source validation;
* public Movement Number;
* Movement Type label;
* direction;
* amount;
* Store, Register, Session, and Drawer context;
* reason;
* external reference;
* performing and approving User labels;
* original/reprint status;
* signature-label selection;
* omission of sensitive information.

The renderer owns:

* typography;
* spacing;
* amount alignment;
* signature lines;
* 80 mm print layout;
* browser-print controls;
* page-break handling.

---

# 29. Error handling

Cash Movement Slip generation failure must:

* leave the movement unchanged;
* leave Session cash accountability unchanged;
* create no additional movement;
* consume no additional Movement Number;
* permit retry;
* display an actionable error.

Examples:

### Missing Register name

Use the stable POS Device code.

### Missing Cash Drawer name

Use the stable Cash Drawer code or omit the Drawer row if the movement legitimately has none.

### Missing current Movement Type name

Use a safe label derived from the stable Type code.

### Missing Approval

If Approval was required but no valid Approval is associated, treat this as a source-record inconsistency rather than printing `Approved`.

### Rendering failure

The movement remains posted and historically retrievable.

---

# 30. Data and schema requirements

## 30.1 Recommended additions

```text id="2oswzn"
stores.next_cash_movement_sequence
pos_cash_movements.movement_sequence
pos_cash_movements.movement_number
```

## 30.2 Existing facts are otherwise sufficient

The current Cash Movement and related records already provide:

* Store;
* POS Session;
* Cash Drawer;
* Movement Type;
* direction through Movement Type;
* amount;
* reason;
* reference;
* performing User;
* approving User or Approval;
* posting timestamp.

## 30.3 No print table required

Do not add:

```text id="2f28oy"
cash_movement_slips
cash_movement_print_events
cash_movement_signature_records
cash_movement_rendered_documents
```

Physical signatures remain on the printed slip for MVP.

If ShelfStack later needs to capture signed forms electronically, that should be specified as a document-retention or attachment capability rather than hidden inside print events.

---

# 31. MVP acceptance scenarios

## 31.1 Paid Out

Given a successfully posted Paid Out:

* `PAID OUT` prints;
* `CASH OUT` prints;
* public Movement Number prints;
* amount prints as positive;
* reason and reference print;
* performing and approving Users print;
* signature fields print.

## 31.2 Paid In

Given a successfully posted Paid In:

* `PAID IN` prints;
* `CASH IN` prints;
* source or reference prints where available;
* signature fields print.

## 31.3 Cash Drop

Given a Cash Drop:

* `CASH DROP` and `CASH OUT` print;
* bag or envelope reference prints where captured;
* Safe or destination wording does not imply a paired destination posting unless one exists.

## 31.4 Till Loan

Given a Till Loan:

* `TILL LOAN` and `CASH IN` print;
* source prints where captured;
* issuing and receiving signature lines print.

## 31.5 All types

Given any active configured Cash Movement Type:

* a successfully posted movement has a printable slip;
* no Type is excluded solely because a specialized template does not exist;
* the common slip layout provides safe fallback presentation.

## 31.6 Approval required

Given a Type requiring Approval:

* movement does not post without valid Approval;
* approving User prints;
* Approval credential does not print.

## 31.7 Approval not required

Given a Type not requiring Approval:

* slip remains printable;
* signature section remains present;
* the system-fact section may state `Approval: Not required`.

## 31.8 Reference required

Given a Type requiring a reference:

* movement does not post with a blank reference;
* the completed reference prints.

## 31.9 Original slip

Given immediate printing from the posting confirmation:

* `REPRINT` does not appear;
* retries and additional copies remain original context.

## 31.10 Historical reprint

Given printing from Cash Movement history:

* `REPRINT` appears;
* original Movement Number remains;
* original and reprint timestamps appear;
* no Cash Movement is created.

## 31.11 Number assignment

Given a successful movement:

* a Store-scoped Movement Number is assigned atomically;
* the number is unique;
* it never changes.

Given a failed posting:

* no printable Movement Number is assigned;
* no movement effect is recorded.

## 31.12 Current labels

Given a renamed Register, User, or Cash Movement Type:

* later reprints may use the current display label;
* amount, direction, reason, reference, Approval relationship, and timestamp remain historical.

## 31.13 Rendering failure

Given a rendering or browser-print failure:

* movement remains posted;
* accountability totals remain correct;
* retry remains possible;
* no duplicate movement is created.

---

# 32. MVP boundaries

## Required

* printable slip for every Cash Movement Type;
* explicit `CASH IN` or `CASH OUT`;
* prominent amount;
* public Cash Movement Number;
* Store, Register, Session, and Drawer context;
* reason and reference;
* performing User;
* approving User where applicable;
* signature fields on every slip;
* original/reprint context;
* browser-printable HTML;
* 80 mm print styling;
* no print-event persistence.

## Deferred

* paired Cash transfer workflow;
* Safe-side acceptance records;
* electronic signature capture;
* scanned signed-slip retention;
* barcode-based movement lookup;
* direct ESC/POS printing;
* managed printer queues;
* configurable signature layouts;
* configurable Cash Movement footers;
* movement correction implementation;
* automatic browser-print policy;
* physical print-success tracking.

---

# 33. Proposed MVP decisions

The following should be locked:

1. Every posted Cash Movement has a printable slip.

2. Every Cash Movement Slip contains signature fields.

3. Cash direction is explicit and the amount prints as positive.

4. Each movement receives an immutable Store-scoped Cash Movement Number.

5. The generated Movement Number is separate from the user-entered reference.

6. The Movement Number is assigned only when posting succeeds.

7. Original and reprint status follows trusted workflow context.

8. Historical reprints retain the original Movement Number and posting facts.

9. All active Cash Movement Types use the common slip contract.

10. Movement-specific layouts may adapt signature labels without requiring separate document models.

11. Current labels may change on reprint, but historical movement facts do not.

12. Corrections use separate future compensating records rather than editing posted movements.

13. A Cash Movement barcode is deferred until scan-based lookup exists.

14. No Cash Movement print-event or rendered-document table is required for MVP.

15. A dedicated configurable Cash Movement footer is not required for MVP.
