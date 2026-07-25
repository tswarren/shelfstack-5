# POS Shell and Workspace

## Purpose

The ShelfStack register should operate as a dedicated cashier workspace rather than a series of general application pages.

The workspace supports five primary presentations:

```
Ready
Transaction
Tender
Recovery
Receipt
```

These presentations describe what the cashier can currently do. They do not replace the underlying transaction, tender, session, inventory, or Stored Value domain states.

The POS shell should feel like a continuous workspace even when individual actions are processed through separate requests or routes.

---

# 1\. Governing Principles

## Dedicated POS shell

The register uses a dedicated POS layout optimized for:

* rapid scanning;  
* keyboard and numpad operation;  
* compact information density;  
* minimal navigation;  
* clear transaction totals;  
* predictable focus;  
* recovery from interrupted requests.

The cashier should not need to leave the POS shell for ordinary register work.

Supporting Product, Customer, Stored Value, receipt, and customer-order workflows should open within the register workspace.

## One authoritative presentation

ShelfStack derives the current presentation from persisted business facts.

The browser does not independently decide whether the register is in Ready, Transaction, Tender, Recovery, or Receipt.

Conceptually:

```
Business day
+ POS session
+ active transaction
+ tender state
+ completion state
+ recovery conditions
→ current POS presentation
```

A page refresh, browser navigation, or failed request should restore the correct presentation from authoritative state.

## Processing is not a persisted presentation

A request may temporarily place the interface in a processing condition:

```
Adding item…
Recording tender…
Completing transaction…
```

Processing is temporary client or request state. It is not a sixth POS presentation.

While processing:

* duplicate submissions are blocked;  
* relevant controls are disabled;  
* focus remains stable where possible;  
* the final presentation is derived from the request result.

## No empty transactions from navigation

Opening a lookup, selecting an entry intent, attaching a staged Customer, or navigating through Ready must not create an empty transaction.

The first valid unit of customer work creates the transaction atomically.

Examples include:

* adding a Product;  
* submitting an Open Ring line;  
* submitting a Stored Value issuance or reload;  
* selecting Customer Order pickup lines.

A failed first action must not leave an empty or partially initialized transaction.

## Commercial editing and tendering remain distinct

Transaction is the editable commercial workspace.

Tender is the settlement workspace.

Once unresolved tender activity exists, ShelfStack must protect the commercial facts from unsafe editing. The cashier may return to Transaction only when tender state can be safely removed, reversed, or otherwise resolved.

## Visible actions remain authoritative

Keyboard shortcuts, scanner commands, and numpad accelerators improve speed, but every important operation must have a visible and accessible control.

A shortcut must never be the only way to:

* enter Tender;  
* complete a transaction;  
* suspend or cancel;  
* apply a discount;  
* begin a return;  
* print a receipt;  
* recover from a tender problem.

---

# 2\. Operational Prerequisites

The POS workspace requires:

1. an open Business Day for the store;  
2. an open POS Session for the current user;  
3. permission to access and perform the requested POS operation.

These prerequisites are operational shell conditions rather than POS presentations.

## Business Day required

When no Business Day is open, the register should show an operational message and permitted actions rather than Ready.

Example:

```
No business day is open.

[ Open Business Day ]
[ Return to Main Application ]
```

The available actions depend on the user’s permissions.

## POS Session required

When the Business Day is open but the current user has no open session, the register should show session-opening controls.

Example:

```
No POS session is open.

Register: Register 2
Drawer: Drawer 2

[ Open Session ]
```

Once the session is opened, the workspace proceeds to the appropriate Ready or active-transaction presentation.

## Register locking and session takeover

Register locking, same-user unlocking, and authorized access to another user’s session are deferred.

For this milestone, the governing assumption is:

```
Authenticated user
→ their open POS session
→ their active transaction
```

These deferred capabilities are not prerequisites for the POS shell.

---

# 3\. Shared Shell Structure

Ready, Transaction, and Tender should retain a consistent overall geometry.

A recommended structure is:

```
┌──────────────────────────────────────────────────────────┐
│ Register header                                           │
├─────────────────────────────────┬────────────────────────┤
│ Primary workspace               │ Transaction/session     │
│                                 │ summary and actions      │
│                                 │                         │
│                                 │                         │
└─────────────────────────────────┴────────────────────────┘
```

