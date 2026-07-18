# ShelfStack System Invariants

**Status:** Governing architectural reference
**Purpose:** Collect the cross-domain rules that must remain true throughout ShelfStack
**Applies to:** Domain Specifications, schema design, migrations, application services, tests, reports, and operational corrections

**Related documentation:**

* [System Overview](system-overview.md)
* [Domain Map](domain-map.md)
* [Architectural Decision Records](../adr/README.md)
* [Domain Specifications](../domains/README.md)
* [Glossary](../glossary.md)
* [Schema Documentation](../schema/README.md)

---

## 1. Purpose

An invariant is a condition that must remain true regardless of:

* user interface;
* workflow entry point;
* application service;
* background processing;
* import;
* API;
* correction;
* concurrency;
* current configuration.

Invariants protect the consistency of ShelfStack’s:

* identity;
* inventory;
* money;
* tax;
* stored-value liability;
* authorization;
* audit history;
* reporting.

This document collects the system-wide invariants established by accepted Architectural Decision Records and the System Overview.

Domain Specifications may define additional local invariants, but they must not contradict this document.

---

## 2. Interpretation

The terms **must**, **must not**, **may**, and **should** are normative.

* **Must** — required for system correctness.
* **Must not** — prohibited.
* **May** — permitted but not required.
* **Should** — expected unless a documented exception applies.

Each invariant has a stable identifier such as:

```text
INV-CAT-001
```

Invariant identifiers should not be renumbered after they are referenced by:

* code comments;
* tests;
* migrations;
* issues;
* pull requests;
* schema documentation.

When an invariant is superseded, retain its identifier and mark it as superseded rather than reusing it.

---

## 3. Enforcement model

Not every invariant is enforced in the same layer.

### 3.1 Database enforcement

Use database constraints where the rule can be expressed reliably through:

* `NOT NULL`;
* unique indexes;
* foreign keys;
* check constraints;
* exclusion constraints;
* partial indexes;
* transaction-level locking.

Examples include:

* one Stock Balance per Store and Product Variant;
* unique Product Variant SKU;
* unique Inventory Unit Identifier;
* one active Reservation per Inventory Unit;
* one open Business Day per Store.

### 3.2 Application-service enforcement

Use application services for rules involving:

* several records;
* several Domains;
* external policy;
* calculations;
* state transitions;
* historical snapshots;
* Approval;
* atomic posting.

Examples include:

* POS Completion;
* Receipt posting;
* Stored-Value redemption;
* Product Request fulfilment;
* Post-Void processing.

### 3.3 Validation and policy enforcement

Use application validation for contextual rules that may produce:

* warnings;
* blockers;
* Approval requirements;
* user-correctable errors.

Examples include:

* missing cost warning;
* negative inventory warning;
* missing Department blocker;
* insufficient Authority Limit;
* invalid identifier checksum warning.

### 3.4 Audit and reconciliation enforcement

Some rules cannot be prevented completely, especially where external systems are involved.

ShelfStack must make exceptions visible through:

* audit records;
* exception reports;
* Reconciliation;
* corrective records;
* documented reasons.

---

# 4. Organization and Store invariants

## INV-ORG-001 — One operating Organization per installation

One ShelfStack installation represents one operating Organization.

The initial architecture does not require general-purpose multi-tenancy within one installation.

Enforcement:

* application validation rejects creating a second Organization;
* a unique database index on a constant expression allows at most one `organizations` row;
* `shelfstack:bootstrap` aborts when an Organization already exists under a different code.

## INV-ORG-002 — Store belongs to one Organization

Every Store belongs to exactly one Organization.

## INV-ORG-003 — Store is the operational boundary

Store-scoped operational records must explicitly identify the applicable Store.

This includes:

* inventory;
* purchasing destination;
* Receiving;
* Business Days;
* POS Sessions;
* POS Transactions;
* Receipt Numbers;
* tax rules;
* cash accountability;
* Reconciliation.

## INV-ORG-004 — Shared configuration does not imply shared operations

Organization-level Products and configuration may be shared across Stores.

Physical inventory and Store operations remain Store-specific.

## INV-ORG-005 — Deactivation preserves history

Deactivating an Organization-level or Store-level master record must not break historical references or reporting.

---

# 5. User, access, and authorization invariants

## INV-AUTH-001 — Store access requires Store Membership

A User may act at a Store only through an effective active Store Membership.

## INV-AUTH-002 — Default Store does not grant access

A User’s default Store is a navigation preference and must not substitute for Store Membership.

## INV-AUTH-003 — Permissions are evaluated in Store context

A Permission check must use the User’s effective Store Membership for the Store in which the action occurs.

## INV-AUTH-004 — Role names do not control behavior

Application logic must not authorize actions by testing user-facing Role names such as `Manager` or `Cashier`.

Application logic must evaluate Permissions and Authority Limits.

## INV-AUTH-005 — Permission and numeric authority are separate

Possessing a Permission does not imply unlimited monetary or percentage authority.

Where a numeric limit applies, both must be satisfied:

```text
required Permission
AND
sufficient Authority Limit
```

## INV-AUTH-006 — Approval is an independent record

A restricted action requiring Approval must create an auditable Approval record.

The Approval must retain:

* requesting User;
* approving User;
* Store;
* action type;
* affected record;
* reason;
* requested value;
* approved value;
* applicable authority context;
* approval timestamp.

