# ShelfStack System Overview

**Status:** Governing architectural overview **Purpose:** Define what ShelfStack is, the business functions it supports, its principal domain boundaries, its central architectural decisions, how its domains interact, and the intended implementation sequence.

## 1.1 Purpose of this document

ShelfStack is an integrated retail operations system for independent bookstores and similar specialty retailers.

It is intended to support the complete operational path from defining merchandise through purchasing, receiving, inventory management, sale, return, stored value, cash accountability, and reporting.

ShelfStack is not designed as one undifferentiated application. Catalog, purchasing, inventory, point of sale, authorization, stored value, and reporting have different responsibilities and preserve different kinds of history. The system therefore separates these concerns into related business domains with clear ownership boundaries.

This overview establishes the governing structure for those domains.

Detailed entity definitions, field lists, status transitions, permissions, and workflow rules belong in the Domain Specifications and Schema Dictionary.

---

## 1.2 What ShelfStack is

ShelfStack is a store-centered retail management platform designed for merchandise and services commonly carried by an independent bookstore, including:

* new and used books;  
* recorded music;  
* video;  
* periodicals;  
* games;  
* stationery and paper goods;  
* gifts and sidelines;  
* café merchandise;  
* services and fees;  
* stored value;  
* individually tracked collectible, signed, consignment, or used items.

ShelfStack connects the major operating functions of the business while preserving the distinctions among them.

At a high level, the system allows an organization to:

1. define stores, users, roles, permissions, and operating policies;  
2. maintain a shared catalog of products and sellable variants;  
3. classify merchandise for financial, merchandising, tax, and operational purposes;  
4. maintain vendor sources and create purchase orders;  
5. receive merchandise and establish inventory quantities and cost;  
6. track inventory independently for each store;  
7. reserve merchandise for incomplete transactions;  
8. sell, return, exchange, and correct transactions;  
9. manage tenders, cash drawers, business days, and POS sessions;  
10. issue, redeem, refund, and adjust stored value;  
11. preserve reliable historical transaction and inventory records;  
12. produce operational, financial, tax, inventory, and reconciliation reports.

ShelfStack should impose strong controls where activity affects:

* money;  
* inventory ownership;  
* tax;  
* customer liability;  
* authorization;  
* historical reporting.

Routine bookstore activity should remain fast and practical.

---

## 1.3 Operating model

### 1.3.1 Organization

A ShelfStack installation represents one operating organization.

The organization is the shared administrative and catalog boundary for:

* products and product variants;  
* generated identifiers;  
* departments;  
* display categories;  
* merchandise classes;  
* formats and conditions;  
* tax categories;  
* vendors;  
* roles and permissions;  
* tender definitions;  
* stored-value accounts;  
* shared policies and defaults.

The initial design does not require a general-purpose multi-tenant architecture.

### 1.3.2 Stores

An organization may operate one or more stores.

A store is the primary operational boundary for:

* inventory balances;  
* inventory availability;  
* purchasing destination;  
* receiving;  
* receipt numbering;  
* business days;  
* POS sessions;  
* POS devices;  
* cash drawers;  
* tax rates and rules;  
* tender availability;  
* cash accountability;  
* reconciliation.

Products and configuration may be shared across the organization, but physical inventory belongs to a specific store.

### 1.3.3 Users and store access

Users do not receive implicit access to every store.

Access is established through a store membership connecting:

* one user;  
* one store;  
* one role;  
* effective dates;  
* optional store-specific authorization limits.

A user may have different roles or authority limits at different stores.

Role names are administrative templates. Application logic evaluates granular permissions and numeric authorization limits rather than hard-coded names such as “Manager” or “Cashier.”

A user’s default store is a navigation preference and does not grant access.

---

## 1.4 Supported business functions

## 1.4.1 Catalog and product management

ShelfStack maintains the records required to identify, describe, sell, purchase, receive, and report merchandise.

It supports:

* universal product records;  
* sellable product variants;  
* exact inventory units where individual tracking is required;  
* externally assigned trade identifiers;  
* ShelfStack-generated internal identifiers;  
* formats;  
* product conditions;  
* variant options and matrices;  
* product type;  
* sale eligibility;  
* inventory-tracking mode;  
* current regular price;  
* return and discount behavior.

The catalog describes what an item is.

It does not own the quantity currently held by a store or the historical values used in completed transactions.

## 1.4.2 Classification and financial categorization

ShelfStack uses a hierarchical merchandise-class structure for merchandising, shelving, browsing, and product classification.

The hierarchy may contain levels such as:

```
Primary merchandise class
└── Secondary merchandise class
    └── Minor merchandise class
```

Examples include:

```
Books
└── Nonfiction
    └── History
```

and:

```
Stationery, Paper Goods & Correspondence
└── Greeting Cards
    └── Birthday
```

