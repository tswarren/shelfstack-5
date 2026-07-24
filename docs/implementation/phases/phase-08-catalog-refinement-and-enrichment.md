# Phase 8 — Catalog Refinement & Enrichment

**Status:** Ready for implementation — not started
**Date:** 2026-07-24
**Depends on:** Phase 7 core complete
**Roadmap position:** Next delivery phase after Phase 7
**Governing documents:** ADR-0001, ADR-0002, ADR-0003; [catalog-and-products](../../domains/catalog-and-products.md); [architectural-locks](../architectural-locks.md)
**Carry-forward register:** [deferred-work-register.md](../deferred-work-register.md)
**Decision note:** [phase-08-catalog-refinement-and-enrichment-v1.md](../decisions/phase-08-catalog-refinement-and-enrichment-v1.md)  
**Decision register:** [open-decisions.md](../open-decisions.md) (OD-P8-01…10 dispositioned; other open items in that file remain open)

**Source draft (superseded as planning home):** [phase-8-catalog-refinement-ideas.md](../../temp_draft/phase-8-catalog-refinement-ideas.md)

Operating decisions OD-P8-01 through OD-P8-10 have been dispositioned.
See the decision note for binding implementation rules.

---

## 1. Goal

Make catalog work safe, fast, and intelligible for staff.

ShelfStack should allow staff to:

* locate and link related records without navigating long unfiltered lists;
* create bibliographic products from an ISBN using an external metadata provider;
* review imported data before it changes ShelfStack records;
* understand a product’s catalog, operational, inventory, purchasing, and availability state from one staff-oriented summary;
* distinguish values explicitly set on a record from values derived through ShelfStack defaults;
* enrich existing products without allowing external metadata to silently replace operational configuration.

External metadata must never silently:

* make a product sellable or purchasable;
* change inventory-tracking mode;
* change a store selling price;
* change department or tax overrides;
* change inventory quantities or unit status;
* create inventory movements;
* reinterpret completed POS, purchasing, receiving, or reporting history.

---

## 2. Operator priorities

The following priorities govern the phase.

### 2.1 Enrichment before multi-variant

Create-from-ISBN and catalog enrichment provide more immediate operational value than enabling several variants under one product.

Phase 8 may ship while retaining the current:

```text
product.variant_structure = single
one product → one standard variant
```

constraint.

Multi-variant support requires a separate cross-domain implementation packet and is not a Phase 8 core exit criterion.

### 2.2 Create-from-ISBN is the core enrichment path

Create-from-ISBN is required for the core Phase 8 release.

Enrich-existing is an important follow-on, but Phase 8 core may complete before the full selective enrichment workflow ships.

### 2.3 Product hardening, not domain expansion

Phase 8 improves how existing Catalog, Classification, Inventory, Product Request, Purchasing, and Receiving facts are entered and presented.

It must not transfer ownership of those facts into the Catalog domain.

---

## 3. Characterization

```text
existing Product + one standard Product Variant
→ shared linking and lookup controls
→ bibliographic representation foundation
→ create-from-ISBN
→ staff-oriented product summary hub
→ effective-value and source presentation
→ streamlined vendor-source linking
→ enrich-existing suggest/apply
→ optional subject and image enrichment
→ separate Phase 8.5 named-variant implementation
```

### Should deliver

* faster catalog data entry;
* shared record-picking controls;
* ISBN-based product creation;
* normalized provider integration;
* bibliographic creators;
* safer imported metadata;
* a clearer product overview;
* visible inherited and overridden values;
* streamlined vendor-source linking;
* clear catalog data-quality warnings.

### Should not deliver

* inventory counts;
* inter-store transfers;
* complete return-to-vendor workflows;
* buyback;
* full customer CRM;
* customer notification infrastructure;
* ONIX or frontlist campaign management;
* EDI;
* integrated accounting exports;
* offline POS;
* warehouse-style sublocations;
* a second display-category hierarchy;
* store inventory mutation from catalog screens;
* full multi-variant matrices.

---

## 4. Terminology and interface language

Domain and schema names remain unchanged.

| Staff-facing term   | Domain / schema  |
| ------------------- | ---------------- |
| Products or catalog | `Product`        |
| Items               | `ProductVariant` |
| Units or copies     | `InventoryUnit`  |

