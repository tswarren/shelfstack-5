# Recommended milestone slices

Use **vertical slices** that produce a complete cashier outcome. Avoid implementing all models first, then all controllers, then all screens. Each slice should include its domain changes, service behavior, POS presentation, permissions, keyboard handling, and automated tests.

## Slice 1 — POS shell and presentation resolver

### Outcome

The register reliably opens in the correct operational condition or POS presentation.

### Includes

* Dedicated POS layout  
    
* Central current-session resolution  
    
* Business Day required condition  
    
* POS Session required condition  
    
* Presentation resolver for:  
    
  * Ready  
  * Transaction  
  * Tender  
  * Recovery  
  * Receipt


* Shared register header and left/right workspace geometry  
    
* Processing and duplicate-submission protection  
    
* Server-authoritative restoration after refresh

### Acceptance tests

* No Business Day shows the appropriate prerequisite screen.  
* Open Business Day with no user session shows session opening.  
* Open session with no active transaction shows Ready.  
* Editable active transaction restores Transaction.  
* Transaction with settlement context restores Tender.  
* `void_required` tender restores Recovery.  
* Completed transaction reached through completion restores Receipt.  
* Refresh never creates, cancels, suspends, or otherwise changes a transaction.

This slice establishes the routing contract for everything that follows.

---

## Slice 2 — Ready workspace and first-sale path

### Outcome

A cashier can open a session, scan an item from Ready, and begin a transaction without encountering an intermediate empty transaction.

### Includes

* Ready workspace  
    
* Primary scan field  
    
* Unique scan-to-start behavior  
    
* Ambiguous and unsuccessful scan outcomes  
    
* Suspended transaction summary  
    
* Existing session actions integrated into the new shell:  
    
  * Cash Movement  
  * No Sale  
  * Session X  
  * Close Session  
  * Store Operations


* Passive cash-drop indication  
    
* Removal of sensitive reporting totals from the register shell

### Acceptance tests

* A valid unique scan atomically creates the transaction, line, and reservation.  
* An invalid or ambiguous scan creates no transaction.  
* Repeated submission cannot create duplicate lines or transactions.  
* Suspended transactions do not prevent Ready.  
* An active transaction prevents Ready.  
* No Sale records an audited drawer action without creating a cash movement.  
* Users without permission cannot invoke restricted session actions.  
* Expected cash, variance, sales totals, and tender totals are absent from the shell.

This gives the milestone its first usable end-to-end cashier workflow.

---

## Slice 3 — Core Transaction workspace

### Outcome

A cashier can build, review, suspend, or cancel an ordinary sale.

### Includes

* Transaction line list  
* Repeated scanning  
* Quantity changes  
* Line removal  
* Selected-line context  
* Running totals  
* Inventory reservations  
* Individually tracked unit selection  
* Readiness summary  
* Suspend  
* Cancel  
* Begin Tender  
* Safe focus return to the scan field

### Acceptance tests

* Adding, changing, and removing lines updates totals and reservations correctly.  
* Individually tracked merchandise requires an eligible exact unit.  
* Negative availability produces the intended warning rather than an unintended hard block.  
* Suspending preserves the transaction and reservations and returns to Ready.  
* Cancelling releases reservations and returns to Ready.  
* Suspension is rejected when unresolved tender activity exists.  
* Begin Tender is blocked when readiness requirements are incomplete.  
* Refresh restores the same authoritative line and reservation state.

At the end of this slice, ordinary sale construction should be stable before special workflows are added.

---

## Slice 4 — POS-native Product lookup

### Outcome

A cashier can search for Products without leaving the register and add the selected Variant where the current context permits.

### Includes

* Shared POS lookup presentation  
    
* Product search by:  
    
  * ISBN or trade identifier  
  * ISBN-10 normalization  
  * SKU  
  * alternate identifier  
  * title  
  * creator  
  * exact Inventory Unit identifier


