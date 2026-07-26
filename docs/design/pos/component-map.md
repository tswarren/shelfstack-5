# POS component map

**Status:** Draft implementation map  
**Parent:** [README.md](README.md)  
**Visual contract:** [visual-contract.md](visual-contract.md)  
**Presentation inventory:** [presentation-matrix.md](presentation-matrix.md)

## Purpose

This document maps the accepted POS visual composition to Rails partials, forms, Turbo boundaries, and Stimulus controllers.

It is not a requirement to create every listed partial immediately. Split components when they have a distinct visual responsibility, command, replacement boundary, or testing need. Avoid creating partials solely to make files shorter.

## Component levels

The POS is composed at four levels:

1. **Document shell** — HTML layout, assets, workspace frame, overlay host.
2. **Presentation compositions** — Ready, Transaction, Tender, Recovery, Receipt.
3. **Stable workspace components** — header, totals, Customer summary, readiness, commands.
4. **Operation components** — forms, rows, lookup results, tender controls, approval controls.

Do not mix these levels:

- a form partial does not determine the full presentation layout;
- a presentation partial composes components but does not calculate domain results;
- a shared component does not infer permissions or server readiness beyond the values passed to it;
- JavaScript does not own transaction state.

## Turbo consistency boundaries

### `pos_workspace`

The complete authoritative register presentation.

Contains:

- register header;
- primary workspace;
- summary rail;
- command bar;
- warnings and status;
- presentation-specific components.

A transaction mutation may affect lines, totals, readiness, tenders, permissions, focus, and presentation state at once. Replace the complete workspace so the browser receives one coherent server-rendered snapshot.

Do not make separate authoritative frames for:

- transaction lines;
- totals;
- readiness;
- Customer summary;
- primary CTA;
- tender collection.

Those are visual components, not independent consistency boundaries.

### `pos_overlay`

The temporary supporting-work frame.

Used for:

- Product lookup;
- Customer lookup and compact creation;
- Receipt lookup;
- linked-return selection;
- Stored Value lookup;
- Open Ring entry;
- discount, price, tax, and approval forms;
- Cash Movement.

The overlay may update independently until an action changes authoritative POS state. A successful state-changing action replaces `pos_workspace`, clears `pos_overlay`, closes the dialog, and restores focus.

### Optional results frame

A lookup may use a nested results frame when the result list is richer than the existing Stimulus record picker. It remains inside `pos_overlay` and does not own transaction state.

## Document-level components

### `app/views/layouts/pos.html.erb`

Retain:

- document metadata;
- POS assets;
- skip link;
- CSRF/CSP tags;
- `pos_workspace` frame;
- overlay host and `pos_overlay` frame;
- nonvisual live-announcement region.

Remove or avoid:

- normal shared application page header;
- presentation-specific business markup;
- transaction-specific calculations.

### `app/views/layouts/pos_receipt.html.erb`

Retain as a separate browser-print document. It does not render the interactive POS shell.

## Shared shell components

Suggested structure:

```text
app/views/pos/
  _shell.html.erb
  _register_header.html.erb
  _flash_region.html.erb
  _live_region.html.erb
```

### `_shell`

Owns only:

- shell classes and presentation modifier;
- header, primary, summary, and command regions;
- Stimulus controller root;
- yielded presentation content.

### `_register_header`

Displays compact operational identity:

- store;
- POS device/register;
- drawer where applicable;
- cashier;
- session;
- presentation;
- restricted operational navigation.

### `_flash_region`

Displays bounded operation results and errors without changing overall geometry unnecessarily.

### `_live_region`

Provides polite announcements for successful scans, line changes, Customer changes, settlement changes, Recovery, and completion.

## Presentation compositions

Suggested structure:

```text
app/views/pos/presentations/
  _ready.html.erb
  _transaction.html.erb
  _tender.html.erb
  _recovery.html.erb
  _receipt.html.erb
```

Each presentation partial determines:

- which components appear;
- which region contains each component;
- presentation-specific visual modifier;
- command-bar composition.

It does not own domain calculations or duplicate `Pos::WorkspacePresentation` logic.

### Ready

Primary:

- Ready start area;
- scan-to-start;
- Ready launcher tiers (`ready/_intent_launchers` — not Transaction entry intents).

Summary:

- staged Customer;
- suspended-work preview;
- session summary.

Commands:

- Cash Movement;
- No Sale;
- Store Operations.

Close Session and day/session administration are first-level actions inside Store Operations, not ordinary Ready command-bar items.

### Transaction

Primary:

- entry bar with `entry/_intent_selector` (`Sale | Return | Stored Value | Open Ring`);
- line collection;
- selected-line context.

Summary:

- Customer;
- totals;
- readiness;
- sign-aware progression CTA (not duplicated in the command bar).

Commands:

- Quantity, Remove, Discount, Price override;
- More (tax override, unit selection, etc.);
- Suspend;
- Cancel;
- other secondary transaction actions.

### Tender

Primary:

- direction and balance status;
- tender method selector;
- active tender form;
- recorded tenders.

