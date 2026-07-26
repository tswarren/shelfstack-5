Draft for `docs/implementation/phases/phase-11-pos-shell-and-workspace-revamp.md`

# Phase 11 — POS Shell and Workspace Revamp

**Status:** Scheduled — not started
**Depends on:** Phase 10 fully complete; Phase 6.5 cashier workspace on `main`; Phase 9 Customer v1
**Primary register item:** [DWR-067](../deferred-work-register.md)
**Absorbs:** DWR-010
**Partially absorbs:** DWR-017, DWR-020
**Governing docs:** [pos-register-ui.md](../../design/pos-register-ui.md); [scanner-and-hotkeys.md](../../design/scanner-and-hotkeys.md); [accessibility.md](../../design/accessibility.md); [point-of-sale.md](../../domains/point-of-sale.md); ADR-0009; ADR-0011; [ADR-0016](../../adr/0016-treat-standalone-credit-card-activity.md); [ADR-0017](../../adr/0017-customer-domain-and-namespace-22.md)

> Phase 11 is the POS shell and cashier-workspace phase. It is not the “later operational extensions” bucket described elsewhere in the system roadmap.

---

## 1. Characterization

Phase 11 is a **cashier product and workflow phase**.

ShelfStack already supports the underlying transaction capabilities needed for ordinary register work:

* sales;
* returns;
* Open Ring;
* stored-value issuance and tendering;
* cash and standalone-card tenders;
* split tender;
* suspend and recall;
* Customer attachment;
* Product Request pickup;
* transaction completion;
* post-void eligibility;
* session and business-day operations.

The problem is that these capabilities do not yet behave as one continuous, efficient register.

Phase 11 reorganizes them into a dedicated, server-authoritative POS shell with five explicit presentations:

```text
Ready
Transaction
Tender
Recovery
Receipt
```

The ordinary cashier journey becomes:

```text
Ready
  → first valid customer work
  → Transaction
  → Tender
  → Complete
  → Receipt
  → Ready
```

Phase 11 should make the existing transaction engine feel like one coherent product without changing the authoritative business rules established in earlier phases.

---

## 2. Goal

Deliver a register workspace in which a cashier can:

1. enter the correct operational presentation based on persisted facts;
2. scan or deliberately select the first item without creating an empty transaction;
3. build, suspend, cancel, and restore an ordinary transaction;
4. perform Product lookup, Customer attachment, returns, Open Ring, pickup, and stored-value line entry inside the shell;
5. tender and atomically complete realistic sale and refund combinations;
6. retrieve and reproduce a minimal customer-facing receipt;
7. safely resolve the narrow set of known financial-recovery conditions;
8. complete ordinary journeys using keyboard and scanner input efficiently and accessibly.

---

## 3. Governing interaction and authority contracts

### 3.1 The server determines the presentation

The browser does not decide whether the register is in Ready, Transaction, Tender, Recovery, or Receipt.

A central resolver derives the presentation from persisted facts such as:

* active Business Day;
* active POS Session;
* active transaction;
* transaction editability;
* tender or settlement context;
* unresolved external tender state;
* completed transaction context.

Browser refresh must never create, cancel, suspend, reopen, complete, or otherwise mutate a transaction.

### 3.2 Navigation does not create empty transactions

The following do not create a transaction by themselves:

* opening the register;
* navigating to a POS route;
* selecting an entry intent;
* staging a Customer;
* opening Product lookup;
* opening a supporting lookup.

A transaction is created only with the first valid customer-work action, such as:

* adding an eligible Product or Variant;
* adding an eligible return;
* adding an Open Ring line;
* adding eligible pickup activity;
* adding a stored-value issuance or reload line.

The first valid action must create the transaction and its associated work atomically. Failure leaves no empty transaction.

### 3.3 Commercial editing locks during tender

Once tendering begins:

* ordinary line and pricing edits are locked;
* Customer changes are locked;
* the cashier may return to Transaction only when tender state is safe;
* unresolved external activity prevents unsafe editing or additional payment activity.

