# Design note — future workflow costing (proposed / open)

**Status:** Proposed design exploration  
**Authority:** Not ADR. Not Phase 3. Not automatic domain promotion.  
**Governing constraint from ADR-0013:** Future workflows must preserve carried cost, avoid rewriting completed history, and represent discrepancies explicitly. Detailed algorithms remain open.

## Inter-Store transfers (lifecycle deferred)

Candidate costing rules when designed:

* Transfer out requires physically available stock; must not create negative On Hand.
* Remove source quantity at source carrying cost (moving average or exact Unit).
* Transfer in adds that exact carried value at destination; Store average differences alone create no profit/loss.
* In-transit loss/damage/mismatch becomes an explicit discrepancy or write-off.

## Return to Vendor (lifecycle deferred)

Candidate costing rules when designed:

* RTV holding increases Unavailable only; On Hand and inventory value unchanged.
* RTV shipment removes On Hand and carrying cost; expected Vendor credit is not inventory cost.
* Vendor-credit differences are RTV/purchasing settlement variances, not negative-inventory cost variances.
* Rejected returns reverse at original RTV shipment cost.

## Inventory Counts (lifecycle deferred)

Candidate costing rules when designed:

* Count entry does not change inventory.
* Count posting creates a quantity-only adjustment (`observed − on_hand`).
* Overage does not automatically invoke a Department estimate.
* Correcting a deficit toward zero is not an acquisition-cost variance.

## Receipt corrections (lifecycle deferred)

**Governing rule (ADR-0013):** A posted Receipt correction must divide its effect between current inventory valuation and a separately reported historical cost variance without rewriting completed POS snapshots.

**Allocation algorithm: open.**

Counterfactual replay of all later Store-and-Variant history is one alternative. It is **not** accepted architecture. Other allocation methods may be evaluated when Receipt corrections are designed.

Questions any method must answer:

* interaction with later Receipts, sales, returns, post-voids, transfers, counts, and prior corrections;
* closed or exported accounting periods;
* concurrency with current activity.
