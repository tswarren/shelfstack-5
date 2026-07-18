# Proposed changes to `docs/domains/authorization-permissions.md`

**Phase 3 interim policy.** Numeric authority precedence remains open under OD-009 / OD-013.

## Permission keys

Clarify:

| Key | Description | Phase |
| --- | --- | --- |
| `inventory.adjustment.post` | Post opening and quantity-only adjustments | 3 |

Add:

| Key | Description | Scope | Phase | Approvals | Audit |
| --- | --- | --- | --- | --- | --- |
| `inventory.cost_correction.post` | Post inventory cost corrections | store | 3 | yes (Phase 3 interim: always) | yes |
| `inventory.cost_correction.approve` | Approve inventory cost corrections | store | 3 | is the Approval permission | yes |

Do not use `inventory.adjustment.post` alone to post cost corrections.

## Phase 3 authority policy

Until the full authority-precedence model is implemented:

* ordinary opening and quantity-only posts use `inventory.adjustment.post`;
* cost corrections use `inventory.cost_correction.post`;
* **all cost corrections require an independent Approval** in Phase 3;
* numeric self-authority limits (`maximum_inventory_cost_correction_*`) are deferred.

This is easier to enforce correctly than introducing authority keys whose default chain is not ready.

## Open decision

Whether `inventory.cost.view` is required to create a draft that captures cost. Do not assume that browsing inventory valuation and entering an opening cost are the same capability.

## After seeding new permissions

Existing installs need `bin/rails shelfstack:sync_admin_permissions` (see [bootstrap-and-seed.md](../implementation/bootstrap-and-seed.md)).