## INV-AUTH-007 — Approver uses their own credentials

An approving User must authenticate using their own credentials.

One User must not enter another User’s credentials on their behalf.

## INV-AUTH-008 — Performing identity is retained

Every material operational action must retain the actual performing User and Store context.

## INV-AUTH-009 — Historical identity survives deactivation

Deactivating a User, Role, Store Membership, Device, or Cash Drawer must not remove or reassign historical activity.

## INV-AUTH-010 — Device belongs to one Store

Every active POS Device belongs to exactly one Store.

A POS Device must not operate against another Store’s Business Day.

## INV-AUTH-011 — Drawer belongs to one Store

Every Cash Drawer belongs to exactly one Store.

## INV-AUTH-012 — One active cash-enabled session per Drawer

A Cash Drawer may have at most one active cash-enabled POS Session.

A card-only POS Session may have no Cash Drawer.

---

# 6. Product and Catalog invariants

## INV-CAT-001 — Product, Product Variant, and Inventory Unit are distinct

ShelfStack must preserve the hierarchy:

```text
Product
└── Product Variant
    └── Inventory Unit, when individual tracking applies
```

These records are not interchangeable.

## INV-CAT-002 — Product is not sold directly

An ordinary Product sale must resolve an exact Product Variant before Completion.

## INV-CAT-003 — Every sellable Product has a Variant

Every sellable Product must have at least one active sellable Product Variant.

A Product without meaningful options still receives one standard Product Variant.

## INV-CAT-004 — Variant belongs to one Product

Every Product Variant belongs to exactly one Product.

## INV-CAT-005 — Tracking mode belongs to the Variant

Every Product Variant declares exactly one Inventory-Tracking Mode:

```text
quantity
individual
none
```

Inventory-Tracking Mode must not be inferred solely from Product Type, Merchandise Class, Department, or Format.

## INV-CAT-006 — Quantity tracking does not create one Unit per copy

Quantity-tracked merchandise must use a Store-and-Variant Stock Balance.

ShelfStack must not create one Inventory Unit for each interchangeable copy.

## INV-CAT-007 — Individual tracking requires exact Unit identity

An individually tracked sale must identify the exact Inventory Unit being sold.

## INV-CAT-008 — Non-inventory Variants create no stock effects

A Product Variant using tracking mode `none` must not create:

* Stock Balances;
* Inventory Reservations;
* Inventory Movements;
* Inventory Units.

## INV-CAT-009 — Active and Sellable are distinct

A Product or Product Variant may be active without being sellable.

Sale eligibility must evaluate both states.

## INV-CAT-010 — Sellable and Purchasable are distinct

A Product Variant’s sellability must not automatically determine its purchasability, or vice versa.

## INV-CAT-011 — Missing normal price blocks Completion

An ordinary Product line must not complete without a resolved Selling Price.

ShelfStack must not silently assign a zero price.

An Open-Ring Line is a separate authorized workflow.

## INV-CAT-012 — Current Catalog does not define completed history

Changes to current Product or Product Variant data must not rewrite completed operational records.

---

# 7. Identifier invariants

## INV-ID-001 — Product has one canonical identifier

Every Product has exactly one canonical primary identifier.

## INV-ID-002 — Canonical Product identifiers are unique

Canonical Product identifiers must be unique within the Organization.

## INV-ID-003 — Valid ISBN-10 normalizes to ISBN-13

A valid ISBN-10 input must be converted to its canonical ISBN-13 representation for storage and lookup.

ISBN-10 must not be stored as the Alternate Identifier merely to support ISBN-10 search.

## INV-ID-004 — Invalid ISBN-10 is not silently converted

An invalid ISBN-10-shaped value must not be converted into a different valid-looking ISBN-13.

## INV-ID-005 — UPC-A and leading-zero EAN may resolve together

ShelfStack may treat a UPC-A and its equivalent leading-zero EAN-13 representation as the same Product identifier.

Leading zeroes must be preserved.

## INV-ID-006 — Generated identifiers use assigned namespaces

ShelfStack-generated EAN-13 identifiers use:

```text
21 — Stored-Value Account
27 — Inventory Unit
28 — Product Variant
29 — locally identified Product
```

## INV-ID-007 — Generated identifiers are immutable

Generated identifiers must be:

* Organization-wide;
* unique;
* immutable;
* never reused;
* checksum-valid;
* scannable.

## INV-ID-008 — Identifiers do not encode mutable meaning

Generated identifiers must not encode:

* Store;
* Department;
* Merchandise Class;
* Condition;
* cost;
* price;
* date;
* balance;
* status;
* parent relationship.

## INV-ID-009 — Every Product Variant has one SKU

Every Product Variant has exactly one generated `28` EAN-13 SKU.

## INV-ID-010 — Every Inventory Unit has one Unit Identifier

Every Inventory Unit has exactly one generated `27` EAN-13 Unit Identifier.

The field must not be called `sku`.

## INV-ID-011 — Stored-Value Account has one canonical Account Number

Every Stored-Value Account has exactly one canonical `21` EAN-13 Account Number.

An Alternate Identifier may resolve the same account but does not replace its canonical identity.

## INV-ID-012 — Checksum warning is distinct from identity uniqueness

Checksum validity may produce a warning.

Presence and uniqueness remain separate requirements.

---

# 8. Classification and configuration invariants

## INV-CLS-001 — One Merchandise-Class hierarchy

