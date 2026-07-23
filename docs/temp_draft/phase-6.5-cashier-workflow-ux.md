# Cashier Workflow Map

> **Planning status:** Non-governing draft. Delivery scope for a thin Phase 6.5 is in [../implementation/phases/phase-06.5-cashier-workspace.md](../implementation/phases/phase-06.5-cashier-workspace.md). Prefer that phase plan and [../design/pos-register-ui.md](../design/pos-register-ui.md) when they conflict with this draft.

## Purpose

The cashier workflow defines how a user moves through a POS transaction from an idle register to a completed receipt.

It is not intended to expose every underlying POS record or posting operation. The interface presents recognizable cashier tasks, while ShelfStack coordinates pricing, tax, inventory, tender, stored value, authorization, and historical posting behind those tasks.

The primary workflow should optimize the ordinary sale while allowing returns, discounts, stored value, and other exceptional activity to enter the transaction contextually.

---

## 1\. Governing interaction model

The cashier should normally experience the POS as the following sequence:

```
Ready
→ Start transaction
→ Build transaction
→ Review
→ Tender
→ Complete
→ Receipt
→ Ready
```

Exceptional activity branches from this sequence rather than creating separate disconnected applications.

The system may support temporary workflow modes such as:

* Sale  
* Return  
* Stored value  
* Transaction actions  
* Tender

These modes guide data entry. They do not permanently classify the transaction. A completed transaction may contain sales, returns, open-ring activity, and stored-value activity together.

---

## 2\. Top-level workflow

```
REGISTER READY
│
├── Start new transaction
│       │
│       ▼
│   BUILD TRANSACTION
│       │
│       ├── Scan or search for merchandise
│       ├── Add sale line
│       ├── Add return line
│       ├── Add open-ring line
│       ├── Add stored-value activity
│       ├── Modify selected line
│       ├── Apply transaction action
│       ├── Suspend transaction
│       └── Cancel transaction
│
│       ▼
│   REVIEW TRANSACTION
│       │
│       ├── Resolve warnings
│       ├── Resolve blockers
│       ├── Obtain required approvals
│       └── Confirm customer-facing total
│
│       ▼
│   TENDER
│       │
│       ├── Receive payment
│       ├── Issue refund
│       ├── Apply split tender
│       ├── Confirm external card approval
│       ├── Apply or restore stored value
│       └── Return to editing when permitted
│
│       ▼
│   COMPLETE
│       │
│       ├── Final validation
│       ├── Atomic posting
│       ├── Receipt-number assignment
│       └── Completion confirmation
│
│       ▼
│   RECEIPT
│       │
│       ├── Print or display receipt
│       ├── Print gift receipt
│       └── Start next transaction
│
└── Recall suspended transaction
        │
        ▼
    REFRESH AND REVIEW
        │
        └── Return to Build Transaction
```

---

## 3\. Register-ready state

The register-ready state is the cashier’s neutral starting point.

The interface should prominently offer:

* start a new transaction;  
* scan an item to start automatically;  
* recall a suspended transaction;  
* look up a completed receipt;  
* access limited session actions;  
* sign out or change cashier.

The ready state should confirm the active:

* store;  
* device;  
* business day;  
* POS session;  
* cashier;  
* cash drawer, where applicable.

Configuration problems that prevent selling should be shown before a transaction begins.

Examples include:

* no open business day;  
* no open session;  
* inactive device;  
* missing drawer assignment;  
* cashier lacks POS access.

---

## 4\. Starting a transaction

A transaction may begin through:

* selecting **New transaction**;  
* scanning merchandise while the register is ready;  
* recalling a suspended transaction;  
* beginning a return from receipt lookup;  
* beginning an administrative reversal from transaction lookup.

A new transaction receives its internal and public identity immediately, but it does not receive a receipt number until successful completion.

The interface should enter ordinary sale entry by default.

---

## 5\. Building the transaction

Building the transaction is the primary cashier workspace.

The workspace should have three stable areas:

### Entry area

Used for:

* barcode scanning;  
* identifier entry;  
* descriptive search;  
* quantity entry;  
* receipt lookup during returns;  
* stored-value account lookup.

Scanner input should normally remain focused here unless the cashier is actively completing another required task.

### Transaction lines

Shows the current transaction in entry order.

Each line should clearly communicate:

* sale or return direction;  
* description;  
* quantity;  
* regular price;  
* selling price;  
* discount;  
* tax;  
* line total;  
* inventory-unit identity when applicable;  
* warning or approval status.

