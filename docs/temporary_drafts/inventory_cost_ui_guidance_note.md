# Design note — inventory cost UI (proposed / open)

**Status:** Proposed UI guidance  
**Authority:** Not ADR. Implementation may evolve if the following rules are preserved.

## Governing presentation rules

* Never display unknown cost as `$0.00`.
* Confirmed zero cost may display as `$0.00` with quality shown.
* Users without `inventory.cost.view` should not see blank or masked cost amounts; hide cost columns and related actions.
* Amount and quality must remain distinguishable; do not rely on color alone.

## Suggested (non-binding) presentation

Stock lists may show On Hand, average cost, inventory value, and cost quality for authorized users.

Negative On Hand should separate:

* inventory asset value (`$0.00`);
* outstanding deficit quantity;
* provisional deficit cost when implemented.

Estimated values may expose Department, regular price used, margin assumption, and posting time when those snapshots exist.

Mixed cost may initially display as mixed without inventing a percentage split from the aggregate alone.