## Register header

The persistent header may show:

* store or register identity;  
* current user;  
* Business Day;  
* POS Session status;  
* current presentation;  
* navigation back to Store Operations where permitted.

The header should avoid unnecessary cash or financial totals when customer-visible.

## Primary workspace

The left or primary area contains the current work:

* scan and search;  
* line entry;  
* lookup results;  
* Tender controls;  
* Recovery instructions;  
* completed Receipt.

## Summary and action area

The right or secondary area may contain:

* transaction totals;  
* Customer summary;  
* readiness status;  
* session actions;  
* tender summary;  
* Receipt actions;  
* contextual warnings.

The summary area should remain stable enough that cashiers do not need to relearn the screen between Transaction and Tender.

## Sensitive register information

The customer-visible register shell should not display sensitive accountability information such as:

* expected drawer cash;  
* cash variance;  
* detailed tender totals;  
* net sales totals;  
* reconciliation information.

These belong in protected X/Z reports or other authorized reporting surfaces.

The register may display limited operational indicators, such as a non-sensitive recommendation that a cash drop may be appropriate.

---

# 4\. Entry Intents and Workspace Context

Sale, Return, Open Ring, Customer Order Pickup, and Stored Value are not separate persisted transaction states.

They are entry intents that change how the next valid action is interpreted.

Examples:

```
Sale intent
→ scan adds a sale line

Return intent
→ scan identifies an item for return

Open Ring intent
→ opens the Open Ring editor

Pickup intent
→ lookup resolves Customer Orders or Product Requests

Stored Value intent
→ opens issuance or reload workflow
```

Other temporary workspace contexts may include:

* staged Customer;  
* selected transaction line;  
* pending transaction discount;  
* tax exemption workflow;  
* Product lookup;  
* Customer lookup;  
* Stored Value lookup.

These contexts should not override authoritative transaction or tender state.

---

# 5\. Ready Presentation

## Purpose

Ready represents an open POS Session with no active open transaction.

It is the starting point for new customer work and operational register actions.

## Ready eligibility

Ready may be shown only when:

* the Business Day is open;  
* the current user has an open POS Session;  
* that session has no active open transaction requiring Transaction, Tender, Recovery, or Receipt.

Suspended transactions do not prevent Ready.

If an active transaction exists, ShelfStack must restore that transaction rather than showing Ready.

## Ready workspace

The primary Ready area should include:

* scan and search input;  
* Product lookup;  
* Customer lookup;  
* Stored Value lookup;  
* Receipt lookup;  
* Customer Order or pickup lookup;  
* Return;  
* Open Ring;  
* Customer Order Pickup;  
* Gift Card or Stored Value issuance/reload;  
* suspended transactions.

The exact presentation may use visible buttons, keyboard hints, or both.

## Scan to start

The cashier may scan an eligible Product while in Ready.

When a unique match is found, ShelfStack should atomically:

1. create the POS transaction;  
2. assign it to the current session;  
3. add the line;  
4. create any required reservation;  
5. enter Transaction presentation.

If the scan is ambiguous or invalid:

* no transaction is created;  
* the result or error remains in Ready;  
* the cashier can resolve the ambiguity through Product lookup.

## Staged Customer

A Customer selected from Ready may be staged for the next transaction.

Example:

```
Customer for next transaction:
Jordan Lee

[ Remove ]
```

Selecting the Customer alone does not create a transaction.

When the first valid transaction work is submitted, the transaction and Customer association are created together.

## Ready entry intents

The cashier may select an entry intent before a transaction exists.

Examples:

* Return;  
* Open Ring;  
* Pickup;  
* Stored Value issue or reload.

The transaction is created only when the cashier submits valid work for that intent.

## Suspended transactions

Ready should show suspended transactions available for recall at the current store.

A suspended-transaction summary may include:

* suspension time;  
* original cashier;  
* Customer;  
* item count;  
* transaction amount;  
* identifying note.

Recalling a suspended transaction restores it into Transaction after applying the defined recall and refresh rules.

## Session and register actions

The secondary Ready area may include:

* Cash Movement;  
* Session X Report;  
* No Sale;  
* Close Session;  
* Store Operations.