This terminology is interface guidance only.

Domain models, services, permissions, routes, and technical documentation should continue to use the canonical entity names where precision is required.

---

## 5. Core architectural rules

### 5.1 Product, variant, and inventory unit remain distinct

```text
Product
└── Product Variant
    └── Inventory Unit, when individually tracked
```

* Product owns stable descriptive and bibliographic identity.
* Product Variant owns the exact operational configuration that is sold, purchased, priced, taxed, and tracked.
* Inventory Unit represents one exact physical copy when individual tracking applies.

### 5.2 One merchandise-class hierarchy remains authoritative

External subjects such as BISAC may be imported or mapped, but they must not create a parallel ShelfStack display hierarchy.

ShelfStack merchandise classes remain the authoritative hierarchy for merchandising, shelving, browsing, and class-based defaults.

### 5.3 Inventory remains store-owned

Catalog changes must not:

* create an inventory ledger entry;
* change `on_hand`;
* change `reserved`;
* change `unavailable`;
* change an inventory unit’s status;
* move an inventory unit between stores.

Inventory effects continue through the existing Inventory services.

### 5.4 Completed history remains unchanged

Catalog enrichment affects current master data only.

It must not rewrite completed:

* POS snapshots;
* purchase-order snapshots;
* receipt records;
* inventory movements;
* stored-value records;
* report results.

---

## 6. Phase gates

### 8a — Catalog interaction foundation

**Priority:** Must
**Purpose:** Establish shared controls used by the remaining Phase 8 workflows.

#### Scope

Create reusable controls for:

* hierarchical merchandise-class selection;
* hierarchical department selection;
* product-format selection;
* tax-category selection;
* product search-to-link;
* product-variant search-to-link;
* vendor search-to-link;
* a reusable record-picker foundation capable of supporting later Creator lookup;
* optional create-from-picker actions where authorized.

Creator search-to-link is delivered in Gate 8b after the Creator model exists.

Controls should support, as appropriate:

* typing to filter;
* keyboard navigation;
* clear current selection;
* hierarchical labels;
* active/inactive distinction;
* empty-state messaging;
* loading and error states;
* Turbo and Stimulus compatibility;
* server-side authorization;
* accessible labels and focus behavior.

#### Exit criteria

* Product and variant forms no longer depend on unwieldy unfiltered lists for high-volume linking fields.
* One shared implementation pattern is documented.
* Search results remain scoped to the current organization or store as appropriate.
* Inactive records are excluded by default but may be intentionally shown where a correction workflow requires them.
* Controls work without requiring a single-page application.

---

### 8b — Bibliographic representation and provider foundation

**Priority:** Must
**Purpose:** Establish a provider-neutral model before implementing product creation.

#### Scope

* provider-neutral lookup adapter with ISBNdb as the primary production provider;
* normalized enrichment result;
* Creator model and ordered Product-Creator join;
* Creator search-to-link using the shared record-picker foundation;
* accepted minimum bibliographic Product fields (`publication_date`, `publication_date_precision`, `language_code`, `edition_statement`);
* provider credentials and error handling;
* append-only `catalog_enrichment_events` provenance contract;
* format-mapping boundary;
* explicit operator-selected secondary-provider lookup (Google Books optional);
* provider-independent tests.

#### Normalized provider result

Provider adapters should map their results into a common internal representation before controllers or forms use them.

A normalized result should be capable of representing:

```text
requested_identifier
canonical_identifier
provider
provider_record_id
retrieved_at

title
subtitle
description
creators
publisher
imprint
publication_or_release_date
language_code
edition_statement
format
external_subjects
list_price
list_price_currency
images
warnings
```

Not every provider must populate every field.

Application forms and persistence services must not depend directly on ISBNdb- or Google-Books-specific response keys.

#### Provider behavior

The provider boundary must define:

* connection timeout;
* response timeout;
* rate-limit handling;
* invalid credential behavior;
* no-result behavior;
* ambiguous-result behavior;
* incomplete-result behavior;
* safe logging;
* credential redaction;
* explicit operator-selected secondary-provider lookup;
* no automatic multi-provider fallback in v1;
* optional short-lived lookup caching for preview-and-accept only.

