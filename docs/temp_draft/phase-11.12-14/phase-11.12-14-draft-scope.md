# Phase 11 — Point of Sale Completion and Operations

**Status:** In progress — **Completed:** Phase 11.0, Phase 11.1 · **Active:** Phase 11.2 · **Scheduled:** Phase 11.3, Phase 11.4  
**Authoritative phase plans:** [phase-11.2…](../../implementation/phases/phase-11.2-register-workflow-refinement.md) · [phase-11.3…](../../implementation/phases/phase-11.3-pos-operations-workspace.md) · [phase-11.4…](../../implementation/phases/phase-11.4-pos-policy-and-lifecycle-hardening.md)  
**This folder:** background design packet only (not governing)  
**Depends on:** Core POS, corrections and stored value, reporting and reconciliation, customer records, and the current POS workspace foundation  
**Primary areas:** Register, POS Operations, approvals, tendering, returns, refund settlement, sessions, business days, X/Z reporting, and POS lifecycle hardening

## Goal

Complete ShelfStack’s point-of-sale experience as a coherent, cashier-centered operating environment.

The earlier POS work established the required business rules, data integrity, transaction lifecycle, cash accountability, reporting, and basic user interface. Phase 11 finishes the user-facing system built around those foundations.

The completed system should clearly distinguish among:

* **ShelfStack**, the normal application experience;  
* **Store Workspace**, the contextual return destination shown when leaving the focused POS environment;  
* **Register**, where customer transactions are conducted;  
* **Operations**, where the conditions and accountability surrounding those transactions are managed;  
* **Register Operations**, covering the current POS session, workstation, and drawer;  
* **Store Operations**, covering the current business day and activity across the store.

Phase 11 is not intended to replace the existing POS domain model or rewrite posting services. Its purpose is to make the implemented capabilities understandable, efficient, and operationally complete while closing known gaps left by the original POS delivery.

---

# Phase summary

| Slice | Name | Status | Purpose |
| :---- | :---- | ----: | :---- |
| **11.0** | POS Baseline | Complete | Establish the operational and financial foundation of the register |
| **11.1** | Transaction Documents | Complete | Produce receipts, gift receipts, stored-value vouchers, and activity slips |
| **11.2** | Register Workflow Refinement | Active | Repair approvals, tendering, returns, and refund settlement workflows |
| **11.3** | POS Operations Workspace | Scheduled | Separate Register Operations from Store Operations and establish clear workspace navigation |
| **11.4** | POS Policy and Lifecycle Hardening | Scheduled | Close the remaining known Phase 11 gaps and verify the complete operating lifecycle |

---

# Phase 11.0 — POS Baseline

**Status:** Complete

## Purpose

Phase 11.0 established an operable point-of-sale system with the business rules and integrity controls needed to conduct transactions safely.

The result is functionally substantial. ShelfStack can manage the lifecycle of a retail transaction, interact with inventory and stored value, account for cash and tenders, preserve historical commercial facts, and support corrections and reconciliation.

The remaining issue is not an absence of core functionality. It is that several workflows still expose the implementation structure rather than guiding the cashier through the work.

## Completed capabilities

### Register lifecycle

The POS supports the major register states required for normal operation:

* Ready for customer work;  
* active transaction;  
* tendering;  
* completion recovery;  
* completed receipt.

The register can:

* begin work from a merchandise scan or product lookup;  
* build and modify a transaction;  
* add sale and return lines;  
* add open-ring lines;  
* issue or reload stored value;  
* attach or stage a customer;  
* handle customer-request pickups;  
* suspend and recall transactions;  
* cancel an open transaction;  
* tender and complete a transaction;  
* return to a ready state after completion.

The register uses a focused POS layout rather than the general ShelfStack application layout.

### Transaction integrity

The POS preserves the required financial and operational boundaries:

* completed transactions are immutable;  
* completion occurs through a single controlled posting operation;  
* receipt numbers are assigned only after successful completion;  
* failed completion does not consume a receipt number or post partial activity;  
* completed sale and return lines preserve historical commercial snapshots;  
* inventory movements, tenders, taxes, costs, and stored-value activity are posted through controlled services;  
* corrections occur through linked reversing records rather than edits to completed history.

### Pricing, discounts, taxes, and approvals

The POS supports:

* configured prices;  
* manual price overrides;  
* line and transaction discounts;  
* tax calculation;  
* tax-category overrides;  
* tax exemptions;  
* approval requirements where authority is exceeded.

However, the approval experience remains too closely tied to form structure. Approval fields are often shown preemptively on workflows that may require approval, rather than being requested only when a specific action crosses an authority boundary.

### Returns and refunds

The POS supports:

* receipt-linked returns;  
* unlinked returns;  
* product and open-ring returns;  
* return reasons;  
* return dispositions;  
* inventory effects;  
* refund tenders;  
* mixed sale-and-return transactions;  
* return quantities limited by remaining returnable quantities.

The underlying return rules are available, but the cashier experience remains underdeveloped. Linked returns require repetitive line-by-line interaction, while unlinked returns expose too many fields simultaneously without guiding the user through identification, pricing, tax, reason, disposition, and approval decisions.

