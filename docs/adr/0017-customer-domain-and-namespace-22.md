# ADR-0017: Introduce a Flat Customer Domain and Namespace 22

**Status:** Accepted

## Context

Phase 5 Customer Requests used a nullable opaque `customer_reference` string (OD-006 v1). POS transactions carried no customer association. A durable Customer master is required for:

* POS identification and fulfilment context;
* Product Request customer identity and contactability;
* stable external references (receipts, imports, customer service) without exposing database primary keys.

Full CRM (households, loyalty, notifications platform, merge workflows, multi-contact tables) remains deferred.

## Decision

ShelfStack introduces a flat, organization-scoped **Customer** master record.

### Identifier namespace

ADR-0002 namespaces are extended:

```text
21 — stored-value account
22 — customer
27 — inventory unit
28 — product variant
29 — locally identified product
```

Every Customer receives an immutable generated `22` EAN-13 `customer_number`, unique within the installation, never reused, and free of encoded mutable meaning.

### Customer types

```text
individual
organization
```

Stored explicitly. Organizations may optionally carry a primary contact via `first_name` / `last_name` without a separate contact table.

### Contact normalization

* Phone numbers are parsed with a proven library and stored in E.164 when valid.
* An explicit `+` country prefix is never reinterpreted using customer or store country.
* Default phone country resolution (when no `+`): customer `country_code`, then caller-supplied store country.
* Store-dependent phone parsing belongs in application services, not model callbacks that read ambient store context.
* Email addresses are trimmed and lowercased as a ShelfStack application policy (not claimed as an RFC mandate). Provider-specific rewriting is forbidden.
* Contact fields are optional on the Customer record. Preferred contact method uses **primary** fields only:

```text
phone → primary_phone required
email → primary_email required
none  → neither required
```

* Contacts are indexed for lookup and duplicate warnings but are not unique identifiers.

### Duplicate warnings

Creation normalizes and validates, searches for possible duplicates across primary and alternate phone/email positions, and returns choices **before** insert unless an explicit `create_anyway` flag is supplied.

### Product Requests

`customer_reference` is replaced by `customer_id`. New `customer_request` records require an active, organization-compatible, contactable Customer. Contactability is enforced in request services, not as a blanket model validation on every Product Request edit. Pre-production backfill may create non-contactable legacy customers and bypass the new-request check.

### POS attachment

POS may stage, attach, replace, or remove a Customer. Staging on a shared session records the staging user; only that user may consume the staged Customer. Phase 9 attachment is commercially inert: it does not change price, discounts, promotions, tax, tender eligibility, or totals. It obeys the existing transaction edit / tender lock.

### Inactive customers

Inactive Customers remain on historical records and open requests, are excluded from normal search by default, may appear on direct `customer_number` lookup with a warning, and cannot be newly staged, attached, or assigned.

## Consequences

* OD-006 opaque-reference interim is superseded for new work.
* Identifier sequences, normalization, and lookup must recognize namespace `22`.
* Rich CRM, outbound notifications, merge, and `customer_contact_methods` remain deferred.
* Later commercial customer effects (membership pricing, exemptions, loyalty) require explicit superseding decisions.

## Related

- [ADR-0002](0002-canonical-identifiers-and-namespaces.md)
- [customers domain](../domains/customers.md)
- [Phase 9 plan](../implementation/phases/phase-09-customer-records.md)