One user action calls one provider. The operator may intentionally try another enabled provider after no result, incomplete result, error, or a rejected primary result.

A provider failure must not create or partially update a ShelfStack product.

#### Exit criteria

* The ISBNdb adapter produces the normalized provider-neutral result.
* Google Books may be wired as an optional secondary provider without rewriting product persistence.
* Creator search-to-link uses the shared record-picker foundation.
* Creator and format mappings can be represented.
* Provider credentials are not stored in ordinary database fields or logs.
* Failure behavior is tested.

---

### 8c — Create from ISBN

**Priority:** Must
**Purpose:** Create a Product and one standard Product Variant from reviewed bibliographic metadata.

#### Workflow

```text
operator enters or scans identifier
→ normalize identifier
→ search ShelfStack canonical identity
→ search equivalent identifier representation where applicable
→ existing product found?
   → open existing product
   → optionally offer enrichment
→ otherwise query provider
→ normalize provider result
→ preview proposed Product and Variant values
→ operator confirms or changes mappings
→ transactionally create Product + standard Variant + creator links
→ open product summary
```

#### Identifier rules

* ISBN-10 is validated and normalized to ISBN-13 before lookup.
* An invalid ISBN-10-shaped value must not be converted into a valid-looking ISBN-13.
* ISBN-13, EAN, and UPC normalization continues to follow existing catalog rules.
* ShelfStack searches for an existing product before querying a provider.
* The database uniqueness constraint remains the final duplicate-creation guard.
* A provider response containing a conflicting identifier must require operator review.

#### Preview

The preview should show:

* requested identifier;
* canonical identifier;
* provider;
* title and subtitle;
* creators and roles;
* publisher and imprint;
* publication date;
* language;
* edition statement;
* proposed format;
* external subjects;
* external list price and currency;
* proposed image;
* fields that remain unresolved;
* provider or mapping warnings.

#### Creation policy

On acceptance, ShelfStack creates:

* one Product;
* one standard Product Variant;
* creator records or creator links as permitted;
* optional image and subject-source records only when Gate 8g policy permits;
* one `catalog_enrichment_events` row for the successful create.

Creation must occur in one database transaction. The enrichment event commits in that same transaction. A preview or rejected result creates no business provenance event.

The external provider call occurs before the database transaction.

#### Operational-field policy

External metadata may suggest but must not silently determine:

* inventory-tracking mode;
* sellable;
* purchasable;
* status;
* regular selling price;
* department override;
* tax-category override;
* merchandise-class override;
* returnability;
* discountability;
* vendor source.

Store defaults and operator confirmation remain authoritative.

#### Default safety

A newly imported product should not become ordinarily sellable until all required sale-eligibility values resolve.

The creation workflow may use existing configured defaults, but must visibly show:

* which values are explicit;
* which values are inherited;
* which required values remain missing;
* whether the standard variant is currently sale eligible.

#### Exit criteria

* A valid ISBN can create one complete Product and standard Variant.
* An existing canonical product is detected before creation.
* Concurrent duplicate creation is safely rejected or redirected.
* Provider failures create no product records.
* Product and Variant are not partially created.
* External list price is never treated as the store regular price.
* Product creation creates no inventory movement.
* Imported operational fields require explicit operator confirmation.

---

### 8d — Product summary hub

**Priority:** Must
**Purpose:** Provide one staff-shaped view of a product without collapsing domain ownership.

The product summary should be a navigable operational surface, not a dump of database fields.

#### Summary sections

##### Identity

* title;
* subtitle;
* canonical identifier;
* alternate identifier;
* product type;
* format;
* status;
* publisher or manufacturer;
* imprint or brand;
* publication or release date;
* language;
* edition;
* creators;
* image or thumbnail;
* identifier warnings.

##### Standard item

* SKU;
* item name;
* status;
* selling price;
* tracking mode;
* sellable;
* purchasable;
* effective merchandise class;
* effective department;
* effective tax category;
* return and discount settings;
* sale-eligibility result.

##### Stock

For the selected store:

* on hand;
* reserved;
* unavailable;
* available;
* on order;
* last received;
* moving-average cost where authorized;
* link to inventory detail;
* units by status when individually tracked.

##### Purchasing and demand

