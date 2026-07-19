# Service Catalog

**Status:** Living catalog of introduced application services  
**Purpose:** Record concrete services as they are implemented — not a speculative design of later phases  
**Principle:** See [AGENTS.md](../../AGENTS.md) §7 (do not restate here)

Add a row when a service lands in the codebase. Do not pre-design Phase 6–8 classes.

## Columns

| Column | Meaning |
| --- | --- |
| Service | Ruby constant / module path |
| Domain owner | Owning business domain |
| Introduced | Delivery phase |
| Transactional? | Runs inside an explicit DB transaction |
| Idempotent? | Safe under replay with the same key/input |
| Locks | Primary lock targets |
| Input | Principal inputs |
| Result | Principal outputs / side effects |

## Phase 1 — Organization and authorization

| Service | Domain owner | Introduced | Transactional? | Idempotent? | Locks | Input | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Authorization::EvaluatePermission` | Organization and Authorization | 1 | No | Yes | None | User, store, permission key | `:allow` / `:deny` |
| `Authorization::EvaluateAuthority` | Organization and Authorization | 1 | No | Yes | None | User, store, limit key, requested value | `AuthorityResult` (`:allow` / `:requires_approval` / `:deny`); fail-closed on inactive role and invalid requested values; membership overrides only (OD-013) |
| `Administration::RecordAuditEvent` | Organization and Authorization | 1 | Caller | Yes* | None | Actor, org, action, subject, metadata | Append-only audit row |
| `Administration::CreateRole` / `UpdateRole` | Organization and Authorization | 1 | Yes | No | Role / role_permissions | Role attrs, permission IDs | Persisted role + assignments + audit; invalid permission IDs abort |
| `Administration::SyncAdministratorPermissions` | Organization and Authorization | 1 | Yes | No | Role permissions | Administrator role, actor | Additive grant of all catalog permissions + audit |
| `Administration::CreateUser` / `UpdateUser` | Organization and Authorization | 1 | Yes | No | User | User attrs | Persisted user + audit (no secrets in metadata) |
| `Administration::CreateStore` / `UpdateStore` | Organization and Authorization | 1 | Yes | No | Store | Store attrs | Persisted store + audit |
| `Administration::CreateStoreMembership` / `UpdateStoreMembership` | Organization and Authorization | 1 | Yes | No | Membership | Membership attrs | Persisted membership + audit; identity immutable on update |
| `Administration::CreatePosDevice` / `UpdatePosDevice` | Organization and Authorization | 1 | Yes | No | Device | Device attrs | Persisted device + audit |
| `Administration::CreateCashDrawer` / `UpdateCashDrawer` | Organization and Authorization | 1 | Yes | No | Drawer | Drawer attrs | Persisted drawer + audit |

\*Audit write itself is not replay-idempotent; mutations call it once inside their transaction.

## Phase 2 — Catalog

| Service | Domain owner | Introduced | Transactional? | Idempotent? | Locks | Input | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Identifiers::Normalize` | Catalog and Products | 2 | No | Yes | None | Raw identifier string | `Identifiers::NormalizedIdentifier` (canonical value, type, validation status, warnings) |
| `Identifiers::Generate` | Catalog and Products | 2 | Yes | No* | `identifier_sequences` row (`lock`) | Namespace (`21`/`27`/`28`/`29`) | Generated EAN-13; raises on ten-digit overflow |
| `Catalog::CreateProduct` | Catalog and Products | 2 | Yes | No* | Sequence + product uniqueness | Org, actor, store, product/variant attrs, optional identifier | Product + Standard variant (`28` SKU); allocation inside txn; collision retry for generated ids |
| `Catalog::UpdateProduct` | Catalog and Products | 2 | Yes | No | Product row | Product, attrs (no identifier) | Updated product + audit |
| `Catalog::UpdateVariant` | Catalog and Products | 2 | Yes | No | Variant row | Variant, attrs (no sku) | Updated variant + audit |
| `Catalog::UpdateProductWithStandardVariant` | Catalog and Products | 2 | Yes | No | Product + variant | Product, standard variant, attrs | Atomic product+variant update + audits |
| `Catalog::Lookup` | Catalog and Products | 2 | No | Yes | None | Organization, query | `Catalog::LookupResult` (products, match_kind; ambiguous alternates) |
| `Catalog::SaleEligibility` | Catalog and Products | 2 | No | Yes | None | Variant, store, as-of date | `Catalog::SaleEligibilityResult` distinct readiness blockers |

