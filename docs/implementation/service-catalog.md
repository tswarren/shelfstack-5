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
| `Catalog::ResolveClassification` | Catalog and Products | 4f | No | Yes | None | Product, optional variant | Effective merchandise class, department, and tax category with source labels (variant → product → MC → department) |
| `StoreTime` | Organization and Authorization | 4f | No | Yes | None | Store, optional moment | Store-zone `today` / `at` helpers for business dates and display |

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
| `Pos::OpenSession` | Point of Sale | 4a | Yes | No | Business Day (`lock`), then device/drawer open-session checks | Business Day, store, device, cashier, optional drawer, `opening_cash_cents` when drawer present | Open Session; day status rechecked under lock; opening cash count for cash-enabled sessions |
| `Pos::CloseSession` | Point of Sale | 4a | Yes | Yes | Session (`lock`) | Session, actor | Closed Session; cash-enabled sessions require a closing cash count and snapshot expected/counted/variance; blocks while controlling an open Transaction; leaves Suspended Transactions untouched |
| `Pos::OpenTransaction` | Point of Sale | 4a | Yes | No | Session (`lock`) | Session, actor, optional cashier | Open Transaction with generated `public_id`; Session status rechecked under lock; origin/active session set |
| `Pos::ResolveScan` | Point of Sale | 4a | No | Yes | None | Organization, scan/search query, store | `Pos::ResolveScanResult` (variant, ambiguity, blockers/warnings via `Catalog::SaleEligibility`) |
| `Pos::AddLine` | Point of Sale | 4a | Yes | No | Reservation via `Inventory::Reserve` | Transaction, variant, quantity, actor | Pending product line; reserves only `quantity`-tracked variants |
| `Pos::AddOpenRingLine` | Point of Sale | 4a | Caller | No | None | Transaction, department, price, optional description, actor | Pending open-ring line; no Variant/Reservation; blank description snapshots to Department name |
| `Pos::UpdateLineQty` | Point of Sale | 4a | Yes | No | Transaction then Line (`lock`); reservation via `Inventory::Reserve` | Line, quantity, actor | Updated quantity; re-reserves in place for quantity-tracked lines |
| `Pos::RemoveLine` | Point of Sale | 4a | Yes | No | Transaction then Line (`lock`); reservation via `Inventory::ReleaseReservation` | Line, actor, optional reason | Soft-removed line (`status: removed`); releases any active reservation; row retained |
| `Pos::SuspendTransaction` | Point of Sale | 4a | Yes | No | Transaction (`lock`) | Transaction, actor | Suspended Transaction; retains Reservations; clears active-session control |
| `Pos::RecallTransaction` | Point of Sale | 4a | Yes | No | Session then Transaction (`lock`) | Transaction, session, actor | Reopened Transaction bound to the recalling Session; refreshes catalog price/classification/eligibility via `RefreshRecalledTransaction`; concurrent recall has exactly one winner |
| `Pos::CancelTransaction` | Point of Sale | 4a | Yes | No | Transaction (`lock`); reservations via `Inventory::ReleaseReservation` | Transaction, actor, optional reason | Cancelled Transaction; releases all pending-line Reservations; no ledger/receipt effect |
| `Pos::RefreshRecalledTransaction` | Point of Sale | 4a | Yes | No | Transaction then Lines (`lock`) | Open Transaction | Refreshes pending sale product prices/tax/department from catalog (preserving price and tax-category overrides); returns eligibility blockers and material change list |

### Phase 4a notes

- `Pos::AddLine` / `Pos::AddOpenRingLine` resolve Department and Tax Category via `Catalog::ResolveClassification` (same order as `Catalog::SaleEligibility`: variant override → product default → merchandise-class default → department default for tax).
- Individually tracked variants (`inventory_tracking_mode: individual`) are accepted by `Pos::AddLine` when an exact `InventoryUnit` is supplied (Phase 4d).
- No service in this list sets `pos_transactions.status` or `pos_line_items.status` to `completed`; that is reserved for `Pos::CompleteTransaction` (Phase 4c).

## Phase 4b — Price, tax persistence, discounts, approvals

