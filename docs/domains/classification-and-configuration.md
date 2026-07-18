# Classification and Configuration Domain

**Status:** Consolidated specification  
**Domain owner:** Shared classifications, policies, reasons, and Store configuration

## Governing ADRs

- [ADR-0003: Use One Merchandise-Class Hierarchy with Department Defaults](../adr/0003-merchandise-classes-and-departments.md)
- [ADR-0011: Separate Permissions, Numeric Authority, and Approval Events](../adr/0011-permissions-authority-and-approvals.md)
- [ADR-0013: Govern Quantity-Tracked Inventory Cost Through Moving Weighted Average and Explicit Cost Provenance](../adr/0013-govern-quantity-tracked-inventory-cost.md)

## Purpose

This domain owns controlled structures that categorize merchandise and govern operational behavior.

| Concept | Purpose |
|---|---|
| Product Type | Describes what kind of Product it is |
| Merchandise Class | Hierarchical merchandising, shelving, browsing, buyer organization, and default Department resolution |
| Department | Broad financial and managerial reporting and selling-policy defaults |
| Tax Category | Describes an item for tax treatment |
| Store Tax Rule | Applies effective Store-specific tax calculation |
| Return Policy | Defines return eligibility and handling rules |
| Tender Type | Defines permitted settlement behavior |
| Reason records | Explain controlled exceptions and corrections |
| Accounting mapping | Future mapping of posted events to external accounts |

## Ownership boundary

### Owns

- Merchandise Class hierarchy;
- Department;
- Tax Category;
- Store Tax Rate;
- Store Tax Rule;
- Return Policy;
- Return Reason;
- Discount Reason;
- Inventory Adjustment Reason;
- Price-Override Reason;
- Cancellation Reason;
- Post-Void Reason;
- Tender Type;
- Cash-Movement Type;
- Store operating configuration;
- future accounting configuration.

### References but does not own

- Products and Product Variants;
- Inventory-Tracking Mode;
- Store inventory;
- completed POS tax components;
- completed transaction classifications;
- Tenders;
- reports.

## Merchandise Classes

ShelfStack uses one hierarchy rather than separate Merchandise Class and Display Category hierarchies.

Suggested attributes:

- Organization;
- stable code;
- name;
- parent;
- level or depth;
- description;
- default Department;
- optional used-merchandise Department default;
- shelving guidance;
- merchandising notes;
- reporting position;
- active status.

Suggested conceptual levels:

```text
primary
secondary
minor
```

The parent-child structure remains authoritative. Temporary placements such as Front Table, Staff Picks, or Cashwrap are not Merchandise Classes when they describe short-term presentation.

## Departments

A Department is the broad financial and managerial classification attached to completed merchandise and service lines.

Suggested attributes:

- Organization;
- stable code;
- name and description;
- optional parent;
- default Tax Category;
- default Return Policy;
- maximum merchandise Discount;
- optional `default_cost_estimation_margin_bps` (Organization-level estimation policy);
- future accounting mappings;
- active status;
- reporting order.

Department resolution follows the applicable Catalog precedence. A completed ordinary POS Line Item must resolve one Department.

Department must not determine Inventory-Tracking Mode.

### Cost estimation policy

A Department may define an optional Organization-level default gross-margin assumption for estimating inventory cost when no more authoritative cost is available.

- Express as basis points of gross margin, not markup (`0`–`10_000`).
- The estimate is Classification policy, not actual acquisition cost.
- The Department does not own Product-Variant cost.
- Inventory owns calculation and posting; Classification owns the margin field.

Suggested field (schema when implemented):

```text
default_cost_estimation_margin_bps   optional integer
```

Canonical calculation (owned by Receiving and Inventory Domain):

```text
estimated_unit_cost_cents
=
round_half_up(
  regular_price_cents
  × (10,000 - margin_bps)
  / 10,000
)
```

Rules enforced at Inventory posting:

- Catalog regular selling price required; temporary discounts/promotions not used;
- user must explicitly confirm the estimate;
- price, margin, Department, and result are snapshotted;
- calculated zero is estimated confirmed-zero, not unknown;
- missing margin or price means estimate unavailable, not zero;
- user may leave cost unknown;
- later Department or Catalog price changes do not recalculate posted estimates.

