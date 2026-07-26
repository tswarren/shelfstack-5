# ShelfStack Deferred-Work Prioritization Matrix

**Status:** Proposed planning framework
**Starting point:** Phase 10 complete
**Recommended next delivery phase:** Phase 11 — POS Shell and Workspace Revamp
**Purpose:** Group unresolved deferred work into coherent delivery phases, parallel design work, conditional enablers, maintenance, and explicitly parked extensions.

---

## 1. Planning principles

ShelfStack’s Deferred Work Register is not a single ranked backlog. It includes:

* ready delivery debt;
* unresolved design decisions;
* temporary operational blocks;
* conditional enabling work;
* intentionally deferred capabilities;
* documentation history.

These categories should not compete directly with one another.

The prioritization model therefore uses six planning dispositions:

1. **Next delivery phase**
   Work that belongs in the next coherent user-facing phase.

2. **Independent maintenance**
   Small, bounded fixes that may land before or alongside a phase but do not block its scheduling.

3. **Parallel design**
   Important work that needs an accepted design before implementation can begin.

4. **Conditional enablers**
   Settings, administration, or infrastructure pulled only when a specific delivery requirement demonstrates the need.

5. **Triggered invariants**
   Work that becomes mandatory when a particular architectural or authorization condition is introduced.

6. **Parked or pressure-driven work**
   Capabilities that remain unscheduled until merchant need, design readiness, or operational pressure justifies promotion.

The governing sequence is:

```text
daily operational value
  → removes operational or integrity risk
  → unlocks accepted work
  → design readiness
  → coherent delivery scope
  → merchant pressure
  → later extensions
```

---

# 2. Recommended delivery spine

```text
Phase 10 complete
        │
        ├── Independent maintenance
        │     DWR-028 / DWR-064
        │     May land before or alongside Phase 11
        │     Does not block Phase 11 scheduling
        │
        ▼
Phase 11 — POS Shell and Workspace Revamp
        │
        ├── Parallel design:
        │     Correction Integrity Design Packet
        │     DWR-004 / DWR-005 / DWR-006
        │
        ├── Conditional settings work:
        │     DWR-001 / DWR-018 / DWR-019
        │     Only when a concrete phase requirement needs it
        │
        ▼
Preferred next phase:
Correction Workflows
        │
        ├── Accepted implementations from DWR-004–006
        ├── DWR-011
        └── DWR-012

Independent subsequent candidate:
Reporting and Reconciliation Hardening
        │
        ├── DWR-015
        ├── DWR-016
        ├── DWR-013
        └── DWR-014

Later phases:
Catalog, inventory, customer, commerce, or platform work
selected by operational pressure and design readiness
```

Corrections remain the preferred phase after Phase 11, but reporting is not technically blocked by completion of the correction phase. Reporting work may proceed if correction design stalls.

Phase numbering after Phase 11 should follow actual delivery order. If reporting ships before corrections, it should receive the next chronological phase number rather than preserving a conceptual number reservation.

---

# 3. Next delivery phase

## Phase 11 — POS Shell and Workspace Revamp

### Phase goal

Make the existing ShelfStack transaction engine operate as one coherent cashier workspace:

```text
Ready
  → Transaction
  → Tender
  → Complete
  → Receipt or completion confirmation
  → Ready
```

Phase 11 is primarily a workflow, interaction, and presentation phase. It should consume existing POS capabilities rather than expand the POS domain into payments, offline operation, advanced promotions, or correction algorithms.

## Phase 11 DWR mapping

| DWR         | Work                                | Phase 11 treatment                                                                                    |
| ----------- | ----------------------------------- | ----------------------------------------------------------------------------------------------------- |
| **DWR-067** | POS shell and workspace revamp      | Phase epic covering Gates A–E                                                                         |
| **DWR-010** | Keyboard and scanner stabilization  | Fully absorbed into Gate E                                                                            |
| **DWR-017** | Customer receipt product            | Split between mandatory receipt core, Should-level receipt variants, and later printer infrastructure |
| **DWR-020** | Searchable picker / nested combobox | Use relevant patterns for POS-native lookup; keep purchasing and receiving adoption separate          |

