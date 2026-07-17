# ShelfStack

ShelfStack is a store-centered retail operations platform designed for independent bookstores and similar specialty retailers.

The project is intended to support the complete merchandise lifecycle—from catalog definition and purchasing through receiving, inventory, point of sale, returns, stored value, cash accountability, and reporting—while preserving clear boundaries among those responsibilities.

> **Project status:** Architecture and domain design are in progress. Foundational architectural decisions have been documented. Domain specifications, schema reconciliation, and implementation planning are the current priorities.

## Project goals

ShelfStack is designed to support merchandise and services commonly carried by independent bookstores, including:

* new and used books;
* recorded music and video;
* periodicals;
* games and toys;
* stationery and paper goods;
* gifts and sidelines;
* café merchandise;
* services and fees;
* gift cards, store credit, and trade credit;
* signed, collectible, consignment, and individually tracked items.

The system should provide strong controls wherever activity affects:

* money;
* inventory ownership;
* tax;
* customer commitments;
* stored-value liability;
* authorization;
* historical reporting.

Routine bookstore activity should remain practical, fast, and barcode-oriented.

## Supported business areas

ShelfStack is organized into related business domains with explicit ownership boundaries.

| Domain                           | Principal responsibilities                                                                                             |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Organization and Authorization   | Organizations, stores, users, store memberships, roles, permissions, authority limits, devices, drawers, and approvals |
| Catalog and Products             | Products, variants, formats, conditions, identifiers, pricing inputs, and sale eligibility                             |
| Classification and Configuration | Merchandise classes, departments, tax categories, tender types, return policies, discount reasons, and store rules     |
| Product Requests                 | Customer requests, staff purchasing suggestions, buyer-review demand, and fulfilment status                            |
| Vendors and Purchasing           | Vendors, vendor sources, purchase orders, expected quantities, and expected cost                                       |
| Receiving and Inventory          | Receipts, stock balances, inventory units, reservations, movements, availability, and cost                             |
| Point of Sale                    | Transactions, sales, returns, discounts, tax, tenders, cash controls, receipts, and corrections                        |
| Stored Value                     | Gift cards, store credit, trade credit, account balances, and immutable ledger activity                                |
| Reporting and Reconciliation     | Operational reports, inventory reporting, tax, tenders, cash reconciliation, cost, margin, and audit reporting         |

## Core architecture

### Product hierarchy

ShelfStack distinguishes three levels of merchandise:

```text
Product
└── Product Variant
    └── Inventory Unit, when individual tracking is required
```

* A **Product** represents the commercial item.
* A **Product Variant** represents the exact configuration that is sold, priced, purchased, taxed, and inventoried.
* An **Inventory Unit** represents one exact physical copy when individual identity matters.

Every sellable product has at least one variant.

Variants use one of three inventory-tracking modes:

```text
quantity
individual
none
```

Quantity-tracked merchandise uses a store-and-variant balance. It does not require one inventory-unit record per copy.

### Identifier namespaces

ShelfStack-generated identifiers use separate restricted-circulation EAN-13 namespaces:

```text
21 — stored-value account
27 — exact inventory unit
28 — product variant
29 — locally identified product
```

Generated identifiers are unique across the organization, immutable, never reused, and do not encode mutable information such as store, department, condition, cost, price, or status.

Products retain one canonical primary identifier and may have one alternate lookup identifier.

Valid ISBN-10 input is normalized to ISBN-13 before storage and lookup.

### Merchandise classification

ShelfStack uses one hierarchical merchandise-class structure for:

* shelving;
* browsing;
* merchandising;
* buyer organization;
* category reporting;
* default department resolution.

Departments remain separate and provide financial and selling-policy defaults.

Attributes such as inventory tracking, price, format, exact-copy condition, and vendor sourcing remain explicit outside the department.

### Store-level inventory

The store is the authoritative inventory boundary.

ShelfStack does not initially require operational tracking among receiving, stockroom, sales floor, cashwrap, or temporary displays within the same store.

For quantity-tracked merchandise:

```text
available = on_hand - reserved - unavailable
```

* **On hand** represents physical merchandise present and owned by the store.
* **Reserved** represents present inventory committed to an incomplete workflow.
* **Unavailable** represents present inventory that cannot currently be sold.
* **Available** represents inventory currently sellable.
* **On order** represents expected but unreceived purchase-order quantity.

Only inventory movements change on-hand quantity.

### Requests, allocations, and reservations

ShelfStack keeps the following concepts separate:

```text
Product request
Purchase-order allocation
Inventory reservation
Purchase order
Receipt
```

* A **Product Request** records customer demand or a staff purchasing suggestion.
* A **Purchase-Order Allocation** commits future incoming quantity to a customer request.
* An **Inventory Reservation** commits merchandise already physically present.
* A **Purchase Order** records the intent to acquire merchandise.
* A **Receipt** records merchandise physically delivered and accepted.

Customer requests may be fulfilled from:

1. physically located in-house inventory;
2. uncommitted merchandise already on order;
3. a new purchase order created through buyer review.

### Purchasing and receiving

Purchasing, receiving, and inventory are separate events.

* Purchasing records acquisition intent.
* Receiving records what physically arrived and was accepted.
* Inventory records current physical ownership.

A vendor shipment may fulfil merchandise from several purchase orders. Purchase-order relationships are therefore recorded at the receipt-line level rather than requiring one receipt per purchase order.

Only accepted receipt quantity enters inventory.

The detailed purchasing and receiving workflows remain under review and should favor the simplest model that supports actual bookstore operations.

### Point-of-sale integrity

A POS transaction is a checkout container that may contain both sale and return activity.

Completed transactions and completed lines are immutable.

Corrections use explicit linked records:

* return lines;
* refund tenders;
* post-void transactions;
* inventory reversals;
* stored-value reversals;
* reconciliation adjustments.

POS completion is atomic and idempotent. Inventory, tender, tax, stored-value, cost, receipt-number, and transaction effects either complete together or do not complete.

### Stored value

ShelfStack supports:

* gift cards;
* store credit;
* trade credit.

Stored-value accounts use canonical `21` EAN-13 identifiers and may also have an alternate user-supplied identifier.

Stored-value balances are governed by an append-only ledger.

Gift-card issuance creates a liability rather than ordinary merchandise revenue. Stored-value redemption is a tender rather than a discount.

### Authorization

Users receive access through store memberships.

A store membership connects:

* one user;
* one store;
* one role;
* effective dates;
* optional store-specific authority limits.

Application behavior is controlled by granular permissions rather than hard-coded role names.

Numeric authority is separate from permission. Restricted actions may require an independent approval record identifying both the requester and approver.

## Principal workflow

```text
Product definition
→ Product variant
→ Vendor source
→ Product request or purchasing decision
→ Purchase order
→ Vendor shipment
→ Receipt and acceptance
→ Store inventory
→ Reservation
→ POS completion
→ Inventory, cost, tax, tender, and stored-value posting
→ Reporting and reconciliation
```

## Documentation

ShelfStack is documented in layers so that architectural rationale, domain behavior, data structures, workflows, and delivery planning remain distinct.

| Document                                                 | Purpose                                                                                 |
| -------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| [System Overview](docs/architecture/system-overview.md)  | Defines ShelfStack’s purpose, domain boundaries, central rules, and system interactions |
| [Architectural Decision Records](docs/adr/README.md)     | Records why foundational architectural choices were made                                |
| [Domain Specifications](docs/domains/README.md)          | Defines domain responsibilities, entities, workflows, permissions, and invariants       |
| [Schema Documentation](docs/schema/README.md)            | Defines how domain concepts are represented structurally                                |
| [Implementation Docs](docs/implementation/README.md)     | Delivery index: roadmap, current phase, locks, open decisions, and per-phase plans      |
| [Implementation Roadmap](docs/implementation/roadmap.md) | Tracks completed, current, upcoming, and deferred implementation work                   |
| [Permission Catalog](docs/domains/authorization-permissions.md) | Canonical permission keys for seeds and authorization checks                      |
| [Identifier Guide](docs/reference/identifiers.md)        | Normalization, generation, and lookup procedures for trade and ShelfStack IDs           |
| [Glossary](docs/glossary.md)                             | Defines shared ShelfStack terminology                                                   |

Recommended reading order:

1. System Overview
2. Glossary
3. Architectural Decision Records
4. Domain Specifications
5. Schema Documentation
6. Implementation Roadmap

## Architectural Decision Records

The foundational ADR set currently addresses:

1. Product, Product Variant, and Inventory Unit
2. Canonical identifiers and EAN namespaces
3. Merchandise classes and department defaults
4. Store-level authoritative inventory
5. Demand, allocations, and reservations
6. Inventory quantities and explicit reservation records
7. Purchasing, receiving, and inventory separation
8. Immutable completed POS transactions
9. Atomic and idempotent POS completion
10. Business days, sessions, devices, drawers, and Z reports
11. Permissions, authority limits, and approvals
12. Stored-value accounts and append-only ledgers

See [`docs/adr/README.md`](docs/adr/README.md) for the ADR index and contribution rules.

## Documentation authority

When project documentation conflicts, use the following order:

1. the most recent applicable accepted ADR;
2. the applicable Domain Specification;
3. the Schema Documentation;
4. workflow documentation;
5. implementation and phase plans;
6. archived or superseded material.

Database migrations describe what is currently implemented, but they do not silently redefine the intended architecture.

A conflict between implementation and governing documentation must be resolved explicitly.

## Current design priorities

The immediate documentation and design priorities are:

* revise the Domain Specifications to conform to the accepted ADRs;
* reconcile the proposed schema with the revised domains;
* simplify purchasing and receiving workflows;
* define the product-request and buyer-review lifecycle;
* define inventory posting and cost behavior;
* confirm business-date and Z-report policies;
* create an implementation roadmap based on domain dependencies.

## Deferred capabilities

The following areas remain intentionally deferred or require dedicated design:

* inventory counts;
* inter-store transfers;
* complete return-to-vendor workflow;
* detailed buyback;
* customer records and notifications;
* reusable tax exemptions;
* advanced promotions;
* stored-value replacement and expiration;
* accounting exports;
* integrated payment processing;
* offline POS operation;
* optional physical shelf-location tracking.

Deferred capabilities should extend the established architecture rather than bypass its domain boundaries.

## Contributing

Changes affecting architecture, domain behavior, or schema should update the corresponding documentation.

A pull request should review documentation when it:

* changes a domain boundary;
* changes an invariant;
* changes product identity;
* changes inventory ownership or availability;
* changes reservation behavior;
* changes transaction correction behavior;
* changes authorization;
* changes stored-value accounting;
* adds or removes a major entity or lifecycle state.

Suggested pull-request checklist:

```markdown
## Architecture and documentation

- [ ] No governing documentation change required
- [ ] Applicable ADRs reviewed
- [ ] ADR added or clarified
- [ ] Domain Specification updated
- [ ] Schema documentation updated
- [ ] Workflow documentation updated
- [ ] Implementation roadmap updated
```

Material reversals of accepted architectural decisions require a new ADR that supersedes the earlier decision.

## Development setup

Application setup, dependencies, database preparation, test commands, and local-development instructions will be added when the implementation scaffold is established in this repository.

Until then, contributors should begin with the System Overview and ADRs and use the Domain Specifications and schema work as the basis for implementation planning.