| Service | Domain owner | Introduced | Transactional? | Idempotent? | Locks | Input | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Classification::CreateStoreTaxRate` / `UpdateStoreTaxRate` | Classification and Configuration | 4b | Yes | No | Store Tax Rate | Store, rate attrs (code immutable on update) | Persisted Store Tax Rate + audit |
| `Classification::CreateStoreTaxRule` / `UpdateStoreTaxRule` | Classification and Configuration | 4b | Yes | No | Store Tax Rule | Store, Tax Category, optional Store Tax Rate, treatment, fraction, order, compounding, effective dates | Persisted Store Tax Rule + audit; overlap and treatment/rate consistency validated on the model |
| `Tax::CalculateTransaction` | Point of Sale / Classification and Configuration | 4b | No (read-only rule resolution) | Yes | None | Store, completion date, duck-typed lines (`id`, `tax_category_id`, `direction`, `taxable_merchandise_amount_cents`, `position`) | Per-line component results (taxable base, amount, snapshots), warnings, blockers; missing effective rule is a blocker, never an exemption; collecting rules whose Store Tax Rate is inactive or outside its effective window are blockers |
| `Pos::AuthorizeAction` | Point of Sale / Organization and Authorization | 4b | Yes (only when creating a `PosApproval`) | No | None | Store, requester, permission key, optional authority `limit_key`/requested value, optional approver + approver PIN | `:allowed` / `:approved` (with `PosApproval`) / `:requires_approval` / `:denied`; requester lacking permission or authority escalates to an independent approver rather than a flat deny |
| `Pos::OverridePrice` | Point of Sale | 4b | Yes | No | Transaction then Line (`lock`) | Line, requested unit price, actor, optional reason/approver | Overridden `unit_price_cents` with `price_overridden_at` snapshot; audit event; triggers `Pos::RecalculateTransaction` |
| `Pos::ApplyDiscount` | Point of Sale | 4b | Yes | No | Transaction then affected Lines (`lock`); capacity computed after lock | Transaction, scope (`line`/`transaction`), method, rate/amount, `tax_treatment` (defaults `reduces_taxable_base`), actor, optional discount reason/approver | `PosDiscount` + largest-remainder `PosDiscountAllocation`s; audit event; triggers `Pos::RecalculateTransaction` |
| `Pos::RemoveDiscount` | Point of Sale | 4f | Yes | No | Transaction then Discount (`lock`) | Discount, actor | Deletes provisional Discount + allocations while Transaction is editable; audit event; triggers `Pos::RecalculateTransaction` |
| `Pos::OverrideTaxCategory` | Point of Sale | 4b | Yes | No | Transaction then Line (`lock`) | Line, Tax Category, required reason, actor, optional approver | Overridden line Tax Category; retains first pre-override category/actor/timestamp/reason; audit event; triggers `Pos::RecalculateTransaction` |
| `Pos::ApplyTaxExemption` | Point of Sale | 4b | Yes | No | Transaction (`lock`) | Transaction, exemption type, actor, optional notes/approver | `PosTaxExemption` (`coverage: whole_transaction` only; one per Transaction, re-applying is a no-op success); audit event; triggers `Pos::RecalculateTransaction` |
| `Pos::RecalculateTransaction` | Point of Sale | 4b | Yes | Yes (same inputs reproduce the same persisted rows) | Transaction (`lock`) | Transaction | Deletes and re-persists `pos_line_item_taxes` for non-completed lines from `Tax::CalculateTransaction` against the currently allocated taxable base; returns subtotal/discount/tax/net totals and blockers/warnings for display; does not write cached totals onto `pos_transactions` |

### Phase 4b tax notes

- `Tax::CalculateTransaction` is the pure ADR-0014 hybrid calculation: taxability/base resolved per line, one round-half-up aggregation per transaction component (`store_tax_rate_id` + `calculation_order` + `compounds_on_prior_tax`) and line direction, largest-remainder cent allocation (tie-break: remainder desc, then position asc, then id asc), and ascending-`calculation_order` compounding using already-finalized (allocated) prior tax amounts on the line. It does not persist anything.
- `exempt` and `not_applicable` treatments produce no `Tax::CalculateTransaction` *component* result (no collectible tax to allocate); `zero_rated` produces an explicit zero-amount component so the base still reports. `Pos::RecalculateTransaction` still persists zero-amount `pos_line_item_taxes` rows with the matching `treatment_snapshot` for those non-collecting rules, so receipts/audits can show *why* no tax was collected rather than silently omitting the category.
- Effective Store Tax Rules are resolved by the **store-local calendar date at completion**, not the Business Day `reporting_date` (ADR-0014). Collecting treatments also require the referenced Store Tax Rate to be active and effective on that same date; an invalid rate is a configuration blocker, not silent omission.
- `Pos::RecalculateTransaction` runs after every 4a/4b line- or transaction-mutating service (`AddLine`, `AddOpenRingLine`, `UpdateLineQty`, `RemoveLine`, `OverridePrice`, `ApplyDiscount`, `RemoveDiscount`, `OverrideTaxCategory`, `ApplyTaxExemption`); a missing effective Store Tax Rule surfaces as a blocker in that service's `warnings`, never an implicit exemption.
- Commercial POS mutations use canonical lock order `PosSession` (when creating/attaching) → `PosTransaction` → affected `PosLineItem`s → discount/tax rows → inventory. Eligibility and discount capacity are computed after the transaction lock is held.
- `Pos::AuthorizeAction` centralizes ADR-0011 permission/authority/approval evaluation for all restricted 4b actions: the requester's own numeric authority (`EvaluateAuthority`, membership-override columns per OD-013 interim) is checked first when a `limit_key` is given; an approver must differ from the requester, authenticate with their own PIN (`authenticate_pin`, not the requester's), hold the approving permission, and (for numeric actions) independently have authority covering the requested value.
- Completion-time blocker revalidation under a Transaction lock (`Pos::CompleteTransaction`) is Phase 4c work.

## Phase 4c — Inventory sale bridge, tender, and atomic completion

| Service | Domain owner | Introduced | Transactional? | Idempotent? | Locks | Input | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Inventory::ConvertReservation` | Receiving and Inventory | 4c | Yes | Yes (posting key) | Balance, then Reservation (Reserve/ReleaseReservation order) | POS line, posted-by actor | Posts an outbound `sale` via `PostLedgerEntry`; decrements `reserved`; marks Reservation `converted`; snapshots `cost_unit_cost_cents`/`cost_extended_cents`/`cost_method_snapshot`/`cost_quality_snapshot` on the line; warns on negative resulting `available` |
| `Pos::AddCashTender` | Point of Sale | 4c | Yes | No | Transaction (`lock`) | Transaction, cash Tender Type, amount tendered, actor | `pending` `PosTender` capped at balance due; enforces active/`payment_enabled`/over-tender flags; fails when recalculation has blockers |
| `Pos::AddCardTender` | Point of Sale | 4c | Yes | No | Transaction (`lock`) | Transaction, card Tender Type, amount, authorization code, optional terminal reference, actor | `authorized` `PosTender`; enforces remaining balance unless `requires_reconciliation`; fails when recalculation has blockers |
| `Pos::RemoveTender` | Point of Sale | 4c | Yes | No | Tender (`lock`) | Tender, actor, optional reason | `pending` → `removed`; `authorized` → `voided`; restores `PosTransaction#editable?` |
| `Pos::CreateCashMovement` | Point of Sale | 4c | Yes | No | None (session-scoped, not Transaction-scoped) | Session, Cash Movement Type, amount, actor, optional reason/reference/approver | `PosCashMovement`; escalates through `Pos::AuthorizeAction` (`maximum_paid_out_cents`) when the type `requires_approval` |
| `Pos::RecordClosingCashCount` | Point of Sale | 4c | Yes | No | Session (`lock`) | Cash-enabled Session, counted cents, actor | Append-only `closing` `PosSessionCashCount` |
| `Pos::CalculateExpectedCash` | Point of Sale | 4c | No | Yes | None | Session | Expected drawer cash = opening + cash received (amount tendered) − change given − cash refunded ± cash movements (INV-CASH-001); returns component breakdown for close UI |
| `Pos::CompleteTransaction` | Point of Sale | 4c | Yes | Yes (`completion_idempotency_key`) | Session then Transaction, pending Lines, unresolved Tenders (all `lock`); Balance/Reservation via `Inventory::ConvertReservation`; Store (`lock`, receipt sequence) | Transaction, completing Session, actor, idempotency key | Revalidates tax and sale eligibility under lock (blockers fail completion); converts Reservations / posts sale movements; finalizes Lines and Tenders; assigns `receipt_number`/`receipt_sequence` only on success; marks Transaction `completed`; sets `cashier_user` to completing actor |

