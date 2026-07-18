# Proposed changes to `docs/domains/receiving-and-inventory.md`

Companion drafts:

* [ADR-0013 draft](0013-govern-quantity-tracked-inventory-cost.md)
* [Catalog cost interaction](catalog_cost_interaction_update.md)
* [Classification estimation and GL](classification_cost_estimation_update.md)
* [Permission catalog cost corrections](permission_catalog_cost_correction_update.md)

---

## Governing ADR addition

Add:

```markdown
- [ADR-0013: Govern Quantity-Tracked Inventory Cost Through Moving Weighted Average and Explicit Cost Provenance](../adr/0013-govern-quantity-tracked-inventory-cost.md)
```

---

## Replace `## Stock Balance` with

## Stock Balance

One Stock Balance exists per Store and quantity-tracked Product Variant.

It represents the current physical quantity, availability quantities, and current quantity-tracked valuation state.

Suggested attributes:

* Store;
* Product Variant;
* On Hand;
* Reserved;
* Unavailable;
* optional cached Available;
* `inventory_value_cents` — aggregate positive inventory asset value;
* `moving_average_cost_cents` — cached rounded convenience average;
* `cost_quality`;
* `last_known_unit_cost_cents`;
* `last_known_cost_quality`;
* `deficit_costed_quantity`;
* `provisional_deficit_cost_cents`;
* `provisional_deficit_cost_quality`;
* concurrency / lock version;
* last received timestamp.

```text
available = on_hand - reserved - unavailable
deficit_quantity = max(-on_hand, 0)
unknown_deficit_quantity = deficit_quantity - deficit_costed_quantity
```

Do not store a duplicate `deficit_quantity` column.

### Authority of value fields

```text
Inventory Ledger Entries
→ authoritative history

Stock Balance
→ authoritative current operational state
→ reconcilable from history
```

`inventory_value_cents` is the authoritative **current projection** for positive valuation calculations. Posted Inventory Ledger Entries remain the historical explanation. A reconciliation process may replay posted entries and compare the result with the balance. A mismatch is an operational error requiring investigation, not an invitation to overwrite the ledger.

`moving_average_cost_cents` is a cached, rounded convenience value. Proportional outbound allocation uses `inventory_value_cents` and positive On Hand, not the cached unit average.

### Balance constraints

```text
on_hand <= 0
→ inventory_value_cents = 0
→ moving_average_cost_cents is null

on_hand > 0 and cost_quality = unknown
→ inventory_value_cents is null
→ moving_average_cost_cents is null

on_hand > 0 and cost_quality != unknown
→ inventory_value_cents is not null

0 <= deficit_costed_quantity <= max(-on_hand, 0)

deficit_costed_quantity = 0
→ provisional_deficit_cost_cents = 0
```

A positive balance with explicitly established zero cost has:

```text
inventory_value_cents = 0
cost_quality = actual
```

It is not `unknown`.

Every cost-bearing posting locks the applicable Stock Balance, creates ledger and related variance records as needed, and updates the balance atomically.

Inventory Ledger Entries explain quantity and valuation changes. Inventory Reservation records explain Reserved quantity.

---

## Replace `## Inventory Ledger` with

## Inventory Movements and Inventory Ledger

Only posted Inventory Movements change On Hand.

An Inventory Ledger Entry is the persisted record of a posted Inventory Movement. Posted entries form an append-only inventory ledger.

Illustrative movement types include:

```text
opening_inventory
quantity_adjustment
cost_correction
receipt
sale
customer_return
post_void
transfer_out
transfer_in
rtv_shipment
discard
correction
```

This list does not establish the workflow or lifecycle of Receipts, transfers, Returns to Vendor, Inventory Counts, or other movement sources. Those workflows remain governed separately. Their costing behavior is specified in this domain under ADR-0013.

### Cost-bearing fields

Each cost-bearing Inventory Movement retains enough information to reproduce:

* Store;
* Product Variant;
* optional Inventory Unit;
* `movement_type`;
* `quantity_delta`;
* `inventory_value_delta_cents` — signed change to positive inventory asset;
* `unit_cost_cents`;
* `movement_cost_cents` — nonnegative extended cost associated with the quantity moved;
* `cost_method`;
* `cost_quality`;
* `cost_finality`;
* source record;
* reversal or correction reference;
* resulting On Hand;
* resulting inventory value;
* resulting moving-average cost where applicable;
* Department attribution;
* estimation inputs where applicable;
* posting key;
* User;
* posting time;
* reason.

`movement_cost_cents` and `inventory_value_delta_cents` can differ. Example: a sale into negative inventory may have provisional COGS (`movement_cost_cents > 0`) while `inventory_value_delta_cents = 0` because it does not create a negative inventory asset.

Posting an Inventory Movement, updating its Stock Balance, and creating related `inventory_cost_variances` occur in one atomic transaction.

The posting operation must be idempotent. Retrying the same source event must not create duplicate quantity, valuation, or variance effects.

---

## Add `## Inventory Cost Variances`

## Inventory Cost Variances

Represent cost differences that do not change physical quantity through related records:

```text
inventory_cost_variances
```

Do not overload Inventory Movements to represent these variances.

A negative-inventory cost variance:

* does not change On Hand;
* does not create or remove positive inventory asset value;
* may link one incoming movement to several prior deficit-origin movements;
* reports in the settlement period;
* may use different accounting mapping from inventory asset changes;
* preserves attribution to both the historical movement and the resolving event.

Suggested fields:

| Field | Purpose |
| --- | --- |
| `store_id` | Store scope |
| `product_variant_id` | Costed Variant |
| `variance_type` | Why the variance exists |
| `origin_ledger_entry_id` | Earlier movement whose cost was provisional or incorrect |
| `trigger_ledger_entry_id` | Later movement or correction resolving the difference |
| `quantity` | Quantity being reconciled |
| `provisional_cost_cents` | Previously assigned extended cost |
| `resolved_cost_cents` | Later established extended cost |
| `variance_cents` | `resolved - provisional` |
| `cost_quality` | Actual, estimated, mixed, or unknown |
| `department_id` | Historical accounting/reporting attribution |
| `posted_by_user_id` | Posting identity |
| `posted_at` | Reporting period |
| `reason` | Explanation |

Recommended variance types:

```text
negative_inventory_settlement
receipt_cost_correction
manual_cost_resolution
```

An RTV-credit difference is an RTV or purchasing settlement variance, not an `inventory_cost_variances` negative-inventory settlement.

---

## Replace `## Cost` with

## Cost

### Costing scope

Quantity-tracked Product Variants and individually tracked Inventory Units use different cost models.

Quantity-tracked merchandise uses a Store-and-Variant moving weighted average.

Individually tracked merchandise retains acquisition cost on each exact Inventory Unit and does not participate in quantity moving-average calculations.

Catalog owns Inventory-Tracking Mode and regular selling price. Receiving and Inventory owns posted cost, Stock Balances, and ledger effects.

### Cost method, quality, and finality

ShelfStack distinguishes:

* how a cost was calculated (`cost_method`);
* how authoritative that cost is (`cost_quality`);
* whether the amount is settled (`cost_finality`).

Recommended `cost_method` values:

```text
moving_weighted_average
inventory_unit_acquisition
original_completed_line
explicit_actual
department_margin_estimate
retained_cost_rate
unknown
```

Future additions may include `vendor_expected_cost` and `receipt_actual_cost`.

Recommended `cost_quality` values:

```text
actual
estimated
mixed
unknown
```

Recommended `cost_finality` values:

```text
final
provisional
unresolved
```

Example:

```text
method = retained_cost_rate
quality = estimated
finality = provisional
```

