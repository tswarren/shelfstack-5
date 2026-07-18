# ShelfStack UI mockups (prototypes)

**Status:** Living visual / interaction reference — **not** authoritative for business logic  
**Governing design docs:** [`docs/design/`](../../README.md)

Open `index.html` in a browser.

## Demo-only warning

Prototype JavaScript in these pages (especially `pos.html`) is **demo-only**. It must not be treated as implementation guidance for:

- pricing or discounts
- tax calculation or tax category resolution
- inventory reservation or availability
- tender posting or stored-value ledger effects
- receipt numbering
- transaction completion, atomicity, or idempotency

The server remains authoritative for all of the above. Monetary amounts in ShelfStack are integer cents; completed POS validation is never bypassed by a keyboard shortcut.

## Files

- `index.html` — dashboard application mockup (includes future-state widgets)
- `record.html` — product-detail application mockup
- `pos.html` — compact, keyboard-friendly point-of-sale mockup
- `components.html` — color, form, alert, badge, button, tab, and table reference
- `styles.css` — shared design tokens and component styles
- `shelfstack-icon.svg` — the ShelfStack SVG icon

The mockup is static and self-contained. No web server, package installation, or external assets are required.