* active vendor sources;
* preferred vendor;
* vendor item codes;
* expected costs where authorized;
* open purchase orders;
* recent receipts;
* open product requests;
* customer-request commitments;
* links to the owning workflows.

#### Store context

Product identity is organization-wide, but inventory, demand, purchase orders, receipts, and some sourcing information are store-specific.

The summary must therefore display an explicit store context.

The primary operational view uses the selected Store.

An optional all-accessible-Stores table may supplement the selected-Store view, but it does not replace it. Any aggregate or cross-Store quantity must be explicitly labeled, and inaccessible Stores must not appear.

The interface must not display an unlabeled organization-wide stock number as though it belonged to one store.

#### Effective values

The summary should show the effective value and its source.

Example:

```text
Department: Books
Source: Merchandise class → Books / Fiction / Mystery

Tax category: Physical Book
Source: Department → Books

Tracking mode: Quantity
Source: Standard item
```

Source labels:

* Item override;
* Product override;
* Merchandise-class default;
* Department default;
* Store rule;
* Missing.

The summary must use the same application-level resolvers used by sale eligibility and POS completion.

It must not independently reproduce inheritance logic in view helpers.

#### Exit criteria

* Staff can understand the product’s current operational state from one screen.
* Store-specific values are clearly scoped.
* Effective classifications match the operational resolver.
* Missing sale-eligibility inputs are visible.
* Inventory and purchasing data are read from their owning domains.
* Catalog screens do not mutate inventory.

---

### 8e — Vendor-source linking workflow

**Priority:** Should
**Purpose:** Make an existing item orderable without navigating several unrelated screens.

#### Scope

From the product or item workflow, authorized users should be able to:

* search and select an existing vendor;
* create or update a variant-vendor source;
* enter vendor item code;
* enter vendor identifier;
* enter list cost;
* enter discount;
* derive or enter expected net cost;
* mark a preferred source;
* set minimum order quantity;
* set order multiple;
* set returnability where supported;
* see last ordered and last received dates;
* deactivate a source.

#### Rules

* The source must link to the Product Variant used for purchasing.
* Duplicate active links for the same variant and vendor are not allowed.
* A publisher string must not automatically create a Vendor.
* Vendor creation remains a separately authorized action.
* Imported publisher metadata may help search for a vendor but does not establish that the publisher is the supplying vendor.
* Product setup must not require a vendor source unless the item is being made purchasable through a workflow that requires one.

#### Exit criteria

* A standard item can be linked to an existing vendor from the product workflow.
* Duplicate source links are prevented.
* Publisher import does not create vendors.
* Cost access remains permission-controlled.
* The workflow respects current purchasing-domain ownership.

---

### 8f — Enrich existing product

**Priority:** Should
**Purpose:** Apply selected bibliographic improvements without overwriting ShelfStack operational decisions.

#### Workflow

```text
open existing product
→ resolve canonical identifier
→ query provider
→ normalize result
→ compare proposed and current values
→ show field-level diff
→ choose apply mode
→ validate protected fields
→ apply selected changes
→ record catalog_enrichment_events in the same transaction
```

A preview or rejected result creates no business provenance event.

#### Apply modes

Initial modes:

* **Fill empty fields only**
* **Apply selected fields**

A broad “replace all” action should not be included in v1.

#### Field categories

##### ShelfStack identity fields

Never provider-managed:

* Product Variant SKU;
* Inventory Unit identifier;
* internal record IDs;
* generated sequence information.

##### Canonical product identifier

* Used for lookup and matching.
* Not replaced through ordinary enrichment after operational use.
* Correction requires a separate controlled identifier-correction workflow.

##### Operational controls

Protected from automatic import:

* tracking mode;
* Product or Variant status;
* sellable;
* purchasable;
* regular selling price;
* department override;
* tax-category override;
* merchandise-class override;
* discountability;
* returnability;
* return policy;
* availability dates unless explicitly selected and supported.

##### Bibliographic metadata

May be suggested and selectively applied:

* title;
* subtitle;
* description;
* publisher string;
* imprint string;
* publication date;
* language;
* edition;
* creators;
* images;
* external subjects;
* external list price.

#### External list price

External list price:

* remains product-level bibliographic or manufacturer metadata;
* retains currency context where available;
* does not replace Variant regular selling price;
* may apply when currency matches the organization currency, or when currency is null (null treated as assume organization currency, shown in preview).