ShelfStack uses one hierarchical Merchandise Class structure for:

* merchandising;
* shelving;
* browsing;
* buyer organization;
* category reporting;
* default Department resolution.

A separate Display Category hierarchy must not be introduced without a superseding ADR.

## INV-CLS-002 — Merchandise Class and Department remain distinct

Merchandise Class describes merchandising and classification.

Department describes broad financial and managerial treatment.

One must not replace the other.

## INV-CLS-003 — Merchandise Class may provide a Department default

A Merchandise Class may resolve a default Department.

The resolved Department remains a separate classification.

## INV-CLS-004 — Department does not determine tracking mode

Department must not determine Inventory-Tracking Mode.

One Department may contain:

* quantity-tracked merchandise;
* individually tracked merchandise;
* non-inventory services.

## INV-CLS-005 — Product Type is descriptive

Product Type may guide:

* forms;
* search;
* metadata;
* import behavior;
* reporting.

Product Type must not directly hard-code:

* tax;
* Inventory-Tracking Mode;
* Department;
* Return Policy;
* Discount eligibility;
* cost behavior.

## INV-CLS-006 — Temporary placement does not change inventory ownership

Temporary merchandising placement must not change:

* Store ownership;
* On Hand;
* Stock Balance;
* Inventory Unit Store assignment.

## INV-CLS-007 — Completed ordinary lines resolve a Department

Every completed ordinary merchandise or service POS Line Item must have one resolved Department.

## INV-CLS-008 — Completed taxable or exempt lines resolve a Tax Category

Every completed taxable or exempt POS Line Item must have one resolved Tax Category.

## INV-CLS-009 — Tax Category is distinct from Tax Rate

Tax Category describes what is sold.

Tax Rate and Tax Rule determine the Store- and date-specific calculation.

## INV-CLS-010 — Current classification does not rewrite history

Changing a Merchandise Class, Department, Tax Category, or policy assignment affects future activity only.

Completed records retain historical snapshots.

---

# 9. Product Request invariants

## INV-REQ-001 — Product Request represents demand

A Product Request records demand the Store may attempt to fulfil.

It does not represent physical or expected supply.

## INV-REQ-002 — Customer Request and Staff Suggestion are distinct request types

A Customer Request creates an intended customer-fulfilment workflow.

A Staff Suggestion creates a purchasing recommendation without a customer obligation.

## INV-REQ-003 — Request is not a Reservation

A Product Request must not itself reduce Available inventory.

## INV-REQ-004 — Request is not a Purchase Order

Creating a Product Request must not create On Order unless a Purchase Order is separately created or updated.

## INV-REQ-005 — In-house fulfilment requires physical confirmation

In-house merchandise must be physically located and confirmed before an Inventory Reservation is created for a Customer Request.

## INV-REQ-006 — Future fulfilment uses Purchase-Order Allocation

Expected incoming merchandise committed to a Customer Request must be represented by a Purchase-Order Allocation.

It must not be represented as physical Reserved inventory.

## INV-REQ-007 — Staff Suggestion does not ordinarily reserve supply

A Staff Suggestion must not ordinarily:

* reserve current inventory;
* commit expected inventory to a customer;
* create a customer obligation.

## INV-REQ-008 — Unfulfilled quantity is derived

The remaining quantity requiring buyer action is:

```text
requested quantity
- active confirmed Inventory Reservations
- active Purchase-Order Allocations
= unfulfilled request quantity
```

## INV-REQ-009 — Request fulfilment cannot exceed requested quantity

Active Reservations and active Purchase-Order Allocations associated with a request must not exceed the requested quantity unless an explicit authorized quantity change is recorded.

---

# 10. Vendor and Purchasing invariants

## INV-PUR-001 — Purchase Order belongs to one receiving Store

Every Purchase Order identifies exactly one Store that will receive and own the resulting inventory.

## INV-PUR-002 — Purchase Order normally belongs to one Vendor

An ordinary Purchase Order identifies one Vendor.

## INV-PUR-003 — Purchase-Order Line identifies one Variant

An ordinary Purchase-Order Line identifies exactly one Product Variant.

## INV-PUR-004 — Purchasing does not change On Hand

Creating, editing, placing, closing, or cancelling a Purchase Order must not directly change On Hand inventory.

## INV-PUR-005 — Open ordered quantity contributes to On Order

On Order is based on expected quantity not yet accepted or cancelled.

A baseline relationship is:

```text
on_order =
ordered quantity
- accepted received quantity
- cancelled quantity
```

Any later backorder treatment must preserve the distinction between expected and physical supply.

## INV-PUR-006 — On Order is not inventory value

On-Order quantity must not:

* increase On Hand;
* increase Available;
* create inventory value;
* create COGS.

## INV-PUR-007 — Purchase-Order Allocation does not exceed open supply

The sum of active Purchase-Order Allocations on a Purchase-Order Line must not exceed its unallocated open quantity.

## INV-PUR-008 — Historical Purchase Orders retain snapshots

Purchase-Order Lines must retain enough historical information to remain understandable after current Product, Variant, Vendor, or Vendor Source data changes.

## INV-PUR-009 — Closed or cancelled orders do not accept ordinary new fulfilment

A closed or cancelled Purchase Order must not receive ordinary new activity without an explicit authorized reopening or correction workflow.

The exact reopening workflow remains open.

---

# 11. Receiving invariants

