# POS annotated wireframes

**Status:** Draft composition reference — Phase 11 shell + Phase 11.2/11.3 workflow additions  
**Parent:** [README.md](README.md)  
**Visual contract:** [visual-contract.md](visual-contract.md)  
**Decisions:** [decisions.md](decisions.md)  
**Phase plans:** [phase-11.2…](../../implementation/phases/phase-11.2-register-workflow-refinement.md) · [phase-11.3…](../../implementation/phases/phase-11.3-pos-operations-workspace.md)

## Purpose

These wireframes define information hierarchy and stable region placement before production markup is refactored.

They are intentionally low fidelity. Typography, color, and exact spacing remain implementation details until reviewed through deterministic screenshots. The wireframes do not redefine server behavior.

**Phase 11 (L0–L7):** shared shell through Receipt and primary overlays (below).  
**Phase 11.2:** approval interrupt, return workflows, refund proposed plan, tender polish notes.  
**Phase 11.3:** Register Operations / Store Operations / navigation.

## Shared shell

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ SHELFSTACK POS · Store · Register/Device · Drawer · Cashier · Session · State│
├───────────────────────────────────────────────────┬──────────────────────────┤
│ PRIMARY OPERATIONAL WORKSPACE                     │ STABLE SUMMARY RAIL      │
│                                                   │                          │
│ Presentation-specific dominant task               │ Persistent context       │
│                                                   │ Totals / readiness        │
│ Flexible bounded content                          │ Primary progression       │
│                                                   │                          │
├───────────────────────────────────────────────────┴──────────────────────────┤
│ CONTEXTUAL COMMAND BAR                                                      │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Shared behavior

- Header, summary, and command regions remain visible.
- The primary region consumes remaining space.
- Long lines or results scroll internally.
- The summary rail may change content and ratio, but does not become an accidental leftover column.
- Overlays sit above the complete workspace and restore focus when closed.

## Ready

Ready launchers are not Transaction entry intents (POS-UI-033). There is no Ready-level Sale control.

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ SHELFSTACK POS · Main Store · Register 2 · Alex · Session 104 · READY        │
├───────────────────────────────────────────────────┬──────────────────────────┤
│ START CUSTOMER WORK                               │ NEXT TRANSACTION CONTEXT │
│                                                   │                          │
│ Scan / ISBN / SKU                                 │ Customer                │
│ ┌────────────────────────────────────┐ [Qty]      │  No customer staged      │
│ │                                    │ [Scan to   │                          │
│ └────────────────────────────────────┘  start]    │ Suspended work          │
│                                                   │  Txn … · 2 lines [Recall]│
│ [ Product lookup ] [ Start return ]               │  Txn … · Pat   [Recall]  │
│                                                   │  View all (N)            │
│ [ Customer ] [ Receipt lookup ] [ Open Ring ]     │                          │
│ [ Stored Value ] [ Pickup / Product Request ]     │ Session                  │
│                                                   │  Drawer open             │
│ Recent status/warning area                        │  Cash enabled            │
├───────────────────────────────────────────────────┴──────────────────────────┤
│ [Cash Movement] [No Sale]                              [Store Operations]   │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Ready annotations

1. Scan-to-start is the dominant control and initial focus.
2. Primary launchers are Product lookup and Start return; supporting customer-work actions remain visible without disclosures.
3. Customer, suspended-work preview (up to three + View all), and session context remain compact in the summary rail.
4. Lookups launch overlays.
5. Detailed business-day/session tables, Close Session, and cash history are not part of ordinary Ready (POS-UI-037: Close Session is first-level inside Store Operations).
6. Pre-Ready prerequisites reuse the shell but replace the start area with one clear operational task.