#### Operational-use protection

Whether a product identifier is operationally used must be determined by an application service.

Relevant use may include references from:

* purchase-order lines;
* receipts;
* inventory records;
* Product Requests;
* completed POS lines;
* immutable snapshots or posted records.

The user interface must not determine operational use through an incomplete ad hoc query.

#### Exit criteria

* Current and proposed values are shown side by side.
* No field changes merely because the provider was queried.
* Fill-empty mode changes only empty eligible fields.
* Selected mode changes only the fields selected by the operator.
* Protected fields remain unchanged.
* Imported changes retain provider, user, time, and applied-field evidence.
* Enrichment creates no inventory ledger entry.

---

### 8g — Optional catalog enrichment extensions

**Priority:** Nice
**Purpose:** Add useful enrichment that can ship independently after the core gates.

#### 8g.1 Images and thumbnails

Initial external-image support stores source references and attribution metadata. It does not permanently copy provider image binaries unless the applicable provider policy expressly permits local storage.

Persist `product_images` source rows only when the adapter image-use policy is `remote_display_permitted` or `local_storage_permitted`. Policies `preview_only`, `unsupported`, or uncertain rights create no image row.

Supported metadata:

* source provider;
* source URL;
* external record identifier;
* attribution;
* retrieved timestamp;
* image position.

Do not copy externally sourced binaries into Active Storage by default. Local storage of provider binaries requires provider-specific confirmation that policy is `local_storage_permitted`. Staff-uploaded images are a separate source type and are not introduced by default in Gate 8g.

Google Books images must not be copied permanently in Phase 8.

Image failure must not block product creation.

#### 8g.2 External subjects

External provider subjects are retained separately from ShelfStack merchandise-class assignment as descriptive source metadata, not operational classification.

```text
product_external_subjects
- id, product_id, taxonomy, external_code, external_label, provider, position, timestamps
```

#### 8g.3 BISAC-to-merchandise-class mapping

External subject mappings connect an organization-scoped taxonomy and external code to one existing Merchandise Class:

```text
external_subject_mappings
- id, organization_id, taxonomy, external_code, merchandise_class_id, active, timestamps
```

Unique active mapping per `(organization_id, taxonomy, external_code)`.

Rules:

* mappings suggest an existing merchandise class;
* applying a mapped class requires operator acceptance;
* adding or changing a mapping does not automatically reclassify existing Products;
* unmapped subjects remain unresolved;
* the system does not automatically create merchandise classes;
* several subject matches may require operator selection;
* the mapping does not create a parallel display hierarchy;
* manual ShelfStack classification remains authoritative.

#### 8g.4 Catalog data-quality views

Potential views:

* products with identifier warnings;
* possible duplicate identifiers;
* products missing format;
* products missing merchandise class;
* products missing effective department;
* products missing effective tax category;
* sellable variants missing price;
* inactive products with active inventory;
* products with failed or incomplete enrichment.

These views may ship incrementally and are not required for the core 8a–8d exit.

---

## 7. Creator implementation contract

Phase 8 introduces an organization-owned `Creator` master and an ordered `ProductCreator` join.

Binding detail and rationale: [phase-08-catalog-refinement-and-enrichment-v1.md](../decisions/phase-08-catalog-refinement-and-enrichment-v1.md) (OD-P8-02).

### Schema

```text
creators
- id
- organization_id
- display_name
- normalized_name
- sort_name
- active
- created_at
- updated_at
```

```text
product_creators
- id
- product_id
- creator_id
- role
- credited_as
- position
- created_at
- updated_at
```

`normalized_name` is indexed but not unique. Different Creators may share a normalized name.

### Initial roles

Controlled string allowlist (no admin control-master table in Phase 8):

```text
author editor illustrator translator narrator photographer contributor
```

### Matching behavior

* Normalize names for search and match suggestions.
* Exact normalized-name match → suggest that Creator.
* Several exact matches or other ambiguity → require operator selection.
* When no acceptable match exists, an authorized import may create a new Creator.
* Name matching is advisory; do not merge Creators solely because normalized names match.
* Duplicate Creators are acceptable in v1.
* Same Creator and role on one Product uses soft validation (not a hard unique database constraint).
* Perfect identity reconciliation is not a Phase 8 requirement.

