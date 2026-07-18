# ShelfStack Glossary

This glossary defines the shared terminology used throughout ShelfStack’s architecture, domain specifications, schema documentation, workflows, implementation plans, and source code.

Terms should be used consistently across:

* user interfaces;
* model and service names;
* database tables and fields;
* documentation;
* tests;
* reports;
* API contracts;
* issue and pull-request descriptions.

When this glossary conflicts with an accepted Architectural Decision Record, the most recent applicable ADR governs.

---

## Usage conventions

### Established term

A term with a settled meaning under the current ShelfStack architecture.

### Open term

A term whose general purpose is understood but whose detailed workflow or implementation has not been finalized.

### Deprecated term

A term retained for historical reference but no longer preferred for new documentation or implementation.

### Snapshot

A historical copy of a value used when an operational record was completed or posted.

Snapshots preserve the original result even when current master data later changes.

---

# A

## Accepted quantity

The portion of delivered merchandise the store accepts into inventory.

Accepted quantity may enter inventory as:

* sellable;
* inspection required;
* damaged;
* awaiting return to vendor;
* another authorized unavailable status.

Only accepted quantity increases on-hand inventory.

## Acquisition cost

The cost assigned to merchandise when the store acquires it.

For quantity-tracked merchandise, acquisition cost contributes to aggregate Inventory Value and the Store-and-Variant Moving Weighted-Average Cost.

For individually tracked merchandise, acquisition cost belongs to the exact Inventory Unit.

Acquisition Cost should normally describe actual or directly supported cost. A Department-based configured estimate is an estimated cost basis, not actual acquisition cost.

## Administrative audit event

An append-only record of an administrative change to master data, identity, access, or configuration.

An Administrative Audit Event identifies the acting User, applicable Organization or Store context, action, affected record, timestamp, and relevant change details.

It is distinct from:

* an Approval, which authorizes a restricted operational action;
* an Inventory Ledger Entry or Stored-Value Entry;
* ordinary application request logging.

## Activation

The process of making a master record available for current operational use.

ShelfStack generally deactivates historically referenced records rather than deleting them.

## Active

A master-record state indicating that the record may participate in current workflows, subject to other eligibility rules.

An active record is not necessarily sellable, purchasable, or otherwise eligible for every operation.

## Allocation

A commitment of identified supply to demand.

In ShelfStack, the unqualified term should normally be avoided in favor of a more specific term such as:

* Purchase-Order Allocation;
* Discount Allocation;
* Tender Allocation, if later introduced.

## Alternate identifier

An optional secondary lookup value associated with a record.

For Products, an alternate identifier:

* assists search;
* is not the canonical product identity;
* may be non-unique;
* may return more than one Product.

For Stored-Value Accounts, an alternate identifier may represent a preprinted, migrated, or externally assigned card or certificate number.

## Amount applied

The portion of a Tender used to settle a POS Transaction.

For cash, the amount applied may be less than the amount presented because part of the presented cash is returned as change.

## Append-only

A recordkeeping approach in which existing posted entries are not overwritten or removed.

Corrections are represented by additional entries that reverse or adjust earlier activity.

ShelfStack uses append-only history for areas such as:

* inventory movements;
* Stored-Value Entries;
* completed POS corrections;
* reconciliation adjustments.

## Approval

An independent, auditable record showing that an authorized user approved a restricted action requested by another user.

An Approval records information such as:

* requesting user;
* approving user;
* action type;
* affected record;
* reason;
* requested value;
* approved value;
* authority context;
* approval timestamp.

An Approval is not merely a Boolean flag.

## Authority limit

A numeric threshold defining the maximum value a User may approve or perform for a particular action.

Examples include:

* maximum discount rate;
* maximum discount amount;
* maximum price-override rate;
* maximum cash refund;
* maximum no-receipt return;
* maximum paid-out;
* cash-variance review threshold.

A User may possess a Permission but lack sufficient Authority Limit for a particular action.

Until Role and Store authority defaults are implemented, Phase 1 evaluates Store-Membership overrides only. A missing, malformed, or negative configured value fails closed rather than granting unlimited authority.

## Available

The quantity of merchandise currently sellable without consuming Reserved or Unavailable inventory.

For quantity-tracked merchandise:

```text
available = on_hand - reserved - unavailable
```

Available may be negative when ShelfStack permits warned negative inventory.

## Availability status

A status describing whether physical inventory may currently be sold.

Examples may include:

* available;
* reserved;
* inspection;
* damaged;
* RTV;
* quarantine;
* sold;
* discarded.

For individually tracked merchandise, availability is generally determined by the Inventory Unit’s status and active Reservation.

---

# B

## Balance due

The amount remaining to be settled on an open POS Transaction.

A completed transaction must have no unresolved balance.

## Barcode namespace

A restricted prefix range used by ShelfStack to identify the type of internally generated EAN-13 identifier.

Current namespaces are:

```text
21 — Stored-Value Account
27 — Inventory Unit
28 — Product Variant
29 — locally identified Product
```

## Basis point

One ten-thousandth of a rate.

```text
10,000 basis points = 100%
```

ShelfStack uses basis points for fixed-precision percentage configuration such as the Department gross-margin assumption used by configured inventory-cost estimates.

## Bootstrap

The idempotent installation operation that creates the sole Organization, initial Store, administrator Role, User, and Store Membership, plus development POS Device and Cash Drawer records where applicable.

Bootstrap must not silently:

* create a second operating Organization;
* reactivate disabled access;
* clear authentication lockout state;
* restore deliberately removed Role-Permission assignments;
* reset Identifier Sequences.

Bootstrap is distinct from `db:seed` and Reference-Data loading.

## Business date

The explicit reporting date assigned to a Business Day.

The Business Date is distinct from the actual opening and closing timestamps.

The policy for assigning the Business Date remains an open implementation detail.

## Business day

The store-wide operational and reporting period under which completed POS activity is recorded.

A Business Day:

* belongs to one Store;
* may cross calendar midnight;
* may contain several POS Sessions;
* has an explicit Business Date;
* receives a sequential store-specific Z-Report Number;
* cannot close while a POS Session remains open.

## Buyer-review queue

The work queue containing Product Requests whose quantity is not yet satisfied by:

* confirmed in-house Reservations; or
* active Purchase-Order Allocations.

A buyer may source, order, defer, decline, or otherwise resolve the remaining demand.

## Buyback

A future workflow through which the store acquires merchandise from a customer in exchange for cash or Trade Credit.

Buyback is merchandise acquisition, not a Customer Return.

The detailed Buyback workflow remains open.

---

# C

## Cached balance

A stored summary value maintained for efficient access but supported by a more authoritative history.

Examples include:

* a Stock Balance supported by Inventory Ledger Entries;
* a Stored-Value Account balance supported by Stored-Value Entries.

A cached balance must remain reconcilable to its authoritative records.

## Cancellation

The termination of an editable workflow before it becomes a completed or posted event.

For an open POS Transaction, Cancellation:

* releases Reservations;
* removes provisional commercial effects;
* creates no completed sale;
* creates no completed Tender;
* creates no inventory movement;
* consumes no Receipt Number.

