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
| `Inventory::PostLedgerEntry` | Receiving and Inventory | 3 | Yes | Yes (posting key) | `stock_balances` row | Quantity/value delta, source, cost inputs | Ledger insert + On Hand / valuation-state update |
| `Inventory::CalculateQuantityCost` | Receiving and Inventory | 3 | No | Yes | None | Balance state, inbound/outbound cost inputs | Allocated value, average, quality, estimate result |
| `Inventory::PostAdjustment` | Receiving and Inventory | 3 | Yes | Yes (idempotency key recommended) | `stock_balances` row | Posted adjustment | Ledger entries + balance updates via posting service |
| `Inventory::Reserve` | Receiving and Inventory | 3 | Yes | Yes | Balance and/or reservation rows | Store, variant, qty, source | Active reservation; may warn on negative available |
| `Inventory::ReleaseReservation` | Receiving and Inventory | 3 | Yes | Yes | Reservation (+ balance) | Reservation | Released reservation; reserved qty restored |

### Phase 3 service notes

- `Inventory::PostLedgerEntry` is the exclusive owner of Stock Balance On Hand and valuation-state changes for quantity-tracked variants. Atomic with ledger insert; idempotent via posting key. Used by adjustment posting and later sale/receipt posting.
- `Inventory::CalculateQuantityCost` is a pure calculation helper for positive MWA inbound/outbound allocation, first-positive-from-zero initialization, cost-quality aggregation, Department-margin estimate formula, and residual-cent assignment for fully depleted positive balances. Must not persist balances by itself.
- `Inventory::PostAdjustment` coordinates draft → posted adjustment kinds (`opening_inventory`, `quantity_only`, `cost_correction`) through the posting service with permission checks.

### Phase 3 concurrency test matrix

- concurrent quantity-only posts on same Store × Variant
- concurrent opening vs quantity-only
- concurrent cost correction vs quantity-only (positive balance)
- failed post rolls back ledger and balance together
- idempotent retry does not duplicate value deltas

## Later phases (add when implemented)

Placeholder only — do not invent APIs now:

- Phase 4a–4c: session/day services, `Pos::CompleteTransaction`, discount/tax helpers  
- Phase 5: receipt posting, PO placement, allocation services  
- Phase 6: stored-value posting, post-void  

## Related

- [roadmap.md](roadmap.md)
- [testing.md](testing.md)
- [../reference/identifiers.md](../reference/identifiers.md)
- [../domains/authorization-permissions.md](../domains/authorization-permissions.md)
