# Phase 11.4 — Check refund treatment

**Status:** Accepted  
**Needed by:** Phase 11.4  
**Governing area:** Point of Sale / Refund settlement  
**Open decision:** OD-P11-01  
**Does not reopen:** [SV-first refund allocation](phase-11.2-refund-allocation-sv-first.md)

## Decision

For MVP, an amount originally received by check does **not** automatically default to a cash refund.

After the accepted original-tender and stored-value allocations have been satisfied, the check-funded remainder defaults to **new store credit**. Refunding that amount in cash requires the existing refund-exception approval (`pos.return.refund_exception.approve` / `approve_self`).

ShelfStack does not attempt to infer whether a check has cleared and does not introduce a configurable check-holding period in Phase 11.

Store-configurable check-refund policy remains deferred until Check is enabled as an ordinary tender and concrete operating requirements justify it (see [deferred-work-register.md](../deferred-work-register.md) DWR-068).

## Rationale

- Avoids treating uncleared or unknown check funds as immediately refundable cash without an explicit exception.
- Keeps MVP policy simple: no clearance inference and no store holding-period configuration.
- Preserves the existing exception path for cashiers who must refund cash after SV-first / original-tender restoration.

## Consequences

- Refund recommendation UX (11.2F and later hardening) must not propose cash as the automatic remainder for check-funded amounts.
- Phase 11.4 return/refund policy reconciliation implements and tests this default.
- Configurable check-refund rules are not invented in Phase 11.

## Related

- [architectural-locks.md](../architectural-locks.md#check-refund-treatment-mvp)
- [phase-11.2-refund-allocation-sv-first.md](phase-11.2-refund-allocation-sv-first.md)
- [open-decisions.md](../open-decisions.md) OD-P11-01
- [phase-11.4-pos-policy-and-lifecycle-hardening.md](../phases/phase-11.4-pos-policy-and-lifecycle-hardening.md)