Actions appear only when permitted.

### No Sale

No Sale is an explicit, audited drawer-opening operation.

It is not represented as a cash movement and does not change the expected cash balance.

### Cash-drop indication

Ready may display a passive `Drop` indicator when configured cash thresholds are crossed.

The indicator:

* communicates that a drop may be appropriate;  
* does not itself perform the movement;  
* is not a replacement for Cash Movement;  
* should not expose the estimated drawer total;  
* should be accessible without requiring hover.

---

# 6\. Transaction Presentation

## Purpose

Transaction is the editable workspace for building and reviewing customer activity before settlement.

It supports both ordinary sales and more complex mixed activity.

## Supported work

Transaction may contain:

* Product sale lines;  
* Product return lines;  
* Open Ring sale lines;  
* Open Ring return lines;  
* Stored Value issuance or reload lines;  
* Customer Order pickup lines;  
* line discounts;  
* transaction discounts;  
* promotions;  
* price overrides;  
* tax exemptions;  
* Customer association.

Mixed sale and return lines may exist in the same transaction.

## Transaction layout

The primary area should emphasize:

* scan and search;  
* current entry intent;  
* transaction line list;  
* selected-line editing;  
* Product, Customer, and Stored Value lookup;  
* warnings and validation messages.

The summary area should emphasize:

* Customer;  
* merchandise total;  
* discounts;  
* returns;  
* tax;  
* transaction total;  
* amount currently due or refundable;  
* readiness status;  
* primary actions.

## Scan and search

The scan field remains the primary Product-entry control.

It may resolve:

* Product identifiers;  
* Variant identifiers;  
* ISBN-10 normalized to ISBN-13;  
* exact Inventory Unit identifiers;  
* Stored Value identifiers where context permits;  
* commands where the optional command parser applies.

A populated scan field always takes precedence over workflow-advancement shortcuts.

## Line selection

Selecting a line establishes selected-line context.

Available actions may include:

* change quantity;  
* remove line;  
* apply or remove discount;  
* apply price override;  
* change tax category where authorized;  
* review return source or disposition;  
* choose exact Inventory Unit where required.

Actions are constrained by:

* line type;  
* transaction editability;  
* user authority;  
* approval requirements;  
* inventory tracking mode;  
* tender state.

## Inventory interaction

Adding a quantity-tracked Product sale line creates or updates an inventory reservation.

Adding an individually tracked item requires selecting the exact Inventory Unit.

Removing or reducing a line updates or releases the corresponding reservation.

Return lines apply the defined return-disposition behavior but do not post inventory until completion.

## Customer association

The cashier may:

* attach a Customer;  
* replace the Customer;  
* remove the Customer;  
* view or edit Customer details.

Changing the Customer may cause ShelfStack to reevaluate:

* membership or Customer discounts;  
* Customer-specific pricing;  
* tax exemptions;  
* Customer Order associations;  
* transaction readiness.

## Readiness summary

Transaction should show a consolidated readiness area identifying anything that prevents Tender or completion.

Examples:

* no transaction lines;  
* unresolved approval;  
* missing return reason;  
* missing return disposition;  
* incomplete tax exemption;  
* missing exact Inventory Unit;  
* invalid Stored Value line;  
* incomplete Customer Order fulfillment data.

Readiness problems should appear before the cashier enters Tender whenever possible.

They do not require Recovery presentation.

## Transaction actions

Typical actions include:

* Begin Tender;  
* Suspend;  
* Cancel Transaction;  
* Transaction Discount;  
* Tax Exemption;  
* Customer;  
* Return;  
* Open Ring;  
* Pickup;  
* Stored Value.

## Suspend

Suspending:

* preserves the transaction;  
* preserves reservations;  
* removes it from the active session workspace;  
* returns the register to Ready;  
* makes the transaction available for same-store recall.

Suspension is prohibited while unresolved tender activity exists.

## Cancel

Cancelling an open transaction:

* changes it to its cancelled state;  
* releases reservations;  
* records the actual cancelling user;  
* returns the register to Ready.

Completed transactions cannot be cancelled in place.

## Entering Tender

The cashier may enter Tender only when the transaction satisfies pre-tender requirements.