---

## Gate A — Stable register foundation

### Cashier outcome

The cashier can enter the register, begin work from a scan or deliberate action, build an ordinary transaction, suspend or cancel safely, and recover the authoritative transaction after refresh.

### Scope

* authoritative register-state resolver;
* Ready presentation;
* scan-to-start without creating empty transactions;
* ordinary sale-line entry;
* transaction restoration after refresh;
* suspend and cancel;
* no mutation from browser presentation state.

### Exit criteria

* navigation alone does not create a transaction;
* first valid customer work creates the transaction atomically;
* refresh derives presentation from persisted business facts;
* failed initial actions leave no empty transaction;
* ordinary validation remains inline rather than entering Recovery.

---

## Gate B — Complete transaction entry

### Cashier outcome

The cashier can perform the ordinary transaction-building workflows without leaving the POS shell.

### Scope

* POS-native Product lookup;
* Customer stage and attach;
* linked and permitted unlinked returns;
* Open Ring;
* Product Request pickup;
* stored-value issue or reload lines;
* relevant DWR-020 interaction patterns.

### DWR-020 boundary

Phase 11 may adopt the existing shared lookup and picker patterns, but it should not absorb all remaining DWR-020 work.

Remain deferred:

* Purchase Order nested-line adoption;
* receipt nested-line adoption;
* unrelated shared-form refactoring.

---

## Gate C — Financial completion

### Cashier outcome

The cashier can tender and complete transactions safely within the continuous register workflow.

### Scope

* cash tender;
* standalone card tender;
* stored-value tender;
* split tender;
* safe return from Tender to Transaction when no unresolved tender activity exists;
* atomic and idempotent completion;
* protection against duplicate submission;
* proper handling of completion uncertainty.

### Exit criteria

* commercial editing locks when tendering begins;
* returning to Transaction is permitted only when tender state is safe;
* completion is atomic and idempotent;
* standalone card behavior remains consistent with the accepted card ADR;
* declined external card attempts are not recorded as tenders;
* unresolved financial conditions do not silently reopen ordinary editing.

---

## Gate D — Customer-facing completion

Gate D remains part of Phase 11, but its scope is divided into **Must** and **Should** work.

### Must

The cashier product requires a minimal, stable completion record:

* basic customer receipt presentation;
* receipt lookup;
* receipt reprint;
* stable transaction-completion confirmation;
* print or presentation failure does not reverse transaction completion.

This narrow receipt core remains an exit requirement because the completed transaction must have retrievable customer and operator evidence.

### Should

These are the first cuts if Phase 11 scope or timing becomes excessive:

* gift receipt variant;
* dedicated stored-value issuance or reload slip;
* richer receipt templates;
* expanded presentation customization;
* nonessential receipt formatting refinements.

Should-level items may remain as residual DWR-017 work without preventing Phase 11 completion, provided the mandatory receipt core is delivered.

### Later extensions

Remain outside Phase 11:

* ESC/POS printer fleets;
* complex printer queues;
* cross-device print orchestration;
* advanced hardware configuration;
* broad template-management infrastructure.

---

## Gate E — Release readiness

### Cashier outcome

The workspace is reliable under fast data entry, scanner input, keyboard use, refresh, and the narrow set of known recovery conditions.

### Scope

* absorb DWR-010;
* scanner and hotkey journey matrix;
* deterministic focus movement;
* accessible live-region behavior;
* duplicate scan protection;
* keyboard-only completion paths;
* narrow Recovery presentation;
* `void_required` as the initial financial-recovery state;
* final workflow hardening.

### Exit criteria

* keyboard, scanner, focus, and accessibility journeys pass;
* input routing is deterministic;
* scanner bursts do not create duplicate actions;
* Recovery is a closed list rather than a general error screen;
* ordinary validation stays in Transaction or Tender;
* design documents match shipped behavior.

---

## Phase 11 non-goals