### Transaction summary

Shows:

* sale subtotal;  
* return subtotal;  
* discounts;  
* tax;  
* net amount;  
* amount due or refund due;  
* unresolved warnings or approvals.

The summary should remain visible without competing with line entry.

---

## 6\. Adding merchandise

### Scan resolution

A scan should resolve in the following practical order:

```
Exact inventory unit
→ Exact product variant
→ Product
→ Stored-value account or other recognized POS reference
→ No match
```

The cashier-facing result should be based on the resolved record rather than requiring the cashier to understand the identifier type.

### Exact inventory-unit scan

The line is added for the identified unit when it is valid for sale at the active store.

The system should show a focused exception when the unit is:

* at another store;  
* already reserved;  
* already sold;  
* unavailable;  
* associated with an unexpected variant.

### Variant scan

The exact sellable variant is added directly.

### Product scan

If the product has one ordinary sellable variant, that variant may be selected automatically.

If several variants are plausible, the cashier receives a concise selection list.

### Search

Search is the fallback for merchandise that cannot be scanned.

Results should emphasize information needed at checkout:

* title or description;  
* format or variant;  
* condition;  
* price;  
* available quantity;  
* SKU or identifier;  
* exact-unit requirement.

Administrative catalog detail should remain outside the checkout result.

---

## 7\. Line-level actions

The selected line provides the context for line-specific actions.

Common actions include:

* change quantity;  
* remove line;  
* apply line discount;  
* override selling price;  
* view tax treatment;  
* select or change exact inventory unit;  
* enter return information;  
* change return disposition;  
* view approval status.

Actions should not be scattered among unrelated parts of the screen.

A cashier should first select a line and then choose the applicable action.

### Removed lines

A removed pending line should disappear from the ordinary transaction presentation or move into an optional activity history.

The cashier does not need to manage the persisted removed-line record directly.

---

## 8\. Sale workflow

Sale entry is the default workflow.

```
Scan or search
→ Resolve exact variant or unit
→ Validate sale eligibility
→ Add line
→ Reserve inventory
→ Continue scanning
```

Ordinary warnings should not interrupt rapid scanning unless immediate attention is required.

Examples of nonblocking warnings include:

* the sale will create negative quantity inventory;  
* cost is unavailable;  
* stock information may be stale.

Blockers must prevent completion, but they do not necessarily need to prevent the cashier from continuing to build the rest of the transaction.

---

## 9\. Return workflow

Return is a temporary entry mode within the same transaction workspace.

The preferred linked-return path is:

```
Find receipt
→ Select original line
→ Enter return quantity
→ Confirm return reason
→ Confirm disposition
→ Add return line
```

ShelfStack should derive the original:

* selling amount;  
* discount allocation;  
* tax;  
* cost;  
* department;  
* return eligibility;  
* remaining returnable quantity.

The cashier should not re-enter those values manually.

### Unlinked return

An unlinked return requires additional guided information:

```
Identify merchandise
→ Select return source
→ Select refund basis
→ Enter reason
→ Select disposition
→ Obtain approval when required
→ Add return line
```

The interface should ask only for information that cannot be derived.

### Mixed sale and return

After a return line is added, the cashier may return to sale entry and continue scanning purchases.

The transaction summary should show the resulting net:

* amount due to the store; or  
* refund due to the customer.

The cashier should not have to construct a separate exchange transaction manually.

---

## 10\. Stored-value workflow

Stored-value activity should use a focused mode with clearly separated actions.

### Issue new value

```
Select account type
→ Scan or generate account
→ Enter issuance amount
→ Add stored-value sale line
```

### Reload existing account

```
Scan or search account
→ Confirm account
→ Enter reload amount
→ Add reload activity
```

### Redeem stored value

Redemption occurs during tendering:

```
Select stored-value tender
→ Scan or search account
→ Display available balance
→ Enter amount to apply
→ Validate balance
→ Add tender
```

### Refund to stored value

When store credit is the refund method:

```
Select or generate store-credit account
→ Confirm refund amount
→ Add refunded stored-value tender
```

The cashier interface should distinguish issuance, reload, redemption, and refund even though they share account infrastructure.

---

## 11\. Transaction-level actions

Transaction-level actions apply to the transaction rather than one selected line.

Examples include:

* transaction discount;  
* coupon or promotion;  
* tax exemption;  
* customer association;  
* suspend;  
* cancel;  
* transaction note;  
* open-ring entry;  
* receipt or gift-receipt options.

Less common or privileged actions should be grouped under a clearly named transaction-actions control rather than permanently occupying the main workspace.

---

## 12\. Approval workflow

Approval is an interruption to the current task, not a separate destination.

```
Cashier requests restricted action
→ ShelfStack evaluates permission and authority
→ Approval required
→ Approver authenticates
→ Approver reviews action and reason
→ Approve or decline
→ Cashier returns to the same transaction context
```

The approval prompt should show:

* requested action;  
* affected line or transaction;  
* requested value;  
* cashier;  
* reason;  
* authority required.

After approval, the cashier should return to the exact point at which the action was requested.

An approval should not require rebuilding the line or re-entering the transaction.

---

## 13\. Review before tender

The review stage confirms that the transaction is ready for settlement.

The interface should distinguish:

### Informational messages

No action is required.

### Warnings

The cashier may continue after acknowledgment or according to store policy.

### Approval requirements

An authorized user must approve before completion.

### Blockers

Completion cannot proceed until the condition is corrected.

Typical blockers include:

* missing price;  
* missing department;  
* missing tax category;  
* required exact inventory unit not selected;  
* invalid reservation;  
* unresolved return requirement;  
* unresolved tender activity;  
* stored-value account problem.

The cashier should be able to select a blocker and move directly to the place where it can be resolved.

---

## 14\. Entering tender mode

Selecting **Tender** moves the transaction into a focused settlement state.

The tender screen should emphasize:

* net amount due or refund due;  
* completed tender entries;  
* remaining amount;  
* available tender methods;  
* completion readiness.

Product and line editing should be visibly locked while active tender activity exists.

The cashier may return to transaction editing only when provisional tender activity can be safely removed or reversed.

---

## 15\. Customer payment

### Cash

```
Select cash
→ Enter amount presented
→ Calculate amount applied and change
→ Confirm
```

The display should clearly distinguish:

* amount due;  
* amount presented;  
* change due.

### Standalone card

```
Select card
→ Display amount to process
→ Cashier processes external terminal
→ Confirm approved or not approved
→ Record optional reference
```

ShelfStack should not imply that it processed the card itself.

An approved external card entry should remain clearly marked so the cashier understands that removing or changing it may require a terminal void.

### Split tender

```
Add first tender
→ Reduce remaining amount
→ Add next tender
→ Continue until settled
```

The tender list should show both the original applied amount and the remaining balance after each tender.

### Stored value

```
Scan account
→ Display balance
→ Apply requested amount
→ Reduce remaining amount
```

---

## 16\. Customer refund

When the transaction produces a refund, the tender workspace changes from **Payment due** to **Refund due**.

ShelfStack should suggest refund tenders according to policy.

Examples include:

* original cash;  
* original card type;  
* restoration to original stored value;  
* new store credit;  
* authorized alternative.

For linked mixed-tender returns, the interface should calculate the recommended tender restoration rather than requiring the cashier to reconstruct it.

For a mixed sale-and-return transaction, return value should first offset new purchases. Only the remaining net amount is paid or refunded.

---

## 17\. Completion

The cashier selects **Complete transaction** only after tender settlement is valid.

The interface should then present a brief processing state and prevent duplicate input.

ShelfStack performs final validation and commits the required effects together, including:

* completed lines;  
* discounts;  
* tax;  
* tenders;  
* inventory;  
* cost snapshots;  
* stored-value entries;  
* receipt-number assignment;  
* final transaction totals.

### Successful completion

```
Completion succeeds
→ Receipt number assigned
→ Receipt presented
→ Transaction becomes immutable
```

### Failed completion

```
Completion fails
→ Transaction remains incomplete
→ No duplicate internal posting
→ Cashier receives a recovery state
```

The error should explain:

* what failed;  
* whether any external card approval exists;  
* what the cashier must do next;  
* whether manager or back-office intervention is required.

The cashier should not be returned to an empty transaction or left uncertain whether the sale completed.

---

## 18\. Receipt state

After completion, the cashier may:

* print the customer receipt;  
* reprint after a printer failure;  
* print gift receipts for selected eligible lines;  
* display or send an electronic receipt when supported;  
* start the next transaction.

The primary action should be **Next transaction**.

A completed transaction should no longer expose ordinary line editing or tender editing.

Corrections begin through a new linked workflow.