A merchandise class may provide:

* a default department;  
* shelving guidance;  
* merchandising notes;  
* reporting position;  
* parent and child relationships.

The merchandise class identifies where and how an item is merchandised. It does not itself define financial posting or operating policy.

The department supplies the default financial and operational configuration for merchandise assigned to it. Department defaults may include:

* general-ledger account mappings;  
* tax category;  
* return policy;  
* maximum merchandise discount;  
* other department-level operating policies.

The normal resolution is:

```
Product or variant override
→ merchandise-class default department
→ department defaults
```

Product and variant records may override department-derived defaults where ShelfStack explicitly supports an override.

Certain attributes remain explicit on the product or variant and should not be inferred solely from department membership. These include:

* canonical product identity;  
* product format;  
* product type;  
* variant SKU;  
* inventory-tracking mode;  
* current regular price;  
* exact-copy condition;  
* exact-copy cost;  
* vendor sourcing.

This model avoids maintaining separate display-category and merchandise-class hierarchies that describe substantially the same merchandise organization.

## 1.4.3 Vendors and purchasing

ShelfStack records the store’s intent to acquire merchandise from vendors.

The purchasing domain is expected to support:

* vendors;  
* vendor-specific product or variant references;  
* vendor item codes;  
* expected costs and discounts;  
* purchase orders;  
* purchase-order lines;  
* quantities ordered;  
* quantities cancelled;  
* quantities received;  
* customer-request commitments;  
* expected delivery information;  
* buyer notes.

The detailed purchasing workflow remains under review.

Earlier designs introduced more statuses, allocations, sourcing layers, and exception workflows than may be operationally necessary. The implementation should therefore begin with the simplest model that can support:

* one purchase order for one store and vendor;  
* variant-level order lines;  
* partial receipt;  
* combined shipments;  
* customer-request allocations;  
* buyer review of unfulfilled demand;  
* later closure or cancellation of unfulfilled quantity.

Purchasing records acquisition intent.

Creating or updating a purchase order does not change on-hand inventory.

Open purchase-order quantity contributes to `on_order`, but it does not become physically available until merchandise is received and accepted.

## 1.4.4 Receiving

Receiving records merchandise physically delivered to a store and the quantity the store accepts.

A receipt represents a vendor shipment or receiving event.

One shipment may contain merchandise from several purchase orders. A receipt therefore does not belong exclusively to one purchase order.

Instead:

* the receipt header identifies the store, vendor, shipment, and receiving event;  
* each receipt line may reference the purchase-order line it fulfils;  
* different receipt lines on the same receipt may reference different purchase orders;  
* a receipt line may remain unlinked when merchandise was received without a prior purchase-order line and the workflow permits it.

When one delivered product fulfils quantities from several purchase-order lines, ShelfStack may record separate receipt lines for each purchase-order allocation even when staff sees them grouped together in the receiving interface.

Receiving is responsible for recording:

* delivered quantity;  
* accepted quantity;  
* rejected quantity;  
* damaged quantity;  
* inspection quantity;  
* actual acquisition cost;  
* receiving discrepancies;  
* exact inventory units where individual tracking applies.

Only accepted merchandise enters store inventory.

Accepted merchandise may initially enter one of several availability states:

* sellable;  
* inspection required;  
* damaged;  
* awaiting return to vendor;  
* another authorized unavailable state.

Rejected merchandise does not increase on-hand inventory.

The detailed receipt-status and correction workflow remains under review. It should preserve posted inventory history without creating unnecessary receiving stages.

## 1.4.5 Inventory management

ShelfStack tracks physical inventory at the store level.

The store is the authoritative ownership boundary. ShelfStack does not initially require staff to record ordinary movement among receiving, stockroom, sales floor, front table, cashwrap, or other areas within the same store.

For quantity-tracked merchandise, ShelfStack maintains:

* `on_hand`;  
* `reserved`;  
* `unavailable`;  
* `available`;  
* `on_order`.

The governing relationship is:

```
available = on_hand - reserved - unavailable
```

These quantities have distinct meanings:

* **On hand** represents merchandise physically present and owned by the store.  
* **Reserved** represents in-house merchandise committed to an incomplete transaction or confirmed customer request.  
* **Unavailable** represents physical merchandise that cannot currently be sold.  
* **Available** represents merchandise currently sellable without consuming reserved or unavailable stock.  
* **On order** represents merchandise expected from open purchase orders but not yet accepted into inventory.

For individually tracked merchandise, ShelfStack records the exact physical unit, including its:

* store;  
* unit identifier;  
* condition;  
* acquisition cost;  
* selling price where applicable;  
* availability status;  
* active reservation;  
* acquisition source;  
* sale history.

Inventory movements explain changes in physical inventory.

Reservations and purchase-order allocations explain commitments of present or future supply.