Phase 11 must not include:

* integrated payment-terminal control;
* processor settlement or chargebacks;
* offline POS or PWA architecture;
* posted-receipt correction;
* post-settlement or return-containing post-void algorithms;
* full CRM;
* loyalty;
* advanced promotions;
* multi-variant Product unlock;
* register lock, session takeover, or acting-user switching;
* accounting export;
* multi-tenant platform work;
* full receipt-printer fleet management.

---

# 4. Independent maintenance

Independent maintenance may be completed before or alongside early Phase 11 work. It does not block Phase 11 scheduling or promotion.

| DWR         | Work                                          | Treatment                                                 |
| ----------- | --------------------------------------------- | --------------------------------------------------------- |
| **DWR-028** | Product-import malformed `return_to` handling | Small Catalog boundary-hardening fix                      |
| **DWR-064** | Publication-date normalization boundary       | Small Catalog normalization-policy and input-boundary fix |

## DWR-028

Resolve malformed nested-query decoding so Product creation cannot commit successfully and then produce a redirect-time 500.

Expected result:

* malformed local return paths fall back safely;
* valid local return paths remain supported;
* absolute and protocol-relative URLs remain rejected;
* Product creation remains successful.

## DWR-064

Apply the accepted publication-date policy:

```text
YYYY       → YYYY-01-01
YYYY-MM    → YYYY-MM-01
YYYY-MM-DD → exact date
```

Also:

* accept explicit Date and date/time types;
* use the shared provider parser for strings;
* reject arbitrary `to_date` duck typing;
* return `nil` for invalid dates;
* retain no separate precision field in the current schema.

## Scheduling status

DWR-028 and DWR-064:

* are not Phase 11 gates;
* are not Phase 11 prerequisites;
* should not appear in the Phase 11 dependency tree;
* may be completed as one small maintenance PR;
* should be removed from active register buckets when resolved.

---

# 5. Parallel design

## Correction Integrity Design Packet

### DWR scope

* **DWR-004** — Posted-receipt correction
* **DWR-005** — Post-settlement post-void
* **DWR-006** — Return-containing post-void

These items form one design problem: how ShelfStack corrects completed or posted activity without editing history or breaking cross-domain integrity.

They should be designed together before any implementation phase begins.

## Design objectives

The packet must define:

* correction document identity;
* lifecycle and status;
* authorization and approval;
* reversal versus compensating-entry rules;
* idempotency;
* linked original records;
* inventory quantity consequences;
* moving-average cost and valuation consequences;
* Purchase Order and receipt fulfilment restoration;
* Product Request fulfilment restoration;
* reservation restoration or release;
* tender and stored-value consequences;
* handling of later activity after the original posting;
* deficit and negative-inventory interactions;
* report presentation;
* audit evidence;
* explicit non-correctable conditions.

## DWR-004 — Posted-receipt correction

The design must cover:

* reversing accepted receipt quantities;
* Purchase Order fulfilment;
* moving-average inventory cost;
* inventory already sold or otherwise consumed;
* allocations and reservations;
* individually tracked units where applicable;
* authorization;
* audit history.

The permission `inventory.receipt.correct` remains unseeded until this design is accepted.

## DWR-005 — Post-settlement post-void

The design must replace the current interim block with a safe algorithm for transactions affected by later activity.

It must account for:

* later sales or returns;
* stored-value entries;
* tender settlement evidence;
* inventory deficits;
* Product Request activity;
* linked corrections.

## DWR-006 — Return-containing post-void

The design must define how a transaction containing return lines can be reversed without mutating completed history.

It must include append-only restoration of Product Request fulfilment and any inventory-unit state changes.

## Implementation trigger

A correction implementation phase may begin only when:

1. the combined design packet is accepted;
2. cross-domain ownership is explicit;
3. test vectors cover ordinary and adverse sequences;
4. non-correctable scenarios are documented;
5. required permissions and approvals are defined.

---

# 6. Conditional enablers

Conditional enablers are not a parallel correction track. They form a separate settings and administration thread.

