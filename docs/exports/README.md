# Export seed examples

Bookstore-shaped **canonical reference data** for a ShelfStack installation. These CSVs are planning and seed inputs for Phase 2 classification/catalog masters—not the proforma schema (see [`schema/README.md`](schema/README.md)).

## Seed lifecycle

Organization-scoped masters load **after** bootstrap creates the organization:

```text
bin/rails db:seed                         # permissions only
bin/rails shelfstack:bootstrap            # org / store / admin
bin/rails shelfstack:seed_reference_data  # these files (Phase 2+)
```

Do not load organization-owned CSVs from bare `db:seed`.

## Import-ready files

One row ≈ one database record. Stable `code` values; suitable for idempotent import.

| File | Entity |
| --- | --- |
| [`tax_categories.csv`](tax_categories.csv) | Tax categories |
| [`departments.csv`](departments.csv) | Departments (hierarchy, GL defaults, tax category) |
| [`return_policies.csv`](return_policies.csv) | Return policies |
| [`return_reasons.csv`](return_reasons.csv) | Return reasons |
| [`discount_reasons.csv`](discount_reasons.csv) | Discount reasons |
| [`product_formats.csv`](product_formats.csv) | Product formats |
| [`product_conditions.csv`](product_conditions.csv) | Product conditions (used-copy ladder) |
| [`merchandise_classes.csv`](merchandise_classes.csv) | Merchandise-class **nodes** (path-qualified codes) |

## Source-only files

Not for direct import. Used to regenerate canonical merchandise classes:

| File | Role |
| --- | --- |
| [`sources/merchandise_categories_leaf.csv`](sources/merchandise_categories_leaf.csv) | Denormalized leaf rows with primary/secondary/minor codes and department defaults |
| [`sources/merchandise_classes_leaf_sort.csv`](sources/merchandise_classes_leaf_sort.csv) | Original sort order for leaf rows |
| [`sources/merchandise_class_default_overrides.csv`](sources/merchandise_class_default_overrides.csv) | Explicit parent default-department overrides when descendants conflict |

Regenerate [`merchandise_classes.csv`](merchandise_classes.csv):

```bash
ruby script/build_merchandise_classes.rb
```

## Format family note

Each format has exactly one `format_family`. When a physical item could span families, the primary family is chosen for merchandising defaults (e.g. bookmark → `stationery`).

## Related

- [Phase 2 — Configuration and catalog](../implementation/phases/phase-02-configuration-and-catalog.md)
- [Classification domain](../domains/classification-and-configuration.md)
- [ADR-0003](../adr/0003-merchandise-classes-and-departments.md)
