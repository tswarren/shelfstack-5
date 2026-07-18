# Application shell

**Status:** Governing for shared chrome  
**Prototype reference:** [prototypes/ui_mockup/index.html](prototypes/ui_mockup/index.html)

## Two interface modes

### Administrative / back-office

Record-oriented work (catalog, classification, users, reasons, devices) may use search, tables, detail pages, forms, and explicit save/deactivate. Prefer a coherent business object over exposing every foreign key as a separate “app.”

### Operational workspaces

POS, receiving, adjustments, and similar loops keep the user in one context for rapid repeated actions. These may be denser and more keyboard-oriented than admin pages. The design system supports both modes.

## Shell structure

Back-office default:

```text
[ sticky header: brand | store context | user ]
[ sidebar nav | main content ]
```

- Header height and sidebar width use design tokens.
- Active nav uses a soft primary tint and inset primary border (see prototype).
- Main content is a single scrollable canvas with a bounded inner width where helpful.

## Store and user context

ShelfStack is store-centered. Where inventory, POS, cash, or store-scoped masters are involved, show:

- organization / store (active store);
- current user;
- switch-store affordance when the user has multiple memberships.

Do not let users believe they are acting at store A while mutating store B’s records. Context should be prominent without consuming the workspace.

A user’s default store is a navigation preference and does not grant access.

## Navigation clusters

Group links by function (workspace, operations, administration). Hide items the user cannot access. Do not hard-code role names in the UI layer; use permission evaluation.

## Responsive expectations

| Profile | Expectation |
| --- | --- |
| Back-office desktop / laptop | Full shell |
| Narrower desktop | Collapse multi-column grids; stack split layouts |
| Phone | Limited admin/lookup; full POS register layout is not required on narrow phones |
| Dedicated register | POS workspace; may set a minimum width |

## Out of scope for early adoption

Rebuilding every Phase 1–3 CRUD screen into the full mockup shell is not required before Phase 4a. Apply header/context and tokens first; deepen shell usage as screens are touched.
