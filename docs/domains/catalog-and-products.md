# Catalog and Products Domain

**Status:** Consolidated specification  
**Domain owner:** Product identity, sellable configurations, identifiers, descriptive metadata, and eligibility inputs

## Governing ADRs

- [ADR-0001: Separate Product, Product Variant, and Inventory Unit](../adr/0001-product-variant-inventory-unit.md)
- [ADR-0002: Use Canonical Identifiers and Separate Restricted-Circulation Namespaces](../adr/0002-canonical-identifiers-and-namespaces.md)
- [ADR-0003: Use One Merchandise-Class Hierarchy with Department Defaults](../adr/0003-merchandise-classes-and-departments.md)

## Related documentation

- [ADR-0013: Govern Quantity-Tracked Inventory Cost Through Moving Weighted Average and Explicit Cost Provenance](../adr/0013-govern-quantity-tracked-inventory-cost.md) — quantity-tracked cost owned by Receiving and Inventory; Catalog supplies tracking mode and regular price

## Purpose

This domain defines what ShelfStack recognizes as a commercial item and which exact configuration is sold, purchased, received, taxed, or inventoried.

It owns:

```text
Product
└── Product Variant
    └── Inventory Unit, when individual tracking is required
```

The Receiving and Inventory domain owns the operational Inventory Unit. Catalog defines when a Variant requires one.

## Ownership boundary

### Owns

- Product;
- Product Variant;
- canonical Product Identifier;
- Alternate Identifier;
- generated local Product Identifier;
- generated Variant SKU;
- Product Type;
- Format;
- Condition definitions;
- variant option structures;
- Inventory-Tracking Mode;
- current pricing inputs;
- Department, Merchandise-Class, and Tax-Category assignments or overrides;
- Discount and return eligibility inputs;
- Product and Variant activation, sellability, and purchasability;
- lookup and scan resolution;
- sale-eligibility inputs.

### Does not own

- Store Stock Balances;
- Inventory Units' operational status and cost;
- Inventory Reservations;
- Vendor Sources;
- Purchase Orders;
- Receipts;
- completed POS snapshots;
- final tax calculation;
- Tenders.

## Product

A Product represents the commercial item recognized by publishers, manufacturers, Vendors, and customers.

Examples:

- one ISBN-defined book edition;
- one music release;
- one video edition;
- one game package;
- one greeting-card design;
- one packaged café item;
- one service.

Suggested attributes:

- Organization;
- canonical identifier;
- Alternate Identifier;
- title and subtitle;
- descriptions;
- Product Type;
- variant structure;
- Format;
- publisher or manufacturer;
- imprint or brand;
- release date;
- language;
- edition;
- external list price;
- default Merchandise Class;
- optional Department and Tax-Category overrides;
- Discount and return settings;
- active and sellable states;
- availability dates.

A Product is not sold directly.

## Product Variant

A Product Variant represents the exact operational configuration.

Examples:

- standard new copy;
- used configuration;
- signed configuration;
- size or color;
- package variation;
- café size;
- service configuration.

Suggested attributes:

- Product;
- generated SKU;
- name and description;
- Condition category;
- option summary;
- Inventory-Tracking Mode;
- Merchandise-Class override;
- Department override;
- Tax-Category override;
- regular selling price;
- Discount setting;
- return setting and policy;
- default Return Disposition;
- active, sellable, and purchasable states;
- availability dates.

Every sellable Product has at least one Variant.

## Identifiers

### Canonical Product Identifier

Every Product has exactly one canonical identifier.

Accepted forms include ISBN-13, UPC-A, EAN-13, another approved trade identifier, or generated `29` EAN-13 local identifier.

Canonical identifiers are normalized, indexed, unique within the Organization, and treated as immutable after operational use.

### ISBN normalization

A valid ISBN-10 input is validated and converted to ISBN-13 for canonical storage and search. An invalid ISBN-10-shaped value is not silently converted.

### UPC and EAN equivalence

ShelfStack recognizes a UPC-A and its leading-zero EAN-13 representation as equivalent where applicable.

### Alternate Identifier