Persistence uses ordinary string columns with application validation and database check constraints. Avoid native PostgreSQL enums.

A cost amount of zero means zero cost was explicitly established.

A missing cost amount means cost is unknown.

UI and reports must never present unknown cost as `$0.00`.

### Aggregate inventory value

For quantity-tracked inventory, aggregate inventory value is authoritative when the complete positive balance has known or estimated cost.

When On Hand is positive and valued:

```text
moving average
=
aggregate inventory value
/
on-hand quantity
```

The displayed unit average may be rounded, but outbound allocation must use aggregate value so that rounding does not accumulate across movements.

When positive inventory includes unresolved unknown-cost quantity:

* complete aggregate inventory value is unknown;
* moving-average cost is unknown;
* reports must not present partially known value as complete valuation;
* later known-cost inventory does not silently assign cost to the unresolved quantity;
* an explicit cost correction may establish a complete valuation.

### Positive-cost inbound movement

For an inbound quantity with an applicable unit cost:

```text
incoming value
=
incoming quantity
× incoming unit cost
```

When existing On Hand is positive and valued:

```text
resulting quantity = existing quantity + incoming quantity
resulting inventory value = existing inventory value + incoming value
resulting moving average = resulting inventory value / resulting quantity
```

Combining actual-cost and estimated-cost inventory normally produces mixed cost quality.

### Outbound movement from positive inventory

For an outbound quantity that does not exceed positive On Hand:

```text
allocated outbound value
=
round_half_up(
  existing inventory value
  × outbound quantity
  / existing on-hand quantity
)
```

```text
resulting inventory value
=
existing inventory value
- allocated outbound value
```

When the outbound movement consumes all remaining positive quantity, it receives all remaining aggregate inventory value.

This rule applies to any physical outbound movement. It does not define the operational lifecycle of the workflow that created that movement.

### Outbound movement crossing into negative On Hand

When an outbound movement exceeds positive On Hand:

1. the positive portion consumes all remaining positive inventory value;
2. the excess portion creates or increases an inventory deficit;
3. the deficit portion receives a provisional issue cost when a defensible retained cost is available;
4. otherwise, deficit cost remains unknown;
5. positive inventory value becomes zero.

The provisional rate is normally the most recent applicable known or estimated moving-average / retained unit cost for that Store and Product Variant (`last_known_unit_cost_cents` when available).

A provisional cost is historical costing state. It does not create a negative inventory asset.

### Negative-inventory cost pool

Negative quantity may be associated with a provisional deficit-cost pool.

The Stock Balance caches:

* `deficit_costed_quantity`;
* `provisional_deficit_cost_cents`;
* `provisional_deficit_cost_quality`.

Immutable detail remains on deficit-origin ledger entries and related settlement / variance records. Do not derive deficit state from the entire movement history during every posting.

### Deficit settlement order

Settle outstanding deficit-origin movements in deterministic FIFO order:

```text
posted_at
then ledger-entry ID
```

This is reconciliation order for outstanding negative movements. It is **not** physical FIFO inventory costing.

FIFO settlement preserves:

* original Department attribution;
* original POS or other source;
* actual versus estimated provenance;
* which historical movement a later variance corrects;
* deterministic partial settlement.

When only part of a deficit is settled, allocate against the oldest outstanding deficit-origin movements first. The final settlement of a movement receives any remaining cent residual for that movement.

### Incoming quantity against negative On Hand

Incoming quantity settles existing negative On Hand before creating positive inventory.

```text
deficit quantity = max(-existing on hand, 0)
settlement quantity = min(incoming quantity, deficit quantity)
surplus quantity = incoming quantity - settlement quantity
```

For each settled origin movement portion:

```text
cost variance
=
settlement cost for that portion
- provisional cost for that portion
```

The variance:

* is posted when the settling cost becomes known or estimated;
* does not change On Hand;
* does not create inventory asset value;
* does not rewrite earlier completed activity;
* retains Store, Product Variant, origin and trigger ledger entries, cost quality, User, and posting time;
* is separately reportable from current inventory value.

#### Partial deficit settlement

When incoming quantity only partially offsets the deficit:

* On Hand remains negative;
* positive inventory value remains zero;
* oldest outstanding deficit-origin movements are settled first;
* the Stock Balance aggregate deficit cache is reduced;
* settled portions create `inventory_cost_variances` where both costs are available;
* remaining deficit retains its remaining provisional or unknown cost state.

#### Exact deficit settlement

When incoming quantity brings On Hand exactly to zero:

* positive inventory value remains zero;
* the deficit-cost pool is fully settled;
* any final cost variances and cent residuals are posted;
* no moving-average cost exists for a zero positive balance, although the most recent rate may be retained for provisional costing.

#### Crossing from negative to positive

When incoming quantity exceeds the deficit:

* the settlement portion resolves the deficit and posts variances as applicable;
* the settlement portion does not create positive inventory value;
* only the surplus quantity creates positive inventory value;
* the surplus uses the incoming unit cost;
* the resulting moving average is based on the positive surplus.

Example:

```text
Before movement:
on hand = -2
provisional deficit cost = $20.00

Incoming:
3 units at $12.00
incoming value = $36.00

Deficit settlement:
2 units at $12.00 = $24.00
provisional cost settled = $20.00
cost variance = $4.00

Positive surplus:
1 unit
inventory value = $12.00
moving-average cost = $12.00
```

The cost of the earlier outbound movement remains unchanged.

### Unknown settling cost

If incoming quantity settles a deficit but its cost is unknown:

* quantity settlement still occurs;
* positive inventory value remains zero unless separately valued surplus exists;
* the related cost variance remains unresolved;
* later authoritative or estimated cost posts an explicit variance correction;
* ShelfStack does not assume zero cost.

### Opening inventory

An `opening_inventory` adjustment establishes physical quantity without requiring a Receipt.

Each opening line records quantity; known actual, explicit estimated, or unknown cost; cost quality; estimation inputs where applicable; reason; and posting identity and time.

When opening inventory is posted into an existing positive balance, the normal positive inbound formula applies.

When no cost is available:

* quantity may still be established;
* current valuation remains unknown;
* the condition appears in missing-cost reporting.

Opening inventory does not imply a Vendor acquisition or create a Receipt.

### Department-based cost estimate

When no more authoritative cost is available, ShelfStack may offer an estimate based on an effective Department gross-margin assumption. The regular selling price comes from Catalog. The margin assumption comes from Classification.

```text
estimated unit cost
=
round_half_up(
  regular selling price
  × (10,000 - gross-margin basis points)
  / 10,000
)
```

The estimate uses the effective regular selling price, excluding transaction discounts, coupons, temporary promotions, temporary markdowns, and employee or membership discounts.

The posted Inventory Movement snapshots:

* the regular selling price used;
* the gross-margin rate used;
* the resolved Department;
* the resulting estimated unit cost;
* estimated cost quality;
* posting or authorizing identity.

The user may reject the estimate and leave cost unknown.

Later changes to Department configuration or Product-Variant price do not recalculate posted estimates.

Cost-source precedence follows ADR-0013. Store-level estimation overrides are future Classification policy records and are out of Phase 3.

### Quantity-only adjustments

A `quantity_only` adjustment changes quantity without accepting an arbitrary replacement cost.

When current positive inventory has a known or estimated moving average:

* added quantity uses the current moving-average rate;
* removed quantity receives an allocated share of current aggregate value.

When On Hand is zero or negative:

* a retained provisional rate may be used;
* otherwise the adjustment carries unknown cost;
* quantity added toward zero settles the operational deficit without creating an acquisition-cost variance;
* any quantity crossing into positive On Hand uses the retained rate when available;
* otherwise the positive balance remains unknown-cost inventory.