* Exact, multiple, no-match, unavailable, and restricted outcomes  
    
* Product and Variant result grouping  
    
* Current-store price and availability  
    
* Add from Ready  
    
* Add from Transaction  
    
* View-only behavior in Tender and Recovery

### Acceptance tests

* Explicit lookup never automatically adds an exact match.  
* Adding from Ready atomically creates the transaction and line.  
* Adding from Transaction uses the existing transaction.  
* Failed addition from Ready leaves no empty transaction.  
* Inactive or ineligible matches explain why they cannot be sold.  
* Acquisition cost, margin, internal IDs, and other restricted information are not shown.  
* Keyboard navigation works through results.

This slice also establishes the reusable lookup interaction pattern for Customer and Stored Value.

---

## Slice 5 — Customer records and Customer lookup

### Outcome

A cashier can create, find, stage, attach, replace, and remove a Customer within the POS shell.

### Includes

* Flat Customer model  
    
* Individual and Organization types  
    
* Name validation  
    
* Address fields  
    
* Phone normalization to E.164  
    
* Email normalization  
    
* Possible-duplicate warnings  
    
* Compact POS Customer form  
    
* Search by:  
    
  * individual name  
  * organization name  
  * organization contact name  
  * phone  
  * email


* Stage Customer from Ready  
    
* Attach, replace, or remove Customer in Transaction  
    
* Read-only Customer display after tender locking

### Acceptance tests

* Individual and Organization validation follows the agreed rules.  
* Phone and email are normalized before storage.  
* Duplicate contact values warn but are not globally rejected.  
* Selecting a Customer from Ready creates no transaction.  
* The staged Customer is attached atomically with the first valid transaction work.  
* Attaching or replacing a Customer can trigger required recalculations.  
* Customer changes are rejected once commercial editing is locked.  
* Customer notes do not appear in broad lookup results.

This should be independently deployable even before all Customer-dependent pricing or exemption capabilities are added.

---

## Slice 6 — Return and Open Ring workflows

### Outcome

A cashier can construct mixed sale-and-return activity and add merchandise not represented by a normal Product record.

### Includes

* Return entry intent  
* Linked return lookup  
* Unlinked return Product selection  
* Open Ring sale lines  
* Open Ring return lines  
* Return reason  
* Return source or basis  
* Return disposition  
* Historical refund calculation where linked  
* Required approval handling  
* Mixed sale and return totals  
* Net settlement calculation

### Acceptance tests

* Linked returns preserve original commercial facts.  
* Unlinked returns collect all required snapshots and reasons.  
* Open Ring lines retain description, department, tax, and price facts.  
* Return lines do not incorrectly use current sale prices.  
* Return dispositions produce the correct completion-time inventory behavior.  
* Mixed transactions calculate the net balance correctly.  
* Readiness blocks Tender when required return information is missing.

Return behavior should be proven before introducing the more complex refund tender matrix.

---

## Slice 7 — Pickup and Stored Value line-entry workflows

This is best treated as two sub-slices because they depend on different domains.

### Slice 7A — Customer Order pickup

#### Outcome

The cashier can locate open Customer Order or Product Request work and add eligible pickup lines to a transaction.

#### Acceptance boundary

* Lookup by customer or request reference  
* Selection of eligible lines and quantities  
* Correct fulfillment linkage  
* No duplicate fulfillment  
* Correct reservation and inventory behavior  
* Completion updates the originating request

### Slice 7B — Stored Value issuance and reload

#### Outcome

The cashier can issue or reload Stored Value as transaction activity.

#### Acceptance boundary

* Resolve or create an account  
* Validate account status  
* Add issuance or reload line  
* Do not change account balance before transaction completion  
* Correct completed ledger posting  
* Correct customer-facing account type and masked presentation

These may be scheduled separately if Customer Order functionality is less ready than Stored Value.

---

## Slice 8 — Tender foundation and cash settlement