### Ordering and credit

* Preserve provider contributor order.
* Preserve role.
* `credited_as` may retain edition-specific presentation.
* Do not introduce a general `primary` Boolean unless a concrete workflow requires it.

Authorized create-from-ISBN may create missing Creator rows in the same transaction as Product and Variant. Any failure rolls back the complete creation.

Creator merging remains deferred data-quality work.

---

## 8. Import provenance and audit

Phase 8 uses a dedicated append-only `catalog_enrichment_events` table (OD-P8-09). Ordinary application logs alone are not sufficient business provenance.

Actions:

```text
create | fill_empty | selected_apply
```

ShelfStack must retain enough evidence to answer:

* which provider supplied the data;
* which provider record or identifier was used;
* when the data was retrieved;
* which user applied it;
* which Product was affected;
* which action was performed;
* which fields were applied;
* which warnings were accepted.

The event is committed atomically with the associated Product / Variant / Creator / subject / image changes. A preview or rejected result creates no business provenance event.

Events are immutable. Later edits create new enrichment events or ordinary catalog audit records.

Do not retain complete raw provider payloads as permanent business evidence. Short-lived debugging retention, if any, must not expose credentials or unnecessary personal data.

---

## 9. Permissions

A proposed Phase 8 permission set is:

```text
catalog.lookup_external
catalog.create_from_enrichment
catalog.enrich_product
catalog.replace_enriched_fields
catalog.manage_creators
catalog.manage_product_images
catalog.link_vendor_source
catalog.review_data_quality
```

Existing permissions may be reused where they express the same capability clearly.

### Permission principles

* Viewing external suggestions does not automatically permit applying them.
* Creating products from enrichment requires ordinary product-creation authority.
* Replacing non-empty metadata may require more authority than filling empty fields.
* Correcting an operationally used canonical identifier remains a separate elevated action.
* Viewing vendor cost continues to require cost-view permission.
* Vendor creation and vendor-source linking may use distinct permissions.
* Provider credentials are administratively configured and are not exposed to ordinary catalog users.

---

## 10. Service boundaries

Phase 8 should prefer application services for multi-record and provider workflows.

Candidate services include:

```text
Catalog::NormalizeIdentifier
Catalog::FindExistingProduct
Catalog::LookupExternalMetadata
Catalog::NormalizeEnrichmentResult
Catalog::MapProductFormat
Catalog::SuggestMerchandiseClass
Catalog::PreviewProductImport
Catalog::CreateFromEnrichment
Catalog::PreviewProductEnrichment
Catalog::ApplyProductEnrichment
Catalog::ResolveEffectiveValues
Catalog::BuildProductSummary
Catalog::LinkVendorSource
```

Names are illustrative rather than prescriptive.

### Required separation

* Provider adapters fetch and normalize external data.
* Preview services prepare proposed changes.
* Persistence services create or update ShelfStack records.
* Effective-value resolvers provide authoritative inherited values.
* Inventory, purchasing, and demand queries remain read-only from catalog summary services.
* Controllers coordinate workflows but do not contain provider mapping or cross-domain business rules.

---

## 11. Required data and schema changes

Phase 8b adds the accepted minimum bibliographic Product fields (OD-P8-10):

* `publication_date`;
* `publication_date_precision` (`year` | `month` | `day` when present);
* `language_code`;
* `edition_statement`.

Phase 8 also introduces:

* `creators`;
* `product_creators`;
* `catalog_enrichment_events`.

Optional Gate 8g may introduce:

* `product_images`;
* `product_external_subjects`;
* `external_subject_mappings`.

Do not add fields merely because one provider returns them. Do not create first-class Product columns for page count, dimensions, series, Dewey/LCC, reviews, provider IDs, or similar provider-specific attributes without a concrete new requirement.

Provider-specific fields remain in adapters or related source tables rather than becoming Product columns without broader meaning. UI may label `name` as **Title**; do not rename the column.

---

## 12. Product summary read model

The hub may use a query object, presenter, or read model to aggregate:

* Product;
* standard Product Variant;
* effective classification;
* sale eligibility;
* selected-store Stock Balance;
* Inventory Units when applicable;
* active Inventory Reservations summary;
* Product Requests;
* Product Variant Vendors;
* open Purchase Order lines;
* recent Receipt lines.

