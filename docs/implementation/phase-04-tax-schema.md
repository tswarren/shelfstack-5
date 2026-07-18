# Phase 4 — Tax and POS Commercial Schema Notes

**Status:** Authoritative deltas before Phase 4 tax / 4b migrations  
**Governing:** [ADR-0014](../adr/0014-hybrid-transaction-component-tax-calculation.md), [classification-and-configuration](../domains/classification-and-configuration.md), [point-of-sale](../domains/point-of-sale.md)  
**Related:** Reconciled proforma under [../exports/schema/](../exports/schema/) (update when these deltas land)

Document expected schema refinements relative to the current proforma. Do not invent selected-line exemption application tables in Phase 4b.

## `store_tax_rules` deltas

```text
store_id              FK stores, null: false (denormalized; required even when rate is null)
tax_category_id       FK tax_categories, null: false
store_tax_rate_id     FK store_tax_rates, null: true
component_code        string, null: false   # equals rate.code when rate present; required for exempt
treatment             string, null: false   # taxable | zero_rated | exempt
taxable_fraction      decimal(10,8), null: false, default 1
calculation_order     smallint, null: false, default 0
compounds_on_prior_tax boolean, null: false, default false
effective_from        date
effective_to          date
active                boolean, null: false, default true
timestamps
```

### Treatment and rate nullability

| treatment | `store_tax_rate_id` | Rate value |
| --- | --- | --- |
| `taxable` | required | nonnegative |
| `zero_rated` | required | explicit 0% |
| `exempt` | nullable | no collectible tax |

When `store_tax_rate_id` is present, `store_id` must match the rate’s Store and `component_code` must equal the rate’s `code`.

### Overlap invariant

Effective periods must not overlap for:

```text
(store_id, tax_category_id, component_code)
```

### Not on `tax_categories`

Do **not** add global `taxable` / `zero_rated` / `exempt` status to `tax_categories`. Tax Category remains an Organization-level merchandise descriptor.

## `pos_line_item_taxes` snapshots

In addition to proforma amount/rate/taxable-base fields, retain:

```text
store_tax_rule_id
store_tax_rate_id              # nullable when rule treatment is exempt
tax_category_id
treatment_snapshot             # taxable | zero_rated | exempt
receipt_code_snapshot
position
taxable_amount_cents
taxable_fraction_snapshot
rate                           # nullable when exempt without rate
compounds_on_prior_tax_snapshot
amount_cents
```

## `pos_discounts` delta

```text
tax_treatment    string, null: false
                 # reduces_taxable_base | does_not_reduce_taxable_base
```

Phase 4b ordinary discretionary and promotional discounts default to `reduces_taxable_base`.

## Tax Category override audit on `pos_line_items`

```text
tax_category_overridden_at
tax_category_overridden_by_user_id
tax_category_override_reason
original_tax_category_id
```

Required when the line’s effective Tax Category differs from the catalog- or Department-resolved default via `pos.tax_category.override`.

## `pos_tax_exemptions` coverage

```text
coverage    string, null: false, default whole_transaction
            # Phase 4b allows only: whole_transaction
```

Deferred (do not scaffold in 4b):

```text
selected_lines
selected_tax_components

pos_tax_exemption_applications
- pos_tax_exemption_id
- pos_line_item_id
- store_tax_rate_id or component identity
```

## Related POS enums (introduce full sets at table create)

```text
pos_transactions.status: open | suspended | completed | cancelled
pos_line_items.status:   pending | completed | removed
pos_line_items.line_kind: product | open_ring | stored_value
                          # stored_value inactive until Phase 6
```

Phase 4a services must not transition to `completed`.

## Service boundary (not tables)

```text
Tax::CalculateTransaction      # pure calculation result
Pos::RecalculateTransaction    # persist pending discounts/tax/totals
Pos::CompleteTransaction       # revalidate under lock; finalize
```

## Card tender fields (existing proforma; clarify usage)

Use `pos_tenders.status = authorized` plus:

```text
authorization_code
terminal_reference
authorized_at          # if not already covered by processed_at
requires_reconciliation  # optional boolean for operational queues
```

Do not introduce a separate card-exception table for Phase 4c.
