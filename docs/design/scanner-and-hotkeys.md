# Scanner and hotkeys

**Status:** Governing baseline for POS input  
**Exploratory archive:** [../archive/ux-drafts-2026-07/keyboard-shortcuts-barcode-integration.md](../archive/ux-drafts-2026-07/keyboard-shortcuts-barcode-integration.md)  
**Prototype:** [prototypes/ui_mockup/pos.html](prototypes/ui_mockup/pos.html)

## Scanner model

Most USB/Bluetooth scanners act as keyboard wedges and append Enter (or equivalent) after the barcode payload.

### Dedicated scan field (Phase 4 baseline)

1. Maintain a dedicated scan input as the default focus target in an open transaction.
2. On Enter: prevent default form submit / full-page navigation; trim payload; dispatch resolve/add to the application; clear the field.
3. Restore focus to the scan field after successful add and after dismissing non-blocking dialogs where safe.
4. While a modal requires input, do not silently consume scanner payload into the wrong field; document focus ownership.

### Distinguishing scan vs typing

Speed-threshold “global body capture” may be explored later for dedicated registers. It is **not** required for the Phase 4a gate. Prefer the dedicated field pattern first.

### Resolution

Scans resolve through ShelfStack identifier rules (ISBN normalization, namespaces `21` / `27` / `28` / `29`, variant vs unit). Ambiguous product-level hits require variant selection. Exact inventory-unit scans are Phase 4d.

## Hotkeys (progressive)

1. **All actions remain available via visible controls.**
2. Prefer browser-safe shortcuts in ordinary desktop browsers.
3. Dedicated-register shortcuts may conflict with browser defaults only when explicitly adopted for that deployment profile.
4. No destructive or irreversible action from a single accidental keystroke without confirmation or server-side completion validation.

### Completion shortcut

`Ctrl+Enter` (or successor) may **request** completion when the UI believes the tender balance is resolved. The completion service remains authoritative and may reject the request. It does **not** bypass validation.

## PWA / installable register

An installable or standalone web app may be evaluated later for dedicated registers. It is a deployment option, not adopted architecture. It does not imply offline POS (deferred capability).

## Stack constraint

Ordinary frontend behavior continues to use Rails Importmap, Propshaft, Turbo, and Stimulus. Do not introduce Node/npm/Yarn solely for scanner handling.