## Transaction

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ SHELFSTACK POS · Main Store · Register 2 · Alex · Session 104 · TRANSACTION  │
├───────────────────────────────────────────────────┬──────────────────────────┤
│ [Sale] [Return] [Stored Value] [Open Ring]         │ CUSTOMER                 │
│ Scan / ISBN / SKU ┌──────────────────┐ [Qty] [Add] │ Pat Example [Change]     │
│                   └──────────────────┘ [Lookup]     ├──────────────────────────┤
│ ┌────────────────────────────────────────────────┐ │ TOTALS                   │
│ │ Description                 Qty Price Disc Total│ │ Merchandise       $62.00 │
│ │ Book title                    1  18.00  —  19.08│ │ Returns           -$9.00 │
│ │ Long title wraps compactly    2  12.00 2.00 23.32│ Discounts          -$2.00 │
│ │ Return: original receipt      1  -9.00  —  -9.54│ │ Tax                $3.86 │
│ │ ...                                            │ │ TOTAL              $54.86 │
│ │             internal line scrolling            │ ├──────────────────────────┤
│ └────────────────────────────────────────────────┘ │ READINESS                │
│ Selected: Long title                              │ Ready to tender           │
│ Warning/status associated with affected line      │                          │
│                                                   │ [Tender $54.86]           │
├───────────────────────────────────────────────────┴──────────────────────────┤
│ [Qty] [Remove] [Discount] [Price override] [More]     [Suspend] [Cancel]   │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Transaction annotations

1. Entry and lines dominate the screen. The four-intent Entry Bar applies only inside an active Transaction (not Ready).
2. The line collection is the only ordinary scrolling region.
3. Customer, totals, readiness, and the progression CTA remain visible in the summary rail.
4. The selected line drives the command bar (Qty, Remove, Discount, Price override; More for uncommon actions).
5. The progression CTA is not duplicated in the command bar (POS-UI-023).
6. Complex line actions open overlays while preserving the selected line.
7. Tender forms do not appear expanded in Transaction.
8. Sale and return lines are distinguishable without relying on color alone.

## Tender — positive balance

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ SHELFSTACK POS · Main Store · Register 2 · Alex · Session 104 · TENDER       │
├───────────────────────────────────────────────────┬──────────────────────────┤
│ PAYMENT                                           │ TRANSACTION SUMMARY      │
│ Amount due $54.86                                 │ Customer: Pat Example    │
│                                                   │ Total              $54.86 │
│ [Cash] [Card] [Stored Value] [Other]              │ Tendered           $20.00 │
│                                                   │ REMAINING          $34.86 │
│ Active method: Card                               ├──────────────────────────┤
│ Amount ┌─────────────────────────────┐             │ SETTLEMENT               │
│        └─────────────────────────────┘             │ Payment still required   │
│ [Confirm approved card]                           │                          │
│                                                   │ [Add payment $34.86]      │
│ RECORDED TENDERS                                  │                          │
│ Cash · payment · $20.00                 [Remove]  │                          │
│                                                   │                          │
│ Compact read-only line review [View]              │                          │
├───────────────────────────────────────────────────┴──────────────────────────┤
│ [Return to Transaction] [Remove selected tender] [More]                    │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Tender — settled

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ ... · TENDER                                                                  │
├───────────────────────────────────────────────────┬──────────────────────────┤
│ RECORDED TENDERS                                  │ TRANSACTION SUMMARY      │
│ Cash · payment · $20.00                           │ Total              $54.86 │
│ Card · payment · $34.86                           │ Tendered           $54.86 │
│                                                   │ REMAINING           $0.00 │
│ Settlement complete                              ├──────────────────────────┤
│ Compact read-only line review [View]              │ Ready to complete        │
│                                                   │                          │
│                                                   │ [Complete Transaction]   │
├───────────────────────────────────────────────────┴──────────────────────────┤
│ [Return to Transaction, only when safe] [More]                             │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Tender annotations

1. Tender controls occupy the primary region.
2. Amount due/refundable and remaining balance are visually dominant.
3. Recorded tenders remain visible during split settlement.
4. Commercial line editing is absent.
5. Return to Transaction is absent when unresolved activity forces Tender.
6. Add payment / Add refund / Complete Transaction live only in the summary rail (never duplicated in the command bar).

## Tender — net refund

Use the same composition as positive balance, but replace payment language consistently and surface the **proposed refund plan** (Phase 11.2F) before recording tenders. Do not rely only on negative-number notation to communicate direction.