### 3.4 Completion remains atomic and idempotent

Phase 11 does not redesign the accepted completion boundary.

Completion must:

* validate the complete transaction;
* post all required domain effects;
* assign one receipt number;
* complete once;
* resist duplicate submissions;
* leave a recoverable open transaction when completion fails before commit.

Printing or presentation failure after successful completion does not reverse completion.

### 3.5 Progressive enhancement

The register may use Stimulus and Turbo for interaction efficiency, but:

* server-rendered HTML remains authoritative;
* essential content and controls remain present without JavaScript;
* JavaScript does not create a second business-state authority;
* no SPA, client-side router, Node.js toolchain, or JavaScript bundler is introduced.

### 3.6 Permissions remain enforced at action and data boundaries

The shell must not expose an action or sensitive value merely because the surrounding register is visible.

Every slice must verify:

* route and service authorization;
* action visibility;
* actor attribution;
* restricted result fields;
* cost and margin suppression;
* supervisor approval where required;
* fail-closed handling when authorization changes.

---

## 4. Delivery model

Phase 11 uses vertical slices grouped into five delivery gates.

Each slice includes the complete cashier outcome:

* owning-domain behavior;
* application services;
* controller and route behavior;
* POS presentation;
* permissions;
* actor attribution;
* keyboard and scanner behavior;
* accessibility;
* request, service, and model tests;
* complete cashier-journey tests;
* refresh and duplicate-submission behavior;
* documentation updates.

A slice is not complete merely because its models and controllers exist.

---

## 5. Gate summary

| Gate                               | Slices | Required cashier outcome                                                                                               |
| ---------------------------------- | -----: | ---------------------------------------------------------------------------------------------------------------------- |
| **A — Stable register foundation** |    1–3 | Enter the register, scan and build an ordinary sale, suspend or cancel, and restore authoritative state                |
| **B — Complete transaction entry** |    4–7 | Use Product lookup, Customer attachment, returns, Open Ring, pickup, and stored-value line entry                       |
| **C — Financial completion**       |    8–9 | Settle and atomically complete realistic payment and refund combinations                                               |
| **D — Customer-facing completion** |     10 | Produce, find, and reprint the mandatory receipt core                                                                  |
| **E — Release readiness**          |  11–12 | Handle narrow financial Recovery and pass the full keyboard, scanner, accessibility, permission, and resilience matrix |

Suggested dependency order:

```text
1 Shell and resolver
        ↓
2 Ready and first sale
        ↓
3 Core Transaction
        ├────────────────┐
        ↓                ↓
4 Product lookup     5 Customer integration
        └────────┬───────┘
                 ↓
6 Returns and Open Ring
7 Pickup and stored-value lines
                 ↓
8 Tender foundation and cash
                 ↓
9 Card, stored value, and split tender
                 ↓
10 Receipt core
                 ↓
11 Recovery
                 ↓
12 Integrated release hardening
```

Product lookup and Customer integration may proceed partly in parallel after the shell contract is stable.

Receipt rendering may be developed in parallel once completed transaction facts are stable, but final integration follows the completion boundary.

---

# Gate A — Stable register foundation

## 6. Slice 1 — POS shell and presentation resolver

### Outcome

The register reliably opens in the correct operational presentation.

### Includes

* dedicated POS layout;
* shared register header;
* compact cashier workspace geometry;
* current Business Day and POS Session resolution;
* presentation resolver for:

  * Ready;
  * Transaction;
  * Tender;
  * Recovery;
  * Receipt;
* processing and duplicate-submission protection;
* server-authoritative restoration after refresh.

### Acceptance criteria

* no active Business Day shows the appropriate prerequisite state;
* an open Business Day without an active user session presents session opening;
* an open session without an active transaction presents Ready;
* an editable transaction restores Transaction;
* a transaction with active settlement context restores Tender;
* `void_required` restores Recovery;
* a newly completed transaction restores Receipt in the appropriate completion context;
* refresh never changes transaction state.

---

## 7. Slice 2 — Ready workspace and first-sale path

