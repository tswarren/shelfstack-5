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
| `Authorization::EvaluateAuthority` | Organization and Authorization | 1 | No | Yes | None | User, store, limit key, requested value | `AuthorityResult` (`:allow` / `:requires_approval` / `:deny`); Phase 1 treats non-allow as do-not-proceed; membership overrides only (OD-013) |

## Phase 2 — Catalog

| Service | Domain owner | Introduced | Transactional? | Idempotent? | Locks | Input | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Identifiers::Normalize` | Catalog and Products | 2 | No | Yes | None | Raw identifier string | Normalized typed identifier + warnings |
| `Identifiers::Generate` | Catalog and Products | 2 | Yes | No* | Sequence / uniqueness | Namespace (`28`/`29`/…) | Generated EAN-13 |
| `Catalog::SaleEligibility` | Catalog and Products | 2 | No | Yes | None | Variant, store, context | blockers / warnings |

\*Generation is not replay-idempotent; callers must not retry blindly without checking uniqueness errors.

## Phase 3 — Quantity inventory

| Service | Domain owner | Introduced | Transactional? | Idempotent? | Locks | Input | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Inventory::PostAdjustment` | Receiving and Inventory | 3 | Yes | Yes (idempotency key recommended) | `stock_balances` row | Posted adjustment | Ledger entries + balance updates |
| `Inventory::Reserve` | Receiving and Inventory | 3 | Yes | Yes | Balance and/or reservation rows | Store, variant, qty, source | Active reservation; may warn on negative available |
| `Inventory::ReleaseReservation` | Receiving and Inventory | 3 | Yes | Yes | Reservation (+ balance) | Reservation | Released reservation; reserved qty restored |

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
