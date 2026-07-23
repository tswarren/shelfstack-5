> **Planning status:** Non-governing draft. Visible-state simplification and implementation order here largely informed [../implementation/phases/phase-06.5-cashier-workspace.md](../implementation/phases/phase-06.5-cashier-workspace.md). A full `POSWorkspaceState` command façade, printers, and global scanner capture remain out of Phase 6.5 scope.

## Core recommendation

ShelfStack should not present the cashier with the underlying POS domains as separate workflows. It should present **one persistent checkout workspace** that changes behavior according to the cashier’s immediate task.

The cashier’s mental model is closer to:

> Scan something → correct anything unusual → collect or return money → finish.

It is not:

> Create transaction record → create line item → manage reservation → calculate tax → create tender → post inventory.

Your workflow map already establishes this principle: exceptional activity branches from one continuous transaction rather than becoming separate applications. 

---

# 1. Simplify the cashier-facing state model

The proposed sequence is sound, but I would reduce the number of states the cashier perceives.

## Visible states

| State           | Cashier’s understanding                         |
| --------------- | ----------------------------------------------- |
| **Ready**       | The register is waiting                         |
| **Transaction** | I am adding or correcting items                 |
| **Tender**      | I am collecting or refunding money              |
| **Processing**  | ShelfStack is completing the transaction        |
| **Receipt**     | The transaction succeeded                       |
| **Recovery**    | Something failed and requires a specific action |

I would **not make Review a separate screen**.

Instead, review readiness should appear inside the Transaction workspace:

* a green **Ready for tender** condition;
* warnings that do not block tender;
* approvals that must be obtained;
* blockers linked directly to the affected line or field.

This preserves the desired ordinary path:

```text
Scan
→ Tender
→ Complete
```

The cashier may visually review the transaction at any time, but ShelfStack should not require an additional Review step for every sale.

---

# 2. Use entry intents, not separate applications

Within the Transaction state, ShelfStack can temporarily change how input is interpreted.

Recommended entry intents:

```text
Sale
Return
Stored value
Open ring
Receipt lookup
```

These are not transaction types. They are short-lived instructions to the workspace.

For example:

* **Sale intent:** a scanned product is added as a sale line.
* **Return intent:** a scan searches the original receipt or identifies returned merchandise.
* **Stored-value intent:** a scan resolves or creates a stored-value account.
* **Receipt lookup:** input searches completed transactions rather than adding merchandise.

After the task is finished, ShelfStack normally returns to Sale intent.

The cashier should never have to leave the current transaction and enter a separate “Returns module” to perform an exchange.

---

# 3. Build one stable POS workspace

The cashier should always know where information and actions will appear.

## Recommended layout

```text
┌─────────────────────────────────────────────────────────────────────┐
│ Store · Register · Session · Cashier            Transaction status  │
├─────────────────────────────────────────────────────────────────────┤
│ Entry / Scan                                      Current intent    │
│ [ Scan barcode, enter identifier, or search... ] [ SALE ▼ ]         │
├───────────────────────────────────────────┬─────────────────────────┤
│ Transaction lines                         │ Transaction summary     │
│                                           │                         │
│  1  Product A                  $14.99     │ Sales           $34.98  │
│  2  Product B × 2              $19.99     │ Returns          $0.00  │
│  3  Product C RETURN          −$10.00     │ Discounts        $2.00  │
│                                           │ Tax              $1.84  │
│                                           │ Amount due      $24.82  │
│                                           │                         │
│                                           │ 1 warning               │
│                                           │ Ready for tender        │
├───────────────────────────────────────────┴─────────────────────────┤
│ Line actions / transaction actions                  [TENDER $24.82] │
└─────────────────────────────────────────────────────────────────────┘
```

### Stable regions

**Header**

* store;
* device;
* session;
* cashier;
* transaction status;
* connectivity or configuration problems.

**Entry field**

* receives scans;
* accepts identifiers;
* supports descriptive search;
* changes interpretation based on the current intent.

**Transaction lines**

