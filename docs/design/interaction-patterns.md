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
* creator (Gate 8b+).

Do **not** use it for small closed enums (`status`, `product_type`, tracking mode).

### Implementation

* Partial: `app/views/shared/_record_picker.html.erb`
* Stimulus: `record-picker` (`app/javascript/controllers/record_picker_controller.js`)
* Search: `GET /catalog/record_searches?type=…&q=…` (`Catalog::RecordSearchesController` → `Catalog::SearchRecords`)

The control submits a hidden id field with the correct param name for ordinary Rails forms (including `fields_for`). It does not require a single-page application.

### Behavior

* Typeahead search with keyboard navigation (↑ ↓ Enter Esc).
* Clear control when blank selection is allowed.
* Loading, empty, and error status text via `aria-live`.
* Combobox semantics: `role="combobox"` on the text input, `role="listbox"` / `option` on results.
* Inactive records are **excluded by default**. Pass `include_inactive: true` only for intentional correction workflows.
* Results are scoped to `Current.organization`. Variant search may further scope with `product_id`.
* Server-side authorization is required per record type; the UI must not be the only gate.

### Labels

Reuse path / option helpers:

* hierarchical records → `hierarchy_path_label`
* variants → `variant_option_label`
* other masters → `record_option_label` / `record_picker_label`

### Accessibility

* Every picker has a visible `<label>` associated with the query input.
* Focus remains on the text input while navigating options.
* Do not rely on color alone for selected/active option state.
* Disabled pickers (for example locked foreign keys after create) remain readable and expose the selected label.

### Out of scope for the foundation

* Create-from-picker actions (optional later; keep deep links such as product import).
* Nested PO/receipt line template re-init (foundation is Stimulus-compatible; adoption is a follow-on).
