# POS review scenarios

**Status:** Draft visual and workflow acceptance procedure  
**Parent:** [README.md](README.md)  
**Presentation inventory:** [presentation-matrix.md](presentation-matrix.md)  
**Screenshot requirements:** [screenshots/README.md](screenshots/README.md)

## Purpose

These scenarios test the POS as a cashier workflow rather than as a collection of pages or controller actions.

Run them first against annotated wireframes or a prototype, then against the implementation. Record where focus lands, what remains visible, what scrolls, and whether the next action is apparent without explanation from the reviewer.

## Review method

For every step, record:

- current presentation;
- focused control;
- visually dominant control or amount;
- primary action shown;
- whether totals remain visible;
- whether document scrolling occurs;
- whether an overlay opens;
- whether the cashier leaves the POS shell;
- warnings, blockers, or approvals shown;
- unexpected search or hesitation.

Use these ratings:

- **Accepted** — task is clear and contract is satisfied;
- **Needs refinement** — task is possible but hierarchy or continuity is weak;
- **Fail** — workflow, safety, focus, or viewport contract is broken.

A failure in financial safety, task clarity, keyboard continuity, or supported viewport behavior blocks acceptance.

## Environment

Run each applicable scenario at:

- 1366 × 768;
- 1024 × 768.

Use deterministic fixtures or seed data. Disable browser zoom changes and record the browser and operating system used for screenshots.

## Scenario 1 — Fast ordinary sale

### Setup

- open business day;
- open cash-enabled session;
- no staged Customer;
- no active transaction;
- eight resolvable quantity-tracked products.

### Steps and expectations

1. Open Register.
   - Presentation: Ready.
   - Scan field has focus.
   - Store, register, cashier, and session are identifiable.
   - Scan-to-start is visually dominant.

2. Scan the first product.
   - Transaction opens atomically with one line.
   - No empty transaction is visible first.
   - Scan field regains focus.
   - Line, totals, and sign-aware progression are visible.

3. Scan seven additional products.
   - Eight lines remain visible where practical at 1366 × 768.
   - No document-level scroll is required.
   - Totals and primary action remain visible.

4. Select the fourth line.
   - Selected state is obvious and keyboard-accessible.
   - Selected-line commands appear in their stable location.

5. Change its quantity.
   - Updated quantity, line total, transaction totals, and readiness arrive as one coherent server state.
   - Focus returns to scan unless a required task remains.

6. Remove the selected line.
   - Ordinary removal does not require unnecessary confirmation.
   - Selection and focus move predictably.

7. Begin Tender.
   - Tender becomes the primary composition.
   - Commercial lines are read-only and subordinate.
   - Amount due and tender method are dominant.

8. Enter cash sufficient to complete.
   - Cash presented and change due are unambiguous.
   - Recorded tender and settled state are visible.

9. Complete transaction.
   - Duplicate submission UI is prevented.
   - Receipt presentation replaces Tender.
   - Completion and receipt number are announced.

10. Review Receipt.
    - Change due, Print, and Next Transaction are visually dominant.
    - Next Transaction has focus after the announcement.

11. Press Enter.
    - Returns to Ready without opening an empty transaction.
    - Scan field becomes the default focus target.

### Blocking failures

- whole-page scrolling during the eight-line transaction;
- totals or Tender CTA scroll out of view;
- Tender is merely the former summary sidebar expanded;
- focus is lost after scan or completion;
- Next Transaction is visually weaker than correction actions.

## Scenario 2 — Product lookup from Ready

### Setup

- normal Ready;
- search term with multiple Product Variants.

### Steps

1. Open Product lookup from Ready.
2. Verify a bounded POS-native overlay opens.
3. Search by title.
4. Compare variants using title, format, identifier, price, availability, and tracking context as applicable.
5. Select one variant deliberately.
6. Set quantity and add.
7. Verify the transaction opens with the selected line.
8. Verify the overlay closes and scan focus is restored.

### Blocking failures

- navigating to a general Product index or detail page;
- Product selection without enough operational context;
- ambiguous search automatically opening an empty transaction;
- focus remaining in a removed overlay.

## Scenario 3 — Customer lookup and compact creation

### Existing Customer

1. From Ready, open Customer lookup.
2. Search by name, number, email, or phone as permitted.
3. Select Customer for the next transaction.
4. Verify Ready shows a compact staged Customer summary.
5. Scan first item.
6. Verify only the staging user consumes the staged Customer according to server rules.

### New Customer

1. Open Customer lookup.
2. Confirm no acceptable match.
3. Open compact creation within the POS overlay.
4. Enter the minimum required Customer facts.
5. Create and stage/attach the Customer.
6. Verify the POS workspace returns without navigating to the general Customer form.
7. Verify focus returns to the next cashier task.

### Blocking failures

- leaving the POS shell for the ordinary create path;
- Customer form dominating Ready;
- losing the active transaction or staged context;
- duplicate creation encouraged without search context.

## Scenario 4 — Long transaction and line commands

### Setup

- twenty ordinary sale lines;
- one long title;
- one discount;
- one warning;
- one individually tracked line.

### Steps

1. Open the twenty-line transaction.
2. Verify only the line region scrolls.
3. Move through lines using keyboard controls.
4. Verify selected line remains visible.
5. Open selected-line commands.
6. Apply a discount requiring a reason.
7. Open an override requiring authorization.
8. Cancel the approval prompt.
9. Verify focus returns to the affected line/action.
10. Resolve the individually tracked unit.