* remain the central work area;
* support keyboard selection;
* show only cashier-relevant facts.

**Summary**

* remains visible;
* reports the net financial result;
* shows warnings, approvals, blockers and tender readiness.

**Action area**

* changes according to the selected line and current state;
* does not permanently display every possible POS operation.

---

# 4. Make the selected object determine available actions

The interface should answer:

> What can I do with the thing I currently selected?

## When a sale line is selected

Show actions such as:

* quantity;
* remove;
* discount;
* price override;
* exact unit;
* tax details.

## When a return line is selected

Show:

* return reason;
* disposition;
* return basis;
* original sale;
* refund eligibility;
* approval status.

## When no line is selected

Show transaction actions:

* customer;
* transaction discount;
* tax exemption;
* coupon;
* open ring;
* suspend;
* cancel;
* note.

This prevents actions from being scattered across the screen and reduces the number of controls competing for the cashier’s attention.

Less-common operations should be placed under one **Transaction actions** control, but frequently used actions should remain directly accessible.

---

# 5. Treat scanner input as a global command channel

Scanner handling is one of the most important differences between an ordinary web form and a cashier-oriented POS.

## Default rule

Unless a focused workflow explicitly owns scanner input, every completed scan should go through the POS scan resolver.

```text
Exact inventory unit
→ Exact variant
→ Product
→ Stored-value account or POS reference
→ No match
```

This is consistent with ShelfStack’s identifier hierarchy and exact-unit requirements. 

## Scanner ownership

A temporary workflow can take ownership of the next scan:

| Current task           | Scan interpretation                            |
| ---------------------- | ---------------------------------------------- |
| Ordinary transaction   | Add merchandise                                |
| Select exact unit      | Resolve inventory unit                         |
| Find receipt           | Resolve receipt or transaction identifier      |
| Redeem stored value    | Resolve stored-value account                   |
| Manager approval       | Authenticate approver                          |
| Gift receipt selection | Select eligible line, where scanning is useful |

After the task succeeds or is cancelled, scanner ownership returns to ordinary sale entry.

## Important behavior

* A scan should work even when the visible cursor is not inside the entry field.
* ShelfStack should distinguish rapid scanner input from ordinary keyboard typing.
* A modal must never silently consume a scan unless that modal clearly owns scanning.
* `Escape` should cancel the current temporary task and restore ordinary sale entry.
* The scan field should regain logical focus after line actions, approvals and errors.

---

# 6. Use task panels instead of navigation

Most exceptional actions should appear as a drawer, panel or focused overlay while the transaction remains visible behind it.

Examples:

```text
Transaction
└── Return panel
    └── Receipt search
        └── Select original line
            └── Reason and disposition
```

```text
Transaction
└── Discount panel
    └── Enter discount
        └── Manager approval
            └── Return to selected line
```

```text
Tender
└── Stored-value panel
    └── Scan account
        └── Apply balance
            └── Return to tender list
```

The underlying transaction context should remain mounted and unchanged. The cashier should not have to reconstruct their place after completing a subtask.

---

# 7. Design exceptions as resumable interruptions

Approvals, warnings and validation failures should preserve the cashier’s current context.

Every interruption should retain:

```text
transaction
selected line
current intent
active action
entered values
scanner ownership
expected return location
```

For example:

```text
Cashier selects 25% discount
→ ShelfStack determines approval is required
→ Manager authenticates
→ Manager approves 25%
→ Discount is applied
→ Same line remains selected
→ Scanner returns to sale entry
```

A poor workflow would return the cashier to the top of the transaction or require them to reopen the discount form.

This is particularly important because ShelfStack separates permission, numeric authority and approval records at the domain level. The cashier should experience that complexity as one contextual interruption rather than as separate administration. 

---

# 8. Separate warnings from interruptions

Your warning categories are correct, but they should behave differently.

| Category                | Interface behavior                                                    |
| ----------------------- | --------------------------------------------------------------------- |
| **Information**         | Display quietly; no acknowledgment                                    |
| **Warning**             | Show persistently but allow continued scanning                        |
| **Approval**            | Allow transaction building; block the restricted result or completion |
| **Blocker**             | Prevent tender or completion and provide a direct correction action   |
| **Immediate exception** | Interrupt because the current task cannot continue                    |

