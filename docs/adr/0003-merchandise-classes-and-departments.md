# ADR-0003: Use One Merchandise-Class Hierarchy with Department Defaults

**Status:** Accepted

## Context

ShelfStack previously distinguished:

* display categories, describing customer-facing merchandising;  
* merchandise classes, describing operational defaults;  
* departments, describing financial classification.

In practice, the proposed display-category hierarchy and merchandise-class hierarchy substantially overlapped.

Both were intended to classify merchandise into structures such as:

```
Books
└── Nonfiction
    └── History
```

Maintaining two separate hierarchical classifications would create:

* duplicated administration;  
* competing product assignments;  
* unclear reporting;  
* inconsistent defaults;  
* uncertainty over which hierarchy drives shelving and purchasing.

Departments remain separately necessary because financial posting and operational policy do not always follow the same level of merchandising detail.

## Decision

ShelfStack will use one hierarchical merchandise-class structure for:

* merchandising;  
* shelving;  
* browsing;  
* merchandise reporting;  
* buyer organization;  
* default department resolution.

The separate display-category hierarchy will be removed.

A merchandise class may contain:

* code;  
* name;  
* parent;  
* hierarchy level;  
* default department;  
* shelving guidance;  
* merchandising notes;  
* reporting order;  
* activation status.

Suggested hierarchy levels are:

```
primary
secondary
minor
```

The exact number of levels may remain configurable through parent-child relationships.

## Department responsibility

A merchandise class normally points to a default department.

The department supplies financial and selling-policy defaults such as:

* general-ledger account mappings;  
* tax category;  
* return policy;  
* maximum merchandise discount;  
* financial reporting classification;  
* other department-level policy defaults.

The normal resolution is:

```
Variant override
→ Product override
→ Merchandise-class default department
→ Department defaults
```

## Explicit attributes that do not belong to the department

The following remain explicit elsewhere:

| Attribute | Owner |
| :---- | :---- |
| Product identity | Product |
| Product type | Product |
| Format | Product |
| Variant SKU | Product variant |
| Inventory-tracking mode | Product variant |
| Regular selling price | Product variant or pricing service |
| Exact-copy condition | Inventory unit |
| Exact-copy cost | Inventory unit |
| Vendor sourcing | Variant-vendor relationship |
| Current store quantity | Inventory domain |

A department must not determine inventory-tracking mode.

The same department may include:

* quantity-tracked merchandise;  
* individually tracked merchandise;  
* non-inventory services.

## Used merchandise defaults

The initial implementation may allow a merchandise class to specify:

* a default department;  
* a default used-merchandise department.

This is an interim convenience.

If ShelfStack later needs different department defaults for several merchandise classes or behaviors, it may introduce a generalized mapping such as:

```
merchandise_class
+ operational category
→ department
```

## Consequences

### Benefits

* Eliminates overlapping classification hierarchies.  
* Simplifies catalog maintenance.  
* Aligns shelving, browsing, and category reporting.  
* Preserves separate financial departments.  
* Allows departments to remain broad and stable while merchandise classes remain detailed.  
* Provides a clear default chain.

### Costs

* Existing display-category references must be migrated.  
* Merchandise classes must support both merchandising and reporting needs.  
* Some products may need explicit department overrides.  
* Temporary displays such as Staff Picks or Front Table require a different mechanism.

## Temporary merchandising placements

Temporary placements do not become merchandise classes when they describe short-term presentation rather than product identity.

Examples include:

* Front Table;  
* Staff Picks;  
* Cashwrap;  
* Bargain Display;  
* Seasonal Feature.

These may later use optional placement or promotional metadata.

They do not change inventory ownership or financial department.

## Alternatives considered

### Retain separate display categories and merchandise classes

Rejected because the conceptual overlap did not justify the administrative complexity.

### Use departments as the complete merchandising hierarchy

Rejected because departments should remain financially meaningful and relatively stable.

### Assign all operational behavior to merchandise class

Rejected because tracking mode, price, cost, and other behavior belong to more specific records.

## Governing rules

* Products are classified through one merchandise-class hierarchy.  
* Merchandise classes may resolve a default department.  
* Departments remain separate financial and policy records.  
* Department defaults may be overridden where explicitly supported.  
* Temporary display placement does not change merchandise classification or inventory ownership.

## Related domains

* Classification and Configuration  
* Catalog and Products  
* Point of Sale  
* Reporting and Reconciliation