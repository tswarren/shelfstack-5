# ShelfStack Domain Specifications

**Status:** Governing domain documentation  
**Scope:** Responsibilities, ownership boundaries, principal records, workflows, permissions, audit requirements, invariants, and open questions for ShelfStack's business domains

## Purpose

ShelfStack is divided into business domains so each major part of the system has a clear responsibility.

A domain:

- owns particular records and business rules;
- exposes controlled information or operations to other domains;
- does not duplicate records owned elsewhere;
- preserves its own operational and audit history;
- participates in cross-domain workflows through explicit references and posting operations.

These specifications describe intended business behavior. They are not exhaustive database dictionaries and do not replace accepted Architectural Decision Records.

## Document authority

When ShelfStack documentation conflicts, use:

1. the most recent applicable accepted ADR;
2. the applicable Domain Specification;
3. Schema Documentation;
4. workflow documentation;
5. implementation and phase plans;
6. archived or superseded material.

Database migrations describe the schema currently implemented. They do not silently redefine intended architecture.

## Domain index

| Domain | Document | Principal responsibility |
|---|---|---|
| Organization and Authorization | [organization-and-authorization.md](organization-and-authorization.md) | Organization, Stores, Users, Store Memberships, Roles, Permissions, authority, Devices, Drawers, and Approvals |
| Authorization permissions (catalog) | [authorization-permissions.md](authorization-permissions.md) | Canonical permission keys, scope, phase, authority, and approval behavior |
| Classification and Configuration | [classification-and-configuration.md](classification-and-configuration.md) | Merchandise Classes, Departments, tax configuration, reasons, Tender Types, and Store policies |
| Catalog and Products | [catalog-and-products.md](catalog-and-products.md) | Products, Product Variants, identifiers, Formats, Conditions, options, pricing inputs, and eligibility |
| Product Requests | [product-requests.md](product-requests.md) | Customer demand, staff suggestions, replenishment/frontlist demand, buyer-review state, and fulfilment state |
| Ordering and Acquisition Planning | [ordering-and-acquisition-planning.md](ordering-and-acquisition-planning.md) | Product-backed demand, buyer review, sourcing, expected cost, and supply-to-fulfilment planning |
| Vendors and Purchasing | [vendors-and-purchasing.md](vendors-and-purchasing.md) | Vendors, Vendor Sources, Purchase Orders, expected supply, and allocations |
| Receiving and Inventory | [receiving-and-inventory.md](receiving-and-inventory.md) | Receipts, physical inventory, Stock Balances, Inventory Units, Reservations, movements, and cost |
| Point of Sale | [point-of-sale.md](point-of-sale.md) | Business Days, Sessions, Transactions, lines, tax, Tenders, cash, receipts, returns, and corrections |
| Stored Value | [stored-value.md](stored-value.md) | Gift Cards, Store Credit, Trade Credit, account balances, and immutable Ledger activity |
| Reporting and Reconciliation | [reporting-and-reconciliation.md](reporting-and-reconciliation.md) | Operational reporting, historical attribution, close reporting, and Reconciliation |

## Shared status labels

### Established

Explicitly governed by an accepted ADR or another authoritative ShelfStack document.

### Proposed

A working design needed to make the domain specification coherent, but not yet established through an accepted architectural decision.

### Open

A question intentionally left unresolved. Open items must not be implemented as settled architecture without review.

### Deferred

Recognized as likely future scope but excluded from the current baseline.

## Shared conventions

### Organization and Store context

One ShelfStack installation represents one operating Organization. Organization-level master records may be shared. Store-level operational records must identify their Store explicitly.

### Activation rather than deletion

Master records referenced by operational history should ordinarily be deactivated rather than deleted.

### Money

Monetary amounts use integer cents. Rates use fixed precision sufficient for deterministic calculation.

### Historical snapshots

Completed or posted records retain the values required to reproduce their historical result. Current master-data changes do not reinterpret completed history.

### Posted records

Completed financial, inventory, tax, Tender, and Stored-Value records are not edited in place. Corrections use explicit returns, reversals, adjustments, or other linked corrective records.

### Audit identity

Material actions retain User, Store, action, affected record, timestamp, reason when required, and approver when required.

### Idempotency

Operations coordinating several financial, inventory, or liability effects must be safe to retry without creating duplicates.

## Cross-domain ownership summary

| Concern | Owning domain | Referencing domains |
|---|---|---|
| Organization, Store, User, access | Organization and Authorization | All domains |
| Merchandise Class, Department, Tax Category | Classification and Configuration | Catalog, Purchasing, POS, Reporting |
| Product and Product Variant | Catalog and Products | Requests, Purchasing, Inventory, POS, Reporting |
| Product Request | Product Requests | Purchasing, Inventory, POS, Reporting |
| Vendor, Purchase Order, PO Allocation | Vendors and Purchasing | Requests, Receiving, Reporting |
| Receipt, Stock Balance, Inventory Unit, Reservation | Receiving and Inventory | Requests, POS, Reporting |
| Business Day, POS Session, POS Transaction, Tender | Point of Sale | Inventory, Stored Value, Reporting |
| Stored-Value Account and Entry | Stored Value | POS, Reporting |
| Report definition and Reconciliation | Reporting and Reconciliation | Operational users and future integrations |

## Cross-domain interaction rules

1. Reference records owned elsewhere rather than duplicating them.
2. Snapshot external values only when historical reproducibility requires it.
3. Modify authoritative data only through the owning domain's service boundary.
4. Coordinate cross-domain financial and inventory posting atomically where required.
5. Preserve original posted records and create explicit corrections.
6. Keep demand, expected supply, physical inventory, and completed transactions as distinct facts.

## Updating a Domain Specification

Update the relevant specification when a change:

- changes domain ownership;
- introduces or removes a principal entity;
- changes a lifecycle or state transition;
- changes a workflow;
- changes authorization or Approval;
- changes an invariant;
- changes audit requirements;
- resolves an Open item.

A material change to an accepted cross-domain decision normally requires a new or superseding ADR.