### Outcome

A cashier can open the register, scan an item from Ready, and begin a transaction without encountering an intermediate empty transaction.

### Includes

* Ready workspace;
* primary scan input;
* unique scan-to-start behavior;
* ambiguous and unsuccessful scan results;
* suspended-transaction summary;
* existing session actions integrated into the shell:

  * Cash Movement;
  * No Sale;
  * Session X;
  * Close Session;
  * Store Operations;
* passive cash-drop indication where accepted configuration exists;
* removal of sensitive reporting totals from the cashier shell.

### Acceptance criteria

* one valid unique scan atomically creates the transaction, line, and reservation;
* an invalid or ambiguous scan creates no transaction;
* repeated submission does not create duplicate transactions or lines;
* suspended transactions do not prevent Ready;
* an active transaction prevents Ready;
* No Sale records its audited drawer action without creating an unrelated cash movement;
* restricted session actions remain permission-gated;
* expected cash, variance, sales totals, and tender totals are not exposed in the register shell.

---

## 8. Slice 3 — Core Transaction workspace

### Outcome

A cashier can build, review, suspend, or cancel an ordinary sale.

### Includes

* transaction line list;
* repeated scanning;
* quantity changes;
* line removal;
* selected-line context;
* running totals;
* inventory reservations;
* exact unit selection for individually tracked merchandise;
* transaction-readiness summary;
* Suspend;
* Cancel;
* Begin Tender;
* deterministic focus return to the scan input.

### Acceptance criteria

* adding, changing, and removing lines updates totals and reservations correctly;
* individually tracked merchandise requires an eligible exact unit;
* negative availability produces the accepted warning rather than an unintended hard block;
* suspension preserves the transaction and reservations and returns to Ready;
* cancellation releases reservations and returns to Ready;
* suspension is rejected while unresolved tender activity exists;
* Begin Tender is blocked until required transaction facts are complete;
* refresh restores the same authoritative transaction and reservation state.

## Gate A exit

Gate A is accepted when a cashier can:

* enter the register;
* scan and build an ordinary sale;
* suspend or cancel;
* restore the same state after refresh;
* perform those actions without accidental empty transactions or duplicate submissions.

---

# Gate B — Complete transaction entry

## 9. Slice 4 — POS-native Product lookup

### Outcome

A cashier can find Products without leaving the register and deliberately add an eligible Variant.

### Search coverage

* ISBN or canonical trade identifier;
* ISBN-10 normalization;
* SKU;
* alternate identifier;
* Product title;
* Creator;
* exact Inventory Unit identifier.

### Result behavior

Support:

* exact match;
* multiple matches;
* no match;
* inactive or unavailable result;
* restricted result;
* Product and Variant grouping;
* current-store price and availability;
* Add from Ready;
* Add from Transaction;
* view-only behavior in Tender and Recovery.

### Acceptance criteria

* explicit lookup never automatically adds an exact match;
* adding from Ready atomically creates the transaction and line;
* adding from Transaction uses the existing transaction;
* a failed add from Ready leaves no empty transaction;
* ineligible results explain why they cannot be sold;
* acquisition cost, margin, internal IDs, and other restricted fields are not shown;
* keyboard navigation works through results.

### DWR-020 boundary

Phase 11 may use the shared picker and lookup interaction patterns delivered earlier.

It does not absorb:

* Purchase Order nested-line adoption;
* receipt-entry nested-line adoption;
* unrelated shared-form refactoring.

Those remain separately registered.

---

## 10. Slice 5 — Customer integration

### Outcome

A cashier can create, find, stage, attach, replace, and remove a Customer within the POS shell.

Phase 11 consumes the Customer v1 domain delivered in Phase 9. It does not reopen the Customer persistence design.

### Includes

* compact POS Customer lookup;
* search by:

  * individual name;
  * organization name;
  * organization contact name;
  * normalized phone;
  * normalized email;
* compact Customer creation;
* possible-duplicate warning;
* Customer staging from Ready;
* attach, replace, and remove in Transaction;
* read-only Customer display after tender locking.

