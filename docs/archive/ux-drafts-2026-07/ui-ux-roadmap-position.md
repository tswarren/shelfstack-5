# ShelfStack UI/UX Direction and Roadmap Position

## 1. Overall position

ShelfStack should treat UI/UX as part of the application architecture, not as a layer of visual polish applied after the domains are implemented.

This does not mean that the entire application should be designed in detail before development continues. It means that every phase should consider how users will understand, enter, review, correct, and complete the activity being implemented. The interface must reflect ShelfStack’s domain distinctions, preserve operational context, and make consequential actions understandable.

The existing mockups provide a strong visual and interaction direction. In particular, they demonstrate:

* a restrained and credible retail-operations visual language;
* clear distinctions among primary, secondary, warning, and destructive actions;
* compact but readable data presentation;
* a scanner-oriented POS workspace;
* prominent transaction totals and tender controls;
* visible store, register, drawer, session, and cashier context;
* store-level inventory information using on-hand, reserved, unavailable, and available quantities.

These ideas should be preserved as the target experience. The mockups should initially be treated as **design prototypes and visual reference material**, rather than as authoritative implementations of business logic. The current review correctly identifies that prototype JavaScript, sample calculations, example API payloads, and future-state workflows must not silently become architectural decisions.

The goal should not be to reproduce every mockup pixel-for-pixel. The goal should be to build an application that has the same qualities:

* clear;
* efficient;
* operationally credible;
* visually cohesive;
* keyboard- and scanner-friendly;
* appropriately dense;
* resistant to user error;
* faithful to the underlying business model.

## 2. Two related interface modes

ShelfStack will need two related but distinct interaction modes.

### 2.1 Administrative and back-office interfaces

Many ShelfStack functions are legitimately record-oriented:

* products and variants;
* departments and merchandise classes;
* vendors;
* users and permissions;
* tender configuration;
* tax categories;
* reason codes;
* store and device setup.

These areas may use familiar patterns such as:

* search and filter pages;
* tables;
* detail pages;
* tabbed records;
* forms;
* drawers and dialogs;
* batch actions;
* explicit save or deactivate actions.

CRUD is not inherently a problem in these areas. The problem arises when the database record structure becomes the entire user experience. A user should normally experience a coherent business object or workflow, not a collection of unrelated tables and foreign keys.

For example, product identity, selling setup, variants, identifiers, pricing, sourcing, and inventory should feel like connected aspects of one merchandise lifecycle even when they are owned by separate records or domains.

### 2.2 Operational workspaces

Other ShelfStack functions require purpose-built workspaces rather than conventional CRUD pages:

* POS;
* receiving;
* purchase-order entry;
* buyer review;
* product-request fulfilment;
* inventory adjustments and counts;
* return processing;
* reconciliation.

These workspaces should keep the user within one operational context and support repeated, rapid actions without unnecessary page navigation.

The POS is the clearest example:

```text
Scan
→ resolve item
→ add or increment line
→ retain scan focus
→ repeat
→ tender
→ validate
→ complete
→ issue receipt
→ open next transaction
```

Receiving will have a comparable operational loop:

```text
Identify shipment
→ scan or locate item
→ match expected order quantity
→ record accepted or exception quantity
→ repeat
→ review
→ post receipt
```

The design system should support both modes while allowing operational workspaces to be denser, more keyboard-oriented, and more stateful than ordinary administration pages.

## 3. Position in the roadmap

UI/UX should not become a separate long-running phase that blocks implementation. It should become a **cross-cutting responsibility**, with a focused readiness gate immediately before Phase 4.

The adopted roadmap deliberately uses thin vertical slices and brings POS forward after organization, catalog, and a minimal inventory foundation. The sequence is:

1. Phase 0 — scaffold and conventions;
2. Phase 1 — organization, stores, users, and authorization;
3. Phase 2 — classification and catalog;
4. Phase 3 — inventory bootstrap;
5. Phase 4 — POS through first completed sale;
6. Phase 5 — purchasing, receiving, and product requests;
7. Phase 6 — corrections and stored value;
8. Phase 7 — reporting and reconciliation;
9. Phase 8 — deferred capabilities.