## INV-REC-001 — Receipt represents one Vendor shipment or receiving event

A Receipt header identifies one Store, one Vendor, and one shipment or receiving event.

## INV-REC-002 — Receipt is not restricted to one Purchase Order

One Receipt may contain Receipt Lines associated with several Purchase Orders.

## INV-REC-003 — PO relationship occurs at Receipt-Line level

A Receipt must not require a header-level `purchase_order_id`.

Each Receipt Line may reference one Purchase-Order Line in the initial model.

## INV-REC-004 — One Receipt Line links to at most one PO Line

A Receipt Line may reference no more than one Purchase-Order Line under the initial architecture.

When one delivered quantity fulfils several Purchase-Order Lines, separate Receipt Lines may be created.

## INV-REC-005 — Unlinked Receipt Line requires an authorized workflow

A Receipt Line may remain unlinked only where receiving without a prior Purchase-Order Line is permitted.

## INV-REC-006 — Only accepted quantity creates inventory

Delivered or rejected quantity must not increase inventory unless it is explicitly accepted.

## INV-REC-007 — Rejected quantity does not increase On Hand

Rejected receiving quantity must not create:

* On Hand;
* Inventory Units;
* inventory value.

## INV-REC-008 — Accepted unavailable merchandise remains On Hand

Accepted merchandise assigned to inspection, damaged, RTV, quarantine, or another unavailable status remains part of On Hand.

## INV-REC-009 — Posted Receipt is not edited to change inventory history

After a Receipt has posted inventory effects, corrections must use explicit corrective records or reversing Inventory Movements.

## INV-REC-010 — Receipt posting and inventory posting agree

A posted accepted Receipt quantity must have corresponding Inventory Movements.

Inventory Movements sourced from a Receipt must reconcile to its accepted posted quantity.

---

# 12. Inventory invariants

## INV-INV-001 — Store is the authoritative inventory boundary

Inventory quantity and ownership are authoritative at the Store level.

## INV-INV-002 — Internal movement does not change Store On Hand

Movement among receiving, stockroom, sales floor, front table, cashwrap, or similar areas inside one Store must not change Store-level On Hand.

## INV-INV-003 — Inter-store movement is an Inventory Transfer

Movement between Stores changes the authoritative Store assignment and must use an auditable transfer workflow.

## INV-INV-004 — One Stock Balance per Store and Variant

There must be at most one Stock Balance for each:

```text
Store + quantity-tracked Product Variant
```

## INV-INV-005 — Stock Balance applies only to quantity tracking

Quantity-based Stock Balances must not be used as a substitute for exact Inventory Units on individually tracked Variants.

## INV-INV-006 — Only Inventory Movements change On Hand

Direct unexplained edits to On Hand are prohibited.

Every On-Hand change must be explained by one or more Inventory Ledger Entries.

## INV-INV-007 — Available is derived consistently

For quantity-tracked merchandise:

```text
available = on_hand - reserved - unavailable
```

## INV-INV-008 — Reservation does not change On Hand

Creating, releasing, or converting an Inventory Reservation changes commitment and availability, not physical possession.

## INV-INV-009 — Unavailable remains On Hand

Unavailable quantity represents physical merchandise still owned and present at the Store.

## INV-INV-010 — On Order remains outside Inventory

On Order is expected supply from Purchasing.

It is not part of:

* On Hand;
* Reserved;
* Unavailable;
* Available.

## INV-INV-011 — Inventory Unit belongs to one Store

An active Inventory Unit belongs to exactly one Store at a time, except where a later transfer design explicitly introduces an in-transit state.

## INV-INV-012 — Inventory Unit belongs to an individually tracked Variant

Every Inventory Unit belongs to exactly one Product Variant using individual tracking.

## INV-INV-013 — One active Reservation per Inventory Unit

An Inventory Unit may have at most one active Inventory Reservation.

## INV-INV-014 — Sold Unit cannot be sold again

A sold Inventory Unit must not be sold again unless an explicit reversing operation restores it to an eligible state.

## INV-INV-015 — Discarded Unit cannot be sold

A discarded Inventory Unit must not become sellable without an explicit authorized reversal or correction.

## INV-INV-016 — Quantity Reservation identifies Store, Variant, and quantity

An active quantity-tracked Reservation must identify:

* Store;
* Product Variant;
* positive quantity;
* source record.

## INV-INV-017 — Individual Reservation identifies exact Unit

An active individually tracked Reservation must identify the exact Inventory Unit.

## INV-INV-018 — Every active Reservation has a source

An active Inventory Reservation must identify the workflow that owns the commitment.

Examples include:

* POS Line Item;
* Customer Request.

## INV-INV-019 — Suspended POS retains Reservation

Suspending a tender-free POS Transaction must not release its Inventory Reservations.

## INV-INV-020 — Cancellation releases POS Reservation

Cancelling an incomplete POS Transaction must release its active Inventory Reservations.

## INV-INV-021 — Completion converts Reservation

Successful POS Completion converts the applicable Reservation into posted Inventory Movements.

It must not leave the original Reservation active.

## INV-INV-022 — Failed Completion preserves or rolls back Reservation state

A failed POS Completion must not leave partially converted Reservations or Inventory Movements.

## INV-INV-023 — Negative quantity may warn without inherent Approval

Quantity-tracked merchandise may become negative where Store policy allows.

Negative inventory is a warning and not inherently an Approval event.

