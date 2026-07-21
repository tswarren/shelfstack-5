# Current Phase

**Active delivery phase:** Phase 5 — Supply and Demand  
**Status:** Ready to begin (governing baseline + planning defaults locked)  
**Phase 4g merge:** `c51dcca823e4476b7f0f62441301d451e83307b2` (PR #31)  
**Phase 4f merge:** `34f371f5590c6942f5291c5bd750a1d98756d13f` (PR #30)  
**Design docs:** [../design/README.md](../design/README.md)  
**Plan document:** [phases/phase-05-supply-and-demand.md](phases/phase-05-supply-and-demand.md)

## Immediate next work

1. Write and execute the Phase 5 implementation plan from [phases/phase-05-supply-and-demand.md](phases/phase-05-supply-and-demand.md) (build order + planning defaults).
2. Scaffold migrations from the reconciled proforma and [ShelfStack_Schema_Reconciliation_2026-07-20.xlsx](../exports/schema/ShelfStack_Schema_Reconciliation_2026-07-20.xlsx); seed Phase 5 permissions from [authorization-permissions.md](../domains/authorization-permissions.md).
3. Continue residual 4g-5 backlog in parallel as needed.
4. Keep [architectural-locks.md](architectural-locks.md) binding; track remaining open items in [open-decisions.md](open-decisions.md).

## Completed recently

- Phase 4a–4e (Point of Sale) and Phase 4f UX Baseline Gate merged to `main` (PR #30).
- Phase 4g test hardening merged to `main` (PR #31) — Phase 5 integrity/security/browser gate satisfied.
- Phase 5 governing decisions: ADR-0015, OD-007, OD-014 settlement; domains, schema exports, and permission catalog reconciled.
- Phase 5 planning defaults locked (resolution columns, follow-up requests, allocation events, thin product path).
- Phase 5a vendors/vendor sources and Phase 5b purchase orders merged into the Phase 5 integration branch.
- Phase 5c (`phase/5c-receipts`, on the Phase 5 integration branch): Receipt/Receipt Line draft-post-cancel lifecycle, `Inventory::PostReceipt` (quantity and individual tracking, PO-line `received_quantity` update), and OD-014 negative-inventory settlement implemented generically in `Inventory::PostLedgerEntry` (deficit-pool creation/release + settlement variance apply to any quantity-tracked movement, not only receipts). PO-line allocation conversion is implemented in Phase 5f.
- Phase 5d (`phase/5d-product-requests`): `product_requests` (four types, required Product, optional Variant, non-customer resolution columns, optional `supersedes_product_request_id`); `Requests::{Create,Update,Assign,Resolve,Cancel}ProductRequest`; Buyer-review queue projection (`Purchasing::ReplenishmentSnapshot`); thin product-from-demand path (`Catalog::ImportProductMetadata`); and the buyer → draft Purchase Order seam (`Purchasing::AddDemandToDraftPurchaseOrder`) that never creates a Purchase-Order Allocation. Customer Request allocation/reservation/fulfilment remain Phase 5e/5f.
- Phase 5e (`phase/5e-allocations`): `purchase_order_allocations`/`purchase_order_allocation_events` (append-only, `remaining_quantity`/`state` always derived from events, no stored fulfilment status); `Purchasing::CreateAllocation` (Customer Requests only, capped by both the PO Line's open quantity and the request's uncovered quantity) and `Purchasing::ReleaseAllocation` (structured reason codes, `posting_key` idempotency); `AmendPurchaseOrder`/`CancelPurchaseOrder` updated to atomically release or reject rather than silently letting cancelled/reduced supply fall below what is already allocated; minimal allocate/release UI on the Purchase Order and Product Request show pages. Conversion to Inventory Reservation and fulfilment implemented in Phase 5f.
- Phase 5f (`phase/5f-fulfilment`): `Inventory::PostReceipt` now converts remaining `purchase_order_allocations` to `product_request`-sourced `InventoryReservation`s in the same posting transaction as the accepted quantity, in deterministic order (priority urgent>high>normal, then `needed_by_on` earlier-first with nulls last, then `created_at`), recording an append-only `converted_to_reservation` event per allocation touched; `Requests::ReserveInHouseInventory` reserves physically-confirmed on-hand quantity-tracked stock against a Customer Request (`requests.customer_request.reserve`, explicit `physically_confirmed: true` required); `product_request_fulfillments` (append-only, `kind: fulfill|reverse`, unique `posting_key`) records the demand-closing fact; `Pos::AddLine` accepts an optional `product_request:` linkage (capped by the request's outstanding quantity) and `Pos::CompleteTransaction` posts the fulfilment fact (`Requests::RecordFulfillment`, consuming/releasing the linked reservation and closing the request once fulfilled quantity meets requested quantity) or a reversing fulfilment on a linked return (`Requests::ReverseFulfillment`, reopening the request if it drops below fully fulfilled) atomically with the sale/return posting. `ProductRequest#uncovered_quantity` is now `requested - fulfilled - active_reserved - remaining_allocated`. Post-void reversal of a fulfilled sale line is Phase 6 (post-void itself is not yet implemented) and is intentionally not wired.

## Do not start yet

- Inventing deficit settlement beyond the accepted OD-014 Phase 5 decision.
- Seeding `inventory.receipt.correct` before a posted-receipt correction workflow is accepted.
- Closing [OD-009](open-decisions.md), [OD-010](open-decisions.md), or [OD-013](open-decisions.md) without an accepted decision.
- Deferred capabilities in [deferred-capabilities.md](deferred-capabilities.md).
- PWA / offline POS as adopted architecture.
- External Inter font dependency (see deferred UX in the 4f phase plan).

## Pointers

- Master sequence: [roadmap.md](roadmap.md)
- Design: [../design/README.md](../design/README.md)
- Git workflow: [git-workflow.md](git-workflow.md)
- Index: [README.md](README.md)
- Testing: [testing.md](testing.md), [testing/test-review-2026-07-19.md](testing/test-review-2026-07-19.md)
- Services: [service-catalog.md](service-catalog.md)
