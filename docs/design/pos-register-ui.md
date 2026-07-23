# POS register UI

**Status:** Governing for Phase 6.5 cashier workspace (supersedes Phase 4-only interaction notes where they conflict)  
**Prototype reference:** [prototypes/ui_mockup/pos.html](prototypes/ui_mockup/pos.html)  
**Phase plan:** [../implementation/phases/phase-06.5-cashier-workspace.md](../implementation/phases/phase-06.5-cashier-workspace.md)  
**Related:** [scanner-and-hotkeys.md](scanner-and-hotkeys.md); [accessibility.md](accessibility.md)  
**Domain:** [point-of-sale](../domains/point-of-sale.md)

## Layout principles

Persistent cashier workspace with stable regions:

```text
Header: store · device · session · cashier · presentation status
Entry:  scan / identifier / search          [ current intent ]
Lines:  transaction lines (selection)    | Summary: totals + readiness
Action: selected-line or transaction actions     [ dynamic primary CTA ]
```

- Scan entry is primary; restore focus per the focus contract below.
- Product / Product Variant / Inventory Unit remain distinguishable in resolution UI.
- Labels may be cashier-friendly (for example “Register 2”) while the system records POS device and drawer separately.
- Day/session open forms are **pre-Ready operational** states, not POS transaction presentation states.

## Terminology (UI vs domain)

| Prefer in UI | Domain meaning |
| --- | --- |
| Merchandise class | Hierarchical merchandise class (not a separate display category) |
| Product request | Customer/staff demand — not an inventory reservation |
| POS device / drawer | Distinct from session and business day |
| Tax category / store tax rules | Taxability — never inferred from item title text |

Stored-value redemption is tender, not a discount. Issuance is non-revenue liability activity.

## Presentation states

These are **cashier-facing presentation states**. They do **not** require corresponding database status values. Do not invent persisted statuses such as `processing`, `receipt`, or `recovery`.

Derive state in one server-side place (`Pos::WorkspacePresentation` or equivalent):

```text
No active transaction and operational session open
→ Ready
  (missing day/session/device = pre-Ready operational setup)

Completed transaction
→ Receipt

Open transaction with void_required tender activity
→ Recovery

Open transaction with unresolved tenders
→ Tender (forced by server)

Open transaction with presentation=tender (or /tender) and editable
→ Tender (UI choice; reload-safe URL)

Otherwise open
→ Transaction

Processing
→ client-ephemeral only while the completion form is submitting
```

After pending or authorized tenders exist, reload **must** force Tender (or Recovery if `void_required`). Opening Tender before any tender is entered is a UI choice via reload-safe URL (`GET .../tender` or `?presentation=tender`).

### Entry intents (not transaction types)

Within **Transaction**:

```text
Sale (default) | Return | Stored value | Open ring
```

Receipt lookup from Ready is a **register utility**, not an entry intent.

### Navigation context (URL / form state only)

Never used for eligibility or posting:

```text
intent=sale|return|stored_value|open_ring
selected_line_id=
presentation=transaction|tender
focus_target=scan|line_actions|first_blocker|next_transaction|...
```

## Primary actions (sign-aware)

| Situation | Primary action |
| --- | --- |
| Empty / scanning | Focus entry (Continue scanning) |
| Positive net, unpaid | **Tender $X** |
| Negative net, unpaid | **Issue refund $X** |
| Blockers present | **Resolve N blockers** |
| Payment remaining | **Add payment $X** |
| Refund remaining | **Add refund $X** |
| Settled | **Complete transaction** |
| Completed | **Next transaction** → Ready (no empty txn) |
| Recoverable failure | Explicit recovery control |

Avoid generic **Continue** / **Submit** / **Save** as the dominant control.

## Focus-management contract

- Opening a transaction focuses the entry field.
- Completing a selected-line action restores entry focus unless another required task remains.
- Cancelling an intent restores Sale intent and entry focus.
- Closing an approval prompt returns to the affected action or line.
- Returning from tender restores the previously selected line or entry field.
- Validation failure moves focus to the first resolvable blocker.
- Receipt focuses the **Next transaction** control; live region announces completion and receipt number first.
- Recovery focuses the primary recovery control.

## Confirmation standards

Confirm hard-to-reverse or money-abandoning actions only:

- cancel transaction;
- remove or alter an externally approved card tender;
- leave Tender with unresolved activity (when allowed);
- recall that would displace current work.

Do **not** require confirmation for ordinary line removal unless policy already demands a reason/approval. Post-void begin uses the existing post-void workflow (not a core 6.5 confirmation).

## Warnings, blockers, approvals, and readiness

| Kind | Meaning | UI |
| --- | --- | --- |
| Information | No action required | Quiet display |
| Warning | Proceed allowed (for example negative available) | Persistent; do not block Tender |
| Approval | Restricted result needs approver | Interrupt; return to same context |
| Blocker | Cannot tender/complete until resolved | Disable Tender/Complete; link to line/field |

**The server determines readiness; the interface presents it.** Use a side-effect-free projection (`Pos::ProjectCompletionReadiness`) for GET renders. Do **not** call locking/mutating `ValidateCompletionReadiness` or `RecalculateTransaction` from show. Completion always reruns authoritative validation under locks.

Stable issue/recovery **codes** drive focus and recovery UI — do not parse flash alert text.

## Recovery (closed list)

Present from persisted state + structured outcome codes:

- validation failed before posting;
- duplicate / already-completed (idempotent);
- card approved but internal completion failed;
- `void_required`;
- transaction / session / business day no longer valid;
- stale or invalid reservation;
- stored-value balance changed / redemption blocked.

Triage new categories; do not invent a broad exception framework.

## Supported register viewport

- Intended: desktop register / laptop widths with the persistent shell usable.
- Minimum usable width: align with existing POS CSS breakpoint (~960px stacks to one column; declare phone-width POS **unsupported**).
- Summary may stack below lines on narrow widths within the supported range.
- Drawers/panels overlay the workspace; trap focus while open ([accessibility.md](accessibility.md)).
- Touch-first / phone POS is out of Phase 6.5 scope.

## Accessibility

Apply [accessibility.md](accessibility.md) while restructuring: real controls, keyboard reachability, visible focus, live-region announcements, severity not by color alone, modal/drawer focus containment, labeled intent and readiness.

Line selection must be a keyboard-focusable control (button / radio / equivalent), not mouse-only row click.

## Turbo / Back

- Active Transaction, Tender, Processing, and Recovery must not restore stale Turbo snapshots.
- Clear transient disabled-submit state on `turbo:before-cache`.
- Browser Back must not show editable controls for an already completed transaction.
- Server state always wins after navigation.

## Server authority

Client may preview totals and keep focus. Server owns eligibility, reservation, price, tax, tender sufficiency, posting, receipt numbers, and completion idempotency. Prototype cart math is not a contract.