Cancellation is distinct from Post-Void.

## Canonical identifier

The primary stable identifier used as the authoritative lookup identity for a record.

A canonical identifier is normally:

* normalized;
* indexed;
* unique within its required scope;
* immutable after operational use;
* never reused when ShelfStack-generated.

Examples include:

* ISBN-13 for an ISBN-defined Product;
* UPC-A or EAN-13 for other Products;
* `28` EAN-13 SKU for a Product Variant;
* `27` EAN-13 identifier for an Inventory Unit;
* `21` EAN-13 identifier for a Stored-Value Account.

## Card-only session

A POS Session that processes non-cash activity and has no Cash Drawer.

## Cash count

A recorded statement of the cash physically present in a Cash Drawer at a particular point in a POS Session.

Count types may include:

* opening count;
* closing count;
* manager recount;
* reconciled count.

Later counts do not overwrite earlier counts.

## Cash drawer

The physical till used for cash accountability.

A Cash Drawer:

* belongs to one Store;
* is distinct from a POS Device;
* may be used by different devices over time;
* may have no more than one active cash-enabled POS Session.

## Cash movement

A non-sale cash event affecting a POS Session or Cash Drawer.

Examples include:

* additional float;
* paid in;
* paid out;
* safe drop;
* cash pickup;
* transfer in;
* transfer out;
* correction.

## Cash variance

The difference between counted and expected cash:

```text
cash_variance = counted_cash - expected_cash
```

A Cash Variance may require a reason, review, or Approval.

## Catalog

The shared organizational collection of Products, Product Variants, identifiers, descriptive metadata, formats, and related sellable definitions.

The Catalog defines what an item is.

It does not own Store inventory quantity, posted inventory valuation, or completed transaction history.

## Catalog readiness

The Phase 2 evaluation confirming that a Product Variant has the minimum Catalog configuration needed for later sale workflows.

Catalog Readiness may validate Product and Variant activation, sellability, price, Department, Tax Category, and Inventory-Tracking Mode. It does not validate an open Business Day, POS Session, transaction tax calculation, Tender settlement, inventory reservation, or operational Approval.

`Catalog::SaleEligibility` is therefore a Catalog-readiness service, not the complete POS Sale-Eligibility decision.

## Checksum

A calculated digit used to validate identifiers such as:

* ISBN-10;
* ISBN-13;
* UPC-A;
* EAN-13.

ShelfStack normally treats invalid checksums as warnings rather than database-level blockers.

## Close

The operational act of ending a POS Session or Business Day.

Close is distinct from Reconciliation.

A record may close with a documented variance and be reconciled later.

## Completed line

A POS Line Item whose commercial, tax, inventory, cost, and tender-related consequences have been finalized.

A Completed Line is immutable.

## Completed transaction

A POS Transaction that has passed final validation and atomically posted all required internal effects.

A Completed Transaction:

* has one Receipt Number;
* is immutable;
* cannot later become cancelled, returned, or voided;
* is corrected through new linked records.

## Completion

The atomic operation that changes an open POS Transaction into a Completed Transaction.

Completion coordinates:

* final line values;
* Discounts;
* tax;
* Tenders;
* Reservations;
* inventory movements;
* Inventory Unit statuses;
* Stored-Value Entries;
* cost snapshots;
* Receipt Number assignment.

## Condition

The physical or commercial condition of merchandise.

Examples may include:

* new;
* like new;
* very good;
* good;
* acceptable;
* poor;
* collectible;
* damaged.

A Product Variant may identify a shared condition category, while an individually tracked Inventory Unit may retain the exact condition of one physical copy.

## Confirmed zero cost

A known cost whose value is exactly zero.

Confirmed Zero Cost is valid cost information. It is distinct from Unknown Cost and must retain a non-unknown Cost Quality.

Examples may include donated merchandise, promotional inventory supplied at no charge, or another acquisition whose actual or confirmed estimated cost is zero.

## Correction

An explicit later record that reverses or adjusts a completed or posted event.

Corrections do not rewrite the original activity.

Examples include:

* Customer Return;
* Post-Void;
* Inventory Adjustment;
* Stored-Value reversal;
* Reconciliation Adjustment.

## Cost correction

An Inventory Adjustment kind that changes aggregate inventory valuation without changing physical quantity.

For the Phase 3 baseline:

```text
on_hand > 0
quantity_delta = 0
```

A Cost Correction may establish complete valuation for previously unknown-cost stock, replace estimated cost with actual cost, or correct an erroneous Inventory Value. It requires the dedicated Permission, cost visibility, a controlled reason, and full audit.

A Cost Correction does not rewrite earlier Ledger Entries or completed POS cost snapshots. Independent Approval is not mandatory in Phase 3.

## Cost of goods sold

The inventory cost recognized when merchandise is sold.

Common abbreviation:

```text
COGS
```

For quantity-tracked merchandise, COGS uses the applicable Store-and-Variant cost.

For individually tracked merchandise, COGS uses the exact Inventory Unit’s cost.

## Cost method

The calculation or sourcing approach used to establish inventory cost.

Current values are:

```text
explicit
configured_estimate
moving_average
unknown
```

`retained_rate` is reserved for a later negative-inventory policy and is not part of the Phase 3 implemented baseline.

Cost Method is distinct from Cost Quality.

## Cost quality

The evidentiary quality of inventory cost, independent of the Cost Method used to calculate it.

Current values are:

```text
actual
estimated
mixed
unknown
```

Unknown Cost must never be treated as Confirmed Zero Cost.

## Customer request

A Product Request indicating that the store is attempting to supply merchandise for a particular customer.

A Customer Request may be fulfilled from:

1. physically located and Reserved in-house inventory;
2. uncommitted On-Order supply;
3. a new Purchase Order.

A Customer Request does not itself prove that supply exists.

## Customer return

A later customer-facing transaction that reverses some or all of a previous sale or accepts an item under an authorized unlinked-return basis.

A Customer Return is distinct from:

* Cancellation;
* Post-Void;
* Return to Vendor.

---

# D

## Deactivation

The process of preventing a master record from participating in new ordinary activity while preserving its historical references.

Deactivation is preferred to deletion for records such as:

* Products;
* Product Variants;
* Stores;
* Users;
* Roles;
* Departments;
* Merchandise Classes;
* Tax Categories;
* Vendors;
* Tender Types.

## Delivered quantity

The amount of merchandise physically presented in a vendor shipment.

Delivered Quantity may be divided into:

* Accepted Quantity;
* Rejected Quantity;
* damaged or inspection quantities, depending on the final receiving design.

The detailed treatment remains partly open.

## Department

The broad financial and managerial classification used for merchandise and service reporting.

Departments are hierarchical. A Department may be:

* postable, meaning it may be assigned to operational merchandise and completed lines; or
* reporting-only, meaning it acts as a hierarchy or reporting parent.

A Department may provide defaults such as:

* general-ledger mappings;
* Tax Category;
* Return Policy;
* maximum merchandise Discount;
* optional gross-margin basis points for configured inventory-cost estimation;
* other selling-policy defaults.

A Department used as an active Merchandise-Class default must be postable.