| DWR         | Work                               | Trigger                                                                                     |
| ----------- | ---------------------------------- | ------------------------------------------------------------------------------------------- |
| **DWR-001** | Store configuration home           | A phase needs an editable behavioral setting or threshold                                   |
| **DWR-019** | Organization/store settings UI     | Receipt content, card grain, address, or similar existing settings need operator management |
| **DWR-018** | Admin CRUD for control masters     | Operational users need to maintain seeded reason/type records                               |
| **DWR-003** | Role and store authority defaults  | Role templates or editable authority inheritance become active work                         |
| **DWR-007** | Negative-inventory blocking policy | A store requires stricter behavior and an accepted settings home exists                     |

## DWR-001 — Store configuration home

Do not design a universal configuration framework speculatively.

Pull only the minimum required setting ownership when a concrete workflow requires it.

Likely triggers include:

* Phase 11 receipt header/footer;
* cash-drop or till thresholds;
* Phase 13 card reconciliation grain;
* store-specific operational defaults.

## DWR-019 — Organization/store settings UI

A thin settings interface may be introduced when operators need to maintain existing values such as:

* store address;
* receipt header/footer;
* card reconciliation grain;
* organization defaults;
* other already-accepted configuration fields.

Do not use DWR-019 to invent broad new configuration policy.

## DWR-018 — Control-master administration

Potential scope includes:

* tender types;
* cash movement types;
* stored-value adjustment reasons.

Schedule only when seed-only management becomes an actual operational constraint.

## DWR-003 — Role and authority defaults

Remain deferred until ShelfStack needs:

* role templates;
* inheritance;
* editable default authority;
* one-role versus multi-role policy changes;
* broader role administration.

## DWR-007 — Negative-inventory hard blocking

Retain the current warning-and-allow behavior unless:

1. a merchant requires a hard block;
2. DWR-001 establishes where that policy lives;
3. authorization and exception behavior are accepted.

---

# 7. Triggered invariants

Triggered invariants are not ordinarily ranked backlog items. They become mandatory when their trigger condition is introduced.

## DWR-066 — Product-rail capability decoupling

### Trigger

Any role is allowed to receive one or more of the following without `stock_view`:

* last-received visibility;
* Purchase Order or on-order visibility;
* cost visibility.

### Required work

Before such a role configuration ships:

* build the product stock-summary object when any relevant capability exists;
* return `nil` for unauthorized fields;
* gate each product-rail row independently;
* verify no value is overexposed;
* verify independently authorized values are not suppressed.

### Current status

DWR-066 is not a Phase 11 deliverable because current roles still bundle these capabilities with `stock_view`.

It becomes a hard precondition before permission bundles are separated.

---

# 8. Subsequent delivery candidates

## A. Correction Workflows

Corrections are the preferred next delivery phase after Phase 11, provided the design packet is accepted.

### Candidate scope

* implementation of accepted DWR-004 design;
* implementation of accepted DWR-005 design;
* implementation of accepted DWR-006 design;
* DWR-011 linked correction resolutions;
* DWR-012 resolution superseding and post-finalization policy.

### DWR-011

Implement linked resolution records only after owning-domain correction contracts are stable.

### DWR-012

Define whether and how finalized resolutions can be superseded. Until then, the existing finalize freeze remains binding.

### Exit objective

ShelfStack can correct defined completed and posted activity through linked append-only records without rewriting historical facts.

---

## B. Reporting and Reconciliation Hardening

Reporting is a separately schedulable phase. It should follow corrections when practical, but it must not wait indefinitely for correction design.

### Recommended internal order

1. **DWR-015** — Organization-scoped stored-value liability and cache integrity
2. **DWR-016** — Complete the remaining Phase 7e report pack
3. **DWR-013** — Session card grain and merchant-slip close
4. **DWR-014** — Directional and multi-terminal card evidence

### DWR-015

Prioritize liability correctness before expanding report breadth.

Scope should include:

* organization-level stored-value liability;
* cache or projection integrity;
* reconciliation against the append-only ledger;
* explicit store activity versus organization liability.

### DWR-016

Complete the accepted Phase 7e report set using existing authoritative sources.

Do not reinterpret completed historical activity from current master data.

### DWR-013

Add session card reconciliation grain once the configuration ownership is accepted.

This may trigger a thin DWR-001/DWR-019 settings slice.

### DWR-014

Add directional or multi-terminal evidence after DWR-013 establishes the session-level comparison model.

Do not expand this into processor settlement, chargebacks, or integrated payments.

### Independence from corrections

DWR-015 and DWR-016 may proceed while correction design remains unresolved.

DWR-011 and DWR-012 remain correction-dependent and should not be folded into the reporting phase merely because they affect reports.

---

# 9. Pressure-driven Catalog work

Catalog follow-up should remain pressure-driven rather than committed to a fixed order.

| Operating pressure                                        | Candidate work                                  |
| --------------------------------------------------------- | ----------------------------------------------- |
| Buyers need better Product-to-vendor source maintenance   | **DWR-065**                                     |
| Staff need to enrich incomplete existing Products         | **DWR-022**                                     |
| Image, subject, or data-quality problems become material  | **DWR-023 / DWR-027**                           |
| Product Request coverage logic is actively changing       | **DWR-029**                                     |
| Multi-variant merchandise becomes operationally necessary | **DWR-021**, after a cross-domain design packet |

## DWR-065 — Vendor-source linking

Likely the strongest operational Catalog candidate, but not a fixed phase promise.

Pull when buyers need a direct workflow for:

```text
Product or Variant
  → Vendor search
  → Create or update vendor source
  → Vendor code, cost, pack, and terms
```

Purchasing remains the owning domain.

## DWR-022 — Enrich existing Product

Pull when:

* provider credentials are available;
* field-level apply behavior is accepted;
* conflict handling is designed;
* operator control over overwriting is clear.

Operational fields must not be overwritten merely because external metadata differs.

## DWR-023 / DWR-027

Images, subjects, BISAC mapping, and data-quality views should be grouped only when a concrete Catalog presentation or cleanup need exists.

## DWR-029

Treat as an internal ownership refactor when Product Request coverage or the Catalog product hub is next modified. It does not warrant an independent phase.

---

# 10. Parked structural Catalog work

| DWR         | Work                                              | Re-entry trigger                                        |
| ----------- | ------------------------------------------------- | ------------------------------------------------------- |
| **DWR-021** | Multi-variant unlock                              | Accepted cross-domain packet                            |
| **DWR-024** | Publisher/manufacturer party model                | ONIX, publisher feeds, or multi-role party requirements |
| **DWR-025** | Product merge and canonical-identifier correction | Controlled merge and audit design                       |
| **DWR-026** | Store-specific pricing                            | Accepted price-resolution hierarchy                     |

## DWR-021

Do not treat multi-variant support as a simple Product schema change.

The design must cover:

* Product forms;
* identifiers;
* Product Variant lifecycle;
* inventory;
* purchasing;
* receiving;
* POS;
* returns;
* reporting;
* pricing;
* historical snapshots.

## DWR-024

Retain string-based publisher/manufacturer data until external feeds or party-role requirements make the richer model necessary.

## DWR-025

Requires a controlled correction workflow for:

* duplicate Products;
* canonical identifier errors;
* dependent references;
* audit;
* irreversible merge consequences.

## DWR-026

Requires an accepted price-resolution order covering:

* organization defaults;
* store-specific prices;
* promotions;
* manual overrides;
* historical POS snapshots.

---

# 11. Parked inventory and supply-chain extensions

Inventory counts remain the best default first extension after current operational hardening. Work after counts should remain merchant-pressure driven.