Entering Tender does not complete the transaction. It changes the workspace from commercial editing to settlement.

---

# 7\. Tender Presentation

## Purpose

Tender settles the transaction’s remaining financial balance.

Tender is a distinct presentation of the same open transaction.

## Direction derived from balance

The POS should derive the tender direction rather than asking the cashier to choose between payment and refund.

```
Positive remaining balance
→ payment is due

Negative remaining balance
→ refund is due

Zero remaining balance
→ transaction is settled
```

The UI may use customer-facing labels such as:

* Amount Due;  
* Refund Due;  
* Settled.

Internal tender records may continue to preserve explicit received and refunded directions.

## Tender layout

The primary area should contain:

* available tender methods;  
* tender amount controls;  
* Stored Value resolution;  
* standalone card confirmation;  
* cash-entry controls;  
* recorded tenders;  
* tender warnings.

The summary area should contain:

* transaction total;  
* tendered or refunded amounts;  
* remaining balance;  
* readiness and completion status;  
* Return to Transaction where safe;  
* Complete Transaction.

## Tender methods

Initial tender workflows may include:

* cash received;  
* cash refunded;  
* standalone card received;  
* standalone card refunded;  
* Stored Value redemption;  
* Stored Value refund or restoration;  
* other configured tenders.

Split tender is supported.

Each tender is recorded separately rather than collapsing all settlement into one net payment record.

## Cash tender

For cash received, the interface may capture:

* amount tendered;  
* amount applied;  
* change due.

The cashier-facing workflow should emphasize:

* amount due;  
* amount tendered;  
* change.

For cash refunds, ShelfStack records the refunded amount as an explicit refund tender.

## Standalone card tender

Because card processing occurs on a separate terminal, ShelfStack should capture only the approved result the cashier can verify.

Possible fields include:

* amount;  
* card brand;  
* last four digits;  
* authorization code;  
* terminal reference.

ShelfStack must not store full card data.

The cashier remains responsible for confirming that the terminal transaction succeeded before recording the tender in ShelfStack.

## Stored Value tender

Stored Value resolution should show:

* account type;  
* masked identifier;  
* status;  
* available balance;  
* proposed amount.

The cashier must explicitly confirm redemption or refund.

Scanning or resolving an account never changes its balance by itself.

## Commercial-editing lock

Pending, authorized, completed, or otherwise unresolved tender activity may prevent commercial editing.

The transaction must not allow changes that would invalidate recorded settlement.

## Returning to Transaction

The cashier may return to Transaction only when tender state permits it safely.

Examples:

* no tender has been recorded;  
* reversible draft tender information can be discarded;  
* recorded tenders have been removed or voided according to domain rules.

The cashier must not be returned to editable Transaction while external payment activity remains unresolved.

## Completion readiness

Completion requires:

* transaction readiness satisfied;  
* no unresolved approval;  
* no pending or authorized tender requiring further action;  
* no `void_required` tender;  
* remaining balance equal to zero;  
* all Stored Value and inventory postings valid;  
* valid completion idempotency protection.

## Completion

Completion is one authoritative operation.

It:

1. validates the final transaction;  
2. records completed tenders;  
3. posts inventory movements;  
4. posts Stored Value entries;  
5. assigns the receipt number;  
6. records completion attribution;  
7. commits the completed transaction;  
8. transitions the workspace to Receipt.

There is no separate confirmation step after successful completion unless required for a specific high-risk workflow.

## Completion failure

Ordinary completion failures should normally remain in Tender as an inline failure state.

Example:

```
Transaction could not be completed.

Stored Value account balance changed.
Review the tender and try again.
```

The failure should:

* preserve the open transaction;  
* preserve valid recorded facts;  
* explain the corrective action;  
* prevent duplicate submission.

A dedicated Recovery presentation is used only when ordinary Tender controls cannot resolve the problem safely.

---

# 8\. Recovery Presentation

## Purpose

Recovery handles persisted conditions that block ordinary Transaction or Tender progression and cannot safely be resolved through normal editing.

Recovery is not a general error page.

## Initial Recovery scope

The primary confirmed Recovery case is a tender in `void_required` state.

This may occur when:

* external card activity may have succeeded;  
* ShelfStack cannot safely remove or finalize the tender;  
* the cashier must confirm or perform a void externally;  
* ordinary retry could duplicate payment.

