# Phase 11.2 — Refund allocation priority (stored-value first)

**Status:** Accepted  
**Needed by:** Phase 11.2 (Gate 11.2F and refund recommendation UX)  
**Governing area:** Point of Sale / Stored Value  
**Implements:** Existing `Pos::RefundAllocationPolicy` behavior  
**Supersedes:** Cash → card → stored value → other proposal in [phase-11.12-14-draft-scope.md](../../temp_draft/phase-11.12-14/phase-11.12-14-draft-scope.md) §11.2.7 / Open decisions

## Decision

Default refund allocation for receipt-linked (and mixed) return transactions restores **remaining original stored-value tenders before** cash, card, or new store-credit destinations.

Deviations from that plan require the existing exception approval path (`pos.return.refund_exception.approve`), recorded against the bypassing tender.

## Rationale

- Matches the already-shipped server policy in `Pos::RefundAllocationPolicy` (Phase 6d).
- Preserves liability restoration to the original stored-value account before external refund destinations.
- Avoids dual conflicting recommendation rules during Phase 11.2 UX work.

## Consequences

- Gate **11.2F** recommendation UI must present and edit plans under this ordering.
- Cashiers may still record any **permitted** refund tender; non-recommended destinations remain exception-gated as today.
- Draft cash-first ordering is not an open decision for 11.2.

## Related

- [architectural-locks.md](../architectural-locks.md#refund-allocation-priority-v1)
- [service-catalog.md](../service-catalog.md) — `Pos::RefundAllocationPolicy`
- [phase-11.2-register-workflow-refinement.md](../phases/phase-11.2-register-workflow-refinement.md)