A Department does not determine:

* Inventory-Tracking Mode;
* exact-copy Condition;
* exact-copy cost;
* current Store quantity;
* Tender behavior.

A Department cost-estimation margin is policy for producing an explicitly confirmed estimate. It is not actual Acquisition Cost and does not make the Department the owner of inventory valuation.

## Discount

A promotional or discretionary reduction applied after the Selling Price has been determined.

A Discount is distinct from a Price Override.

Discounts may be:

* line-level;
* transaction-level;
* percentage;
* fixed amount;
* fixed price;
* promotional;
* discretionary.

## Discount allocation

The stored distribution of a Discount amount among eligible POS Line Items.

Discount Allocations support reproducible:

* tax calculation;
* Customer Returns;
* reporting;
* rounding.

The sum of allocations must equal the applied Discount.

## Discount reason

A controlled explanation for a discretionary Discount.

A Discount Reason is not the same as a Promotion.

## Display category

**Deprecated.**

An earlier ShelfStack term for the customer-facing merchandise hierarchy.

The accepted architecture merges this concept into the hierarchical Merchandise Class model.

Do not create a separate Display Category hierarchy in new implementation or documentation unless a later ADR supersedes this decision.

## Disposition

See **Return Disposition**.

## Domain

A bounded area of business responsibility that owns particular records, rules, and history.

A Domain may reference records owned by another Domain but should not duplicate their ownership.

## Domain specification

The governing document that describes how one ShelfStack Domain behaves under the accepted architecture.

A Domain Specification normally defines:

* purpose;
* ownership boundary;
* entities;
* terminology;
* statuses;
* workflows;
* permissions;
* audit requirements;
* invariants;
* open questions.

---

# E

## EAN-13

A 13-digit barcode format used for external trade identifiers and ShelfStack-generated restricted-circulation identifiers.

ShelfStack-generated EAN-13 values use prefixes `21`, `27`, `28`, and `29`.

## Effective store membership

A Store Membership that is active and whose effective-date range includes the applicable Store-local date.

An Effective Store Membership grants no capability by itself; the User must also hold the required Permission and sufficient Authority Limit for the requested Store-scoped action.

## Effective value

The value selected after applying an established precedence chain of overrides and defaults.

An example Department resolution may be:

```text
Variant override
→ Product override
→ Merchandise-Class default Department
→ missing-value blocker
```

## Exact unit

A shorthand term for an individually tracked Inventory Unit.

Prefer **Inventory Unit** in formal documentation.

## Exemption

See **Tax Exemption**.

---

# F

## Financial classification

The categorization used to distinguish financial effects such as:

* sales;
* returns;
* Discounts;
* Price Overrides;
* tax;
* COGS;
* inventory;
* Tender;
* Stored-Value liability.

Department is the current primary merchandise financial classification.

## Format

The physical or commercial presentation of a Product.

Examples include:

* hardcover;
* trade paperback;
* compact disc;
* vinyl;
* Blu-ray;
* board book;
* greeting card;
* boxed calendar.

Format describes presentation. It does not by itself determine tax, inventory tracking, or Department.

## Fulfilled request

A Product Request whose required quantity has been supplied and whose customer or operational obligation has been completed.

The exact closure workflow will be defined in the Product Requests Domain Specification.

---

# G

## Gift card

A Stored-Value Account type representing value purchased for later redemption.

Gift-card issuance creates a liability rather than ordinary sales revenue.

## Gift receipt

A receipt representation that:

* references the original completed transaction;
* omits prices;
* identifies eligible lines;
* supports later return validation.

A Gift Receipt does not create a new financial transaction.

## Gross amount

For a POS Line Item:

```text
gross_amount = selling_price × quantity
```

Gross Amount is calculated before Discounts and tax.

## Gross margin

The difference between net merchandise sales and COGS.

Tax and Stored-Value issuance are not merchandise margin.

## Gross sales

Completed sale-line Selling Prices extended by quantity before Discounts and tax.

Gross Sales:

* use Selling Price after Price Override;
* exclude Stored-Value issuance;
* exclude tax.

---

# H

## Historical snapshot

See **Snapshot**.

## Hold

An informal user-facing term for physically present merchandise Reserved for a Customer Request.

In architecture and schema documentation, prefer **Inventory Reservation**.

A Product Request without physically confirmed merchandise is not a Hold.

---

# I

## Idempotency

The property that allows the same operation request to be submitted repeatedly without creating duplicate posted or completed effects.

Idempotency applies to multi-record workflows involving money, inventory, identifiers, or completion. Examples include:

* POS Completion through an Idempotency Key;
* Inventory Adjustment posting through a Posting Key;
* Bootstrap and Reference-Data synchronization through stable natural keys.

A retry must return or recognize the previously posted result rather than create duplicate Transactions, Receipt Numbers, Ledger Entries, Tenders, Stored-Value Entries, or balance changes.

## Identifier

A value used to locate or distinguish a record.

ShelfStack distinguishes:

* Canonical Identifier;
* Alternate Identifier;
* Product Variant SKU;
* Inventory Unit Identifier;
* Stored-Value Account Number;
* internal database identifier.

## Identifier sequence

Installation-singleton sequence state used to generate ShelfStack EAN-13 identifiers in the assigned restricted-circulation namespace.

Identifier Sequences:

* remain unique across the Organization;
* are concurrency-safe;
* are never reset during ordinary seed or Reference-Data reruns;
* do not reuse previously assigned values.

## Immutable

Not editable after becoming completed or posted.

Immutability applies to facts whose historical meaning must remain reproducible.

Examples include:

* Completed Transactions;
* Completed Lines;
* posted Inventory Ledger Entries;
* Stored-Value Entries;
* historical tax components.

## In-house inventory

Merchandise physically present at a Store.

For a Customer Request, in-house inventory must be physically located and confirmed before it becomes Reserved.

## Individually tracked

An Inventory-Tracking Mode used when ShelfStack must identify the exact physical copy.

Each copy has an Inventory Unit.

Examples may include:

* used books;
* signed copies;
* collectibles;
* consignment items;
* numbered editions.

## Inspection

An Unavailable status indicating that merchandise is physically present but requires review before being sold or otherwise resolved.

## Inventory

Physical merchandise owned and possessed by a Store.

Inventory does not include merchandise that is merely:

* requested;
* ordered;
* allocated from future supply;
* delivered but rejected.

## Inventory adjustment

A controlled, Store-scoped document used to post an authorized change to inventory quantity or valuation.

Phase 3 supports three distinct kinds:

```text
opening_inventory
quantity_only
cost_correction
```

An Inventory Adjustment has a lifecycle of:

```text
draft
posted
cancelled
```

Posting creates Inventory Ledger Entries. Posted or cancelled Adjustments and their lines are immutable. Direct unexplained edits to On Hand, Inventory Value, Moving Weighted-Average Cost, or Cost Quality are prohibited.

## Inventory adjustment reason

An Organization-owned controlled reason scoped to one Inventory-Adjustment kind.

An Inventory Adjustment Reason has an immutable code, may require a note, and may be deactivated for future use. When an Adjustment posts, the reason code and name are snapshotted so later reason changes do not rewrite posted history.

