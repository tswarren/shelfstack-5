# Workflow: Post-Void Completed Transaction

**Status:** Delivered in Phase 6a (Policy A card path)  
**Type:** Record-level workflow  
**Governing:** ADR-0008, ADR-0009, ADR-0016; [point-of-sale](../domains/point-of-sale.md); [phase-06 post-void eligibility](../implementation/decisions/phase-06-post-void-eligibility-and-cross-domain-reversal.md); [service-catalog](../implementation/service-catalog.md)

## Purpose

Create an explicit reversing completed Transaction for a previously completed POS Transaction without mutating the original completed records.

## Policy A card sequence

For a completed Transaction that includes completed card tenders:

1. Approve the post-void reason and authorization (`ApprovePostVoid` / `pos.post_void.approve` as required).
2. Reverse each original card payment on the external standalone terminal.
3. Record durable confirmation audits that each required external reversal occurred (operator confirmation; optional external void/refund reference and note).
4. Create the reversing Transaction (`PostVoidTransaction`) with reversing lines and tenders.

Approval authorizes the ShelfStack correction and operational procedure. It does not prove that the processor accepted the external reversal (ADR-0016).

## Preconditions (high level)

- Original Transaction is completed and eligible under the Phase 6 post-void decision note.
- Actor holds `pos.post_void.create` (and approval permission when required).
- Interim OD-014 and return-containing blocks remain as documented in the decision note.

## Related

- [pos-completion.md](pos-completion.md)
- [customer-return.md](customer-return.md)
