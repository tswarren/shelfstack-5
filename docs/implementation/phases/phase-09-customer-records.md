# Phase 9 — Customer records (v1)

**Status:** Implemented (gates 9a–9d)  

**Depends on:** Phase 5 (Product Requests), Phase 6.5 (cashier workspace shell)  
**Chronologically follows:** Phase 8 catalog refinement (closed)  
**Unlocks:** POS customer attach, contactable customer requests, stable customer references  
**Governing docs:** [ADR-0017](../../adr/0017-customer-domain-and-namespace-22.md); [ADR-0002](../../adr/0002-canonical-identifiers-and-namespaces.md); [customers](../../domains/customers.md); [customers schema](../../schema/customers.md)

## Goal

Introduce a flat organization-scoped Customer master with namespace-`22` identity, wire Product Requests to `customer_id`, and support POS stage/attach/lookup without inventing full CRM or commercially significant customer pricing.

## Scope summary

1. **Customer domain** — schema, model, normalization services, duplicate-before-create, permissions, admin CRUD.
2. **Product Requests** — replace `customer_reference` with `customer_id`; service-level contactability for new customer requests; pre-production backfill.
3. **POS** — owner-scoped session staging triad; attach/replace/remove; commercially inert; inactive and org-boundary rules.

## Delivery gates

| Gate | Focus |
| --- | --- |
| **9a** | ADR + docs + schema + identifier `22` + model/service normalize split + `phonelib` |
| **9b** | Customer services + admin CRUD + pre-create duplicate warning UX + permissions |
| **9c** | Product Request `customer_id`, backfill, drop `customer_reference`, contactability |
| **9d** | POS stage triad, attach/replace/remove, register lookup |

## Architectural locks (Phase 9)

- Attaching, replacing, or removing a customer does **not** change price, discounts, promotions, tax, tender eligibility, or transaction totals.
- Staged customers on shared sessions are owned by `staged_customer_by_user_id`; only that user may consume.
- Preferred contact uses primary fields only.
- Phone store-country context is passed through Customer services, not ambient model callbacks.
- Single `UNIQUE (customer_number)` constraint.

## Out of scope

- Full CRM, households, loyalty, outbound notifications.
- `customer_contact_methods`, merge/restore/archival.
- Keeping `customer_reference` after backfill; legacy remediation queues.
- Stored-value ↔ customer FK.
- Membership pricing, tax exemptions, promotions driven by customer.
- Full POS shell revamp beyond customer attach.

## Exit criteria

- Namespace `22` generation and immutability tested.
- Duplicate gate blocks insert until `create_anyway`.
- New `customer_request` requires contactable customer; backfilled requests remain editable without contactability.
- Staging owner-only consume; inactive and org-boundary enforced.
- Attach is commercially inert and tender-lock aware.
- `bin/ci` green.

## Related

- [../roadmap.md](../roadmap.md)
- [../current-phase.md](../current-phase.md)
- [../deferred-work-register.md](../deferred-work-register.md) (DWR-036)