The qualified form combines kind and code, for example:

```text
quantity_only.physical_count_shortage
```

## Inventory ledger

The append-only history explaining posted changes to inventory quantity, aggregate Inventory Value, cost state, or an Inventory Unit’s inventory state.

## Inventory ledger entry

One posted movement, valuation correction, or status transition in the Inventory Ledger.

An Inventory Ledger Entry may retain:

* quantity delta;
* inventory-value delta, where known;
* movement and unit cost;
* Cost Method and Cost Quality;
* resulting On Hand and valuation snapshots;
* reason code and note;
* Source Record and reversal relationship;
* Posting Key;
* posting User and timestamp.

An Inventory Ledger Entry may reference its source, such as:

* Receipt;
* sale;
* Customer Return;
* Inventory Adjustment;
* transfer;
* Post-Void;
* discard;
* Return to Vendor.

A Cost Correction may create a Ledger Entry with `quantity_delta = 0`. When a positive-balance inventory-value delta cannot be known, the delta is `null`, not zero.

## Inventory movement

A posted event that changes On Hand or an Inventory Unit’s inventory state.

Only Inventory Movements change On Hand.

A Reservation is not an Inventory Movement.

## Inventory reservation

An explicit temporary commitment of physically present inventory to an incomplete workflow.

An Inventory Reservation:

* reduces Available;
* does not reduce On Hand;
* identifies its source;
* may reserve quantity or an exact Inventory Unit;
* remains active until released or converted.

Initial sources include:

* open POS Line Item;
* suspended POS Line Item;
* confirmed Customer Request.

## Inventory transfer

A workflow that moves authoritative inventory ownership from one Store to another.

Movement within one Store is not an Inventory Transfer.

The detailed transfer lifecycle remains open.

## Inventory-tracking mode

The Product Variant setting that determines how inventory is represented.

Allowed modes are:

```text
quantity
individual
none
```

## Inventory unit

One exact physical copy of an individually tracked Product Variant.

An Inventory Unit may retain:

* Unit Identifier;
* current Store;
* Condition;
* acquisition cost;
* unit-specific price;
* status;
* Reservation;
* acquisition source;
* sale history.

Inventory Units are not created for every copy of Quantity-Tracked merchandise.

## Inventory value

The aggregate positive inventory asset value associated with one Store-and-Product-Variant Stock Balance.

Inventory Value is the governing basis for quantity-tracked valuation calculations. It is not calculated by blindly multiplying On Hand by a rounded display average.

Rules include:

* positive On Hand with known complete valuation has a non-null Inventory Value;
* positive On Hand with unknown complete valuation has unknown, not zero, Inventory Value;
* zero or negative On Hand carries zero positive inventory asset value;
* Inventory Value changes only through Inventory posting services and remains reconcilable to Ledger history.

## ISBN-10

A 10-character book identifier accepted by ShelfStack as an input and lookup representation.

A valid ISBN-10 is normalized to its equivalent ISBN-13 before canonical storage.

ISBN-10 is not stored as the Alternate Identifier merely to support lookup.

## ISBN-13

The normal canonical identifier for an ISBN-defined Product.

ISBN-13 is represented as an EAN-13 beginning with `978` or `979`.

## Issuance

The creation or addition of value to a new Stored-Value Account through a sale-line workflow.

Gift-card Issuance creates a liability.

---

# L

## Last-known unit cost

The most recent known carrying unit rate from a positive valued quantity-tracked Stock Balance.

Last-Known Unit Cost and its quality are retained separately when On Hand reaches zero or becomes negative. They are historical reference state, not the current Moving Weighted-Average Cost and not automatic authority for valuing later positive stock.

## Liability

An amount the store owes through a future obligation.

Unredeemed Stored Value is a liability rather than sales revenue.

## Line direction

The commercial direction of a POS Line Item.

Initial values are:

```text
sale
return
```

Amounts and quantities remain positive. Direction determines their effect.

## Line kind

The type of activity represented by a POS Line Item.

Initial values are:

```text
product
open_ring
stored_value
```

## Linked return

A Customer Return whose return line references an original completed sale line.

A Linked Return uses the original historical:

* price;
* Discount;
* tax;
* Department;
* cost;
* eligibility basis.

## List price

A publisher, manufacturer, or supplier’s external suggested price.

List Price is descriptive and is not necessarily the store’s Regular Price or Selling Price.

## Local product identifier

A ShelfStack-generated `29` EAN-13 assigned to a Product without a usable external trade identifier.

---

# M

## Manager approval

An informal UI term for an Approval performed by a qualified user.

Formal architecture should use **Approval**, since the approving user is determined by Permission and Authority Limit rather than a hard-coded job title.

## Merchandise class

The hierarchical classification used for:

* merchandising;
* shelving;
* browsing;
* buyer organization;
* category reporting;
* default Department resolution.

Suggested levels include:

```text
primary
secondary
minor
```

The parent-child hierarchy is authoritative. Implemented codes are path-qualified so similarly named nodes under different parents remain unambiguous.

A Merchandise Class may point to a default postable Department. Merchandise-Class defaults are setup aids and precedence inputs; they do not determine runtime Inventory-Tracking Mode solely from the class.

It does not replace explicit Product or Product Variant settings such as:

* Inventory-Tracking Mode;
* price;
* Format;
* exact Condition;
* vendor source.

## Mixed cost quality

A Cost Quality indicating that a positive quantity-tracked balance contains both actual and estimated cost provenance.

Mixed Cost Quality persists until the Stock Balance reaches zero or an explicit complete Cost Correction establishes another complete valuation basis.

## Money

Monetary values stored as integer cents.

Examples include:

* `regular_price_cents`;
* `unit_cost_cents`;
* `tax_amount_cents`;
* `applied_amount_cents`.

Floating-point types should not be used for monetary amounts.

## Moving weighted-average cost

The current carrying unit cost of positive quantity-tracked inventory for one Store and Product Variant.

```text
moving weighted-average cost
=
aggregate positive Inventory Value
÷
positive On Hand
```

The aggregate Inventory Value governs calculations; the cached unit average is a display and convenience value. It may change through Opening Inventory, cost-bearing inbound movements, proportional outbound allocation, deterministic rounding, and explicit Cost Corrections—not only through Receipts.

When On Hand is zero or negative, current Moving Weighted-Average Cost is `null` and positive Inventory Value is zero. Any retained prior rate belongs in Last-Known Unit Cost fields.

Completed sales snapshot the cost used. The final allocation and settlement treatment for negative-inventory deficits remains open.

---

# N

## Negative inventory

A quantity-tracked Stock Balance with On Hand or Available below zero.

ShelfStack may permit a sale that creates negative inventory after warning the user.

Negative inventory is not inherently an Approval event.

## Net amount

For a POS Line Item:

```text
net_amount = gross_amount - discount_amount
```

Tax is calculated separately.

## Net sales

Gross Sales reduced by Discounts, Customer Returns, and applicable Post-Void commercial effects.

Tax and Stored-Value issuance are excluded.

## No inventory tracking

