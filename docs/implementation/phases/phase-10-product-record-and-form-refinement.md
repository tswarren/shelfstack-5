# Phase 10 — Product Record and Form Workflow Refinement

**Status:** Scheduled — active delivery phase  
**Depends on:** Phase 9 closed (Gates 9a–9d merged, PR [#122](https://github.com/tswarren/shelfstack-5/pull/122)); Gate 8a shared record picker  
**Governing docs:** [visual-style-guide.md](../../design/visual-style-guide.md); [application-shell.md](../../design/application-shell.md); [interaction-patterns.md](../../design/interaction-patterns.md); [accessibility.md](../../design/accessibility.md); mockup reference [record.html](../../design/prototypes/ui_mockup/record.html)  
**Design docs updated in this change set:** `interaction-patterns.md` gains **Tabs** and **Dependent select (progressive enhancement)** sections; `visual-style-guide.md` gains icon usage rules.  
**Touches:** `app/views/products/*`, `app/views/shared/_record_summary.html.erb`, `app/views/shared/_record_picker.html.erb`, `app/views/creators/*`, `app/controllers/{creators,products}_controller.rb`, `app/services/catalog/build_product_summary.rb`, `app/services/catalog/create_product.rb` (form defaults / identifier-warning binding — see §7), `app/assets/stylesheets/shelfstack/{patterns,forms}.css`, `app/javascript/controllers/*`

> **Naming note:** Delivery Phase 10 is product-record/form refinement. System-overview §1.8 “Phase 10 — Later operational extensions” remains the deferred-capabilities bucket (buyback, CRM, promotions, etc.). See [roadmap.md](../roadmap.md) mapping.

## 1. Characterization

Phase 10 is a **product-management workflow and interaction phase**. It refines existing Catalog-domain surfaces — the product record page and the product create/update form — without expanding the persistence model or changing established catalog rules.

It does **not** change:

- `Catalog::CreateProduct`'s two-step safety mechanism — product and standard variant are still built `sellable: false`, then the requested final sellable state is applied once both records exist. This phase changes what the **form pre-selects** as that requested state, not how the service persists it.
- Merchandise class / department / tax category effective-value resolution.
- Identifier normalization's `warning` vs. `invalid` `validation_status` distinction (`Identifiers::NormalizedIdentifier`), including that invalid ISBN-10 input remains non-overridable and is not stored as a ten-digit `:isbn13` canonical. Gate 10d binds overridable EAN-13/UPC check-digit warnings on the create form (§7.3).
- The `capabilities`-gated dataset boundaries already returned by `Catalog::BuildProductSummary`.

It must **not**:

- introduce new schema solely for presentation;
- build a general-purpose icon system beyond what these two pages need;
- add a JS bundler, SPA framework, or client-side routing;
- require JavaScript for any content to be present or for any form field to be submittable;
- create new operational screens (inventory history, reservation show, etc.) when a destination route is missing — omit the link or use the nearest existing surface;
- invent a reservation age / “stale” policy;
- deepen Product Request coverage-formula ownership inside Catalog (leave [DWR-029](../deferred-work-register.md) unscheduled).

## 2. Goal

1. **`products#show`** — attention banner → store-scoped operational rail → tabbed record (Overview / Selling configuration / Inventory / Supply), each tab a concise current-state summary that links to its owning workflow rather than reproducing it.
2. **Product create/update form** — normalized grid alignment via explicit modifiers, inline creator creation (Gate 10e), a progressively-enhanced merchandise-class control, price-field synchronization with one deterministic state model, and a specified reachable action bar.

## 3. Store context, authorization, and capability matrix

**Store resolution requires no new design.** `Authentication#set_current_from_membership` already resolves `Current.store`. The operational rail is headed **"Store status — {Current.store.name}"**.

**Authorization:** every restructured tab/rail element must retain the same `caps.*` flag (or lack thereof) that gated it before the restructure. New aggregates must declare an explicit gate:

| Information | Gate |
| --- | --- |
| Stock quantities | `stock_view` |
| Unit status summary | `stock_view` |
| Last received date | `receipt_view` |
| Inventory cost | `inventory_cost_view` |
| Vendor sources | `vendor_source_view` |
| Vendor identity/details | `vendor_view` |
| PO counts and latest PO | `purchase_order_view` |
| Latest receipt | `receipt_view` |
| Demand / open request count | `request_view` |
| Purchasing cost | `purchasing_cost_view` |

**MVP interim:** quantity-tracked stock summary construction currently requires `stock_view`, which can underexpose independently authorized last-received / on-order / cost fields when those caps are granted without stock. MVP roles bundle these permissions. Follow-up: [DWR-066](../deferred-work-register.md).

**Summary-service boundary.** `Catalog::BuildProductSummary` may be extended with bounded, capability-gated summary values required by §4. Views must not issue new catalog, inventory, purchasing, receiving, or request queries directly. Summary additions must:

- remain store-scoped through `Current.store`;
- respect the existing `capabilities` contract;
- avoid loading complete ledgers or operational collections;
- return only the counts, latest records, and links required by the product summary surface;
- avoid N+1 queries.

**"Missing store context" and "no stock balance"** remain distinct existing states.

## 4. The show page is a summary surface, not a domain replacement

**Operational rail** (outside tab panels): available, on hand, reserved, unavailable, on order, last received date. Cost appears only where `caps.inventory_cost_view` is true, and only inside Selling configuration or Inventory — never automatically in the rail.

**Overview tab:** identity fields, description, classification breadcrumb.

**Selling configuration tab:** standard variant — price (§10.1), tracking mode, status, sellability, effective department/tax category with provenance, returnability, discountability.

**Inventory tab:** current quantities, availability explanation, individually-tracked unit summary where applicable, and links to existing inventory surfaces (`stock_balances#show` when `stock_balance_id` present; else `inventory_units` / `inventory_reservations#index` as applicable). No new inventory-history screen. No “stale reservation” age warning.

**Supply tab:** preferred/active vendor sources, open order quantity, most recent purchase order, most recent receipt, open demand/request count — each with a link to an **existing authorized** destination (`purchase_orders#show`, `receipts#show`, `product_requests#show`). If a proposed link lacks a destination, omit it or redirect to the nearest existing surface.

## 5. Progressive enhancement — tabs

Unenhanced baseline is ordinary anchor navigation:

```html
<a href="#inventory">Inventory</a>
```

**Server-rendered HTML** provides stable anchor and panel IDs plus the data relationships needed for enhancement. It does **not** apply tab roles or hide panels.

**Stimulus** applies:

- `role="tablist"`, `role="tab"`, and `role="tabpanel"`;
- `aria-selected`;
- roving `tabindex`;
- `aria-controls` and `aria-labelledby`, if they are not rendered safely in the baseline markup;
- inactive-panel hiding.

Without JavaScript: anchors remain ordinary in-page links, all panel content is present and readable (stacked).

**Browser history:** clicking a tab updates the fragment; Back/Forward reactivates the corresponding panel; unknown or absent fragment → Overview active.

## 6. Progressive enhancement — merchandise-class control

The flat hierarchical select remains the **canonical** form control (`name="product[merchandise_class_id]"`).

When enhanced:

- cascade selects are presentation controls and do **not** have submitted `name` attributes;
- cascade changes synchronize the canonical select;
- the canonical select may be visually hidden but remains present;
- enhancement failure leaves the canonical select visible and usable;
- JavaScript must never create a second successful field with the same parameter name.

Behavior:

- permits stopping at primary or secondary — submits the deepest node actually selected;
- initializes correctly when editing;
- preserves selection after validation-failure re-render;
- includes the currently assigned class **and the ancestor path required to represent it**, even when one or more of those records are inactive, while excluding other inactive classes from new selection;
- clears child selection whenever a parent selection changes (cascade mode only).

## 7. Form-state contracts

### 7.1 Sellability default

`sellable: true` is assigned only when constructing the initial new-product form in `ProductsController#new` for **both** the product and its standard variant (independent checkboxes).

`ProductsController#create` validation rerenders reuse the submitted product and variant values and do **not** reapply the default. Editing never overrides a persisted value.

`Catalog::CreateProduct`'s existing `sellable: false`-then-apply-final-state persistence sequence is unchanged.

### 7.2 Price-field synchronization

```text
linked      → regular price mirrors list price as the user types
user edits regular price directly → independent (no further mirroring)
user clicks "Use list price"      → relinks; regular price mirrors list price again
```

Clearing the regular price field alone does **not** implicitly relink. Server-side validation accepts both fields independently regardless of client sync state.

### 7.3 Identifier-warning resubmission (create path only)

**Implementation names (confirmed):**

- Controller: `ProductsController#create`
- Service: `Catalog::CreateProduct` (`accept_identifier_warning:`)
- Edit path is out of scope: edit form shows identifier as read-only; `Catalog::UpdateProduct` / `Catalog::UpdateProductWithStandardVariant` reject `identifier` attrs.

When identifier normalization returns an overridable `warning` (invalid EAN-13 / UPC check digits), an inline banner offers an accept checkbox plus **Save anyway** or **Correct identifier**, with entered form data preserved either way. Both **Save anyway** and the sticky create submit require the checkbox; neither button forces acceptance on its own.

On resubmission, the server re-normalizes the currently submitted identifier. Warning acceptance is valid only when:

- `accept_identifier_warning=true`; and
- the re-normalized current identifier is still a warning; and
- its normalized value matches the normalized value presented in the warning confirmation.

Client-supplied warning state is never accepted without rerunning normalization. Structurally `invalid` identifiers remain blocking with no override.

### 7.4 Inline creator creation — duplicate handling (Gate 10e)

The submit control is disabled while a creator request is in flight, and Turbo responses replace the invoking assignment row rather than append blindly. Replayed presentation responses must not insert multiple assignment rows.

Cross-request Creator-creation idempotency is **not** introduced. Name-based `Creator` entity deduplication is out of scope.

## 8. Delivery gates

```text
10a Product show and shared display primitives (tabs, icons, header, rail, breadcrumb, provenance)

10b Form structure and action bar
├── 10c Merchandise-class control and price synchronization
└── 10d Identifier-warning flow and new-product defaults

10e Inline creator creation (optional / should-have)
```

| Gate | Deliverable | Core? |
| --- | --- | --- |
| **10a** | Product show shell: icon foundation, tabs, structured header, store-scoped operational rail, classification breadcrumb, provenance | Yes |
| **10b** | Product form structure: grid modifiers, product/variant field grouping, action-bar contract (§9) | Yes |
| **10c** | Merchandise-class control (§6) + price-field synchronization (§7.2) | Yes |
| **10d** | Identifier-warning resubmission (§7.3) + new-product sellability default (§7.1) | Yes |
| **10e** | Inline creator creation (§7.4) | Should |

**Post-core roadmap status wording (required):**

```text
Core complete — Gates 10a–10d accepted; Gate 10e deferred
```

**Fully complete** only when 10e is also accepted (or 10e is explicitly descoped in the deferred-work register).

## 9. Action-bar contract

- Remains in normal document flow by default.
- Becomes sticky at the bottom of the content viewport when width ≥ the documented desktop breakpoint **and** viewport height meets the documented minimum (exact values recorded in the design guide during Gate 10b).
- Never covers the final form field(s) — reserve bottom padding equal to the bar's height.
- Opaque background + a top border/divider.
- Respects mobile safe-area padding where applicable.
- Collapses to normal in-flow positioning on narrow/constrained layouts.
- Fully usable without JavaScript (plain submit + link; sticky is CSS-only).
- Labels: **Create product** / **Cancel** on create; **Update product** / **Cancel** on edit.

## 10. Display specification

### 10.1 Price

| List price | Regular price | Display |
| --- | --- | --- |
| Present, equal to regular | Present | One line: "Selling price: $X" |
| Present, different from regular | Present | Both: "List price: $X" / "Selling price: $Y" |
| Missing | Present | "Selling price: $Y" only |
| Present | Missing | "List price: $X"; missing-price condition surfaced |
| Missing | Missing | Missing-price condition surfaced |

Missing selling price for a sellable variant remains the existing `SaleEligibility` / `_attention` behavior.

### 10.2 Description

Collapse into `<details>` only when long; short descriptions display normally; blank description omits the section. "Long" is one shared helper/constant against **normalized plain-text length**.

### 10.3 Suppressed default fields

Suppress only: alternate identifier, edition, imprint when blank; language when it equals the **application** default `Catalog::LanguageCodes::DEFAULT` (`eng`). Phase 10 does not introduce organization-specific language settings.

**Never suppress:** product status, product sellability, variant status, variant sellability, tracking mode, effective department, effective tax category, price (per §10.1).

## 11. Exit criteria (by gate)

### 10a

- [ ] `_tabs` partial + `tabs_controller.js` meet the §5 progressive-enhancement contract
- [ ] `interaction-patterns.md` documents the Tabs contract
- [ ] Icon helper: inline SVG inheriting `currentColor`; documented Phosphor subset source/license; allowlist; rejects unknown names; decorative icons default `aria-hidden="true"`; icon usage rule in `visual-style-guide.md`
- [ ] Header: title, subtitle, creator byline, format/publisher/date phrase, status badges — composed subtitle removed
- [ ] Operational rail headed "Store status — {store}", outside tab panels, contains exactly the §4 measures; cost not in rail
- [ ] Every moved field/section and every new aggregate traced to its `caps.*` flag
- [ ] Classification breadcrumb; provenance as visible label + decorative icon + visually-hidden detail
- [ ] Summary links resolve only to existing authorized routes

### 10b

- [ ] `.form-grid`/`.definition-grid` modifiers (`--2`, `--3`, `--full`) exist and are applied per-section
- [ ] Action bar meets every bullet in §9; sticky conditions documented in the design guide

### 10c

- [ ] Merchandise-class control meets the §6 canonical contract
- [ ] Cascade permits stopping at primary/secondary; inactive assigned path included; children clear on parent change
- [ ] Price synchronization matches the §7.2 state machine exactly

### 10d

- [ ] New-product form pre-selects `sellable: true` only in `#new`; submitted values survive validation re-render; edit never overrides; `CreateProduct` non-sellable-first persistence unchanged
- [ ] Identifier `warning` Save-anyway binding on `ProductsController#create` → `Catalog::CreateProduct` as specified in §7.3; `invalid` remains blocking

### 10e

- [ ] "New creator" visible only with `catalog.manage_creators`
- [ ] Dialog is row-aware (unique `row_key` per assignment, including same creator with multiple roles); validation errors in-dialog; replaces only the invoking row’s creator picker; focus return; focus trap; Escape when safe
- [ ] In-flight disable + Turbo replace picker (not whole row); no Creator name dedup; no cross-request idempotency

### Phase-level definition of done

- [ ] Core gates 10a–10d accepted; roadmap status set to `Core complete — Gates 10a–10d accepted; Gate 10e deferred` (or Fully complete if 10e also accepted)
- [ ] `interaction-patterns.md` and `visual-style-guide.md` updated in the same change set
- [ ] No schema change introduced
- [ ] `bin/ci` green
- [ ] Accessibility and responsive walkthrough complete (§13)

## 12. Test strategy

- **Request/view tests:** every tab panel present in initial HTML; fragment IDs and enhancement data attrs; merchandise-class flat select submits `product[merchandise_class_id]`; capability-absent sections omitted; sellability default/create/edit cases; identifier-warning binding. Request tests do **not** assert Stimulus-only ARIA roles.
- **System/Stimulus tests:** tab keyboard + fragment/history; applied roles and synchronized ARIA; cascade enhancement; price sync; creator dialog lifecycle.
- **No-JS contract:** verified at request/view layer.
- **Service tests:** summary additions capability-gated and query-bounded; `CreateProduct` non-sellable-first unchanged.

## 13. Manual walkthrough

1. Open a product with a full field set → tabs render, "Store status — {store}" rail visible, status/sellability/price/tracking-mode always visible, blank bibliographic fields omitted.
2. Exercise each row of the §10.1 price matrix.
3. Keyboard tab navigation; `#supply` fragment; Back/Forward; unknown fragment → Overview; JS disabled → all panels readable; merchandise-class flat select usable.
4. Focus provenance icon → inherited/override detail available without mouse.
5. Create product selecting primary / secondary / minor merchandise class; edit restores selections.
6. Price sync-then-decouple; "Use list price" relinks; clear does not relink.
7. Gate 10e: permission gating, validation failure in-dialog, success focus return, double-submit no duplicate rows.
8. Identifier warning Save-anyway / Correct; stale acceptance after edit invalid; invalid blocks.
9. Capability-absent sections absent.
10. Long form → action bar reachable, never covers last field.

## 14. Scheduling checklist

- [x] Add Phase 10 to `roadmap.md`
- [x] Set it as the active phase in `current-phase.md`
- [x] Confirm no residual `9.5a`–`9.5e` identifiers
- [x] Cross-check `deferred-work-register.md`; keep DWR-021 / DWR-029 unscheduled
- [x] Create gate issues (10a–10e) that **copy** contracts and exit criteria from this document — [#123](https://github.com/tswarren/shelfstack-5/issues/123)–[#127](https://github.com/tswarren/shelfstack-5/issues/127)
- [ ] On core-gate completion, set status to `Core complete — Gates 10a–10d accepted; Gate 10e deferred`

## 15. Related

- [../current-phase.md](../current-phase.md)
- [../roadmap.md](../roadmap.md)
- [../deferred-work-register.md](../deferred-work-register.md)
- [phase-09-customer-records.md](phase-09-customer-records.md)
- [phase-08-catalog-refinement-and-enrichment.md](phase-08-catalog-refinement-and-enrichment.md)
- [../../design/README.md](../../design/README.md)
- [../../design/prototypes/ui_mockup/record.html](../../design/prototypes/ui_mockup/record.html)