Other Recovery cases may be added later as external integrations become more complex.

## What does not require Recovery

The following should normally remain in Transaction or Tender:

* missing required fields;  
* validation errors;  
* incomplete return information;  
* missing approvals;  
* ordinary Stored Value balance changes;  
* unavailable Product;  
* failed printer output;  
* duplicate scan;  
* ambiguous lookup result.

These should be resolved through readiness warnings or inline failures.

## Recovery content

Recovery must clearly state:

1. what happened;  
2. what financial or operational condition is uncertain;  
3. why normal progression is blocked;  
4. what the cashier must verify or do;  
5. whether authorization is required;  
6. what will happen after resolution.

Example:

```
Card tender requires void confirmation

A $42.18 card authorization may still exist on the external terminal.
Do not process another card payment.

1. Verify the transaction on the card terminal.
2. Void the authorization if required.
3. Confirm the result below.

[ Authorization voided ]
[ Authorization did not exist ]
[ Request supervisor ]
```

## Recovery restrictions

Recovery must not provide generic actions that could conceal or duplicate financial activity.

It should not offer:

* begin another tender;  
* clear all tenders;  
* edit transaction lines;  
* cancel the transaction without resolving the blocker;  
* force completion without an authorized domain action.

## Recovery resolution

When the blocking condition is resolved, ShelfStack derives the next presentation from authoritative state.

Possible destinations include:

```
Transaction
Tender
Receipt
```

Recovery itself does not decide the destination independently.

---

# 9\. Receipt Presentation

## Purpose

Receipt confirms successful completion and provides customer-facing follow-up actions.

It is a hard workflow transition from the open transaction to completed history.

A literal full-page browser reload is not required, but the cashier must no longer see or interact with the transaction as editable.

## Receipt content

The Receipt presentation may show:

* completion confirmation;  
* receipt number;  
* transaction total;  
* received or refunded tender summary;  
* change;  
* Customer where appropriate;  
* receipt preview;  
* print status or print error;  
* Stored Value activity.

The completed transaction is read-only.

## Receipt actions

Available actions may include:

* Print Receipt;  
* Gift Receipt;  
* Stored Value Slip;  
* Begin Linked Return;  
* View Completed Transaction;  
* Next Transaction.

## Customer receipt

The Customer Receipt is itemized and generated from completed transaction facts.

It may contain:

* historical lines;  
* historical prices;  
* discounts and overrides;  
* taxes;  
* totals;  
* tenders;  
* Stored Value activity;  
* receipt number and date;  
* current store header and footer.

## Gift receipt

The Gift Receipt is non-itemized and price-opaque.

It includes:

* current store header;  
* `GIFT RECEIPT` label;  
* original receipt number;  
* original transaction date;  
* scannable receipt-number barcode;  
* store-defined Gift Receipt footer.

It omits:

* item descriptions;  
* quantities;  
* prices;  
* discounts;  
* tax;  
* totals;  
* tenders;  
* payment details;  
* Customer information;  
* Stored Value activity.

The Gift Receipt locates the original transaction but does not independently authorize a return.

## Stored Value slip

When applicable, the Receipt presentation may offer a compact informational Stored Value slip showing:

* customer-facing account type;  
* masked identifier;  
* completed activity;  
* amount;  
* balance immediately following the posting;  
* receipt reference.

## Printing

Printing occurs after completion.

A print failure:

* does not reverse completion;  
* does not remove the receipt number;  
* does not repeat commercial postings;  
* does not prevent the cashier from continuing.

The cashier may:

* retry;  
* choose another printer where supported;  
* continue without printing.

## Next transaction

Selecting Next Transaction returns the register to Ready.

The previous transaction remains available through Receipt Lookup and completed transaction history.

---

# 10\. Presentation Transitions

## Primary workflow

```
Ready
  │
  │ First valid customer work
  ▼
Transaction
  │
  ├── Suspend ───────────────► Ready
  │
  ├── Cancel ────────────────► Ready
  │
  │ Begin Tender
  ▼
Tender
  │
  ├── Safely return to edit ─► Transaction
  │
  ├── Blocking tender issue ─► Recovery
  │
  │ Complete successfully
  ▼
Receipt
  │
  │ Next Transaction
  ▼
Ready
```