Customer requests, staff suggestions, purchase orders, receipts, inventory balances, and reservations are related but remain separate records because they represent different stages of the acquisition and fulfilment cycle.

The inventory design should remain intentionally simple. Additional workflows such as detailed counts, inter-store transfers, returns to vendor, and location tracking should be added only when their operating requirements are defined.

## 1.4.6 Point of sale

The POS domain supports:

* barcode scanning;  
* product and variant search;  
* exact-unit scanning;  
* sale lines;  
* return lines;  
* open-ring lines;  
* stored-value lines;  
* quantity changes;  
* pending-line removal;  
* suspension and recall;  
* price overrides;  
* line and transaction discounts;  
* promotions;  
* tax calculation;  
* tax exemptions;  
* split tender;  
* cash;  
* standalone card processing;  
* stored-value tender;  
* receipts and gift receipts;  
* exchanges;  
* manager approvals;  
* transaction cancellation;  
* full post-void correction.

A POS transaction is a checkout container.

It may contain both sale and return activity. It is not permanently classified as only a sale, return, exchange, or stored-value transaction.

## 1.4.7 Stored value

ShelfStack supports three stored-value account types:

* gift card;  
* store credit;  
* trade credit.

These account types may share technical infrastructure but remain distinct for:

* policy;  
* accounting;  
* customer communication;  
* reporting.

Stored-value activity includes:

* issuance;  
* reload;  
* redemption;  
* refund;  
* reversal;  
* manual adjustment.

Each stored-value account receives a canonical ShelfStack-generated identifier unless the implementation is explicitly configured otherwise.

The generated identifier:

* is a valid EAN-13;  
* begins with the restricted-circulation prefix `21`;  
* is unique across the organization;  
* is immutable;  
* is never reused;  
* may be printed or encoded on a physical card;  
* may be scanned at POS.

A user may also enter an alternate identifier, such as:

* a preprinted card number;  
* a migrated legacy gift-card number;  
* an externally supplied certificate reference;  
* another organization-approved lookup value.

Both the canonical `21` identifier and the alternate identifier may resolve the same stored-value account.

The canonical identifier provides ShelfStack with a consistent internal public reference even when the physical card uses an externally assigned number.

Stored-value balances are governed by an append-only ledger.

The current balance may be cached for performance, but the ledger remains the authoritative history.

Gift-card issuance creates a liability rather than ordinary merchandise revenue.

Stored-value redemption is a tender rather than a discount.

## 1.4.8 Buyback

ShelfStack’s product, inventory-unit, cash-movement, and trade-credit structures provide the foundation for customer buyback.

The detailed buyback workflow remains a separate design area.

It is expected eventually to support:

* item evaluation;  
* exact-copy condition;  
* offer calculation;  
* cash or trade-credit settlement;  
* creation of used inventory;  
* acquisition cost;  
* approval limits;  
* seller and legal requirements where applicable.

Buyback should be treated as merchandise acquisition, not as an ordinary customer return.

## 1.4.9 Reporting and reconciliation

ShelfStack produces operational and financial information from completed transactions and posted ledgers.

Reporting includes:

* gross sales;  
* price-override variance;  
* discounts;  
* returns;  
* post-voids;  
* net sales;  
* tax;  
* tenders received;  
* tenders refunded;  
* cash movements;  
* stored-value activity;  
* units;  
* cost of goods sold;  
* gross margin;  
* inventory quantities;  
* inventory valuation;  
* purchase orders;  
* receiving;  
* suspended transactions;  
* reservations;  
* approvals;  
* exceptions;  
* cash variances.

Operational close and reconciliation are separate.

A POS session or business day may close with a documented variance and be reconciled later.

Reconciliation records differences without rewriting the completed source transactions.

---

## 1.5 Major domain boundaries

## 1.5.1 Organization, stores, and authorization

This domain owns:

* organization;  
* stores;  
* users;  
* store memberships;  
* roles;  
* permissions;  
* authority limits;  
* POS devices;  
* cash drawers;  
* approvals.

It determines:

* who may act;  
* at which store;  
* under which permissions;  
* within which monetary or percentage limits.

It does not own the commercial or inventory records created by those actions.

## 1.5.2 Catalog and products

This domain owns:

* product identity;  
* canonical product identifiers;  
* product metadata;  
* product variants;  
* variant SKUs;  
* variant options;  
* product formats;  
* product conditions;  
* inventory-tracking mode;  
* sale-eligibility inputs;  
* current regular price;  
* product and variant lifecycle.

It determines what the item is and what sellable configuration exists.

It does not own store inventory quantity or completed transaction history.

## 1.5.3 Classification and configuration

This domain owns:

* departments;  
* display categories;  
* merchandise classes;  
* tax categories;  
* store tax rates and rules;  
* discount reasons;  
* return policies;  
* return reasons;  
* cash-movement types;  
* tender types.