Summary:

- compact transaction/Customer context;
- total;
- tendered/refunded amount;
- remaining balance;
- completion readiness.

Commands:

- Return to Transaction when safe;
- Remove selected tender;
- More / permitted tender correction.

Progression (`Add payment $X`, `Add refund $X`, `Complete transaction`) lives only in the summary rail.

Tender must have intentional markup. It is not Transaction with the primary column hidden.

### Recovery

Primary:

- incident summary;
- numbered verification steps;
- permitted resolution component (dominant Recovery control).

Summary:

- transaction amount;
- affected tender or fact;
- masked reference;
- Recovery status.

Commands:

- normally absent or extremely limited; do not move the required resolution solely into a generic command bar.

### Receipt

Primary:

- completion identity;
- receipt number;
- change due;
- final tender summary;
- Next Transaction (completion action area only).

Summary:

- optional compact final totals and Customer context; Receipt need not use the ordinary operational rail.

Commands:

- Print;
- Reprint;
- View detail;
- subordinate return/correction actions under More.

Do not duplicate Next Transaction in the command bar.

## Stable shared components

Suggested structure:

```text
app/views/pos/components/
  _customer_summary.html.erb
  _transaction_totals.html.erb
  _readiness_summary.html.erb
  _primary_action.html.erb
  _warning_list.html.erb
  _session_summary.html.erb
  _transaction_reference.html.erb
  _tender_summary.html.erb
```

### Component rules

- Accept explicit locals.
- Render values already projected by the server.
- Support compact/read-only variants only when the underlying information is genuinely shared.
- Do not call mutating services.
- Do not use broad controller instance-variable coupling when a focused local can be passed.
- Do not combine unrelated actions simply because they occupy the same rail.

## Entry components

Suggested structure:

```text
app/views/pos/entry/
  _entry_bar.html.erb
  _intent_selector.html.erb
  _scan_form.html.erb
  _scan_result.html.erb
  _lookup_launcher.html.erb
```

The visible Transaction Entry Bar combines:

```text
[ Sale | Return | Stored Value | Open Ring ] [ Scan / ISBN / SKU ] [Qty] [Add]
```

`entry/_intent_selector` is used only inside an active Transaction. It is not the Ready launcher hierarchy.

The operation implementations remain separate:

- scan/exact identifier;
- Product lookup;
- Stored Value issue/reload;
- Open Ring;
- linked return.

Do not retain one `_scan_form` partial that contains all intent-specific workflows.

## Ready components

Suggested structure:

```text
app/views/pos/ready/
  _start_area.html.erb
  _intent_launchers.html.erb
  _staged_customer.html.erb
  _suspended_transactions.html.erb
  _session_actions.html.erb
  _register_unavailable.html.erb
```

`ready/_intent_launchers` owns the Ready tiers from POS-UI-033 (Product lookup, Start return, supporting customer-work strip). It must not render a Ready-level Sale intent and must not reuse `entry/_intent_selector`.

No-business-day, no-session, active-transaction, and insufficient-permission conditions are Ready substates. They remain inside the POS shell.

Detailed day/session tables, Close Session, and cash-movement history belong in Store Operations, not the normal Ready composition.

## Line components

Suggested structure:

```text
app/views/pos/lines/
  _collection.html.erb
  _line.html.erb
  _line_metadata.html.erb
  _empty.html.erb
  _selected_line_commands.html.erb
```

### `_collection`

Owns:

- semantic table/grid wrapper;
- bounded internal scrolling;
- column header;
- empty state;
- line collection render.

### `_line`

Owns one line’s visible facts and selection control.

Retain semantic keyboard selection. The whole row may not be mouse-only.

### `_selected_line_commands`

Owns ordinary selected-line actions:

- quantity;
- remove;
- discount;
- price override;
- tax override;
- return disposition;
- Inventory Unit selection.

Complex or approval-sensitive actions launch overlays.

## Action-specific forms

Each form represents one server command.

Suggested structure:

```text
app/views/pos/forms/
  _scan_to_start.html.erb
  _add_product_line.html.erb
  _update_quantity.html.erb
  _open_ring.html.erb
  _stored_value_line.html.erb
  _return_lookup.html.erb
  _return_line.html.erb
  _attach_customer.html.erb
  _discount.html.erb
  _price_override.html.erb
  _tax_override.html.erb
  _tax_exemption.html.erb
  _cash_tender.html.erb
  _card_tender.html.erb
  _stored_value_tender.html.erb
  _complete_transaction.html.erb
  _confirm_void.html.erb
  _cash_movement.html.erb
```

A form owns:

- fields;
- field errors;
- action URL and method;
- submit label;
- required hidden navigation context;
- Turbo target.

A form does not own:

- shell layout;
- unrelated totals;
- authoritative presentation-state derivation;
- client-side permission decisions.

## Tender components

Suggested structure:

```text
app/views/pos/tender/
  _direction_status.html.erb
  _method_selector.html.erb
  _active_form.html.erb
  _recorded_tenders.html.erb
  _tender.html.erb
  _remaining_balance.html.erb
  _completion_status.html.erb
```

Switching a tender-method form is presentational and may use query navigation, a small local frame, or Stimulus. Recording, removing, confirming, or voiding a tender replaces the authoritative workspace.

## Recovery components

Suggested structure:

```text
app/views/pos/recovery/
  _incident_summary.html.erb
  _verification_steps.html.erb
  _allowed_actions.html.erb
  _void_required.html.erb
```

Use an explicit component for each supported structured Recovery category. Do not create a broad generic exception form that guesses permitted actions from message text.

## Receipt components

Suggested structure:

```text
app/views/pos/receipt/
  _completion.html.erb
  _receipt_identity.html.erb
  _change_due.html.erb
  _final_tenders.html.erb
  _actions.html.erb
  _transaction_detail.html.erb
```

Detailed completed lines may remain subordinate or disclosed. Next Transaction and Print remain visually dominant.

## Overlay components

Suggested structure:

```text
app/views/pos/overlays/
  _frame.html.erb
  _product_lookup.html.erb
  _customer_lookup.html.erb
  _customer_form.html.erb
  _receipt_lookup.html.erb
  _linked_return_lookup.html.erb
  _stored_value_lookup.html.erb
  _open_ring.html.erb
  _line_discount.html.erb
  _price_override.html.erb
  _tax_override.html.erb
  _cash_movement.html.erb
```

The generic overlay frame owns only title, close control, focus containment, size, and yielded content.

Product lookup may require a POS-specific result presentation rather than the generic record picker because the cashier may need title, variant, format, identifier, price, availability, and tracking context before selecting.

## Stimulus controllers

### `pos-register`

Retain for ergonomics only:

- initial and restored focus;
- visible keyboard shortcuts;
- live announcements;
- duplicate-submit UI;
- Turbo cache cleanup.

### `pos-dialog`

Add for:

- opening/closing `<dialog>`;
- focus containment and restoration;
- safe Escape handling;
- clearing stale overlay content;
- reacting to successful Turbo replacement.

### `pos-line-list`

Optional for:

- arrow-key line navigation;
- selected-row focus;
- Home/End behavior;
- keeping the selected line visible.

It does not mutate line state directly.

### `pos-tender-entry`

Optional for:

- amount-input ergonomics;
- cash-presented shortcuts;
- numpad handling;
- switching purely presentational tender forms.

It does not decide tender validity or sufficiency.

### `record-picker`

Retain for simple record selection. Supplement it with richer POS-specific lookup where operational comparison is required.

## Current-to-target mapping

| Current view/partial | Treatment |
| --- | --- |
| `layouts/pos` | Retain; replace shared app header; add workspace and overlay boundaries |
| `register/show` | Reduce to resolving and rendering Ready presentation/substate |
| `pos_transactions/show` | Reduce to rendering one resolved presentation composition |
| `_session_context` | Move useful identity into register header |
| `_transaction_status` | Fold into compact header/status region |
| `_recall_summary` | Render only when operationally relevant |
| `_entry_intents` | Move into Transaction `entry/_intent_selector`; do not reuse for Ready launchers |
| `_scan_form` | Split by scan, Stored Value, Open Ring, and return responsibilities |
| `_line_items` | Retain concept; convert to bounded central collection |
| `_line_item` | Retain and refine selection/action hierarchy |
| `_selected_line_actions` | Move into selected-line command component |
| `_customer_panel` | Convert to compact Customer summary plus overlay launchers |
| `_totals` | Retain as explicit-local shared totals component |
| `_readiness_summary` | Retain separately from totals |
| `_primary_cta` | Retain as summary-rail progression CTA for Transaction/Tender; never duplicate in command bar |
| `_tenders` | Split collection and row |
| `_tender_entry` | Split by tender method |
| `_recovery_panel` | Promote to Recovery primary workspace |
| `_secondary_actions` | Recompose into contextual command bar/menu |
| `_transaction_actions` | Recompose per presentation command bar |
| `shared/_record_picker` | Retain for simple selection; supplement for rich Product lookup |

## Dependency rules

- Presentations may render stable components, operation components, and forms.
- Operation components may render shared field primitives.
- Stable components must not render whole presentations.
- Forms must not select presentation state.
- Stimulus may improve local interaction but must not become the source of commercial state.
- Turbo Frames follow consistency boundaries, not visual boxes.
- A bordered panel is not automatically a Turbo Frame.

## Review checklist

- [ ] Each partial has one clear visual or command responsibility.
- [ ] Presentation composition is visible in one place.
- [ ] Server-authoritative state is replaced coherently.
- [ ] Overlays are transient and focus-safe.
- [ ] Forms map to explicit server commands.
- [ ] No domain calculation is duplicated in JavaScript.
- [ ] Tender and Recovery have dedicated compositions.
- [ ] Shared components are genuinely shared, not condition-heavy universal panels.
- [ ] File structure supports the accepted workflow rather than driving it.