## Recovery transitions

```
Recovery
  ├── blocker resolved; editing allowed ─► Transaction
  ├── blocker resolved; settlement remains ─► Tender
  └── completion confirmed ────────────────► Receipt
```

## Refresh restoration

On any request or refresh, ShelfStack should determine:

```
No active transaction
→ Ready

Open, editable transaction
→ Transaction

Open transaction with settlement context
→ Tender

Open transaction with dedicated blocker
→ Recovery

Just-completed transaction in completion workflow
→ Receipt
```

Receipt restoration may use a completion redirect, flash context, or another explicit navigation result. A completed transaction should not be mistaken for an active transaction merely because the user refreshes its page.

---

# 11\. Keyboard and Numpad Model

## General rules

### Enter

`Enter` activates or submits the currently focused control.

Examples:

* submit scan;  
* choose lookup result;  
* confirm tender;  
* activate button.

### Numpad Enter

When the browser positively identifies `NumpadEnter`, it may act as an optional register accelerator.

Recommended behavior:

```
Scan field contains input
→ submit scan

Scan field is empty and Transaction is eligible
→ enter Tender
```

When Numpad Enter cannot be positively distinguished from ordinary Enter, ShelfStack should fail closed and treat it as ordinary Enter.

### Ctrl+Enter

`Ctrl+Enter` advances the overall transaction workflow.

| Presentation | Behavior |
| :---- | :---- |
| Ready | No transaction progression |
| Transaction, ready | Enter Tender |
| Transaction, blocked | Focus readiness summary |
| Tender, balance remaining | Focus tender method or amount |
| Tender, settled and ready | Complete transaction |
| Recovery | No generic action |
| Receipt | Plain Enter remains Next Transaction |

A populated scan field must prevent `Ctrl+Enter` from abandoning entered scan data.

### Escape

`Escape` exits transient context where safe.

Examples:

* close lookup results;  
* clear entry intent;  
* close non-destructive panel;  
* return from a selected-line editor.

Escape must not:

* discard recorded tender activity;  
* cancel the transaction;  
* dismiss Recovery;  
* abandon an approval without warning.

### Up and Down

Up and Down navigate the active context:

* lookup results;  
* transaction lines;  
* option lists.

They should not produce unexpected document scrolling while a POS result list owns focus.

## Shortcut suppression

Global shortcuts should be ignored when:

* an approval or authentication prompt owns focus;  
* a modal dialog owns focus;  
* a multiline input owns focus;  
* an unsaved form would be abandoned;  
* an IME composition is active;  
* the key event is repeating;  
* the relevant request is already in flight.

---

# 12\. Focus and Accessibility

## Focus restoration

After an operation, focus should move to the next expected cashier action.

Examples:

| Operation | Focus destination |
| :---- | :---- |
| Product added | Scan field |
| Lookup closed | Previous initiating control |
| Tender added with balance remaining | Tender method or amount |
| Tender settles transaction | Complete action |
| Completion succeeds | Next Transaction or Print Receipt |
| Readiness failure | First blocking issue |
| Recovery begins | Recovery heading or first required action |

## Status announcements

Important status changes should use accessible live announcements.

Examples:

* Line added  
* Product not found  
* Customer attached  
* Tender recorded  
* Balance remaining  
* Transaction completed  
* Print failed  
* Recovery required

Announcements should be concise and should not repeat the entire screen.

## Control semantics

Use controls according to their actual behavior:

* buttons for actions;  
* links for navigation;  
* radio buttons only for persistent mutually exclusive selection;  
* checkboxes for independent toggles;  
* listbox or combobox patterns for searchable results;  
* dialogs for bounded modal work.

Discount chips, tender choices, and similar action controls should not automatically be implemented as radio groups when activation immediately performs an action or opens an editor.

## Error visibility

Errors must not rely solely on:

* color;  
* toast messages;  
* hover;  
* transient animation.

The affected area should retain a visible explanation until resolved or dismissed.

---

# 13\. Supporting Capability Dependencies

The POS shell consumes, but does not own, several supporting capabilities.