### 3.1 Before Phase 4: UX foundation and POS readiness

Before substantive Phase 4 work begins, ShelfStack should establish a limited but governing UX foundation.

This should include:

* application shell and primary navigation;
* active-store and user-context presentation;
* visual tokens and semantic colors;
* typography and spacing conventions;
* button and form hierarchy;
* tables, tabs, badges, dialogs, drawers, and alerts;
* loading, empty, warning, blocker, and failure patterns;
* keyboard-focus principles;
* accessibility baseline;
* POS workspace states;
* scanner and keyboard behavior;
* terminology rules;
* separation between visual guidance and business workflow contracts.

This does not require finalizing every screen. It creates the shared language needed to prevent Phase 4 from becoming an isolated interface that later conflicts with the rest of the application.

A practical roadmap gate should be:

> Phase 4 implementation may begin when the POS workflow states, scan behavior, focus rules, warning and approval patterns, principal layout, and accessibility baseline have been documented and prototyped.

### 3.2 Phase 4: validate the operational interaction model

Phase 4 should develop the POS interface and the POS transaction engine together.

The roadmap’s first meaningful demonstration is:

```text
quantity-tracked variant
→ adjust into stock
→ open POS session
→ reserve and sell item
→ atomically complete transaction
→ assign receipt number
→ post inventory movement
```

That path is intended to validate one of the highest-risk parts of the product early.

The Phase 4 UI should therefore be functional and coherent, not merely a scaffold. It should support:

* scan and search;
* product, variant, and exact-unit resolution;
* line selection;
* repeated scanning;
* quantity changes;
* pending-line removal;
* reservations;
* warnings and blockers;
* suspension and recall;
* discounts and price overrides as they enter scope;
* tax presentation;
* tender entry;
* completion;
* receipt presentation;
* failure and recovery states.

However, the roadmap is also correct to postpone **full POS polish** until the completion semantics are proven.

The distinction is:

* interaction architecture must be designed before and during Phase 4;
* final refinements, animation, edge-case optimization, and exhaustive visual polish do not need to block the first completed sale.

### 3.3 Phase 5: first broader UX consolidation

Phase 5 is the appropriate point for the first application-wide UX review.

By then, ShelfStack will include several different interaction types:

* merchandise administration;
* store inventory;
* POS;
* vendor and source maintenance;
* purchase-order editing;
* receiving;
* buyer-review queues;
* product-request allocation and fulfilment.

This will reveal whether the application shell, terminology, components, and workspace patterns work across domains.

The end of Phase 5 should include a deliberate review of:

* navigation and workspace boundaries;
* repeated terminology;
* shared search behavior;
* queues and task lists;
* master-detail patterns;
* record history and audit presentation;
* component duplication;
* store-context consistency;
* keyboard behavior;
* density;
* responsive behavior;
* accessibility;
* performance.

### 3.4 Later phases

Phase 6 should establish interaction patterns for corrective and high-risk actions:

* linked returns;
* no-receipt returns;
* post-voids;
* stored-value adjustments;
* reversals;
* manager approvals;
* inspection, damage, RTV, and discard decisions.

Phase 7 should establish reporting and reconciliation patterns:

* dashboards;
* filters;
* date and business-day context;
* store and session scope;
* drill-down;
* exports;
* exception review;
* reconciliation differences;
* historical versus current classifications.

Phase 8 may revisit broader capabilities such as offline POS, advanced placement, integrated payment processing, and other deployment-specific enhancements. These should not be predesigned as though their architecture were already settled.

## 4. UX must reflect the domain model

ShelfStack’s UI terminology and behavior must be derived from accepted architectural decisions rather than from convenient labels in a mockup.

Examples include:

* Product, Product Variant, and Inventory Unit must remain distinguishable.
* A product scan may require variant resolution.
* A variant SKU resolves an exact sellable configuration.
* An inventory-unit scan resolves an exact physical copy.
* A product request is not an inventory reservation.
* A purchase-order allocation is not on-hand inventory.
* Reserved inventory remains on hand.
* Unavailable inventory remains physically present.
* Purchase orders record intent.
* Receipts record accepted physical delivery.
* Completed POS transactions are immutable.
* Returns and post-voids create new linked records.
* Stored-value redemption is tender, not discount.
* Store context determines inventory and operational ownership.