### Outcome

A cashier can move from Transaction to Tender, settle a transaction using cash, and complete it safely.

### Includes

* Tender presentation  
* Direction derived from balance  
* Amount Due, Refund Due, and Settled states  
* Cash received  
* Cash refunded  
* Cash tendered and change calculation  
* Recorded tender list  
* Safe Return to Transaction  
* Completion readiness  
* Atomic completion  
* Idempotency protection  
* Initial Receipt transition, even before full printing support

### Acceptance tests

* Positive balance offers receipt tendering.  
* Negative balance offers refund tendering.  
* Zero balance is recognized as settled.  
* Cash received records amount presented, applied, and change correctly.  
* Cash refund records an explicit refunded tender.  
* Returning to Transaction is allowed only when settlement state is safe.  
* Duplicate completion submissions produce one completed transaction.  
* Completion posts inventory and assigns one receipt number.  
* Failed completion preserves the open transaction and valid tender facts.  
* Successful completion transitions to a read-only Receipt presentation.

This is the most important commercial slice. Cash-only completion provides a constrained path for testing the full posting boundary before adding other tender types.

---

## Slice 9 — Card, Stored Value, and split tender

### Outcome

A cashier can settle realistic payment and refund combinations.

### Includes

* Standalone card receipt tender  
* Standalone card refund tender  
* Partial card tenders  
* Stored Value redemption  
* Stored Value refund or restoration  
* Store Credit creation where policy permits  
* Split tender  
* Mixed sale-and-return net settlement  
* Original-tender refund policy  
* Tender removal and void behavior  
* Commercial-editing protection after external activity

### Acceptance tests

* Card confirmation stores only permitted metadata.  
* Full card data is never accepted or retained.  
* Partial tenders reduce the remaining balance correctly.  
* Stored Value redemption cannot exceed eligible balance or amount due.  
* Stored Value balance changes only through completed postings.  
* Refunds follow original-tender and Store Credit policy.  
* Mixed transactions settle only the net difference by default.  
* Removing or voiding tenders preserves external-payment safety.  
* Unresolved external activity blocks unsafe return to Transaction.

This slice should use a broad tender matrix rather than a few isolated examples.

---

## Slice 10 — Receipt documents and Receipt Lookup

### Outcome

A completed transaction produces usable customer-facing documents and can later be found and reprinted.

### Includes

* Customer Receipt generation  
* Derived Receipt, Return Receipt, mixed, and Post-Void presentation  
* Current store header and footer  
* Historical completed transaction facts  
* Non-itemized Gift Receipt  
* Receipt-number barcode  
* Stored Value activity slip  
* Printable HTML  
* Immediate print and retry  
* Receipt Lookup  
* Functional reprints marked `REPRINT`  
* Begin linked return from Receipt Lookup

### Acceptance tests

* Printing occurs only after completion.  
* Print failure does not alter completion.  
* A reprint retains historical transaction facts and the original receipt number.  
* Current store presentation configuration may differ on later reprints.  
* Gift Receipts contain no item, price, tax, tender, Customer, or Stored Value information.  
* A Gift Receipt barcode locates the original transaction but does not authorize a return by itself.  
* Stored Value slips show the post-transaction balance, not a current live balance.  
* Receipt Lookup cannot mutate the completed transaction.

Receipt generation can be developed in parallel earlier, but integration belongs after completion is stable.

---

## Slice 11 — Dedicated Recovery

### Outcome

The register safely handles financial uncertainty that cannot be resolved through ordinary Tender controls.

### Includes

* Recovery presentation  
* `void_required` tender handling  
* External terminal verification instructions  
* Supervisor approval where required  
* Explicit recovery actions  
* Safe transition back to Tender, Transaction, or Receipt  
* Prevention of duplicate external payment activity

### Acceptance tests

