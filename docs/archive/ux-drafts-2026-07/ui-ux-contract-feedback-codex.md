## Review: docs/temp\_draft fit for ShelfStack

Overall, the draft is visually promising and directionally compatible with ShelfStack’s goals, especially for a fast, barcode-oriented retail workflow. ShelfStack explicitly wants routine bookstore activity to be practical, fast, and barcode-oriented, while keeping strong controls around money, inventory, tax, customer commitments, stored value, authorization, and historical reporting. 

That said, I would treat the current docs/temp\_draft material as a concept mockup, not as a governing UX/API contract yet. Several parts fit very well; several others conflict with ShelfStack’s accepted architecture or over-specify unresolved workflow details.

---

## What fits well

### 1\. The visual direction feels appropriate for ShelfStack

The palette and component system in the mockup are restrained, operational, and credible for a bookstore back-office/POS application. The static mockup includes a dashboard, product detail page, POS page, component reference, shared CSS, and SVG icon, and it is intentionally self-contained with no external assets or package installation. 

The design tokens are also a good starting point: primary teal, secondary plum, ochre accent, neutral surfaces, semantic alert colors, and clear typography choices. 

I would keep:

* the teal/plum/ochre brand family;  
* separate semantic colors for info/success/warning/danger;  
* the card/table/form visual language;  
* the POS-specific visual density;  
* the static HTML mockup format for quick review.

### 2\. The POS layout matches ShelfStack’s POS-forward roadmap

The roadmap prioritizes a real inventory-aware POS path before full purchasing and product-request workflows: opening inventory adjustment → reservation → atomic POS completion → inventory movement, cost snapshot, and receipt number. 

The POS mockup is aligned with that direction: it centers scan entry, transaction lines, balance due, tenders, session context, cashier, drawer/register, and keyboard actions. 

That is the right general screen priority for Phase 4\.

### 3\. The mockup respects several core domain concepts

The product record mockup shows inventory by store with on hand, reserved, unavailable, and available, which maps directly to ShelfStack’s established inventory formula. 

The POS mockup also recognizes:

* stored-value issuance as non-revenue.   
* card, cash, gift card, and store credit as tenders.   
* session/store/register/drawer/cashier context. 

Those are good fits with ShelfStack’s domain model, where POS owns transactions, tenders, cash controls, receipts, and corrections, while stored value owns gift cards/store credit/trade credit and immutable ledger activity. 

---

## Main concerns

### 1\. The draft calls itself an “official UX contract,” but it should not be governing yet

ui-style-guide-ux-contract.md says it “establishes the official user experience contract” and that all future implementations “must comply” with it. 

I would change that immediately before promoting it. This repository’s actual governing documents are ADRs, domain specifications, schema documentation, workflow documentation, and the roadmap. The ADR README says accepted ADRs are authoritative and govern affected domain specs, schemas, workflows, and implementation. 

Recommended replacement positioning:

“This is a draft visual and interaction proposal for review. It is not authoritative unless promoted into the appropriate design, workflow, or implementation documentation.”

### 2\. “Display category” conflicts with accepted classification architecture

The product record mockup includes a “Display category” field. 

That is the biggest architecture mismatch. ShelfStack explicitly uses one hierarchical merchandise-class structure for shelving, browsing, merchandising, buyer organization, category reporting, and default department resolution.  The ADR summary also says the former separate display-category hierarchy is not retained. 

I would change the product page language from:

* Display category

to one of:

* Merchandise class  
* Merchandise class path  
* Class  
* Shelving / merchandise class

Example:

```
Department: Books
Merchandise class: Books › Nonfiction › Nature & Environment
```

This preserves the useful UI idea without reintroducing a prohibited domain concept.

### 3\. The POS “transaction state API contract” is not ShelfStack-safe

The style guide proposes a client-side JSON transaction contract using floating-point money values like 20.00, 4.50, and 71.07. 

That does not fit ShelfStack’s money conventions. Monetary amounts should be integer cents, not floats. The shared domain conventions say money uses integer cents and rates need fixed precision. 

I would replace the JSON example with cents-based fields:

```
{
  "transaction_id": "00018452",
  "store_id": "...",
  "pos_session_id": "...",
  "cart_lines": [
    {
      "line_index": 1,
      "product_variant_id": "...",
      "quantity": 1,
      "unit_price_cents": 2000,
      "unit_discount_cents": 0,
      "line_total_cents": 2000
    }
  ],
  "financial_summary": {
    "subtotal_cents": 6959,
    "discount_cents": 380,
    "tax_cents": 148,
    "balance_due_cents": 7107
  }
}
```