### Acceptance criteria

* staging a Customer from Ready creates no transaction;
* the staged Customer attaches atomically with the first valid transaction work;
* attaching or replacing a Customer performs any accepted recalculation;
* Customer changes are rejected once commercial editing is locked;
* sensitive Customer notes do not appear in broad POS lookup results;
* Phase 11 does not introduce households, loyalty, multiple contact methods, merge, or notification workflows.

---

## 11. Slice 6 — Returns and Open Ring

### Outcome

A cashier can construct mixed sale-and-return activity and add lines not represented by a normal Product record.

### Includes

* return entry intent;
* linked return lookup;
* unlinked return Product selection;
* Open Ring sale lines;
* Open Ring return lines;
* return reason;
* return source or basis;
* return disposition;
* historical refund calculation for linked returns;
* required approval handling;
* mixed sale and return totals;
* net settlement calculation.

### Acceptance criteria

* linked returns preserve original commercial facts;
* unlinked returns collect the required identifying, pricing, tax, reason, and disposition snapshots;
* Open Ring lines preserve description, department, tax, and price facts;
* return lines do not use current sale price when historical calculation is required;
* disposition produces the accepted completion-time inventory behavior;
* mixed transactions calculate their net balance correctly;
* Tender is blocked while required return information is incomplete.

---

## 12. Slice 7 — Pickup and stored-value line entry

This slice may be implemented as two independently reviewable sub-slices.

### 12.1 Product Request pickup

#### Outcome

The cashier can find open customer demand and add eligible pickup quantities to a transaction.

#### Includes

* lookup by Customer or request reference;
* selection of eligible lines and quantities;
* fulfilment linkage;
* duplicate-fulfilment protection;
* reservation and inventory behavior;
* completion-time update of the originating Product Request.

### 12.2 Stored-value issuance and reload

#### Outcome

The cashier can issue or reload stored value as transaction activity.

#### Includes

* resolve or create an eligible stored-value account;
* validate account status;
* add issuance or reload line;
* delay account balance effects until completion;
* post the correct append-only ledger entry at completion;
* show customer-facing account type and masked identifier.

## Gate B exit

Gate B is accepted when the cashier can perform the supported transaction-entry workflows from inside the POS shell:

* Product lookup;
* Customer stage and attachment;
* linked and permitted unlinked returns;
* Open Ring;
* Product Request pickup;
* stored-value issuance and reload.

---

# Gate C — Financial completion

## 13. Slice 8 — Tender foundation and cash

### Outcome

A cashier can move from Transaction to Tender, settle using cash, and complete safely.

### Includes

* Tender presentation;
* direction derived from transaction balance:

  * Amount Due;
  * Refund Due;
  * Settled;
* cash received;
* cash refunded;
* amount presented;
* applied amount;
* change calculation;
* recorded tender list;
* safe Return to Transaction;
* completion readiness;
* atomic completion;
* idempotency;
* initial Receipt transition.

### Acceptance criteria

* positive balance presents receipt tendering;
* negative balance presents refund tendering;
* zero balance is recognized as settled;
* cash received records presented, applied, and change values correctly;
* cash refund records an explicit refunded tender;
* Return to Transaction is allowed only when settlement state is safe;
* duplicate completion submissions produce one completed transaction;
* completion posts inventory and assigns one receipt number;
* failed completion preserves the open transaction and valid tender facts;
* successful completion transitions to read-only Receipt.

Cash-only completion is the first complete posting path and must be stable before adding the full tender matrix.

---

## 14. Slice 9 — Card, stored value, and split tender

### Outcome

The cashier can settle realistic payment and refund combinations.

### Includes

* standalone-card receipt tender;
* standalone-card refund tender;
* partial card tender;
* stored-value redemption;
* stored-value refund or restoration;
* store-credit creation where existing policy permits;
* split tender;
* mixed sale-and-return net settlement;
* original-tender refund policy;
* tender removal and void behavior;
* commercial-editing protection after external activity.

### Acceptance criteria

