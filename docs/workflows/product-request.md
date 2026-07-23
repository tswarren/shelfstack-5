# Workflow: Product Request — Demand, Buyer Review, Allocation, Fulfilment

**Status:** Delivered in Phase 5d/5e/5f; hardened in Phase 5g
**Type:** Record-level workflow
**Governing:** [ADR-0015](../adr/0015-product-backed-demand-and-customer-supply-commitments.md), [OD-007](../implementation/decisions/od-007-allocation-receipt-and-fulfilment.md), [product-requests](../domains/product-requests.md), [ordering-and-acquisition-planning](../domains/ordering-and-acquisition-planning.md), [service-catalog](../implementation/service-catalog.md)

## Purpose

A Product Request records demand: a customer request, staff suggestion, stock replenishment need, or frontlist selection. It does not create on-hand inventory or on-order supply by itself. Customer supply commitments are represented separately as Purchase-Order Allocations for expected supply or Inventory Reservations for physically present supply.

## Preconditions

- The actor has store-context request permission for the action.
- The request belongs to the Store and references a Product; a Variant is required once exact supply is committed or sold.
- Create/update quantity is positive and status-compatible.
- Update, assignment, resolution, cancellation, allocation, and in-house reservation require an open request unless stated otherwise.
- Non-customer requests may be buyer-resolved; Customer Requests are fulfilled through reservation/POS workflows and are refused by `Requests::ResolveProductRequest`.
- In-house reservation requires `physically_confirmed: true`; expected/on-order supply cannot be reserved.

## Records read

- Store, actor Membership/Permission records, requesting User when present.
- Product and Product Variant.
- Product Request and related superseded/superseding request when applicable.
- Stock Balance, active Inventory Reservations, Purchase-Order Allocations and Allocation Events when deriving uncovered quantity.
- Purchase Order Line and Vendor Source when demand is added to a draft Purchase Order.
- POS Line Item and Product Request Fulfilment rows during completion and reversal.

## Records created or changed

- `Requests::CreateProductRequest` creates an open Product Request.
- `Requests::UpdateProductRequest` changes mutable fields on an open request.
- `Requests::AssignProductRequest` records the assigned buyer user.
- `Requests::ResolveProductRequest` records non-customer buyer decisions and may create a follow-up request for partially ordered quantity.
- `Requests::CancelProductRequest` changes status to `cancelled` and releases remaining allocations/reservations as implemented by the request service boundary.
- `Purchasing::AddDemandToDraftPurchaseOrder` may add non-customer demand to a draft Purchase Order and resolve that request as ordered; it never creates a Purchase-Order Allocation.
- `Purchasing::CreateAllocation` creates a Purchase-Order Allocation for a Customer Request.
- `Purchasing::ReleaseAllocation` appends release events.
- `Requests::ReserveInHouseInventory` creates or increases a `product_request`-sourced Inventory Reservation for physically confirmed stock.
- `Requests::RecordFulfillment` appends a fulfilment fact from POS completion and may set the request to `fulfilled`.
- `Requests::ReverseFulfillment` appends a reversal fact from linked returns/post-voids and may reopen the request.

## Transaction boundary

Each direct request service runs in its own database transaction. Cross-domain effects occur inside the coordinating service transaction: adding demand to a draft PO wraps PO-line creation and optional non-customer resolution together; POS completion wraps sale/return posting, reservation conversion/release, request fulfilment/reversal, tender/tax effects, and receipt numbering together.

## Locks

- Update, assignment, resolution, cancellation, in-house reservation, fulfilment, and reversal lock the Product Request.
- Allocation creation locks Purchase Order Line then Product Request.
- Allocation release locks the Purchase-Order Allocation.
- In-house reservation and fulfilment lock existing active Inventory Reservations through inventory reservation services.
- POS fulfilment follows the POS completion lock order before entering request fulfilment.

## Status transitions

### Non-customer requests

```text
open → open      (deferred resolution)
open → declined
open → closed    (ordered, duplicate, superseded, no_longer_needed)
open → cancelled
```

### Customer requests

```text
open → fulfilled     (only when net fulfilled quantity >= requested quantity)
fulfilled → open     (linked return/reversal drops net fulfilled below requested quantity)
open → cancelled
```

Allocation, receipt conversion, and in-house reservation do not close a Customer Request.

## Ledger or snapshot effects

- Product Requests are demand records, not inventory or liability ledger records.
- Purchase-Order Allocation Events are append-only and derive remaining allocated quantity.
- Product Request Fulfilments are append-only; corrections create `reverse` rows linked to original `fulfill` rows.
- Customer request coverage is derived as `requested_quantity - fulfilled_quantity - active_reserved_quantity - remaining_allocated_quantity`, clamped at zero for uncovered quantity.

## Permissions and approvals

Implemented permissions include `requests.product_request.*`, `requests.customer_request.*`, and `purchasing.allocation.*`, all evaluated in Store context. Customer-request fulfilment permission is checked during POS completion. Detailed approval policy for special demand or purchasing thresholds remains open.

## Failure behavior

- Permission, validation, stale-status, or insufficient-uncovered-quantity failures roll back the service transaction.
- Customer Requests cannot be resolved through the non-customer resolution service.
- Non-customer requests cannot receive Purchase-Order Allocations.
- In-house reservation fails unless the caller explicitly confirms the stock is physically present.
- If request fulfilment fails during POS completion, the entire POS completion rolls back; no partial inventory, tender, receipt number, or fulfilment fact survives.

## Idempotency behavior

- `Requests::CancelProductRequest` is idempotent when replayed against an already cancelled request.
- `Purchasing::ReleaseAllocation` is idempotent by posting key.
- `Requests::RecordFulfillment` and `Requests::ReverseFulfillment` are idempotent by posting key derived from POS line identity.
- Create, update, assignment, resolution, allocation creation, in-house reservation, and add-demand-to-draft-PO are not idempotent without caller-level retry guards.

## Governing ADR references

- [ADR-0015](../adr/0015-product-backed-demand-and-customer-supply-commitments.md) — Product-backed demand and separate customer supply commitments.
- [ADR-0007](../adr/0007-purchasing-receiving-and-inventory-events.md) — receipt posting creates inventory, not demand or purchase-order intent.
- [OD-007](../implementation/decisions/od-007-allocation-receipt-and-fulfilment.md) — implemented allocation, receipt conversion, and fulfilment seam.

## Unresolved details

- Detailed customer identity/notification workflows remain deferred.
- Exact policy for partial customer fulfilment communication and abandonment remains open.
- Individually tracked in-house customer holds and receipt-to-reservation conversion are out of current scope.
- Buyer scoring, vendor availability automation, and demand prioritization beyond current deterministic conversion ordering remain deferred.