Quantity-only adjustments must not be used to impose a new valuation rate.

### Cost corrections

A `cost_correction` changes valuation or resolves cost state without disguising the change as quantity movement.

For positive On Hand, it may:

* establish a previously unknown complete inventory value;
* replace an estimated valuation with a documented actual valuation;
* correct an erroneous aggregate value.

A positive-balance cost correction posts:

```text
quantity delta = 0
inventory-value delta = corrected value - previous value
```

For zero or negative On Hand, a correction may resolve provisional or unknown deficit cost, but it must post as a variance or deficit-cost correction. It must not create positive inventory asset value.

Cost corrections require:

* `inventory.cost_correction.post`;
* sufficient numeric authority (amount and, when evaluable, relative rate);
* an independent Approval when mandatory (see permission catalog draft);
* an audit reason;
* previous and resulting cost state;
* cost method, quality, and finality;
* posting User and timestamp.

Cost corrections do not rewrite earlier Inventory Movements or completed POS lines.

### Customer returns

A linked customer return restores the cost snapshotted on the original completed sale line.

It does not use the current moving average.

A partial return receives a proportional share of the original extended cost. The final return of the remaining quantity receives any original residual cents.

If the return:

* enters a positive balance, its restored value participates in the moving average;
* settles negative On Hand, the negative-inventory settlement and variance rules apply.

An unlinked return without authoritative historical cost uses explicit actual cost, an approved estimate, or unknown cost.

### Post-voids

A post-void reverses the original completed transaction’s quantity and cost effects using the original snapshots.

It does not recalculate cost using current inventory, price, Department, or purchasing data.

Restored positive quantity participates in the current moving weighted average.

### Rounding

ShelfStack stores monetary amounts in integer cents.

Unless another accepted ADR establishes a more specific rule:

* rate-based estimates use round-half-up;
* proportional cost allocation uses round-half-up;
* aggregate inventory value remains authoritative;
* the final movement consuming a positive balance receives any remaining valuation residual;
* the final settlement of a deficit-origin movement receives any remaining provisional-cost residual for that movement.

The same posted inputs must produce the same result through every interface and retry.

---

## Add `## Workflow costing rules`

## Workflow costing rules

Full Transfer, RTV, Count, and Receipt-correction document lifecycles remain open. Their costing behavior is settled here.

### Inter-Store transfers

#### Transfer out

* Require physically available stock.
* Do not permit a transfer to create negative On Hand.
* Remove source quantity at the source Store’s current moving-average cost (or exact Unit acquisition cost).
* Snapshot the exact extended cost removed.
* Move the quantity and value into an in-transit state owned by the Transfer.

#### Transfer in

* Add the exact transferred value to the destination Store.
* Recalculate the destination moving average.
* Do not use the destination’s old average as the transfer cost.
* Do not recognize profit, loss, or cost variance merely because Store averages differ.

#### In-transit discrepancies

Loss, damage, rejection, or quantity mismatch creates an explicit transfer discrepancy or write-off. It does not silently change the carried transfer cost.

For individually tracked Units, exact Unit acquisition cost travels with the Unit.

### Return to Vendor

#### RTV holding

Marking stock as awaiting RTV:

* increases Unavailable;
* leaves On Hand unchanged;
* leaves inventory value unchanged.

#### RTV shipment

When merchandise physically leaves:

* reduce On Hand;
* remove quantity-tracked value at current moving average;
* remove individual Units at exact acquisition cost;
* prevent shipment beyond physically present RTV quantity.

The expected Vendor credit is not inventory cost.

#### Vendor credit difference

A difference between inventory carrying cost and Vendor credit is an RTV or purchasing settlement variance, not a negative-inventory cost variance.

If the Vendor rejects the return and the merchandise comes back, use a linked reversal at the original RTV shipment cost.

### Inventory Counts

#### Count entry