It provides effective classifications and policy defaults to the catalog, inventory, POS, and reporting domains.

## 1.5.4 Vendors and purchasing

This domain owns:

* vendors;  
* vendor sources;  
* purchase orders;  
* purchase-order lines;  
* ordered and cancelled quantities;  
* expected cost;  
* expected delivery;  
* purchasing history.

It determines what the store intends to acquire.

## 1.5.5 Receiving and inventory

This domain owns:

* receipts;  
* receipt lines;  
* stock balances;  
* inventory units;  
* inventory movements;  
* inventory reservations;  
* inventory adjustments;  
* availability states;  
* moving weighted-average cost.

It is the authoritative source for what physical merchandise each store possesses and what portion is currently sellable.

## 1.5.6 Point of sale

This domain owns:

* open, suspended, completed, and cancelled transactions;  
* line items;  
* discounts and allocations;  
* tax components;  
* tenders;  
* cash movements;  
* business days;  
* sessions;  
* receipts;  
* POS approvals;  
* transaction corrections.

It coordinates catalog, classification, inventory, authorization, stored value, and reporting during checkout.

It does not replace those domains.

## 1.5.7 Stored value

This domain owns:

* stored-value accounts;  
* account balances;  
* immutable ledger entries;  
* issuance;  
* reload;  
* redemption;  
* refund;  
* adjustment;  
* reversal.

Stored-value activity may originate in POS, returns, or future buyback workflows, but its balance remains governed by its own ledger.

## 1.5.8 Reporting and reconciliation

This domain consumes:

* completed POS snapshots;  
* posted inventory movements;  
* stored-value entries;  
* purchase orders and receipts;  
* cash counts and movements;  
* session and business-day records;  
* approvals and exceptions.

It does not modify operational source records.

---

## 1.6 Central architectural decisions

## 1.6.1 Product, variant, and inventory unit are distinct

ShelfStack uses three merchandise levels:

```
Product
└── Product Variant
    └── Inventory Unit, when individually tracked
```

A product represents the commercial item.

A variant represents the exact configuration that is sold, purchased, priced, taxed, and tracked operationally.

An inventory unit represents one exact physical copy when individual identity matters.

Ordinary interchangeable stock is represented by a store-and-variant balance rather than one unit record per copy.

## 1.6.2 Every product has one canonical identifier

A product stores one canonical primary trade or local identifier.

Examples include:

* ISBN-13;  
* UPC-A;  
* EAN-13;  
* another approved trade identifier;  
* ShelfStack-generated local identifier.

A valid ISBN-10 entered or scanned is normalized to its equivalent ISBN-13 before storage and lookup.

ISBN-10 is not stored as an alternate identifier merely to support ISBN-10 search.

UPC-A and its equivalent leading-zero EAN-13 representation resolve to the same product where applicable.

Invalid checksums produce warnings but do not necessarily block storage.

## 1.6.3 ShelfStack identifiers have separate namespaces

ShelfStack-generated identifiers use separate restricted-circulation EAN-13 namespaces:

```
21 — stored-value account
27 — exact inventory unit
28 — product variant
29 — locally identified product
```

These identifiers are:

* organization-wide;  
* unique;  
* immutable;  
* never reused;  
* scannable;  
* generated with valid EAN-13 check digits.

They do not encode mutable information such as:

* store;  
* department;  
* merchandise class;  
* condition;  
* cost;  
* price;  
* date;  
* account balance;  
* status;  
* parent-child relationship.

### Stored-value identifiers

A stored-value account receives a canonical `21` identifier.

The account may additionally hold an alternate identifier supplied by a user or external source.

The alternate identifier is a lookup value and does not replace the canonical account identity.

### Inventory-unit identifiers

An individually tracked physical copy receives a `27` unit identifier.

### Product-variant identifiers

Every product variant receives a `28` SKU.

### Local product identifiers

A product without a usable external trade identifier receives a `29` product identifier.

The separation of namespaces allows ShelfStack to determine the type of record represented by a scanned internally generated barcode without encoding operational attributes into the identifier.

## 1.6.4 Inventory is authoritative at the store level

ShelfStack does not initially require staff to track ordinary movement among receiving, stockroom, sales floor, front table, cashwrap, or other areas within one store.

These may later be represented as optional merchandising or placement metadata.

They do not determine authoritative inventory quantity.

Movement between stores is an inventory transfer because the authoritative store owner changes.

## 1.6.5 Requests, allocations, and reservations are explicit records

ShelfStack distinguishes among:

* a product request;  
* an allocation of future supply;  
* a reservation of in-house inventory.

These concepts participate in the same fulfilment process but represent different business facts.

### Product request

A product request records demand that should be reviewed or fulfilled.

