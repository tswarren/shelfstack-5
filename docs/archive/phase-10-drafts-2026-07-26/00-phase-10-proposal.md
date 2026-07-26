# Phase 10 — Product Record and Form Workflow Refinement

**Status:** Proposed — not yet scheduled; see §14 for roadmap bookkeeping required at scheduling time
**Depends on:** Phase 9 closed (Gates 9a–9d merged, PR #122); Gate 8a shared record picker
**Governing docs:** [visual-style-guide.md](../../design/visual-style-guide.md); [application-shell.md](../../design/application-shell.md); [interaction-patterns.md](../../design/interaction-patterns.md); [accessibility.md](../../design/accessibility.md); mockup reference [record.html](../../design/prototypes/ui_mockup/record.html)
**Design docs updated in this change set:** `interaction-patterns.md` gains a **Tabs** section and a **Dependent select (progressive enhancement)** section, the same way Phase 6.5 updated `pos-register-ui.md` alongside its implementation rather than after.
**Touches:** `app/views/products/*`, `app/views/shared/_record_summary.html.erb`, `app/views/shared/_record_picker.html.erb`, `app/views/creators/*`, `app/controllers/{creators,products}_controller.rb`, `app/services/catalog/create_product.rb` (form defaults only — see §7.1), `app/assets/stylesheets/shelfstack/{patterns,forms}.css`, `app/javascript/controllers/*`

## 1. Characterization

Phase 10 is a **product-management workflow and interaction phase**. It refines existing Catalog-domain surfaces — the product record page and the product create/update form — without expanding the persistence model or changing established catalog rules.

It is not purely visual: it also touches identifier-warning confirmation, form defaults, dependent merchandise-class selection, inline creator persistence, and new Turbo response behavior. The title reflects that; this is not framed as an interstitial ".5" gate the way Phase 6.5 was, because it doesn't need to justify itself as inserted between two domain phases — it's a full phase in its own right.

It does **not** change:
- `Catalog::CreateProduct`'s two-step safety mechanism — product and standard variant are still built `sellable: false`, then the requested final sellable state is applied once both records exist. This phase changes what the **form pre-selects** as that requested state, not how the service persists it.
- Merchandise class / department / tax category effective-value resolution. This phase changes how the *result* is displayed and adds a form control over the existing `primary → secondary → minor` hierarchy; it does not change which level a `Product` may reference (`belongs_to :merchandise_class, optional: true` has no level constraint today, confirmed against the model).
- Identifier normalization's `warning` vs. `invalid` `validation_status` distinction (`Identifiers::NormalizedIdentifier`).
- The `capabilities`-gated dataset boundaries already returned by `Catalog::BuildProductSummary` (`stock_view`, `purchase_order_view`, `receipt_view`, `vendor_source_view`, `purchasing_cost_view`, `inventory_cost_view`, `vendor_view`, `request_view`). Every restructured tab/rail element must continue to check the same `caps.*` flags the current partials already check — see §3.

It must **not**:
- introduce new schema solely for presentation;
- build a general-purpose icon system beyond what these two pages need;
- add a JS bundler, SPA framework, or client-side routing;
- require JavaScript for any content to be present or for any form field to be submittable — see §5.

## 2. Goal

1. **`products#show`** — attention banner → store-scoped operational rail (summary measures + links out) → tabbed record (Overview / Selling configuration / Inventory / Supply), each tab a concise current-state summary that links to its owning workflow rather than reproducing it.
2. **Product create/update form** — normalized grid alignment via explicit modifiers, inline creator creation, a progressively-enhanced merchandise-class control, price-field synchronization with one deterministic state model, and a specified reachable action bar.

## 3. Store context and authorization — reusing what already exists

**Store resolution requires no new design.** `Authentication#set_current_from_membership` already resolves `Current.store` app-wide at the session level (`session[:store_id]` → membership), with `new_store_selection_path` already handling the multi-membership case. `ProductsController#show` already calls `Catalog::BuildProductSummary.call(store: Current.store, actor: Current.user, ...)`. There is no product-page-specific store precedence chain to define, and a page-local `store_id` query-param reload would work *against* the existing single-active-store-per-session pattern rather than align with it — so this phase introduces none. The only page-level requirement is a heading that makes the scope legible: the operational rail is headed **"Store status — {Current.store.name}"** so a user cannot mistake store-scoped figures for organization-wide ones.

**Authorization requires no new mechanism, but does require discipline during the restructure.** `Catalog::BuildProductSummary` already returns a `capabilities` struct, and every current partial (`_stock`, `_store_operations`, `_vendor_sources`) already branches on it (e.g. `unless caps.stock_view`, `if caps.purchase_order_view`). The real risk in this phase is **accidentally dropping an existing `caps.*` check** while moving fields into tabs and the rail — not designing new authorization. Exit criteria (§11) require each moved field/section to be traced back to the `caps.*` flag that gated it before the restructure.

**"Missing store context" and "no stock balance" are already distinct, existing states**, not new design: `_stock.html.erb` already renders a distinct empty state when `stock.nil?` ("Stock is unavailable for this product at {store}"), separately from the zero-quantity case where `stock` is present with `on_hand: 0`. This phase preserves that distinction when the same data moves into the Inventory tab; it does not need to invent new states for it.

## 4. The show page is a summary surface, not a domain replacement

Tabs provide concise current-state summaries and links to owning workflows. They do **not** reproduce full purchasing, receiving, inventory-ledger, or demand-management screens.

**Operational rail** (outside the tab panels, visible regardless of active tab): available, on hand, reserved, unavailable, on order, last received date. Cost appears only where `caps.inventory_cost_view` is true, and only inside Selling configuration or Inventory — never automatically in the rail.

**Overview tab:** identity fields, description, classification breadcrumb.

**Selling configuration tab:** standard variant — price (see §10.1 for the display matrix), tracking mode, status, sellability, effective department/tax category with provenance (§10 in the prior draft, retained), returnability, discountability.

**Inventory tab:** current quantities, an availability explanation, individually-tracked unit summary where applicable, a stale-reservation warning where relevant, and a link to full inventory history — not the ledger itself.

**Supply tab:** preferred/active vendor sources, open order quantity, most recent purchase order, most recent receipt, open demand/request count — each with a link to its full owning record (PO, receipt, request), not the full list inline.

## 5. Progressive enhancement — tabs

Unenhanced baseline is ordinary anchor navigation, not inert buttons:

```html
<a href="#inventory">Inventory</a>
```

With JavaScript: Stimulus enhances these into `role="tablist"` / `role="tab"` / `role="tabpanel"`, hides inactive panels, and synchronizes keyboard state (roving `tabindex`, Left/Right between tabs, Home/End to first/last) with the URL fragment.

Without JavaScript: the anchors remain ordinary in-page links, all panel content is present and readable (stacked), and nothing is presented as interactive that isn't.

**Browser history contract:** clicking a tab updates the fragment; Back/Forward reactivates the corresponding panel; an unknown or absent fragment leaves Overview active rather than hiding all content.

## 6. Progressive enhancement — merchandise-class control

Not three dependent selects plus a separate fallback control — that creates two code paths and risks two controls submitting different values.

**Canonical contract:**
1. Render one ordinary hierarchical flat select as the no-JavaScript baseline — every leaf, primary, or secondary node the organization has, in path order (e.g. "Books › Nonfiction › History").
2. With Stimulus, enhance or replace its presentation with the three-level cascade (primary → secondary → minor).
3. Exactly one field is submitted either way: `product[merchandise_class_id]`.
4. Behavior regardless of enhancement state:
   - permits stopping at primary or secondary — submits the deepest node actually selected, never forces a minor-level pick (no such constraint exists on `Product.merchandise_class`, confirmed against the model);
   - initializes correctly when editing an existing product;
   - preserves the selection after a validation-failure re-render;
   - includes the currently assigned class even if inactive, while excluding other inactive classes from new selection;
   - clears child selection whenever a parent selection changes (cascade mode only — irrelevant to the flat baseline).

## 7. Form-state contracts

### 7.1 Sellability default

- `sellable: true` is applied **only to a pristine new-product form** (no submitted params).
- Any submitted value — including an explicit `false` — is preserved verbatim after a validation-failure re-render. (A naive `value || true` helper would silently flip an intentional `false` back to `true`; this is explicitly disallowed.)
- Editing an existing product never overrides its persisted `sellable` value with the new-form default.
- Both the product and its automatically-created standard variant default to `sellable: true` on a pristine new form.
- `Catalog::CreateProduct`'s existing `sellable: false`-then-apply-final-state persistence sequence is unchanged (§1).

### 7.2 Price-field synchronization

One deterministic state machine, not "may optionally":

```
linked      → regular price mirrors list price as the user types
user edits regular price directly → independent (no further mirroring)
user clicks "Use list price"      → relinks; regular price mirrors list price again
```

Clearing the regular price field alone does **not** implicitly relink it — relinking requires the explicit "Use list price" action. Server-side validation continues to accept and check both fields independently regardless of client-side sync state.

### 7.3 Identifier-warning resubmission

When identifier normalization returns an overridable `warning` (`validation_status == :warning`), an inline banner offers **Save anyway** or **Correct identifier**, with entered form data preserved either way.

**Save-anyway acceptance is bound to the exact normalized identifier that produced the warning** — the server requires both `accept_identifier_warning=true` and a match against the normalized value (or a warning fingerprint) that generated it. If the user edits the identifier after the warning appears, the prior acceptance does not carry over to the new value; the check re-runs. Acceptance requires only the ordinary explicit confirmation already implied by having reached the form (`catalog.product.edit`/create permission) — no separate permission is introduced.

Structurally invalid or prohibited identifiers (`validation_status == :invalid`) remain blocking; no override is offered, per existing behavior.

### 7.4 Inline creator creation — duplicate handling

"No duplicates" means: no duplicate assignment rows in the unsaved product form, and no duplicate Turbo-inserted rows from a repeated/double-clicked submission. It does **not** mean deduplicating `Creator` records by name — two people can legitimately share a display name, so name-based entity dedup is explicitly out of scope and would be unsafe.

## 8. Delivery gates

```text
10a Product show and shared display primitives (tabs, icons, header, rail, breadcrumb, provenance)

10b Form structure and action bar
├── 10c Merchandise-class control and price synchronization
└── 10d Identifier-warning flow and new-product defaults

10e Inline creator creation (optional / should-have)
```

10c and 10d both build on the form structure 10b establishes, so they proceed **after** 10b rather than in parallel with it — this avoids either gate styling itself against a form 10b is about to replace, and reduces merge conflict.

| Gate | Deliverable | Core phase requirement |
| --- | --- | --- |
| **10a** | Product show shell: icon foundation, tabs (progressive-enhancement contract documented in `interaction-patterns.md`), structured header, store-scoped operational rail, classification breadcrumb, provenance treatment | Yes |
| **10b** | Product form structure: grid modifiers, product/variant field grouping, action-bar contract (§9) | Yes |
| **10c** | Merchandise-class control (§6) + price-field synchronization (§7.2) | Yes |
| **10d** | Identifier-warning resubmission (§7.3) + new-product sellability default (§7.1) | Yes |
| **10e** | Inline creator creation (§7.4) | **Should — not required for core completion** |

**Phase 10 core complete:** 10a–10d accepted. **Phase 10 fully complete:** 10e also accepted. 10e may ship later or be descoped without reopening 10a–10d.

## 9. Action-bar contract

- Remains in normal document flow by default.
- Becomes sticky at the bottom of the content viewport on sufficiently tall screens.
- Never covers the final form field(s) — reserve bottom padding equal to the bar's height.
- Opaque background + a top border/divider so it reads as chrome, not floating content.
- Respects mobile safe-area padding where applicable.
- Collapses to normal in-flow positioning on narrow/constrained layouts.
- Remains fully usable without JavaScript (it's a plain `<button type="submit">` + link; sticky positioning is CSS-only).
- Labels: **Create product** / **Cancel** on create; **Update product** / **Cancel** on edit. (Note: the current form code already uses "Cancel" in both cases — `link_to "Cancel", ...` — so this isn't a behavior change, just dropping "Ignore changes," which only ever existed in the original wireframe notes and was never implemented.)

## 10. Display specification

### 10.1 Price

| List price | Regular price | Display |
| --- | --- | --- |
| Present, equal to regular | Present | One line: "Selling price: $X" |
| Present, different from regular | Present | Both: "List price: $X" / "Selling price: $Y" |
| Missing | Present | "Selling price: $Y" only |
| Present | Missing | "List price: $X"; missing-price condition surfaced |
| Missing | Missing | Missing-price condition surfaced |

**The "missing selling price" condition is not new UI** — `Catalog::SaleEligibility` already raises a `missing_price` blocker when a variant is `sellable?` with `regular_price_cents.nil?`, and that already renders via the existing `_attention` partial at the top of the page. This table describes how price fields display in Selling configuration; the attention-level warning for a sellable-but-unpriced variant is existing behavior this phase preserves, not new behavior it invents. A non-sellable product may legitimately have only a list price with no blocker — the table's "missing" rows are not assumed to always coincide with an active blocker.

### 10.2 Description

Collapse into `<details>` only when long; short descriptions display normally; a blank description omits the section entirely. "Long" is defined by one shared helper/constant, measured against **normalized plain-text length** (stripped of markup), not raw HTML length, so tests and behavior don't drift against each other.

### 10.3 Suppressed default fields

Suppress only: alternate identifier, edition, imprint when blank; language when it equals the organization's ordinary default (normalized `eng`) — never suppress a meaningful non-default language value.

**Never suppress, regardless of value:** product status, product sellability, variant status, variant sellability, tracking mode, effective department, effective tax category, price (display per §10.1, never omitted). These determine whether and how the product can sell.

## 11. Exit criteria (by gate)

### 10a
- [ ] `_tabs` partial + `tabs_controller.js` meet the §5 progressive-enhancement contract (anchor baseline, roving tabindex, arrow/Home/End keys, synchronized ARIA, fragment activation, Back/Forward reactivation, unknown fragment → Overview, fully readable with JS disabled)
- [ ] `interaction-patterns.md` documents the Tabs contract
- [ ] Icon helper: inline SVG inheriting `currentColor`; documented source version/license for the vendored Phosphor subset; allowlist of supported names/weights; helper rejects unknown names (no arbitrary path lookup); decorative icons default `aria-hidden="true"`; icon usage rule (icon-only vs. icon+text) documented in `visual-style-guide.md`
- [ ] Header: title, subtitle, creator byline, format/publisher/date phrase, status badges — composed subtitle removed
- [ ] Operational rail headed "Store status — {store}", outside tab panels, contains exactly the §4 measures, cost gated on `caps.inventory_cost_view`
- [ ] Every field/section moved from the current flat partials into a tab or the rail is traced to the same `caps.*` flag (or lack thereof) it was gated by before the restructure
- [ ] Classification shown as breadcrumb; provenance shown as visible label + decorative icon + visually-hidden detail (no reliance on `title` alone)

### 10b
- [ ] `.form-grid`/`.definition-grid` modifiers (`--2`, `--3`, `--full`) exist and are applied per-section; pages using the base classes outside this phase are unaffected
- [ ] Action bar meets every bullet in §9, including usability with JavaScript disabled

### 10c
- [ ] Merchandise-class control meets the §6 canonical contract, including the flat no-JS baseline submitting the same single field as the enhanced cascade
- [ ] Cascade permits stopping at primary/secondary, submits deepest selected node, initializes on edit, preserves selection after validation failure, includes inactive assigned class without allowing new inactive selection, clears children on parent change
- [ ] Price synchronization matches the §7.2 state machine exactly, including the explicit "Use list price" relink action

### 10d
- [ ] New-product form pre-selects `sellable: true` only on a pristine form; submitted values (including explicit `false`) survive a validation-failure re-render; editing never overrides a persisted value; `Catalog::CreateProduct`'s non-sellable-first persistence is unchanged and covered by existing/updated tests
- [ ] Identifier `warning` produces the Save-anyway/Correct-identifier banner bound to the specific normalized value that triggered it (re-editing the identifier invalidates prior acceptance); `invalid` remains blocking with no override

### 10e
- [ ] "New creator" visible only to users with `catalog.manage_creators`
- [ ] Dialog is row-aware, rerenders validation errors in-dialog, selects the new creator in the invoking row on success, returns focus to the invoking control, traps focus while open, closes on Escape when safe
- [ ] Repeated/double-click submission produces no duplicate assignment rows or duplicate Turbo-inserted rows (§7.4) — no `Creator`-entity name deduplication is implemented

### Phase-level definition of done
- [ ] All core gates (10a–10d) accepted
- [ ] `interaction-patterns.md` and `visual-style-guide.md` updated in the same change set
- [ ] No schema change introduced
- [ ] `bin/ci` green
- [ ] Accessibility and responsive walkthrough complete (§13)

## 12. Test strategy

- **Request/view tests:** every tab panel is present in the initial server-rendered HTML regardless of JS; fragment ids and `aria-controls`/`aria-labelledby` relationships are correct; merchandise-class flat-select baseline submits `product[merchandise_class_id]` correctly at each depth.
- **Stimulus/system tests:** tab switching, keyboard navigation (roving tabindex, arrow/Home/End), fragment activation, Back/Forward behavior; cascade-select enhancement and price-field sync interactions; creator dialog lifecycle (open, validation failure, success, focus return, Escape, focus trap).
- **No-JS contract test:** rendered HTML contains all tab content and the merchandise-class flat select with no server-side state that makes any of it inaccessible without JavaScript.
- **Request/service tests:** identifier-warning acceptance bound to the triggering normalized value; sellability default preserved-vs-applied rules across new/failed-validation/edit cases; permission gating on the inline-creator action and on every `caps.*`-dependent tab/rail element; Turbo success/failure response shapes for creator creation.

This avoids standing up a second system-test environment with JavaScript globally disabled — the no-JS contract is verified at the request/view layer since panel content is server-rendered regardless of enhancement state.

## 13. Manual walkthrough

1. Open a product with a full field set → tabs render, "Store status — {store}" rail visible on every tab, status/sellability/price/tracking-mode always visible, only genuinely blank bibliographic fields omitted.
2. Exercise each row of the §10.1 price matrix against real fixture data.
3. Tab through the show page using only Left/Right/Home/End; reload on a `#supply` fragment → opens directly to Supply; use Back/Forward after switching tabs → reactivates correctly; load an unknown fragment → Overview is active. Disable JavaScript → all panel content is present and readable, and the merchandise-class control on the form falls back to the flat select with no loss of function.
4. Focus (not just hover) the provenance icon → inherited/override detail is available without a mouse.
5. Create a product selecting only a primary merchandise class → persists at primary. Repeat to secondary and to minor → persists correctly at each depth; edit reopens with the right selection(s) restored at every depth tested.
6. Type a list price, then a regular price → sync-then-decouple; click "Use list price" after decoupling → confirms explicit relink, not automatic relink on clear.
7. As a user without `catalog.manage_creators`, confirm "New creator" is absent. As a user with permission: create inline, including one submission that fails validation (confirm in-dialog rerender), then succeeds (confirm correct row selection and focus return). Double-submit → confirm no duplicate rows.
8. Submit an identifier producing a `warning` → Save-anyway/Correct-identifier banner, data preserved either way; change the identifier after the warning appears and attempt Save-anyway → confirm the stale acceptance does not carry over. Submit a structurally `invalid` identifier → blocks with no override.
9. As a user lacking `purchasing_cost_view` / `inventory_cost_view` / etc., confirm each gated section is absent from its tab/rail exactly as it would have been on the current page.
10. Scroll a long product form → action bar remains reachable and never covers the last field.

## 14. Scheduling checklist (roadmap bookkeeping)

When this phase is formally scheduled:
- [ ] Add Phase 10 to `roadmap.md`
- [ ] Set it as the active phase in `current-phase.md`
- [ ] Confirm no residual `9.5a`–`9.5e` identifiers remain anywhere in docs/comments/branch names
- [ ] Cross-check `deferred-work-register.md` for any overlapping entries and mark them scheduled rather than leaving duplicate backlog rows
- [ ] Preserve DWR-021 (multi-variant, Phase 8.5) as unscheduled — unrelated to this phase
- [ ] On core-gate completion, update the roadmap to reflect "10a–10d complete"; track 10e separately if it remains open

## 15. Related

- [../current-phase.md](../current-phase.md)
- [../roadmap.md](../roadmap.md)
- [phase-09-customer-records.md](phase-09-customer-records.md)
- [phase-08-catalog-refinement-and-enrichment.md](phase-08-catalog-refinement-and-enrichment.md)
- [../../design/README.md](../../design/README.md)
- [../../design/prototypes/ui_mockup/record.html](../../design/prototypes/ui_mockup/record.html)