## INV-INV-024 — Missing cost differs from zero cost

ShelfStack must distinguish:

* cost unavailable;
* confirmed zero cost.

## INV-INV-025 — Completed sale snapshots cost

A completed sale must retain the cost used at Completion.

Later cost changes must not alter historical margin.

---

# 13. POS Transaction invariants

## INV-POS-001 — POS Transaction is a checkout container

A POS Transaction may contain both sale and return activity.

It must not require a permanent transaction type such as only `sale`, `return`, or `exchange`.

## INV-POS-002 — Allowed transaction statuses are limited

The baseline statuses are:

```text
open
suspended
completed
cancelled
```

A Completed Transaction does not transition to another status.

## INV-POS-003 — Completed Transaction is immutable

A Completed Transaction must not be edited or deleted.

## INV-POS-004 — Completed Line is immutable

A completed POS Line Item must not later be changed to `returned`, `voided`, or another corrective status.

## INV-POS-005 — Removed pending lines remain recorded

Removing a pending POS Line Item must retain it as a Removed Line rather than deleting it.

## INV-POS-006 — Removed Line has no completed commercial effect

A Removed Line must not contribute to:

* sales;
* returns;
* Discounts;
* tax;
* Tender;
* COGS;
* Inventory Movements;
* Stored-Value activity.

## INV-POS-007 — Amounts and quantities remain positive

POS Line Item amounts and quantities remain positive.

Line direction determines sale or return effect.

## INV-POS-008 — Product Line requires a Variant

An ordinary Product line must identify one Product Variant.

## INV-POS-009 — Individually tracked Product Line requires a Unit

An individually tracked Product line must identify one Inventory Unit before Completion.

## INV-POS-010 — Open-Ring Line is explicit

An Open-Ring Line must explicitly identify:

* description;
* Department;
* Tax Category;
* price.

It must not masquerade as an ordinary Product Variant.

## INV-POS-011 — Stored-Value Line is not ordinary merchandise

A Stored-Value Line must not create ordinary merchandise inventory or ordinary merchandise revenue.

## INV-POS-012 — Receipt Number is assigned only at Completion

Open, suspended, cancelled, and failed transactions must not consume Receipt Numbers.

## INV-POS-013 — Completed Transaction has one Receipt Number

Every Completed Transaction has exactly one Store-unique Receipt Number.

## INV-POS-014 — Receipt reprint does not create financial activity

A receipt reprint retains the original Receipt Number and records a print event.

It must not create a new POS Transaction or Tender.

## INV-POS-015 — Transaction may cross Sessions

A POS Transaction may open in one POS Session and complete in another.

The Completion Session governs financial reporting.

## INV-POS-016 — Suspended tender-free Transaction may outlive Session

A Suspended Transaction without unresolved Tender activity may remain after its originating POS Session closes.

## INV-POS-017 — Suspended Transaction remains Store-bound

A Suspended Transaction must not be recalled at another Store.

## INV-POS-018 — Completion is idempotent

Repeating the same Completion request must not create duplicate:

* Completed Transactions;
* Receipt Numbers;
* Inventory Movements;
* Tenders;
* Stored-Value Entries.

## INV-POS-019 — Completion is atomic

All required internal Completion effects must commit together or none must commit.

## INV-POS-020 — Transaction totals reconcile

The stored completed transaction totals must reconcile to completed line, Discount, tax, and Tender records.

---

# 14. Pricing, Discount, and tax invariants

## INV-PRICE-001 — Regular Price and Selling Price are distinct

Regular Price represents the current normal price.

Selling Price represents the price after an approved Price Override.

## INV-PRICE-002 — Price Override and Discount are distinct

A Price Override establishes Selling Price.

A Discount reduces the Selling Price afterward.

## INV-PRICE-003 — Price-Override Variance reports separately

Price-Override Variance must not be included in reported Discount totals.

## INV-PRICE-004 — Transaction Discounts are allocated

A transaction-level Discount must be allocated among eligible POS Line Items.

## INV-PRICE-005 — Discount Allocations reconcile

The sum of Discount Allocations must equal the applied transaction-level Discount.

## INV-PRICE-006 — Discount allocation is reproducible

Discount allocation must use deterministic rounding and retain historical results.

## INV-TAX-001 — Tax follows price and Discount

Tax calculation follows:

```text
Regular Price
→ Selling Price
→ Gross Amount
→ Discount Allocation
→ Taxable Merchandise Amount
→ Tax
→ Total Amount
```

Only Discount allocations with tax treatment that reduces the taxable base reduce Taxable Merchandise Amount. See [ADR-0014](../adr/0014-hybrid-transaction-component-tax-calculation.md).

## INV-TAX-002 — Tax components reconcile

The sum of completed Tax Components for a POS Line Item must equal the line’s Tax Amount. Transaction tax totals are derived only from stored line tax components.

## INV-TAX-003 — Completed tax uses historical rules

Completed tax reporting must use stored tax components and snapshots, not current Tax Rates or Tax Rules. Linked Returns and Post-Voids reverse stored components exactly.

## INV-TAX-004 — Tax exemption is snapshotted

A Completed Transaction using a Tax Exemption must retain the exemption evidence and scope used at Completion. A missing Store Tax Rule for a taxable Tax Category is not an exemption.

## INV-TAX-005 — Tax and revenue remain separate

Collected tax must not be included in ordinary sales revenue.

