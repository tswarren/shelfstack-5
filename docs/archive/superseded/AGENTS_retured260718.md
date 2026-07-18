# AGENTS.md

This file provides instructions for automated coding agents and contributors working in the ShelfStack repository.

ShelfStack is an architecture-first retail operations platform for independent bookstores and similar specialty retailers. Changes must preserve the project’s accepted architectural decisions, domain boundaries, historical integrity, and documentation structure.

---

## 1. Read the governing documentation first

Before making a material change, review the documentation that governs the affected area.

Recommended reading order:

1. [`README.md`](README.md)
2. [`docs/architecture/system-overview.md`](docs/architecture/system-overview.md)
3. [`docs/adr/README.md`](docs/adr/README.md)
4. the applicable file under [`docs/domains/`](docs/domains/)
5. the applicable schema documentation under [`docs/schema/`](docs/schema/)
6. the applicable workflow under [`docs/workflows/`](docs/workflows/)
7. [`docs/implementation/roadmap.md`](docs/implementation/roadmap.md)

Do not infer current architecture from archived documents, superseded specifications, old branches, or outdated migrations when a newer accepted ADR or Domain Specification applies.

---

## 2. Document authority

When project documents conflict, use the following order:

1. the most recent applicable accepted ADR;
2. the applicable Domain Specification;
3. the Schema Documentation;
4. workflow documentation;
5. implementation and phase plans;
6. archived or superseded material.

Database migrations describe what is currently implemented. They do not silently redefine the intended architecture.

When implementation conflicts with governing documentation, do not normalize the inconsistency by documenting the implementation as correct. Identify the conflict and resolve it explicitly through one of the following:

* change the implementation;
* correct documentation that inaccurately describes the accepted decision;
* propose a new ADR that supersedes the earlier decision.

---

## 3. Do not invent unresolved architecture

Several ShelfStack areas remain intentionally open or under review.

Do not fill these gaps by importing assumptions from earlier ShelfStack versions or by introducing a conventional retail pattern without project approval.

Areas currently requiring additional design include:

* detailed purchase-order statuses;
* receipt correction workflows;
* purchasing approval thresholds;
* inventory counts;
* inter-store transfers;
* complete return-to-vendor workflows;
* customer identity and notifications;
* advanced promotions;
* reusable tax exemptions;
* detailed buyback;
* stored-value replacement and expiration;
* accounting exports;
* integrated payment processing;
* offline POS operation;
* physical shelf-location tracking.

When work reaches an unresolved area:

1. implement only the behavior explicitly required by the current task;
2. keep the design minimal;
3. document assumptions;
4. add or update an open question where appropriate;
5. do not create speculative tables, statuses, services, or abstractions.

A proposed implementation detail must not be treated as an accepted architectural decision.

---

## 4. Core architectural invariants

The following rules are foundational.

### 4.1 Product hierarchy

ShelfStack distinguishes:

```text
Product
└── Product Variant
    └── Inventory Unit, when individual tracking is required
```

* A Product represents the commercial item.
* A Product Variant represents the exact sellable and operational configuration.
* An Inventory Unit represents one exact physical copy.

Every sellable product must have at least one variant.

A product is not sold directly. POS must resolve an exact variant.

Quantity-tracked merchandise must not create one inventory-unit record per physical copy.

### 4.2 Inventory-tracking modes

Every variant declares one tracking mode:

```text
quantity
individual
none
```

* `quantity` uses a store-and-variant balance.
* `individual` requires exact inventory-unit identity.
* `none` creates no inventory reservation or movement.

Do not infer tracking mode solely from product type, merchandise class, or department.

### 4.3 Identifier namespaces

ShelfStack-generated EAN-13 identifiers use separate namespaces:

```text
21 — stored-value account
27 — inventory unit
28 — product variant
29 — locally identified product
```

Generated identifiers must be:

* organization-wide;
* unique;
* immutable;
* never reused;
* valid EAN-13 values;
* free of encoded mutable meaning.

