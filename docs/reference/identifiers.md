# Identifier Handling Guide

**Status:** Implementer reference  
**Authority:** [ADR-0002](../adr/0002-canonical-identifiers-and-namespaces.md)  
**Needed by:** Phase 2 (catalog); Phase 4d (units); Phase 6 (stored value)

This document specifies procedures. It does not replace ADR-0002.

## Namespaces

| Prefix | Record | Field |
| --- | --- | --- |
| `21` | Stored-value account | canonical account number |
| `27` | Inventory unit | `unit_identifier` |
| `28` | Product variant | `sku` |
| `29` | Locally identified product | `products.identifier` when generated |

Generated values are organization-wide, unique, immutable, never reused, valid EAN-13, and encode no mutable meaning (store, dept, price, status, etc.).

## Input normalization (general)

1. Trim surrounding whitespace.
2. Remove spaces, hyphens, and common punctuation used in display forms of ISBN/UPC.
3. Preserve significant leading zeros after deciding identifier type.
4. Reject empty results.

Exact allowed character sets for free-text alternate identifiers may be wider; trade identifiers follow the rules below.

## ISBN-10 → ISBN-13

1. Strip separators.
2. Validate ISBN-10 check digit (including `X`).
3. Convert to ISBN-13 by prefixing `978` and recalculating the EAN-13 check digit.
4. Store and look up only the ISBN-13 canonical form.
5. Do **not** store ISBN-10 solely as an alternate identifier for search.

Invalid ISBN-10-shaped input must not be silently converted into a valid-looking ISBN-13.

### Test vector

```text
Input: 0-306-40615-2
Normalized digits: 0306406152
ISBN-10 valid: true
Normalized canonical value: 9780306406157
Type: ISBN-13
Valid: true
```

## ISBN-13 / EAN-13 / UPC-A

- Prefer interpreting 13-digit book numbers in the ISBN-13 ranges as ISBN-13 when checksum validates.
- Recognize UPC-A equivalence with leading-zero EAN-13 where applicable; preserve leading zeros.
- Invalid checksum: warn, keep searchable/storable when authorized, flag for data-quality review. Do not enforce checksum as a DB constraint.

## Generated identifier procedure

1. Allocate the next value from the installation-singleton `identifier_sequences` row for the namespace (`21` / `27` / `28` / `29`) — [OD-011 accepted](../implementation/open-decisions.md). Under INV-ORG-001 there is no per-organization sequence table.
2. Build 12 digits: two-digit prefix + ten-digit zero-padded payload (no encoded business meaning). Fail if the payload would exceed ten digits.
3. Append EAN-13 check digit.
4. Persist with the consuming record. **Never reuse** means never reuse a successfully **committed** assignment; a rolled-back allocation may be regenerated.
5. On rare uniqueness collision at persist time, the **caller** retries (savepoint or whole transaction), allocating again.

## Lookup precedence (product)

Suggested scan/search resolution order:

1. Exact match on `products.identifier` (canonical).
2. Exact match on `product_variants.sku` (`28`).
3. Exact match on `inventory_units.unit_identifier` (`27`) when individual tracking is in scope.
4. Exact match on `products.alternate_identifier` (may be ambiguous → selection UI).
5. Normalized ISBN-10 → ISBN-13 retry of steps 1–4.
6. UPC-A ↔ EAN-13 equivalence retry where applicable.
7. Stored-value `21` / alternate paths when the POS context expects tender/account lookup.

## Canonical vs alternate

| Kind | Role |
| --- | --- |
| Canonical product identifier | Identity; unique per organization |
| Alternate product identifier | Lookup aid; not necessarily unique |
| Variant SKU (`28`) | Exact sellable configuration |
| Unit identifier (`27`) | Exact physical copy |
| SV canonical (`21`) | Account identity |
| SV alternate | Lookup only; does not replace `21` |

## Correction after operational use

Changing a canonical identifier after operational use requires a controlled correction workflow, permission `catalog.identifier.correct`, audit, and must not break historical snapshots (completed lines retain the identifier values as snapshotted).

## Related

- [Catalog domain](../domains/catalog-and-products.md)
- [Stored value domain](../domains/stored-value.md)
- [Inventory domain](../domains/receiving-and-inventory.md)
