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
| [quantity-tracked-sale.md](quantity-tracked-sale.md) | Existing | Phase 4 |
| [individually-tracked-sale.md](individually-tracked-sale.md) | Existing | Phase 4d |
| [suspended-transaction.md](suspended-transaction.md) | Existing | Phase 4a |
| [customer-return.md](customer-return.md) | Existing | Phase 4e+ |
| [post-void.md](post-void.md) | Existing | Phase 6 |
| [purchasing-and-receiving.md](purchasing-and-receiving.md) | Existing | Phase 5 |
| [customer-request-fulfillment.md](customer-request-fulfillment.md) | Existing | Phase 5 |
| [business-day-close.md](business-day-close.md) | Existing | Phase 4 / 7 |
| [stored-value.md](stored-value.md) | Existing | Phase 6 |

## Planned enrichments before Phase 4c

- Expand or add **POS completion** detail (ordered steps + failure matrix) — prefer enhancing domain completion section or a dedicated `pos-completion.md` without duplicating checklists elsewhere.
- Thin **opening-stock-to-sale** integration narrative linking opening-stock → suspend/recall → completion.
