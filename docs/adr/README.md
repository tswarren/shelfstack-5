# Architectural Decision Records

This directory contains the Architectural Decision Records (ADRs) that govern ShelfStack’s system architecture and cross-domain design.

ADRs explain **why** ShelfStack uses a particular architectural approach, the alternatives considered, and the consequences of that decision.

They are not intended to replace:

* the [System Overview](../architecture/system-overview.md);
* the [Domain Specifications](../domains/README.md);
* the [Schema Documentation](../schema/README.md);
* workflow documentation;
* implementation plans.

Instead, ADRs establish the decisions those documents must follow.

---

## Document authority

When ShelfStack documentation conflicts, use the following order of authority:

1. the most recent applicable accepted ADR;
2. the applicable Domain Specification;
3. the Schema Documentation;
4. workflow documentation;
5. implementation and phase plans;
6. archived or superseded documents.

Database migrations describe the schema currently implemented, but they do not silently redefine the intended architecture.

A conflict between implementation and an accepted ADR must be resolved explicitly by:

* correcting the implementation;
* correcting documentation that inaccurately describes the accepted decision; or
* accepting a new ADR that supersedes the earlier decision.

---

## ADR index

| ADR                                                              | Decision                                                                    | Status                     |
| ---------------------------------------------------------------- | --------------------------------------------------------------------------- | -------------------------- |
| [ADR-0001](0001-product-variant-inventory-unit.md)               | Separate Product, Product Variant, and Inventory Unit                       | Accepted                   |
| [ADR-0002](0002-canonical-identifiers-and-namespaces.md)         | Use Canonical Identifiers and Separate Restricted-Circulation Namespaces    | Accepted                   |
| [ADR-0003](0003-merchandise-classes-and-departments.md)          | Use One Merchandise-Class Hierarchy with Department Defaults                | Accepted                   |
| [ADR-0004](0004-store-level-inventory-boundary.md)               | Treat the Store as the Authoritative Inventory Boundary                     | Accepted                   |
| [ADR-0005](0005-demand-allocations-and-reservations.md)          | Represent Demand, Supply Allocations, and Inventory Reservations Separately | Accepted                   |
| [ADR-0006](0006-inventory-quantities-and-reservation-records.md) | Use Explicit Inventory Quantities and Reservation Records                   | Accepted                   |
| [ADR-0007](0007-purchasing-receiving-and-inventory-events.md)    | Separate Purchasing, Receiving, and Inventory Events                        | Accepted with open details |
| [ADR-0008](0008-immutable-pos-transactions.md)                   | Keep Completed POS Transactions Immutable and Use Explicit Corrections      | Accepted                   |
| [ADR-0009](0009-atomic-idempotent-pos-completion.md)             | Complete POS Transactions Atomically and Idempotently                       | Accepted                   |
| [ADR-0010](0010-business-days-sessions-and-z-reports.md)         | Distinguish Business Days, Sessions, Devices, Drawers, and Z Reports        | Accepted with open details |
| [ADR-0011](0011-permissions-authority-and-approvals.md)          | Separate Permissions, Numeric Authority, and Approval Events                | Accepted                   |
| [ADR-0012](0012-stored-value-ledger.md)                          | Govern Stored Value Through Independent Accounts and an Append-Only Ledger  | Accepted                   |
| [ADR-0013](0013-govern-quantity-tracked-inventory-cost.md)       | Govern Quantity-Tracked Inventory Cost Through Moving Weighted Average and Explicit Cost Provenance | Accepted with open details |
| [ADR-0014](0014-hybrid-transaction-component-tax-calculation.md) | Use Hybrid Transaction-Component Tax Calculation with Largest-Remainder Allocation | Accepted                   |

---

## ADR status definitions

### Proposed

The decision is under review and is not yet authoritative.

Implementation should not depend on a proposed ADR unless the work is explicitly exploratory.

### Accepted

The decision is authoritative and governs affected Domain Specifications, schemas, workflows, and implementation.

### Accepted with open details

The architectural direction is accepted, but one or more implementation or policy details remain unresolved.

The unresolved details must be listed explicitly in the ADR.

Later decisions may clarify those details without superseding the architectural direction.

### Superseded

The ADR has been replaced by a later ADR.

A superseded ADR remains in the repository to preserve decision history and must link to the ADR that replaced it.

### Deprecated

The decision is no longer recommended for new work but may still describe existing implementation that has not yet been migrated.

### Rejected

The proposal was considered but not adopted.

Rejected ADRs may be retained when documenting the rejected approach provides meaningful historical context.

---

## Current foundational decisions

The current ADR set establishes the following system-wide principles.

### Catalog and product identity

