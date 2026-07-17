# Authorization Permission Catalog

**Status:** Canonical permission-key reference  
**Domain owner:** Organization and Authorization  
**Governing ADR:** [ADR-0011](../adr/0011-permissions-authority-and-approvals.md)  
**Related:** [organization-and-authorization.md](organization-and-authorization.md)

## Purpose

This catalog is the single source of truth for stable permission keys used in seeds, membership evaluation, and application checks.

Domain Specifications may describe capabilities in prose; **keys used in code and seeds must match this catalog**. When a domain list disagrees, update this catalog deliberately and align the domain section.

## Grammar

Prefer a consistent three-part form:

```text
<domain>.<resource>.<action>
```

Examples:

```text
catalog.product.view
catalog.product.create
inventory.adjustment.create
inventory.adjustment.post
pos.transaction.complete
pos.discount.apply
```

Broad capability keys such as `pos.access` are allowed when the resource is the whole surface.

### Permission vs authority vs approval

```text
Permission: pos.discount.apply
Authority: maximum_discount_rate (numeric)
Approval permission: pos.discount.approve
```

Application logic must not hard-code role names.

## Column definitions

| Column | Meaning |
| --- | --- |
| Key | Stable machine-readable string |
| Description | What the capability allows |
| Owning domain | Domain that defines the business meaning |
| Scope | `organization` or `store` |
| Phase | Delivery phase that introduces the key |
| Authority | Related numeric limit key, if any |
| Approvals | Whether another user may approve when authority is insufficient |
| Audit | Whether exercise should be audited beyond normal request logs |
| Notes | Deprecation, replacement, or staging notes |

## Administration

| Key | Description | Scope | Phase | Authority | Approvals | Audit |
| --- | --- | --- | --- | --- | --- | --- |
| `administration.store.view` | View stores | organization | 1 | — | no | no |
| `administration.store.manage` | Create/edit/deactivate stores | organization | 1 | — | no | yes |
| `administration.user.view` | View users | organization | 1 | — | no | no |
| `administration.user.manage` | Create/edit/deactivate users | organization | 1 | — | no | yes |
| `administration.membership.manage` | Manage store memberships and overrides | store | 1 | — | no | yes |
| `administration.role.manage` | Manage roles and role-permission sets | organization | 1 | — | no | yes |
| `administration.permission.manage` | Manage permission definitions (rare) | organization | 1 | — | no | yes |
| `administration.device.manage` | Manage POS devices | store | 1 | — | no | yes |
| `administration.drawer.manage` | Manage cash drawers | store | 1 | — | no | yes |
| `administration.audit.view` | View administrative audit records | organization | 1 | — | no | no |

Legacy names in [organization-and-authorization.md](organization-and-authorization.md) (`administration.view_stores`, etc.) should be treated as superseded by this table when seeding.

## Classification

| Key | Description | Scope | Phase | Authority | Approvals | Audit |
| --- | --- | --- | --- | --- | --- | --- |
| `classification.view` | View classification masters | organization | 2 | — | no | no |
| `classification.merchandise_class.manage` | Manage merchandise classes | organization | 2 | — | no | yes |
| `classification.department.manage` | Manage departments | organization | 2 | — | no | yes |
| `classification.tax_category.manage` | Manage tax categories | organization | 2 | — | no | yes |
| `classification.store_tax_rule.manage` | Manage store tax rates/rules | store | 2 / 4b | — | no | yes |
| `classification.return_policy.manage` | Manage return policies | organization | 2 | — | no | yes |
| `classification.reason.manage` | Manage reason catalogs | organization | 2 | — | no | yes |
| `classification.tender_type.manage` | Manage tender types | organization | 2 | — | no | yes |
| `classification.store_configuration.manage` | Manage store operating settings | store | 2 | — | no | yes |

## Catalog

| Key | Description | Scope | Phase | Authority | Approvals | Audit |
| --- | --- | --- | --- | --- | --- | --- |
| `catalog.product.view` | View products and variants | organization | 2 | — | no | no |
| `catalog.product.create` | Create products | organization | 2 | — | no | yes |
| `catalog.product.edit` | Edit products | organization | 2 | — | no | yes |
| `catalog.product.deactivate` | Deactivate products | organization | 2 | — | no | yes |
| `catalog.identifier.correct` | Controlled canonical identifier correction | organization | 2 | — | yes | yes |
| `catalog.variant.create` | Create variants | organization | 2 | — | no | yes |
| `catalog.variant.edit` | Edit variants (incl. price, tracking mode) | organization | 2 | — | no | yes |
| `catalog.variant.deactivate` | Deactivate variants | organization | 2 | — | no | yes |
| `catalog.option.manage` | Manage option structures | organization | 2 | — | no | yes |
| `catalog.format.manage` | Manage product formats | organization | 2 | — | no | yes |
| `catalog.condition.manage` | Manage product conditions | organization | 2 | — | no | yes |
| `catalog.label.print` | Print labels | store | 2 | — | no | no |