| DWR         | Work                        | Planning position                                  |
| ----------- | --------------------------- | -------------------------------------------------- |
| **DWR-031** | Inventory counts            | Default first inventory extension                  |
| **DWR-030** | Detailed buyback            | Pressure-driven after dedicated acquisition design |
| **DWR-032** | Inter-store transfers       | Pressure-driven after transfer ownership design    |
| **DWR-033** | Complete RTV                | Pressure-driven after RTV document design          |
| **DWR-034** | Shelf-location tracking     | Later optional metadata                            |
| **DWR-035** | Weighted/decimal quantities | Major quantity-model change                        |
| **DWR-040** | Automated replenishment     | After manual operations and reporting mature       |
| **DWR-041** | Frontlist/ONIX campaigns    | Separate campaign product                          |
| **DWR-042** | Vendor EDI                  | External lifecycle and messaging design            |

## DWR-031 — Inventory counts

Counts are the preferred first inventory extension because they test and correct the authoritative store-level balance.

Required design includes:

* count document lifecycle;
* blind versus visible counts;
* count scope;
* recount;
* variance approval;
* ledger posting;
* individually tracked units;
* reserved and unavailable quantities;
* audit.

## DWR-030 / DWR-032 / DWR-033

Do not lock a permanent sequence among buyback, transfers, and RTV.

Choose based on:

* merchant pain;
* design readiness;
* operational volume;
* dependency on counts or availability statuses;
* cross-store requirements.

## DWR-034

Shelf location remains optional metadata and must not fragment authoritative store inventory.

## DWR-035

Decimal quantity support requires deliberate changes across:

* Product configuration;
* inventory;
* purchasing;
* POS;
* tax;
* returns;
* reporting.

---

# 12. Parked customer and commerce extensions

| DWR         | Work                                         | Re-entry trigger                                                          |
| ----------- | -------------------------------------------- | ------------------------------------------------------------------------- |
| **DWR-036** | Full CRM                                     | Need for households, multiple contacts, merge, or relationship management |
| **DWR-037** | Notifications                                | Accepted consent and channel platform                                     |
| **DWR-038** | Richer holds/special orders                  | Demonstrated gaps in Product Requests                                     |
| **DWR-039** | Loyalty                                      | Separate loyalty-domain design                                            |
| **DWR-043** | Reusable tax exemptions                      | Exemption-master lifecycle                                                |
| **DWR-044** | Line/component exemptions                    | Component-level application model                                         |
| **DWR-045** | Tax-inclusive pricing                        | Accepted pricing policy                                                   |
| **DWR-046** | Configurable tax rounding                    | Jurisdiction rounding ADR                                                 |
| **DWR-047** | Advanced promotions                          | Promotion-definition and allocation model                                 |
| **DWR-048** | Stored-value replacement/transfer/expiration | Expanded account-lifecycle policy                                         |

Customer v1 remains intentionally flat. Do not grow CRM, loyalty, notifications, or exemptions opportunistically inside POS or Phase 11.

---

# 13. Parked platform and financial extensions

| DWR         | Work                               | Re-entry trigger                              |
| ----------- | ---------------------------------- | --------------------------------------------- |
| **DWR-049** | Integrated payments and settlement | Processor selection and payments architecture |
| **DWR-050** | Offline POS                        | Dedicated synchronization architecture        |
| **DWR-051** | Accounting export batches          | Target accounting system and mapping policy   |
| **DWR-052** | Multi-tenant SaaS                  | Full platform redesign                        |

## DWR-049

Integrated payments must be a dedicated architecture and product phase covering:

* processor ownership;
* terminal interaction;
* authorization;
* capture;
* refunds;
* settlement;
* chargebacks;
* discrepancies;
* failure recovery.

## DWR-050

Offline POS requires explicit rules for:

* local authority;
* identifier allocation;
* synchronization;
* conflict handling;
* pricing and tax freshness;
* inventory reservations;
* tender restrictions;
* security.

## DWR-051

Accounting export should wait for:

* a target accounting system;
* accepted General Ledger mapping;
* export batch grain;
* correction and re-export policy;
* reconciliation expectations.

## DWR-052

Multi-tenancy is not a normal extension of the current single-organization deployment model.

---

# 14. Priority summary