### Tendering

The POS supports:

* cash payments and refunds;  
* card payments and refunds recorded from standalone terminals;  
* stored-value payments and refunds;  
* split tenders;  
* partial tenders;  
* change due;  
* tender removal or reversal according to tender state;  
* completion blocking when tenders remain unresolved;  
* recovery when externally processed tender activity must be voided.

The existing tender screen remains visually and behaviorally tied to the earlier stacked form layout. Tender-method selection, active entry forms, recorded tenders, editing, removal, voiding, totals, and completion actions compete for attention on the same screen.

### Stored value and corrections

The POS supports:

* stored-value issuance;  
* reloads;  
* redemption;  
* refund restoration;  
* stored-value ledger posting;  
* post-void corrections;  
* reversal of inventory, tender, tax, and stored-value effects;  
* durable records of corrective activity.

### Sessions, drawers, and business days

ShelfStack supports:

* opening and closing a business day;  
* opening and closing POS sessions;  
* associating a session with a POS device;  
* optional cash-drawer assignment;  
* opening cash;  
* closing cash counts;  
* expected cash calculations;  
* cash variance;  
* cash movements;  
* no-sale events;  
* session-level and business-day-level reporting.

### X reports, Z reports, and reconciliation

ShelfStack supports:

* Session X reports;  
* Session Z reports;  
* business-day X reports;  
* business-day Z reports;  
* persisted close reports;  
* reconciliation records;  
* comparison and resolution workflows;  
* finalization of reconciliations;  
* separation between live operating reports and finalized historical reporting.

### POS workspace foundation

The POS has a dedicated shell that distinguishes among Ready, Transaction, Tender, Recovery, and Receipt presentations.

This foundation improved the register’s overall structure, but it did not fully resolve the workflow design of tendering, returns, approvals, or store operations.

## Known gaps carried forward from Phase 11.0

Phase 11.0 left the following principal gaps:

* approvals are visible in advance rather than requested contextually;  
* tendering remains difficult to understand and manipulate;  
* recorded tender actions are not sufficiently clear;  
* unlinked returns present one large technical form rather than a guided workflow;  
* receipt-linked returns are repetitive and line-oriented;  
* refund-tender defaults and overrides are difficult to understand;  
* the POS-adjacent Store Operations page combines current-session and store-wide responsibilities;  
* navigation among Register, Operations, and the normal ShelfStack application is not fully formalized;  
* several permissions, policy boundaries, lifecycle edge cases, and terminology inconsistencies require final review.

These gaps form the basis for Phases 11.2–11.4.

---

# Phase 11.1 — Transaction Documents

**Status:** Complete

## Purpose

Phase 11.1 completed the customer-facing and operational documents produced by POS activity.

The objective was to ensure that completed POS activity could generate clear, printable artifacts without recalculating or reinterpreting completed history.

## Completed document classes

### Customer receipts

ShelfStack can produce a customer receipt from completed transaction facts, including the transaction’s original:

* receipt number;  
* store and register context;  
* lines and quantities;  
* prices and discounts;  
* taxes;  
* tenders;  
* totals;  
* customer information where applicable.

Historical reprints preserve the original receipt identity and are distinguishable from the original print.

### Gift receipts

Gift receipts provide appropriate proof of purchase while omitting information that should not be disclosed to the recipient, such as the original tender and selling-price details where policy requires their exclusion.

Gift receipts remain linked to the completed transaction and do not create a second commercial record.

### Stored-value vouchers

Stored-value activity can produce printable vouchers or references for the applicable operation, such as issuance, reload, redemption, refund restoration, or adjustment.

The printed document reflects posted stored-value facts rather than functioning as the stored-value ledger itself.

### Activity slips

Non-sale register activity can produce suitable operational slips, including the applicable identifying, timing, user, session, amount, reason, and reference information.

Activity slips document an event but do not replace the authoritative POS, cash-movement, or audit records.

## Phase 11.1 principles

* Printed documents are projections of authoritative posted facts.  
* Printing or reprinting cannot mutate completed activity.  
* Reprints preserve the original document identity.  
* Gift receipts do not create financial activity.  
* Stored-value vouchers do not replace ledger authority.  
* Activity slips do not replace cash or audit records.  
* Print authority is enforced by the server rather than trusted from user-supplied parameters.

---

# Phase 11.2 — Register Workflow Refinement

