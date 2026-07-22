# ShelfStack Workflow Documentation

**Purpose:** Record-level (and user-visible) sequences that coordinate multiple records or domains  
**Authority:** Below ADRs and Domain Specifications; update when sequences change ([AGENTS.md](../../AGENTS.md) §10)

## Preferred structure for each workflow

1. Preconditions  
2. Records read  
3. Records created or changed  
4. Transaction boundary  
5. Locks  
6. Status transitions  
7. Ledger or snapshot effects  
8. Permissions and approvals  
9. Failure behavior  
10. Idempotency behavior  
11. Governing ADR references  
12. Unresolved details  

Keep workflows record-level. Screen layout belongs elsewhere.

## Index

| Workflow | Status | Phase focus |
| --- | --- | --- |
| [opening-stock.md](opening-stock.md) | Active draft | Phase 3 |
| [product-setup.md](product-setup.md) | Existing | Phase 2 |
| [quantity-tracked-sale.md](quantity-tracked-sale.md) | Delivered | Phase 4c |
| [pos-completion.md](pos-completion.md) | Delivered | Phase 4c+ |
| [individually-tracked-sale.md](individually-tracked-sale.md) | Delivered | Phase 4d |
| [suspended-transaction.md](suspended-transaction.md) | Delivered | Phase 4a |
| [cancel-transaction.md](cancel-transaction.md) | Delivered | Phase 4a |
| [customer-return.md](customer-return.md) | Delivered | Phase 4e |
| [purchase-order.md](purchase-order.md) | Minimal stub, points to service catalog | Phase 5a/5b/5c/5e |
| [product-request.md](product-request.md) | Minimal stub, points to service catalog | Phase 5d/5e/5f |
| [post-void.md](post-void.md) | Delivered (Policy A card path) | Phase 6 |
| [business-day-close.md](business-day-close.md) | Stub (not yet written) | Phase 4 / 7 |
| [stored-value.md](stored-value.md) | Stub (not yet written) | Phase 6 |

## Phase 4 notes

- Completion ordered steps and failure/idempotency behavior live in [pos-completion.md](pos-completion.md).
- Opening stock → sale path: [opening-stock.md](opening-stock.md) → [quantity-tracked-sale.md](quantity-tracked-sale.md) → [pos-completion.md](pos-completion.md).
- Linked returns: [customer-return.md](customer-return.md).

## Phase 5 notes

- Purchasing and receiving: [purchase-order.md](purchase-order.md); receiving itself
  (`Inventory::PostReceipt`) has no dedicated workflow doc yet — see the Phase 5c/5f
  service-catalog entries.
- Demand and fulfilment: [product-request.md](product-request.md).