Do not encode store, department, condition, price, cost, date, status, or parent relationship into an identifier.

A valid ISBN-10 input must be normalized to ISBN-13 for canonical storage and lookup.

### 4.4 Merchandise classification

ShelfStack uses one hierarchical merchandise-class structure for:

* merchandising;
* shelving;
* browsing;
* buyer organization;
* category reporting;
* default department resolution.

Do not reintroduce a separate display-category hierarchy unless a later accepted ADR explicitly changes this decision.

Departments remain distinct and provide financial and selling-policy defaults.

The following remain explicit outside the department:

* inventory-tracking mode;
* regular price;
* product format;
* exact-copy condition;
* exact-copy cost;
* vendor sourcing;
* store inventory quantity.

### 4.5 Store inventory boundary

Inventory is authoritative at the store level.

Do not require routine inventory movements among:

* receiving;
* stockroom;
* sales floor;
* front table;
* cashwrap;
* temporary displays.

Internal placement may later exist as optional metadata, but it must not fragment the authoritative store balance.

Movement between stores is an inventory transfer and requires an auditable inventory workflow.

### 4.6 Inventory quantities

For quantity-tracked inventory:

```text
available = on_hand - reserved - unavailable
```

Definitions:

* `on_hand`: physically present and owned by the store;
* `reserved`: physically present but committed to an incomplete workflow;
* `unavailable`: physically present but not currently sellable;
* `available`: currently sellable;
* `on_order`: expected but not yet received.

Only inventory movements change `on_hand`.

Reservations do not reduce `on_hand`.

On-order quantity is not inventory.

### 4.7 Requests, allocations, and reservations

Keep these concepts separate:

```text
Product request
Purchase-order allocation
Inventory reservation
Purchase order
Receipt
```

* A request records demand.
* A purchase-order allocation commits future supply to demand.
* An inventory reservation commits physically present supply.
* A purchase order records acquisition intent.
* A receipt records delivered and accepted supply.

Do not represent an unfulfilled request as an inventory reservation.

Do not represent on-order supply as on-hand inventory.

In-house inventory for a customer request must be physically confirmed before reservation.

### 4.8 Purchasing and receiving

Purchasing, receiving, and inventory are different events.

* Purchase orders do not change on-hand inventory.
* Only posted accepted receipt quantity creates inventory.
* One receipt may contain lines from several purchase orders.
* Purchase-order linkage belongs at the receipt-line level.
* Rejected quantity does not become inventory.

Favor the simplest workflow that supports actual bookstore operations.

### 4.9 Completed transaction immutability

Completed POS transactions and completed lines are immutable.

Do not:

* edit a completed transaction;
* delete a completed transaction;
* change a completed transaction to `voided`;
* change an original sale line to `returned`;
* rewrite completed tax, tender, inventory, cost, or stored-value values.

Corrections use new linked records:

* return lines;
* refund tenders;
* post-void transactions;
* inventory reversals;
* stored-value reversals;
* reconciliation adjustments.

### 4.10 Atomic POS completion

POS completion must be atomic and idempotent.

Completion coordinates:

* final line values;
* discounts;
* tax;
* tenders;
* inventory reservations;
* inventory movements;
* inventory-unit statuses;
* stored-value entries;
* cost snapshots;
* receipt numbering;
* transaction completion.

All required internal effects must commit together or none may commit.

Repeated completion requests must not create duplicates.

Receipt numbers are assigned only during successful completion.

### 4.11 Business days and sessions

Keep these concepts distinct:

* business day;
* reporting date;
* business-day Z number;
* POS session;
* session Z number;
* POS device;
* cash drawer.

Do not collapse device, session, and drawer into one record.

A business day cannot close while a session remains open.

Closing and reconciliation remain separate.

The rule for assigning the reporting date remains unresolved. Store the reporting date explicitly and do not derive policy from timestamps without an accepted decision.

### 4.12 Authorization

Permissions, numeric authority, and approvals are separate concepts.

