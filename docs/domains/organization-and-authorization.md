# Organization and Authorization Domain

**Status:** Consolidated specification  
**Domain owner:** Organization, Store, identity, access, authority, and Approval records

## Governing ADRs

- [ADR-0010: Distinguish Business Days, Sessions, Devices, Drawers, and Z Reports](../adr/0010-business-days-sessions-and-z-reports.md)
- [ADR-0011: Separate Permissions, Numeric Authority, and Approval Events](../adr/0011-permissions-authority-and-approvals.md)

## Purpose

This domain establishes the operating and authorization context used by every other ShelfStack domain.

It answers:

- Which Organization owns the installation?
- Which Store is affected?
- Which User is acting?
- Does the User have active access to that Store?
- Which Permissions apply?
- Does the User have sufficient numeric authority?
- Did an authorized approver approve the restricted action?
- Which POS Device and Cash Drawer are involved?

## Ownership boundary

### Owns

- Organization;
- Store;
- User;
- Store Membership;
- Role;
- Permission;
- Role-Permission assignment;
- Role and membership authority limits;
- Approval;
- POS Device;
- Cash Drawer;
- authentication identity;
- administrative audit events.

### References but does not own

- Business Day and POS Session, owned by Point of Sale;
- Product and inventory records;
- Purchase Orders and Receipts;
- POS Transactions;
- Stored-Value Accounts;
- report definitions.

## Principal entities

### Organization

One installation represents one operating Organization.

Suggested attributes:

- code;
- name;
- legal name;
- active status;
- default currency;
- default time zone;
- Organization-wide configuration references.

### Store

A Store is the operational boundary for inventory, Receiving, tax configuration, POS, receipt numbering, cash accountability, and Reconciliation.

Suggested attributes:

- Organization;
- stable code;
- name and legal name;
- active status;
- time zone;
- currency;
- address and contact information;
- receipt header and footer;
- Store configuration references.

An inactive Store cannot begin ordinary new operational activity but remains available for history.

### User

A User is one authenticated person. Shared cashier identities are prohibited for accountable activity.

Suggested attributes:

- name;
- email or login identity;
- active status;
- optional default Store;
- authentication fields;
- optional PIN credential;
- last login.

### Store Membership

A Store Membership grants one User access to one Store.

Suggested attributes:

- User;
- Store;
- Role;
- active status;
- effective dates;
- optional authority-limit overrides.

A User may have different Roles and limits at different Stores.

### Role

A Role is an Organization-owned administrative template containing Permissions and default limits.

Suggested templates may include Cashier, Senior Cashier, Store Manager, Inventory Staff, Buyer, and Administrator. Application logic must not test these names.

### Permission

A Permission is a stable machine-readable capability.

Suggested namespaces:

```text
administration.*
catalog.*
classification.*
purchasing.*
inventory.*
pos.*
stored_value.*
reporting.*
```

### Authority limits

Numeric authority is evaluated separately from Permission.

Examples:

- maximum Discount rate or amount;
- maximum Price Override;
- maximum cash refund;
- maximum no-receipt Return;
- maximum paid-out;
- Cash Variance review threshold.

Recommended precedence:

```text
Store-Membership override
→ Role default
→ Store default
```

### Approval

An Approval records authorization of one restricted action.

It retains Store, action type, affected record, requesting User, approving User, reason, requested and approved values, authority snapshot, and timestamp.

Approvers authenticate with their own credentials.

### POS Device

A POS Device is a physical or logical register assigned to one Store. It is not a User, POS Session, or Cash Drawer.

### Cash Drawer

A Cash Drawer is a physical till assigned to one Store. It may be used by different POS Devices over time but has at most one active cash-enabled POS Session.

## Effective access

A User may perform a Store-scoped action when:

```text
User active
AND Store active
AND Store Membership effective and active
AND required Permission present
AND applicable authority sufficient
AND Approval present when required
```

POS operation additionally requires the applicable active POS Device, Business Day, and POS Session.

## Workflows

### Grant Store access

1. Select User and Store.
2. Assign Role.
3. Set effective dates.
4. Add authority overrides only where required.
5. Activate Store Membership.
6. Audit the change.

### Restricted action Approval

1. Requesting User attempts action.
2. ShelfStack validates Permission and numeric authority.
3. When authority is insufficient, request Approval.
4. Approver authenticates.
5. Validate approver access, Permission, and limit.
6. Create Approval record.
7. Continue the original workflow using the Approval reference.

### User deactivation

1. Block new authentication.
2. Preserve historical identity.
3. Disable Store Membership use.
4. Resolve open Sessions or assignments through an authorized process.
5. Do not reassign completed activity.

## Permissions

Canonical keys, scopes, phases, authority, and approval behavior are maintained in [authorization-permissions.md](authorization-permissions.md).

Administration and operational permissions used in seeds and application checks must match that catalog. Older illustrative names in this section are superseded when they disagree.

## Audit requirements

Audit User and Store activation, Store-Membership changes, Role and Permission changes, authority-limit changes, Device and Drawer activation, Approval requester and approver, emergency overrides, and administrative access changes.

## Invariants

- Default Store does not grant access.
- Permissions are evaluated in Store context.
- Role names do not control behavior.
- Permission and numeric authority are separate checks.
- Every material action retains the actual User.
- Every Approval retains requester and approver.
- Devices and Drawers belong to one Store.
- One Drawer has at most one active cash-enabled Session.
- Historical records survive deactivation.

## Open questions

- Can one User hold more than one Role at the same Store?
- Which non-POS actions require numeric authority?
- Should Approvals remain one shared cross-domain entity?
- Which actions require recent PIN reauthentication?
- How are open Sessions resolved when a User is deactivated?
- Which administrative actions require dual authorization?