## INV-TAX-006 — Hybrid transaction-component rounding

Taxability and taxable base are resolved per line. Each transaction tax component and line direction is rounded once (half up to the nearest cent) and allocated to lines with largest remainder. Residual cents are not assigned automatically to the last line. Sale and return directions are separate rounding pools. Governing decision: [ADR-0014](../adr/0014-hybrid-transaction-component-tax-calculation.md).

## INV-TAX-007 — Tax rule effective date at Completion

Final tax rules are selected using the store-local calendar date at Transaction Completion, not the Business Day reporting date.

---

# 15. Tender and cash invariants

## INV-TND-001 — Tender settles value but does not define revenue

Tender identifies how a transaction is settled.

Tender Type must not determine merchandise Department or revenue classification.

## INV-TND-002 — Tender direction is explicit

POS Tenders use explicit directions:

```text
received
refunded
```

## INV-TND-003 — Only completed Tenders settle a Transaction

Pending, declined, failed, removed, or otherwise incomplete Tenders must not count toward settlement.

## INV-TND-004 — Completed Tender net equals Transaction net

At Completion:

```text
completed received Tenders
- completed refunded Tenders
= completed transaction net total
```

## INV-TND-005 — Cash change is part of Cash Tender

Change given is part of the Cash Tender and must not be represented as a separate customer refund.

## INV-TND-006 — Card data is limited

ShelfStack must not store full payment-card numbers.

Stored card metadata may include only approved non-sensitive references such as:

* card brand;
* masked last four;
* authorization code;
* terminal reference.

## INV-TND-007 — Standalone card confirmation remains auditable

Where standalone terminals are used, the cashier’s approval confirmation and reference information must remain auditable.

## INV-CASH-001 — Expected cash is reproducible

Expected cash must derive from:

* cash received;
* cash refunded;
* change given;
* cash movements;
* opening cash.

## INV-CASH-002 — Cash variance preserves original counts

A manager recount must create an additional Cash Count.

It must not overwrite the original count.

## INV-CASH-003 — No-sale Drawer opening is audited

A no-sale Cash Drawer opening must retain:

* User;
* POS Session;
* timestamp;
* reason.

## INV-CASH-004 — Close and Reconciliation are separate

A POS Session or Business Day may close with a documented variance and be reconciled later.

---

# 16. Business Day and POS Session invariants

## INV-DAY-001 — One open Business Day per Store

A Store may have at most one open Business Day.

## INV-DAY-002 — Business Date is explicit

Every Business Day stores an explicit Business Date.

It must not be reconstructed later solely from timestamps.

## INV-DAY-003 — Date policy remains configurable or explicitly decided

Until a governing policy is accepted, application code must not assume that Business Date always equals:

* opening date;
* closing date;
* current calendar date.

## INV-DAY-004 — Business Day has sequential Store Z number

Each closed Business Day receives a sequential Store-specific Z-Report Number.

## INV-DAY-005 — Business Date and Z number are distinct

Business Date and Z-Report Number must both be retained.

Neither replaces the other.

## INV-DAY-006 — Session belongs to one Business Day

Every POS Session belongs to exactly one Business Day.

## INV-DAY-007 — Business Day cannot close with open Session

A Business Day must not close while any POS Session remains open.

## INV-DAY-008 — POS Device, Session, and Drawer remain distinct

POS Device, POS Session, and Cash Drawer must not be collapsed into one record.

## INV-DAY-009 — Session Z and Business-Day Z remain distinct

A Session Z Report and Business-Day Z Report are separate reports with separate accountability scope.

## INV-DAY-010 — Closed periods reject ordinary new activity

A closed Business Day or POS Session must not accept ordinary new completed activity.

Later corrections complete in the currently open reporting period.

---

# 17. Return and correction invariants

## INV-RET-001 — Customer Return creates a new line

A Customer Return must create a new return POS Line Item.

It must not change the original sale line.

## INV-RET-002 — Linked Return references original line

A Linked Return must reference the original completed sale line.

## INV-RET-003 — Linked Return cannot exceed remaining quantity

The cumulative linked returned quantity must not exceed the remaining returnable quantity of the original sale line.

## INV-RET-004 — Linked Return uses historical basis

A Linked Return uses the applicable original historical:

* price;
* Discount;
* tax;
* Department;
* cost;
* return eligibility.

Current configuration must not recalculate the original basis.

## INV-RET-005 — Return Reason and Return Disposition are separate

Return Reason explains why the item was returned.

Return Disposition records what the Store will do with it.

## INV-RET-006 — Only return-to-stock becomes immediately Available

Returned physical merchandise becomes immediately Available only when the Disposition is `return_to_stock`.

## INV-RET-007 — Physical unavailable returns remain On Hand

Returned merchandise assigned to inspection, damaged, RTV, or quarantine remains part of On Hand until a later Inventory Movement removes it.

## INV-RET-008 — Cancellation and Post-Void are distinct

Cancellation applies before Completion.

Post-Void applies after Completion and creates a new Completed Transaction.

## INV-RET-009 — Post-Void leaves original completed

A Post-Void must not change the original transaction’s Completed status.

## INV-RET-010 — Post-Void reverses complete historical effects

A valid Post-Void reverses the original:

* lines;
* Discounts;
* tax;
* cost;
* Inventory Movements;
* Tenders;
* Stored-Value activity.