* Permissions are evaluated in store context.
* Role names do not control application behavior.
* Numeric limits supplement permissions.
* Restricted actions may require an independent approval.
* Approvers authenticate with their own credentials.
* Approval records retain requester, approver, reason, value, and authority context.

A user’s default store is a navigation preference and does not grant access.

### 4.13 Stored value

Gift cards, store credit, and trade credit share infrastructure but remain separately reportable.

Stored value uses:

* a stored-value account;
* an append-only ledger;
* a cached current balance where useful.

The ledger is authoritative.

Issuance creates liability.

Redemption is tender, not a discount.

Corrections create reversing entries.

Stored-value activity and related POS activity must commit atomically.

---

## 5. Domain ownership

Do not duplicate records or business rules across domains.

### Organization and Authorization owns

* organizations;
* stores;
* users;
* store memberships;
* roles;
* permissions;
* authority limits;
* POS devices;
* cash drawers;
* approvals.

### Catalog and Products owns

* product identity;
* canonical identifiers;
* product metadata;
* variants;
* variant SKUs;
* option structures;
* formats;
* conditions;
* inventory-tracking mode;
* sale-eligibility inputs.

### Classification and Configuration owns

* merchandise classes;
* departments;
* tax categories;
* store tax rules;
* discount reasons;
* return policies;
* return reasons;
* tender types;
* cash-movement types.

### Product Requests owns

* customer demand;
* staff suggestions;
* requested quantity;
* request priority;
* needed-by dates;
* request status;
* relationships to supply allocations.

### Vendors and Purchasing owns

* vendors;
* vendor sources;
* purchase orders;
* purchase-order lines;
* expected supply;
* expected cost;
* on-order intent.

### Receiving and Inventory owns

* receipts;
* receipt lines;
* stock balances;
* inventory units;
* inventory movements;
* inventory reservations;
* availability states;
* inventory adjustments;
* inventory cost.

### Point of Sale owns

* business days;
* POS sessions;
* transactions;
* line items;
* discounts;
* tax components;
* tenders;
* cash movements;
* receipts;
* transaction corrections.

### Stored Value owns

* stored-value accounts;
* stored-value balance history;
* issuance;
* reload;
* redemption;
* refund;
* adjustment;
* reversal.

### Reporting and Reconciliation owns

* report definitions;
* reconciliation;
* operational reporting;
* historical aggregation.

Reporting consumes posted source records. It does not modify them.

---

## 6. Data conventions

### 6.1 Money

Store monetary amounts in integer cents.

Examples:

```text
regular_price_cents
unit_cost_cents
tax_amount_cents
applied_amount_cents
```

Do not use floating-point types for money.

### 6.2 Rates

Use fixed-precision decimals or explicitly documented scaled integers for rates.

Tax rates may require greater precision than basis points.

Rounding must be deterministic and reproducible.

### 6.3 Timestamps and dates

Distinguish among:

* business date;
* calendar timestamp;
* effective date;
* completion date;
* posting date;
* reconciliation date.

Interpret operational timestamps using the applicable store time zone.

### 6.4 Activation

Master records referenced by history should normally be deactivated rather than deleted.

Examples include:

* products;
* variants;
* stores;
* users;
* roles;
* departments;
* merchandise classes;
* tax categories;
* vendors;
* tender types.

Deactivation must not break historical reporting.

### 6.5 Historical snapshots

Completed records must retain the values needed to reproduce their results.

Typical snapshots include:

* product and variant identity;
* descriptions;
* SKU and product identifier;
* department;
* merchandise class;
* tax category;
* return policy;
* regular and selling price;
* discounts;
* tax;
* cost;
* tender metadata;
* approval authority.

Do not rely on current master data to reproduce completed transactions.

### 6.6 Posted records

Posted financial and inventory records are not edited in place.

Corrections use explicit reversing or adjusting records.

---

## 7. Service boundaries

Prefer application services for workflows that coordinate several records or domains.

Likely service boundaries include:

* identifier normalization and resolution;
* sale-eligibility evaluation;
* effective department and tax resolution;
* product lookup;
* inventory reservation;
* inventory posting;
* product-request fulfilment;
* purchase-order allocation;
* receipt posting;
* transaction completion;
* return processing;
* post-void processing;
* stored-value posting;
* authorization evaluation;
* approval creation;
* reconciliation.

Avoid placing multi-record business workflows entirely in:

* controllers;
* callbacks;
* views;
* background-job wrappers;
* model lifecycle hooks.

Models should enforce local invariants. Services should coordinate cross-record and cross-domain behavior.

---

## 8. Transaction boundaries and concurrency

Use explicit database transactions when an operation affects more than one financial, inventory, or liability record.

Apply locking where concurrent operations could:

* reserve the same quantity;
* reserve the same inventory unit;
* consume the same stored-value balance;
* assign the same receipt number;
* complete the same transaction twice;
* receive beyond open purchase-order quantity;
* allocate future supply beyond uncommitted quantity.

Lock ordering should be deterministic to reduce deadlocks.

Do not rely on UI state to guarantee consistency.

Use database constraints where practical for invariants such as:

* unique variant SKU;
* unique inventory-unit identifier;
* unique stored-value account number;
* one stock balance per store and variant;
* one active reservation per inventory unit;
* one open business day per store;
* one active cash-enabled session per drawer;
* unique receipt number within a store;
* unique completion idempotency key.

Application validation should complement, not replace, database protection.

---

## 9. Testing expectations

Every material change should include tests appropriate to its risk.

### 9.1 Required categories

Use:

* model tests for local validations and constraints;
* service tests for business rules;
* request or controller tests for access and error behavior;
* integration tests for cross-domain workflows;
* system tests for important user paths;
* concurrency tests for reservations, balances, sequences, and stored value;
* idempotency tests for posting operations;
* reversal tests for immutable completed activity.

### 9.2 High-risk workflows

Changes to the following require both success and failure-path tests:

* transaction completion;
* inventory reservation;
* receipt posting;
* inventory adjustment;
* return completion;
* post-void;
* stored-value issuance or redemption;
* cash movement;
* business-day close;
* manager approval;
* receipt numbering;
* purchase-order allocation.

### 9.3 Atomicity tests

Verify that failures do not leave partial effects.

Examples:

* no inventory movement without completed POS;
* no completed POS without finalized tender;
* no stored-value entry without related completed activity;
* no receipt number consumed on failed completion;
* no accepted receipt quantity without inventory posting;
* no released reservation when completion rolls back.

### 9.4 Historical integrity tests

Verify that changes to current master data do not change historical results.

Examples:

* department renamed after sale;
* tax rate changed after sale;
* price changed after sale;
* product description changed after sale;
* cost changed after sale;
* return policy changed after sale.

Completed transaction reports must retain the original snapshots.

---

## 10. Documentation requirements

Update documentation when a change:

* changes a domain boundary;
* adds or removes a major entity;
* changes a lifecycle status;
* changes an invariant;
* changes inventory ownership or availability;
* changes request, allocation, or reservation behavior;
* changes transaction correction behavior;
* changes authorization or approval;
* changes stored-value accounting;
* changes a cross-domain workflow.

### ADR required

Create or revise an ADR when a decision:

* affects several domains;
* changes ownership of important data;
* changes a durable architectural constraint;
* selects among meaningful alternatives;
* reverses an accepted decision.

Do not create an ADR for a minor field rename or routine implementation detail.

### Domain Specification update

Update the applicable domain specification when behavior, terminology, statuses, permissions, workflows, or invariants change.

### Schema update

Update schema documentation when tables, fields, constraints, indexes, enums, or relationships change.

### Workflow update

Update a workflow document when the user-visible or record-level sequence changes.

### Roadmap update

Update the roadmap when scope, dependencies, phase status, or deferred work changes.

---

## 11. Pull-request expectations

Branching, PR size, merge strategy, and `main` protection follow [`docs/implementation/git-workflow.md`](docs/implementation/git-workflow.md): trunk-based development on `main`, short-lived branches, squash merges, and no permanent `develop` or phase branches.