The interface may use clearer user-facing wording than the database or service layer, but the mapping must remain explicit.

For example, **Register 2** may be a better cashier-facing label than **POS Device POS-02**, while the system still records the exact device and drawer separately.

The UI should simplify the model without contradicting it.

## 5. The server remains authoritative

The browser will need to provide immediate feedback, but it must not become the authoritative business engine.

Client-side behavior may:

* update selected rows;
* format currency;
* preview totals;
* retain scan focus;
* display expected warnings;
* optimistically show a pending action;
* reduce unnecessary full-page reloads.

The server must remain authoritative for:

* product and variant eligibility;
* inventory reservation;
* price resolution;
* discounts and promotions;
* tax;
* approval requirements;
* tender sufficiency;
* stored-value balances;
* inventory posting;
* receipt sequencing;
* transaction completion;
* reversals;
* historical snapshots.

A keyboard command such as `Ctrl+Enter` may request completion. It may never bypass validation. Prototype JavaScript that calculates totals or inserts demo products must be clearly identified as non-authoritative.

Monetary amounts should be stored, transmitted, and calculated in integer cents, while the interface displays and accepts ordinary formatted currency.

## 6. Build from state models, not only screens

Before implementing a workflow, define its meaningful states and transitions.

For POS, these include:

* no transaction;
* empty open transaction;
* active transaction;
* item resolution required;
* variant selection required;
* exact-unit selection required;
* warning present;
* blocker present;
* approval required;
* tendering;
* externally approved card awaiting internal completion;
* ready to complete;
* completion in progress;
* completion failed;
* completed;
* suspended;
* recalled;
* cancelled.

Each state should answer:

* What can the user see?
* What action is primary?
* What actions are unavailable?
* Where is keyboard focus?
* What remains editable?
* What data is provisional?
* What happens after a failure?
* Can the action be safely retried?
* What activity is retained for audit?

This prevents backend statuses from being exposed as a confusing set of buttons and badges.

## 7. Scanner and keyboard behavior are first-class requirements

Barcode input should not be treated as ordinary text entry with an Enter handler added later.

ShelfStack should define:

* scanner input termination;
* how scanner input is distinguished from manual typing, if necessary;
* behavior when a dialog is open;
* repeated-scan behavior;
* whether a repeated scan increments an existing line;
* product-versus-variant-versus-unit resolution;
* ambiguous-match behavior;
* focus restoration;
* protection against input loss during latency;
* handling of rapid consecutive scans;
* auditory or visual success and failure feedback.

Keyboard actions should be divided into:

1. universal browser-safe actions;
2. optional shortcuts for ordinary desktop use;
3. dedicated-register shortcuts that may conflict with browser defaults.

All actions must remain accessible through visible controls. No destructive or irreversible action should occur through one easily triggered keystroke without an appropriate confirmation or completion validation.

## 8. Performance is part of UX

A visually accurate POS that pauses unpredictably will not meet the intended design.

The UX contract should eventually define measurable targets for:

* scan-to-feedback time;
* scan-to-line-add time;
* product-search response;
* transaction recalculation;
* tender entry;
* dialog opening;
* suspension and recall;
* completion feedback;
* receipt readiness.

The interface should also communicate latency clearly:

* acknowledge the scan immediately;
* show when resolution is still in progress;
* prevent duplicate actions without freezing the workspace;
* retain queued scanner input where safe;
* distinguish retryable failures from blockers;
* never leave the cashier uncertain whether an item or tender was recorded.

Turbo and Stimulus can support this interaction model, but they should be used intentionally rather than forcing every operational interaction through conventional page submissions.

## 9. Error and recovery behavior must be designed

Operational confidence depends as much on failure behavior as on the ordinary path.

ShelfStack should define interface behavior for:

* network loss;
* search timeout;
* product becoming inactive;
* reservation conflict;
* stale suspended transaction;
* business day or session becoming unavailable;
* duplicate completion submission;
* validation changes between tendering and completion;
* card approval occurring externally but internal completion failing;
* stored-value balance changing before completion;
* receipt printer failure after successful completion.