**Status:** Active — authoritative plan: [phase-11.2-register-workflow-refinement.md](../../implementation/phases/phase-11.2-register-workflow-refinement.md) (epic [#158](https://github.com/tswarren/shelfstack-5/issues/158))

## Goal

Refine the cashier-facing transaction workflows so that the normal path is simple and exceptional complexity appears only when required.

Phase 11.2 focuses on three major areas:

1. contextual approvals;  
2. tendering;  
3. returns and refund settlement.

The phase should preserve the accepted financial and posting rules while replacing form-driven interactions with guided workflows.

---

## 11.2.1 Contextual, exception-driven approvals

### Problem

Approval fields are currently embedded in workflows that may require approval. This makes ordinary actions appear more complicated than they are and requires the cashier to understand approval policy before ShelfStack has determined whether approval is needed.

### Target behavior

Approvals should be **contextual and exception-driven**.

The ordinary workflow should not display approval fields. Instead:

1. The cashier enters the intended action.  
     
2. ShelfStack evaluates the action against permissions, authority limits, store policy, and transaction state.  
     
3. When the user has sufficient authority, the action proceeds normally.  
     
4. When additional authority is required, ShelfStack interrupts with a focused approval prompt.  
     
5. The approval prompt explains:  
     
   * the action requiring approval;  
   * the policy or authority boundary involved;  
   * the material values being approved;  
   * the effect of approval.

   

6. After approval, ShelfStack resumes the original workflow.

### Approval scope

An approval must be attached to the specific decision being authorized, such as:

* a no-receipt return above the cashier’s limit;  
* a refund to a tender other than the recommended method;  
* a price override;  
* a discount above an authority threshold;  
* a tax override;  
* a return disposition exception;  
* a session or cash-variance exception;  
* another action explicitly governed by authority limits.

Approvals must identify whether they apply to:

* one line;  
* one tender;  
* one transaction;  
* one session action;  
* one business-day action.

### Approval invalidation

A material change to the approved action must invalidate the approval.

Examples include changing:

* the amount;  
* the tender method;  
* the affected line;  
* the refund basis;  
* the return disposition;  
* the transaction or session being authorized.

An approval for one decision must not function as unrestricted authority for subsequent changes.

### Reusable mechanism

Phase 11.2 should establish a reusable approval interaction and service boundary. Register workflows will use it first. Phase 11.3 may reuse the same mechanism for session and business-day exceptions.

---

## 11.2.2 Tender workspace redesign

### Problem

> **Note (promotion):** Phase 11 L3 already replaced the older stacked tender-entry layout with a method selector + active form. Gate 11.2C is **settlement polish** on that workspace, not a greenfield rebuild. See [phase-11.2…](../../implementation/phases/phase-11.2-register-workflow-refinement.md) §3.

The current tender screen reflects the previous stacked-element layout.

Tender method selection, entry forms, recorded tenders, settlement totals, tender actions, and completion controls are presented together. This makes it difficult to understand:

* what has already been recorded;  
* what remains due;  
* which tender is being edited;  
* whether an action means edit, remove, delete, or void;  
* when the transaction is ready to complete;  
* what must happen before returning to the transaction.

### Target tender workspace

The main tender screen should emphasize settlement state rather than the tender-entry form.

It should prominently display:

* transaction total;  
* total payments or refunds recorded;  
* remaining balance;  
* change due;  
* settlement status;  
* any completion blocker.

The tender screen should also display a clear list of recorded tenders.

Each tender should show:

* tender type;  
* payment or refund direction;  
* amount;  
* status;  
* identifying details where appropriate;  
* actions permitted for its current state.

### Primary action

The primary action should change according to settlement state:

| State | Primary action |
| :---- | :---- |
| Balance remains due | **Add tender** |
| Refund remains due | **Add refund tender** |
| Balance is settled and transaction is valid | **Complete transaction** |
| Balance is settled but completion is blocked | Show the blocker and its required resolution |

### Return to transaction

**Return to transaction** should be available when the tender state permits it.

Returning is not inherently destructive when no committed tender activity must be reversed. When returning requires an externally processed tender to be voided or another recorded action to be undone, ShelfStack must explain the consequence and route the user through the correct reversal or recovery workflow.

### Modal tender entry

Selecting **Add tender** or **Add refund tender** should open a focused modal.

The modal should include:

* available tender methods;  
* amount, defaulted appropriately;  
* method-specific fields;  
* confirmation requirements;  
* contextual approval only when required.

The cashier should not have to navigate among persistent tender-entry forms on the main screen.

### Recorded-tender interaction

Selecting a recorded tender should open a focused detail or action modal.

The available action must be based on the actual tender lifecycle.

| Tender state | Appropriate action |
| :---- | :---- |
| Entered but not externally processed | Edit or remove |
| Externally processed while transaction remains open | Void and optionally replace |
| Requires external void after failed completion | Resolve void |
| Completed as part of a completed transaction | Correct through return, post-void, or another linked reversal |
| Already voided | View only |

The interface must not use **edit**, **delete**, **remove**, and **void** as interchangeable terms.

### Split tendering

The redesigned workspace must continue to support:

* partial tenders;  
* multiple tenders;  
* cash change;  
* payment and refund directions;  
* standalone card-terminal references;  
* stored-value accounts;  
* recovery when an external card action cannot be attached;  
* completion only after all tender activity is resolved.

---

## 11.2.3 Guided return workflow

### Problem

The existing return experience exposes too much complexity at once.

Unlinked returns combine product selection, open-ring fields, source, price, quantity, reason, disposition, tax basis, cost basis, and approval details in one form.

Receipt-linked returns require repetitive line-by-line forms rather than allowing the cashier to select several items from the receipt.

### Start Return

The return workflow should begin with a focused choice:

* enter or scan a receipt number;  
* begin an unlinked return.

The workflow should then branch according to the selected path.

---

## 11.2.4 Receipt-linked returns

### Receipt lookup

When a cashier enters a valid completed receipt number, ShelfStack should open a receipt-return selector automatically.

The selector should show the eligible original lines and relevant receipt context.

### Multi-line selection

The cashier should be able to select one or more returnable lines before adding them to the current transaction.

For each line, the interface should show:

* item description;  
* original quantity;  
* quantity previously returned;  
* remaining returnable quantity;  
* original unit price;  
* selected return quantity;  
* return reason;  
* return disposition.

The workflow may provide a shared default reason or disposition, while allowing per-line overrides.

### Historical basis

Receipt-linked returns should use the original transaction’s commercial facts, including:

* original price;  
* allocated discounts;  
* tax;  
* department;  
* tax classification;  
* cost snapshot where applicable.

The cashier should not be asked to reconstruct information that is already available from the original completed transaction.

### Result

Selected return lines are added to the current transaction. The cashier may then continue adding purchases, returns, or other eligible lines before tendering the net result.

---

## 11.2.5 Unlinked product returns

The unlinked product-return path should guide the cashier through a sequence rather than presenting one comprehensive form.

### Step 1 — Identify the item

Allow the cashier to:

* scan or enter an ISBN;  
* scan or enter a SKU;  
* scan an individually tracked unit identifier where permitted;  
* search for a product or variant;  
* choose the separate open-ring return path.

### Step 2 — Confirm the matched item

Display sufficient item detail to confirm that the correct product and variant have been selected.

### Step 3 — Establish the return quantity and price

Prompt for:

* quantity;  
* proposed refund unit price.

ShelfStack should propose the refund price according to the applicable return policy.

For a no-receipt return, the current selling price may be used as the proposal when no more authoritative basis exists. The current selling price should not be treated as an unconditional rule when external receipt evidence or another policy basis is available.

### Step 4 — Reason and disposition

Prompt for:

* return reason;  
* return disposition.

The proposed disposition may be derived from product configuration, condition, reason, tracking mode, or department policy.

### Step 5 — Tax basis

Only show tax-basis decisions relevant to the selected return source.

Possible bases include:

* configured current rules;  
* explicit tax supported by an external receipt;  
* no tax refund.

Receipt-linked returns should not require a tax-basis prompt because they use original tax snapshots.

### Step 6 — Approval when required

After all material values are known, ShelfStack should determine whether approval is required.

The approval prompt should appear only when the return exceeds the cashier’s authority or violates the ordinary return policy.

### Step 7 — Add the return line

Once the workflow is valid and any required approval has been obtained, add the completed return line to the current transaction.

---

## 11.2.6 Unlinked open-ring returns

The open-ring return path should prompt for:

* department;  
* unit price;  
* quantity;  
* return reason;  
* return disposition;  
* optional description;  
* tax category or tax basis where required.

The department field should use a searchable selector supporting:

* department-code entry;  
* department-name search;  
* list selection;  
* active, postable departments only.

Only fields relevant to the selected return source and tax basis should be displayed.

---

## 11.2.7 Refund tender recommendations

### Problem

Tendering a receipt-linked refund is difficult because the current interface does not clearly distinguish between:

* the recommended refund allocation;  
* the refund tenders that have actually been recorded;  
* an exception from the recommended method.

### Proposed refund plan

When a transaction requires a net refund, ShelfStack should first produce a proposed refund plan.

The proposed plan should:

* identify eligible original tenders;  
* respect remaining refundable amounts;  
* account for any new purchases in a mixed transaction;  
* show the resulting refund allocation before it is recorded.

The cashier should be able to:

* accept the proposed plan;  
* remove a proposed refund method;  
* adjust an amount where permitted;  
* add another permitted refund tender;  
* request approval automatically when the deviation requires it.

A proposed refund line is not a completed refund tender until the cashier confirms and records it.

### Proposed default ordering

> **Superseded (2026-07-28).** Refund allocation remains **stored-value first** per [phase-11.2-refund-allocation-sv-first.md](../../implementation/decisions/phase-11.2-refund-allocation-sv-first.md) and [architectural-locks.md](../../implementation/architectural-locks.md#refund-allocation-priority-v1). The cash → card → stored value → other ordering below is **not** accepted for Phase 11.2. Gate 11.2F recommendations must follow SV-first `Pos::RefundAllocationPolicy`.

~~The currently proposed user-facing order is:~~

1. ~~Cash;~~  
2. ~~Credit card;~~  
3. ~~Stored value;~~  
4. ~~Other.~~

For refund-default purposes, an original check payment is proposed to be treated as cash (**OD-P11-01** — still open; does not reopen SV-first ordering).

~~This ordering must be reconciled with the earlier ShelfStack policy that restored stored value before refunding external payment methods. Phase 11.2 must make an explicit policy decision rather than leaving both rules active.~~ **Resolved:** SV-first supersedes the cash-first proposal.

The final policy should determine recommendations from:

* original tender composition;  
* remaining refundable amount by original tender;  
* technical ability to refund to the original destination;  
* return source;  
* store policy;  
* user authority.

The cashier may add any **permitted** refund tender, not necessarily every configured tender type.

A deviation from the recommended method should invoke contextual approval only when store policy or authority limits require it.

---

## Phase 11.2 acceptance criteria

Phase 11.2 is complete when:

* ordinary workflows no longer expose unused approval fields;  
* approval prompts appear only after ShelfStack detects an authority exception;  
* approvals are bound to the exact action and invalidated by material changes;  
* the tender screen clearly communicates total, recorded settlement, balance, and change;  
* tender entry occurs through focused modal interactions;  
* recorded-tender actions use correct lifecycle terminology;  
* a cashier can add, inspect, remove, or void a tender without ambiguity;  
* linked returns support receipt lookup and multi-line selection;  
* unlinked returns guide the cashier through product, price, reason, disposition, tax, and approval decisions;  
* open-ring returns use a searchable department selector;  
* refund tender recommendations are visible and editable before recording;  
* refund-allocation policy is explicitly resolved and tested;  
* all existing posting, inventory, tender, stored-value, and historical-integrity rules remain intact.

---

# Phase 11.3 — POS Operations Workspace

**Status:** Scheduled — authoritative plan: [phase-11.3-pos-operations-workspace.md](../../implementation/phases/phase-11.3-pos-operations-workspace.md) (epic [#165](https://github.com/tswarren/shelfstack-5/issues/165))

## Goal

Create a coherent POS-adjacent Operations workspace and distinguish between:

* operations for the current register session;  
* operations for the store’s current business day.

The current implementation already places Store Operations next to Register and renders it using the focused POS shell. However, one page currently combines the user’s session, drawer activity, all store sessions, business-day controls, and X/Z reports.

Phase 11.3 formalizes and separates those responsibilities.

---

## 11.3.1 Workspace model

### ShelfStack

The normal application remains branded simply as **ShelfStack**.

While the user is in the standard application layout, there is no need to display a persistent “Store Workspace” label. The user is simply using ShelfStack.

This application area includes:

* Home;  
* catalog;  
* products;  
* customers;  
* requests;  
* purchasing;  
* receiving;  
* inventory;  
* stored value;  
* reports;  
* reconciliation;  
* configuration;  
* administration.

### Store Workspace

**Store Workspace** is the contextual name used from within the focused POS environment to describe the return destination to normal ShelfStack.

It is a navigational label, not necessarily a separately branded application module.

For example:

* From Register: **Store Workspace** and **Operations**  
* From Operations: **Store Workspace** and **Register**

### Register

Register is the customer-transaction workspace.

It includes:

* Ready;  
* transaction entry;  
* line management;  
* returns;  
* tendering;  
* recovery;  
* receipt presentation.

### Operations

Operations is a sibling workspace to Register within the focused POS environment.

It manages the operating conditions and accountability surrounding transactions rather than the customer transaction itself.

Operations contains two scopes:

* Register Operations;  
* Store Operations.

---

## 11.3.2 Register Operations

### Scope

Register Operations concerns the current operating session used by the signed-in user.

Its authoritative context is the POS session, including its associated:

* store;  
* business day;  
* cashier;  
* POS device;  
* cash drawer, when applicable.

Although the user-facing term is **Register Operations**, the implementation must continue to recognize that the session is the authoritative record. It should not assume that browser identity alone defines a register or that a workstation is always permanently assigned to one cashier.

### Responsibilities

Register Operations should include:

* current session identity;  
* session status;  
* cashier;  
* POS device;  
* assigned cash drawer;  
* cash-enabled or card-only status;  
* opening time;  
* opening cash;  
* current-session cash movements;  
* no-sale activity where appropriate;  
* Session X report;  
* closing count;  
* expected cash;  
* declared cash;  
* cash variance;  
* close session;  
* generated Session Z report;  
* session reconciliation status;  
* session-level exceptions that prevent close.

### Session opening

When no session is open, Register may continue to present the cashier with the immediate next action: **Open session**.

The actual session-opening workflow is operational rather than transactional and should use the same Operations-oriented components and terminology.

This preserves a low-friction Ready experience while maintaining the conceptual boundary.

### Cash movements and no-sale activity

Cash movements and no-sale actions are immediately adjacent to register use and may remain quickly accessible from Register.

Their authoritative history and operational management belong to Register Operations.

The design should therefore distinguish between:

* a quick action launched from Register;  
* the session-level operational record shown in Register Operations.

### Session closing

Session closing must guide the user through:

* completion or resolution of open transaction work;  
* required closing count;  
* expected-cash calculation;  
* variance display;  
* contextual approval where required;  
* close confirmation;  
* generation and presentation of Session Z;  
* reconciliation status where applicable.

---

## 11.3.3 Store Operations

### Scope

Store Operations concerns the current business day across the entire selected store.

It is not limited to the signed-in user’s session.

### Responsibilities

Store Operations should include:

* current business-day identity and reporting date;  
* business-day status;  
* opening time and opening user;  
* all sessions belonging to the business day;  
* session cashier, device, drawer, and status;  
* identification of the signed-in user’s session;  
* Session X and Z access according to permission;  
* current operational exceptions;  
* sessions that must be closed;  
* unresolved tender or cash conditions;  
* business-day X report;  
* readiness to close the business day;  
* business-day close;  
* generated Day Z report;  
* business-day reconciliation status;  
* direct links to reconciliation or historical reporting where appropriate.

### Business-day opening

When no business day is open, Register may continue to show the next required action: **Open business day**.

The actual workflow belongs to Store Operations conceptually, even when it is reached from Register because trading cannot begin without it.

### Business-day closing

Business-day close must verify:

* all required sessions are closed;  
* all required Session Z reports exist;  
* card evidence or other close evidence is present where required;  
* blocking operational exceptions are resolved;  
* required approvals are obtained;  
* the consolidated Day Z can be generated atomically.

The closing interface should explain blockers rather than merely rejecting the close request.

### Reconciliation boundary

Operations manages:

* live status;  
* close readiness;  
* immediate operating exceptions;  
* generation of X and Z reports;  
* visibility of reconciliation status.

The full reconciliation process may remain in normal ShelfStack under reporting and reconciliation, especially when reconciliation occurs after the operating day or is performed by a different role.

Operations should surface:

* whether reconciliation is required;  
* whether it is pending or finalized;  
* any blocking exception relevant to current operations;  
* a direct link to the appropriate reconciliation record.

Historical analysis and finalized reconciliation should not be forced into the focused POS workspace.

---

## 11.3.4 Navigation and shared context

Register and Operations must preserve the same operating context when the user moves between them.

The application should retain or clearly display:

* selected store;  
* active business day;  
* current session;  
* device;  
* drawer;  
* signed-in user;  
* open-transaction status.

A user should be able to move between:

* Register and Register Operations;  
* Register Operations and Store Operations;  
* Operations and Store Workspace;

without losing the operating context or accidentally creating a second session or transaction.

### Open transaction restrictions

Navigation must account for an active transaction.

Some workspace switches may be allowed while preserving the transaction; others may need to be disabled or require the user to suspend, complete, or cancel the transaction.

The rule should be explicit and tested rather than dependent on individual links.

---

## Phase 11.3 acceptance criteria

Phase 11.3 is complete when:

* Register and Operations are presented as sibling workspaces within the POS environment;  
* **Store Workspace** is used as the return label to normal ShelfStack;  
* normal ShelfStack is not persistently renamed Store Workspace;  
* the current Store Operations page is replaced or reorganized as an Operations workspace;  
* Register Operations clearly covers the current session, device, and drawer;  
* Store Operations clearly covers the business day and all store sessions;  
* current-session and store-wide actions are no longer mixed without hierarchy;  
* session opening and closing use consistent operational components;  
* business-day opening and closing use consistent operational components;  
* Session X/Z and Day X/Z reports appear in the correct scope;  
* cash movements and no-sale activity have a clear quick-action versus history boundary;  
* close blockers are visible and actionable;  
* reconciliation status is surfaced without duplicating the full reconciliation workspace;  
* movement among Register, Operations, and Store Workspace preserves context and respects open-transaction rules;  
* permissions determine which scopes, sessions, reports, and actions a user may access.

---

# Phase 11.4 — POS Policy and Lifecycle Hardening

**Status:** Scheduled — authoritative plan: [phase-11.4-pos-policy-and-lifecycle-hardening.md](../../implementation/phases/phase-11.4-pos-policy-and-lifecycle-hardening.md) (epic [#166](https://github.com/tswarren/shelfstack-5/issues/166))

## Goal

Close a predefined inventory of known POS policy, lifecycle, permission, terminology, and integration gaps after the Register and Operations workflows have been refined.

Phase 11.4 is an integration and hardening slice. It must not become an unlimited miscellaneous cleanup phase.

Before implementation begins, its work should be recorded as a closed list of:

* known Phase 11.0 gaps;  
* defects discovered during 11.1–11.3;  
* policy conflicts that must be resolved for the new workflows;  
* missing tests or documentation required for Phase 11 exit.

New requests that do not satisfy an existing Phase 11 contract should be deferred rather than absorbed automatically.

---

## 11.4.1 Approval consistency

Review approval behavior across Register and Operations.

Confirm that:

* the same contextual approval mechanism is used consistently;  
* approval requirements are evaluated server-side;  
* the approval records the actor requesting the action and the actor authorizing it;  
* approval scope is explicit;  
* approval limits are applied consistently;  
* self-approval rules are enforced;  
* approval invalidation is consistent;  
* approval audit records identify the affected line, tender, transaction, session, business day, or reconciliation;  
* approval prompts do not expose unrestricted credentials or authority.

---

## 11.4.2 Tender lifecycle consistency

Review all tender states and actions.

Confirm the meaning and availability of:

* add;  
* edit;  
* remove;  
* confirm;  
* void;  
* resolve void;  
* refund;  
* reverse;  
* complete.

Ensure that:

* unresolved external activity cannot be forgotten;  
* removed local tenders and voided external tenders are distinguished;  
* recovery paths remain available after failed completion;  
* completed tender history remains immutable;  
* duplicate submissions are safe;  
* card-terminal references are retained as required;  
* stored-value posting remains append-only;  
* refund tenders cannot exceed authorized or refundable amounts;  
* mixed payment and refund transactions settle correctly.

---

## 11.4.3 Return and refund policy reconciliation

Resolve and document the final rules governing:

* linked-return refund allocation;  
* unlinked-return refund methods;  
* gift-receipt refunds;  
* no-receipt refunds;  
* external-receipt returns;  
* original-tender preference;  
* stored-value priority;  
* cash and check treatment;  
* card refund eligibility;  
* alternative refund tenders;  
* approval requirements for exceptions;  
* return-price proposals;  
* tax-refund basis;  
* return disposition changes;  
* individually tracked merchandise.

The system must not retain conflicting default-priority rules.

The policy must distinguish among:

* what ShelfStack recommends;  
* what a cashier may select;  
* what requires approval;  
* what is prohibited.

---

## 11.4.4 Session and business-day lifecycle review

Verify the complete operating lifecycle:

1. select store;  
2. open business day;  
3. open session;  
4. conduct transactions;  
5. record cash movements and no-sale events;  
6. suspend and recall work;  
7. close session;  
8. generate Session Z;  
9. resolve required session exceptions;  
10. close business day;  
11. generate Day Z;  
12. reconcile;  
13. finalize reconciliation;  
14. review historical reports.

Review edge cases including:

* no open business day;  
* no open session;  
* multiple sessions;  
* card-only sessions;  
* shared versus individual session policy;  
* attempts to close with an open transaction;  
* attempts to close a day with open sessions;  
* failed close operations;  
* repeated close requests;  
* report access after close;  
* variance approvals;  
* evidence-unavailable paths;  
* pending reconciliation;  
* cross-store scoping;  
* unauthorized access to another cashier’s session.

---

## 11.4.5 Permissions and role boundaries

Review permissions for:

* entering Register;  
* opening transactions;  
* opening and closing sessions;  
* opening and closing business days;  
* cash movements;  
* no-sale activity;  
* Session X and Z;  
* Day X and Z;  
* returns;  
* no-receipt returns;  
* refund-method overrides;  
* tender voids;  
* stored-value actions;  
* post-voids;  
* reconciliation;  
* approval and self-approval.

The interface should not show actions the user cannot perform unless showing the disabled action materially explains a required escalation.

Permission checks must remain enforced by services or controllers, not only by hidden interface controls.

---

## 11.4.6 Terminology and navigation cleanup

Normalize user-facing and internal terminology, including:

* ShelfStack;  
* Store Workspace;  
* Register;  
* Operations;  
* Register Operations;  
* Store Operations;  
* business day;  
* session;  
* workstation or POS device;  
* cash drawer;  
* X report;  
* Z report;  
* payment;  
* refund;  
* tender;  
* remove;  
* void;  
* reversal;  
* reconciliation.

Remove or update obsolete wording such as:

* Main workspace;  
* back office in user-facing contexts;  
* Store Operations when referring to the entire mixed operations page;  
* ambiguous use of delete for financial activity.

Review routes, page titles, navigation labels, headers, breadcrumbs, and help text for consistency.

---

## 11.4.7 Reporting and reconciliation integration

Confirm that:

* live X reports remain projections and do not close activity;  
* Z reports are generated only through the appropriate close boundary;  
* Session Z and Day Z preserve their reporting scope;  
* Day Z reconciles to its Session Z roll-up and authoritative activity;  
* finalized reports and reconciliations remain immutable;  
* Operations links to the correct current reports;  
* Store Workspace provides historical report and reconciliation access;  
* no report recalculates completed history using current master data;  
* operational status does not conflict with reconciliation status.

---

## 11.4.11 Regression and acceptance testing

Phase 11.4 should add or complete end-to-end coverage for the principal cashier and supervisory journeys.

### Cashier journeys

* open session and begin work;  
* ordinary sale;  
* split-tender sale;  
* cash sale with change;  
* standalone card payment;  
* stored-value payment;  
* linked return;  
* unlinked product return;  
* open-ring return;  
* mixed sale and return;  
* receipt-linked refund;  
* refund-method override requiring approval;  
* suspend and recall;  
* completion failure and tender recovery;  
* session cash movement;  
* close session and produce Session Z.

### Supervisory journeys

* approve a contextual exception;  
* review active store sessions;  
* run Session X and Day X;  
* resolve a session-close blocker;  
* approve a variance where required;  
* close the business day;  
* produce Day Z;  
* enter or review reconciliation;  
* finalize reconciliation;  
* access historical reports and documents.

### Integrity tests

Confirm:

* atomicity;  
* idempotency;  
* immutable completed history;  
* snapshot preservation;  
* approval binding;  
* permission enforcement;  
* store scoping;  
* transaction and session locking;  
* refund limits;  
* tender lifecycle correctness;  
* inventory and stored-value reversals;  
* X/Z report integrity;  
* reconciliation finalization.

---

## Phase 11.4 acceptance criteria

Phase 11.4 is complete when:

* the predefined Phase 11 gap list is closed or explicitly deferred;  
* approval behavior is consistent across Register and Operations;  
* tender lifecycle actions have unambiguous meaning;  
* refund-allocation policy is singular, documented, and tested;  
* session and business-day lifecycle edge cases are handled;  
* permissions and role boundaries are verified;  
* terminology and navigation are consistent;  
* Operations and reconciliation responsibilities are clearly separated;  
* end-to-end cashier and supervisory journeys pass;  
* financial, inventory, stored-value, reporting, and historical-integrity invariants remain intact;  
* Phase 11 documentation reflects the system as implemented;  
* no unresolved issue is hidden under a generic “cleanup” designation.

---

# Cross-phase design principles

## Reveal complexity only when required

The ordinary cashier path should remain simple.

ShelfStack should reveal additional fields, policy explanations, and approval requirements only when the specific transaction or exception requires them.

## Preserve authoritative domain services

The redesigned workflows should compose existing domain services rather than reproduce financial or inventory logic in controllers, presenters, or client-side code.

## Distinguish proposals from posted facts

The interface must clearly distinguish among:

* a suggested refund allocation;  
* an entered but unresolved tender;  
* a confirmed external tender;  
* a completed posted tender;  
* a projected X report;  
* a persisted Z report;  
* a pending reconciliation;  
* a finalized reconciliation.

## Preserve historical facts

Completed transactions, tenders, inventory effects, stored-value entries, reports, and reconciliations must not be reinterpreted using current configuration.

## Make scope visible

The user should always be able to determine whether an action applies to:

* a transaction;  
* a line;  
* a tender;  
* the current session;  
* a cash drawer;  
* the entire business day;  
* the selected store.

## Prefer guided decisions over comprehensive forms

A workflow should ask the next relevant question rather than presenting every possible field in advance.

## Keep operational and historical work distinct

Register and Operations should support current work and close readiness.

Normal ShelfStack should remain the primary location for:

* historical review;  
* reporting analysis;  
* finalized reconciliation;  
* configuration;  
* administration.

---

# Implementation order

The planned order is:

1. **Phase 11.2 — Register Workflow Refinement**  
     
   * establish contextual approvals;  
   * redesign tendering;  
   * redesign linked and unlinked returns;  
   * resolve refund recommendations and overrides.

   

2. **Phase 11.3 — POS Operations Workspace**  
     
   * formalize workspace navigation;  
   * separate Register Operations and Store Operations;  
   * apply contextual approvals to operational exceptions;  
   * refine session and business-day close workflows.

   

3. **Phase 11.4 — POS Policy and Lifecycle Hardening**  
     
   * reconcile policies across both workspaces;  
   * close known Phase 11.0 gaps;  
   * normalize permissions and terminology;  
   * complete integration and regression testing.

This order allows 11.3 to reuse the approval and interaction mechanisms introduced by 11.2, while 11.4 validates the complete system rather than hardening workflows that are about to be replaced.

---

# Open decisions to resolve during planning

## Refund allocation priority

**Accepted:** stored-value first — [phase-11.2-refund-allocation-sv-first.md](../../implementation/decisions/phase-11.2-refund-allocation-sv-first.md) (OD-P11-R1). Cash-first proposal superseded.

## Check refund treatment

Confirm whether check payments always default to cash refunds for MVP or whether store configuration may impose another method or holding rule. Tracked as **OD-P11-01**.

## Register quick actions versus Operations history

Confirm which actions remain immediately accessible from Register while their authoritative history is managed in Register Operations.

This particularly affects:

* cash movements;  
* no-sale activity;  
* session opening;  
* session closing.

Tracked as **OD-P11-02**.

## Open-transaction navigation

Define which workspace transitions are permitted while a transaction is open and which require completion, suspension, or cancellation. Tracked as **OD-P11-03**.

## Reconciliation placement

Confirm that Operations surfaces current reconciliation status and links while the full reconciliation workflow remains in normal ShelfStack. Tracked as **OD-P11-04**.

---

# Out of scope

Unless separately scheduled, Phase 11 does not introduce:

* integrated card processing;  
* automatic communication with external payment terminals;  
* full offline POS operation;  
* new loyalty or membership pricing systems;  
* complete CRM functionality;  
* accounting-system integration;  
* new physical inventory sublocation authority;  
* redesigned historical analytics beyond the operational links required here;  
* unrestricted receipt or report customization;  
* a general-purpose workflow engine;  
* new approval policy unrelated to an implemented Phase 11 action.

---

# Phase 11 exit condition

Phase 11 is complete when ShelfStack provides an understandable and dependable POS operating environment from the beginning of the business day through transaction entry, tendering, returns, session close, business-day close, reporting, and reconciliation.

At exit:

* the cashier can conduct ordinary work without confronting unnecessary policy complexity;  
* approvals appear only when an exception actually requires them;  
* tendering and refunds clearly communicate settlement state;  
* linked and unlinked returns are guided workflows;  
* Register and Operations have distinct purposes;  
* Register Operations and Store Operations have clear scopes;  
* Store Workspace provides a consistent route back to normal ShelfStack;  
* permissions, corrections, tenders, reports, and reconciliation remain financially and historically sound;  
* all known Phase 11 gaps are either resolved or explicitly deferred.

The most consequential formerly unresolved item was the **refund-allocation priority**. That is now **accepted as stored-value first** ([phase-11.2-refund-allocation-sv-first.md](../../implementation/decisions/phase-11.2-refund-allocation-sv-first.md)). Remaining open items for 11.3/11.4 are OD-P11-01–04.  