## INV-RET-011 — Post-Void uses historical values

A Post-Void must not recalculate current price, tax, cost, Department, or policy.

## INV-RET-012 — Post-Void may be blocked

A Post-Void must be blocked when complete reversal is no longer possible.

Examples include:

* partial prior Return;
* partial Tender refund;
* redeemed issued Stored Value;
* subsequently sold Inventory Unit;
* prior complete Post-Void.

## INV-RET-013 — Partial correction is not Post-Void

Partial correction uses Customer Returns, Tender refunds, or another explicit corrective workflow.

---

# 18. Stored-Value invariants

## INV-SV-001 — Stored-Value account types remain distinct

ShelfStack distinguishes:

```text
gift_card
store_credit
trade_credit
```

These types may share infrastructure but remain separately reportable.

## INV-SV-002 — Stored Value uses an append-only Ledger

Stored-Value Entries must not be edited or deleted after posting.

## INV-SV-003 — Ledger is authoritative

The Stored-Value Ledger is the authoritative balance history.

A cached balance must reconcile to the Ledger.

## INV-SV-004 — Positive entries increase value

Positive Stored-Value Entries increase the account balance.

## INV-SV-005 — Negative entries consume value

Negative Stored-Value Entries reduce the account balance.

## INV-SV-006 — Issuance creates liability

Gift-card or similar Stored-Value Issuance creates a liability.

It must not be reported as ordinary merchandise sales revenue.

## INV-SV-007 — Redemption is Tender

Stored-Value Redemption is a received Tender.

It must not be represented as:

* Discount;
* negative revenue;
* tax adjustment.

## INV-SV-008 — Redemption validates available balance

Stored-Value Redemption must not exceed available balance unless a later accepted policy explicitly permits it.

## INV-SV-009 — POS and Stored Value post atomically

A Completed POS Stored-Value line or Tender must have its related Stored-Value Entry.

The Stored-Value Entry must not post without the related Completed POS activity, except for an authorized manual adjustment.

## INV-SV-010 — Cached balance updates atomically

The cached Stored-Value balance and new Ledger Entry must update in the same transaction.

## INV-SV-011 — Corrections create reversing entries

Stored-Value corrections must create new reversing or adjusting Entries.

They must not overwrite existing Entries.

## INV-SV-012 — Manual adjustment is authorized and reasoned

A manual Stored-Value adjustment must retain:

* performing User;
* reason;
* Approval where required;
* related account;
* amount;
* timestamp.

## INV-SV-013 — Issuance reversal may be blocked after redemption

ShelfStack must not reverse issued value when doing so would invalidate later redeemed activity without an explicit resolution workflow.

---

# 19. Historical integrity invariants

## INV-HIST-001 — Completed facts are immutable

Completed or posted financial, inventory, tax, Tender, and Stored-Value facts must not be rewritten in place.

## INV-HIST-002 — Corrections are explicit

Corrections must use explicit linked records such as:

* Customer Returns;
* Post-Voids;
* Inventory reversals;
* Stored-Value reversals;
* Reconciliation Adjustments.

## INV-HIST-003 — Historical records retain source relationships

Corrective records must retain their relationship to the original activity.

## INV-HIST-004 — Completed records retain required snapshots

Completed records must retain enough information to reproduce their historical result.

Typical snapshots include:

* Product;
* Product Variant;
* Product Identifier;
* SKU;
* description;
* Merchandise Class;
* Department;
* Tax Category;
* Return Policy;
* Regular Price;
* Selling Price;
* Discount;
* tax;
* cost;
* Tender metadata;
* Approval context.

## INV-HIST-005 — Current master-data changes affect future activity

Changes to current configuration affect future operations unless an explicit effective-dated rule states otherwise.

They do not rewrite completed activity.

## INV-HIST-006 — Deletion must not orphan history

Records referenced by completed or posted history must not be deleted in a way that removes historical meaning or referential integrity.

---

# 20. Reporting and Reconciliation invariants

## INV-REP-001 — Reports use posted source records

Financial and inventory reporting must use completed or posted operational records.

## INV-REP-002 — Reporting does not modify source records

The Reporting and Reconciliation domain must not directly modify:

* POS Transactions;
* Tenders;
* Inventory Movements;
* Purchase Orders;
* Receipts;
* Stored-Value Entries.

## INV-REP-003 — Historical reporting uses snapshots

Completed reporting uses the classifications, price, tax, and cost stored at Completion or posting.

## INV-REP-004 — Revenue and Tender remain separate

Reports must not treat Tender totals as revenue totals.

## INV-REP-005 — Stored-Value Issuance is excluded from ordinary sales

Stored-Value Issuance must report as liability activity rather than ordinary sales revenue.

## INV-REP-006 — Returns and Post-Voids remain distinct

Customer Returns and Post-Voids must be separately reportable.

## INV-REP-007 — Received and refunded Tenders remain distinct

Tender reporting must preserve:

* received;
* refunded;
* net.

## INV-REP-008 — Corrections report in their completion period

A Return, Post-Void, or other correction reports in the Business Day in which the correction completes.

The relationship to the original activity remains available.

## INV-REP-009 — Missing cost differs from zero cost

Cost and margin reporting must distinguish missing cost from confirmed zero cost.

## INV-REP-010 — Tax reports use completed tax records

Tax reporting must use completed tax components rather than current Tax Rules.