A request may originate from:

* a customer;  
* a staff member;  
* a future automated replenishment process.

Initial request types should include:

```
customer_request
staff_suggestion
```

A customer request indicates that the store is attempting to supply merchandise for a particular customer.

A staff suggestion indicates that a buyer should consider purchasing an item, but it does not by itself commit stock to a customer.

A product request may identify:

* store;  
* customer, where applicable;  
* product;  
* product variant, where known;  
* requested quantity;  
* priority;  
* needed-by date;  
* requesting user;  
* notes;  
* current status.

### Inventory reservation

An inventory reservation commits merchandise already physically present at the store.

For a customer request, an in-house reservation is created only after a user physically locates the merchandise and confirms the allocation.

This prevents the system from treating an apparently available database quantity as a confirmed customer hold when the item cannot actually be found.

For quantity-tracked merchandise, the reservation identifies:

* store;  
* variant;  
* quantity;  
* customer request.

For individually tracked merchandise, the reservation identifies the exact inventory unit.

A reservation:

* reduces available inventory;  
* does not reduce on hand;  
* identifies the request or transaction holding the item;  
* remains until fulfilled, released, or cancelled.

### Purchase-order allocation

A purchase-order allocation commits expected incoming merchandise to a customer request.

It does not create on-hand or reserved inventory because the merchandise has not yet been received.

The allocation identifies:

* customer request;  
* purchase-order line;  
* allocated quantity;  
* current allocation status.

Staff suggestions do not ordinarily create purchase-order allocations that make incoming stock unavailable to other customers.

### Customer-request fulfilment sequence

ShelfStack evaluates a customer request through the following sequence.

#### 1\. In-house inventory

ShelfStack identifies potentially available store inventory.

A user physically locates the merchandise and confirms the allocation.

ShelfStack then creates an inventory reservation linked to the request.

#### 2\. Uncommitted on-order merchandise

When sufficient in-house merchandise is not reserved, ShelfStack searches open purchase-order quantities that have not already been committed to earlier requests.

An authorized user may allocate incoming quantity to the customer request.

Earlier requests should normally receive priority unless an authorized user changes the allocation.

#### 3\. Buyer-review queue

Any requested quantity that is neither reserved from in-house inventory nor allocated from an existing purchase order appears in a buyer-review queue.

A buyer may:

* select or create a vendor source;  
* add the item to a purchase order;  
* defer the request;  
* decline the request;  
* request more information;  
* contact the customer.

The remaining quantity requiring buyer action is:

```
requested quantity
- confirmed in-house reservation
- allocated on-order quantity
= unfulfilled request quantity
```

### Staff suggestions

Staff suggestions use the same buyer-review process but do not reserve current inventory or commit future inventory to a customer.

They represent purchasing recommendations rather than customer obligations.

### Governing distinction

```
Request
= demand the store may attempt to fulfil

Purchase-order allocation
= future supply committed to a request

Inventory reservation
= physically present supply committed to a request or POS transaction

Purchase order
= intent to acquire supply

Receipt
= supply physically delivered and accepted
```

Keeping these records separate provides traceability without requiring separate special-order, customer-request, and TBO systems.

## 1.6.6 Availability and possession are separate

Merchandise may remain physically present while being unavailable for sale.

Examples include:

* inspection;  
* damaged;  
* RTV holding;  
* quarantine;  
* in-transfer handling.

For quantity-tracked merchandise, unavailable quantity remains part of on hand.

For individually tracked merchandise, availability is determined from the unit’s status and active reservation.

## 1.6.7 Purchasing and receiving are different events

A purchase order records the store’s intention to acquire merchandise.

It contributes to on-order quantity but does not affect on-hand inventory.

A receipt records merchandise physically delivered to and accepted by the store.

It creates inventory only when accepted quantities are posted.

A receipt may fulfil merchandise from more than one purchase order.

The relationship is maintained at the receipt-line level:

```
Receipt
├── Receipt line → Purchase-order line from PO 1
├── Receipt line → Purchase-order line from PO 2
├── Receipt line → Purchase-order line from PO 2
└── Unlinked receipt line, where permitted
```

The receipt header normally identifies one:

* store;  
* vendor;  
* shipment or vendor document;  
* receiving event.

Each receipt line may reference one purchase-order line.

When one delivered product fulfils several purchase-order lines, separate receipt lines may be created for each allocation. This avoids introducing a more complicated many-to-many receipt-allocation model unless later workflows require it.

Purchasing records expected supply.

Receiving records accepted supply.

Inventory records current physical ownership.

Customer-request allocations determine whether some current or expected supply is committed to particular demand.

## 1.6.8 Completed transactions are immutable

A completed POS transaction is not edited, deleted, changed to returned, or changed to voided.

Corrections use new linked records:

* return lines;  
* refund tenders;  
* post-void transactions;  
* stored-value reversals;  
* inventory reversals;  
* reconciliation adjustments.

The original completed record remains available for audit and reporting.

## 1.6.9 Transaction cancellation and post-void are different

An open transaction may be cancelled before completion.

Cancellation releases provisional effects and creates no completed sale, inventory, tax, tender, or stored-value posting.

A post-void is a new completed transaction reversing an earlier completed transaction.

It copies and reverses the exact original:

* prices;  
* discounts;  
* tax;  
* cost;  
* inventory;  
* tenders;  
* stored value.

Current configuration is not recalculated.

## 1.6.10 POS completion is atomic and idempotent

Completing a POS transaction is one coordinated operation.

The system either completes all required effects or completes none of them.

Completion includes:

* final line validation;  
* discount allocation;  
* tax calculation;  
* tender validation;  
* reservation conversion;  
* inventory posting;  
* inventory-unit status changes;  
* stored-value posting;  
* cost snapshotting;  
* receipt-number assignment;  
* transaction completion.

Repeated submission of the same completion request must not create duplicate postings.

## 1.6.11 Price overrides and discounts remain separate

A price override establishes the selling price.

A discount reduces the selling price afterward.

ShelfStack reports separately:

* regular price;  
* selling price;  
* price-override variance;  
* discount;  
* net merchandise amount.

This preserves meaningful margin and authorization reporting.

## 1.6.12 Return reason and disposition remain separate

Return reason explains why the customer returned the item.

Return disposition records what the store will do with it.

Possible dispositions include:

* return to stock;  
* inspection;  
* damaged;  
* return to vendor;  
* discard;  
* non-inventory.

A return reason may suggest a default disposition but does not determine the actual result.

## 1.6.13 Business day, session, device, and drawer are distinct

ShelfStack distinguishes:

* business day;  
* POS session;  
* POS device;  
* cash drawer;  
* Z report.

### Business day

A business day is the store-wide operational and reporting period.

It records:

* store;  
* reporting date;  
* opening timestamp;  
* closing timestamp;  
* reconciliation timestamp;  
* status;  
* sequential business-day or Z-report number.

The exact policy for assigning the reporting date remains undecided.

Possible policies include:

* the calendar date on which the business day opens;  
* the operating date selected when the day is opened;  
* the calendar date on which the business day closes;  
* another store-configured rule.

ShelfStack should store the reporting date explicitly rather than derive it later from timestamps.

This allows the date-assignment policy to be changed or configured without losing clarity about how activity was reported.

### Z-report number

The business-day close receives a sequential store-specific Z-report number.

The Z-report number and reporting date answer different questions:

* the reporting date identifies the operating period for date-based reporting;  
* the Z-report number identifies the sequential close.

Both should be retained.

Example:

```
Business date: 2026-07-17
Opened at:     2026-07-17 08:41
Closed at:     2026-07-18 00:23
Z number:      0001842
```

### POS session

A POS session is an accountability period within one business day.

A business day may include several sessions.

Each session has its own:

* device;  
* optional cash drawer;  
* responsible user or shared-cashier configuration;  
* opening and closing timestamps;  
* cash counts;  
* expected cash;  
* variance;  
* session Z number where applicable.

All sessions must be closed before the business day may be closed.

### POS device

A POS device is a physical or logical register assigned to one store.

It does not itself represent a cashier or cash drawer.

### Cash drawer

A cash drawer is the physical till used for cash accountability.

It may be associated with different POS devices over time but may have only one active cash-enabled session at a time.

### Session and business-day Z reports

Session Z reports and the store-wide business-day Z report remain distinct.

For example:

```
Business-day Z 1842
├── Session Z 5511
├── Session Z 5512
└── Session Z 5513
```

Closing and reconciliation remain separate events.

A session or business day may close with a documented variance and be reconciled later.

## 1.6.14 Permission and authority are separate

A user must possess the required permission.

Some actions also require sufficient numeric authority, such as:

* discount percentage;  
* price-override percentage;  
* cash refund amount;  
* no-receipt return amount;  
* paid-out amount;  
* cash-variance review threshold.

When the user’s authority is insufficient, another qualified user must approve the action using their own credentials.

The approval is an independent auditable record.

## 1.6.15 Stored value uses an append-only ledger

Stored-value balances are derived from immutable ledger entries.

The current account balance may be cached for performance, but the ledger remains the authoritative history.

Stored-value entries and their related POS records must commit atomically.

## 1.6.16 Historical reporting uses snapshots

Completed POS lines retain the values required to reproduce the original result, including:

* product and variant;  
* identifiers;  
* description;  
* department;  
* display category;  
* tax category;  
* return policy;  
* regular and selling price;  
* discounts;  
* tax;  
* cost;  
* inventory-tracking mode.

