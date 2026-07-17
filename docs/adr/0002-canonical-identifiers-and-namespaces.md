# ADR-0002: Use Canonical Identifiers and Separate Restricted-Circulation Namespaces

**Status:** Accepted

## Context

ShelfStack must support:

* externally assigned identifiers;  
* locally created products;  
* internally generated variant SKUs;  
* exact-copy identifiers;  
* stored-value account numbers;  
* ISBN-10 input;  
* ISBN-13;  
* UPC-A;  
* EAN-13;  
* migrated or externally printed stored-value cards.

Identifiers must remain stable and scannable without encoding mutable business information.

Earlier designs considered a one-to-many product-identifier table. The current design instead favors one canonical product identifier and one optional alternate lookup value.

ShelfStack also needs to distinguish internally generated identifiers by record type.

## Decision

ShelfStack will assign one canonical identifier to each applicable record and use separate restricted-circulation EAN-13 namespaces.

```
21 — stored-value account
27 — inventory unit
28 — product variant
29 — locally identified product
```

Internally generated identifiers will:

* contain 13 digits;  
* begin with their assigned prefix;  
* contain a valid EAN-13 check digit;  
* be unique across the organization;  
* be immutable;  
* never be reused;  
* be suitable for scanning and label printing.

They will not encode:

* store;  
* department;  
* merchandise class;  
* condition;  
* price;  
* cost;  
* account balance;  
* status;  
* date;  
* parent record.

## Product identifiers

Every product will have one canonical primary identifier.

The identifier may be:

* ISBN-13;  
* UPC-A;  
* EAN-13;  
* another approved trade identifier;  
* a ShelfStack-generated `29` identifier.

A product may also have one optional alternate identifier.

The alternate identifier:

* is indexed;  
* need not be globally unique unless a specific workflow requires uniqueness;  
* may return more than one product;  
* is a lookup aid rather than the product’s canonical identity.

## ISBN handling

A valid ISBN-10 entered through:

* scanning;  
* search;  
* import;  
* manual entry;

will be:

1. normalized;  
2. validated;  
3. converted to ISBN-13;  
4. stored and searched through the canonical ISBN-13 representation.

ISBN-10 will not be stored as an alternate identifier merely to support ISBN-10 lookup.

An invalid ISBN-10-shaped value must not be silently converted into a valid-looking ISBN-13.

## UPC and EAN handling

ShelfStack will recognize the equivalence between a UPC-A and its leading-zero EAN-13 representation where applicable.

Leading zeroes must be preserved.

## Checksum validation

ISBN, UPC, and EAN check digits will be validated.

An invalid checksum will normally:

* generate a warning;  
* remain searchable;  
* remain storable when authorized;  
* be available for later data-quality review.

Checksum validity will not ordinarily be enforced as a database constraint.

## Variant identifiers

Every product variant receives a generated `28` EAN-13 SKU.

The SKU resolves the exact sellable configuration.

## Inventory-unit identifiers

Every individually tracked physical copy receives a generated `27` EAN-13 unit identifier.

The field will be called:

```
unit_identifier
```

rather than `sku`.

## Stored-value identifiers

Every stored-value account receives a generated `21` EAN-13 account number.

A stored-value account may also have an alternate identifier entered by a user.

Examples include:

* a preprinted card number;  
* a migrated legacy number;  
* an external certificate reference.

Both identifiers may resolve the same stored-value account.

The generated `21` identifier remains the canonical ShelfStack account identity.

## Consequences

### Benefits

* Scanned internal barcodes identify the record type immediately.  
* Identifiers remain stable when operational attributes change.  
* ShelfStack can create valid barcodes without external registration.  
* Product lookup supports common ISBN and UPC representations.  
* Migrated stored-value cards can retain their existing numbers.  
* Duplicate and malformed identifier behavior is explicit.

### Costs

* Identifier generation requires organization-wide sequencing or collision prevention.  
* Lookup services must normalize ISBN and UPC/EAN input.  
* Alternate-identifier ambiguity requires a selection workflow.  
* Changing a canonical identifier after operational use requires a controlled correction process.

## Alternatives considered

### Encode department, condition, or store in identifiers

Rejected because those attributes may change.

### Use one unrestricted internal sequence for every record type

Rejected because scan resolution would require additional database lookups before the record type is known.

### Store every identifier in a one-to-many product-identifiers table

Rejected for the current baseline because the present requirements are satisfied by one canonical and one alternate identifier.

A related identifier table may be reconsidered if future requirements include multiple package barcodes, historical aliases, or numerous vendor codes.

## Governing rules

* Canonical identifiers are immutable after operational use except through controlled correction.  
* Generated identifiers are never reused.  
* ISBN-10 input resolves through canonical ISBN-13.  
* Stored-value alternate identifiers do not replace the canonical `21` identifier.  
* Identifiers must not encode mutable operational meaning.

## Related domains

* Catalog and Products  
* Receiving and Inventory  
* Stored Value  
* Point of Sale