* card confirmation stores only permitted metadata;
* full card data is never accepted or retained;
* partial tenders reduce the remaining balance correctly;
* stored-value redemption cannot exceed eligible balance or amount due;
* stored-value balance changes only through completed ledger posting;
* refunds follow accepted original-tender and store-credit policy;
* mixed transactions settle only the net difference by default;
* removing or voiding tender preserves external-payment safety;
* unresolved external activity blocks unsafe Return to Transaction.

## Gate C exit

Gate C is accepted when realistic cash, standalone-card, stored-value, refund, and split-tender combinations can be completed atomically and idempotently.

---

# Gate D — Customer-facing completion

## 15. Slice 10 — Receipt core and Receipt Lookup

Gate D remains a Phase 11 exit gate, but its scope is divided into **Must**, **Should**, and **Later**.

## 15.1 Must — Phase 11 exit scope

The mandatory receipt core includes:

* read-only Receipt presentation after completion;
* printable basic customer receipt;
* completed-transaction facts from historical snapshots;
* store identity and basic presentation;
* receipt number;
* receipt lookup;
* functional reprint;
* reprints marked `REPRINT`;
* original receipt number retained;
* print or display failure does not reverse completion;
* Receipt Lookup cannot mutate the transaction.

Gate D may be accepted when this mandatory core is complete.

## 15.2 Should — first scope cuts

The following remain planned Phase 11 work but may be deferred without preventing Phase 11 completion:

* non-itemized gift receipt;
* dedicated stored-value issuance or reload slip;
* richer receipt variants for return, mixed, and post-void presentation;
* receipt-number barcode;
* expanded template formatting;
* begin linked return directly from Receipt Lookup;
* current receipt header/footer administration beyond existing configuration.

Any Should item not delivered must be explicitly re-registered under DWR-017 rather than silently dropped.

## 15.3 Later extensions

The following remain outside Phase 11:

* ESC/POS printer-fleet management;
* printer queues;
* cross-device print orchestration;
* advanced hardware configuration;
* broad template-management infrastructure;
* offline printing.

## Gate D exit

Gate D is accepted when:

* a completed transaction has a stable read-only Receipt presentation;
* staff can find and reprint the receipt;
* customer-facing evidence uses completed historical facts;
* reprinting does not recalculate commercial history;
* presentation or printing failure cannot reverse completion;
* any undelivered Should scope is explicitly retained in DWR-017.

---

# Gate E — Release readiness

## 16. Slice 11 — Dedicated Recovery

### Outcome

The register safely handles financial uncertainty that cannot be resolved through ordinary Tender controls.

### Initial Recovery condition

Phase 11 begins with a closed list containing:

```text
void_required
```

No speculative general recovery framework is introduced.

### Includes

* dedicated Recovery presentation;
* external-terminal verification instructions;
* supervisor approval where required;
* explicit resolution actions;
* transition back to Tender, Transaction, or Receipt where valid;
* prevention of duplicate external payment activity.

### Acceptance criteria

* a `void_required` tender always restores Recovery;
* Recovery clearly describes the uncertain financial state;
* the cashier cannot add another tender or edit commercial lines while blocked;
* resolution records the actual action and actor;
* resolution derives the correct next presentation;
* refresh cannot bypass Recovery;
* ordinary validation failures stay in Transaction or Tender.

---

## 17. Slice 12 — Integrated interaction and release hardening

### Outcome

The complete workspace behaves as one coherent, efficient, accessible register.

### Includes

* final keyboard contract;
* numpad Enter detection with fail-closed behavior;
* `Ctrl+Enter` progression where documented;
* deterministic focus restoration;
* live-region announcements;
* scanner timing and duplicate-input tests;
* persistent actionable errors;
* permission matrix;
* performance profiling;
* browser and representative hardware testing;
* end-to-end presentation restoration;
* density and styling refinement;
* full absorption of DWR-010.

### Required cashier journeys