\*Generation is not replay-idempotent; callers must not retry blindly without checking uniqueness errors.

## Phase 3 — Quantity inventory

| Service | Domain owner | Introduced | Transactional? | Idempotent? | Locks | Input | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Inventory::CalculateQuantityCost` | Receiving and Inventory | 3 | No | Yes | None | Prior balance state, qty/cost inputs | Allocated value, average, quality (pure) |
| `Inventory::DepartmentEstimate` | Receiving and Inventory | 3 | No | Yes | None | Product variant | Optional Department margin estimate |
| `Inventory::PostLedgerEntry` | Receiving and Inventory | 3 | Yes | Yes (posting key) | `stock_balances` row (`lock!`) | Qty/value inputs, source, posting key | Ledger insert + On Hand / valuation-state update |
| `Inventory::CreateAdjustment` | Receiving and Inventory | 3 | Yes | No | Adjustment | Draft header + lines | Persisted draft + audit |
| `Inventory::UpdateAdjustment` | Receiving and Inventory | 3 | Yes | No | Adjustment (`reload.lock!`) | Draft attrs + lines | Updated draft + audit; rejects if no longer draft |
| `Inventory::PostAdjustment` | Receiving and Inventory | 3 | Yes | Yes (header posting key) | Adjustment (`reload.lock!`); balances via PostLedgerEntry | Draft adjustment | Sorted line posts + posted status + audit |
| `Inventory::CancelAdjustment` | Receiving and Inventory | 3 | Yes | No | Adjustment (`reload.lock!`) | Draft + cancel note | Cancelled status + audit |

| `Inventory::Reserve` | Receiving and Inventory | 3 | Yes | Yes (active source) | Balance + active reservation | Store, variant, qty, source | Active reservation; may warn on negative available |
| `Inventory::ReleaseReservation` | Receiving and Inventory | 3 | Yes | Yes | Reservation (+ balance) | Reservation | Released reservation; reserved qty restored |
| `Classification::CreateInventoryAdjustmentReason` / `UpdateInventoryAdjustmentReason` | Classification and Configuration | 3 | Yes | No | Reason | Reason attrs | Persisted reason + audit (`code`/`kind` immutable on update) |

### Phase 3 service notes

- `Inventory::PostLedgerEntry` is the exclusive owner of Stock Balance On Hand and valuation-state changes for quantity-tracked variants. Atomic with ledger insert; idempotent via posting key. Used by adjustment posting and later sale/receipt posting. Callers must not pre-lock balances. After each known positive resulting balance, syncs `last_known_*` to the carrying average; does not clear last-known when On Hand reaches zero.
- `Inventory::CalculateQuantityCost` is a pure calculation helper for positive MWA inbound/outbound allocation, first-positive-from-zero initialization, cost-quality aggregation, aggregate cost-correction deltas, and residual-cent assignment for fully depleted positive balances. Must not persist balances by itself.
- `Inventory::UpdateAdjustment` / `PostAdjustment` / `CancelAdjustment` lock the adjustment header and recheck draft status before mutating. Posted or cancelled adjustments and lines are immutable.
- `Inventory::PostAdjustment` coordinates draft → posted adjustment kinds (`opening_inventory`, `quantity_only`, `cost_correction`) by sorting lines and calling `PostLedgerEntry` under one outer transaction with permission checks.


### Phase 3 concurrency test matrix

- concurrent quantity-only posts on same Store × Variant
- concurrent opening vs quantity-only
- concurrent cost correction vs quantity-only (positive balance)
- failed post rolls back ledger and balance together
- idempotent retry does not duplicate value deltas

## Phase 4a — Editable POS

| Service | Domain owner | Introduced | Transactional? | Idempotent? | Locks | Input | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Pos::OpenBusinessDay` | Point of Sale | 4a | Yes | No | `business_days` (lock query) | Store, actor, optional reporting date | Open Business Day; rejects a second open day per store |
| `Pos::CloseBusinessDay` | Point of Sale | 4a | Yes | Yes | Business Day (`lock`) | Business Day, actor | Closed Business Day; blocks while a Session is open |
| `Pos::OpenSession` | Point of Sale | 4a | Yes | No | Device/drawer open-session existence checks | Business Day, store, device, cashier, optional drawer | Open Session; device and cash-drawer exclusivity |
| `Pos::CloseSession` | Point of Sale | 4a | Yes | Yes | Session (`lock`) | Session, actor | Closed Session; blocks while it controls an open Transaction; leaves Suspended Transactions untouched |
| `Pos::OpenTransaction` | Point of Sale | 4a | Caller | No | None | Session, actor | Open Transaction with generated `public_id`; origin/active session set |
| `Pos::ResolveScan` | Point of Sale | 4a | No | Yes | None | Organization, scan/search query, store | `Pos::ResolveScanResult` (variant, ambiguity, blockers/warnings via `Catalog::SaleEligibility`) |
| `Pos::AddLine` | Point of Sale | 4a | Yes | No | Reservation via `Inventory::Reserve` | Transaction, variant, quantity, actor | Pending product line; reserves only `quantity`-tracked variants |
| `Pos::AddOpenRingLine` | Point of Sale | 4a | Caller | No | None | Transaction, department, price, optional description, actor | Pending open-ring line; no Variant/Reservation; blank description snapshots to Department name |
| `Pos::UpdateLineQty` | Point of Sale | 4a | Yes | No | Line (`lock`); reservation via `Inventory::Reserve` | Line, quantity, actor | Updated quantity; re-reserves in place for quantity-tracked lines |
| `Pos::RemoveLine` | Point of Sale | 4a | Yes | No | Line (`lock`); reservation via `Inventory::ReleaseReservation` | Line, actor, optional reason | Soft-removed line (`status: removed`); releases any active reservation; row retained |
| `Pos::SuspendTransaction` | Point of Sale | 4a | Yes | No | Transaction (`lock`) | Transaction, actor | Suspended Transaction; retains Reservations; clears active-session control |
| `Pos::RecallTransaction` | Point of Sale | 4a | Yes | No | Transaction (`lock`) | Transaction, session, actor | Reopened Transaction bound to the recalling Session; concurrent recall has exactly one winner |
| `Pos::CancelTransaction` | Point of Sale | 4a | Yes | No | Transaction (`lock`); reservations via `Inventory::ReleaseReservation` | Transaction, actor, optional reason | Cancelled Transaction; releases all pending-line Reservations; no ledger/receipt effect |