Store-specific estimation policy may later override the Organization Department default through an effective-dated configuration model. Do not design that table in Phase 3.

Deficit-clearing and cost-variance GL fields remain deferred until Accounting/Reporting design accepts them.

## Product Types

Suggested initial values:

```text
book
recorded_music
video
periodical
game
stationery
gift
cafe
service
other
```

Product Type may guide data-entry forms, search, imports, and metadata presentation. It does not directly determine tax, inventory tracking, Department, Discount, or Return Policy.

## Tax configuration

### Tax Category

Describes what is being sold for tax purposes.

Examples may include printed books, periodicals, prepared food, packaged food, general merchandise, services, exempt merchandise, and Stored-Value issuance.

### Store Tax Rate

Defines an effective-dated jurisdictional percentage.

Suggested attributes include Store, code, name, jurisdiction, rate, effective period, receipt code, and active status.

### Store Tax Rule

Connects Store, Tax Category, Store Tax Rate, taxable fraction, calculation order, compounding behavior, and effective period.

Rates require fixed precision. Completed POS activity stores historical tax components.

## Policy and reason records

### Return Policy

May define return window, receipt requirements, permitted refund methods, Condition requirements, default Return Disposition, and Approval requirements.

Detailed behavior remains partly Open.

### Reason records

Controlled reasons should be used where business review or audit requires a stable explanation.

Reason types include Discount, Price Override, line removal, Cancellation, Customer Return, Post-Void, cash movement, Inventory Adjustment, and manual Stored-Value adjustment.

Inventory Adjustment Reasons are scoped by `adjustment_kind` (`opening_inventory`, `quantity_only`, `cost_correction`) with immutable `code` values. Posted Adjustments snapshot reason code and name; `requires_note` is enforced at post, not merely when saving a draft.

## Tender Types

A Tender Type defines payment and refund eligibility, over-tender behavior, change behavior, required references, status, and reporting category.

Suggested categories:

```text
cash
card
check
stored_value
other
```

Tender Type does not determine revenue classification.

## Effective-value resolution

Typical precedence:

```text
Product-Variant override
→ Product override
→ Merchandise-Class default
→ Department or Store fallback where explicitly defined
→ blocker
```

Each value uses its own documented chain.

## Workflows

### Create or reorganize Merchandise Class

1. Select or create parent.
2. Assign code and name.
3. Assign default Department where appropriate.
4. Validate hierarchy.
5. Activate.
6. Reclassify current Products explicitly.
7. Preserve completed snapshots.

### Change Store tax rule

1. Create a new effective-dated rule.
2. Validate overlap and calculation order.
3. Leave completed tax components unchanged.
4. Apply only to applicable future calculations.
5. Audit the change.

## Permissions

```text
classification.view
classification.manage_merchandise_classes
classification.manage_departments
classification.manage_tax_categories
classification.manage_store_tax_rules
classification.manage_return_policies
classification.manage_reasons
classification.manage_tender_types
classification.manage_store_configuration
classification.manage_accounting_mappings
classification.override_defaults
```

## Audit requirements

Audit Merchandise-Class changes, Department changes, default changes, Tax Category and Store Tax Rule changes, Return Policy changes, Tender-Type changes, reason-record changes, Store configuration changes, and accounting-mapping changes.

## Invariants

- Merchandise Class and Department remain distinct.
- A separate Display Category hierarchy is not accepted.
- Department does not determine Inventory-Tracking Mode.
- A department used as an active merchandise-class default (`default_department` or `default_used_department`) must remain postable; clear or reassign those defaults before making the department reporting-only (`postable = false`).
- Temporary placement does not change inventory ownership.
- Product Type remains descriptive.
- Tax Category is distinct from Tax Rate.
- Completed lines snapshot classifications and tax components.
- Current classification changes do not rewrite history.
- Tender Type does not define revenue.
- Department gross-margin defaults are estimation policy only, not actual acquisition cost.

## Open questions

- Departments are hierarchical with `postable` (OD-012 accepted). Reporting-only parents use `postable = false`.
- May a Product have several simultaneous Merchandise-Class assignments?
- How should temporary merchandising placements be represented?
- Which defaults belong to Merchandise Class?
- What is the final Return Policy structure?
- Which accounting mappings are required?
- Should Department or accounting mapping vary by Store?
