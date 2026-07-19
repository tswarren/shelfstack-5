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
| [customer-return.md](customer-return.md) | Delivered | Phase 4e |
| [post-void.md](post-void.md) | Stub | Phase 6 |
| [purchasing-and-receiving.md](purchasing-and-receiving.md) | Stub | Phase 5 |
| [customer-request-fulfillment.md](customer-request-fulfillment.md) | Stub | Phase 5 |
| [business-day-close.md](business-day-close.md) | Stub | Phase 4 / 7 |
| [stored-value.md](stored-value.md) | Stub | Phase 6 |

## Phase 4 notes

- Completion ordered steps and failure/idempotency behavior live in [pos-completion.md](pos-completion.md).
- Opening stock → sale path: [opening-stock.md](opening-stock.md) → [quantity-tracked-sale.md](quantity-tracked-sale.md) → [pos-completion.md](pos-completion.md).
- Linked returns: [customer-return.md](customer-return.md).