## INV-REP-011 — Reconciliation does not rewrite operations

Reconciliation records differences and resolutions without silently changing completed source activity.

## INV-REP-012 — Session and Business-Day totals remain reproducible

Session and Business-Day reports must be reproducible from their completed source records and stored counts.

---

# 21. Cross-domain atomicity invariants

## INV-XDOM-001 — POS Completion coordinates all required internal effects

POS Completion must coordinate, as applicable:

* POS Transaction;
* POS Line Items;
* Discounts;
* tax;
* Tenders;
* Inventory Reservations;
* Inventory Movements;
* Inventory Unit statuses;
* Stored-Value Entries;
* cost snapshots;
* Receipt Number assignment.

## INV-XDOM-002 — No partial internal POS Completion

A failed Completion must not leave any subset of required internal effects posted.

## INV-XDOM-003 — Receipt posting coordinates Inventory

Posting accepted Receipt quantity and posting the related Inventory Movements must occur atomically.

## INV-XDOM-004 — Stored-Value posting coordinates balance

Posting a Stored-Value Entry and updating its cached balance must occur atomically.

## INV-XDOM-005 — Concurrency cannot overcommit exact supply

Concurrent operations must not:

* reserve the same Inventory Unit twice;
* allocate more future supply than remains uncommitted;
* redeem the same Stored-Value balance twice;
* assign the same Receipt Number twice;
* complete the same POS Transaction twice.

## INV-XDOM-006 — Lock ordering is deterministic

Services coordinating several inventory, Stored-Value, Tender, or transaction records should acquire locks in a consistent order to reduce deadlocks.

---

# 22. Important uniqueness and cardinality constraints

The schema should enforce the following wherever technically practical.

| Constraint                                               | Expected enforcement               |
| -------------------------------------------------------- | ---------------------------------- |
| Product canonical identifier unique within Organization  | Unique index                       |
| Product Variant SKU unique within Organization           | Unique index                       |
| Inventory Unit Identifier unique within Organization     | Unique index                       |
| Stored-Value Account Number unique within Organization   | Unique index                       |
| One Stock Balance per Store and quantity-tracked Variant | Composite unique index             |
| One active Reservation per Inventory Unit                | Partial unique index or equivalent |
| One open Business Day per Store                          | Partial unique index or equivalent |
| One active cash-enabled Session per Cash Drawer          | Partial unique index or equivalent |
| Receipt Number unique within Store                       | Composite unique index             |
| Completion Idempotency Key unique within required scope  | Unique index                       |
| One Product parent per Product Variant                   | Foreign key and `NOT NULL`         |
| One Variant parent per Inventory Unit                    | Foreign key and `NOT NULL`         |
| One Business Day parent per POS Session                  | Foreign key and `NOT NULL`         |

---

# 23. Derived relationships

The following values should be calculated or maintained consistently.

## Inventory availability

```text
available = on_hand - reserved - unavailable
```

## Unfulfilled Product Request quantity

```text
unfulfilled =
requested quantity
- active confirmed Inventory Reservations
- active Purchase-Order Allocations
```

## Purchase-Order open quantity

```text
open quantity =
ordered quantity
- accepted received quantity
- cancelled quantity
```

## POS Line Item amounts

```text
gross amount =
Selling Price × quantity
```

```text
net amount =
gross amount - Discount amount
```

```text
total amount =
net amount + Tax amount
```

## Tender settlement

```text
completed received Tenders
- completed refunded Tenders
= completed transaction net total
```

## Cash variance

```text
cash variance =
counted cash - expected cash
```

These equations do not determine the entire workflow, but any cached or reported values must reconcile to them.

---

# 24. Open questions that are not yet invariants

The following subjects remain intentionally unresolved and must not be treated as governing invariants until decided:

* exact Purchase-Order status set;
* whether internal submission and ordering are separate;
* detailed Receipt statuses;
* posted Receipt correction process;
* treatment of unresolved Vendor backorders;
* freight allocation;
* complete Return-to-Vendor lifecycle;
* Inventory Count methodology;
* inter-store transfer lifecycle;
* Business Date assignment policy;
* Stored-Value expiration and replacement;
* complete Buyback workflow;
* Customer identity and communication;
* integrated payment processing;
* offline POS behavior;
* full accounting-export structure;
* physical shelf-location history.

Implementations touching these areas should remain minimal and document assumptions explicitly.

---

# 25. Testing expectations

Every invariant affected by a code change should have an appropriate test.

Tests should reference the invariant identifier where useful.

Example:

```ruby
# INV-INV-013: One active Reservation per Inventory Unit
test "an inventory unit cannot have two active reservations" do
  # ...
end
```

High-risk invariants should be tested at more than one level.

Examples include:

* database constraint test;
* service behavior test;
* concurrency test;
* rollback test;
* historical reporting test.

Tests must include failure paths for operations affecting:

* inventory;
* tax;
* Tender;
* Stored Value;
* POS Completion;
* Receipt posting;
* Approval;
* historical corrections.

---

# 26. Change policy

A change to a governing invariant requires review of:

1. the applicable ADR;
2. this document;
3. the affected Domain Specifications;
4. Schema Documentation;
5. workflows;
6. implementation and tests.

A material reversal of an accepted invariant normally requires a new ADR superseding the decision that established it.

Do not change an invariant solely to make an existing implementation appear compliant.

Implementation and documentation conflicts must be resolved explicitly.