## Inventory (Phases 3–4)

| Key | Description | Scope | Phase | Authority | Approvals | Audit |
| --- | --- | --- | --- | --- | --- | --- |
| `inventory.stock.view` | View store stock balances | store | 3 | — | no | no |
| `inventory.cost.view` | View inventory cost | store | 3 | — | no | no |
| `inventory.adjustment.create` | Create draft adjustments | store | 3 | — | no | yes |
| `inventory.adjustment.post` | Post adjustments (opening/quantity/cost) | store | 3 | cost correction may require elevated authority | yes when policy requires | yes |
| `inventory.reservation.view` | Review reservations | store | 3 | — | no | no |
| `inventory.reservation.release` | Release active reservations | store | 3 | — | no | yes |
| `inventory.receipt.create` | Create receiving drafts | store | 5 | — | no | yes |
| `inventory.receipt.post` | Post receipts | store | 5 | — | yes when policy requires | yes |
| `inventory.unit.manage` | Create/manage inventory units | store | 4d | — | no | yes |

Deferred keys (do not seed until designed): `inventory.transfer.*`, RTV document permissions, count permissions.

## POS (Phases 4a–4e)

| Key | Description | Scope | Phase | Authority | Approvals | Audit |
| --- | --- | --- | --- | --- | --- | --- |
| `pos.access` | Operate POS workspace | store | 4a | — | no | no |
| `pos.business_day.open` | Open business day | store | 4a | — | no | yes |
| `pos.business_day.close` | Close business day | store | 4a | — | no | yes |
| `pos.session.open` | Open POS session | store | 4a | — | no | yes |
| `pos.session.close` | Close POS session | store | 4a | — | no | yes |
| `pos.transaction.open` | Open transactions | store | 4a | — | no | no |
| `pos.transaction.suspend` | Suspend transactions | store | 4a | — | no | yes |
| `pos.transaction.recall` | Recall suspended transactions | store | 4a | — | no | yes |
| `pos.transaction.cancel` | Cancel open/suspended transactions | store | 4a | — | no | yes |
| `pos.transaction.complete` | Complete transactions | store | 4c | — | no | yes |
| `pos.line.remove` | Remove pending lines | store | 4a | — | no | yes |
| `pos.price.override` | Override selling price | store | 4b | `maximum_price_override_rate` / amount | yes | yes |
| `pos.discount.apply` | Apply discounts | store | 4b | `maximum_discount_rate` / amount | yes | yes |
| `pos.discount.approve` | Approve discounts beyond requester authority | store | 4b | approver’s discount authority | — | yes |
| `pos.tax.exempt` | Apply transaction tax exemption | store | 4b | — | yes | yes |
| `pos.return.create` | Create return lines | store | 4e | — | no | yes |
| `pos.return.no_receipt` | No-receipt returns | store | 4e | `maximum_no_receipt_return_amount` | yes | yes |
| `pos.tender.cash` | Accept cash tenders | store | 4c | — | no | no |
| `pos.tender.card_standalone` | Record standalone card tenders | store | 4c | — | no | yes |
| `pos.cash_movement.create` | Paid-in / paid-out / drops | store | 4c | `maximum_paid_out_amount` | yes | yes |
| `pos.receipt.reprint` | Reprint receipts | store | 4c | — | no | yes |
| `pos.post_void.create` | Create post-void corrections | store | 6 | — | yes | yes |

## Purchasing, requests, stored value, reporting

Seed when the owning phase begins. Canonicalize domain lists to this grammar at that time:

| Namespace | Phase | Source domain list to normalize |
| --- | --- | --- |
| `purchasing.*` | 5 | [vendors-and-purchasing.md](vendors-and-purchasing.md) |
| `requests.*` | 5 | [product-requests.md](product-requests.md) |
| `stored_value.*` | 6 | [stored-value.md](stored-value.md) |
| `reporting.*` | 7 | [reporting-and-reconciliation.md](reporting-and-reconciliation.md) |

Until normalized, prefer adding explicit rows here before seeding those phases.

## Seeding rules

- Permission rows are organization-scoped definitions; grant occurs through roles and store memberships.
- Deactivate rather than delete permissions once used in history.
- Never grant access solely by role name in application code.