1. ordinary cash sale;
2. split cash/card sale;
3. stored-value redemption;
4. linked return to original tender;
5. permitted no-receipt or gift-receipt return to store credit;
6. mixed sale and return;
7. suspended transaction recall;
8. Product Request pickup;
9. stored-value issue or reload;
10. card tender entering Recovery;
11. presentation or printer failure after successful completion;
12. browser refresh in every presentation;
13. duplicate submission during scan, tender, and completion;
14. permission-restricted refund, override, and session action;
15. keyboard-only journey from Ready through Receipt.

Keyboard and accessibility behavior must be implemented throughout earlier slices. Slice 12 verifies consistency rather than adding accessibility at the end.

## Gate E exit

Gate E is accepted when:

* Recovery safely handles the accepted uncertain-tender condition;
* keyboard, scanner, focus, and live-region contracts pass;
* duplicate input does not create duplicate commercial activity;
* restricted actions and data remain permission-gated;
* refresh restores every presentation correctly;
* the documented cashier journeys pass;
* DWR-010 is closed or any residual is explicitly re-registered.

---

## 18. Cross-cutting requirements

Every gate must preserve the following.

### Data authority

* persisted business facts remain authoritative;
* views do not infer or store competing transaction state;
* completed transaction history is never recalculated from current master data.

### Inventory

* open Product lines create or maintain explicit reservations;
* completion converts reservations into the accepted inventory movement;
* suspension preserves reservations;
* cancellation releases reservations;
* negative inventory continues to warn and allow under current policy;
* individually tracked merchandise requires an eligible exact unit.

### Tender safety

* unresolved tender activity blocks suspension and unsafe editing;
* standalone-card handling remains manual confirmation;
* full card data is never stored;
* stored-value effects post only at completion;
* duplicate completion cannot duplicate ledger, inventory, or receipt effects.

### Accessibility

* all essential workflows are keyboard operable;
* focus movement is predictable;
* errors remain associated with the relevant action or field;
* live-region announcements are concise and meaningful;
* color is not the sole status indicator;
* reduced-motion preferences are respected.

### Performance

* the shell avoids unbounded collection loading;
* lookup results are bounded and paginated where necessary;
* summary services avoid N+1 queries;
* repeated scanning does not require full-page reload;
* performance testing uses realistic transaction sizes.

---

## 19. Deferred-work mapping

| DWR         | Phase 11 disposition                                                                                                   |
| ----------- | ---------------------------------------------------------------------------------------------------------------------- |
| **DWR-067** | Phase 11 epic; resolved when Gates A–E are accepted or residual work is explicitly re-registered                       |
| **DWR-010** | Absorbed into Gate E                                                                                                   |
| **DWR-017** | Mandatory receipt core in Gate D; richer receipt documents may remain deferred; printer fleets remain later extensions |
| **DWR-020** | POS-native lookup may reuse the shared pattern; purchasing/receiving adoption remains separate                         |
| **DWR-066** | Not Phase 11 scope; mandatory before receipt/PO/cost permissions are granted independently of `stock_view`             |

---

## 20. Independent maintenance

DWR-028 and DWR-064 are independent Catalog maintenance.

They:

* may land before or alongside early Phase 11 work;
* do not block Phase 11 scheduling;
* are not Phase 11 gates;
* must not be added to the Phase 11 dependency tree.

---

## 21. Parallel design work

The **Correction Integrity Design Packet** may proceed in parallel with Phase 11:

* DWR-004 — posted-receipt correction;
* DWR-005 — post-settlement post-void;
* DWR-006 — return-containing post-void.

Phase 11 must not implement or invent these algorithms.

Correction implementation begins only after the combined packet is accepted.

---

## 22. Conditional enablers

The following remain outside Phase 11 exit scope unless a concrete gate is blocked:

* DWR-001 — store configuration home;
* DWR-018 — control-master administration;
* DWR-019 — organization/store settings UI.

Potential triggers include:

* mandatory receipt identity or presentation that cannot use existing fields;
* cash-drop thresholds;
* card reconciliation grain;
* an existing seed-only control master that operations must maintain.