Also, I would avoid calling this a final API contract until the POS workflow/API design is implemented.

### 4\. Tax logic based on item text is explicitly wrong for ShelfStack

The draft says tax algorithms should inspect metadata titles and treat strings containing “Coffee” as taxable. 

That should be removed. ShelfStack has a Classification and Configuration domain that owns tax categories and rules.  Product/variant and department-derived defaults are supposed to drive classification and policy, not string matching. 

The mockup can show café as taxable, but the documentation should say:

* taxable status is resolved from configured tax category/rules;  
* completed POS lines snapshot tax results;  
* UI labels are display outputs, not the calculation source.

### 5\. The POS JavaScript is useful as a demo but should not imply business logic

The POS mockup recalculates totals in browser JavaScript using Number, calculates tax only for item names containing “Coffee,” and generates random demo SKUs. 

That is fine for a static demo, but not for ShelfStack implementation guidance. ShelfStack POS completion is supposed to be atomic and idempotent; inventory, tender, tax, stored value, cost, receipt number, and transaction completion commit together or not at all. 

I would add a warning banner at the top of the mockup README and style-guide:

“Demo-only JavaScript. Not authoritative for pricing, tax, tender posting, inventory reservation, receipt numbering, stored value, or transaction completion.”

### 6\. “Ctrl+Enter bypasses secondary validation” is not acceptable wording

The style guide says Ctrl+Enter “bypasses secondary validation” to complete operations when outstanding balances equal zero. 

For ShelfStack, completion must never bypass validation. The shortcut can invoke completion, but the server-side workflow still needs to enforce:

* transaction state;  
* line validity;  
* sale eligibility;  
* inventory reservation/conversion;  
* tax calculation;  
* tender sufficiency;  
* stored-value ledger effects;  
* receipt-number assignment;  
* idempotency.

I would change the wording to:

“Ctrl+Enter requests completion when the UI believes all tenders are resolved; the server-side completion service remains authoritative and may reject the request.”

### 7\. Return mode and suspended transactions need careful wording

The POS mockup has return mode and suspend controls.  The script says return mode makes scanned items “added as returns,” and F8 says the transaction is suspended with inventory reservations retained. 

Those concepts are plausible, but ShelfStack has strong rules:

* completed sale lines are immutable;  
* returns create new return lines;  
* corrections use linked records;  
* reservations commit physically present inventory, not future supply. 

I would keep the UI affordances but rewrite the mockup labels to avoid implying unresolved behavior:

* Return mode → Add return line  
* Suspend → Suspend transaction  
* message → “Demo: suspension would preserve any valid physical-inventory reservations according to the POS service.”

### 8\. PWA recommendation is premature

The keyboard/barcode document recommends a hybrid installed standalone PWA plus context-aware hotkeys. 

That may be a good future lane deployment option, but ShelfStack’s stack currently uses Rails, Propshaft, Importmap, Turbo, and Stimulus, and explicitly says not to introduce Node/npm/Yarn/bundlers for ordinary frontend behavior. The draft’s PWA idea does not inherently require Node, but making it an implementation recommendation is premature without an architectural decision. The UI draft should frame it as:

* “possible deployment option for dedicated registers,” not  
* “the recommended architecture.”

I would also avoid relying on a YouTube implementation guide as an architectural reference. The content can remain as exploratory research, but governing docs should cite internal decisions and standards rather than tutorial videos. 

---

## Specific changes I would make

### High-priority changes before adoption

1. Rename the style guide from contract to draft.  
   Change title/intro from “official UX contract” to “draft UI style guide and interaction proposal.”   
2. Remove “Display category.”  
   Replace it with “Merchandise class” or “Merchandise class path.”   
3. Remove float money from the API example.  
   Use integer cents everywhere.   
4. Remove text-based tax calculation.  
   Replace the “Coffee” string rule with tax-category/rule resolution from configuration.   
5. Reword Ctrl+Enter.  
   It should request completion, not bypass validation.   
6. Mark the POS JavaScript as demo-only.  
   The mockup’s client-side calculations and demo insertion logic should not be interpreted as implementation guidance.   
