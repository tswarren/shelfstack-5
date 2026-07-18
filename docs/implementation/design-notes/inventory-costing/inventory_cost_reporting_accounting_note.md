# Design note — inventory cost reporting and accounting (proposed / open)

**Status:** Proposed design exploration  
**Authority:** Not ADR. Not Phase 3. Accounting integration remains open in Reporting Domain.

## What Inventory must preserve for later export

Variance and cost facts should retain at least:

* amount;
* posting / settlement period;
* Department attribution;
* origin reference;
* resolution source;
* cost quality (actual / estimated / mixed / unknown).

## What remains open for Accounting / Reporting design

* whether a deficit-clearing account is used;
* whether a dedicated cost-variance account is used;
* journal timing and batch protocol;
* account precedence;
* how unknown-cost catch-up is classified externally;
* whether Department-level GL codes are sufficient.

## Not Phase 3

Do not add Department fields such as:

```text
inventory_deficit_clearing_gl_account_code
inventory_cost_variance_gl_account_code
```

until Accounting/Reporting design accepts them.

## Illustrative journal patterns (not accepted)

Earlier exploration sketched debit/credit patterns for negative sales, deficit settlement, and unknown catch-up. Those patterns are retained only as discussion material and must not be treated as governing until Reporting settles accounting integration.