### Blocking failures

- summary and primary CTA scroll away;
- every line permanently displays a large action set;
- warnings make row height uncontrolled;
- selected-line actions appear in inconsistent locations;
- modal close returns focus to the document body.

## Scenario 5 — Linked return and mixed transaction

### Setup

- completed original sale with eligible lines;
- one returnable quantity-tracked line;
- one new product to sell.

### Steps

1. From Ready, choose Return.
2. Open Receipt lookup.
3. Resolve the original receipt.
4. Select eligible original line and quantity.
5. Choose or confirm return reason and disposition.
6. Add return line.
7. Switch to Sale intent.
8. Scan a new product.
9. Verify sale and return rows are visually distinguishable.
10. Verify totals show the net transaction and taxes separately as applicable.
11. Begin sign-aware settlement.

### Blocking failures

- return workflow requires a separate transaction when mixed activity is allowed;
- original-line context is lost;
- disposition blocker is not associated with the return line;
- net refund/payment direction is unclear.

## Scenario 6 — Split tender

### Setup

- positive transaction total;
- cash and standalone card available.

### Steps

1. Enter Tender.
2. Record partial cash.
3. Verify recorded cash and remaining balance update together.
4. Select Card.
5. Enter the remaining amount.
6. Confirm approval using permitted metadata only.
7. Verify settled state.
8. Complete transaction.
9. Verify Receipt displays the split tender summary.

### Blocking failures

- recorded tenders are hidden while entering the next tender;
- remaining balance is not dominant;
- full card data is requested;
- Complete Transaction appears enabled before settlement;
- commercial editing is available while unresolved tender activity forces Tender.

## Scenario 7 — Net refund

### Setup

- return value exceeds new sale value;
- permitted refund tender methods.

### Steps

1. Build mixed transaction with a negative net total.
2. Verify Transaction primary action reads `Issue refund $X`.
3. Enter Tender.
4. Verify refund direction is explicit throughout the presentation.
5. Record refund tender.
6. Complete and review refund Receipt wording.

### Blocking failures

- payment language used for a refund;
- negative values relied on without a plain-language direction;
- refund method validation hidden until completion.

## Scenario 8 — Stored Value

### Issuance or reload

1. Select Stored Value intent.
2. Open the bounded issue/reload task.
3. Resolve existing account or create one when authorized.
4. Enter amount and add liability line.
5. Verify line and totals use Stored Value terminology correctly.

### Redemption

1. Enter Tender for a positive sale.
2. Select Stored Value tender.
3. Resolve account.
4. Enter redemption amount.
5. Verify remaining balance and liability treatment.

### Blocking failures

- issuance presented as merchandise revenue;
- redemption presented as a discount;
- account search exposes unauthorized balance information;
- issue/reload and redemption controls are combined ambiguously.

## Scenario 9 — Recovery: `void_required`

### Setup

- open transaction with a persisted tender requiring external void verification.

### Steps

1. Load the transaction.
2. Verify Recovery is derived automatically.
3. Verify the incident occupies the primary workspace.
4. Read the affected tender, amount, and masked external reference.
5. Follow numbered verification steps.
6. Verify only closed-list permitted resolution actions appear.
7. Choose a permitted result.
8. Verify the server determines the next valid presentation.

### Blocking failures

- normal tender entry remains available;
- Cancel Transaction is offered as a bypass;
- Recovery appears only as a banner above ordinary Tender controls;
- resolution options are inferred from flash text;
- unsafe actions are merely visually muted rather than absent.

## Scenario 10 — Receipt and correction discoverability

### Setup

- completed transaction eligible for linked return and post-void by authorized user.

### Steps

1. Open Receipt immediately after completion.
2. Verify Next Transaction and Print dominate.
3. Verify linked return and post-void remain discoverable but secondary.
4. Open printable receipt and verify interactive shell is absent.
5. Reprint and verify original receipt number is preserved and marked REPRINT.

### Blocking failures

- correction actions compete with Next Transaction;
- printable receipt includes register controls;
- reprint consumes a new receipt number;
- transaction detail is expanded so heavily that completion is obscured.

## Scenario 11 — Ready session utilities

### Steps

1. From Ready, identify staged Customer and session status without opening a disclosure.
2. Open Cash Movement.
3. Cancel and verify scan focus restores.
4. Open Session X.
5. Return to Ready.
6. Verify detailed day/session tables and cash history are not part of the normal Ready document flow.

### Blocking failures

- routine Ready requires scrolling past operational tables;
- cash movement form is permanently expanded;
- sensitive totals appear in the Ready summary without requirement;
- returning from utility loses the active register context.

## Review report template

```markdown
## Scenario

- ID:
- Viewport:
- Browser/OS:
- Build/commit:
- Fixture/seed:

### Result

- Status: Accepted | Needs refinement | Fail
- Initial focus:
- Dominant task/control:
- Document scrolling:
- Internal scrolling:
- Overlay behavior:
- Primary action visibility:
- Keyboard continuity:

### Findings

1.
2.

### Required changes

1.
2.

### Evidence

- Screenshot(s):
- Recording, if used:
```

## Completion criteria

The review package is complete when:

- all mandatory scenarios have been run at both supported viewports;
- blocking failures are resolved;
- accepted screenshots are stored or attached;
- accepted decisions are recorded in [decisions.md](decisions.md);
- component implementation is reviewed only after the visual workflow passes.
