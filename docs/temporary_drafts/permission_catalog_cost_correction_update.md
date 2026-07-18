# Proposed changes to `docs/domains/authorization-permissions.md`

Companion drafts:

* [ADR-0013 draft](0013-govern-quantity-tracked-inventory-cost.md)
* [Receiving and Inventory domain update](receiving_inventory_domain_update.md)

Aligns with ADR-0011: permissions, numeric authority, and Approval remain separate.

---

## Inventory permission table updates

Keep:

```text
inventory.adjustment.create
inventory.adjustment.post
inventory.cost.view
```

Clarify `inventory.adjustment.post`:

| Key | Description | Scope | Phase | Authority | Approvals | Audit |
| --- | --- | --- | --- | --- | --- | --- |
| `inventory.adjustment.post` | Post opening and quantity-only adjustments | store | 3 | — | yes when policy requires | yes |

Add:

| Key | Description | Scope | Phase | Authority | Approvals | Audit |
| --- | --- | --- | --- | --- | --- | --- |
| `inventory.cost_correction.post` | Post inventory cost corrections | store | 3 | amount and rate limits | yes when mandatory conditions apply | yes |
| `inventory.cost_correction.approve` | Approve inventory cost corrections | store | 3 | approver amount and rate limits | is the Approval permission | yes |

Do not use `inventory.adjustment.post` alone to post cost corrections.

---

## Evaluation rules

### Create draft adjustment

Requires:

```text
inventory.adjustment.create
inventory.cost.view
```

when the draft displays or captures cost.

### Post opening or quantity-only adjustment

Requires:

```text
inventory.adjustment.post
```

### Post cost correction

Requires:

```text
inventory.cost_correction.post
```

and sufficient numeric authority.

### Approve cost correction

Requires:

```text
inventory.cost_correction.approve
```

and sufficient approver authority. The approver authenticates with their own credentials (ADR-0011).

---

## Authority keys

Add authority dimensions (home table TBD pending OD-009 / OD-013):

```text
maximum_inventory_cost_correction_cents
maximum_inventory_cost_correction_rate_bps
```

Requested amount:

```text
abs(inventory_value_delta_cents)
```

Requested rate when current positive inventory value is known and nonzero:

```text
abs(inventory_value_delta_cents) × 10,000 / current inventory value
```

The requester must be within **both** configured limits when the rate is evaluable.

Until the full authority-precedence chain is implemented, an unconfigured limit fails closed (deny / require Approval path as designed — do not treat null as unlimited).

Do not place universal dollar or percentage defaults in ADR-0013. Values are operating configuration.

---

## Approval is always required when

* either numeric limit is exceeded;
* current inventory value is unknown, so the relative change cannot be evaluated;
* cost quality is changed from `actual` to `estimated` or `unknown`;
* a correction introduces or increases unknown cost;
* a manual correction changes provisional deficit state;
* the affected accounting period is already reconciled or otherwise closed;
* store policy marks the reason as approval-required.

System-calculated `inventory_cost_variances` created by ordinary Receipt (or other triggering-workflow) settlement do not require a separate cost-correction Approval. The permission governing the triggering workflow applies. A later manual override of that variance requires the cost-correction path.

---

## Seed / bootstrap note

After these permissions are added to `db:seed`, existing installations need:

```bash
bin/rails shelfstack:sync_admin_permissions
```

See [bootstrap-and-seed.md](../implementation/bootstrap-and-seed.md).