## Examples

**Noninterrupting warning**

> This sale will result in −1 available.

The line is added and the cashier continues scanning.

**Deferred blocker**

> Exact inventory unit required.

The line may remain visible, but Tender is unavailable until the unit is selected.

**Immediate exception**

> This exact unit was already sold.

The current scan cannot create a line, so the cashier must receive an immediate focused response.

The summary should show the number of unresolved issues, while each affected line carries its own indicator.

---

# 9. Make the primary action reflect the next cashier decision

The primary button should be dynamic.

| Situation                        | Primary action                                    |
| -------------------------------- | ------------------------------------------------- |
| Empty transaction                | Continue scanning                                 |
| Valid transaction                | **Tender $24.82**                                 |
| Blocked transaction              | **Resolve 2 blockers**                            |
| In tender with balance remaining | **Add payment $10.00**                            |
| Fully settled                    | **Complete transaction**                          |
| Completion succeeded             | **Next transaction**                              |
| Recoverable failure              | **Retry completion** or another explicit recovery |
| Receipt printed                  | **Next transaction**                              |

Avoid generic buttons such as **Continue**, **Submit** or **Save**.

The button should tell the cashier what will happen and, where useful, show the amount.

---

# 10. Model tender as a focused calculator

Tender should feel different from merchandise entry, but it should still be part of the same transaction.

## Tender workspace

```text
AMOUNT DUE                                      $24.82

Tender entries
Cash                                             $10.00
Card                                             $10.00

REMAINING                                         $4.82

[Cash] [Card] [Gift card] [Other]
```

For refunds:

```text
REFUND DUE                                      $24.82

Recommended refund
Gift card restoration                            $20.00
Original card                                     $4.82
```

Tender mode should:

* lock commercial line editing;
* make the remaining amount prominent;
* suggest the most likely tender amount;
* provide numeric-keypad entry;
* clearly distinguish received and refunded tenders;
* display external card approval state;
* explain what must occur before an approved card tender can be removed.

The cashier should be able to back out of tender only when provisional tender activity has been safely removed or reversed.

---

# 11. Treat completion failure as its own designed workflow

ShelfStack’s atomic internal completion protects the database, but standalone card processing creates a gap between external approval and internal completion. 

The failure screen therefore needs to answer four questions:

1. **Did ShelfStack complete the transaction?**
2. **Was an external payment approved?**
3. **What financial or inventory effects were posted?**
4. **What must the cashier do next?**

Example:

```text
TRANSACTION NOT COMPLETED

The card terminal approval was recorded, but ShelfStack could not
complete the transaction.

Card approved:       $42.17
Terminal reference:  837164
ShelfStack receipt:  Not assigned
Inventory posted:    No

Next action:
[Retry completion]

Do not process the card again.
```

This is substantially better than returning the cashier to an editable transaction with a generic validation error.

---

# 12. Replace CRUD endpoints with cashier-oriented commands

The UI should not be built primarily around forms that directly manipulate individual records.

Instead, the POS should invoke domain-level commands such as:

```text
StartTransaction
ResolveScan
AddSaleLine
StartLinkedReturn
AddUnlinkedReturn
ChangeLineQuantity
RemoveLine
ApplyDiscount
RequestApproval
SuspendTransaction
RecallTransaction
EnterTender
RemoveTender
CompleteTransaction
CancelTransaction
PrintReceipt
```

Each command response should return the cashier-facing workspace state.

A useful conceptual response object would look like:

```text
POSWorkspaceState
- transaction
- lines
- totals
- selected_line
- entry_intent
- scanner_context
- warnings
- approval_requirements
- blockers
- tender_state
- available_actions
- primary_action
- focus_target
```

This creates an anti-corruption layer between the complex ShelfStack domain model and the focused cashier interface.

The domain can still maintain separate:

* transactions;
* lines;
* reservations;
* taxes;
* discounts;
* approvals;
* tenders;
* inventory movements;
* stored-value entries.

The front end receives one coherent operational projection.

---

# 13. Use a state machine for the workspace

The POS interface should have an explicit state machine rather than relying on scattered controller conditions.

```text
READY
  ├── start transaction ───────────────→ BUILD
  ├── scan merchandise ────────────────→ BUILD
  └── recall transaction ──────────────→ BUILD

BUILD
  ├── select tender ───────────────────→ TENDER
  ├── suspend ─────────────────────────→ READY
  ├── cancel ──────────────────────────→ READY
  └── temporary task ──────────────────→ BUILD.TASK

TENDER
  ├── return to editing ───────────────→ BUILD
  ├── complete ────────────────────────→ PROCESSING
  └── tender task ─────────────────────→ TENDER.TASK

PROCESSING
  ├── success ─────────────────────────→ RECEIPT
  └── failure ─────────────────────────→ RECOVERY

RECOVERY
  ├── retry ───────────────────────────→ PROCESSING
  ├── repair tender ───────────────────→ TENDER
  └── authorized intervention ─────────→ RECOVERY

RECEIPT
  └── next transaction ────────────────→ READY
```

Temporary tasks should be nested states rather than application pages:

```text
BUILD.RETURN
BUILD.DISCOUNT
BUILD.PRICE_OVERRIDE
BUILD.EXACT_UNIT
BUILD.APPROVAL
BUILD.RECEIPT_LOOKUP

TENDER.CASH
TENDER.CARD
TENDER.STORED_VALUE
TENDER.REFUND
```

---

# 14. Recommended keyboard model

The exact keys can remain configurable, but the interaction conventions should be fixed.

| Input          | Suggested behavior                                |
| -------------- | ------------------------------------------------- |
| Scan           | Add or resolve according to current intent        |
| `Enter`        | Accept highlighted result or confirm current task |
| `Escape`       | Cancel current task and restore sale entry        |
| Arrow keys     | Move selected transaction line or result          |
| `+` / `−`      | Adjust selected-line quantity                     |
| `Delete`       | Remove selected pending line                      |
| Function key   | Tender                                            |
| Function key   | Return mode                                       |
| Function key   | Transaction actions                               |
| Function key   | Suspend                                           |
| Function key   | Receipt lookup                                    |
| Numeric keypad | Quantity, price and tender entry                  |

The interface should display shortcut hints beside actions rather than requiring memorization.

---

# 15. Practical implementation order

This POS refinement should occur **before Phase 7 reporting**, while avoiding a complete visual redesign of the entire application.

## Step 1 — Establish the POS interaction contract

Define:

* visible workspace states;
* entry intents;
* scanner ownership;
* selected-line behavior;
* warning and blocker behavior;
* primary-action rules;
* focus restoration;
* recovery requirements.

## Step 2 — Build the persistent shell

Implement:

* register header;
* entry field;
* transaction-line region;
* summary region;
* action region;
* global scanner listener;
* keyboard command routing.

## Step 3 — Refactor ordinary sale

Make the standard workflow:

```text
Scan
→ line appears
→ continue scanning
→ Tender
```

Do not begin by implementing every exception.

## Step 4 — Add contextual exceptions

In this order:

1. quantity and line removal;
2. product and exact-unit selection;
3. discounts and price overrides;
4. linked returns;
5. unlinked returns;
6. approvals;
7. suspension and recall;
8. stored-value issuance.

## Step 5 — Build tender and completion onto the same shell

Tender, completion, recovery and receipt should consume the interaction contract rather than introducing a second unrelated POS design.

---

## Governing design principle

The cashier-facing POS should be understood as:

> **One transaction, one workspace, one current task, and one obvious next action.**

ShelfStack’s domain separation remains correct: completed transactions stay immutable, reservations remain explicit, stored value uses its ledger, approvals remain auditable and completion remains atomic. 

The UX layer should conceal that separation during ordinary use and reveal only the specific facts the cashier needs to make the next decision.
