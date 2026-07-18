# AGENTS.md

This file defines the operating rules for automated coding agents and contributors working in the ShelfStack repository.

ShelfStack is an architecture-first retail operations platform for independent bookstores and similar specialty retailers. Changes must preserve accepted architectural decisions, domain ownership, historical integrity, and the repository’s documentation structure.

## 1. Start with governing documentation

Before making a material change, read:

1. [`README.md`](README.md)
2. [`docs/architecture/system-overview.md`](docs/architecture/system-overview.md)
3. [`docs/adr/README.md`](docs/adr/README.md)
4. the applicable file under [`docs/domains/`](docs/domains/)
5. the applicable schema documentation under [`docs/schema/`](docs/schema/)
6. the applicable workflow under [`docs/workflows/`](docs/workflows/)
7. [`docs/implementation/roadmap.md`](docs/implementation/roadmap.md)

Do not infer current architecture from archived documents, superseded specifications, old branches, or obsolete migrations when newer governing documentation applies.

### Document authority

When documents conflict, use this order:

1. the most recent applicable accepted ADR;
2. the applicable Domain Specification;
3. Schema Documentation;
4. workflow documentation;
5. implementation and phase plans;
6. archived or superseded material.

Database migrations describe what is currently implemented. They do not silently redefine intended architecture.

When implementation conflicts with governing documentation, identify the conflict and resolve it explicitly by:

- changing the implementation;
- correcting documentation that inaccurately describes the accepted decision; or
- proposing a new ADR that supersedes the earlier decision.

## 2. Do not invent unresolved architecture

Implement only behavior established by the current task and governing documentation.

When work reaches an unresolved area:

1. make the smallest coherent change;
2. avoid speculative tables, statuses, services, and abstractions;
3. document necessary assumptions;
4. preserve the open question;
5. surface any architectural decision that requires approval.

Areas intentionally open or deferred include, among others:

- detailed purchase-order and receipt-correction workflows;
- purchasing approval thresholds;
- inventory counts and inter-store transfers;
- complete return-to-vendor workflows;
- detailed customer, promotion, buyback, and tax-exemption behavior;
- stored-value replacement and expiration;
- accounting exports;
- integrated payments;
- offline POS;
- authoritative shelf-location tracking.

A proposed implementation detail is not an accepted architectural decision.

## 3. Core invariants

The ADRs and Domain Specifications contain the full rationale. The following rules are non-negotiable unless superseded by a later accepted ADR.

### Merchandise identity

- Product, Product Variant, and Inventory Unit are distinct.
- A Product is not sold directly; POS resolves an exact Product Variant.
- Every sellable Product has at least one Product Variant.
- Quantity-tracked merchandise does not create one Inventory Unit per physical copy.
- Every Product Variant declares one tracking mode: `quantity`, `individual`, or `none`.

### Identifiers

ShelfStack-generated EAN-13 namespaces are:

```text
21 — stored-value account
27 — inventory unit
28 — product variant
29 — locally identified product
```

Generated identifiers are organization-wide, unique, immutable, never reused, checksum-valid, and free of encoded mutable meaning.

Do not encode store, department, condition, price, cost, date, status, or parent relationships into identifiers.

Valid ISBN-10 input is normalized to ISBN-13 for canonical storage and lookup.

### Classification

- ShelfStack uses one hierarchical merchandise-class structure for merchandising, shelving, browsing, buyer organization, category reporting, and default department resolution.
- Do not recreate a separate display-category hierarchy without a superseding ADR.
- Departments remain distinct financial and selling-policy records.
- Inventory tracking, price, format, exact-copy condition, exact-copy cost, vendor sourcing, and store inventory quantity remain explicit outside the department.

### Inventory

- Inventory is authoritative at the store level.
- Routine movement among receiving, stockroom, sales floor, cashwrap, and temporary displays does not change authoritative inventory.
- Inter-store movement requires an auditable transfer workflow.
- Only inventory movements change `on_hand`.
- Reservations reduce availability, not `on_hand`.
- `on_order` is expected supply, not inventory.

For quantity-tracked inventory:

```text
available = on_hand - reserved - unavailable
```

### Demand and supply