The interface must distinguish:

* an operation that did not occur;
* an operation still in progress;
* an operation completed but whose confirmation failed;
* an operation requiring reconciliation.

Retry behavior must align with the application’s idempotency guarantees.

## 10. Store and operational context must remain visible

ShelfStack is store-centered. Users must be able to see the context under which they are acting, especially where inventory, receiving, POS, cash, and reporting are involved.

Relevant screens should show some combination of:

* store;
* business day;
* reporting date;
* POS session;
* register or device;
* drawer;
* current user or cashier;
* customer, where applicable;
* transaction or document status.

The interface should prevent users from believing they are acting at one store when the record or transaction belongs to another.

Context should be prominent without consuming excessive workspace.

## 11. Accessibility is an adoption requirement

Accessibility should not be treated as later polish.

The minimum design contract should require:

* full keyboard operability;
* visible focus;
* usable high-contrast and forced-colors behavior;
* adequate text and control contrast;
* form labels and associated errors;
* status communication beyond color alone;
* modal and drawer focus management;
* screen-reader announcements for important dynamic changes;
* adequate target sizes where touch is supported;
* no scanner behavior that makes the application inaccessible to ordinary keyboard or assistive-technology users.

Operational density and accessibility are compatible when hierarchy, focus, and state are designed carefully.

## 12. Responsive and device expectations must be explicit

ShelfStack should define supported device profiles rather than claiming that every screen works equally on every viewport.

Likely profiles include:

* dedicated register;
* back-office desktop;
* laptop;
* optional tablet;
* limited mobile access for selected administrative or lookup tasks.

The POS may reasonably establish a minimum supported resolution and decline to offer a full narrow-phone layout. A responsive product-detail page and a responsive cash-register workspace have different requirements.

An installable or standalone PWA may later be evaluated for dedicated registers, but it should remain a deployment option until formally selected. It should not imply offline POS, which remains a separate deferred architectural capability.

## 13. Documentation structure

The UI/UX material should be separated by responsibility:

```text
docs/design/
  README.md
  visual-style-guide.md
  interaction-patterns.md
  accessibility.md
  application-shell.md
  operational-workspaces.md
  pos-register-ui.md
  scanner-and-hotkeys.md
  performance-and-recovery.md

docs/workflows/
  pos-transaction.md
  pos-completion.md
  suspended-transaction.md
  quantity-tracked-sale.md
  individually-tracked-sale.md
```

The design documents should govern:

* visual language;
* components;
* interaction behavior;
* focus;
* feedback;
* accessibility;
* layout;
* workspace conventions.

Workflow and domain documents should govern:

* business states;
* validation;
* posting;
* atomicity;
* idempotency;
* inventory effects;
* tender effects;
* corrections;
* historical records.

Mockups may remain in a prototype area and should identify which features are current-phase, future-state, or purely illustrative.

## 14. Phase completion standard

Each implementation phase should include UX acceptance criteria alongside schema, service, testing, and documentation requirements.

For each principal workflow, the phase should define:

* user goal;
* entry point;
* expected path;
* screen or workspace states;
* primary and secondary actions;
* keyboard and focus behavior;
* warnings, blockers, and approvals;
* loading and failure states;
* accessibility requirements;
* supported device profile;
* terminology;
* audit and history presentation;
* tests for important browser paths.

A phase should not be considered complete merely because records can be created, updated, and listed.

## 15. Final direction

ShelfStack should continue toward the visual and interaction quality demonstrated by the mockups. The overall direction is appropriate: restrained branding, clear hierarchy, compact operational layouts, scanner-first POS behavior, and consistent semantic components.

The project should not pause for a complete front-end redesign before Phase 4. It should instead:

1. establish a small governing UX foundation now;
2. define the POS interaction contract before implementing the Phase 4 workspace;
3. build the POS interface and transaction semantics together;
4. postpone exhaustive polish until the completed-sale path is proven;
5. consolidate the broader application experience during Phase 5;
6. treat UX requirements as part of every later roadmap phase.

The mockups should serve as a north star. The implemented application should reach that target through architecture-aligned, accessible, testable, and operationally reliable vertical slices rather than through a separate cosmetic redesign at the end.