Later changes to catalog or configuration do not alter completed reporting.

## 1.6.17 Financial classifications remain distinct

ShelfStack preserves separate reporting for:

* sales;  
* returns;  
* discounts;  
* price overrides;  
* tax;  
* cost of goods sold;  
* inventory;  
* shrinkage;  
* write-downs;  
* vendor returns;  
* freight;  
* tenders;  
* stored-value liabilities.

Departments may initially retain direct general-ledger account mappings.

A more generalized mapping structure may be introduced later if store-specific, effective-dated, or multi-system requirements justify it.

---

## 1.7 How the domains interact

## 1.7.1 Product setup

```
Product definition
→ Canonical identifier
→ Product classification
→ Product variant
→ SKU
→ Price, tax, department, and tracking configuration
→ Sale eligibility
```

The catalog defines the item.

Classification supplies financial, merchandising, and tax defaults.

The variant becomes the exact operational record used by purchasing, inventory, and POS.

## 1.7.2 Merchandise demand and acquisition

```
Customer request or staff suggestion
→ Check current in-house availability
→ Confirm and reserve located inventory, when applicable
→ Check uncommitted on-order quantity
→ Allocate future supply, when applicable
→ Send remaining demand to buyer review
→ Select vendor source
→ Create or update purchase order
→ Receive combined vendor shipment
→ Link receipt lines to applicable purchase-order lines
→ Accept merchandise and establish cost
→ Post inventory
→ Fulfil customer requests
```

A staff suggestion enters buyer review but does not reserve inventory for a customer.

A customer request may be fulfilled from:

* physically located in-house inventory;  
* uncommitted merchandise already on order;  
* a new purchase order created by the buyer.

## 1.7.3 Quantity-tracked sale

```
Scan or search
→ Resolve product and exact variant
→ Resolve price, department, tax, and return policy
→ Validate sale eligibility
→ Create quantity reservation
→ Accept tender
→ Complete transaction atomically
→ Convert reservation
→ Post sale movement and historical cost
```

If availability is insufficient, ShelfStack may warn and allow negative quantity according to policy.

## 1.7.4 Individually tracked sale

```
Scan product, variant, or exact unit
→ Resolve exact inventory unit
→ Validate store and status
→ Reserve exact unit
→ Accept tender
→ Complete transaction
→ Mark exact unit sold
```

An exact unit is required before completion.

## 1.7.5 Suspended transaction

```
Open transaction
→ Add lines
→ Create reservations
→ Suspend
→ Retain reservations
→ Recall at same store
→ Refresh current commercial rules
→ Complete or cancel
```

Suspended transactions do not automatically expire.

Authorized users must be able to review and cancel abandoned transactions.

## 1.7.6 Customer return

```
Identify original sale or return basis
→ Validate return eligibility
→ Calculate merchandise and tax reversal
→ Select return reason
→ Select inventory disposition
→ Determine refund tender
→ Complete corrective transaction
```

A linked return uses the original completed values.

An unlinked return requires an explicit refund and tax basis.

## 1.7.7 Stored-value issuance and redemption

```
Stored-value sale line
→ Customer pays ordinary tender
→ Stored-value liability entry
```

```
Stored-value tender
→ Validate balance
→ Complete customer sale
→ Stored-value redemption entry
```

POS and stored-value postings commit together.

## 1.7.8 Reporting

```
Completed POS snapshots
+ Inventory ledger
+ Stock balances
+ Stored-value ledger
+ Purchase orders and receipts
+ Session and drawer records
+ Approvals and reconciliation adjustments
→ Operational and financial reporting
```

Reporting consumes posted facts.

It does not revise the source records.

---

## 1.8 Implementation sequence

ShelfStack should be implemented in dependency order.

Later domains should consume earlier services rather than recreating their responsibilities.

## Phase 1 — Organization, stores, users, and authorization

Establish:

* organization;  
* stores;  
* users;  
* roles;  
* permissions;  
* store memberships;  
* authorization limits;  
* POS devices;  
* cash drawers;  
* audit identity.

This provides the store and user context required by every operational domain.

## Phase 2 — Definitions, classifications, and product catalog

Establish:

* departments;  
* display categories;  
* merchandise classes;  
* formats;  
* conditions;  
* tax categories;  
* return policies;  
* discount reasons;  
* products;  
* canonical identifiers;  
* variants;  
* variant SKUs;  
* variant options;  
* inventory-tracking modes;  
* sale eligibility.

The objective is to define a complete minimum sellable variant.

## Phase 3 — Product requests, vendors, and purchasing

Establish:

* customer requests;  
* staff purchase suggestions;  
* buyer-review queue;  
* vendors;  
* variant-vendor sources;  
* vendor item codes;  
* expected costs;  
* purchase orders;  
* purchase-order lines;  
* ordered and cancelled quantities;  
* customer-request allocations;  
* on-order calculation.

