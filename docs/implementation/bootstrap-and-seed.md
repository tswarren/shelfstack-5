# Bootstrap and seed

**Status:** Operational reference  
**Purpose:** Document the three-layer seed lifecycle, bootstrap environment variables, INV-ORG-001 behavior, and administrator permission sync

For day-to-day Docker and host commands, see the Development setup section in [`README.md`](../../README.md). Canonical CSV seed inputs are described in [`docs/exports/README.md`](../exports/README.md).

## Seed layers

ShelfStack separates installation data into three explicit layers:

| Layer | Command | Owns |
| --- | --- | --- |
| 1. Permissions | `bin/rails db:seed` | Canonical permission definitions only |
| 2. Bootstrap | `bin/rails shelfstack:bootstrap` | Organization, store, administrator role/user/membership; development POS device and cash drawer |
| 3. Reference data | `bin/rails shelfstack:seed_reference_data` | Identifier sequences and organization-owned classification/catalog CSV masters |

Do not load organization-owned CSV masters from bare `db:seed`. Reference data requires an organization created by bootstrap.

`bin/setup` runs all three layers after preparing the database:

```text
db:prepare
→ db:seed
→ shelfstack:bootstrap
→ shelfstack:seed_reference_data
```

When `--reset` is passed (intentional database reset / new install), setup also runs `shelfstack:sync_admin_permissions` after bootstrap. Routine setup does **not** sync administrator permissions, so intentionally removed Administrator grants are not restored. After pulling changes that introduce new permission keys, run the sync task explicitly.

Inside Docker:

```bash
./dev/rails-docker bin/setup --skip-server
```

Or the individual tasks:

```bash
./dev/rails-docker bin/rails db:seed
./dev/rails-docker bin/rails shelfstack:bootstrap
./dev/rails-docker bin/rails shelfstack:seed_reference_data
```

## Development defaults

In development and test, bootstrap uses defaults when environment variables are unset:

```text
Organization code: demo
Organization name: Demo Bookstore
Store code: 001
Store name: Main Street
Username: admin
Password: password123
Timezone: America/New_York
Currency: USD
```

These credentials are development defaults only.

In development, bootstrap also creates register `REG1` and its cash drawer when missing.

## Bootstrap environment variables

Outside development and test, the following are **required**:

| Variable | Purpose |
| --- | --- |
| `SHELFSTACK_BOOTSTRAP_ORG_CODE` | Organization code |
| `SHELFSTACK_BOOTSTRAP_ORG_NAME` | Organization name |
| `SHELFSTACK_BOOTSTRAP_STORE_CODE` | Store code |
| `SHELFSTACK_BOOTSTRAP_STORE_NAME` | Store name |
| `SHELFSTACK_BOOTSTRAP_USERNAME` | Bootstrap administrator username |
| `SHELFSTACK_BOOTSTRAP_PASSWORD` | Bootstrap administrator password |

Optional variables (all environments):

| Variable | Purpose | Default |
| --- | --- | --- |
| `SHELFSTACK_BOOTSTRAP_ORG_LEGAL_NAME` | Legal name | Organization name |
| `SHELFSTACK_BOOTSTRAP_STORE_NUMBER` | Store number | `1` |
| `SHELFSTACK_BOOTSTRAP_TIMEZONE` | Organization/store timezone | `America/New_York` |
| `SHELFSTACK_BOOTSTRAP_CURRENCY` | Default currency code | `USD` |
| `SHELFSTACK_BOOTSTRAP_RESET_PASSWORD` | When `1` in development/test, reset the bootstrap user’s password on re-run | unset |

Do not commit environment overrides that contain real credentials.

## INV-ORG-001 and idempotency

Bootstrap is safe to re-run. It:

* creates missing organization, store, administrator role, user, and membership;
* does **not** reactivate disabled access or clear lockout counters on existing records;
* does **not** restore removed administrator permissions on re-run.

Bootstrap **aborts** if an organization already exists under a different code (INV-ORG-001: one operating organization per installation).

## Administrator permissions

When bootstrap creates the `administrator` role for the first time, it grants every catalog permission present at that moment.

Later permission definitions added by `db:seed` are **not** automatically attached to an existing administrator role. After pulling changes that introduce new permissions, re-grant them with the audited sync task:

```bash
./dev/rails-docker bin/rails shelfstack:sync_admin_permissions
```

Or without Docker:

```bash
bin/rails shelfstack:sync_admin_permissions
```

Requirements:

* an organization must already exist (`shelfstack:bootstrap` first);
* an `administrator` role must exist for that organization;
* an audit actor user must exist — identified by `SHELFSTACK_BOOTSTRAP_USERNAME`, defaulting to `admin` in development/test.

The sync is additive and audited: it grants every catalog permission that is missing, and does not remove existing role-permission assignments.

### Permissions vs numeric authority

Permissions and numeric authority are separate (ADR-0011). Holding `pos.discount.apply` is not enough when the action also checks a membership limit such as `maximum_discount_rate`.

Under the OD-013 interim rule, a **null** membership authority override is treated as **unconfigured** and denies the action (which surfaces as “requires approval” for discounts). Bootstrap therefore sets full administrator membership limits when creating the admin membership, and `shelfstack:sync_admin_permissions` fills any still-null administrator membership limits without overwriting values already configured.

If discounts still require approval after sync, check **Administration → Store memberships** for the admin user and confirm discount rate/amount limits are set (or re-run sync / bootstrap to fill nulls).

## Related files

| Path | Role |
| --- | --- |
| [`db/seeds.rb`](../../db/seeds.rb) | Permissions layer entrypoint |
| [`db/seeds/bootstrap.rb`](../../db/seeds/bootstrap.rb) | Bootstrap implementation |
| [`db/seeds/reference_data.rb`](../../db/seeds/reference_data.rb) | Reference-data layer |
| [`lib/tasks/shelfstack.rake`](../../lib/tasks/shelfstack.rake) | Rake task wrappers |
| [`docs/exports/README.md`](../exports/README.md) | CSV seed inventory |
| [`docs/domains/authorization-permissions.md`](../domains/authorization-permissions.md) | Permission catalog |

## Related documentation

* [Implementation documentation index](README.md)
* [Organization and Authorization](../domains/organization-and-authorization.md)
* [Phase 1 — Organization and authorization](phases/phase-01-organization-and-authorization.md)
* [Phase 2 — Configuration and catalog](phases/phase-02-configuration-and-catalog.md)