| Planning disposition               | DWR items                                            |
| ---------------------------------- | ---------------------------------------------------- |
| **Phase 11**                       | DWR-067; DWR-010; DWR-017 partial; DWR-020 partial   |
| **Independent maintenance**        | DWR-028; DWR-064                                     |
| **Parallel correction design**     | DWR-004; DWR-005; DWR-006                            |
| **Conditional enablers**           | DWR-001; DWR-018; DWR-019; later DWR-003 and DWR-007 |
| **Triggered invariant**            | DWR-066                                              |
| **Correction delivery candidate**  | accepted DWR-004–006; DWR-011; DWR-012               |
| **Reporting delivery candidate**   | DWR-015; DWR-016; DWR-013; DWR-014                   |
| **Pressure-driven Catalog**        | DWR-022; DWR-023; DWR-027; DWR-029; DWR-065          |
| **Parked Catalog structure**       | DWR-021; DWR-024; DWR-025; DWR-026                   |
| **Later extensions**               | DWR-030–DWR-052                                      |
| **Resolved documentation history** | DWR-060–DWR-063                                      |

---

# 15. Immediate planning decisions

## Decision 1 — Schedule Phase 11

Promote the Phase 11 stub into the governing phase plan with Gates A–E.

## Decision 2 — Preserve a narrow mandatory Gate D

Require:

* basic receipt presentation;
* receipt lookup;
* reprint;
* stable completion confirmation.

Classify gift receipt, stored-value slips, and richer templates as Should-level work and the first cuts if Phase 11 expands excessively.

## Decision 3 — Start correction design in parallel

Create one Correction Integrity Design Packet for DWR-004–006. Do not begin correction implementation until it is accepted.

## Decision 4 — Keep settings separate

Do not include DWR-001 in correction design. Pull DWR-001, DWR-018, or DWR-019 only when a concrete Phase 11 or reporting requirement needs them.

## Decision 5 — Keep reporting independently schedulable

Prefer corrections before reporting, but allow DWR-015/016 and later DWR-013/014 to proceed if correction design stalls.

## Decision 6 — Treat DWR-066 as a hard trigger

Resolve DWR-066 before introducing any role with receipt, PO, or cost visibility independent of `stock_view`.

## Decision 7 — Keep future work pressure-driven

Do not commit to a permanent order between:

* DWR-065 and DWR-022;
* buyback, transfers, and RTV;
* broader Catalog, customer, or platform extensions.

Inventory counts remain the default first inventory extension, but subsequent work follows merchant need and design readiness.

---

# 16. Phase 11 scheduling checklist

Before marking Phase 11 active:

1. Promote the Phase 11 stub to the governing phase-plan location.
2. Confirm Gates A–E and the Must/Should split in Gate D.
3. Set DWR-067 target to Phase 11.
4. Map DWR-010 to Gate E.
5. Split DWR-017 into:

   * mandatory receipt core;
   * Should-level document variants;
   * later printer infrastructure.
6. Map only the POS portion of DWR-020 into Gate B.
7. Create a Phase 11 epic and gate-level issues.
8. List DWR-004–006 as parallel design work, not Phase 11 implementation.
9. Keep DWR-001/018/019 conditional.
10. Record DWR-066 as an authorization trigger.
11. Keep DWR-028/064 outside the Phase 11 dependency tree.
12. Update `roadmap.md`, `current-phase.md`, and the Deferred Work Register.
13. Archive or supersede the non-governing Phase 11 draft after promotion.

---

# 17. Overall recommendation

The next program of work should be:

```text
Primary delivery:
Phase 11 POS Shell and Workspace

Parallel:
Correction Integrity Design Packet

Independent:
Small Catalog maintenance as convenient

Conditional:
Settings and control surfaces only when a real gate needs them

Then:
Corrections or reporting, based on design readiness

Later:
Catalog, inventory, customer, commerce, and platform work
selected by demonstrated pressure rather than historical phase origin
```

This structure keeps ShelfStack moving toward a usable cashier product without losing correction integrity, reporting completeness, or architectural discipline.