Keep these concepts separate:

```text
Product request
Purchase-order allocation
Inventory reservation
Purchase order
Receipt
```

- A request records demand.
- A purchase-order allocation commits future supply.
- An inventory reservation commits physically present supply.
- A purchase order records acquisition intent.
- A receipt records delivered and accepted supply.

Do not reserve merchandise that is not physically present. Do not represent on-order supply as on-hand inventory.

### Purchasing and receiving

- Purchase orders do not change on-hand inventory.
- Only posted accepted receipt quantity creates inventory.
- One receipt may contain lines from several purchase orders.
- Purchase-order linkage belongs at the receipt-line level.
- Rejected quantity does not become inventory.

### Completed activity

- Completed POS transactions and completed lines are immutable.
- Do not edit, delete, void in place, or mark original sale lines as returned.
- Corrections use new linked records, such as returns, refund tenders, post-voids, inventory reversals, stored-value reversals, and reconciliation adjustments.
- Historical reports use completed snapshots rather than current master data.

### POS completion

POS completion is atomic and idempotent.

Inventory, tax, discounts, tenders, stored value, cost snapshots, receipt numbering, and transaction completion must commit together or not at all.

Repeated completion requests must not create duplicates. Receipt numbers are assigned only during successful completion.

### Business days, sessions, and authorization

- Business day, reporting date, Z number, POS session, POS device, and cash drawer remain distinct.
- A business day cannot close while a session is open.
- Closing and reconciliation remain separate.
- Permissions, numeric authority, and approvals remain separate.
- Permissions are evaluated in store context.
- Role names do not control application behavior.
- Approvers authenticate with their own credentials.
- A default store is a navigation preference, not access authorization.

### Stored value

- Gift cards, store credit, and trade credit share infrastructure but remain separately reportable.
- Stored value uses an append-only ledger.
- The ledger is authoritative even when a current balance is cached.
- Issuance creates liability.
- Redemption is tender, not discount.
- Corrections create reversing entries.
- Stored-value and related POS activity commit atomically.

## 4. Domain ownership

Do not duplicate business records or rules across domains.

- **Organization and Authorization:** organizations, stores, users, memberships, roles, permissions, authority limits, devices, drawers, approvals.
- **Catalog and Products:** product identity, canonical identifiers, metadata, variants, SKUs, options, formats, conditions, tracking mode, sale-eligibility inputs.
- **Classification and Configuration:** merchandise classes, departments, tax categories and rules, discount reasons, return policies and reasons, tender types, cash-movement types.
- **Product Requests:** customer demand, staff suggestions, quantity, priority, needed-by dates, status, supply-allocation relationships.
- **Vendors and Purchasing:** vendors, vendor sources, purchase orders and lines, expected supply, expected cost, on-order intent.
- **Receiving and Inventory:** receipts and lines, stock balances, units, movements, reservations, availability states, adjustments, inventory cost.
- **Point of Sale:** business days, sessions, transactions, lines, discounts, tax components, tenders, cash movements, receipts, corrections.
- **Stored Value:** accounts, balance history, issuance, reload, redemption, refund, adjustment, reversal.
- **Reporting and Reconciliation:** report definitions, reconciliation, operational aggregation, historical reporting.

Reporting consumes posted source records. It does not modify them.

## 5. Implementation rules

### Service boundaries

Use application services for workflows that coordinate several records or domains.

Typical service boundaries include:

- identifier normalization and resolution;
- sale eligibility;
- classification resolution;
- inventory reservation and posting;
- product-request fulfilment;
- purchase-order allocation;
- receipt posting;
- transaction completion;
- returns and post-voids;
- stored-value posting;
- authorization and approvals;
- reconciliation.

Models enforce local invariants. Services coordinate cross-record and cross-domain behavior.

Do not place multi-record financial, inventory, or liability workflows entirely in controllers, callbacks, views, jobs, or model lifecycle hooks.

### Transactions and concurrency

Use explicit database transactions when an operation affects more than one financial, inventory, or liability record.

Use deterministic locking where concurrent activity could:

- reserve the same quantity or unit;
- consume the same stored-value balance;
- assign the same receipt number;
- complete the same transaction twice;
- receive beyond an open purchase-order quantity;
- allocate more future supply than remains uncommitted.

Do not rely on UI state for consistency.

Use database constraints where practical, including for:

- unique variant, inventory-unit, and stored-value identifiers;
- one stock balance per store and variant;
- one active reservation per inventory unit;
- one open business day per store;
- one active cash-enabled session per drawer;
- unique receipt numbers within a store;
- unique completion idempotency keys.

Application validation complements database protection; it does not replace it.

### Data conventions

- Store money as integer cents.
- Never use floating-point types for money.
- Store rates as fixed-precision decimals or explicitly documented scaled integers.
- Use deterministic rounding.
- Distinguish business dates, timestamps, effective dates, completion dates, posting dates, and reconciliation dates.
- Interpret operational timestamps using the applicable store time zone.
- Deactivate historically referenced master records instead of deleting them.
- Preserve snapshots needed to reproduce completed activity.
- Correct posted records through reversing or adjusting records.

## 6. Repository stack

ShelfStack currently uses:

- Ruby 3.4.9;
- Rails 8.1;
- PostgreSQL;
- Puma;
- Propshaft;
- Importmap;
- Turbo and Stimulus;
- Solid Cache, Solid Queue, and Solid Cable;
- Minitest;
- Capybara and Selenium;
- RuboCop Rails Omakase;
- Brakeman;
- Bundler Audit.

Do not introduce Node.js, npm, Yarn, or a JavaScript bundler for ordinary frontend behavior. Changes to the asset or JavaScript strategy require an intentional architectural decision.

## 7. Environment and commands

Use repository-provided `bin/*` commands rather than global executables.

### Preferred local environment

Docker Compose is the preferred workstation environment.

Build and prepare:

```bash
docker compose build
./dev/rails-docker bin/setup --skip-server
```

Start and stop:

```bash
docker compose up
docker compose down
```

Application URL:

```text
http://localhost:3000
```

For one-off Rails commands, prefer:

```bash
./dev/rails-docker bin/rails db:migrate
./dev/rails-docker bin/rails test
./dev/rails-docker bin/ci
```

When environment variables must be passed explicitly, use `docker compose run`, for example:

```bash
docker compose run --rm -e RAILS_ENV=test web \
  bin/rails db:test:prepare test
```

### Managed agent environments without Docker

When nested Docker is unavailable:

1. use the Ruby version in [`.ruby-version`](.ruby-version);
2. install PostgreSQL and required development libraries;
3. configure the database through the environment variables consumed by `config/database.yml`;
4. run:

```bash
bin/setup --skip-server
RAILS_ENV=test bin/rails db:test:prepare
```

Do not commit developer-specific credentials or environment overrides.

### Setup and database safety

`bin/setup` is idempotent and should be preferred over reproducing its operations manually.

For the three-layer seed lifecycle (`db:seed`, `shelfstack:bootstrap`, `shelfstack:seed_reference_data`), bootstrap environment variables, INV-ORG-001 abort behavior, and `shelfstack:sync_admin_permissions`, see [`docs/implementation/bootstrap-and-seed.md`](docs/implementation/bootstrap-and-seed.md).

Do not use destructive commands unless the task explicitly requires them:

```bash
bin/setup --reset
bin/rails db:reset
docker compose down --volumes
```

Do not remove Docker volumes during routine setup or testing.

Do not edit generated schema files manually. Use migrations and regenerate schema output through Rails.

## 8. Testing and validation

Every material change requires tests proportionate to its risk.

Use:

- model tests for local validations and constraints;
- service tests for business rules;
- request tests for access and error behavior;
- integration tests for cross-domain workflows;
- system tests for important browser paths;
- concurrency tests for reservations, balances, sequences, and stored value;
- idempotency tests for posting operations;
- reversal tests for immutable completed activity.

High-risk workflows require both success and failure-path coverage:

- transaction completion;
- inventory reservation and posting;
- receipt posting;
- inventory adjustment;
- return and post-void processing;
- stored-value issuance and redemption;
- cash movement;
- business-day close;
- approvals;
- receipt numbering;
- purchase-order allocation.