See [Refund proposed plan](#refund-proposed-plan-overlay) for the plan review overlay that precedes recording.

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ ... · TENDER · NET REFUND                                                     │
├───────────────────────────────────────────────────┬──────────────────────────┤
│ REFUND SETTLEMENT                                 │ TRANSACTION SUMMARY      │
│ Refund due $18.25                                 │ Total (net)       -$18.25 │
│                                                   │ Refunded           $10.00 │
│ Proposed plan (SV-first)                          │ REMAINING REFUND    $8.25 │
│  ✓ Stored value · original · $10.00  recorded     ├──────────────────────────┤
│  ○ Cash refund · $8.25               pending      │ SETTLEMENT               │
│                                                   │ Refund still required    │
│ [Review / edit plan]                              │                          │
│                                                   │ [Add refund $8.25]       │
│ RECORDED REFUND TENDERS                           │                          │
│ Stored value · refund · $10.00          [Remove]  │                          │
│                                                   │                          │
│ Compact read-only line review [View]              │                          │
├───────────────────────────────────────────────────┴──────────────────────────┤
│ [Return to Transaction] [Remove selected tender] [More]                    │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Tender polish annotations (Phase 11.2C)

1. Settlement hierarchy in the rail: Total → Tendered/Refunded → Remaining/Change → status → primary CTA.
2. Primary CTA by state: **Add tender** / **Add refund tender** / **Complete transaction** / resolve blocker.
3. Recorded-tender row actions match lifecycle: **Remove** (not externally processed), **Void** (externally processed while open), **Resolve void** (recovery), view-only when completed/voided.
4. Do not treat edit / delete / remove / void as interchangeable labels.
5. Optional focused **Add tender** modal may refine the active-form pattern; L3 method selector remains the base (not a stacked-form rebuild).

## Recovery — `void_required`

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ SHELFSTACK POS · Main Store · Register 2 · Alex · Session 104 · RECOVERY     │
├───────────────────────────────────────────────────┬──────────────────────────┤
│ CARD VOID VERIFICATION REQUIRED                   │ AFFECTED ACTIVITY        │
│                                                   │ Transaction #...         │
│ ShelfStack cannot safely continue until the       │ Card payment      $54.86 │
│ external terminal result is verified.             │ Card •••• 1234           │
│                                                   │ Auth/ref: ABC123          │
│ 1. Check the standalone terminal.                 │ Status: void required    │
│ 2. Determine whether the approved charge was      │                          │
│    successfully voided.                           │ Normal tender entry      │
│ 3. Select the matching result below.              │ unavailable              │
│                                                   │                          │
│ [Void confirmed] [Void failed / escalate]         │                          │
│ Authorization fields, when required               │                          │
├───────────────────────────────────────────────────┴──────────────────────────┤
│ Only closed-list permitted Recovery actions                                │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Recovery annotations

1. Recovery replaces the ordinary transaction/tender task.
2. The incident is described in operational language.
3. The affected amount and tender remain visible.
4. Unsafe controls are absent.
5. The primary permitted resolution receives focus.

## Receipt

Receipt may use a focused completion composition rather than the ordinary operational summary rail (POS-UI-022). `Next transaction` lives only in the completion action area (POS-UI-023).

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ SHELFSTACK POS · Main Store · Register 2 · Alex · Session 104 · RECEIPT      │
├──────────────────────────────────────────────────────────────────────────────┤
│ TRANSACTION COMPLETE                                                         │
│                                                                              │
│ Receipt 000184                                                               │
│ CHANGE DUE $5.14                                                             │
│                                                                              │
│ Cash · $60.00                                                                │
│ Customer: Pat Example · Final total $54.86 · Tendered $60.00                 │
│                                                                              │
│ [Next Transaction]                                                           │
│                                                                              │
│ Print status / customer copy                                                 │
├──────────────────────────────────────────────────────────────────────────────┤
│ [Print] [Reprint] [View detail] [More]                                       │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Receipt annotations

1. Completion, receipt number, change, and Next Transaction dominate the completion area.
2. Next Transaction receives focus after the completion announcement and is not repeated in the command bar.
3. Print, Reprint, View detail, linked return, and post-void remain secondary.
4. Full line/tender detail opens via View detail overlay (POS-UI-036).
5. Browser-print rendering uses a separate document layout.

## Product lookup overlay

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ PRODUCT LOOKUP                                                        [Close]│
├──────────────────────────────────────────────────────────────────────────────┤
│ Search ┌──────────────────────────────────────────────────────────┐           │
│        └──────────────────────────────────────────────────────────┘           │
│                                                                              │
│ ┌──────────────────────────────────────────────────────────────────────────┐ │
│ │ Title / Product       Variant  Format  Identifier  Price  Available     │ │
│ │ Example Book          New      HC      978...      $28.00       3       │ │
│ │ Example Book          Used     HC      SKU...      $12.00       1       │ │
│ │ Example Audiobook     New      CD      978...      $34.00       0       │ │
│ │                 bounded results scrolling                               │ │
│ └──────────────────────────────────────────────────────────────────────────┘ │
│ Quantity [1]                                            [Add selected]        │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Overlay annotations

- Rich lookup provides enough operational context for deliberate selection.
- The overlay does not create a transaction until Add succeeds.
- Close/Escape restores focus to the invoking control.
- Successful Add replaces the authoritative workspace and clears the overlay.

## Compact Customer overlay

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ CUSTOMER                                                            [Close] │
├──────────────────────────────────────────────────────────────────────────────┤
│ Search ┌──────────────────────────────────────────────────────────┐           │
│ Results: Pat Example · Customer 220000...                         [Use]       │
│          Patricia Example · Customer 220000...                    [Use]       │
│                                                                              │
│ No acceptable match? [Create customer]                                     │
│                                                                              │
│ Compact create fields appear here without leaving POS context               │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

# Phase 11.2 — Register workflow compositions

These frames support gates 11.2A–F. Ordinary forms must not show unused approval fields; approvals appear only after a server-side authority exception.

## Approval interrupt overlay

Reusable interrupt after `Pos::AuthorizeAction` returns requires-approval. Dims the workspace beneath; does not navigate away.

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ ... underlying Transaction / Tender / Ops workspace remains visible dimmed   │
│ ┌──────────────────────────────────────────────────────────────────────────┐ │
│ │ APPROVAL REQUIRED                                                 [Cancel]│ │
│ ├──────────────────────────────────────────────────────────────────────────┤ │
│ │ Action                                                                    │ │
│ │  Price override on “Example Book”                                        │ │
│ │                                                                          │ │
│ │ Boundary                                                                 │ │
│ │  Your authority limit for price override is $5.00                        │ │
│ │                                                                          │ │
│ │ Material values                                                          │ │
│ │  Current $18.00 → Requested $12.00 · Difference $6.00                    │ │
│ │                                                                          │ │
│ │ Effect if approved                                                       │ │
│ │  Line unit price becomes $12.00 for this transaction only                │ │
│ │                                                                          │ │
│ │ Approver username ┌──────────────────┐                                   │ │
│ │ Approver PIN      ┌──────────────────┐                                   │ │
│ │                                                                          │ │
│ │                                            [Approve and continue]        │ │
│ └──────────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Approval interrupt annotations

1. No approval fields on the ordinary form until ShelfStack detects the exception.
2. Prompt names the exact decision (line, tender, transaction, session, or business-day action).
3. Cancel returns focus to the invoking control without applying the change.
4. Approve resumes the original workflow; material changes invalidate the approval (re-prompt).
5. Same composition for discount, tax, no-receipt return, refund exception, cash variance, etc. — only body copy changes.

## Start Return chooser

Launched from Ready **Start return** or Transaction **Return** intent. Branches to linked or unlinked paths.

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ START RETURN                                                          [Close]│
├──────────────────────────────────────────────────────────────────────────────┤
│ How is this return starting?                                                 │
│                                                                              │
│ Receipt number                                                               │
│ ┌────────────────────────────────────┐ [Look up]                             │
│ └────────────────────────────────────┘                                       │
│                                                                              │
│ — or —                                                                       │
│                                                                              │
│ [ Begin unlinked return ]                                                    │
│                                                                              │
│ Unlinked returns require reason, disposition, and may require approval.      │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Start Return annotations

1. Valid receipt lookup proceeds automatically to the multi-line selector.
2. Unlinked path opens the guided step sequence (not one large form).
3. Close restores Ready or Transaction focus.

## Receipt-linked multi-line return selector

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ RETURN FROM RECEIPT 000184                                            [Close]│
├──────────────────────────────────────────────────────────────────────────────┤
│ Store · completed 2026-07-28 14:22 · Register 2 · Alex                       │
│                                                                              │
│ Defaults for selected lines                                                  │
│ Reason [Damaged            ▾]  Disposition [Return to stock ▾]               │
│                                                                              │
│ ┌──┬──────────────────────────┬────┬─────┬──────┬───────┬──────────────────┐ │
│ │☑ │ Description              │Sold│Prev │Left  │Return │ Price            │ │
│ ├──┼──────────────────────────┼────┼─────┼──────┼───────┼──────────────────┤ │
│ │☑ │ Example Book · New HC    │  1 │  0  │  1   │ [1]   │ $18.00           │ │
│ │  │ Reason/disp: use defaults · [Override]                                │ │
│ ├──┼──────────────────────────┼────┼─────┼──────┼───────┼──────────────────┤ │
│ │☐ │ Bookmark set             │  2 │  1  │  1   │ [1]   │ $4.00            │ │
│ │☑ │ Example Guide · PB       │  1 │  0  │  1   │ [1]   │ $12.00           │ │
│ └──┴──────────────────────────┴────┴─────┴──────┴───────┴──────────────────┘ │
│                                                                              │
│ Selected 2 lines · refund merchandise $30.00                                 │
│                                                          [Add to transaction]│
└──────────────────────────────────────────────────────────────────────────────┘
```

### Linked return selector annotations

1. Only returnable remaining quantity is selectable.
2. Historical price/tax/department/cost facts come from the original transaction — cashier does not re-enter them.
3. Shared reason/disposition defaults with per-line override.
4. Add posts through existing linked-return services (one or more lines); returns to Transaction.

## Unlinked return — guided steps

One overlay/workspace advances through steps. Progress is visible. Do not show the full field set at once.

### Step 1 — Identify

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ UNLINKED RETURN · Step 1 of 5 — Identify                              [Close]│
├──────────────────────────────────────────────────────────────────────────────┤
│ Scan / ISBN / SKU ┌────────────────────────────┐ [Find]                      │
│                   └────────────────────────────┘                             │
│ [ Product search ]                                                           │
│                                                                              │
│ Or: [ Open-ring return instead ]                                             │
│                                                                              │
│ Individually tracked unit scan permitted when policy allows.                 │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Step 2 — Confirm item

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ UNLINKED RETURN · Step 2 of 5 — Confirm item                    [Back][Close]│
├──────────────────────────────────────────────────────────────────────────────┤
│ Example Book                                                                 │
│ Variant: New · Hardcover · 978… · SKU…                                       │
│ Current selling price $18.00 · Available 3                                   │
│                                                                              │
│ [Use this item]                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Step 3 — Quantity and price

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ UNLINKED RETURN · Step 3 of 5 — Quantity & price                [Back][Close]│
├──────────────────────────────────────────────────────────────────────────────┤
│ Example Book · New HC                                                        │
│                                                                              │
│ Quantity ┌────┐                                                              │
│          └────┘                                                              │
│ Proposed refund unit price ┌──────────┐  (from return policy / current price)│
│                            └──────────┘                                      │
│                                                                              │
│                                                              [Continue]      │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Step 4 — Reason and disposition

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ UNLINKED RETURN · Step 4 of 5 — Reason & disposition            [Back][Close]│
├──────────────────────────────────────────────────────────────────────────────┤
│ Return reason      [Customer changed mind ▾]                                 │
│ Return disposition [Return to stock       ▾]                                 │
│                                                                              │
│                                                              [Continue]      │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Step 5 — Tax / policy review (then add)

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ UNLINKED RETURN · Step 5 of 5 — Review                          [Back][Close]│
├──────────────────────────────────────────────────────────────────────────────┤
│ Example Book · Qty 1 · Refund $18.00                                         │
│ Reason / disposition summarized                                              │
│ Tax treatment summary (policy proposal — not a second commercial record)     │
│                                                                              │
│ If inventory-affecting cost requires review → cost-review step (existing)    │
│ If authority exceeded → Approval interrupt (no fields shown here)            │
│                                                                              │
│                                                          [Add return line]   │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Open-ring return — department

When **Open-ring return** is chosen from Step 1, replace identify/confirm with:

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ OPEN-RING RETURN · Department                                     [Back]     │
├──────────────────────────────────────────────────────────────────────────────┤
│ Search department ┌────────────────────────────┐                             │
│                   └────────────────────────────┘                             │
│ 110 Books / New General Trade                                                │
│ 130 Books / Used & Collectible                                               │
│ ...                                                                          │
│ Description ┌──────────────────────────────────────────────┐                 │
│             └──────────────────────────────────────────────┘                 │
│ Then continue at Quantity & price → Reason → Review.                         │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Unlinked return annotations

1. Cost-review remains a separate confirm when the existing service requires it.
2. Approval interrupt appears only after Add fails authority — not as standing fields on every step.
3. Successful Add replaces the workspace and clears the overlay.

## Refund proposed plan overlay

Shown when entering Tender with a net refund, or via **Review / edit plan**. Proposed lines are not tenders until confirmed. Ordering is **stored-value first**.

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ PROPOSED REFUND PLAN                                                  [Close]│
├──────────────────────────────────────────────────────────────────────────────┤
│ Refund due $18.25                                                            │
│ Policy: restore original stored value before cash / card / new credit        │
│                                                                              │
│ ┌──────────────────────────────────────────────────────────────────────────┐ │
│ │ Destination              Capacity     Amount      Status                 │ │
│ │ Stored value (original)  $10.00       $10.00      Recommended            │ │
│ │ Cash                     —            $8.25       Recommended remainder  │ │
│ │ Card (original)          $40.00       $0.00       Available              │ │
│ └──────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│ [Remove row] [Adjust amount] [Add permitted destination]                     │
│ Deviation from recommendation may require Approval interrupt.                │
│                                                                              │
│                                              [Accept plan and record]        │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Refund plan annotations

1. Accept records tenders through existing services under `RefundAllocationPolicy`.
2. Cash-first draft ordering is not shown; SV-first is locked.
3. Check-funded remainder defaults to new store credit after original-tender / SV allocations (OD-P11-01 accepted); cash needs refund-exception approval — [phase-11.4-check-refund-treatment.md](../../implementation/decisions/phase-11.4-check-refund-treatment.md).

## Recorded-tender detail overlay

Selecting a recorded tender opens lifecycle-correct actions (Phase 11.2C).

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ TENDER DETAIL                                                         [Close]│
├──────────────────────────────────────────────────────────────────────────────┤
│ Cash · payment · $20.00 · entered                                            │
│                                                                              │
│ Permitted for this state:                                                    │
│  [Edit amount]  [Remove]                                                     │
│                                                                              │
│ Not shown here: Void (no external processing) · Delete (forbidden term)      │
└──────────────────────────────────────────────────────────────────────────────┘
```

Alternate states (same chrome, different actions):

```text
Card · payment · $34.86 · authorized (external)
[Void on terminal / Void confirmed] [Replace after void]

Card · payment · $34.86 · void_required
[Resolve void]  → Recovery

Completed transaction tender
View only — correct via return / post-void
```

---

# Phase 11.3 — Operations workspace compositions

Operations is a sibling of Register inside the focused POS environment. **Store Workspace** is the return label to normal ShelfStack — not a persistent rename of the back-office app.

## Operations navigation chrome

Header gains explicit workspace switches. Shared operating context stays visible.

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ SHELFSTACK POS · Main Store · Reg 2 · Drawer A · Alex · Day 2026-07-28 · OPEN│
│ [Register] [Operations]                              [Store Workspace]       │
├──────────────────────────────────────────────────────────────────────────────┤
│ Ops scope: ( Register Operations | Store Operations )                        │
│ Session 104 · Device Reg 2 · Drawer A · Txn: none open                       │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Navigation annotations

1. Moving Register ↔ Operations preserves store, day, session, device, drawer, user.
2. **Store Workspace** exits the focused POS shell to normal ShelfStack with store context.
3. Open-transaction rules (OD-P11-03 accepted): active txn stays in Register; leave only after complete / explicit suspend / explicit cancel — interruption offers Suspend, Cancel, or Return; never silent abandon — [phase-11.3-operations-workspace-boundaries.md](../../implementation/decisions/phase-11.3-operations-workspace-boundaries.md).

## Register Operations

Current session, device, and drawer only — not all-store tables.

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ SHELFSTACK POS · … · OPERATIONS · Register                                    │
│ [Register] [Operations]                              [Store Workspace]       │
├───────────────────────────────────────────────────┬──────────────────────────┤
│ REGISTER OPERATIONS                               │ THIS SESSION             │
│                                                   │ Session 104 · Open       │
│ Session                                           │ Device Reg 2 · Drawer A  │
│  Opened 09:02 · Cashier Alex                      │ Opening cash     $150.00 │
│  [Close Session]                                  │ Expected cash      …     │
│                                                   │                          │
│ Quick actions                                     │ CLOSE / BLOCKERS         │
│  [Cash Movement] [No Sale]                        │ (none) or list           │
│                                                   │                          │
│ Reports                                           │ [Session X]              │
│  [Session X] [Session Z / close report]           │                          │
│                                                   │                          │
│ History (this session)                            │                          │
│  Cash movements / no-sale list (scroll)           │                          │
│  …                                                │                          │
├───────────────────────────────────────────────────┴──────────────────────────┤
│ Context preserved · open txn rules apply if a transaction is active          │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Register Operations annotations

1. Quick actions vs history (OD-P11-02 accepted): Cash Movement / No Sale remain on Register Ready; authoritative current-session history lives here.
2. Close Session is first-level (POS-UI-037), not buried under reports.
3. Session X/Z appear only in this scope.

## Store Operations

Business day and all store sessions — not the current drawer’s private quick-action strip alone.

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ SHELFSTACK POS · … · OPERATIONS · Store                                       │
│ [Register] [Operations]                              [Store Workspace]       │
├───────────────────────────────────────────────────┬──────────────────────────┤
│ STORE OPERATIONS                                  │ BUSINESS DAY             │
│                                                   │ 2026-07-28 · Open        │
│ Business day                                      │ Sessions open: 2         │
│  [Close Business Day]                             │                          │
│                                                   │ DAY BLOCKERS             │
│ All sessions                                      │ Session 105 still open   │
│  Reg 1 · Sess 103 · Closed · Z…                   │                          │
│  Reg 2 · Sess 104 · Open  · Alex                  │ [Day X]                  │
│  Reg 3 · Sess 105 · Open  · Sam                   │                          │
│                                                   │ Reconciliation           │
│ Reports                                           │ Status: pending          │
│  [Day X] [Day Z / close report]                   │ [Open reconciliation] →  │
│                                                   │   ShelfStack (not embed) │
├───────────────────────────────────────────────────┴──────────────────────────┤
│ Permissions gate which sessions/reports/actions are visible                  │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Store Operations annotations

1. Current-session and store-wide controls are not mixed without hierarchy (scope tabs or clear sections).
2. Reconciliation (OD-P11-04 accepted): status, blockers, and permission-gated links only; full workflow remains normal ShelfStack Reporting and Reconciliation.
3. Day close blockers are visible and actionable.

## Open-transaction navigation (blocked example)

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ Cannot open Store Workspace while a transaction is open                      │
│                                                                              │
│ Transaction has 3 lines · tender not started                                 │
│                                                                              │
│ [Suspend and continue] [Cancel and continue] [Return to Register]            │
└──────────────────────────────────────────────────────────────────────────────┘
```

Allow/deny follows OD-P11-03 ([decision note](../../implementation/decisions/phase-11.3-operations-workspace-boundaries.md)); this frame establishes the interruption pattern. Labels: Suspend and continue / Cancel and continue / Return to Register.

---

## Review notes

When refining these wireframes, annotate changes with decision IDs from [decisions.md](decisions.md). Do not replace this file with screenshots alone; screenshots show an implementation, while the wireframes preserve hierarchy and intent.

Phase 11.4 does not add a new wireframe set; update frames here only when hardening discovers a hierarchy gap.