This read aggregation creates no new ownership.

The summary should favor:

* current state;
* concise warnings;
* links to owning records;
* limited recent history;
* expandable detail.

It should not attempt to reproduce every historical transaction on the Product page.

---

## 13. Testing requirements

### 13.1 Identifier and duplicate behavior

Test:

* valid ISBN-10 normalization to ISBN-13;
* invalid ISBN-10 warning or rejection behavior;
* canonical ISBN-13 lookup;
* equivalent identifier lookup where supported;
* existing-product detection;
* duplicate database constraint;
* concurrent create attempts;
* provider response with conflicting identifier.

### 13.2 Provider behavior

Test:

* successful lookup;
* no result;
* incomplete result;
* invalid credentials;
* timeout;
* rate limiting;
* malformed provider response;
* operator-selected secondary provider when enabled;
* no automatic multi-provider fallback;
* safe credential handling;
* no partial records after failure.

### 13.3 Create-from-ISBN

Test:

* Product and standard Variant created atomically;
* creator links created in order;
* ambiguous creator matching;
* ambiguous format mapping;
* unresolved classification;
* imported list price kept separate from selling price;
* sellability not silently enabled;
* no inventory ledger entry;
* effective-value warnings shown.

### 13.4 Enrich existing

Test:

* preview performs no writes;
* fill-empty changes only blank eligible fields;
* selected apply changes only selected fields;
* protected fields remain unchanged;
* operational identifier remains protected;
* provider and user provenance retained on `catalog_enrichment_events`;
* preview creates no enrichment event;
* creator additions retain role and order;
* failed apply rolls back all changes including provenance;
* enrichment creates no inventory movement.

### 13.5 Product hub

Test:

* selected-Store stock isolation;
* all-accessible-Stores breakdown when implemented;
* no unauthorized Stores in cross-store views;
* unlabeled cross-store aggregates rejected;
* effective values match central resolver;
* authorization of cost display;
* Product Request and PO links are correctly scoped;
* individually tracked units appear only when applicable;
* inactive or missing configuration warnings are visible;
* completed historical facts are not recalculated.

### 13.6 Shared controls

Test:

* organization and store scoping;
* keyboard navigation;
* nested labels;
* active-record filtering;
* unauthorized create actions hidden and rejected server-side;
* no-JavaScript or failed-JavaScript fallback where required;
* accessible labels and focus behavior.

---

## 14. Phase exit criteria

### 14.1 Core Phase 8 exit

Phase 8 core is complete when Gates 8a–8d are implemented, their exit criteria are satisfied, and the resulting work is accepted.

Required outcomes:

* shared linking controls are available;
* provider-neutral enrichment infrastructure exists with ISBNdb as the primary adapter;
* Creators are represented and linkable through the shared picker;
* a valid ISBN can create one reviewed Product and standard Variant;
* existing products are detected before create;
* provider failure creates no partial records;
* operational fields are protected;
* successful creates and applies write `catalog_enrichment_events` atomically;
* the product hub provides selected-Store context as the primary view;
* effective values and their sources are visible;
* catalog changes create no inventory effects;
* tests cover provider failure, duplicates, protected fields, and store isolation.

### 14.2 Phase closure

Phase 8 is closed when Gates 8e and 8f are either:

* implemented and accepted; or
* explicitly moved to the Deferred Work Register with a named future target.

Optional Gate 8g never blocks Phase 8 closure. Unimplemented 8g items may be:

* completed later;
* moved to the Deferred Work Register;
* assigned to a later catalog-hardening phase.

No optional gate should keep the core phase indefinitely open.

---

## 15. Multi-variant follow-on (Phase 8.5)

Multi-variant support is desirable but is not part of the Phase 8 core.

Treat it as a separate Phase 8.5 named-variant implementation:

```text
Phase 8.5 — Minimal Multi-Variant Enablement
```

### Accepted direction

OD-P8-07 accepts the following direction for Phase 8.5:

* `single` and `named` variant structures;
* several staff-named Variants under one Product;
* no option dimensions or variant matrices;
* exact Variant resolution from Variant SKU;
* operator selection when a Product identifier resolves several eligible Variants;
* no silent default Variant selection.

