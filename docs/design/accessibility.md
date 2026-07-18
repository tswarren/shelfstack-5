# Accessibility baseline

**Status:** Governing minimum for ShelfStack UI  
**Applies to:** Back-office shell and operational workspaces, including POS

Accessibility is an adoption requirement, not Phase 7 polish.

## Required baseline

- Full keyboard operability for all actions that have a visible control.
- Visible `:focus-visible` indicators. If default outlines are replaced, replacements must remain visible (including forced-colors / high-contrast environments).
- Adequate contrast for text and critical controls against surfaces.
- Form controls have associated labels; errors are associated with fields.
- Status and severity are not communicated by color alone (text, icon, or badge label).
- Modal and drawer focus management: move focus in, trap while open, restore on close.
- Important dynamic changes (scan result, reservation warning, completion failure) are announced or otherwise available to assistive technology where practical.
- Adequate target sizes where touch is supported.
- Scanner-oriented flows must not make the application unusable with ordinary keyboard or assistive technology.

## POS density

Operational density is compatible with accessibility when hierarchy, focus, and state are explicit. Do not remove focus rings or skip labels to save space.

## Device profiles

POS may declare a minimum supported resolution and omit a full narrow-phone layout. Back-office pages should remain usable on laptop widths. See [application-shell.md](application-shell.md).