### Phase 4c notes

- **Tender-state lock:** `PosTransaction#editable?` is `open? && !unresolved_tenders?` (`pending`/`authorized` Tenders lock lines, prices, discounts, tax category, and exemptions). Every 4a/4b commercial-editing service re-checks `editable?`/line status *after* acquiring its row lock (`Pos::RemoveLine`, `Pos::UpdateLineQty`, `Pos::OverridePrice`, `Pos::OverrideTaxCategory`), and `Pos::AddLine`/`Pos::AddOpenRingLine` lock the Transaction itself before inserting a new Line, so none of them can slip a commercial mutation past a Transaction that `Pos::CompleteTransaction` is concurrently completing.
- `Pos::SuspendTransaction` and `Pos::CancelTransaction` are hardened against Tenders: Suspend is blocked outright while an unresolved Tender exists (domain: "Suspension ... requires no unresolved Tender activity"); Cancel resolves (removes/voids) any unresolved Tenders itself before cancelling, so no completed Tender can survive a cancelled Transaction (ADR-0008).
- `Pos::CloseSession`'s pre-existing "blocks while it controls an open Transaction" guard already enforces "Session close blocked by unresolved Tenders," because an unresolved Tender can only exist on a still-`open` Transaction (Suspend's guard above rules out the alternative).
- `Pos::CompleteTransaction` supports Product-line tracking modes `quantity`, `none`, and `individual` (4d), plus stored-value issue/reload lines and redeem/refund tenders via `StoredValue::PostEntry`. Departments are re-checked (`active?`/`postable?`) for merchandise lines; SV lines skip department/eligibility.
- Cash-enabled Sessions require opening cash at open and a closing cash count before close; card-only Sessions skip the count contract. Session Z numbering and reconciliation remain Phase 7.
- Check Tender Types are seeded inactive; controller dispatch supports `cash`, `card`, and `stored_value` (Phase 6).
- Receipt Number format (v1, not architecturally locked beyond OD-002's sequence ownership): `"#{store.code}-#{receipt_sequence.to_s.rjust(6, '0')}"`.

## Phase 4d — Individually tracked inventory

| Service | Domain owner | Introduced | Transactional? | Idempotent? | Locks | Input | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Inventory::CreateInventoryUnit` | Receiving and Inventory | 4d | Yes | No | `identifier_sequences` row via `Identifiers::Generate`; requires `inventory.unit.manage` | Store, variant, actor, acquisition cost, optional condition/price/acquisition-source-type+id/description/internal-notes | Persisted `InventoryUnit` (`available`, generated `27` identifier) + audit; bootstrap mechanism parallel to Phase 3's opening-inventory-adjustment, since receiving is not implemented until Phase 5 |
| `Inventory::Reserve` (individual branch) | Receiving and Inventory | 4d | Yes | Yes (unit status is the single source of truth) | `InventoryUnit` (`lock!`) | Store, variant, quantity (always 1), source, `inventory_unit` | Active reservation on the exact unit; unit `status: reserved`; fails safely (no oversell) when the unit is not `available` |
| `Inventory::ReleaseReservation` (individual branch) | Receiving and Inventory | 4d | Yes | Yes | `InventoryUnit` (`lock!`) + Reservation | Reservation | Released reservation; unit `status: available` |
| `Inventory::ConvertReservation` (individual branch) | Receiving and Inventory | 4d | Yes | Yes (reservation-status replay) | `InventoryUnit` (`lock`), then Reservation | POS line (with `inventory_unit_id`), posted-by actor | Unit `status: sold` + `sold_at` + `sold_pos_line_item_id`; Reservation `converted`; line cost snapshot set from the unit's exact `acquisition_cost_cents` (`cost_method_snapshot: "explicit"`) |
| `Pos::AddLine` (individual branch) | Point of Sale | 4d | Yes | No | Reservation via `Inventory::Reserve` | Transaction, variant, `inventory_unit`, actor | Pending product line pinned to the exact unit (`quantity: 1`, `inventory_unit_id` set); rejects a missing/already-reserved unit instead of falling back to aggregate stock |

### Phase 4d notes

- `InventoryUnit#status` (`available` / `reserved` / `sold`, plus inert `inspection`/`damaged`/`discarded`/`rtv`/`in_transfer` values with no service setting them yet) is authoritative; `Inventory::Reserve` locks the unit row and rechecks `available?` after acquiring the lock, so two concurrent reservation attempts for the same unit always leave exactly one winner and one safe failure (`test/services/inventory/concurrency_reserve_unit_test.rb`).
- Unlike quantity-tracked lines, an individually tracked line always reserves quantity `1` against one exact unit; `Pos::UpdateLineQty` rejects any quantity change on a unit-backed line rather than trying to re-resolve a different unit.
- `Pos::ResolveScan` resolves a scanned generated `27` identifier directly to its `InventoryUnit` (and from there to its variant), ahead of the ordinary product/variant lookup path.
- `inventory.unit.manage` gates direct unit creation (`InventoryUnitsController`); there is no receiving workflow yet (Phase 5), so this remains the only creation path.
- `acquisition_source_type`/`acquisition_source_id` is a label pair only (`receipt_line`/`return_line`/`buyback`/`adjustment`/`other`), not a real polymorphic association — none of those source records exist yet, and `buyback` in particular names an explicitly deferred capability (see the phase-04 4d "Open follow-up" note).

## Phase 4e — Simple linked returns

| Service | Domain owner | Introduced | Transactional? | Idempotent? | Locks | Input | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Pos::AddLinkedReturnLine` | Point of Sale | 4e | Yes | No | Transaction (`lock`) + original line (`lock`); requires `pos.return.create` | Open Transaction, completed original sale line, quantity, Return Reason, disposition, actor | Pending `direction: return` line copying original commercial/cost snapshots; proportional historical Discount allocations (INV-RET-004); tax components reversed from original snapshots via `Pos::RecalculateTransaction`; never mutates the original sale line |
| `Pos::AddCashRefundTender` | Point of Sale | 4e | Yes | No | Transaction (`lock`) | Transaction with negative net, cash Tender Type, refund amount, actor | `pending` `PosTender` with `direction: refunded` capped at refund due |
| `Inventory::PostCustomerReturn` | Receiving and Inventory | 4e | Yes | Yes (posting key / unit status) | Balance via `PostLedgerEntry` (+ `unavailable` bump when disposition holds stock), or `InventoryUnit` (`lock`) for individual | Completed return product line, posted-by actor | `return_to_stock`: sellable restore; `inspection`/`damaged`/`rtv`: on_hand + unavailable (or unit status); `discard`: inbound return then outbound adjustment; `non_inventory`: no effect for tracking `none` |
| `Pos::RecalculateTransaction` (return branch) | Point of Sale | 4e | Yes | No | Transaction (`lock`) | Transaction with pending sale and/or return lines | Sale lines use `Tax::CalculateTransaction`; return lines reverse stored original tax components exactly (proportional for partial quantity); net may be negative |
| `Pos::CompleteTransaction` (return branch) | Point of Sale | 4e | Yes | Yes | Same as 4c, plus `PostCustomerReturn` for return lines | Same as 4c | Return product lines post via `PostCustomerReturn` instead of `ConvertReservation`; tender settlement treats `refunded` as negative of `received` |

### Phase 4e notes

- Original completed sale lines remain immutable (ADR-0008); returns are new linked lines on a separate open Transaction.
- Remaining returnable quantity is `original.quantity − sum(pending/completed linked returns)`.
- Free-text cancellation/removal/override reasons remain free text; Return Reasons are organization master data (`docs/exports/return_reasons.csv`).

## Phase 5a — Vendors

| Service | Domain owner | Introduced | Transactional? | Idempotent? | Locks | Input | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Purchasing::CreateVendor` / `UpdateVendor` | Vendors and Purchasing | 5a | Yes | No | Vendor | Organization, actor, vendor attrs | Persisted `Vendor` + audit; code unique within organization |
| `Purchasing::CreateProductVariantVendor` / `UpdateProductVariantVendor` | Vendors and Purchasing | 5a | Yes | No | Product Variant Vendor | Variant, vendor, source attrs (vendor item code, cost, MOQ, order multiple, returnable) | Persisted vendor-source link + audit; unique per (variant, vendor) |

## Phase 5b — Purchase orders

| Service | Domain owner | Introduced | Transactional? | Idempotent? | Locks | Input | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Purchasing::CreatePurchaseOrder` | Vendors and Purchasing | 5b | Yes | No | Store (`lock`, number sequence) | Store, vendor, actor, header + lines attrs | Draft `PurchaseOrder` with store-scoped never-reused number and store currency; snapshots description/SKU/identifier/vendor-item/returnable via `LineSnapshot`; audit |
| `Purchasing::UpdateDraftPurchaseOrder` | Vendors and Purchasing | 5b | Yes | No | Purchase Order (`reload.lock!`) | Draft Purchase Order, header attrs, replacement lines | Updated header + fully replaced line set; rejected once no longer draft; audit |
| `Purchasing::PlacePurchaseOrder` | Vendors and Purchasing | 5b | Yes | Yes (replaying an ordered PO is a no-op) | Purchase Order (`reload.lock!`) | Draft Purchase Order, actor, store | `ordered` status; `ordered_at`/`ordered_by_user`/`ordered_on`; soft MOQ/multiple warnings via `ThresholdWarnings`; audit |
| `Purchasing::AmendPurchaseOrder` | Vendors and Purchasing | 5b | Yes | No | Purchase Order (`reload.lock!`), then affected Lines (`lock`) | Ordered Purchase Order, actor, cancel-quantity attrs (+ reason), and/or new-line attrs | Increases supply via new lines and/or reduces expected quantity via `cancelled_quantity` (never decreases, never edits identity fields in place); audit |
| `Purchasing::CancelPurchaseOrder` | Vendors and Purchasing | 5b | Yes | Yes (replaying a cancelled PO is a no-op) | Purchase Order (`reload.lock!`) | Draft or ordered Purchase Order with no received quantity, actor, optional reason | `cancelled` status + `cancelled_at`/`cancelled_by_user`; rejects if any line has received quantity or PO is closed; audit |
| `Purchasing::ClosePurchaseOrder` | Vendors and Purchasing | 5b | Yes | Yes (replaying a closed PO is a no-op) | Purchase Order (`reload.lock!`) | Ordered Purchase Order where every line's `open_quantity` is zero, actor | `closed` status + `closed_at`/`closed_by_user`; no reopen workflow; audit |
| `Purchasing::ApplyBulkDiscountToDraftLines` | Vendors and Purchasing | 5b | Yes | No | Purchase Order (`reload.lock!`) | Draft Purchase Order, selected `discount_from_list` line IDs, discount bps, actor | Updated `discount_bps`/`cost_provenance` on selected lines; expected unit/extended cost recompute deterministically; audit |
| `Purchasing::OnOrder` | Vendors and Purchasing | 5b | No | Yes | None | Store, product variant | Derived on-order quantity: `max(ordered − received − cancelled, 0)` summed across `ordered` Purchase Order Lines only; never cached or posted through the inventory ledger |
| `Purchasing::ThresholdWarnings` | Vendors and Purchasing | 5b | No | Yes | None | Purchase-order lines (with optional vendor source) | Soft warning strings for vendor minimum-order-quantity and order-multiple mismatches; never blocks placement |

### Phase 5b notes

- Purchase-order commercial lifecycle is `draft → ordered → (closed | cancelled)`; receiving progress (`receiving_state`: `not_received`/`partially_received`/`fully_received`) is derived from line quantity and is never a commercial status.
- Line identity (variant, vendor source, quantity, cost fields, snapshots) is immutable once the parent Purchase Order is placed; only `cancelled_quantity` may change afterward, and only via `AmendPurchaseOrder`.
- `expected_unit_cost_cents` is deterministic for `discount_from_list` lines (`list_cost_cents` × (1 − discount_bps)) via `Inventory::Rounding`, and manual for `direct_net_cost` lines; `expected_extended_cost_cents` is always a derived rollup.
- Receipt posting and PO-line receiving allocation are implemented in Phase 5c below; PO-line **allocation** to Customer Requests lands in Phase 5e (`Purchasing::CreateAllocation`/`ReleaseAllocation`), with conversion to Inventory Reservation implemented in Phase 5f.

## Phase 5c — Receipts and OD-014 negative-inventory settlement

| Service | Domain owner | Introduced | Transactional? | Idempotent? | Locks | Input | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Inventory::CreateReceipt` | Receiving and Inventory | 5c | Yes | No | Store (`lock`, number sequence) | Store, vendor, actor, header + lines attrs | Draft `Receipt` with a store-scoped never-reused number; audit |
| `Inventory::UpdateDraftReceipt` | Receiving and Inventory | 5c | Yes | No | Receipt (`reload.lock!`) | Draft Receipt, header attrs, replacement lines | Updated header + fully replaced line set; rejected once no longer draft; audit |
| `Inventory::CancelReceipt` | Receiving and Inventory | 5c | Yes | Yes (replaying a cancelled Receipt is a no-op) | Receipt (`reload.lock!`) | Draft Receipt, actor, optional reason | `cancelled` status + `cancelled_at`/`cancelled_by_user`; draft only — a posted Receipt has no correction workflow yet; audit |
| `Inventory::PostReceipt` | Receiving and Inventory | 5c (extended 5f) | Yes | Yes (replaying a posted Receipt is a no-op; the whole posting is one transaction) | Receipt (`reload.lock!`), then per line: Stock Balance (via `FindOrCreateStockBalance`) or Purchase Order Line (`lock`); then per converted allocation: Product Request (`lock`), `PurchaseOrderAllocation` (`lock`), existing `InventoryReservation` (`lock`, via `Inventory::Reserve`) | Draft Receipt, actor, store | Only accepted quantity enters inventory (never rejected); quantity-tracked lines call `PostLedgerEntry` and split into a `receipt_deficit_settlement` entry then a `receipt` entry when prior On Hand is negative (OD-014); individual lines call `CreateInventoryUnit` per accepted unit (`require_unit_manage_permission: false`); linked lines advance `PurchaseOrderLine#received_quantity`; permission checks: `inventory.receipt.post` always, `inventory.receipt.receive_unlinked` when a line has no PO Line, `inventory.receipt.over_receive` when accepted quantity exceeds the PO Line's open quantity; **Phase 5f:** for a quantity-tracked linked line, after posting the accepted-into-inventory movement, converts that PO Line's remaining `PurchaseOrderAllocation`s to `product_request`-sourced `InventoryReservation`s (via `Inventory::Reserve`, accumulating onto any existing active reservation for the same request/variant) up to the newly sellable-accepted quantity, in deterministic order (priority `urgent`>`high`>`normal`, then `needed_by_on` ascending with nulls last, then `created_at`), recording one `converted_to_reservation` `PurchaseOrderAllocationEvent` per allocation touched (`posting_key` scoped to receipt+line+allocation); individually tracked lines are not converted (out of scope); audit |

### Phase 5c notes

- `Inventory::PostLedgerEntry` and `Inventory::CalculateQuantityCost` gained `receipt` and `receipt_deficit_settlement` movement kinds. `receipt` reuses the existing opening/customer-return inbound cost path (valid because it only ever runs from a zero-or-positive prior On Hand); `receipt_deficit_settlement` never creates inventory value (`inventory_value_delta_cents` is always zero) and never crosses above zero On Hand.
- OD-014 deficit-pool bookkeeping (`stock_balances.open_provisional_deficit_cost_cents`/`deficit_cost_quality`) is maintained generically inside `PostLedgerEntry#apply_balance!` for **any** quantity-tracked movement whose resulting On Hand crosses the deficit boundary (not only receipts): an outbound movement that drives On Hand further negative adds provisional cost to the pool using that movement's own resolved unit cost/quality (whatever `CalculateQuantityCost` already resolved for the sale/adjustment); any movement that reduces the deficit (settlement, linked return, quantity-only correction) releases pool cost proportionally, in full when the deficit reaches zero. Settlement variance (`provisional_cost_released_cents`/`settlement_variance_cents`/`settlement_variance_kind`) is only ever recorded on `receipt_deficit_settlement` entries, per OD-014's "linked returns and quantity-only corrections do not create ordinary receipt cost variance."
- `Inventory::CreateInventoryUnit` gained `require_unit_manage_permission:` (default `true`) so `PostReceipt` can create receipt-sourced units under the receiver's own `inventory.receipt.post` authorization instead of requiring `inventory.unit.manage`.
- Receipt Line `cost_quality` accepts `confirmed_zero` (a known actual cost of zero) in addition to the ledger's `actual`/`estimated`/`unknown`; `PostReceipt` maps `confirmed_zero` to ledger `cost_quality: "actual"` with a zero unit cost, and any other missing/unknown line cost to ledger `cost_quality: "unknown"` with a null unit cost (never zero).
- An individually tracked line's `accepted_unavailable_quantity` creates units with status `inspection` rather than `available`; there is no dedicated "receiving unavailable" Unit status.
- PO-line **allocation** (committing on-order supply to Customer Request allocations) is implemented in Phase 5e below (not by `PostReceipt`); converting an allocation to an Inventory Reservation at receipt time is implemented in Phase 5f (`PostReceipt` itself, extended — see below).

## Phase 5d — Product Requests, buyer review, and the PO seam

| Service | Domain owner | Introduced | Transactional? | Idempotent? | Locks | Input | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Requests::CreateProductRequest` | Product Requests | 5d | Yes | No | None | Store, actor, optional requesting user, attributes (`request_type`, product, optional variant, quantity, priority, needed-by, customer reference, notes, optional `supersedes_product_request_id`) | Persisted open `ProductRequest`; audit; never changes On Hand or On Order |
| `Requests::UpdateProductRequest` | Product Requests | 5d | Yes | No | Product Request (`reload.lock!`) | Open Product Request, actor, mutable attrs (variant, quantity, priority, needed-by, customer reference, notes) | Updated request while still `open`; rejected once no longer open; audit |
| `Requests::AssignProductRequest` | Product Requests | 5d | Yes | No | Product Request (`reload.lock!`) | Open Product Request, buyer user, actor | Updated `assigned_buyer_user`; rejected once no longer open; audit |
| `Requests::ResolveProductRequest` | Product Requests | 5d | Yes | No | Product Request (`reload.lock!`) | Open non-customer Product Request, resolution code (`ordered`/`declined`/`deferred`/`duplicate`/`superseded`/`no_longer_needed`), optional resolved quantity/note, optional follow-up flag | `deferred` leaves status `open`; `declined` sets `declined`; all other codes `closed`; partial `ordered` quantity can create a linked follow-up `ProductRequest` (`supersedes_product_request_id` → original) via `Requests::CreateProductRequest`; refuses Customer Requests (fulfilment is a later phase); audit |
| `Requests::CancelProductRequest` | Product Requests | 5d | Yes | Yes (replaying a cancelled request is a no-op) | Product Request (`reload.lock!`) | Open Product Request, actor, optional cancellation reason | `cancelled` status; distinct from buyer resolution (no resolution code recorded); audit |
| `Catalog::ImportProductMetadata` | Catalog and Products | 5d | Yes (delegates to `Catalog::CreateProduct`) | No | Sequence + product uniqueness (via `Catalog::CreateProduct`) | Organization, actor, store, structured attributes hash, optional `accept_duplicate_review`/`accept_identifier_warning` | Thin product-from-demand path: local-catalog identifier/SKU lookup plus a name search surface likely duplicates as review candidates before creating; `accept_duplicate_review: true` creates anyway; not a live external-catalog integration |
| `Purchasing::ReplenishmentSnapshot` | Vendors and Purchasing | 5d | No | Yes | None | Store, product variant | Buyer-review read model: On Hand/Reserved/Unavailable/Available (from `StockBalance`), derived On Order (`Purchasing::OnOrder`), current selling price, and expected (preferred active vendor source) or last-known unit cost; never persisted |
| `Purchasing::AddDemandToDraftPurchaseOrder` | Vendors and Purchasing | 5d | Yes | No | Store (`lock`, number sequence when creating), Purchase Order (`lock`) | Store, vendor, quantity, actor, optional Product Request/variant/vendor source/explicit draft Purchase Order/cost fields | Resolves the exact Product Variant and a vendor source, then adds an ordered-quantity line to an existing or newly created draft Purchase Order for that vendor; for non-Customer Requests optionally resolves the Product Request as `ordered` via `Requests::ResolveProductRequest`; Customer Requests are never auto-resolved; never creates a Purchase-Order Allocation (deferred to Phase 5e/5f) |

### Phase 5d notes

- `product_requests` unifies `customer_request`, `staff_suggestion`, `stock_replenishment`, and `frontlist_selection` demand. Customer Requests remain open fulfilment obligations (allocation/reservation/fulfilment are later-phase work); the other three types are buyer-decision records resolved by `Requests::ResolveProductRequest`.
- Non-customer resolution fields (`resolution`, `resolved_quantity`, `resolved_at`, `resolved_by_user_id`, `resolution_note`) live directly on `product_requests` (no separate resolution-event table), per the Phase 5 planning defaults.
- The Buyer-review queue (`BuyerReviewController`) is a read-only projection over open `ProductRequest` rows plus `Purchasing::ReplenishmentSnapshot` — never a table, PO-line flag, or inventory quantity.
- `Purchasing::AddDemandToDraftPurchaseOrder` reuses an existing draft Purchase Order for the same Store × Vendor when one exists and none is explicitly specified, otherwise creates one (mirroring `Purchasing::CreatePurchaseOrder`'s numbering); it never targets an already-`ordered` Purchase Order.
- Purchase-Order Allocation (committing expected supply to a Customer Request) lands in Phase 5e below and is not performed by any Phase 5d service.

## Phase 5e — Purchase-order allocations to Customer Requests

| Service | Domain owner | Introduced | Transactional? | Idempotent? | Locks | Input | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Purchasing::CreateAllocation` | Vendors and Purchasing | 5e | Yes | No | Purchase Order Line (`lock!`), then Product Request (`lock!`) | Purchase Order Line, Customer-Request `ProductRequest`, quantity, actor, store | Persisted `PurchaseOrderAllocation` committing expected (not physical) supply; capped by both the line's open-minus-already-allocated quantity and the request's `uncovered_quantity` (`requested − fulfilled − active_reserved − remaining_allocated`, per Phase 5f); refuses non-Customer-Request types; audit |
| `Purchasing::ReleaseAllocation` | Vendors and Purchasing | 5e | Yes | Yes (`posting_key`) | `PurchaseOrderAllocation` (`lock!`) | Allocation, quantity, structured reason code, actor, optional note/`posting_key`/`occurred_at` | Appends a `released` `PurchaseOrderAllocationEvent`; capped at `remaining_quantity`; replaying the same `posting_key` returns the original event without double-releasing; audit |

### Phase 5e notes

- `purchase_order_allocations` (immutable `purchase_order_line_id`/`product_request_id`/`quantity`/`created_by_user_id`, unique per line+request pair) records only the *original* committed quantity; it carries no `status`/`received`/`fulfilled` column. `remaining_quantity` (`quantity − converted_quantity − released_quantity`) and presentation-only `state` (`active`/`partially_resolved`/`converted`/`released`/`resolved_mixed`, derived from the `converted_to_reservation`/`released` event mix) are always derived from the append-only `purchase_order_allocation_events` ledger, never stored. `converted`/`partially_resolved` states are populated starting Phase 5f (`Inventory::PostReceipt` conversion).
- `purchase_order_allocation_events` supports `event_type: released` (from `ReleaseAllocation`) and `converted_to_reservation` (requiring both `receipt_line_id` and `inventory_reservation_id`, written by `Inventory::PostReceipt` — Phase 5f). Events are append-only (`readonly?` after creation) and a nullable-but-unique `posting_key` gives both `ReleaseAllocation` and the Phase 5f conversion path replay idempotency.
- `released` events require one structured `reason` code: `purchase_order_cancelled`, `line_quantity_cancelled`, `vendor_unavailable`, `received_unavailable`, `request_cancelled`, `request_quantity_reduced`, `fulfilled_from_earlier_supply`, `reallocated_to_other_supply`, `manual_release`. Free-text detail is optional (`note`), never a substitute for the code.
- Allocating never changes `on_hand`, `on_order`, or creates an `InventoryReservation` — it only commits a share of a Purchase Order Line's still-open expected quantity to a specific Customer Request, per ADR-0015.
- `Purchasing::AmendPurchaseOrder` now accepts `release_allocations_attributes` and releases those allocations (inside the same transaction, before applying cancellations) so a caller can atomically shrink `cancelled_quantity` and free the allocated quantity it depends on; without a matching release, reducing a line's open quantity below its `remaining_allocated` is rejected.
- `Purchasing::CancelPurchaseOrder` automatically releases every remaining allocated quantity on the Purchase Order's lines (reason `purchase_order_cancelled`) inside its own transaction before cancelling — cancellation is never blocked by outstanding allocations, and the release is always auditable.
- Minimal UI: allocate/release forms and a status table on both the Purchase Order show page (per-line, listing allocations to Customer Requests) and the Product Request show page (per-request, listing allocations from Purchase Order Lines), gated by `purchasing.allocation.create`/`purchasing.allocation.release`.

## Phase 5f — Reservation conversion and Product Request fulfilment

| Service | Domain owner | Introduced | Transactional? | Idempotent? | Locks | Input | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Requests::ReserveInHouseInventory` | Product Requests | 5f | Yes | No | Product Request (`lock`), existing active `InventoryReservation` (`lock`, via `Inventory::Reserve`) | Customer-Request `ProductRequest`, quantity, actor, store, `physically_confirmed:` (must be explicitly `true`) | Active `product_request`-sourced `InventoryReservation` (accumulated onto any existing one for the same request/variant) reflecting physically-present, already-counted stock; capped by `uncovered_quantity`; quantity-tracked variants only (individually tracked in-house holds are out of scope); requires `requests.customer_request.reserve`; audit |
| `Requests::RecordFulfillment` | Product Requests | 5f | Yes | Yes (`posting_key: pos_line_item:<id>:fulfillment`) | Product Request (`lock`), any active `product_request` `InventoryReservation` for it (`lock`, via `Inventory::Reserve`/`ReleaseReservation`) | Sale `PosLineItem` linked to a Customer Request (`pos_line_item.product_request`), quantity, actor, `fulfilled_at` | Appends a `kind: fulfill` `ProductRequestFulfillment`; releases the linked reservation in full or reduces it by the fulfilled quantity; closes the Product Request (`status: fulfilled`) once `fulfilled_quantity >= requested_quantity`; requires `requests.customer_request.fulfill`; replaying the same `posting_key` returns the original fact unchanged; audit. Always called from inside `Pos::CompleteTransaction`, never standalone from a controller |
| `Requests::ReverseFulfillment` | Product Requests | 5f | Yes | Yes (`posting_key: pos_line_item:<return line id>:fulfillment_reverse`) | Original `ProductRequestFulfillment` (`lock`), Product Request (`lock`, only if reopening) | Linked-return `PosLineItem` (`original_pos_line_item` pointing at a fulfilled sale line), actor, `reversed_at` | Appends a `kind: reverse` `ProductRequestFulfillment` (`linked_fulfilment_id` → the original fact; never edits it) for `min(return quantity, original quantity − already reversed)`; reopens the Product Request (`status: open`) if fulfilled quantity drops back below requested quantity; a no-op result (still `success?`) when the original sale line was never linked to a Customer Request or is already fully reversed; audit. Always called from inside `Pos::CompleteTransaction`, never standalone |

### Phase 5f notes

- **Receipt → reservation conversion.** `Inventory::PostReceipt` (Phase 5c, extended) now converts a quantity-tracked PO Line's remaining `PurchaseOrderAllocation`s into `product_request`-sourced `InventoryReservation`s in the same transaction as posting the accepted quantity into inventory, up to that line's newly sellable-accepted quantity. When accepted quantity cannot satisfy every open allocation, conversion order is deterministic: request `priority` (`urgent` > `high` > `normal`), then `needed_by_on` ascending with nulls last, then `created_at`. Each allocation touched gets exactly one `converted_to_reservation` `PurchaseOrderAllocationEvent` (`posting_key: receipt:<id>:line:<id>:allocation:<id>:convert`) referencing the Receipt Line and the resulting Reservation. Individually tracked variants are never converted (Phase 5f in-house/allocation conversion is quantity-tracked only). The existing `Purchasing::ReleaseAllocation` path (cancel, unavailable, earlier supply, etc.) is unchanged and still the only way to resolve an allocation without a physical reservation.
- **In-house reservation.** `Requests::ReserveInHouseInventory` is the *only* way to create a `product_request`-sourced `InventoryReservation` from counted-but-not-yet-received stock; it deliberately requires an explicit `physically_confirmed: true` argument (there is no default) so a caller cannot reserve inventory that has not actually been counted/located. It shares the same accumulate-onto-existing-reservation pattern as the receipt-conversion path (lock the Product Request, then the existing active reservation, then call `Inventory::Reserve` with the new total).
- **`product_request_fulfillments`.** Append-only fact table: `product_request_id`, nullable `inventory_reservation_id` (a walk-in sale with no prior reservation still fulfils), `pos_line_item_id`, positive `quantity`, `kind` (`fulfill`/`reverse`), `linked_fulfilment_id` (required on `reverse`, forbidden on `fulfill`; points at the original fact — a reversal is never itself reversed), `fulfilled_at`, `fulfilled_by_user_id`, and a unique `posting_key`. `ProductRequestFulfillment` forbids `update`/`destroy` (`readonly?`/`before_destroy`) — corrections are always new rows.
- **POS wiring.** `Pos::AddLine` accepts an optional `product_request:` (validated: must be a Customer Request, open, same store, matching variant if one is already resolved, and quantity ≤ the request's `outstanding_quantity`); `pos_line_items.product_request_id` is DB-constrained to product/sale lines only. Inside `Pos::CompleteTransaction`'s existing per-line loop (same top-level transaction as tax/eligibility/tender revalidation, reservation conversion, and receipt numbering — OD-014/ADR "POS completion is atomic"), a sale line linked to a Product Request calls `Requests::RecordFulfillment` right after its `Inventory::ConvertReservation`; a linked return calls `Requests::ReverseFulfillment` right after its `Inventory::PostCustomerReturn`. Any failure (including a denied `requests.customer_request.fulfill`) raises and rolls back the entire completion — no partial fulfilment fact, reservation change, or sale/return posting survives a failed completion.
- **Post-void (Phase 6).** `Pos::EvaluatePostVoidEligibility` (unlocked preflight) and `Pos::PostVoidTransaction` (locked construction) create a new completed reversing transaction. Inventory uses `Inventory::ReverseLedgerEntry`. Fulfilment uses `Requests::ReverseFulfillment`. Stored-value lines/tenders reverse via `StoredValue::PostEntry` (`reversal`); later redemption blocks reversing earlier positive credits. OD-014 interim blocks later deficit reductions. Return-containing originals remain blocked until fulfilment restoration. See [phase-06-post-void-eligibility-and-cross-domain-reversal.md](decisions/phase-06-post-void-eligibility-and-cross-domain-reversal.md).
- **Stored value (Phase 6b–6d).** `StoredValue::CreateAccount` (`21` ids); `StoredValue::PostEntry` (sole balance owner; concurrency-safe); `StoredValue::AdjustBalance` (`approval_mode: :always`); `Pos::AddStoredValueLine` (issue/reload); `Pos::AddStoredValueTender` / `Pos::AddStoredValueRefundTender` (redeem / store-credit refund).
- **Coverage formula.** `ProductRequest#uncovered_quantity` is now `requested_quantity − fulfilled_quantity − active_reserved_quantity − remaining_allocated_quantity` (each clamped at 0 overall; `fulfilled_quantity` nets `fulfill` minus `reverse` rows). Ordering demand (`Requests::CreateProductRequest`), posting a receipt, or creating an in-house reservation never by themselves close a Customer Request — only `Requests::RecordFulfillment` sets `status: fulfilled`, and only when `fulfilled_quantity >= requested_quantity`.
- **Double-reservation window.** A sale line linked to a Customer Request creates its *own* `pos_line_item`-sourced reservation via `Pos::AddLine` (as always) in addition to any pre-existing `product_request`-sourced reservation from conversion/in-house-reserve; the two are temporarily both active (may transiently warn on negative `available`) until `Pos::CompleteTransaction` converts the POS line's reservation into the sale and `RecordFulfillment` consumes the Product Request's reservation in the same transaction — inventory is never double-counted once completion finishes.

## Phase 5g — Operational views and hardening

No new application services. `ReportsController` (Purchasing and Vendors / Receiving and
Inventory / Product Requests) adds read-only operational views at `/reports` — a
projection controller in the same sense as the Phase 5d Buyer-review queue, never a
table, cache, or new workflow:

| View | Data source | Permission |
| --- | --- | --- |
| Open purchase orders | `PurchaseOrder` (`draft`/`ordered`) + derived `receiving_state` | `purchasing.purchase_order.view` |
| On order | `Purchasing::OnOrder` per store×variant | `purchasing.purchase_order.view` |
| Receiving history | `Receipt` + partially received `PurchaseOrder`s (`receiving_state`) | `inventory.receipt.view` |
| Customer request coverage | `ProductRequest` derived reserved/allocated/fulfilled/uncovered quantities | `requests.product_request.view` |
| Allocation events | `PurchaseOrderAllocationEvent` (append-only history) | `purchasing.purchase_order.view` |

The dashboard (`/reports`) links to these plus the existing Buyer-review queue
(`BuyerReviewController`, Phase 5d). None of these views write to any record; they only
read already-posted facts (AGENTS.md §4, "Reporting consumes posted source records").

### Phase 5g notes

- System-test coverage for the phase's three critical end-to-end paths (vendor → PO →
  place → receive → verify stock; Customer Request → allocation → receipt-converted
  reservation → POS fulfilment; non-customer resolve → PO without allocation) surfaced
  and fixed two pre-existing defects, unrelated to the new views: `PurchaseOrder` and
  `Receipt` were missing `accepts_nested_attributes_for` on their line associations (so
  `form.fields_for` never emitted the `_attributes`-suffixed param key the create/update
  controllers expected — the browser create forms were silently non-functional for
  adding lines), and the Purchase Order show page's "Add new line" `select_tag` call
  passed an invalid extra positional argument (`ActionView::Template::Error` on any
  `ordered` PO with amend permission).

## Later phases (add when implemented)

Placeholder only — do not invent APIs now:

- Phase 7+: reporting/reconciliation interfaces over posted corrections and stored value

## Related

- [roadmap.md](roadmap.md)
- [testing.md](testing.md)
- [../reference/identifiers.md](../reference/identifiers.md)
- [../domains/authorization-permissions.md](../domains/authorization-permissions.md)