Phase 8.5 still requires a short cross-domain implementation packet before schema unlock or code. That packet must cover POS selection, vendor-source, Product Request, stock-summary, receiving, migration of current products, tracking-mode defaults, and related cross-domain behavior.

### Minimum migration concept

Current products migrate unchanged:

```text
existing Product
└── existing standard Product Variant
```

Phase 8.5 may later:

* remove the unique index on `product_variants.product_id`;
* relax the `variant_structure = single` constraint;
* permit several named variants.

Those schema changes must not occur until the Phase 8.5 cross-domain packet is accepted.

---

## 16. Decision disposition

**Disposition:** OD-P8-01 through OD-P8-10 are dispositioned in [open-decisions.md](../open-decisions.md). Binding rules: [phase-08-catalog-refinement-and-enrichment-v1.md](../decisions/phase-08-catalog-refinement-and-enrichment-v1.md).

| ID | Decision | Status | Needed for |
| --- | --- | --- | --- |
| OD-P8-01 | Enrichment overwrite / protect-field / operational-use | accepted | 8b, 8c, 8f |
| OD-P8-02 | Creator master and join | accepted | 8b, 8c |
| OD-P8-03 | Image model and provider rights | accepted (v1) | 8g |
| OD-P8-04 | Provider order, credentials, failure | accepted | 8b, 8c |
| OD-P8-05 | BISAC / external-subject mapping | accepted | 8g |
| OD-P8-06 | Publisher/manufacturer party model | deferred | later |
| OD-P8-07 | Named multi-variant direction | accepted; delivery → Phase 8.5 | 8.5 |
| OD-P8-08 | Product-summary store context | accepted | 8d |
| OD-P8-09 | Import provenance (`catalog_enrichment_events`) | accepted | 8b–8f |
| OD-P8-10 | Minimum bibliographic Product fields | accepted | 8b, 8c |

### Before Gate 8b

Required decisions for core gates are accepted (01, 02, 04, 08, 09, 10). Optional 8g decisions (03, 05) are also accepted early. OD-P8-06 remains deferred. OD-P8-07 is accepted directionally with delivery in Phase 8.5 and does not block Phase 8 core.

---

## 17. Out of scope

The following remain deferred unless separately promoted through the Deferred Work Register and an accepted phase plan:

* product merge;
* canonical identifier correction after operational use;
* full creator deduplication;
* authority-file integration;
* full publisher or party master;
* full ONIX ingest;
* frontlist campaigns;
* automated catalog refresh;
* provider-driven automatic overwrites;
* store-specific pricing;
* customer reviews;
* ecommerce publishing;
* inventory counts;
* transfers;
* complete RTV;
* buyback;
* customer CRM;
* loyalty;
* accounting exports;
* EDI;
* offline POS;
* physical shelf-location inventory ownership;
* full options or variant matrix support.

---

## 18. Documentation updates

The Phase 8 implementation should update, as applicable:

* `docs/implementation/roadmap.md`;
* `docs/implementation/current-phase.md`;
* `docs/implementation/deferred-work-register.md`;
* `docs/implementation/open-decisions.md`;
* `docs/domains/catalog-and-products.md`;
* `docs/domains/classification-and-configuration.md`;
* `docs/service-catalog.md`;
* `docs/glossary.md`;
* design-system documentation for shared record pickers;
* permissions documentation;
* schema reconciliation exports;
* route and interface documentation.

Accepted durable decisions should move into:

* an ADR;
* a domain specification;
* an architectural lock;
* or a Phase 8 decision note,

rather than remaining only in the phase plan.

---

## 19. Implementation sequence

1. Deliver Gate 8a shared record-picker infrastructure.
2. Deliver Gate 8b schema and provider foundation (including Creator model and Creator search-to-link).
3. Deliver Gate 8c create-from-ISBN.
4. Deliver Gate 8d Product summary hub.
5. Evaluate and schedule Gates 8e and 8f (or move them to the Deferred Work Register with a named target).
6. Record unimplemented Gate 8g items in the Deferred Work Register as needed.
7. Keep DWR-021 multi-variant targeted to Phase 8.5 (cross-domain packet before code); DWR-024 publisher party deferred.
8. Create GitHub issues only for accepted, branch-sized gate work.
