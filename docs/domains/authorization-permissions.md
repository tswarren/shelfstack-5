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

For `administration.user.view` and `administration.user.manage`, Scope `organization` means an organization-admin capability evaluated in store context (via membership → role), not a multi-tenant user foreign key. Users are installation-global under INV-ORG-001; see [organization-and-authorization.md](organization-and-authorization.md).

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

## Inventory (Phases 3–5)

| Key | Description | Scope | Phase | Authority | Approvals | Audit |
| --- | --- | --- | --- | --- | --- | --- |
| `inventory.stock.view` | View store stock balances | store | 3 | — | no | no |
| `inventory.cost.view` | View inventory cost | store | 3 | — | no | no |
| `inventory.adjustment.create` | Create draft adjustments | store | 3 | — | no | yes |
| `inventory.adjustment.post` | Post opening and quantity-only adjustments | store | 3 | — | no | yes |
| `inventory.cost_correction.post` | Post inventory cost corrections | store | 3 | — | no (Phase 3); may require Approval later | yes |
| `inventory.reservation.view` | Review reservations | store | 3 | — | no | no |
| `inventory.reservation.release` | Release active reservations | store | 3 | — | no | yes |
| `inventory.receipt.view` | View receipts; receipt cost only when also authorized (`inventory.cost.view` and/or `purchasing.cost.view` as applicable) | store | 5 | — | no | no |
| `inventory.receipt.create` | Create receiving drafts | store | 5 | — | no | yes |
| `inventory.receipt.post` | Post receipts | store | 5 | — | yes when policy requires | yes |
| `inventory.receipt.receive_unlinked` | Add a receipt line without a PO-line reference (reason required) | store | 5 | — | yes when policy requires | yes |
| `inventory.receipt.over_receive` | Accept quantity above the PO open quantity | store | 5 | — | yes when policy requires | yes |
| `inventory.unit.manage` | Create/manage inventory units | store | 4d | — | no | yes |

Do not use `inventory.adjustment.post` alone to post cost corrections.

Do **not** add `inventory.cost_correction.approve` or require Approval records in Phase 3. When common Approval infrastructure lands, revisit mandatory Approval for selected correction cases under ADR-0011.

### Phase 3 evaluation

- Create opening/quantity-only draft: `inventory.adjustment.create` (cost entry allowed without `inventory.cost.view`).
- View draft adjustment cost inputs: creator or `inventory.adjustment.create` (without granting general cost access).
- View posted adjustment cost history or existing stock valuation: `inventory.cost.view`.
- Post opening/quantity-only: `inventory.adjustment.post`.
- Post cost correction: `inventory.cost_correction.post` **and** `inventory.cost.view` (correction reviews current value), plus explicit reason and full audit.
- Numeric self-authority limits deferred until OD-009 / OD-013.


After seeding new permissions, existing installs need `bin/rails shelfstack:sync_admin_permissions` (see [bootstrap-and-seed.md](../implementation/bootstrap-and-seed.md)).