* A `void_required` tender always restores Recovery.  
* Recovery clearly describes the uncertain financial state.  
* The cashier cannot add another tender or edit commercial lines while blocked.  
* Resolution records the actual action and actor.  
* Resolving the blocker derives the correct next presentation.  
* Refresh during Recovery cannot bypass it.  
* Ordinary validation failures remain in Transaction or Tender rather than being misclassified as Recovery.

Keep this narrow. Do not build a speculative general recovery framework for conditions that do not yet exist.

---

## Slice 12 — Integrated interaction and release hardening

### Outcome

The complete milestone behaves as one coherent, efficient, accessible register.

### Includes

* Final keyboard contract  
* Numpad Enter detection with fail-closed behavior  
* `Ctrl+Enter` progression  
* Focus restoration  
* Live-region announcements  
* Scanner timing and duplicate-input testing  
* Error persistence  
* Permission matrix  
* Performance profiling  
* Browser and hardware testing  
* End-to-end state restoration  
* Styling and density refinement

### Acceptance tests

Use complete cashier journeys rather than isolated controller tests:

1. Ordinary cash sale  
2. Split cash/card sale  
3. Stored Value redemption  
4. Linked return to original tender  
5. Gift-receipt return to Store Credit  
6. Mixed sale and return  
7. Suspended transaction recall  
8. Customer Order pickup  
9. Stored Value issue or reload  
10. Card tender requiring Recovery  
11. Printer failure after successful completion  
12. Browser refresh in every presentation  
13. Duplicate submission during scan, tender, and completion  
14. Permission-restricted discount, refund, and session action  
15. Keyboard-only transaction from Ready through Receipt

Keyboard and accessibility behavior should be implemented in every earlier slice; this slice verifies consistency across the complete workflow.

# Suggested dependency order

```
1. Shell and resolver
        ↓
2. Ready and first sale
        ↓
3. Core Transaction
        ├───────────────┐
        ↓               ↓
4. Product Lookup    5. Customer
        └───────┬───────┘
                ↓
6. Return/Open Ring
7. Pickup/Stored Value lines
                ↓
8. Tender foundation and cash
                ↓
9. Card/Stored Value/split tender
                ↓
10. Receipt documents
                ↓
11. Recovery
                ↓
12. Integrated hardening
```

Receipt document building can proceed in parallel once completed transaction facts are stable. Customer records and Product lookup can also proceed partly in parallel after the shared POS lookup contract exists.

# Recommended delivery gates

## Gate A — Stable register foundation

Slices 1–3 complete.

A cashier can:

* enter the register;  
* scan and build an ordinary sale;  
* suspend or cancel;  
* restore state after refresh.

## Gate B — Complete transaction entry

Slices 4–7 complete.

A cashier can use:

* Product lookup;  
* Customer records;  
* returns;  
* Open Ring;  
* pickup;  
* Stored Value issuance and reload.

## Gate C — Financial completion

Slices 8–9 complete.

A cashier can settle and atomically complete realistic payment and refund combinations.

## Gate D — Customer-facing completion

Slice 10 complete.

Transactions produce receipts, Gift Receipts, Stored Value slips, and functional reprints.

## Gate E — Release readiness

Slices 11–12 complete.

The register safely handles unresolved external tender activity and passes the full interaction, accessibility, permission, and resilience matrix.

# Cross-cutting completion checklist

Every slice should include:

* domain and database changes;  
* application-service behavior;  
* POS presentation;  
* permission enforcement;  
* actor attribution;  
* idempotency where applicable;  
* keyboard behavior;  
* accessibility behavior;  
* request and model tests;  
* system tests for the cashier outcome;  
* refresh and stale-request behavior;  
* documentation updates.

A slice is not complete merely because its model and controller exist. It is complete when the cashier outcome works through the POS shell and its important failure paths are tested.

The deferred Register Lock and Session Access work should remain outside these slices. It can later build on the centralized session resolver and authoritative presentation restoration without expanding the current milestone.  
