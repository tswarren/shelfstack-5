# Customers schema (Phase 9)

**Status:** Implemented (Phase 9)  
**Domain:** [customers.md](../domains/customers.md)  
**Governing ADR:** [ADR-0017](../adr/0017-customer-domain-and-namespace-22.md)

## Tables

| Table | Purpose |
| --- | --- |
| `customers` | Organization-scoped Customer master |

## `customers`

| Column | Notes |
| --- | --- |
| `organization_id` | FK, required |
| `customer_number` | string, globally UNIQUE, immutable generated `22` EAN-13 |
| `customer_type` | `individual` \| `organization` |
| `organization_name`, `first_name`, `last_name` | type-dependent |
| `address_line_1`, `address_line_2`, `city`, `region`, `postal_code` | optional |
| `country_code` | ISO 3166-1 alpha-2, uppercased |
| `primary_phone`, `alternate_phone` | E.164 or null |
| `primary_email`, `alternate_email` | trimmed lowercased or null |
| `preferred_contact_method` | `phone` \| `email` \| `none` |
| `notes` | optional text |
| `active` | boolean, default true |
| timestamps | |

Indexes:

- `UNIQUE (customer_number)`
- partial non-unique indexes on each phone/email `WHERE … IS NOT NULL`

## Consumer foreign keys

| Table | Column | Notes |
| --- | --- | --- |
| `product_requests` | `customer_id` | nullable FK; replaces dropped `customer_reference` |
| `pos_transactions` | `customer_id` | nullable FK |
| `pos_sessions` | `staged_customer_id` | nullable FK |
| `pos_sessions` | `staged_customer_by_user_id` | nullable FK to users |
| `pos_sessions` | `staged_customer_at` | nullable timestamp |

## Identifier sequence

`identifier_sequences.namespace` includes `22` (installation-singleton; OD-011 / INV-ORG-001).
