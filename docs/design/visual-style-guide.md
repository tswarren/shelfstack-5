# Visual style guide

**Status:** Governing for shared visual language  
**Prototype reference:** [prototypes/ui_mockup/styles.css](prototypes/ui_mockup/styles.css), [components.html](prototypes/ui_mockup/components.html)  
**Implemented tokens:** `app/assets/stylesheets/shelfstack/`

## Brand and semantic colors

Use CSS custom properties. Do not invent one-off palette hexes in feature CSS.

| Category | Tokens | Use |
| --- | --- | --- |
| Brand | `--brand-primary`, `--brand-secondary`, `--brand-accent` (+ hover/soft) | Identity, primary actions, limited accent |
| Surfaces | `--bg-100`, `--bg-200`, `--surface-primary`, `--surface-selected` | Canvas, sidebar, cards, selection |
| Text | `--text-primary`, `--text-secondary`, `--text-muted` | Hierarchy |
| Semantic | `--info*`, `--success*`, `--warning*`, `--danger*` | Status only — never use brand crimson for destroy |

Destructive actions use `--danger`, not brand secondary.

## Typography

- Family: Inter, then system UI sans stack (as in prototype tokens).
- Prefer clear hierarchy over decorative display faces in operational screens.
- POS totals and badges may use heavier weights; body copy stays readable at operational density.

## Layout tokens

| Token | Role |
| --- | --- |
| `--header-height` | Sticky app / POS header |
| `--sidebar-width` | Back-office nav column |
| `--radius-sm` / `--radius-md` / `--radius-lg` | Controls, cards, panels |
| `--shadow-sm` / `--shadow-md` | Elevation without heavy chrome |

## Action hierarchy

| Class | Role |
| --- | --- |
| Primary | Save, confirm, complete tender path |
| Secondary brand | Auxiliary brand actions |
| Accent | Rare specialized workflows |
| Outline / ghost | Cancel, secondary navigation |
| Danger | Destructive or irreversible intent |

## Alerts and badges

Pair background, border, and text tokens for info / success / warning / danger. Status must not rely on color alone (see [accessibility.md](accessibility.md)).

## Density

- Back-office: comfortable tables and forms.
- Operational workspaces (POS): denser panels, persistent scan focus, prominent totals — without sacrificing focus visibility or target size where touch is supported.

## Money display

Display formatted currency (for example `$20.00`). Persist and compute in integer cents. Never treat unknown cost as `$0.00`.