This phase should favor a minimal acquisition workflow and avoid introducing unnecessary sourcing, status, and approval layers.

## Phase 4 — Receiving and inventory

Establish:

* receipts representing vendor shipments;  
* receipt lines that may reference lines from several purchase orders;  
* delivered, accepted, rejected, damaged, and inspection quantities;  
* acquisition cost;  
* stock balances;  
* inventory units;  
* inventory ledger;  
* inventory reservations;  
* availability states;  
* inventory adjustments;  
* fulfilment of customer-request allocations.

This phase establishes the authoritative store inventory service while preserving the distinction among demand, expected supply, accepted supply, reservations, and physical inventory.

## Phase 5 — Editable POS transactions

Establish:

* business days;  
* POS sessions;  
* open transactions;  
* product lines;  
* open-ring lines;  
* stored-value lines;  
* scanning and search;  
* pending-line removal;  
* inventory reservations;  
* suspension, recall, and cancellation;  
* provisional pricing and tax.

Transactions remain incomplete until tender and atomic posting are implemented.

## Phase 6 — Pricing, discounts, tax, returns, and approvals

Establish:

* regular and selling price;  
* price overrides;  
* line and transaction discounts;  
* deterministic discount allocations;  
* tax components;  
* tax exemptions;  
* return policies;  
* linked and unlinked returns;  
* return reason and disposition;  
* POS approvals.

## Phase 7 — Tenders, cash controls, receipts, and completion

Establish:

* tender types;  
* cash tenders;  
* standalone card tenders;  
* stored-value tenders;  
* split tender;  
* cash movements;  
* cash counts;  
* session close;  
* receipt sequences;  
* receipt printing;  
* atomic and idempotent transaction completion.

## Phase 8 — Corrections and stored value

Establish:

* refund tenders;  
* mixed sale and return transactions;  
* post-voids;  
* exact inventory reversals;  
* gift-card issuance;  
* reload;  
* redemption;  
* store-credit refunds;  
* trade-credit infrastructure;  
* stored-value adjustments and reversals.

## Phase 9 — Reporting and reconciliation

Establish:

* sales reporting;  
* returns and post-void reporting;  
* discount and price-override reporting;  
* tax reporting;  
* tender reporting;  
* cash reconciliation;  
* session and business-day X and Z reports;  
* inventory reporting;  
* margin reporting;  
* purchasing and receiving reporting;  
* stored-value liability reporting;  
* reconciliation adjustments;  
* audit and exception reporting.

## Phase 10 — Later operational extensions

Potential later work includes:

* detailed buyback;  
* inventory counts;  
* store transfers;  
* complete return-to-vendor workflow;  
* customer records;  
* customer holds;  
* special orders;  
* reusable tax exemptions;  
* advanced promotions;  
* loyalty;  
* integrated payments;  
* offline POS;  
* accounting exports;  
* advanced catalog integrations;  
* optional physical placement metadata.

These capabilities should extend the established domain boundaries rather than replace them.

---

## 1.9 Current scope boundaries

The current architecture establishes strong foundations for:

* catalog identity;  
* product variants;  
* store inventory;  
* purchasing and receiving;  
* POS;  
* authorization;  
* stored value;  
* reporting.

The following remain intentionally incomplete and require separate design before implementation:

* detailed buyback workflow;  
* customer master and customer orders;  
* inventory-count workflow;  
* inter-store transfer documents;  
* complete return-to-vendor documentation;  
* advanced promotion definitions;  
* reusable tax-exemption records;  
* stored-value replacement, transfer, and expiration;  
* accounting-export batches;  
* integrated payment processing;  
* offline operation.

These areas should not be filled through assumptions from earlier ShelfStack iterations.

---

## 1.10 Governing summary

ShelfStack is a store-centered retail operations system built on a shared organizational catalog and a set of distinct but coordinated business domains.

Products define commercial identity.

Variants define what is sold, purchased, priced, taxed, and tracked.

Inventory units define exact physical copies when individual identity matters.

Departments, display categories, merchandise classes, tax categories, and formats remain separate because they answer different business questions.

Purchasing records intent.

Receiving records accepted merchandise and acquisition cost.

Inventory is authoritative at the store level.

Reservations explain temporary commitments.

Inventory movements explain changes in physical ownership and availability.

POS coordinates commercial activity but does not replace catalog, inventory, authorization, or stored-value services.

Completed transactions and ledgers are immutable.

Corrections create explicit linked records.

Stored value is governed by its own append-only ledger.

Reporting uses completed snapshots and posted operational facts rather than current master data.

ShelfStack should be implemented in dependency order, beginning with organization and catalog foundations, followed by purchasing and inventory, then POS completion, corrections, stored value, and reporting.  