### Phase 4a notes

- `Pos::AddLine` / `Pos::AddOpenRingLine` resolve Department and Tax Category using the same variant-override → product-default → merchandise-class-default (→ department-default for tax) order as `Catalog::SaleEligibility`.
- Individually tracked variants (`inventory_tracking_mode: individual`) are rejected by `Pos::AddLine` until Phase 4d.
- No service in this list sets `pos_transactions.status` or `pos_line_items.status` to `completed`; that is reserved for `Pos::CompleteTransaction` (Phase 4c).

## Phase 4b — Price, tax persistence, discounts, approvals

| Service | Domain owner | Introduced | Transactional? | Idempotent? | Locks | Input | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Classification::CreateStoreTaxRate` / `UpdateStoreTaxRate` | Classification and Configuration | 4b | Yes | No | Store Tax Rate | Store, rate attrs (code immutable on update) | Persisted Store Tax Rate + audit |
| `Classification::CreateStoreTaxRule` / `UpdateStoreTaxRule` | Classification and Configuration | 4b | Yes | No | Store Tax Rule | Store, Tax Category, optional Store Tax Rate, treatment, fraction, order, compounding, effective dates | Persisted Store Tax Rule + audit; overlap and treatment/rate consistency validated on the model |
| `Tax::CalculateTransaction` | Point of Sale / Classification and Configuration | 4b | No (read-only rule resolution) | Yes | None | Store, completion date, duck-typed lines (`id`, `tax_category_id`, `direction`, `taxable_merchandise_amount_cents`, `position`) | Per-line component results (taxable base, amount, snapshots), warnings, blockers; missing effective rule is a blocker, never an exemption |
| `Pos::AuthorizeAction` | Point of Sale / Organization and Authorization | 4b | Yes (only when creating a `PosApproval`) | No | None | Store, requester, permission key, optional authority `limit_key`/requested value, optional approver + approver PIN | `:allowed` / `:approved` (with `PosApproval`) / `:requires_approval` / `:denied`; requester lacking permission or authority escalates to an independent approver rather than a flat deny |
| `Pos::OverridePrice` | Point of Sale | 4b | Yes | No | Line (`lock`) | Line, requested unit price, actor, optional reason/approver | Overridden `unit_price_cents`; audit event; triggers `Pos::RecalculateTransaction` |
| `Pos::ApplyDiscount` | Point of Sale | 4b | Yes | No | Transaction (`lock`) | Transaction, scope (`line`/`transaction`), method, rate/amount, `tax_treatment` (defaults `reduces_taxable_base`), actor, optional discount reason/approver | `PosDiscount` + largest-remainder `PosDiscountAllocation`s; audit event; triggers `Pos::RecalculateTransaction` |
| `Pos::OverrideTaxCategory` | Point of Sale | 4b | Yes | No | Line (`lock`) | Line, Tax Category, required reason, actor, optional approver | Overridden line Tax Category; retains first pre-override category/actor/timestamp/reason; audit event; triggers `Pos::RecalculateTransaction` |
| `Pos::ApplyTaxExemption` | Point of Sale | 4b | Yes | No | Transaction (`lock`) | Transaction, exemption type, actor, optional notes/approver | `PosTaxExemption` (`coverage: whole_transaction` only; one per Transaction, re-applying is a no-op success); audit event; triggers `Pos::RecalculateTransaction` |
| `Pos::RecalculateTransaction` | Point of Sale | 4b | Yes | Yes (same inputs reproduce the same persisted rows) | Transaction (`lock`) | Transaction | Deletes and re-persists `pos_line_item_taxes` for non-completed lines from `Tax::CalculateTransaction` against the currently allocated taxable base; returns subtotal/discount/tax/net totals and blockers/warnings for display; does not write cached totals onto `pos_transactions` |

### Phase 4b tax notes

- `Tax::CalculateTransaction` is the pure ADR-0014 hybrid calculation: taxability/base resolved per line, one round-half-up aggregation per transaction component (`store_tax_rate_id` + `calculation_order` + `compounds_on_prior_tax`) and line direction, largest-remainder cent allocation (tie-break: remainder desc, then position asc, then id asc), and ascending-`calculation_order` compounding using already-finalized (allocated) prior tax amounts on the line. It does not persist anything.
- `exempt` treatment produces no `Tax::CalculateTransaction` *component* result (no collectible tax to allocate); `zero_rated` produces an explicit zero-amount component so the base still reports. `Pos::RecalculateTransaction` still persists a zero-amount `pos_line_item_taxes` row with `treatment_snapshot: "exempt"` for exempt rules, so receipts/audits can show which rule exempted the line rather than silently omitting the category.
- Effective Store Tax Rules are resolved by the **store-local calendar date at completion**, not the Business Day `reporting_date` (ADR-0014).
- `Pos::RecalculateTransaction` runs after every 4a/4b line- or transaction-mutating service (`AddLine`, `AddOpenRingLine`, `UpdateLineQty`, `RemoveLine`, `OverridePrice`, `ApplyDiscount`, `OverrideTaxCategory`, `ApplyTaxExemption`); a missing effective Store Tax Rule surfaces as a blocker in that service's `warnings`, never an implicit exemption.
- `Pos::AuthorizeAction` centralizes ADR-0011 permission/authority/approval evaluation for all restricted 4b actions: the requester's own numeric authority (`EvaluateAuthority`, membership-override columns per OD-013 interim) is checked first when a `limit_key` is given; an approver must differ from the requester, authenticate with their own PIN (`authenticate_pin`, not the requester's), hold the approving permission, and (for numeric actions) independently have authority covering the requested value.
- Completion-time blocker revalidation under a Transaction lock (`Pos::CompleteTransaction`) is Phase 4c work.

## Phase 4c — Inventory sale bridge, tender, and atomic completion

| Service | Domain owner | Introduced | Transactional? | Idempotent? | Locks | Input | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Inventory::ConvertReservation` | Receiving and Inventory | 4c | Yes | Yes (posting key) | Balance, then Reservation (Reserve/ReleaseReservation order) | POS line, posted-by actor | Posts an outbound `sale` via `PostLedgerEntry`; decrements `reserved`; marks Reservation `converted`; snapshots `cost_unit_cost_cents`/`cost_extended_cents`/`cost_method_snapshot`/`cost_quality_snapshot` on the line; warns on negative resulting `available` |
| `Pos::AddCashTender` | Point of Sale | 4c | Yes | No | Transaction (`lock`) | Transaction, cash Tender Type, amount tendered, actor | `pending` `PosTender` capped at balance due; change computed; does not itself require the Transaction to be `editable?` |
| `Pos::AddCardTender` | Point of Sale | 4c | Yes | No | Transaction (`lock`) | Transaction, card Tender Type, amount, authorization code, optional terminal reference, actor | `authorized` `PosTender` (external approval already confirmed by the cashier; ADR-0009 standalone-terminal limitation) |
| `Pos::RemoveTender` | Point of Sale | 4c | Yes | No | Tender (`lock`) | Tender, actor, optional reason | `pending` → `removed`; `authorized` → `voided`; restores `PosTransaction#editable?` |
| `Pos::CreateCashMovement` | Point of Sale | 4c | Yes | No | None (session-scoped, not Transaction-scoped) | Session, Cash Movement Type, amount, actor, optional reason/reference/approver | `PosCashMovement`; escalates through `Pos::AuthorizeAction` (`maximum_paid_out_cents`) when the type `requires_approval` |
| `Pos::CompleteTransaction` | Point of Sale | 4c | Yes | Yes (`completion_idempotency_key`) | Transaction, Session, pending Lines, unresolved Tenders (all `lock`); Balance/Reservation via `Inventory::ConvertReservation`; Store (`lock`, receipt sequence) | Transaction, completing Session, actor, idempotency key | Revalidates tax under lock (blockers fail completion); converts Reservations / posts sale movements; finalizes Lines and Tenders; assigns `receipt_number`/`receipt_sequence` only on success; marks Transaction `completed`; replays the prior result for a repeated key on an already-completed Transaction |