A Product may have one optional Alternate Identifier. It is indexed but may be non-unique. Multiple matches require a selection workflow.

### Generated namespaces

```text
28 — Product Variant SKU
29 — locally identified Product
```

Generated values are EAN-13, immutable, never reused, and do not encode mutable business meaning.

## Variant structure

Suggested values:

```text
single
options
matrix
```

A single Product has one standard Variant.

Options and matrix Products may use option types, option values, and Variant-option assignments. The exact schema remains Proposed.

## Format and Condition

Format describes the commercial or physical presentation, such as hardcover, trade paperback, vinyl, or greeting card.

Condition describes merchandise state, such as new, very good, acceptable, collectible, or damaged.

Format normally belongs to the Product when it defines the external edition. Exact-copy Condition belongs to the Inventory Unit.

## Inventory-Tracking Mode

Every Variant declares:

```text
quantity
individual
none
```

- `quantity`: interchangeable copies use one Store-and-Variant Stock Balance;
- `individual`: each exact copy receives an Inventory Unit;
- `none`: no Reservation or Inventory Movement is created.

Inventory-Tracking Mode determines whether Stock Balances and inventory cost apply (`quantity` and later `individual`). Catalog regular selling price may be used as an input when Inventory posts a Department-based cost estimate. Catalog does not own Stock Balances, ledger posting, or posted inventory valuation. Current Catalog price or classification changes do not rewrite completed cost snapshots.

## Price resolution

The baseline may keep current regular price on the Variant.

Recommended service boundary:

```text
Inventory-Unit price override
→ Store-specific Variant price, when introduced
→ Organization Variant price
→ missing-price blocker
```

ShelfStack never silently uses zero as the selling price.

## Classification resolution

Recommended Department resolution:

```text
Variant override
→ Product override
→ Merchandise-Class default Department
→ blocker
```

Tax Category and return or Discount settings use their own documented precedence chains.

## Sale-eligibility service

A centralized service evaluates:

- Product active and sellable;
- Variant active and sellable;
- effective price;
- effective Department;
- effective Tax Category;
- availability dates;
- Inventory-Tracking requirements;
- exact Inventory Unit when required;
- Store and Unit status;
- applicable Approval requirements.

The result distinguishes:

```text
eligible
warnings
blockers
approval_requirements
```

## Lookup hierarchy

1. exact Inventory-Unit Identifier;
2. exact Variant SKU;
3. canonical Product Identifier;
4. Alternate Identifier;
5. descriptive search.

A Product match may require Variant selection. An individual Variant still requires exact Unit selection before sale.

## Permissions

```text
catalog.view
catalog.create_product
catalog.edit_product
catalog.deactivate_product
catalog.correct_identifier
catalog.merge_products
catalog.create_variant
catalog.edit_variant
catalog.deactivate_variant
catalog.manage_options
catalog.manage_formats
catalog.manage_conditions
catalog.review_data_quality
catalog.print_labels
```

## Audit requirements

Audit Product creation, identifier generation and correction, Variant creation, SKU generation, activation and sellability changes, Inventory-Tracking changes, price changes, classification changes, return and Discount changes, and Product merges.

## Invariants

- Product, Variant, and Inventory Unit remain distinct.
- Every Product has one canonical identifier.
- Every sellable Product has at least one Variant.
- Every Variant belongs to one Product and has one immutable SKU.
- Product scans never bypass Variant resolution.
- Inventory tracking is explicit at Variant level.
- Quantity tracking does not create one Unit per copy.
- Individual tracking requires exact Unit identity.
- Non-inventory Variants create no stock effects.
- Current Catalog data does not rewrite completed history.
- Catalog regular price may feed estimated inventory cost; Catalog does not own posted inventory valuation.

## Open questions

- Which Product fields are required by Product Type?
- Which Formats belong to Product versus Variant?
- What is the final option and matrix schema?
- When should Store-specific pricing be introduced?
- Under what controlled process may a canonical identifier change?
- How should duplicate Product merges preserve aliases and history?
- When will requirements justify multiple active Product identifiers?
