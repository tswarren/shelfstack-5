# Interaction Patterns

**Status:** Governing for shared UI interaction patterns  
**Related:** [accessibility.md](accessibility.md), [visual-style-guide.md](visual-style-guide.md)

## Record picker

ShelfStack uses a shared **search-to-link** control for high-volume record associations instead of unfiltered native `<select>` lists.

### When to use

Use the shared record picker for organization-scoped links such as:

* merchandise class;
* department;
* product format;
* tax category;
* product;
* product variant;
* vendor;
* creator (Gate 8b+);
* customer (Phase 9 — POS attach/stage and product requests).

Do **not** use it for small closed enums (`status`, `product_type`, tracking mode).

### Implementation

* Partial: `app/views/shared/_record_picker.html.erb`
* Stimulus: `record-picker` (`app/javascript/controllers/record_picker_controller.js`)
* Search: `GET /catalog/record_searches?type=…&q=…` (`Catalog::RecordSearchesController` → `Catalog::SearchRecords`)

The control submits a hidden id field with the correct param name for ordinary Rails forms (including `fields_for`). It does not require a single-page application.

### Behavior

* Typeahead search with keyboard navigation (↑ ↓ Enter Esc).
* Clear control when blank selection is allowed. Only **Clear** intentionally blanks an optional association; unmatched typed text (including deleting a committed label without Clear) restores the last committed selection on blur/Escape and blocks submit via `setCustomValidity`.
* Changing the query clears rendered options immediately (before the debounced search) so Enter/click cannot commit a stale prior result.
* Displayed selections are resolved through `Catalog::ResolveRecordPickerSelection` against `Current.organization` so validation rerenders never disclose foreign-organization labels.
* Loading, empty, and error status text via `aria-live`.
* Combobox semantics: `role="combobox"` on the text input, `role="listbox"` / `option` on results.
* Keyboard-active option uses a leading marker and inset border in addition to background (not color alone). Hover is distinct from the active state.
* Inactive records are **excluded by default**. Product Variant default search also requires the parent Product to be active. Pass `include_inactive: true` only for intentional correction workflows; inactive results then include a status suffix (`· Inactive` / `· Discontinued`) and an inactive option class.
* Results are scoped to `Current.organization`. Variant search may further scope with `product_id`, and matches product identifier / alternate identifier as well as name/SKU.
* In-flight searches use abort + request tokens so stale responses cannot repopulate the listbox after clear, query change, or Product rescope.
* Server-side authorization is required per record type; the UI must not be the only gate.

### Labels

Reuse path / option helpers:

* hierarchical records → `hierarchy_path_label`
* variants → `variant_option_label`
* customers → `customer_option_label` / `record_picker_label`
* other masters → `record_option_label` / `record_picker_label`

### Accessibility

* Every picker has a visible `<label>` associated with the query input.
* Focus remains on the text input while navigating options.
* Do not rely on color alone for selected/active option state.
* Disabled pickers (for example locked foreign keys after create) remain readable and expose the selected label.

### Out of scope for the foundation

* Create-from-picker actions (optional later; keep deep links such as product import).
* Nested PO/receipt line template re-init (foundation is Stimulus-compatible; adoption is a follow-on).

## Tabs

ShelfStack uses progressive-enhancement tabs for multi-section record pages (Phase 10 product show).

### Baseline (no JavaScript)

* Navigation is ordinary in-page anchors (`<a href="#inventory">`), not inert buttons.
* All panel content is present and readable in the initial HTML (stacked).
* Server markup provides stable tab and panel IDs plus `data-tabs-target` hooks. It does **not** apply `role="tablist"` / `role="tab"` / `role="tabpanel"` or hide inactive panels.

### Enhancement (Stimulus `tabs`)

When connected, Stimulus:

* applies `role="tablist"`, `role="tab"`, and `role="tabpanel"`;
* sets `aria-selected`, roving `tabindex`, and `aria-controls` / `aria-labelledby` as needed;
* hides inactive panels;
* synchronizes the URL fragment on activation;
* supports Left/Right between tabs and Home/End to first/last;
* on load / `popstate`, activates the fragment panel or **Overview** when the fragment is absent or unknown.

### Implementation

* Partial: `app/views/shared/_tabs.html.erb`
* Stimulus: `tabs` (`app/javascript/controllers/tabs_controller.js`)

Request/view tests assert IDs, fragments, content, and enhancement data attributes. System tests assert applied roles and synchronized ARIA state.

## Dependent select (progressive enhancement)

Used for hierarchical merchandise-class selection on the product form (Phase 10).

### Canonical contract

1. Render one ordinary hierarchical flat `<select name="product[merchandise_class_id]">` as the no-JavaScript baseline (path-ordered labels such as `Books › Nonfiction › History`).
2. With Stimulus, enhance presentation with a three-level cascade (primary → secondary → minor).
3. Exactly one field is submitted either way: `product[merchandise_class_id]`.
4. Cascade selects are presentation-only (no `name` attributes); they synchronize the canonical select. The canonical select may be visually hidden when enhanced; enhancement failure leaves it visible and usable. JavaScript must never create a second successful field with the same parameter name.

### Behavior

* Stopping at primary or secondary is allowed — submit the deepest node actually selected.
* Edit and validation-failure re-renders initialize correctly.
* Include the currently assigned class **and ancestor path** even when inactive; exclude other inactive classes from new selection.
* Clear child cascade selections when a parent changes.