* Product, Product Variant, and Inventory Unit are separate concepts.
* Every sellable product has at least one variant.
* Quantity-tracked merchandise does not require one inventory-unit record per copy.
* Individually tracked merchandise uses exact inventory-unit records.
* Products use one canonical identifier and an optional alternate lookup identifier.
* ShelfStack-generated identifiers use separate namespaces:

```text
21 — stored-value account
27 — inventory unit
28 — product variant
29 — locally identified product
```

### Classification and departments

* ShelfStack uses one hierarchical merchandise-class structure.
* The former separate display-category hierarchy is not retained.
* Merchandise classes normally resolve a default department.
* Departments provide financial and selling-policy defaults.
* Inventory tracking, price, cost, format, and exact-copy state remain explicit outside the department.

### Inventory and acquisition

* Inventory is authoritative at the store level.
* Routine movement inside a store is not part of authoritative inventory.
* Requests, future-supply allocations, and physical inventory reservations are separate records.
* Inventory supports:

```text
on_hand
reserved
unavailable
available
on_order
```

* Availability is calculated as:

```text
available = on_hand - reserved - unavailable
```

* Purchasing records intent.
* Receiving records delivered and accepted merchandise.
* Inventory records physical ownership.
* A receipt may contain lines associated with several purchase orders.
* Only accepted receipt quantity enters inventory.
* Quantity-tracked inventory uses Store-and-Variant moving weighted-average cost over aggregate inventory value (ADR-0013).
* Zero or negative On Hand carries no positive inventory asset value; deficit allocation details remain open (OD-014).
* Missing inventory cost differs from confirmed zero cost; estimated cost retains provenance.

### Point of sale

* Completed transactions and completed lines are immutable.
* Returns create new return lines.
* Post-voids create new reversing transactions.
* POS completion is atomic and idempotent.
* Receipt numbers are assigned only during successful completion.
* Reservations convert into inventory movements only when completion succeeds.
* Tax uses a hybrid line and transaction-component model: eligibility and taxable base per line, rounding once per transaction tax component and direction, largest-remainder allocation back to lines (ADR-0014).
* Store Tax Rule `treatment` determines taxable / zero-rated / exempt handling; Tax Category does not carry a global status.
* Tax follows Discount allocation; final tax rules use the store-local calendar date at completion, not Business Day reporting date.

### Store operations and authorization

* Business days, reporting dates, Z-report numbers, sessions, devices, and drawers are distinct concepts.
* Permissions are evaluated in store context.
* Numeric authority is separate from permission.
* Restricted actions may require an independent approval record.
* The approving user authenticates with their own credentials.

### Stored value

* Gift cards, store credit, and trade credit share infrastructure but remain separately reportable.
* Stored-value accounts use canonical `21` EAN-13 identifiers.
* Stored-value balances are governed by an append-only ledger.
* Issuance creates liability.
* Redemption is tender.
* Stored-value corrections create reversing entries rather than rewriting history.

---

## Relationship to Domain Specifications

An ADR establishes a decision that affects one or more domains.

A Domain Specification explains how a domain behaves under those decisions.

For example:

* ADR-0001 governs the Catalog, Purchasing, Inventory, and POS domains.
* ADR-0005 governs Product Requests, Purchasing, and Inventory.
* ADR-0008 governs POS, Inventory, Stored Value, and Reporting.
* ADR-0011 governs authorization throughout the system.

Domain Specifications should include a **Governing ADRs** section near the beginning.

Example:

```markdown
## Governing ADRs

- [ADR-0001: Separate Product, Product Variant, and Inventory Unit](../adr/0001-product-variant-inventory-unit.md)
- [ADR-0002: Use Canonical Identifiers and Separate Restricted-Circulation Namespaces](../adr/0002-canonical-identifiers-and-namespaces.md)
- [ADR-0003: Use One Merchandise-Class Hierarchy with Department Defaults](../adr/0003-merchandise-classes-and-departments.md)
```

Domain Specifications should state the resulting behavior but should not repeat the full ADR rationale unless that context is needed to understand the domain.

The initial domain set is expected to include:

* [Organization and Authorization](../domains/organization-and-authorization.md)
* Classification and Configuration
* Catalog and Products
* Product Requests
* Vendors and Purchasing
* Receiving and Inventory
* Point of Sale
* Stored Value
* Reporting and Reconciliation

---

## Relationship to the schema

ADRs do not define individual tables and columns.

They define the architectural rules that the schema must represent.

Examples include:

| ADR decision                                      | Schema consequence                                                     |
| ------------------------------------------------- | ---------------------------------------------------------------------- |
| Product, Variant, and Inventory Unit are distinct | Separate `products`, `product_variants`, and `inventory_units` tables  |
| Store is the authoritative inventory boundary     | Store-and-variant stock balances                                       |
| Reservations are explicit                         | `inventory_reservations` records plus a reserved balance               |
| Completed transactions are immutable              | New return and reversal records instead of updates to completed facts  |
| Stored value uses an append-only ledger           | Separate account and ledger-entry tables                               |
| Permission and authority are separate             | Permissions, store memberships, authority limits, and approval records |
| Receipts may fulfil several POs                   | Purchase-order linkage at the receipt-line level                       |

