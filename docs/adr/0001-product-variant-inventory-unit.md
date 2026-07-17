# ADR-0001: Separate Product, Product Variant, and Inventory Unit

**Status:** Accepted

## Context

ShelfStack must represent merchandise ranging from interchangeable new books to exact used, signed, collectible, consignment, or otherwise individually tracked copies.

A single generic item record cannot adequately represent all three of the following:

1. the commercial identity recognized by publishers, manufacturers, vendors, and customers;  
2. the exact configuration that is sold, priced, purchased, taxed, and inventoried;  
3. one specific physical copy when individual identity matters.

Previous models risked mixing descriptive metadata, selling configuration, and exact-copy inventory into one record.

That creates problems when:

* one product has several sellable configurations;  
* new and used merchandise require different behavior;  
* one exact copy has its own condition, cost, price, or status;  
* quantity-tracked merchandise would otherwise require one row per physical copy;  
* a barcode must resolve either a product, a variant, or one exact unit.

## Decision

ShelfStack will use the following hierarchy:

```
Product
└── Product Variant
    └── Inventory Unit, when individual tracking is required
```

### Product

A product represents the commercial item.

Examples include:

* a particular book edition;  
* a particular music release;  
* a particular board game package;  
* a greeting-card design;  
* a packaged café item;  
* a service offered by the store.

The product owns relatively stable descriptive and catalog information.

### Product variant

A product variant represents the exact sellable and operational configuration.

The variant is the primary record used for:

* SKU;  
* selling price;  
* purchasing;  
* receiving;  
* store inventory balance;  
* department assignment;  
* merchandise-class assignment;  
* tax-category assignment;  
* return policy;  
* discount eligibility;  
* inventory-tracking mode;  
* POS product lines.

Every sellable product must have at least one variant.

A product without meaningful options receives one standard variant.

### Inventory unit

An inventory unit represents one exact physical copy when the variant uses individual tracking.

It may contain:

* exact-copy identifier;  
* current store;  
* condition;  
* acquisition cost;  
* unit-specific selling price;  
* current availability status;  
* acquisition source;  
* reservation;  
* sale history.

Quantity-tracked merchandise does not receive one inventory-unit record for every physical copy.

## Inventory-tracking modes

Each variant explicitly declares one tracking mode:

```
quantity
individual
none
```

### Quantity

Used when copies are operationally interchangeable.

Inventory is maintained through a store-and-variant balance.

### Individual

Used when the exact physical copy must be identified.

Each physical copy receives an inventory-unit record.

### None

Used for services, fees, and other non-inventory merchandise.

No inventory balance, reservation, or movement is required.

## Consequences

### Benefits

* Clear separation between catalog, selling configuration, and physical copy.  
* Supports both interchangeable and individually tracked stock.  
* Prevents excessive unit-row creation for ordinary merchandise.  
* Allows exact-copy condition, cost, and price.  
* Simplifies POS scan resolution.  
* Provides a consistent purchasing and inventory boundary.

### Costs

* Every sellable product requires at least one variant.  
* Product setup requires careful distinction between product-level and variant-level fields.  
* Exact-copy workflows require additional records and validation.  
* Search results may require variant selection after a product-level match.

## Alternatives considered

### One item table for everything

Rejected because it would mix descriptive identity, operational configuration, and physical-copy state.

### One inventory-unit record for every copy

Rejected because it would create unnecessary volume and operational complexity for interchangeable stock.

### Product directly sold without variants

Rejected because purchasing, pricing, inventory, and POS require one consistent sellable record.

## Governing rules

* Every variant belongs to exactly one product.  
* Every sellable product has at least one variant.  
* Every inventory unit belongs to exactly one individually tracked variant.  
* Inventory tracking is determined by the variant.  
* A quantity-tracked variant does not require inventory-unit records.  
* An individually tracked sale must identify the exact inventory unit.  
* Current catalog changes must not rewrite completed transaction history.

## Related domains

* Catalog and Products  
* Vendors and Purchasing  
* Receiving and Inventory  
* Point of Sale  
* Reporting and Reconciliation