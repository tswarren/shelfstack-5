# ADR-0014: Hybrid Transaction-Component Tax Calculation

**Status:** Accepted  
**Date:** 2026-07-18  
**Closes:** [OD-004](../implementation/open-decisions.md), [OD-005](../implementation/open-decisions.md)

## Context

ShelfStack must calculate sales tax after Discount allocation, support multiple Store Tax Rates and Rules (including taxable fractions and compounding), store historical tax components on completed lines for returns and reporting, and avoid binary floating-point money arithmetic.

Two competing aggregation approaches are common:

* round tax independently on every line (simple, but can systematically over- or under-collect versus a transaction total);
* round once at the transaction and store only a transaction total (accurate collection, but weak line history for linked returns).

Domain documentation already required tax after Discount allocation and that completed line tax components reconcile to the line tax total. OD-004 and OD-005 needed the aggregation, precision, residual-cent, compounding, and effective-date mechanics—not a change to the commercial price → discount → tax sequence.

Official guidance in some jurisdictions supports aggregating same-rate taxable amounts before rounding (for example CRA GST/HST practice and Texas retail-sale aggregation with half-cent-up rounding). Those examples do not establish a universal multi-jurisdiction rule, but they support transaction-level aggregation as a defensible v1 baseline. Jurisdiction-configurable line-level rounding remains deferred.

## Decision

### Hybrid model

Taxability and taxable bases are determined **per line** after Discount allocation. Each tax component is aggregated and rounded **once per transaction tax component and line direction**. The rounded cents are allocated back to contributing lines with the largest-remainder method and stored as completed line tax-component records.

The model is neither purely line-rounded nor stored only as one transaction tax total.

### Commercial sequence

```text
Regular Price
→ approved Selling Price
→ Gross Amount
→ Discount Allocations
→ Taxable Merchandise Amount
→ Tax Components
→ Line Total
```

Taxable merchandise amount for a line is:

```text
gross_amount_cents − tax-reducing discount allocations
```

It is not necessarily identical to `net_amount_cents`. Some future coupon or promotion types may reduce what the customer pays without reducing the taxable base.

Discount records carry an explicit `tax_treatment`:

```text
reduces_taxable_base
does_not_reduce_taxable_base
```

For Phase 4b, ordinary discretionary and promotional discounts default to `reduces_taxable_base`. A discount that does not reduce the taxable base must say so explicitly. Unsupported tax treatments block application rather than silently using the wrong basis.

Transaction-level Discounts are allocated deterministically among eligible lines before tax is calculated (same deterministic residual family as other money allocations; see domain Discount rules).

### Transaction tax component identity

A transaction tax component is normally identified by:

```text
store_tax_rate_id
+ calculation_order
+ compounds_on_prior_tax
+ line direction
```

Rules that share the same `store_tax_rate_id` must use consistent `calculation_order`, `compounds_on_prior_tax`, and receipt code. Validate this at configuration time when practical.

Different Tax Categories may use different taxable fractions while still contributing to the same tax component.

Sale and return directions are calculated separately. Return lines must not change the rounding allocation of sale lines.

Removed lines and Stored-Value lines do not participate in ordinary merchandise tax calculations.

### Arithmetic and precision

* Finalized monetary values are integer cents.
* Intermediate calculations use exact decimal arithmetic (`BigDecimal` or equivalent).
* Binary floating-point arithmetic is prohibited.
* Stored rates and taxable fractions use eight decimal places (`decimal(10,8)`), matching the proforma.
* Intermediate multiplications are not rounded until defined aggregation points.

### Rounding mode

Round half up to the nearest cent:

```text
0.0049 dollars → 0 cents
0.0050 dollars → 1 cent
```

### Taxable-fraction allocation

For each line and component:

```text
exact taxable merchandise cents
= taxable merchandise amount cents × taxable_fraction
```

For each transaction component and direction:

1. sum the exact taxable merchandise cents;
2. round that total half-up to integer cents;
3. allocate those cents to lines using largest remainder.

Allocated values become `pos_line_item_taxes.taxable_amount_cents`.

### Compounding

Components are processed in ascending `calculation_order`, with a stable secondary order such as `store_tax_rate_id`.

* Non-compounding component taxable base = allocated taxable merchandise amount.
* Compounding component (`compounds_on_prior_tax = true`) taxable base = allocated taxable merchandise amount **plus finalized earlier tax-component amounts on that line**.

“Finalized earlier” means the **allocated rounded** prior component amounts already stored for the line, not a second exact pass. Taxable fraction applies to the merchandise amount first; prior compounded taxes are then added in full.

### Tax calculation and residual allocation

For each line and component:

```text
exact tax cents = taxable_amount_cents × rate
```

For each transaction component and direction:

1. sum exact tax across eligible lines;
2. round the component total half-up to integer cents;
3. allocate the rounded cents to lines using largest remainder;
4. store the result in `pos_line_item_taxes.amount_cents`.

Largest-remainder method for positive amounts:

1. take the floor of each exact line share;
2. `residual = rounded component total − sum(floored shares)`;
3. sort lines by fractional remainder descending, then line position ascending, then line ID ascending;
4. add one cent to the first `residual` lines.

Residual cents are not assigned automatically to the last line.

The transaction tax total is the sum of completed `pos_line_item_taxes.amount_cents` with line direction applied. There is no separately calculated transaction tax value that may disagree with stored components. Line tax amount equals the sum of that line’s completed components (INV-TAX-002).

### Effective-date rule

Final tax rules are selected using the **store-local calendar date at transaction completion**, not the Business Day `reporting_date`.

A Business Day may cross midnight while a statutory rate change becomes effective at midnight. Therefore:

* open transactions use currently effective rules for provisional display;
* recall refreshes tax rules;
* completion re-resolves and validates rules;
* if totals change materially, the cashier must review before completion.

### Store Tax Rule treatment and missing configuration

A Tax Category describes what the merchandise is for tax purposes at the Organization level. It does **not** carry a global taxable / zero-rated / exempt status. Actual treatment depends on Store, jurisdiction, effective date, and the applicable Store Tax Rule.

Each Store Tax Rule carries an explicit `treatment`:

```text
taxable
zero_rated
exempt
```

Interpretation:

* `taxable` must reference an effective Store Tax Rate with a nonnegative rate;
* `zero_rated` requires an explicit 0% Store Tax Rate and creates an explicit 0% component row for reporting (`amount_cents = 0`);
* `exempt` creates no collectible tax, retains the treatment snapshot, and may omit `store_tax_rate_id`;
* missing an effective Store Tax Rule for a line’s Tax Category at Completion is a configuration error and completion blocker — not an exemption.

A transaction Tax Exemption is separate from a Store Tax Rule with `treatment = exempt`. It records why an otherwise rule-taxable line or component was exempted for that transaction. Reusable tax-exemption master records remain deferred.

Store Tax Rules include a denormalized `store_id` (in addition to the store implied by `store_tax_rate_id` when present) so overlap constraints and Store-scoped queries remain clear.

### Returns and corrections

* Linked returns reverse exact stored original taxable amount, rate, component amount, Tax Category, receipt code, and related Discount allocation—they do not recalculate current tax.
* Post-voids reverse all original tax components exactly.
* Unlinked returns use their approved refund and tax basis and must not pretend to reproduce original tax unless original values are verified.

### Initial scope and deferred capabilities

Initial implementation supports **tax-exclusive** prices.

Deferred:

* tax-inclusive pricing;
* jurisdiction-configurable line-level rounding as an alternate mode.

### Schema expectations

`store_tax_rules` include at least:

```text
store_id
tax_category_id
store_tax_rate_id   # required for taxable and zero_rated; nullable for exempt
component_code      # equals rate.code when rate present; required for exempt
treatment           # taxable | zero_rated | exempt
taxable_fraction
calculation_order
compounds_on_prior_tax
effective_from / effective_to
```

Completed `pos_line_item_taxes` retain enough snapshots to explain the result, including at least:

```text
store_tax_rule_id
store_tax_rate_id
tax_category_id
treatment_snapshot
receipt_code_snapshot
position
taxable_amount_cents
taxable_fraction_snapshot
rate
compounds_on_prior_tax_snapshot
amount_cents
```

`pos_discounts` include `tax_treatment` as above.

Effective periods must not overlap for the same `(store_id, tax_category_id, component_code)`. See [phase-04-tax-schema.md](../implementation/phase-04-tax-schema.md).

Exact column names may follow schema documentation; the snapshots and behaviors above are required.

## Consequences

### Positive

* Line-level tax history supports linked returns and reporting.
* Transaction-component rounding avoids systematic multi-line over-collection from independent line rounding.
* Compounding, fractions, and ordered components fit the Classification proforma.
* Fail-closed missing rules prevent silent under-collection.
* Separation of tax effective date from Business Day reporting date preserves OD-001 without forcing midnight-crossing rate errors.

### Negative / costs

* Tax services are more complex than per-line rounding.
* Configuration must keep component identity consistent across rules sharing a rate.
* Provisional displayed tax may change between open and complete when rules or prices change.

### Constraints

* Do not invent competing residual policies in Phase 4b code.
* Do not use Business Day `reporting_date` to select tax rules.
* Do not recalculate tax for linked returns or post-voids from current rules.
* Do not treat missing Store Tax Rules as exemption.

## Alternatives considered

### Round every line independently

Rejected for v1 because small lines at the same rate can over-collect versus a single aggregated calculation (for example three $0.05 lines at 13% yielding three cents line-rounded versus two cents aggregated).

### Store only a transaction tax total

Rejected because linked returns and line reporting require historical per-line components.

### Assign residual cents to the last line

Rejected because it concentrates arbitrary pennies on an arbitrary line and is less stable under line reordering than largest remainder with explicit tie-breaks.

### Use Business Day reporting date for tax rule selection

Rejected because reporting date answers an operating-period reporting question, not statutory rate effective date at completion.

## Governing rules

* Tax follows Discount allocation; taxable merchandise amount uses only tax-reducing Discount allocations.
* Hybrid line resolution + transaction-component rounding + largest-remainder allocation.
* Exact decimal intermediate math; integer cents for finalized money; no binary floats.
* Round half up only at defined taxable-base and tax-component aggregation points.
* Components process in ascending calculation order; compounding uses finalized prior line component amounts.
* Sale and return directions are separate rounding pools.
* Effective tax rules use store-local calendar date at completion.
* Store Tax Rule `treatment` determines taxable, zero-rated, or exempt handling; Tax Category does not.
* Missing effective Store Tax Rules for a line’s Tax Category block completion.
* Linked returns and post-voids reverse stored tax components exactly.
* Transaction tax totals are derived only from stored line components.

## Related domains

* Classification and Configuration
* Point of Sale
* Reporting and Reconciliation

## Related ADRs

* [ADR-0008: Keep Completed POS Transactions Immutable and Use Explicit Corrections](0008-immutable-pos-transactions.md)
* [ADR-0009: Complete POS Transactions Atomically and Idempotently](0009-atomic-idempotent-pos-completion.md)
* [ADR-0010: Distinguish Business Days, Sessions, Devices, Drawers, and Z Reports](0010-business-days-sessions-and-z-reports.md)
* [ADR-0011: Separate Permissions, Numeric Authority, and Approval Events](0011-permissions-authority-and-approvals.md)
