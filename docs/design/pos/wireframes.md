# POS annotated wireframes

**Status:** Draft composition reference  
**Parent:** [README.md](README.md)  
**Visual contract:** [visual-contract.md](visual-contract.md)  
**Decisions:** [decisions.md](decisions.md)

## Purpose

These wireframes define information hierarchy and stable region placement before production markup is refactored.

They are intentionally low fidelity. Typography, color, and exact spacing remain implementation details until reviewed through deterministic screenshots. The wireframes do not redefine server behavior.

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

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ SHELFSTACK POS · Main Store · Register 2 · Alex · Session 104 · READY        │
├───────────────────────────────────────────────────┬──────────────────────────┤
│ START CUSTOMER WORK                               │ NEXT TRANSACTION CONTEXT │
│                                                   │                          │
│ [ Sale ] [ Return ] [ Stored Value ] [ Open Ring ]│ Customer                │
│                                                   │  No customer staged      │
│ Scan / ISBN / SKU                                 │  [Find customer]         │
│ ┌────────────────────────────────────┐ [Qty] [Add] │                          │
│ │                                    │             │ Suspended work          │
│ └────────────────────────────────────┘             │  2 transactions [View]  │
│                                                   │                          │
│ [Product lookup] [Receipt lookup] [Pickup lookup] │ Session                  │
│                                                   │  Drawer open             │
│ Recent status/warning area                        │  Cash enabled            │
├───────────────────────────────────────────────────┴──────────────────────────┤
│ [Cash Movement] [No Sale] [Session X] [Close Session]   [Store Operations] │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Ready annotations

1. Scan-to-start is the dominant control and initial focus.
2. Work intents are visible without opening disclosures.
3. Customer, suspended work, and session context remain compact.
4. Product, Receipt, and pickup lookups launch overlays.
5. Detailed business-day/session tables and cash history are not part of this screen.
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
│ [Qty] [Remove] [Discount] [Override]       [Suspend] [Cancel] [More]       │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Transaction annotations

1. Entry and lines dominate the screen.
2. The line collection is the only ordinary scrolling region.
3. Customer, totals, readiness, and progression remain visible.
4. The selected line drives the command bar.
5. Complex line actions open overlays while preserving the selected line.
6. Tender forms do not appear expanded in Transaction.
7. Sale and return lines are distinguishable without relying on color alone.

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
│ [Return to Transaction]                              [Complete disabled]     │
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
│ [Return to Transaction, only when safe]               [Complete Transaction]│
└──────────────────────────────────────────────────────────────────────────────┘
```

### Tender annotations

1. Tender controls occupy the primary region.
2. Amount due/refundable and remaining balance are visually dominant.
3. Recorded tenders remain visible during split settlement.
4. Commercial line editing is absent.
5. Return to Transaction is absent when unresolved activity forces Tender.
6. Complete Transaction remains visible when settled.

## Tender — net refund

Use the same composition, but replace payment language consistently:

```text
Refund due $18.25
[Cash refund] [Card refund] [Store Credit]
Refunded $10.00
REMAINING REFUND $8.25
[Add refund $8.25]
```

Do not rely only on negative-number notation to communicate direction.

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

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ SHELFSTACK POS · Main Store · Register 2 · Alex · Session 104 · RECEIPT      │
├───────────────────────────────────────────────────┬──────────────────────────┤
│ TRANSACTION COMPLETE                              │ FINAL SUMMARY            │
│                                                   │ Customer: Pat Example    │
│ Receipt 000184                                    │ Final total       $54.86 │
│                                                   │ Tendered          $60.00 │
│ CHANGE DUE $5.14                                  │ Change due         $5.14 │
│                                                   │                          │
│ Cash · $60.00                                     │ Receipt ready            │
│                                                   │                          │
│ Print status / customer copy                      │ [Next Transaction]       │
│                                                   │                          │
│ [Print Receipt] [Reprint]                         │                          │
├───────────────────────────────────────────────────┴──────────────────────────┤
│ [Next Transaction]           [Linked Return] [Post-void] [Transaction Detail]│
└──────────────────────────────────────────────────────────────────────────────┘
```

### Receipt annotations

1. Completion, receipt number, change, Print, and Next Transaction dominate.
2. Next Transaction receives focus after the completion announcement.
3. Correction and history actions remain secondary.
4. Detailed lines do not obscure completion.
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

## Review notes

When refining these wireframes, annotate changes with decision IDs from [decisions.md](decisions.md). Do not replace this file with screenshots alone; screenshots show an implementation, while the wireframes preserve hierarchy and intent.