An Inventory-Tracking Mode used for nonphysical or non-stock activity.

Examples include:

* services;
* fees;
* non-stock modifiers.

No Stock Balance, Reservation, or Inventory Movement is created.

## No-receipt return

An Unlinked Return processed without a verifiable original ShelfStack or external receipt.

No-receipt returns normally default to Store Credit and may require Approval.

## Non-inventory

A Return Disposition used when the returned line does not represent physical merchandise entering inventory.

---

# O

## On hand

The quantity of physical merchandise present and owned by a Store.

On Hand may include merchandise that is:

* Available;
* Reserved;
* under Inspection;
* damaged;
* awaiting Return to Vendor.

Only Inventory Movements change On Hand.

## On order

Unreceived quantity expected from active Purchase-Order Lines.

On Order is not:

* On Hand;
* Available;
* Reserved physical inventory;
* inventory value.

## Open transaction

A POS Transaction that remains editable and has not been completed or cancelled.

## Opening inventory

An Inventory Adjustment kind used to establish opening On Hand without creating a Receipt.

Opening Inventory may use:

* explicit actual cost;
* an explicitly confirmed configured estimate;
* Unknown Cost.

When the existing balance is zero and incoming cost is known, the posted quantity initializes aggregate Inventory Value and Moving Weighted-Average Cost. Opening Inventory is a controlled bootstrap mechanism, not a substitute for future ordinary Receiving.

## Open-ring line

An authorized POS Line Item not linked to a normal Product Variant.

An Open-Ring Line requires:

* description;
* Department;
* Tax Category;
* price.

It does not represent ordinary catalog merchandise.

## Operating organization

See **Organization**.

## Organization

The shared administrative and Catalog boundary for one ShelfStack installation.

An Organization may operate one or more Stores.

Shared records may include:

* Products;
* Product Variants;
* generated identifiers;
* Merchandise Classes;
* Departments;
* Tax Categories;
* Vendors;
* Roles;
* Permissions;
* Tender Types;
* Stored-Value Accounts.

---

# P

## Pending

A POS Line Item status indicating that the line belongs to an editable transaction and has not yet been completed or removed.

Do not use `pending` as the name of an inventory commitment quantity.

For inventory, use **Reserved**.

## Permission

A stable machine-readable capability authorizing a class of action.

Canonical keys normally use:

```text
<domain>.<resource>.<action>
```

Examples include:

```text
catalog.product.create
inventory.adjustment.post
inventory.cost_correction.post
pos.transaction.complete
pos.discount.apply
```

Broad capabilities such as `pos.access` are allowed when the resource is the whole surface.

Permissions are evaluated in Store context through an Effective Store Membership. Permission, Authority Limit, and Approval remain separate checks.

Role names must not be used directly as application authorization logic.

## Physical placement

Optional metadata describing where merchandise may be found or displayed inside a Store.

Examples include:

* stockroom;
* front table;
* Staff Picks;
* cashwrap.

Physical Placement is not authoritative inventory ownership and does not change Store-level On Hand.

## POS

Point of sale.

The Domain responsible for checkout activity including:

* sale and return lines;
* pricing;
* Discounts;
* tax;
* Tenders;
* cash controls;
* receipts;
* transaction Completion;
* corrections.

## POS device

A physical or logical register assigned to one Store.

A POS Device is distinct from:

* User;
* POS Session;
* Cash Drawer;
* Business Day.

## POS line item

One sale, return, Open-Ring, or Stored-Value line within a POS Transaction.

A POS Line Item has:

* a direction;
* a Line Kind;
* a status;
* quantity;
* price and amount values;
* historical snapshots when completed.

## POS session

An accountability period within one Business Day.

A POS Session identifies:

* Store;
* POS Device;
* optional Cash Drawer;
* responsible user or shared-cashier policy;
* opening and closing timestamps;
* cash counts;
* expected cash;
* variance.

## POS transaction

A checkout container that may contain:

* sale lines;
* return lines;
* Product lines;
* Open-Ring Lines;
* Stored-Value lines;
* received Tenders;
* refunded Tenders.

A POS Transaction is not permanently classified as only a sale, return, exchange, or Stored-Value transaction.

## Post-Void

A new completed transaction that fully reverses an earlier Completed Transaction.

A Post-Void:

* leaves the original transaction completed;
* receives its own Receipt Number;
* reverses original line, tax, Tender, cost, inventory, and Stored-Value effects;
* uses original historical values;
* may be blocked when full reversal is no longer possible.

A Post-Void is distinct from Cancellation and Customer Return.

## Postable department

A Department that may be assigned to operational merchandise and completed transaction lines.

A Department used as an active Merchandise-Class default must remain postable. To make it reporting-only, first clear or reassign those defaults.

## Posted

A state indicating that an operational record’s authoritative effects have been committed.

Posted records are normally immutable.

Corrections use new reversing or adjusting records.

## Posting key

A unique idempotency identifier assigned to an inventory posting operation and reused on retry.

A Posting Key prevents the same Inventory Adjustment or other source operation from creating duplicate Inventory Ledger Entries or Stock-Balance changes.

## Price override

An authorized change that establishes a Selling Price different from the current Regular Price.

A Price Override occurs before Discounts.

Price-Override Variance is reported separately from Discounts.

## Price-override variance

The difference between Regular Price and approved Selling Price.

```text
price_override_variance =
regular_price - selling_price
```

## Product

The commercial item recognized as one catalog identity.

Examples include:

* one ISBN-defined book edition;
* one music release;
* one game package;
* one greeting-card design;
* one packaged café item;
* one service.

A Product:

* has one Canonical Identifier;
* owns relatively stable descriptive information;
* is not sold directly;
* has at least one Product Variant when sellable.

## Product request

A record of demand that the store may attempt to fulfil.

Initial types include:

```text
customer_request
staff_suggestion
```

A Product Request is not an Inventory Reservation or Purchase Order.

## Product type

A descriptive classification indicating what kind of Product the record represents.

Examples may include:

* book;
* recorded music;
* video;
* periodical;
* game;
* stationery;
* gift;
* café;
* service;
* other.

Product Type may guide forms, search, and metadata presentation.

It must not directly hard-code tax, inventory tracking, Return Policy, or Department.

## Product variant

The exact sellable and operational configuration of a Product.

The Product Variant is the primary record used for:

* SKU;
* price;
* purchasing;
* receiving;
* inventory;
* Department assignment;
* Tax Category;
* Return Policy;
* Discount eligibility;
* Inventory-Tracking Mode;
* POS product lines.

Every sellable Product has at least one Product Variant.

## Promotion

A rule defining qualification and reward behavior that creates realized Discounts.

A Promotion is distinct from the resulting POS Discount and Discount Allocation.

The detailed Promotion-definition model remains deferred.

## Purchase order

A store-specific record of intent to acquire merchandise from a Vendor.

A Purchase Order:

* contains Product-Variant-level lines;
* contributes to On Order;
* does not increase On Hand;
* may provide future supply for Customer Requests.

## Purchase-order allocation

A commitment of expected incoming quantity from a Purchase-Order Line to a Customer Request.

A Purchase-Order Allocation:

* does not create On Hand;
* does not create a physical Inventory Reservation;
* reduces future quantity available for other requests.

## Purchase-order line

One Product Variant and quantity ordered within a Purchase Order.

A Purchase-Order Line may retain snapshots of:

* description;
* SKU;
* Vendor item code;
* expected cost;
* returnability.

## Purchasable

A state indicating that a Product Variant may be included in ordinary purchasing workflows.

Purchasable is distinct from Active and Sellable.

## Purchasing

The Domain and workflow that records the Store’s intent to acquire merchandise.

Purchasing does not create inventory.

---

# Q

## Quantity-only adjustment

An Inventory Adjustment kind that changes physical quantity without supplying an arbitrary replacement cost.

For a positive valued balance, added or removed quantity uses the current aggregate valuation rules. Quantity added from negative toward zero creates no positive inventory asset value. Positive surplus created after crossing from negative or zero remains Unknown Cost unless an implemented retained-cost policy supplies a defensible rate.

A Quantity-Only Adjustment must not silently replace Moving Weighted-Average Cost.

## Quantity-tracked

An Inventory-Tracking Mode used when copies are operationally interchangeable.

Inventory is maintained through a Store-and-Product-Variant Stock Balance.

Individual Inventory Unit records are not created for each copy.

## Quarantine

An Unavailable inventory status used when merchandise must be isolated from normal sale until reviewed.

---

# R

## Rate

A fixed-precision percentage used for calculations such as tax or Discounts.

Rates require greater precision than integer cents.

Rounding must be deterministic and reproducible.

## Receipt

A Receiving-domain record representing one Vendor shipment or receiving event at one Store.

A Receipt:

* normally identifies one Store and Vendor;
* may include lines from several Purchase Orders;
* records delivered and accepted merchandise;
* creates inventory only when accepted quantity is posted.

Do not confuse a Receiving Receipt with a POS Receipt.

## Receipt line

One line within a Receiving Receipt.

A Receipt Line may:

* identify a Product Variant;
* reference one Purchase-Order Line;
* record Delivered, Accepted, and Rejected Quantity;
* establish acquisition cost;
* create Inventory Units where required.

## Receipt number

The store-unique identifier assigned to a POS Transaction only during successful Completion.

Cancelled, suspended, and failed transactions do not consume Receipt Numbers.

Receipt reprints retain the original Receipt Number.

## Receiving

The Domain and workflow that records what merchandise physically arrived and what the Store accepted.

Receiving is distinct from Purchasing and Inventory:

* Purchasing records intent;
* Receiving records delivery and acceptance;
* Inventory records physical ownership.

## Reconciliation

The later process of comparing ShelfStack’s expected operational totals with counted or external totals.

Examples include:

* expected cash versus counted cash;
* ShelfStack card Tenders versus terminal totals;
* Stored-Value totals;
* session totals versus Business-Day totals.

Reconciliation does not rewrite source Transactions or Tenders.

## Reconciliation adjustment

An explicit record acknowledging or categorizing a difference discovered during Reconciliation.

It does not alter the original completed source activity.

## Record owner

The Domain that is authoritative for a record’s lifecycle and business rules.

Other Domains may reference the record but should not duplicate its ownership.

## Redeem

To consume value from a Stored-Value Account as Tender for a POS Transaction.

See **Redemption**.

## Redemption

The use of Stored Value to settle a sale.

Redemption:

* decreases the Stored-Value Account balance;
* reduces the related liability;
* is a Tender;
* is not a Discount.

## Reference data

Organization-owned canonical master data loaded after Bootstrap.

Reference Data includes records such as:

* Departments;
* Merchandise Classes;
* Product Formats and Conditions;
* Tax Categories;
* Return, Discount, and Inventory-Adjustment Reasons;
* Identifier Sequences.

Reference-Data reruns create missing canonical rows and may update source-owned descriptive fields, but they preserve administrator-owned operational settings, never reset Identifier Sequences, and do not silently reactivate deactivated records.

## Refund basis

The rule used to establish the refund value for an Unlinked Return.

Examples may include:

* original sale;
* verified receipt;
* current price;
* lowest recent price;
* manual amount.

## Refund tender

A Tender with direction `refunded` that returns value to the customer.

## Regular price

The current normal unit price before a Price Override or Discount.

## Rejected quantity

Delivered merchandise the Store does not accept into inventory.

Rejected Quantity does not increase On Hand.

## Reload

The addition of value to an existing Stored-Value Account, funded through ordinary Tender.

## Removed line

A persisted POS Line Item removed before Completion.

A Removed Line:

* is excluded from totals;
* releases its Reservation;
* does not create completed revenue, tax, inventory, cost, or Tender effects.

## Reporting date

See **Business Date**.

## Reporting-only department

A non-postable Department used as a hierarchy or reporting parent.

A Reporting-Only Department cannot be assigned as the effective posting Department for ordinary merchandise or remain the active default of a Merchandise Class.

## Request

See **Product Request**.

## Reservation

See **Inventory Reservation**.

In architecture and schema documentation, avoid using Reservation for expected future supply.

Future supply is represented by a Purchase-Order Allocation.

## Reserved

Physically present inventory committed to an incomplete workflow.

Reserved inventory remains part of On Hand but is excluded from Available.

## Return

See **Customer Return**.

## Return disposition

The decision describing what the Store will do with returned merchandise.

Initial dispositions include:

```text
return_to_stock
inspection_required
damaged
return_to_vendor
discard
non_inventory
```

Return Disposition is distinct from Return Reason.

## Return reason

The explanation for why merchandise was returned.

Return Reason may suggest a default Return Disposition but does not determine it.

## Return to stock

A Return Disposition that restores returned physical merchandise to immediately sellable inventory.

## Return to Vendor

A workflow through which the Store sends inventory back to a Vendor.

Common abbreviation:

```text
RTV
```

Placing merchandise in an RTV status does not by itself complete the Vendor-return document or remove the merchandise from On Hand.

The complete RTV workflow remains open.

## Reversal

A later posted record that offsets an earlier completed or posted record.

The original record remains unchanged.

## Role

An Organization-owned administrative template that groups Permissions and may later provide default Authority Limits.

In the Phase 1 implementation, numeric authority is evaluated from Store-Membership overrides only until Role and Store defaults are explicitly implemented. Role names are never application authorization logic.

## RTV

See **Return to Vendor**.

---

# S

## Sale eligibility

The full operational result of evaluating whether a Product Variant or Inventory Unit may be sold under current Store and transaction conditions.

The evaluation may return:

* eligible;
* warnings;
* blockers;
* Approval requirements.

Full Sale Eligibility may include Catalog Readiness, Store context, inventory requirements, tax configuration, Business Day and POS Session state, Reservations, restrictions, and Approval requirements.

Do not use the term for Phase 2 Catalog readiness alone. `Catalog::SaleEligibility` is currently a narrower Catalog-readiness service despite its implementation name.

## Sale line

A POS Line Item with direction `sale`.

## Scan resolution

The process of interpreting a scanned or entered identifier.

The normal lookup hierarchy is:

1. Inventory Unit Identifier;
2. Product Variant SKU;
3. canonical Product Identifier;
4. Alternate Identifier;
5. descriptive search.

Equivalent UPC-A and leading-zero EAN-13 representations resolve to the same Product and participate in duplicate prevention during Product creation.

## Seed layer

One of the explicit installation-data stages used to create stable system and Organization data.

ShelfStack currently uses three layers:

1. Permission definitions through `db:seed`;
2. installation identity through Bootstrap;
3. Organization-owned Reference Data through `shelfstack:seed_reference_data`.

A Seed Layer must be safe to rerun according to its documented ownership and idempotency rules.

## Sellable

A state indicating that a Product or Product Variant may participate in ordinary sale workflows, subject to other eligibility checks.

Sellable is distinct from Active and Purchasable.

## Selling price

The unit price after any approved Price Override but before Discounts.

## Session

In POS documentation, prefer **POS Session**.

## Session Z report

The close report generated for one POS Session.

It is distinct from the Business-Day Z Report.

## ShelfStack identifier

An internally generated EAN-13 identifier using a ShelfStack-assigned restricted-circulation namespace.

## SKU

The canonical ShelfStack-generated `28` EAN-13 identifier for a Product Variant.

SKU identifies the exact sellable configuration.

Do not use SKU for an Inventory Unit. Use **Unit Identifier**.

## Snapshot

A stored historical copy of a value used at completion or posting.

Common snapshots include:

* description;
* Product Identifier;
* SKU;
* Department;
* Merchandise Class;
* Tax Category;
* Return Policy;
* Regular Price;
* Selling Price;
* Discount;
* tax;
* cost;
* Tender metadata;
* Approval context.

Current master-data changes do not modify Snapshots.

## Source record

The record that explains why an operational record exists.

Examples include:

* POS Line Item as the source of an Inventory Reservation;
* Receipt Line as the source of an Inventory Movement;
* Customer Request as the source of a Purchase-Order Allocation.

## Special order

**Deprecated as a separate architectural record type.**

Customer special-order demand is represented through a Customer Request, Purchase-Order Allocations, and Inventory Reservations.

The term may still appear in user-facing language.

## Staff suggestion

A Product Request created by staff recommending that buyers consider acquiring an item.

A Staff Suggestion:

* enters the Buyer-Review Queue;
* does not create a customer obligation;
* does not ordinarily reserve current inventory;
* does not ordinarily commit future supply to a customer.

## Stock balance

The authoritative current operational state for one Store and quantity-tracked Product Variant.

A Stock Balance may include:

* On Hand;
* Reserved;
* Unavailable;
* calculated Available;
* aggregate Inventory Value;
* cached Moving Weighted-Average Cost;
* Cost Quality;
* Last-Known Unit Cost and quality;
* concurrency lock version;
* later On Order and last-received information.

Posted Inventory Ledger Entries are the authoritative history. The Stock Balance is the authoritative current state and must remain reconcilable to that history. Reservations explain Reserved without changing On Hand.

At zero On Hand, current Inventory Value is zero, current Moving Weighted-Average Cost is `null`, and current Cost Quality is `unknown`. Zero or negative On Hand does not carry a positive inventory asset value.

## Store

The primary operational boundary for:

* inventory;
* purchasing destination;
* Receiving;
* Business Days;
* POS Sessions;
* POS Devices;
* Cash Drawers;
* tax rules;
* Receipt Numbers;
* cash accountability;
* Reconciliation.

Physical inventory belongs to a Store.

## Store context

The Store against which access, Permissions, Authority Limits, operating rules, and Store-scoped records are evaluated.

Selecting a default or active Store establishes navigation or execution context; it does not grant access. Access requires an Effective Store Membership.

## Store credit

A Stored-Value Account type representing value issued by the Store, commonly as a Customer Return refund.

## Store membership

The record granting one installation-global User access to one Store through one Role and effective period.

A Store Membership may also contain Store-specific Authority-Limit overrides.

Rules include:

* `user_id` and `store_id` are immutable after creation;
* effective dates are evaluated using the Store-local date unless a workflow specifies another date;
* a deactivated or out-of-range membership grants no Store access;
* a User’s default Store is not a Store Membership and does not grant access.

## Store-level inventory

The governing rule that inventory quantity and ownership are authoritative by Store rather than by internal areas such as stockroom or sales floor.

## Stored value

Customer-held value maintained as an account balance rather than physical cash or ordinary merchandise.

Initial types are:

```text
gift_card
store_credit
trade_credit
```

## Stored-value account

The account holding Gift Card, Store Credit, or Trade Credit value.

A Stored-Value Account:

* receives a canonical `21` EAN-13 identifier;
* may have an Alternate Identifier;
* may cache its current balance;
* is governed by Stored-Value Entries.

## Stored-value entry

An append-only ledger record that changes or explains a Stored-Value Account balance.

Examples include:

* issued;
* reloaded;
* redeemed;
* refunded;
* issuance reversed;
* redemption reversed;
* manual adjustment.

## Stored-value ledger

The authoritative append-only history of a Stored-Value Account.

## Suspended transaction

A POS Transaction temporarily set aside for later recall.

A Suspended Transaction:

* retains its Inventory Reservations;
* does not automatically expire;
* may be recalled only at the same Store;
* cannot be suspended with unresolved Tender activity.

---

# T

## Tax amount

The calculated tax associated with a POS Line Item or tax component.

Tax amounts are stored in integer cents.

## Tax category

A classification describing what an item is for tax purposes.

A Tax Category is distinct from the actual Store Tax Rate.

Examples may include:

* printed books;
* periodicals;
* prepared food;
* packaged food;
* general merchandise;
* services;
* exempt merchandise;
* Stored-Value issuance.

## Tax component

One historical jurisdictional or rate component contributing to the tax on a completed POS Line Item.

The sum of Tax Components equals the line’s Tax Amount.

## Tax exemption

Evidence and authorization establishing that some or all of a transaction is exempt from otherwise applicable tax.

Tax Exemptions may be:

* reusable and customer-linked;
* one-time and transaction-specific.

Completed transactions snapshot the exemption evidence used.

## Tax rate

An effective-dated percentage configured for a Store and jurisdiction.

Tax Rate is distinct from Tax Category.

## Tax rule

A Store-specific rule connecting a Tax Category to one or more Tax Rates and calculation behavior.

## TBO

**Deprecated.**

Earlier shorthand for “to be ordered.”

Use:

* Staff Suggestion for non-customer purchasing recommendations;
* Customer Request for customer demand;
* Buyer-Review Queue for unresolved demand.

## Tender

A method by which a POS Transaction is settled.

Examples include:

* cash;
* card;
* check;
* Stored Value;
* another configured Tender Type.

Tender is distinct from revenue.

## Tender direction

The direction in which value moves for a POS Tender.

Initial values are:

```text
received
refunded
```

## Tender type

A configurable definition controlling how a Tender behaves.

A Tender Type may define:

* payment eligibility;
* refund eligibility;
* over-tender behavior;
* change behavior;
* required reference information;
* activation status.

## Total amount

For a POS Line Item:

```text
total_amount = net_amount + tax_amount
```