| POS need | Supporting capability |
| :---- | :---- |
| Product search, scan resolution, and item detail | Product domain and POS-native Product Lookup |
| Customer creation, staging, and attachment | Customer Records and POS-native Customer Lookup |
| Stored Value balance and account resolution | Stored Value domain and POS-native Stored Value Lookup |
| Customer Receipt, Gift Receipt, and reprints | Receipt Documents and Printing |
| Pickup and special-order fulfillment | Customer Order or Product Request domain |
| Manager authorization | POS Approval framework |
| Inventory availability and reservations | Inventory and POS Reservation behavior |
| Historical transaction display | Completed POS snapshots |
| Settlement and completion | POS Tender and completion services |

The POS workspace coordinates these capabilities without duplicating their business rules.

---

# 14\. Deferred Capabilities

The following are not prerequisites for this milestone:

* Register Lock;  
* same-user unlock;  
* authorized session takeover;  
* acting-user switching;  
* cross-user operational session access;  
* cross-device control;  
* detailed session-access auditing;  
* configurable keyboard mappings;  
* direct integrated card-terminal control;  
* advanced printer-fleet management;  
* persisted print-event auditing;  
* exact historical receipt facsimiles.

The workspace should preserve clean architectural seams for these additions, but their implementation should not block the core revamp.

---

# 15\. Remaining Implementation Decisions

The following details may be resolved during implementation planning without changing this workspace contract.

## Visual design

* exact panel widths;  
* responsive breakpoints;  
* typography;  
* compact versus expanded line display;  
* mobile or tablet behavior;  
* precise button placement.

## Command acceleration

* final numpad command vocabulary;  
* optional command parser;  
* shortcut aliases;  
* cashier training and discoverability.

## Tender controls

* exact cash-entry component;  
* standalone-card confirmation form;  
* Stored Value refund-selection layout;  
* amount presets.

## Recovery catalogue

* additional external-payment recovery conditions;  
* future integrated-terminal failures;  
* network or posting interruptions requiring dedicated Recovery.

## Printing transport

* browser printing;  
* direct thermal printing;  
* printer selection;  
* automatic print defaults;  
* device-specific output.

## Permissions

* final permission names;  
* which Receipt actions require separate authority;  
* which lookup details are restricted;  
* approval thresholds.

---

# 16\. Milestone Summary

## Included

### POS shell

* Dedicated register layout  
* Shared Ready, Transaction, and Tender geometry  
* Authoritative state restoration  
* Scanner-, keyboard-, and numpad-oriented interaction  
* Inline supporting lookups  
* Clear readiness and error handling

### Ready

* Scan to begin  
* Entry intents  
* Staged Customer  
* Product, Customer, Stored Value, Receipt, and Pickup lookup  
* Suspended transaction recall  
* Session actions

### Transaction

* Sale and Return lines  
* Open Ring  
* Stored Value issue and reload  
* Customer attachment  
* Discounts, overrides, and exemptions  
* Inventory reservations  
* Suspend and Cancel  
* Readiness summary

### Tender

* Payment and refund direction derived from balance  
* Split tenders  
* Cash, card, and Stored Value workflows  
* Tender-state editing lock  
* Safe return to Transaction  
* Atomic completion

### Recovery

* Dedicated handling for unresolved tender conditions  
* Clear verification and resolution instructions  
* Preservation of transaction and tender facts  
* No unsafe generic bypasses

### Receipt

* Completion confirmation  
* Customer Receipt  
* Non-itemized Gift Receipt  
* Stored Value slip  
* Printing and retry  
* Receipt Lookup integration  
* Next Transaction

## Deferred

* Register Lock  
* Session takeover and acting-user switching  
* Cross-device control  
* Detailed session-access audit  
* Integrated payment-terminal automation  
* Advanced print infrastructure

## Governing rule

> The ShelfStack POS shell is a continuous, authoritative cashier workspace. Ready begins new work, Transaction builds commercial facts, Tender settles them, Recovery protects uncertain financial activity, and Receipt presents the completed result. Each presentation is derived from persisted domain state, while supporting lookups and document services remain integrated without taking ownership of their underlying business rules.

This can serve as the milestone’s governing POS workspace specification and later be divided into separate Ready, Transaction, Tender, Recovery, and Receipt implementation plans.  