Deferred keys (do not seed until designed): `inventory.transfer.*`, RTV document permissions, count permissions, `inventory.receipt.correct` (posted-receipt correction document remains open).

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
| `pos.price.override` | Override selling price | store | 4b | `maximum_price_override_rate` | yes | yes |
| `pos.discount.apply` | Apply discounts | store | 4b | `maximum_discount_rate` / `maximum_discount_amount_cents` | yes | yes |
| `pos.discount.approve` | Approve discounts beyond requester authority | store | 4b | approver’s discount authority | — | yes |
| `pos.tax.exempt` | Apply whole-transaction tax exemption | store | 4b | — | yes | yes |
| `pos.tax_category.override` | Override effective Tax Category on a POS line | store | 4b | — | yes | yes |
| `pos.return.create` | Create return lines | store | 4e | — | no | yes |
| `pos.return.no_receipt` | No-receipt returns | store | 4e | `maximum_no_receipt_return_cents` | yes | yes |
| `pos.return.refund_exception.approve` | Approve refund destination exceptions (bypass remaining original tender restoration) | store | 6 | — | — | yes |
| `pos.tender.cash` | Accept cash tenders | store | 4c | — | no | no |
| `pos.tender.card_standalone` | Record standalone card tenders | store | 4c | — | no | yes |
| `pos.tender.card_void` | Confirm external card voids for authorized card tenders and `void_required` recovery tenders | store | 4c/6 | — | no | yes |
| `pos.cash_movement.create` | Paid-in / paid-out / drops | store | 4c | `maximum_paid_out_cents` | yes | yes |
| `pos.receipt.reprint` | Reprint receipts | store | 4c | — | no | yes |
| `pos.post_void.create` | Create post-void corrections | store | 6 | — | yes | yes |
| `pos.post_void.approve` | Independently approve another user’s post-void | store | 6 | — | — | yes |
| `pos.post_void.approve_self` | Authorize one’s own post-void (still requires PIN re-auth and a recorded approval) | store | 6 | — | — | yes |

## Purchasing (Phase 5)

Canonical keys for Vendors and Purchasing. Domain lists must match this catalog.

| Key | Description | Scope | Phase | Authority | Approvals | Audit |
| --- | --- | --- | --- | --- | --- | --- |
| `purchasing.vendor.view` | View vendors | organization | 5 | — | no | no |
| `purchasing.vendor.manage` | Create, edit, and deactivate vendors | organization | 5 | — | no | yes |
| `purchasing.vendor_source.view` | View variant–vendor sources and expected costs (cost fields also require `purchasing.cost.view`) | organization | 5 | — | no | no |
| `purchasing.vendor_source.manage` | Create, edit, and deactivate variant–vendor sources | organization | 5 | — | no | yes |
| `purchasing.cost.view` | View vendor and expected acquisition cost | store | 5 | — | no | no |
| `purchasing.purchase_order.view` | View purchase orders | store | 5 | — | no | no |
| `purchasing.purchase_order.create` | Create draft purchase orders | store | 5 | — | no | yes |
| `purchasing.purchase_order.edit` | Edit draft purchase orders and lines | store | 5 | — | no | yes |
| `purchasing.purchase_order.place` | Transition a draft PO to ordered | store | 5 | — | yes when policy requires | yes |
| `purchasing.purchase_order.amend` | Cancel placed-line quantity, increase ordered quantity, or other permitted placed-order amendments | store | 5 | — | yes when policy requires | yes |
| `purchasing.purchase_order.cancel` | Cancel an entirely unreceived PO | store | 5 | — | yes when policy requires | yes |
| `purchasing.purchase_order.close` | Close a fully resolved PO | store | 5 | — | no | yes |
| `purchasing.allocation.create` | Commit open PO quantity to a Customer Request | store | 5 | — | no | yes |
| `purchasing.allocation.release` | Release customer allocation quantity (with reason) | store | 5 | — | no | yes |

### Purchasing evaluation

- Draft mutability: `purchasing.purchase_order.edit` only while status is `draft`.
- After placement, reduce or increase open quantity through `purchasing.purchase_order.amend` (including `cancelled_quantity` and permitted line additions). Do not use `edit` on placed POs.
- Whole-PO `cancel` applies only when nothing has been received. Remaining open quantity on a partially received PO is reduced through `amend`, not `cancel`.
- Unexpected deliveries and over-receipt use Receiving keys (`inventory.receipt.receive_unlinked`, `inventory.receipt.over_receive`), not purchasing keys.

## Product Requests (Phase 5)

Canonical keys for Product Requests. On-order allocation uses `purchasing.allocation.create` / `purchasing.allocation.release`. Unclaimed holds use existing `inventory.reservation.release`.

