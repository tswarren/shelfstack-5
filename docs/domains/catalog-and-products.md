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
- release date (`publication_date`, optional exact calendar date — OD-P8-10; year/month-only provider strings are not persisted);
- language (`language_code`, curated ISO 639-2/T alpha-3 via [`Catalog::LanguageCodes`](../implementation/service-catalog.md); UI default `eng`; blank allowed; alpha-2 / BCP-47 mapped on normalize);
- edition (`edition_statement` — Gate 8b);
- ordered Creators (Gate 8b / OD-P8-02 — see below);
- external list price;
- default Merchandise Class;
- optional Department and Tax-Category overrides;
- Discount and return settings;
- active and sellable states;
- availability dates.

A Product is not sold directly.

## Creator (Gate 8b / OD-P8-02)

An organization-owned bibliographic Creator master (authors, editors, illustrators, translators, narrators, photographers, contributors) and an ordered Product-Creator join.

- `Creator`: `display_name`, `normalized_name` (match key via `Catalog::NormalizeCreatorName`; indexed, not unique), `sort_name` (defaults to `display_name` — no inverted "Last, First" guessing), `active`.
- `ProductCreator`: `product_id`, `creator_id`, `role` (allowlist `author editor illustrator translator narrator photographer contributor`), `position` (service-authoritative — see `Catalog::ReplaceProductCreators`), `credited_as` (nullable edition-specific credit).
- Duplicate Creators and duplicate normalized names are acceptable in v1; name matching is advisory and never triggers automatic merges.
- Same Creator + role on one Product is a soft (model-level) uniqueness rule, not a database constraint.
- Deactivating a Creator hides it from new searches but never removes existing Product links.
- Creator search-to-link uses the shared record-picker foundation (Gate 8a); Creator-master mutations require `catalog.manage_creators`, while linking Creators to a Product uses ordinary product create/edit permissions.

## External metadata lookup (Gate 8b Slice 2 / OD-P8-04)

Service-only in 8b — no lookup HTTP endpoint or result cache ships until Gate 8c's preview workflow. `Catalog::LookupExternalMetadata.call(actor:, store:, identifier:, provider:)` is the sole authorization-checking layer (requires `catalog.lookup_external`); provider adapters (`Catalog::Providers::Isbndb`, `Catalog::Providers::GoogleBooks`) and the injectable `Catalog::Providers::HttpTransport` boundary stay authorization-free and independently testable.

- Only a valid ISBN-13 or Bookland EAN-13 (978/979) proceeds to a provider call (ISBN-10 is canonicalized first, per `Identifiers::Normalize`); UPC, ShelfStack-generated `21`/`27`/`28`/`29` identifiers, other EAN-13 ranges, and malformed input return `unsupported_identifier` with **zero** transport calls.
- An unrecognized `provider:` symbol raises `ArgumentError` at the facade (programmer misuse) — Gate 8c's controller is responsible for turning an invalid user-selected provider into an ordinary validation response.
- Provider order remains ISBNdb (primary) → Google Books (operator-selected secondary, never automatic fallback) → manual entry. Google Books defaults to keyless public lookup; an optional API key is used only when keyless fails.
- Adapters map every response into `Catalog::Enrichment::NormalizedResult` — an immutable, deep-frozen, provider-neutral shape (title, creators, publisher, exact `publication_date` `Date` when known, curated ISO 639-2/T `language_code`, list price as `Catalog::Enrichment::NormalizedMoney`, external subjects, images, warnings). Application code never depends on ISBNdb- or Google-Books-specific response keys.
- Provider creator names normalize into the Slice 1 `ProductCreator` role allowlist; a missing or unrecognized role becomes `contributor` plus a `Catalog::Enrichment::NormalizedWarning` — arbitrary provider role strings are never persisted.
- List price parses with `BigDecimal` (never `Float`), rejects negative/non-numeric amounts, rounds half-up to integer cents, and uppercases the currency code (or keeps it null) — whether a null/mismatched currency may apply remains the later create/enrich workflow's decision (OD-P8-01 §5), not this lookup layer's.
- Normalized adapter failures: `not_found`, `ambiguous_result`, `authentication_failed`, `rate_limited`, `timeout`, `provider_unavailable`, `invalid_response`, `unsupported_identifier`. Google Books distinguishes a missing exact-ISBN match (`not_found`) from more than one exact match, including duplicate hits (`ambiguous_result`) — it never accepts the first relevance-ranked hit.
- Transport policy: HTTPS-only fixed provider base URLs, explicit connect/read timeouts, a bounded response body, and at most one retry (connection reset / temporary network failure / HTTP 502/503/504 only — never on authentication failure or a malformed body). HTTP 429 always maps to `rate_limited` without sleeping; a parsed `Retry-After` is preserved in failure metadata when present.
- Credentials (`SHELFSTACK_ISBNDB_API_KEY`, optional `SHELFSTACK_GOOGLE_BOOKS_API_KEY`) are read from `ENV` only — never stored on a Product/org/store row, logged, or included in a failure message (see [bootstrap-and-seed.md](../implementation/bootstrap-and-seed.md#external-metadata-provider-credentials-gate-8b-slice-2)).
- A lookup creates **no** Product, Variant, Creator, ProductCreator, or `catalog_enrichment_events` row — persistence and provenance-event writing are Gate 8c/8f work.
- `Catalog::MapProductFormat` is a read-only suggestion boundary: an exact active-`ProductFormat` code/name match, or a small explicit provider-token map, resolves to at most one suggestion; several matches return no suggestion plus a warning. It never creates, updates, or auto-applies a `ProductFormat`.

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

A valid ISBN-10 input is validated and converted to ISBN-13 for canonical storage and search. An invalid ISBN-10 check digit produces an overridable warning and keeps the stripped ISBN-10-shaped value (it is not silently converted into a valid-looking ISBN-13).

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
catalog.lookup_external
catalog.manage_creators
```

See [authorization-permissions.md](authorization-permissions.md) for the canonical key spellings (e.g. `catalog.product.view`); this list uses shorthand prose names.

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