### Phase 4c notes

- **Tender-state lock:** `PosTransaction#editable?` is `open? && !unresolved_tenders?` (`pending`/`authorized` Tenders lock lines, prices, discounts, tax category, and exemptions). Every 4a/4b commercial-editing service re-checks `editable?`/line status *after* acquiring its row lock (`Pos::RemoveLine`, `Pos::UpdateLineQty`, `Pos::OverridePrice`, `Pos::OverrideTaxCategory`), and `Pos::AddLine`/`Pos::AddOpenRingLine` lock the Transaction itself before inserting a new Line, so none of them can slip a commercial mutation past a Transaction that `Pos::CompleteTransaction` is concurrently completing.
- `Pos::SuspendTransaction` and `Pos::CancelTransaction` are hardened against Tenders: Suspend is blocked outright while an unresolved Tender exists (domain: "Suspension ... requires no unresolved Tender activity"); Cancel resolves (removes/voids) any unresolved Tenders itself before cancelling, so no completed Tender can survive a cancelled Transaction (ADR-0008).
- `Pos::CloseSession`'s pre-existing "blocks while it controls an open Transaction" guard already enforces "Session close blocked by unresolved Tenders," because an unresolved Tender can only exist on a still-`open` Transaction (Suspend's guard above rules out the alternative).
- `Pos::CompleteTransaction` scope matches phase-04: Product-line tracking modes `quantity` and `none` only; individual units and Stored Value are out of scope (4d/6). Departments are re-checked (`active?`/`postable?`) directly off the persisted Line at completion, independent of `Catalog::SaleEligibility`, since a Department can be deactivated after a Line was added.
- Receipt Number format (v1, not architecturally locked beyond OD-002's sequence ownership): `"#{store.code}-#{receipt_sequence.to_s.rjust(6, '0')}"`.

## Later phases (add when implemented)

Placeholder only — do not invent APIs now:

- Phase 5: receipt posting, PO placement, allocation services
- Phase 6: stored-value posting, post-void

## Related

- [roadmap.md](roadmap.md)
- [testing.md](testing.md)
- [../reference/identifiers.md](../reference/identifiers.md)
- [../domains/authorization-permissions.md](../domains/authorization-permissions.md)
