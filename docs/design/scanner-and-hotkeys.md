# Scanner and hotkeys

**Status:** Governing baseline for POS input (Phase 6.5)  
**Exploratory archive:** [../archive/ux-drafts-2026-07/keyboard-shortcuts-barcode-integration.md](../archive/ux-drafts-2026-07/keyboard-shortcuts-barcode-integration.md)  
**Prototype:** [prototypes/ui_mockup/pos.html](prototypes/ui_mockup/pos.html)  
**POS UI contract:** [pos-register-ui.md](pos-register-ui.md)

## Scanner model

Most USB/Bluetooth scanners act as keyboard wedges and append Enter (or equivalent) after the barcode payload.

### Dedicated scan field

1. Maintain a dedicated scan input as the default focus target in Ready (scan-to-start) and open Transaction.
2. On Enter: prevent default form submit / full-page navigation; trim payload; dispatch resolve/add to the application; clear the field on success.
3. Restore focus to the scan field after successful add and after dismissing non-blocking dialogs where safe (see [pos-register-ui.md](pos-register-ui.md) focus contract).
4. While a modal or intent panel requires input, that task owns the next scan; otherwise ordinary sale entry owns scanning.
5. `Escape` cancels the current temporary intent/task and restores Sale intent + entry focus where implemented.

### Scan-to-start (Ready)

Resolve **before** opening a transaction:

```text
Validate store/session/permissions
→ ResolveScan (no transaction required)
→ no match / ambiguous / unresolved → remain Ready (no empty transaction)
→ resolved → OpenTransaction + AddLine atomically
→ redirect to Transaction
```

Do not open an empty transaction solely for an ambiguous descriptive search. Offer **Open transaction to resolve** when needed.

If an open transaction already exists for the register session, resume/use it — do not create a second.

### Distinguishing scan vs typing

Speed-threshold “global body capture” may be explored later for dedicated registers. It is **not** required for Phase 6.5. Prefer the dedicated field pattern.

### Resolution

Scans resolve through ShelfStack identifier rules (ISBN normalization, namespaces `21` / `27` / `28` / `29`, variant vs unit). Ambiguous product-level hits require variant selection.

Entry **intents** change interpretation: Sale (merchandise), Return, Stored value, Open ring. Intents are not transaction types.

## Hotkeys (progressive)

1. **All actions remain available via visible controls.**
2. Prefer browser-safe shortcuts in ordinary desktop browsers.
3. Dedicated-register shortcuts may conflict with browser defaults only when explicitly adopted for that deployment profile.
4. No destructive or irreversible action from a single accidental keystroke without confirmation or server-side completion validation.
5. Customizable per-store hotkey layouts are out of Phase 6.5 scope.

### Completion shortcut

`Ctrl+Enter` (or successor) may **request** completion when the UI believes the tender balance is resolved. The completion service remains authoritative and may reject the request. It does **not** bypass validation.

### Receipt shortcut

On Receipt, focus the **Next transaction** control so native Enter activates it. Announce completion and receipt number in the live region first.

## PWA / installable register

An installable or standalone web app may be evaluated later for dedicated registers. It is a deployment option, not adopted architecture. It does not imply offline POS (deferred capability).

## Stack constraint

Ordinary frontend behavior continues to use Rails Importmap, Propshaft, Turbo, and Stimulus. Do not introduce Node/npm/Yarn solely for scanner handling.