Schema documentation should link to the ADR when a structure exists primarily because of an architectural decision.

---

## Creating a new ADR

Create an ADR when a decision:

* affects more than one domain;
* establishes a major domain boundary;
* changes ownership of important data;
* affects inventory, money, tax, authorization, or historical audit;
* establishes a durable implementation constraint;
* selects among meaningful architectural alternatives;
* reverses or materially changes an accepted decision.

Do not create an ADR merely to document:

* a minor field rename;
* a routine implementation detail;
* a temporary work item;
* a choice with no meaningful architectural consequences;
* an unresolved question with no proposed decision.

Unresolved topics should remain in:

* a Domain Specification’s open-questions section;
* an issue;
* an implementation plan;
* a design note;

until a decision is ready to be proposed.

---

## ADR numbering and filenames

ADR numbers are sequential and are never reused.

Use four-digit zero-padded filenames:

```text
0013-short-decision-title.md
0014-another-decision.md
```

The number identifies the record and does not indicate:

* priority;
* implementation order;
* domain ownership;
* current status.

Do not renumber existing ADRs if files are reordered or a decision is superseded.

---

## ADR template

Use the following structure for new ADRs:

```markdown
# ADR-NNNN: Decision title

**Status:** Proposed  
**Date:** YYYY-MM-DD

## Context

Describe the problem, constraints, and why a decision is required.

## Decision

State the selected architectural approach clearly.

## Consequences

### Benefits

- ...

### Costs

- ...

## Alternatives considered

### Alternative name

Explain why it was not selected.

## Governing rules

- State the invariants and rules created by this decision.

## Open details

List unresolved implementation or policy details, when applicable.

## Related domains

- Domain name

## Related ADRs

- [ADR-NNNN: Title](relative-link.md)
```

Not every ADR requires an `Open details` section.

---

## Changing an accepted ADR

### Minor clarification

An accepted ADR may be edited directly when the change:

* corrects wording;
* clarifies an existing decision;
* adds a missing consequence;
* adds a cross-reference;
* does not change the decision itself.

The commit message should explain the clarification.

### Material change

Create a new ADR when the change:

* reverses the decision;
* changes a governing invariant;
* changes domain ownership;
* selects a different alternative;
* materially changes implementation consequences.

The new ADR must state:

```markdown
**Supersedes:** [ADR-NNNN](previous-adr.md)
```

The prior ADR must be updated to state:

```markdown
**Status:** Superseded by [ADR-NNNN](new-adr.md)
```

Do not delete the superseded ADR.

---

## Partially resolved ADRs

Some ADRs establish a durable architectural boundary while leaving operational details open.

For example:

* ADR-0007 separates purchasing, receiving, and inventory but does not finalize every purchase-order status.
* ADR-0010 distinguishes business date and Z number but does not yet determine how the business date is assigned.

These ADRs remain authoritative for the accepted architectural direction.

Open details should be resolved through:

1. Domain Specification work;
2. operational workflow review;
3. a clarification to the existing ADR when consistent with it; or
4. a new superseding ADR when the resolution changes the architectural direction.

---

## Pull-request expectations

A pull request should review the ADRs when it:

* changes a domain boundary;
* changes how inventory is owned or calculated;
* changes reservation behavior;
* changes product identity;
* changes transaction immutability or correction behavior;
* changes authorization or approval rules;
* changes stored-value accounting;
* changes business-day or session accountability;
* adds a workflow that conflicts with an accepted decision.

Suggested pull-request checklist:

```markdown
## Architecture and documentation

- [ ] No ADR impact
- [ ] Existing ADR reviewed
- [ ] ADR clarification included
- [ ] New ADR proposed
- [ ] Domain Specification updated
- [ ] Schema documentation updated
- [ ] Workflow documentation updated
```

Code should not be merged when it knowingly contradicts an accepted ADR without an explicit architectural decision.

---

## Deferred ADR topics

The following subjects are expected to require ADRs later, but their workflows are not yet sufficiently defined:

* inventory-count methodology;
* inter-store transfer lifecycle;
* complete return-to-vendor workflow;
* detailed buyback workflow;
* customer identity and communication;
* customer pickup and notification policy;
* reusable tax exemptions;
* advanced promotions;
* stored-value replacement and expiration;
* accounting export and correction;
* integrated payment processing;
* offline POS operation.

These should not be decided through schema assumptions alone.

---

## Historical documentation

Superseded specifications and earlier consolidated documents may remain under:

```text
docs/archive/
```

Archived documents are retained for historical context and are not authoritative.

When archived material conflicts with an accepted ADR, the accepted ADR governs.