A pull request should explain:

* which domain is affected;
* which ADRs govern the change;
* which invariants are preserved;
* which schema changes are included;
* which tests were added;
* which documentation was updated;
* which open questions remain.

Suggested pull-request section:

```markdown
## Architecture and documentation

- [ ] Applicable ADRs reviewed
- [ ] Domain Specification reviewed
- [ ] No architectural decision changed
- [ ] ADR added or clarified
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

---

## 12. Prohibited implementation patterns

Do not:

* sell a Product without resolving a Product Variant;
* use inventory-unit rows for every interchangeable copy;
* encode mutable business meaning in generated identifiers;
* recreate a separate display-category hierarchy;
* treat internal store areas as authoritative inventory owners;
* use `pending` as the inventory commitment quantity;
* change `on_hand` without an inventory movement;
* represent expected purchase-order quantity as physical inventory;
* create an inventory reservation for merchandise not physically present;
* restrict one receipt to one purchase order;
* mutate completed POS records;
* mark original sale lines as returned;
* assign receipt numbers before successful completion;
* use role names directly in authorization logic;
* treat stored-value redemption as a discount;
* overwrite stored-value ledger entries;
* use current master data to reinterpret completed history;
* add speculative workflows or tables for unresolved domains without documenting the assumption.

---

## 13. Safe change process

For substantial work:

1. identify the affected domain;
2. read the governing ADRs;
3. identify established invariants;
4. identify open design questions;
5. inspect current implementation and tests;
6. make the smallest coherent change;
7. add database constraints where appropriate;
8. add success, failure, concurrency, and reversal tests as applicable;
9. update governing documentation;
10. state any remaining mismatch or unresolved decision in the pull request.

When the requested behavior conflicts with an accepted ADR, stop implementation of the conflicting portion and surface the conflict clearly.

---

## 14. Repository stack and commands

### 14.1 Application stack

ShelfStack currently uses:

* Ruby 3.4.9;
* Rails 8.1;
* PostgreSQL;
* Puma;
* Propshaft;
* Importmap;
* Turbo;
* Stimulus;
* Solid Cache;
* Solid Queue;
* Solid Cable;
* Minitest;
* Capybara and Selenium for system tests;
* RuboCop Rails Omakase;
* Brakeman;
* Bundler Audit;
* Docker Compose for the standard development environment.

Do not introduce Node.js, npm, Yarn, or a JavaScript bundler merely to add ordinary frontend behavior. The application currently uses Rails Importmap and Hotwire.

A change to the JavaScript or asset-build strategy should be intentional and documented.

---

### 14.2 Preferred development environment

The preferred development environment uses Docker Compose.

The Compose configuration provides:

* a Rails `web` service;
* a PostgreSQL 17 `db` service;
* a persistent Bundler volume;
* a persistent PostgreSQL data volume;
* application access on port `3000`.

For one-off Rails and `bin/*` commands, prefer the repository wrapper [`dev/rails-docker`](dev/rails-docker). It runs `docker compose exec web …` when the `web` service is already up, otherwise `docker compose run --rm web …`:

```bash
./dev/rails-docker bin/rails db:migrate
./dev/rails-docker bin/rails test
./dev/rails-docker bin/setup --skip-server
./dev/rails-docker bin/ci
```

When Compose environment flags are required (for example `RAILS_ENV=test`), call `docker compose run` directly:

```bash
docker compose run --rm -e RAILS_ENV=test web bin/rails db:test:prepare test
```

Build the development image:

```bash
docker compose build
```

Prepare the application and database:

```bash
./dev/rails-docker bin/setup --skip-server
```

Start the application:

```bash
docker compose up
```

Open:

```text
http://localhost:3000
```

Stop the application:

```bash
docker compose down
```

Remove containers and project volumes when a complete local reset is intentionally required:

```bash
docker compose down --volumes
```

Do not remove volumes as part of routine setup or testing.

---

### 14.3 Repository setup script

Use the repository setup script instead of reproducing its operations manually:

```bash
bin/setup
```

The setup script:

1. checks or installs bundled gems;
2. prepares the database;
3. optionally resets the database when passed `--reset`;
4. clears old logs and temporary files;
5. starts the development server unless passed `--skip-server`.

For setup without starting the server:

```bash
bin/setup --skip-server
```

For an intentional database reset:

```bash
bin/setup --reset
```

Inside Docker:

```bash
docker compose run --rm web bin/setup --skip-server
```

Do not use `--reset` unless destroying local development data is intended.

---

### 14.4 Start the development server

The canonical development-server command is:

```bash
bin/dev
```

The current `bin/dev` script starts the Rails server.

Inside Docker, use:

```bash
docker compose up
```

To run the web service interactively:

```bash
docker compose run --rm --service-ports web bin/dev
```

---

### 14.5 Database commands

Prepare the development and test databases:

```bash
bin/rails db:prepare
```

Run pending migrations:

```bash
bin/rails db:migrate
```

Seed canonical permission definitions:

```bash
bin/rails db:seed
```

Bootstrap an installation organization, store, and administrator (explicit; safe to re-run without reactivating disabled access or restoring removed administrator permissions):

```bash
bin/rails shelfstack:bootstrap
```

Outside development, set `SHELFSTACK_BOOTSTRAP_ORG_CODE`, `SHELFSTACK_BOOTSTRAP_ORG_NAME`, `SHELFSTACK_BOOTSTRAP_STORE_CODE`, `SHELFSTACK_BOOTSTRAP_STORE_NAME`, `SHELFSTACK_BOOTSTRAP_USERNAME`, and `SHELFSTACK_BOOTSTRAP_PASSWORD`. Optional: `SHELFSTACK_BOOTSTRAP_RESET_PASSWORD=1` in development/test to reset the bootstrap user password on re-run.

Bootstrap aborts if an organization already exists under a different code (INV-ORG-001). Administrator catalog permissions are granted only when the administrator role is first created. To re-grant every catalog permission later (audited):

```bash
bin/rails shelfstack:sync_admin_permissions
```

Seed organization-owned reference data (identifier sequences and classification/catalog CSV masters):

```bash
bin/rails shelfstack:seed_reference_data
```

`bin/setup` runs `db:seed`, `shelfstack:bootstrap`, and `shelfstack:seed_reference_data` after preparing the database.

Reset the development database:

```bash
bin/rails db:reset
```

Prepare the test database:

```bash
RAILS_ENV=test bin/rails db:test:prepare
```

Inside Docker, prefix commands with:

```bash
docker compose run --rm web
```

For example:

```bash
docker compose run --rm web bin/rails db:migrate
```

Do not edit generated schema files manually. Change the database through migrations and regenerate the schema through Rails.

---

### 14.6 Tests

Run the Rails test suite:

```bash
bin/rails test
```

Inside Docker:

```bash
docker compose run --rm -e RAILS_ENV=test web \
  bin/rails db:test:prepare test
```

Run system tests:

```bash
bin/rails test:system
```

Inside Docker:

```bash
docker compose run --rm -e RAILS_ENV=test web \
  bin/rails db:test:prepare test:system
```

Run a specific test file:

```bash
bin/rails test test/path/to/test_file.rb
```

Run a specific test by line number:

```bash
bin/rails test test/path/to/test_file.rb:42
```

Changes affecting inventory, money, tax, authorization, stored value, transaction completion, or immutable history must not rely solely on broad system tests. Add focused model, service, integration, failure-path, and concurrency tests as applicable.

---

### 14.7 Linting

Run Ruby style checks:

```bash
bin/rubocop
```

Apply safe automatic corrections only when appropriate:

```bash
bin/rubocop -a
```

Do not apply unsafe bulk corrections without reviewing the resulting changes.

Inside Docker:

```bash
docker compose run --rm web bin/rubocop
```

---

### 14.8 Security checks

Run Rails static security analysis:

```bash
bin/brakeman --no-pager
```

Run the Ruby dependency audit:

```bash
bin/bundler-audit
```

Run the Importmap dependency audit:

```bash
bin/importmap audit
```

Inside Docker:

```bash
docker compose run --rm web bin/brakeman --no-pager
docker compose run --rm web bin/bundler-audit
docker compose run --rm web bin/importmap audit
```

Do not suppress a security warning merely to make CI pass. Any ignored advisory or scanner finding must include a documented reason.

---

### 14.9 Full local CI suite

Run the repository’s consolidated CI script:

```bash
bin/ci
```

The current CI script performs:

1. setup without starting the server;
2. RuboCop;
3. Bundler Audit;
4. Importmap audit;
5. Brakeman;
6. Rails tests;
7. test-environment seed validation.

System tests are currently separate from `bin/ci`.

Run them explicitly when the change affects an end-to-end browser workflow:

```bash
bin/rails test:system
```

Inside Docker:

```bash
docker compose run --rm web bin/ci
```

Before completing substantial work, prefer running:

```bash
bin/ci
bin/rails test:system
```

When system tests are not relevant or cannot be run, state that explicitly in the pull request.

---

### 14.10 Rails utilities

Open a Rails console:

```bash
bin/rails console
```

Open a database console:

```bash
bin/rails dbconsole
```

List routes:

```bash
bin/rails routes
```

Run a Rails task:

```bash
bin/rails task:name
```

Inside Docker:

```bash
docker compose run --rm web bin/rails console
```

---

### 14.11 Logs and temporary files

Follow application logs under Docker:

```bash
docker compose logs -f web
```

Follow database logs:

```bash
docker compose logs -f db
```

Clear Rails logs and temporary files:

```bash
bin/rails log:clear tmp:clear
```

The setup script already performs this cleanup.

---

### 14.12 Native host development

Native development requires at minimum:

* Ruby matching `.ruby-version`;
* Bundler;
* PostgreSQL;
* PostgreSQL development libraries;
* libvips where image processing is exercised.

The database configuration defaults to the Docker hostname `db`.

For a PostgreSQL server running directly on the host, set the applicable environment variables, for example:

```bash
export DATABASE_HOST=localhost
export DATABASE_PORT=5432
export DATABASE_USERNAME=postgres
export DATABASE_PASSWORD=postgres
export DATABASE_NAME=shelfstack_development
export TEST_DATABASE_NAME=shelfstack_test
```

Then run:

```bash
bin/setup
```

Do not commit developer-specific credentials or environment overrides.

---

### 14.13 Command-selection rules for agents

Agents should:

* use repository-provided `bin/*` commands rather than global executables;
* **default to Docker** via `./dev/rails-docker …` (or `docker compose exec` / `run --rm web`) for Rails, tests, setup, RuboCop, and `bin/ci`;
* use bare host `bin/rails` only when host Postgres env vars are explicitly configured (see §14.12);
* prefer `./dev/rails-docker bin/setup --skip-server` for initial preparation;
* prefer `./dev/rails-docker bin/ci` (or `docker compose run --rm web bin/ci`) for the consolidated local validation suite;
* prepare the test database in Docker before running tests in a fresh environment;
* run focused tests during development;
* run the broadest relevant checks before completing work;
* report which commands were run and whether they passed.

Agents should not:

* claim tests passed without running them;
* omit a failing result;
* reset or delete databases without explicit need;
* remove Docker volumes as routine cleanup;
* add a new package manager or asset tool without architectural justification;
* bypass repository scripts with undocumented alternatives;
* modify CI merely to conceal a failure.


---

## 15. Final review checklist

Before completing work, verify:

* the change follows accepted ADRs;
* domain ownership remains clear;
* unresolved architecture was not invented;
* inventory and financial effects are explainable;
* completed records remain immutable;
* atomicity and idempotency are preserved;
* database constraints protect critical invariants;
* store context and user identity are retained;
* historical snapshots remain reproducible;
* relevant tests pass;
* documentation is current;
* no archived document was treated as authoritative.