Only the minimum required settings slice should be pulled. Phase 11 must not create a speculative universal configuration platform.

---

## 23. Explicit non-goals

Phase 11 does not include:

* Register Lock;
* session takeover;
* acting-user switching;
* cross-device register control;
* integrated card-terminal automation;
* processor settlement;
* chargebacks;
* offline POS or PWA architecture;
* posted-receipt correction;
* post-settlement post-void;
* return-containing post-void;
* full CRM;
* households;
* loyalty;
* outbound notifications;
* advanced promotions;
* reusable or component-level tax exemptions;
* multi-variant Product unlock;
* store-specific pricing;
* accounting export;
* multi-tenant SaaS;
* full ESC/POS printer infrastructure.

---

## 24. Phase exit criteria

Phase 11 is complete when:

1. Gates A–E are accepted.
2. The register derives Ready, Transaction, Tender, Recovery, and Receipt from persisted facts.
3. Navigation, staged Customer selection, and entry intent do not create empty transactions.
4. The first valid customer action creates its transaction work atomically.
5. Refresh never mutates transaction state.
6. Ordinary sale construction, suspend, cancellation, and recall work through the shell.
7. Product lookup, Customer attachment, returns, Open Ring, pickup, and stored-value line entry work through the shell.
8. Cash, standalone-card, stored-value, refund, and split-tender combinations complete atomically and idempotently.
9. Commercial editing locks during tender and reopens only when settlement state is safe.
10. The mandatory receipt core supports presentation, lookup, and reprint.
11. Print or presentation failure does not reverse completion.
12. Recovery remains a closed list beginning with `void_required`.
13. Keyboard, scanner, focus, accessibility, permission, and resilience journeys pass.
14. DWR-010 is closed or its residual is re-registered.
15. DWR-017 and DWR-020 are updated to show delivered and remaining scope.
16. DWR-067 is marked resolved or replaced by explicitly registered residual items.
17. Governing POS design documents match the shipped behavior.
18. Full CI passes.

Accepted completion wording:

```text
Fully complete — Gates 11A–11E accepted
```

---

## 25. Issue and branch strategy

Prefer:

* one Phase 11 epic;
* one issue per gate, with slice-level child issues only where a gate is too large for one branch;
* short-lived vertical-slice branches;
* no issue per deferred capability.

Suggested epic:

```text
Phase 11 — POS Shell and Workspace Revamp
```

Suggested gate issues:

```text
11A — Stable register foundation
11B — Complete transaction entry
11C — Financial completion
11D — Customer-facing completion
11E — Release readiness
```

Each PR must state:

* gate and slice;
* cashier outcome;
* domain effects;
* authorization changes;
* keyboard and accessibility behavior;
* tests added;
* DWR disposition changes.

---

## 26. Scheduling and documentation bookkeeping

When this plan is promoted:

1. Add Phase 11 to `roadmap.md`.
2. Set `current-phase.md` to Phase 11 — scheduled or in progress.
3. Set DWR-067 target to Phase 11.
4. Point DWR-010 to Gate E.
5. Split DWR-017 into:

   * Gate D mandatory receipt core;
   * Should-level receipt variants;
   * later printer infrastructure.
6. Point only the POS portion of DWR-020 to Gate B.
7. Record DWR-066 as a triggered authorization invariant.
8. List DWR-004–006 as parallel design work.
9. Keep DWR-001/018/019 conditional.
10. Keep DWR-028/064 outside the dependency tree.
11. Archive or supersede the former Phase 11 stub and sequencing drafts after their accepted content is incorporated.
12. Retain the broader Deferred-Work Prioritization Matrix as a planning projection rather than a governing implementation phase.

---

## 27. Sequencing after Phase 11

The preferred subsequent sequence is:

```text
Phase 11
  → Correction workflows, when the design packet is accepted
  → Reporting and reconciliation hardening
```

This is a preference, not a hard dependency.

If correction design remains unresolved, reporting work such as stored-value liability integrity and the remaining Phase 7e report pack may proceed independently.

Subsequent phase numbers follow actual delivery order.