| Key | Description | Scope | Phase | Authority | Approvals | Audit |
| --- | --- | --- | --- | --- | --- | --- |
| `requests.product_request.view` | View Product Requests and buyer review | store | 5 | — | no | no |
| `requests.product_request.create` | Create Product Requests (any type the UI allows) | store | 5 | — | no | yes |
| `requests.product_request.edit` | Edit open requests | store | 5 | — | no | yes |
| `requests.product_request.assign` | Assign or reassign a buyer | store | 5 | — | no | yes |
| `requests.product_request.resolve` | Record the buyer’s terminal decision (ordered, declined, deferred, etc.) | store | 5 | — | no | yes |
| `requests.product_request.cancel` | Cancel a request | store | 5 | — | no | yes |
| `requests.customer_request.reserve` | Commit physically confirmed inventory to a Customer Request | store | 5 | — | no | yes |
| `requests.customer_request.fulfill` | Record Customer Request fulfilment (reservation and/or POS completion link) | store | 5 | — | no | yes |

### Product Request evaluation

- Request type determines which resolution and coverage rules apply; do not add type-specific resolve keys such as `resolve_non_customer_request`.
- Decline, defer, ordered, duplicate, superseded, and no-longer-needed are outcomes of `resolve` (or automatic close from fulfilment), not separate permissions. There is no `requests.product_request.close` key.
- `create` covers all four Phase 5 types. Split into type-scoped create keys only if role design later requires different creators for customer vs buyer-decision demand.
- Customer-only actions use `requests.customer_request.*`. Non-customer requests do not reserve or fulfil through those keys.

## Stored value (Phase 6)

Canonical keys for Stored Value. Domain lists must match this catalog. Policy: [Phase 6 stored-value v1 operating policy](../implementation/decisions/phase-06-stored-value-v1-operating-policy.md).

| Key | Description | Scope | Phase | Authority | Approvals | Audit |
| --- | --- | --- | --- | --- | --- | --- |
| `stored_value.account.view` | View account and current balance | store | 6 | — | no | no |
| `stored_value.ledger.view` | View ledger history | store | 6 | — | no | no |
| `stored_value.account.create` | Create zero-balance accounts | store | 6 | — | no | yes |
| `stored_value.account.suspend` | Suspend or unsuspend accounts | store | 6 | — | no | yes |
| `stored_value.issue` | Issue gift-card value through POS | store | 6 | — | no | yes |
| `stored_value.reload` | Reload gift-card value through POS | store | 6 | — | no | yes |
| `stored_value.tender.redeem` | Redeem stored value as tender | store | 6 | — | no | yes |
| `stored_value.tender.refund` | Refund to stored value | store | 6 | — | no | yes |
| `stored_value.adjustment.create` | Create manual balance adjustments | store | 6 | — | yes | yes |
| `stored_value.adjustment.approve` | Independently approve manual adjustments | store | 6 | — | — | yes |
| `stored_value.adjustment.approve_self` | Authorize one’s own manual adjustment (still requires PIN re-auth and a recorded approval) | store | 6 | — | — | yes |

### Stored-value evaluation

- Replacement and transfer keys remain deferred.
- Every manual adjustment requires `stored_value.adjustment.create` plus a recorded approval: another user with `stored_value.adjustment.approve`, or the same user with `stored_value.adjustment.approve_self` (PIN re-auth still required). Holding only `stored_value.adjustment.approve` does not imply self-approval.
- Post-void always requires `pos.post_void.create` plus a recorded approval: another user with `pos.post_void.approve`, or the same user with `pos.post_void.approve_self` (PIN re-auth still required). Holding only `pos.post_void.approve` does not imply self-approval.

## Reporting

Seed when Phase 7 begins. Canonicalize domain lists to this grammar at that time:

| Namespace | Phase | Source domain list to normalize |
| --- | --- | --- |
| `reporting.*` | 7 | [reporting-and-reconciliation.md](reporting-and-reconciliation.md) |

Until normalized, prefer adding explicit rows here before seeding that phase.

## Seeding rules

- Permission catalog rows are installation-wide definitions; grant occurs through organization-owned roles and store memberships.
- Deactivate rather than delete permissions once used in history.
- Never grant access solely by role name in application code.
