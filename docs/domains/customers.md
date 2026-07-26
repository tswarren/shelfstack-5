# Customers Domain

**Status:** Consolidated specification (Phase 9 v1)  
**Domain owner:** Customer master identity and contact facts  
**Governing ADR:** [ADR-0017](../adr/0017-customer-domain-and-namespace-22.md)

## Purpose

This domain governs organization-scoped Customer records used for identification, contactability, Product Request association, and POS attachment.

It does **not** own loyalty, households, notifications delivery, promotions, tax exemptions, or purchase-history CRM.

## Ownership boundary

### Owns

- Customer;
- `customer_number` (namespace `22`);
- customer type;
- name and organization name;
- address and contact fields;
- preferred contact method;
- active / inactive status;
- Customer create, update, deactivate, search, and duplicate detection.

### References but does not own

- Organization and Store;
- Product Request (`customer_id`);
- POS Transaction (`customer_id`);
- POS Session staged-customer triad;
- Stored-Value Account (optional future link deferred).

## Customer

Suggested attributes:

- Organization;
- immutable `customer_number` (`22` EAN-13);
- `customer_type` (`individual` | `organization`);
- `organization_name`, `first_name`, `last_name`;
- address fields;
- `primary_phone`, `alternate_phone` (E.164);
- `primary_email`, `alternate_email`;
- `preferred_contact_method` (`phone` | `email` | `none`);
- `notes`;
- `active`.

`display_name` is derived (organization name, or joined individual names).

### Type rules

- **individual:** at least one of `first_name` / `last_name`; `organization_name` blank.
- **organization:** `organization_name` required; name fields optional as primary contact.

### Preferred contact

| Method | Requirement |
| --- | --- |
| `phone` | `primary_phone` present |
| `email` | `primary_email` present |
| `none` | neither required |

Alternate fields do not satisfy preferred method.

### Contactable

```text
phone → primary_phone present
email → primary_email present
none  → false
```

Workflows that require notification (new `customer_request` assignment) must use a contactable Customer. Ordinary Customer creation may leave contacts optional with `preferred_contact_method: none`.

### Inactive

- Remain on historical POS and request records.
- Remain on existing open requests.
- Excluded from normal search by default.
- Direct `customer_number` lookup may show with an inactive warning.
- Cannot be staged, attached to a new transaction, or assigned to a new/changed request.

## Permissions

```text
customers.customer.view
customers.customer.lookup
customers.customer.create
customers.customer.edit
customers.customer.deactivate
```

- `view` — full Customer admin (index/show/forms) and search.
- `lookup` — search plus limited name/number/contact references for POS and Product Requests.
- `create` / `edit` / `deactivate` require `view` in addition to the action permission.
- Product Request create/update require `view` or `lookup` whenever `customer_id` is supplied or changed; unrelated request edits do not.

## Invariants

- `customer_number` is unique, immutable, and a valid generated namespace `22` EAN-13.
- Customers belong to an Organization, not a Store.
- Contact values are not unique customer identifiers.
- Duplicate detection warns before insert; creation requires explicit override when duplicates exist.
- Organization compatibility is required for search, stage, attach, and request assignment.
- Phase 9 POS attachment is commercially inert (ADR-0017).

## Deferred

- Full CRM, households, loyalty, notifications platform.
- `customer_contact_methods`, extensions, SMS vs call split.
- Customer merge / restore / archival workflows.
- Stored-value account customer linkage.
- Membership pricing, tax exemptions, and promotions driven by customer.