Verify atomicity: a failed operation must not leave partial inventory, tender, stored-value, receipt-number, reservation, or posting effects.

Verify historical integrity: changes to current products, departments, prices, tax rules, costs, or policies must not change completed results.

### Canonical validation commands

During development, run focused tests first:

```bash
bin/rails test test/path/to/test_file.rb
bin/rails test test/path/to/test_file.rb:42
```

Before completing substantial work, run:

```bash
bin/ci
```

Run system tests separately when the change affects an end-to-end browser workflow:

```bash
bin/rails test:system
```

In Docker, use the repository wrapper or the equivalent Compose command.

Report every validation command run and whether it passed. Do not claim a test passed unless it was executed. Do not conceal or omit failures.

## 9. Documentation requirements

Update documentation when a change affects:

- a domain boundary;
- a major entity or lifecycle status;
- an invariant;
- inventory ownership or availability;
- request, allocation, or reservation behavior;
- transaction corrections;
- authorization or approvals;
- stored-value accounting;
- a cross-domain workflow.

Create or supersede an ADR when a decision:

- affects several domains;
- changes ownership of important data;
- changes a durable architectural constraint;
- selects among meaningful alternatives;
- reverses an accepted decision.

Update the applicable:

- Domain Specification for behavior, terminology, statuses, permissions, workflows, and invariants;
- Schema Documentation for tables, fields, constraints, indexes, enums, and relationships;
- workflow documentation for user-visible or record-level sequences;
- roadmap for scope, dependencies, phase status, and deferred work.

Do not create an ADR for a routine implementation detail.

## 10. Branch and pull-request expectations

Follow [`docs/implementation/git-workflow.md`](docs/implementation/git-workflow.md):

- branch from `main`;
- use short-lived branches;
- create a pull request for every change;
- prefer squash merges;
- do not create permanent `develop` or phase branches.

A substantial pull request should explain:

- the affected domain;
- the governing ADRs;
- preserved invariants;
- schema changes;
- tests added and commands run;
- documentation updated;
- unresolved questions or known mismatches.

Suggested checklist:

```markdown
## Architecture and documentation

- [ ] Applicable ADRs reviewed
- [ ] Applicable Domain Specification reviewed
- [ ] No accepted architectural decision changed
- [ ] ADR added or superseded where required
- [ ] Schema documentation updated
- [ ] Workflow documentation updated
- [ ] Implementation roadmap updated

## Data integrity

- [ ] Database constraints added where appropriate
- [ ] Atomicity preserved
- [ ] Idempotency preserved
- [ ] Historical snapshots preserved
- [ ] Reversal behavior tested
- [ ] Concurrency behavior tested
```

Do not merge code that knowingly contradicts an accepted ADR without an explicit superseding decision.

## 11. Prohibited patterns

Do not:

- sell a Product without resolving a Product Variant;
- create Inventory Units for every interchangeable copy;
- encode mutable meaning in generated identifiers;
- recreate a separate display-category hierarchy;
- treat internal store areas as authoritative inventory owners;
- use `pending` as the inventory commitment quantity;
- change `on_hand` without an inventory movement;
- treat expected purchase-order quantity as physical inventory;
- reserve merchandise that is not physically present;
- restrict one receipt to one purchase order;
- mutate completed POS records;
- mark original sale lines as returned;
- assign receipt numbers before successful completion;
- use role names directly in authorization logic;
- treat stored-value redemption as a discount;
- overwrite stored-value ledger entries;
- use current master data to reinterpret completed history;
- add speculative workflow complexity to unresolved domains;
- modify CI merely to conceal a failure.

## 12. Completion report

Before finishing a task, verify:

- accepted ADRs and domain ownership were followed;
- unresolved architecture was not invented;
- inventory and financial effects remain explainable;
- completed records remain immutable;
- atomicity and idempotency are preserved;
- critical invariants have database protection where appropriate;
- store context and user identity are retained;
- historical snapshots remain reproducible;
- relevant tests pass;
- documentation is current.

In the final report, state:

1. what changed;
2. which files changed;
3. which commands were run;
4. which checks passed or failed;
5. any remaining risk, mismatch, or open decision.
