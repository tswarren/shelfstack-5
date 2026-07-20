# Test Review — 2026-07-19

**Status:** Accepted — drives [Phase 4g test hardening](../phases/phase-04g-test-hardening.md)  
**Scope reviewed:** application models, controllers, services, route surface, existing Minitest files, and governing architecture/testing guidance.  
**Purpose:** Identify tests that should be added, changed, or removed without changing application behavior.

**Phase 4g sequencing note:** The audit’s largest *volume* gaps are request and model coverage (High #1–2). The highest *risk* items for gating Phase 5 are completion atomicity, concurrency, immutability, and historical integrity (High #5–8). Phase 4g therefore executes integrity first (4g-1), then critical endpoint security including permission seed-drift (4g-2), then critical system workflows (4g-3). Broader classification CRUD and static model coverage remain backlog (4g-4/4g-5) and may continue alongside Phase 5.

## Executive summary

The current suite has strong coverage around high-risk service workflows that already exist: identifier normalization and generation, catalog creation and lookup, authorization evaluation, inventory posting/reservations/costing, POS transaction completion, tax calculation, linked returns, individual-unit sale completion, and several concurrency paths.

The largest gaps are not in those core service tests. They are in request/controller coverage for implemented configuration and POS endpoints, model/database invariant coverage for implemented tables without direct model tests, and a few high-risk cross-domain failure paths where the architecture requires atomicity, idempotency, and historical integrity.

## Tests to add

### High priority

1. Add controller tests for implemented routes that currently have no direct request coverage.

   The route table exposes CRUD or workflow endpoints for `business_days`, `departments`, `discount_reasons`, `inventory_adjustment_reasons`, `inventory_reservations#release`, `merchandise_classes`, `permissions#index`, POS line/tender/session/cash-movement endpoints, `product_formats`, `product_conditions`, `return_policies`, `return_reasons`, and `stock_balances`. Several of these are only covered indirectly, if at all. Add request tests for:

   - happy-path access by a user with the relevant permission;
   - denial by a user without the permission;
   - current-store or current-organization scoping;
   - audit event creation for administrative mutations where applicable;
   - workflow failures surfaced through redirects or validation responses.

2. Add model/database invariant tests for implemented tables without direct model tests.

   Add focused tests for `BusinessDay`, `CashDrawer`, `CashMovementType`, `DiscountReason`, `InventoryAdjustment`, `InventoryAdjustmentLine`, `InventoryReservation`, `Permission`, `PosApproval`, `PosCashMovement`, `PosDevice`, `PosDiscount`, `PosDiscountAllocation`, `PosLineItemTax`, `PosSession`, `PosTaxExemption`, `PosTender`, `Product`, `ProductCondition`, `ProductFormat`, `ReturnPolicy`, `ReturnReason`, `Role`, `RolePermission`, `StockBalance`, `TaxCategory`, and `TenderType` where the table has validations, check constraints, uniqueness constraints, active/inactive semantics, or historical-reference behavior.

   Keep these tests small. The goal is not to duplicate service workflow tests; it is to assert the local invariants and database protection promised by the architecture.

3. Add request tests for POS endpoint authorization and edit-state behavior.

   Service tests cover many POS business rules, but controller tests should prove web endpoints preserve the same protections. Add request tests for:

   - adding, updating, and removing line items;
   - adding and removing tenders;
   - suspending, recalling, cancelling, and completing transactions;
   - opening and closing POS sessions;
   - creating cash movements;
   - rejecting commercial edits when a transaction is not editable;
   - rejecting access across stores.

4. Add end-to-end system tests for core POS browser paths.

   The route and controller tests exercise server behavior, but the application has a user-facing register workflow. Add system tests for at least:

   - opening or selecting an active register context;
   - scanning/adding a product line;
   - collecting a cash tender and completing a transaction;
   - suspending and recalling a transaction;
   - a validation/error path that leaves the transaction editable.

5. Add high-risk atomicity tests for POS completion failures after partial workflow preparation.

   Existing tests cover short tender failure and a standalone-card external-authorization limitation. Add failure cases that ensure completion does not leave partial effects when tax calculation, receipt-number assignment, cost snapshotting, inventory conversion, or tender completion fails. Each test should assert no duplicate receipt sequence, no completed line/tender, no converted reservation, and no extra inventory ledger entry.

6. Add immutability tests for completed POS records through web and model/service entry points.

   The architecture requires completed transactions and completed lines to be immutable. Add tests that attempts to edit, remove, discount, tax-override, tender-modify, cancel, or recall a completed transaction fail without changing completed snapshots.

7. Add more historical snapshot tests.

   Add tests proving completed POS line totals, tax allocations, department/tax/category snapshots, tender snapshots, and inventory cost snapshots do not change when current master records are later edited or deactivated.

8. Add concurrency/idempotency coverage for receipt numbering and POS completion.

   Existing completion tests verify same-key replay. Add a concurrent completion test that submits the same open transaction from two threads and asserts only one success path, one receipt number, one sequence increment, one set of inventory movements, and replay or deterministic failure for the other caller.

### Medium priority

1. Add service tests for administrative create/update services that currently rely mostly on controller coverage.

   Services such as cash drawer, POS device, store, store membership, user, and classification create/update operations should have focused service tests for validation, scoping inputs, and audit metadata where behavior is non-trivial.

2. Add tests around active/inactive master data.

   The architecture says historically referenced master records should be deactivated rather than deleted. Add tests proving inactive records are hidden from new operational choices where expected but remain displayable through historical records.

3. Add tests for import helpers or remove the dead import helper if unused.

   `Classification::Import::Helpers` appears in the service tree but has no direct tests. If it is used by seed/bootstrap tasks, add tests for parsing, normalization, idempotency, and error reporting. If it is no longer used, remove the helper and any dead references.

4. Add stock-balance request tests.

   `stock_balances#index` and `show` should verify current-store scoping and cost visibility rules, especially because inventory quantities and costs are high-integrity data.

5. Add business-day controller tests.

   Service tests cover open/close rules. Add controller tests for opening with reporting dates, close blocked by open sessions, idempotent close behavior surfaced to users, and permission denials.

6. Add Bootstrap/seed permission-drift tests for new route permissions.

   As route/controller coverage expands, add tests that seeded permissions include every permission key enforced by controllers and services, and that administrator sync grants those permissions.

### Lower priority

1. Add lightweight model tests for static lookup/configuration records.

   For simple reference tables with minimal behavior, prefer one or two validation/uniqueness tests rather than exhaustive CRUD tests.

2. Add view/system checks for cost visibility and administrative index pages.

   Existing controller tests can verify assignments and response success, but a small number of system tests can catch regressions in permission-sensitive UI rendering.

## Tests to change

1. Prefer service-level assertions for business rules and keep controller tests focused on HTTP behavior.

   Some controller tests should call through the web layer only to verify routing, authorization, scoping, parameter handling, redirects, flash messages, and rendered visibility. Avoid reasserting every service invariant in request tests when the same invariant already has focused service coverage.

2. Move broad POS controller scenarios toward either system tests or focused request tests.

   End-to-end register behavior belongs in system tests. Request tests should stay narrowly focused on one endpoint and one authorization or state transition at a time.

3. Use shared setup helpers for POS and inventory fixtures.

   Several POS and inventory tests need the same business day, session, store, product variant, tender type, and opening stock setup. Consolidating setup in test helpers will reduce divergence without hiding important assertions.

4. Make concurrency tests consistently skip or warn when the database adapter cannot exercise real locking.

   Concurrency tests are important for PostgreSQL-backed behavior. If a local adapter or CI environment cannot exercise the lock semantics, the test should report that limitation explicitly rather than producing misleading pass/fail results.

5. Keep schema-dump-only differences out of behavioral test changes.

   Generated `db/schema.rb` check-constraint formatting can change across PostgreSQL/Rails versions. Treat formatting-only schema diffs as generated output, not a reason to add or change behavior tests.

## Tests that can be removed

No existing test file should be removed based on this review. The present tests align with architectural risk areas and current implementation phases.

The only removal candidates are future duplicates created while closing the gaps above. If a new controller or system test repeats the same service assertions already covered by a focused service test, keep the service test and simplify or remove the duplicative web-layer assertions.

## Suggested next test work order

1. Add request tests for uncovered implemented controllers and POS endpoints.
2. Add model/database invariant tests for high-integrity tables without direct model tests.
3. Add POS completion concurrency and immutability tests.
4. Add browser-level system tests for the register happy path and one failure path.
5. Add administrative/classification service tests where controller tests currently provide the only coverage.