## Trade credit

A Stored-Value Account type issued in exchange for merchandise acquired from a customer.

Trade Credit is expected to participate in the future Buyback workflow.

## Transaction

In POS documentation, prefer **POS Transaction**.

## Transaction discount

A Discount applied at transaction scope and allocated among eligible lines.

## Transfer

See **Inventory Transfer**.

---

# U

## Unavailable

Physical inventory that is part of On Hand but cannot currently be sold.

Examples include:

* Inspection;
* damaged;
* RTV;
* quarantine.

Unavailable inventory reduces Available.

## Unfulfilled request quantity

The portion of a Product Request not yet covered by confirmed in-house Reservations or active Purchase-Order Allocations.

```text
unfulfilled request quantity =
requested quantity
- confirmed in-house reservations
- active purchase-order allocations
```

## Unknown cost

A cost state in which ShelfStack lacks a defensible complete valuation basis.

Unknown Cost is represented explicitly through `null` monetary values where the amount cannot be known and through `cost_quality = unknown`. It must never be treated as zero.

Positive On Hand with Unknown Cost has unknown complete Inventory Value. Confirmed Zero Cost is a separate known state.

## Unit identifier

The canonical generated `27` EAN-13 identifier for one Inventory Unit.

A Unit Identifier is:

* organization-wide;
* unique;
* immutable;
* never reused;
* independent of Store and status.

## Unit-specific price

A price assigned to one exact Inventory Unit that overrides the normal Product Variant price.

## Unlinked return

A Customer Return that does not reference an original ShelfStack sale line.

An Unlinked Return requires explicit information such as:

* Return source;
* Refund Basis;
* Product or Product Variant;
* Return Reason;
* Return Disposition;
* tax treatment;
* Approval where required.

## UPC-A

A 12-digit trade identifier.

ShelfStack recognizes equivalence between a UPC-A and its corresponding leading-zero EAN-13 representation where applicable.

## User

An authenticated person whose identity is retained on operational activity.

Under the one-Organization-per-installation invariant, Users are installation-global. A User does not belong to a Store and does not require an `organization_id` foreign key. Store access exists only through Store Memberships.

A User may exist without any Store Membership but cannot perform Store-scoped actions until access is granted. Shared cashier accounts are not permitted for accountable actions.

---

# V

## Variant

See **Product Variant**.

## Variant structure

The way a Product’s Product Variants are organized.

Architectural values are:

```text
single
options
matrix
```

Phase 2 implements only `single`. `options` and `matrix` remain deferred and must not be treated as currently supported merely because the architectural values are documented.

## Vendor

An organization or party from which the Store purchases merchandise.

## Vendor source

The relationship describing how a Vendor supplies a Product Variant.

A Vendor Source may contain:

* Vendor item code;
* Vendor identifier;
* expected cost;
* discount;
* ordering information;
* returnability;
* preferred-source status;
* last ordered date;
* last received date.

## Void

Avoid using the unqualified term.

Use:

* **Cancellation** for an open transaction stopped before Completion;
* **Post-Void** for a completed reversing transaction;
* processor void for an external payment-terminal operation, where applicable.

A Completed Transaction does not change to a `voided` status.

---

# W

## Warning

A validation result that informs the user of a potentially problematic condition but does not necessarily block the workflow.

Examples include:

* negative inventory;
* missing cost;
* invalid identifier checksum;
* stale availability information.

A Warning is distinct from a Blocker or Approval Requirement.

## Weighted merchandise

Merchandise sold or inventoried using fractional quantities or measured weight.

Weighted merchandise is deferred from the initial scope.

## Workflow

A defined sequence of user actions, validations, state changes, and posted effects crossing one or more Domains.

---

# X

## X report

A non-closing operational snapshot.

ShelfStack may produce:

* Session X Reports;
* Business-Day X Reports.

An X Report does not close or reconcile the underlying period.

---

# Z

## Z report

A closing report for a POS Session or Business Day.

ShelfStack distinguishes:

* Session Z Report;
* Business-Day Z Report.

## Z-report number

A sequential Store-specific identifier assigned to a closed Business Day or POS Session, according to the applicable sequence.

A Z-Report Number is distinct from the Business Date and actual timestamps.

---

# Deprecated and superseded terminology

| Deprecated term                   | Preferred term or model                                |
| --------------------------------- | ------------------------------------------------------ |
| Display Category                  | Merchandise Class                                      |
| Display-category hierarchy        | Merchandise-Class hierarchy                            |
| Pending inventory                 | Reserved inventory                                     |
| Special-order record              | Customer Request plus allocations and Reservations     |
| TBO record                        | Staff Suggestion or Customer Request                   |
| Item SKU for exact copy           | Unit Identifier                                        |
| Voided completed transaction      | Post-Void transaction                                  |
| Returned original sale line       | New linked return line                                 |
| Stock location as inventory owner | Store-level inventory plus optional Physical Placement |
| On-order Reservation              | Purchase-Order Allocation                              |
| Manager role check                | Permission, Authority Limit, and Approval              |
| Gift-card sale revenue            | Stored-Value liability Issuance                        |

---

# Frequently confused distinctions

## Product versus Product Variant versus Inventory Unit

```text
Product
= commercial identity

Product Variant
= exact sellable and operational configuration

Inventory Unit
= one exact physical copy
```

## Product Request versus Purchase-Order Allocation versus Inventory Reservation

```text
Product Request
= demand

Purchase-Order Allocation
= future supply committed to demand

Inventory Reservation
= physically present supply committed to a workflow
```

## Purchasing versus Receiving versus Inventory

```text
Purchasing
= intent to acquire

Receiving
= delivery and acceptance

Inventory
= current physical ownership
```

## On Hand versus Reserved versus Unavailable versus Available versus On Order

```text
On Hand
= physical merchandise present and owned

Reserved
= present merchandise committed

Unavailable
= present merchandise not sellable

Available
= present merchandise currently sellable

On Order
= expected merchandise not yet received
```

## Cancellation versus Customer Return versus Post-Void

```text
Cancellation
= stops an incomplete transaction

Customer Return
= customer-facing reversal after sale

Post-Void
= full administrative reversal of a completed transaction
```

## Regular Price versus Selling Price versus Discount

```text
Regular Price
= normal current price

Selling Price
= price after Price Override

Discount
= reduction applied after Selling Price
```

## Return Reason versus Return Disposition

```text
Return Reason
= why the customer returned it

Return Disposition
= what the Store will do with it
```

## Permission versus Authority Limit versus Approval

```text
Permission
= may the user perform this class of action?

Authority Limit
= how much may the user perform or approve?

Approval
= who authorized this particular restricted action?
```

## Business Date versus timestamp versus Z-Report Number

```text
Business Date
= reporting date assigned to the operating period

Timestamp
= when an event actually occurred

Z-Report Number
= sequential identifier of the close
```

## Revenue versus Tender

```text
Revenue
= what the Store earned from commercial activity

Tender
= how the customer settled the balance
```

## Stored-Value Issuance versus Redemption

```text
Issuance
= creates or increases liability

Redemption
= consumes liability as Tender
```