Recording an observed count does not itself change inventory.

#### Count posting

Post the difference as a quantity-only adjustment:

```text
observed quantity - recorded on hand
```

A shortage removes value at current moving average.

An overage:

* uses the current or retained costing rate when one exists;
* remains unknown-cost inventory when no defensible rate exists;
* does not automatically invoke a Department estimate;
* may be followed by a separate explicit cost correction.

A Count must never silently change the cost rate merely to make its result appear valued.

When a Count corrects negative On Hand toward zero, it resolves a quantity discrepancy. It does not create an acquisition-cost variance because no acquisition event occurred.

### Receipt corrections

#### Draft Receipt

Before posting, correct the draft directly.

#### Posted Receipt

Never edit the posted Receipt or its original Inventory Movement.

Create a linked Receipt correction.

#### Quantity correction

A quantity correction reverses the applicable original Receipt quantity and original unit cost.

If the correction causes negative On Hand, normal deficit rules apply. It must not create a negative inventory asset.

#### Cost correction

A posted Receipt-cost correction may affect:

1. inventory value still represented in current positive stock; and
2. cost already consumed by later outbound movements.

Do not put the entire difference into current Inventory Asset, and do not rewrite historical POS costs.

The correction service should perform a counterfactual replay for the affected Store and Variant from the original Receipt movement forward:

```text
actual posted history
versus
same history using corrected Receipt cost
```

The difference is split into:

```text
current inventory-value adjustment
+
historical cost variance
=
total Receipt-cost correction
```

Post:

* the current-inventory portion as a quantity-zero inventory cost correction;
* the consumed historical portion as `inventory_cost_variances` with type `receipt_cost_correction`;
* no changes to completed POS lines.

Accept this architecturally now. Implementation may wait until Receipt corrections are introduced.

---

## Add `## Accounting export mapping`

## Accounting export mapping

Departments provide GL mapping codes, including:

* inventory asset;
* COGS;
* inventory adjustments / write-downs / shrinkage as already modeled;
* `inventory_deficit_clearing_gl_account_code`;
* `inventory_cost_variance_gl_account_code`.

The variance account normally rolls up to COGS or cost-of-sales reporting.

### Sale into negative inventory

For provisional cost `P`:

```text
Debit   COGS                                P
Credit  Inventory Deficit Clearing         P
```

Do not credit Inventory Asset because no positive inventory asset remains.

### Receipt settling the deficit

If actual settlement cost is `A` and provisional cost was `P`:

```text
Debit   Inventory Deficit Clearing         P
Debit   Inventory Cost Variance             A - P    when A > P
Credit  Inventory Cost Variance             P - A    when A < P
Credit  Receipt/AP Clearing                 A
```

### Receipt quantity exceeding the deficit

The surplus portion posts normally to Inventory Asset. Only the deficit-settlement portion uses clearing and variance accounts.

### Previously unknown deficit cost

When provisional cost was unknown, treat `P = 0` for export reconciliation. The full resolved cost posts as current-period cost catch-up / variance and must be identifiable as unknown-cost catch-up, not an ordinary estimate variance.

### Attribution

Use the Department snapshot from the **origin deficit movement** for COGS, deficit clearing, and cost variance. Use the Receipt/Vendor source for the payable or receipt-clearing side.

### Timing

The variance reports in the period when the resolving Receipt or correction posts. It does not alter the original completed sale period.

External accounting-system batch protocol remains outside this domain decision.

---

## Add `## Cost presentation`

## Cost presentation

For users with `inventory.cost.view`, stock and cost screens show amount, quality, source, and finality explicitly.

Never display unknown cost as `$0.00`. Confirmed zero cost displays as `$0.00` with quality `Actual` (or other established quality).

Users without `inventory.cost.view` must not see blank or masked cost amounts. Hide cost columns and related actions entirely.

Negative inventory displays positive inventory asset value and deficit cost separately:

```text
On Hand: -2
Inventory value: $0.00
Outstanding deficit: 2 units
Provisional deficit cost: $20.00
```

When part of a deficit is unknown:

```text
Costed deficit: 1 unit / $10.00
Unknown-cost deficit: 1 unit
```

Estimated values expose Department, regular price used, margin assumption, estimated unit cost, and posting time.

Mixed cost may initially display as mixed actual and estimated cost. Do not invent a percentage split from the aggregate alone unless it can be derived reliably.

Inventory reports separately surface actual-, estimated-, mixed-, and unknown-valued inventory; provisional deficit cost; unresolved deficit quantity; and cost variances by period. Totals containing estimated or unknown components must be labeled accordingly.

Detailed screen layouts are implementation guidance and may evolve without an ADR change, provided these rules are preserved.

---

## Replace `## Inventory Adjustments` with

## Inventory Adjustments

A posted Inventory Adjustment creates one or more Inventory Movements and corresponding Inventory Ledger Entries.

Suggested header attributes:

* Store;
* adjustment kind;
* status;
* reason;
* creator;
* posting User;
* cancellation or reversal references;
* created and posted timestamps.

Suggested line attributes:

* Product Variant;
* optional Inventory Unit where applicable in a later phase;
* quantity delta;
* explicit cost input where allowed;
* cost method, quality, and finality;
* estimation inputs where applicable;
* reason;
* position.

Initial quantity-tracked adjustment kinds:

```text
opening_inventory
quantity_only
cost_correction
```

Suggested adjustment statuses:

```text
draft
posted
cancelled
```

An opening-inventory adjustment may establish quantity and actual, estimated, or unknown cost.

A quantity-only adjustment changes quantity using the applicable existing costing basis and cannot impose an arbitrary replacement rate.

A cost correction changes valuation or cost state without changing physical quantity and uses the cost-correction permission and authority path.

Posted adjustments are not edited to alter history. Corrections use an explicit correcting or reversing record.

Direct unexplained edits to Stock Balance quantity or valuation are prohibited.

---

## Add to `## Audit requirements`

Audit:

* cost calculation method;
* cost quality;
* cost finality;
* estimate inputs;
* missing-cost conditions;
* confirmed-zero cost;
* aggregate inventory-value changes;
* provisional deficit-cost creation and settlement;
* FIFO deficit settlement attribution;
* negative-inventory cost variances;
* cost corrections and Approvals;
* retained negative-inventory warnings.

---

## Add to `## Invariants`

* Quantity-tracked inventory uses Store-and-Variant moving weighted-average cost.
* Individually tracked Inventory Units retain exact Unit acquisition cost.
* Catalog owns tracking mode and regular price; Inventory owns posted cost and balances.
* Aggregate value on Stock Balance governs positive quantity-tracked valuation calculations.
* Inventory Ledger Entries remain authoritative history.
* Zero or negative On Hand does not carry positive inventory asset value.
* Negative quantity may retain separate provisional deficit cost.
* Deficit settlement uses deterministic FIFO of outstanding deficit-origin movements.
* Incoming quantity settles a deficit before creating positive inventory.
* Negative-inventory cost differences create `inventory_cost_variances` records.
* Missing cost is distinct from confirmed zero cost.
* Cost method, quality, and finality are distinct dimensions.
* Department-based cost is an estimate, not actual acquisition cost.
* Estimate inputs are retained when posted.
* Quantity-only adjustments do not arbitrarily rewrite valuation.
* Cost corrections are explicit, permissioned, and audited.
* Linked returns restore original completed-line cost.
* Post-voids reverse original completed cost.
* Posted cost history is not dynamically recalculated.
* Unknown cost is never presented as zero.

---

## Remove from `## Open questions`

Remove:

```markdown
- How does moving average behave with negative On Hand?
```

This question is resolved only after ADR-0013 is accepted.
