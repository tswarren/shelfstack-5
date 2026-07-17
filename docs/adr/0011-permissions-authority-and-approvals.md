# ADR-0011: Separate Permissions, Numeric Authority, and Approval Events

**Status:** Accepted

## Context

A retail employee may be allowed to perform an action generally but not above a particular amount or percentage.

Examples include:

* applying a discount;  
* overriding a price;  
* refunding cash;  
* processing a no-receipt return;  
* recording a paid-out;  
* accepting a cash variance;  
* performing a post-void.

Role names alone cannot express the necessary granularity.

A role called “Manager” may also mean different authority at different stores.

Manager approval must be auditable and must identify the person who actually approved the action.

## Decision

ShelfStack will separate:

1. permission;  
2. numeric authority;  
3. approval.

## Store membership

A user receives store access through one active store-membership record associating:

* user;  
* store;  
* role;  
* effective dates;  
* optional authority-limit overrides.

The initial design assumes one role per user and store membership.

Multiple-role membership may be reconsidered later if needed.

## Role

A role is an organization-owned administrative template.

Examples include:

* Cashier;  
* Senior Cashier;  
* Store Manager;  
* Inventory Staff;  
* Buyer;  
* Administrator.

Application logic does not test these role names.

## Permission

A permission is a stable machine-readable capability such as:

```
pos.complete_transaction
pos.process_no_receipt_return
inventory.adjust_stock
purchasing.place_purchase_order
stored_value.adjust
```

The user must possess the required permission through their effective store membership.

## Numeric authority

Some actions additionally require a value to remain within the user’s authority.

Examples include:

```
maximum_discount_rate
maximum_discount_amount_cents
maximum_price_override_rate
maximum_cash_refund_cents
maximum_no_receipt_return_cents
maximum_paid_out_cents
cash_variance_review_threshold_cents
```

Recommended precedence is:

```
store-membership override
→ role default
→ store default
```

## Approval

When the requesting user lacks sufficient authority, an authorized approver may approve the action.

An approval is an independent record containing:

* store;  
* action type;  
* affected record;  
* requesting user;  
* approving user;  
* reason;  
* requested value;  
* approved value;  
* authority-limit snapshot;  
* approval timestamp.

The approving user must authenticate with their own credentials.

Requester and approver should normally be different people when explicit approval is required.

Emergency self-approval may be supported only as a separately authorized and audited administrative exception.

## Consequences

### Benefits

* Supports granular store-specific access.  
* Avoids hard-coded role logic.  
* Distinguishes the right to attempt an action from the authority to approve its value.  
* Preserves approver identity.  
* Supports different authority levels at different stores.  
* Provides reliable audit evidence.

### Costs

* Authorization evaluation is more complex than role-name checks.  
* Roles, limits, memberships, and approvals require administration.  
* Some workflows require manager reauthentication.  
* Effective-date handling must be consistent.

## Alternatives considered

### Hard-code behavior by role name

Rejected because roles are configurable and may differ among organizations.

### Put every limit directly on users

Rejected because store-specific authority and reusable role templates are required.

### Record only the final performing user

Rejected because requester and approver are different business roles.

### Treat approval as a Boolean flag

Rejected because the approving identity, reason, and authority must be retained.

## Governing rules

* Default store does not grant access.  
* Permission is evaluated in store context.  
* Numeric authority is separate from permission.  
* Approvals are independent records.  
* Approvers use their own credentials.  
* Historical activity remains linked after user, role, or membership deactivation.

## Related domains

* Organization, Stores, and Authorization  
* Point of Sale  
* Receiving and Inventory  
* Vendors and Purchasing  
* Stored Value