7. Move API/business workflow material out of the visual style guide.  
   UI style should live separately from POS completion workflow/service contracts.

---

## Medium-priority improvements

### 1\. Improve terminology

I would adjust labels across the mockup:

| Current label | Better ShelfStack label |
| ----- | ----- |
| Display category | Merchandise class |
| Create demand | Create product request |
| Demand | Requests / demand |
| Register | POS device, if that is the intended entity |
| Cashier | User / cashier |
| Price level | Price context or pricing rule, unless “price level” becomes accepted terminology |
| Tax: Standard | Tax context / tax profile, resolved from configuration |
| Add to live PO | Add to purchase order / buyer review, depending on workflow |

The domain docs distinguish Product Requests, Purchase Orders, Purchase-Order Allocations, Inventory Reservations, Receipts, and Inventory. The UI should avoid flattening those into generic “demand” or “live PO” language unless the workflow is clear. 

### 2\. Strengthen store context

The POS header correctly shows store, register/drawer, and cashier.  I would extend that pattern into back-office screens where inventory or operational actions are store-scoped. Store-level inventory is a core invariant. 

### 3\. Add accessibility requirements

The component system has decent semantic HTML in places, but the style guide should explicitly include:

* visible focus requirement;  
* minimum contrast targets;  
* keyboard navigation rules;  
* modal/focus-trap behavior;  
* ARIA guidance for badges and alerts;  
* scanner input behavior that does not break assistive technology.

One concern: the CSS removes outlines globally and replaces focus with box-shadow.  That can work, but the design guide should state that replacement focus indicators must remain visible in forced-colors/high-contrast environments.

### 4\. Make hotkeys progressive, not mandatory

The hotkey list is useful, but browser/platform conflicts are real. The keyboard document itself notes conflicts around F3, F5, F7, Delete, and Ctrl+Enter. 

I would define:

* preferred hotkeys for dedicated registers;  
* alternate hotkeys for browser use;  
* all actions reachable by visible controls;  
* no destructive action solely triggered by a single accidental keypress.

### 5\. Align the dashboard with current phase reality

The dashboard shows purchasing, receiving, demand, inventory alerts, department performance, and audit log activity. 

That is fine as a future-state mockup, but roadmap-wise Phase 4 POS is not started and Phases 5–7 remain future work.  I would label the dashboard as future operational dashboard or split it into:

* Phase 4 dashboard;  
* future-state dashboard.

---

## What I would keep almost as-is

* The static, self-contained mockup approach. It is easy to review and does not add build complexity.   
* The brand palette and semantic token structure.   
* The POS two-panel layout with scan/cart on the left and total/tender on the right.   
* The inventory-by-store table using on-hand/reserved/unavailable/available.   
* The stored-value-as-tender/non-revenue concept in the POS mockup.   
* The dedicated scan input pattern, with Enter processing and immediate input clearing, as a UI interaction idea. 

---

## Recommended target structure

If this draft is promoted, I would reorganize it like this:

```
docs/design/
  README.md
  visual-style-guide.md
  interaction-patterns.md
  accessibility.md
  pos-register-ui.md
  scanner-and-hotkeys.md

docs/workflows/
  pos-completion.md
  suspended-transaction.md
  quantity-tracked-sale.md

docs/temp_draft/
  ui_mockup/
    ...
```

Where:

* visual-style-guide.md owns colors, typography, components.  
* interaction-patterns.md owns UI behaviors like focus, forms, validation display.  
* pos-register-ui.md owns POS screen layout and cashier interaction principles.  
* scanner-and-hotkeys.md owns scanner/hotkey research, clearly marked as implementation guidance rather than domain architecture.  
* workflow/API/service contracts stay in docs/workflows/ or implementation docs, not the visual style guide.

---

## Bottom line

The mockup fits ShelfStack well as a visual/interaction prototype, especially the POS layout and component language. It does not yet fit as an authoritative contract because it currently:

* reintroduces “display category,” which conflicts with accepted classification architecture;  
* uses floating-point money in a proposed transaction contract;  
* proposes tax logic based on item names;  
* implies client-side calculations/state are authoritative;  
* says a shortcut can bypass validation;  
* makes PWA/hotkey choices sound settled before they are.

I would keep the visual design, POS density, scanner-first interaction model, and component palette, but rewrite the draft so it supports ShelfStack’s architecture rather than accidentally defining new architecture.