---

## 19\. Suspension and recall

### Suspend

A transaction may be suspended from the build or review stage when no unresolved tender activity remains.

```
Open transaction
→ Select Suspend
→ Enter optional identifying note
→ Transaction becomes suspended
→ Reservations remain active
→ Register returns to Ready
```

The suspension prompt may capture:

* customer name or description;  
* recall note;  
* reason;  
* expected return time.

These details help identification but do not impose an automatic expiration.

### Recall

```
Open suspended list
→ Select transaction
→ Lock transaction to active register
→ Refresh current commercial rules
→ Show material changes
→ Cashier confirms changes
→ Return to Build Transaction
```

Material changes may include:

* price;  
* promotion;  
* tax;  
* department;  
* tax category;  
* eligibility;  
* inventory condition.

The cashier should review differences rather than silently receiving recalculated totals.

---

## 20\. Cancellation

Cancellation applies only before completion.

```
Open or suspended transaction
→ Select Cancel
→ Enter reason when required
→ Confirm
→ Release reservations
→ Remove provisional effects
→ Mark transaction cancelled
→ Return to Ready
```

Cancellation should not be presented as voiding a completed transaction.

---

## 21\. Completed-transaction correction

Completed activity is corrected through a new linked workflow.

### Customer return

Begins from receipt lookup and creates new return lines.

### Post-void

Begins from completed-transaction lookup.

```
Find completed transaction
→ Select Post-void
→ Evaluate reversal eligibility
→ Obtain approval
→ Enter reason
→ Review full reversal
→ Complete new reversing transaction
```

If a post-void is blocked, the interface should explain the downstream activity preventing full reversal.

The original transaction remains completed and viewable.

---

## 22\. Session workflow

Session operations are separate from the transaction workflow.

### Open session

```
Authenticate
→ Confirm device and store
→ Select drawer when cash-enabled
→ Enter opening cash
→ Open session
→ Register Ready
```

### Session X report

An authorized user may view or print a current non-closing snapshot while the session remains open.

### Close session

```
Resolve active transaction or tender issues
→ Begin close
→ Record cash count
→ Compare counted and expected cash
→ Explain variance when required
→ Obtain review when required
→ Close session
→ Generate session Z report
```

Suspended transactions without unresolved tender activity do not need to be completed before session close.

Closing the session ends operations. Reconciliation may occur later.

---

## 23\. Business-day workflow

The business day is store-wide and may contain several POS sessions.

```
Open business day
→ Open and close one or more sessions
→ Confirm all sessions closed
→ Review consolidated activity
→ Close business day
→ Generate business-day Z report
→ Reconcile later when required
```

A business day cannot close while a POS session remains open.

---

## 24\. Design priorities

The workflow should be evaluated against the following priorities.

### Speed

The ordinary sale path should require:

```
Scan
→ Tender
→ Complete
```

Additional fields and controls should appear only when the transaction requires them.

### Stable context

Approvals, warnings, searches, and exceptions should return the cashier to the same line and transaction state.

### Scanner-first operation

Barcode input should work without the cashier repeatedly restoring focus.

### Keyboard completion

The core workflow should be operable without a mouse.

### Progressive disclosure

Exceptional operations should remain available but should not dominate the ordinary sale screen.

### Clear transaction state

The cashier should always be able to determine whether the transaction is:

* being edited;  
* suspended;  
* awaiting tender;  
* externally card-approved;  
* ready to complete;  
* processing;  
* completed;  
* cancelled.

### Explicit recovery

Failures should explain whether the transaction completed, what external activity occurred, and what action is required.

---

## 25\. Summary workflow

```
READY
│
├── New or scanned transaction
│
▼
BUILD
│
├── Sale lines
├── Return lines
├── Stored-value lines
├── Discounts and overrides
├── Approvals
├── Suspend ───────────────→ SUSPENDED
└── Cancel ────────────────→ CANCELLED
│
▼
REVIEW
│
├── Warnings
├── Approvals
└── Blockers
│
▼
TENDER
│
├── Cash
├── Card
├── Stored value
├── Split tender
└── Refund
│
▼
COMPLETE
│
├── Failure ───────────────→ RECOVERY
└── Success
    │
    ▼
RECEIPT
    │
    ▼
READY
```

The key principle is that the cashier follows one continuous operational path. ShelfStack may create and coordinate several domain records, but the interface should not require the cashier to operate those records as separate systems.  