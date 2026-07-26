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

## Icons

ShelfStack vendors a small **Phosphor Icons** subset (MIT; Regular weight) as inline SVG via `IconsHelper#icon_tag`.

Rules:

* Icons inherit `currentColor` — do not hard-code fill colors in the SVG paths.
* Only allowlisted names may be rendered; unknown names raise (no arbitrary path lookup).
* Decorative icons default to `aria-hidden="true"`. Pass `title:` when the icon is the sole accessible name.
* Prefer **icon + text** for actions and navigation. Icon-only controls need an accessible name (`aria-label` / `title:`).
* Do not grow this into a general-purpose icon system beyond page needs without an intentional design decision.

Documented allowlist lives in `app/helpers/icons_helper.rb` (`IconsHelper::ICONS`).

## Sticky form action bar

Product create/edit (Phase 10b) uses `.form-actions--sticky`:

* Sticky when viewport width is at least **701px** (above the narrow form-grid collapse) **and** viewport height is at least **640px**.
* Collapses to normal in-flow positioning on narrower or shorter viewports.
* Opaque background, top border, bottom safe-area padding; form content reserves bottom padding equal to the bar height so fields are never covered.
* Sticky positioning is CSS-only; the bar remains a plain submit + cancel link without JavaScript.
* Action rows (`.form-actions`) are right-aligned. Secondary actions (Cancel / outline / ghost) sit to the left of the primary action: `[Cancel] [Update product]`.

## Density

- Back-office: comfortable tables and forms.
- Operational workspaces (POS): denser panels, persistent scan focus, prominent totals — without sacrificing focus visibility or target size where touch is supported.

## Money display

Display formatted currency (for example `$20.00`). Persist and compute in integer cents. Never treat unknown cost as `$0.00`.
