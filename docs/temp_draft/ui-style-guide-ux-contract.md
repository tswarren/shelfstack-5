# **ShelfStack UI Style Guide & UX Contract**

This document establishes the official user experience contract and interface specifications for **ShelfStack**, governing both the back-office inventory control system and the dedicated point-of-sale (POS) workspace. All future feature implementations must comply with these design tokens, component rules, and layout structures to maintain platform integrity.

## **1\. Core Design Tokens**

### **Color Architecture**

The system utilizes a multi-tiered color model strictly enforced via CSS custom variables to separate semantic meaning from presentation layer shifts.

| Category | Token Name | Hex Value / CSS Definition | Applied Context |
| :---- | :---- | :---- | :---- |
| **Brand** | \--brand-primary  \--brand-secondary  \--brand-accent | \#09595f  \#66153e  \#c77c00 | Core UI identity, main links, active states. Secondary branding actions, specific tag definitions. Limited ochre accents for warning callouts and specific badges. |
| **Surfaces** | \--bg-100  \--bg-200  \--surface-primary  \--surface-selected | \#f8fafa  \#eef3f3  \#ffffff  \#e4f1f2 | Global canvas background. Sidebars, container fills, tables headers. Content cards, dynamic panels. Table rows or items marked as selected/active. |
| **Typography** | \--text-primary  \--text-secondary  \--text-muted | \#0b1c2e  \#465663  \#5f6f79 | Headers, form labels, crucial records. Secondary descriptions, nav links, data metrics. Subtitles, helper captions, timestamp hints. |

### **Typography Stack**

* **Font Family:** Inter, ui-sans-serif, system-ui, \-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif.  
* **Scale Elements:**  
  * h1: Fluidly bound between 1.65rem and 2.15rem via browser clamping, with a line height of 1.15 and bottom margin of 0.25rem.  
  * h2: Set at 1.18rem with an explicit 0.8rem bottom margin.  
  * h3: Base tracking level at 1rem and a 0.45rem bottom margin.  
* **Font Weights:** Fine-tuned explicitly to maximize typography contrast across digital screens: 560 (Nav items), 650 (Metric labels/Tabs), 670 (Buttons/Labels), 680 (Wordmarks), 720 (Badges/POS Totals), 750 (Eyebrows), and 760 (Metric Values).

### **Layout & Border Modifiers**

* **Header Height:** Fixed at 68px.  
* **Sidebar Width:** Fixed at 248px.  
* **Radii Standard:** Small 6px (for interior input elements), Medium 10px (standard container cards), Large 14px (outermost structural panels).  
* **Elevation:** Light borders are paired with soft shadows (\--shadow-sm: 0 1px 2px rgb(11 28 46 / 7%), 0 1px 6px rgb(11 28 46 / 4%)). High prominence sections use \--shadow-md (0 8px 24px rgb(11 28 46 / 10%)).

## **2\. Structural App Layouts**

### **Back-Office Shell (**app-shell**)**

The core back-office viewport requires a grid split into a fixed sidebar navigation column and an isolated main content canvas:  
CSS

```

.app-shell {
  display: grid;
  grid-template-columns: var(--sidebar-width) minmax(0, 1fr);
  min-height: calc(100vh - var(--header-height));
}

```

* **Global Navigation:** Organized into clear semantic functional clusters (Workspace, Operations, Design reference). Dynamic states must inject background soft tints (var(--brand-primary-soft)) and a 3px solid inset primary border for active page tracking.

### **Responsive Adaptation Rules**

* **Desktop Intermediate Block (1100px and under):** Layout structures containing massive dataset grids collapse gracefully from 4 or 3 columns to 2\. Split-layouts fall back to single stack configurations.  
* **Mobile Viewports (820px and under):** The sidebar navigation vanishes fully (display: none). Layout rows drop vertically (grid-template-columns: 1fr). Header search mechanisms transition away to preserve space, and an informative system banner indicates touch/viewport adjustments.

## **3\. Action Hierarchy & Component Anatomy**

### **Button Classification**

To ensure action transparency, engineers must classify interactive fields into designated functional scopes:

```

[ Primary Action ]   -> var(--brand-primary)   -> Save, Confirm, Edits
[ Secondary Brand ]  -> var(--brand-secondary) -> Auxiliary configurations
[ Accent Action ]    -> var(--brand-accent)    -> Specialized workflows
[ Outline / Ghost ]  -> Bordered / Clear       -> Cancellations, Secondary details
[ Destructive ]      -> var(--danger)          -> Record deletion, item removals

```

**UX Rule for Actions:** Reusing the logo's deep crimson-violet hue for dangerous operations is forbidden. Destructive workflows must remain explicitly bound to the semantic red color profile (\--danger) to avoid systemic user error.

### **Semantic Alerts & Badges**

Component statuses use paired semantic tokens ensuring uniform alert borders, background fills, and interior text contrast:

* **Info:** Tinted blue background (\#e8f2f7), matching teal-blue accent messaging borders (\#a7c6d8).  
* **Success:** Earth-toned green framing (\#afd0bc), paired with a deep moss-green text overlay (\#24543d).  
* **Warning:** Amber ochre styling ensuring high visibility reading (\--warning-text: \#684000) without breaking standard focus structures.  
* **Danger:** Deep crimson fields reserved strictly for severe transactional interruptions or processing blocks.

## **4\. Dedicated POS Interaction Contract**

The Point-of-Sale component presents an isolated workspace running a full-height layout optimized specifically for cashier checkouts.

```

+-------------------------------------------------------------------------+
| [POS Brand Icon]  | Session Status: Open | Store Location   |  1:24 PM  |
+-----------------------------------------------------+-------------------+
|  (Q) Barcode Scan Input Field                       | Transaction Head  |
+-----------------------------------------------------+ Balance Due       |
|  Context Bar (Customer Type / Price Tiers / Mode)   |                   |
+-----------------------------------------------------+ $71.07            |
|                                                     |                   |
|  Transactional Cart Table Data Grid                 +-------------------+
|                                                     | Quick Tender Grid |
|  - Qty Adjustments                                  |                   |
|  - Item Descriptions / Dynamic Inventory Messages   | [Card]   [Cash]   |
|  - Individual Discount Calculations                 | [Gift]   [Credit] |
|  - Aggregated Line Totals                          +-------------------+
|                                                     | Line Summaries    |
+-----------------------------------------------------+-------------------+
| [F4 Qty] [F5 Price] [F6 Disc] [F7 Return] [F8 Susp] | [Complete Sale]   |
+-------------------------------------------------------------------------+

```

### **Operational POS Layout Guidelines**

* **Dynamic Viewports:** Unlike the back-office workspace, the POS split view explicitly demands an unyielding 2-column container division split between sale workflows and transaction panels:  
* CSS

```

.pos-workspace {
  display: grid;
  grid-template-columns: minmax(620px, 1fr) 382px;
}

```

*   
* **Barcode Scanning Container:** Styled with a permanent 2px primary brand color border accent to guarantee that input focus fields remain visible during transactional scans.  
* **The Transaction Cart Grid:** Tables require strict table-layout: fixed mechanics to block content spillover when computing long product SKU numbers. Quantities utilize numeric controls (font-variant-numeric: tabular-nums) preventing structural item shifts when calculations refresh live.

### **Interaction & Keyboard Event Specifications**

To keep cashier hands focused entirely on terminal hardware without relying on pointing peripherals, the following physical hotkey listeners are strictly required:

* F2 \- Triggers Advanced Inventory Lookup.  
* F3 \- Customer profile assignment.  
* F4 **through** F6 \- Controls line quantity, unit price overrides, and situational discounts.  
* F7 \- Toggles **Return Mode** (Injects dynamic secondary colors \--brand-secondary-soft to warn cashiers they are currently auditing returns).  
* F8 \- Suspends active registers while preserving temporary product reservations.  
* Delete \- Drops the selected data item row from active calculation queues.  
* Ctrl \+ Enter \- Bypasses secondary validation to complete operations directly if all outstanding customer balances equal zero.

Would you like to expand the style guide to include explicit validation rules for form states, or should we define the technical API contract for saving transactional states from the POS?

# **ShelfStack UI Style Guide & UX Contract (Addendum)**

This addendum expands the core core platform specifications, detailing the layout engine's interactive form behaviors and the transactional data state structures mapping directly to the point-of-sale subsystem.

## **5\. Form State Validation Specifications**

All data-entry interfaces within the back-office and checkout modules must maintain uniform visual hierarchy, sizing tolerances, and micro-interactions when processing user inputs.

### **Structural Layout Engine**

Form topologies utilize an explicit two-column grid framework to keep fields aligned across varied screen dimensions:  
CSS

```

.form-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 16px;
}

```

* **Spanning Columns:** Full-width layout controls (e.g., internal notes, multi-line textareas, checkout option checkboxes) must explicitly deploy the .field-full utility class, forcing a structural override across both columns (grid-column: 1 / \-1).  
* **Field Grouping:** Input fields must wrap completely inside an isolated .field container block, enforcing a strict vertical stack layout via a 6px element gap hierarchy.

### **Input Sizing and Interactive Token Matrices**

Every form input element—including text strings, picklist selectors, and multiline comment containers—must scale programmatically based on the active structural tokens defined below:

| Interactive State | Boundary Properties | Surface & Shadow Tokens | Text & Typographic Scaling |
| :---- | :---- | :---- | :---- |
| **Default Field State** | border: 1px solid var(--border-default);  border-radius: 7px; | background: var(--surface-primary); | Height: 40px (Inputs & Selects). Text Fill: var(--text-primary); |
| **Placeholder / Empty State** | border: 1px solid var(--border-default); | background: var(--surface-primary); | Text Color: var(--text-disabled); |
| **Hover Interaction** | border-color: var(--border-strong); | background: var(--surface-primary); | Safe execution state for all interactive fields. |
| **Focus Engagement** | border-color: var(--brand-primary); | box-shadow: 0 0 0 3px rgb(125 180 184 / 30%); | Outline rule: outline: none; (Prevents default browser ring anomalies). |
| **Invalid / Validation Fail** | border-color: var(--danger); | background: var(--surface-primary); | Paired with an active .error-text block container. |

### **Validation Rule Assertions**

* **Mandatory Field Denotation:** Inputs that fail structural null checks must display a colored asterisk \* rendered in the semantic identity token \--danger.  
* **Inline Contextual Guidance:** Supplementary information strings beneath standard elements use the .help-text modifier, pinning contrast cleanly to var(--text-muted).  
* **Error Messaging Blocks:** When value bounds fail parsing criteria (e.g., unit cost threshold deviations), the input element must immediately acquire the .input-invalid boundary class. The system must dynamically render a companion description below using the .error-text class to display errors in var(--danger-text).

## **6\. Technical API & Transaction State Contract**

The Point-of-Sale framework operates as an isolated execution thread, relying on client-side reactive models to aggregate calculation steps before submitting them to server-side inventory control logs.

### **The Client-Side Transaction Data Model**

Every operational session tracking customer checkout lines must compile its structural mutations into a single standardized JSON data format:  
JSON

```

{
  "transaction_id": "00018452",
  "store_location": "Main Street",
  "register_metadata": {
    "register_id": 2,
    "drawer_id": 2,
    "cashier_identity": "Thomas"
  },
  "operational_mode": "sale",
  "customer_tier": {
    "profile_type": "Walk-in",
    "price_level": "Retail",
    "tax_profile": "Standard"
  },
  "cart_lines": [
    {
      "line_index": 1,
      "primary_identifier": "9781668072240",
      "item_name": "The Serviceberry",
      "meta_tags": ["Hardcover", "Books"],
      "financials": {
        "unit_price": 20.00,
        "unit_discount": 0.00,
        "quantity": 1,
        "line_total": 20.00
      }
    },
    {
      "line_index": 4,
      "primary_identifier": "OPEN-RING-01",
      "item_name": "Café — Large Drip Coffee",
      "meta_tags": ["Open ring", "Café beverages"],
      "financials": {
        "unit_price": 4.50,
        "unit_discount": 0.00,
        "quantity": 1,
        "line_total": 4.50
      }
    }
  ],
  "financial_summary": {
    "gross_merchandise_subtotal": 69.59,
    "aggregated_discounts": -3.80,
    "calculated_tax": 1.48,
    "net_balance_due": 71.07
  },
  "resolved_tenders": [
    {
      "tender_method": "Card",
      "captured_value": 71.07,
      "authorization_status": "Approved"
    }
  ]
}

```

### **Core Business Logic and Calculation Engine Requirements**

#### **1\. Dynamic Totals Formula**

The processing thread updates math balances in real time whenever lines are added, removed, or quantity values shift. The formula for determining line items must strictly execute as:  
$$\\text{Line Total} \= (\\text{Unit Price} \- \\text{Unit Discount}) \\times \\text{Quantity}$$

#### **2\. Specialized Café Taxation Processing**

Standard merchandise records (e.g., printed books) evaluate as tax-exempt within inventory master indexes. Tax algorithms must inspect the metadata titles of cart item arrays to isolate taxable food service components:

* **Tax Determination Condition:** If an item's descriptive string contains the token designation "Coffee", the calculation engine isolates that item's line total into a distinct taxable base index.  
* **Formula Rate Calculation:** This subtotal is multiplied by a fixed scalar rate of $0.0825$ ($8.25\\%$), rounding upwards to the nearest penny before modifying the top-level transaction envelope:

$$\\text{Tax Amount} \= \\text{Taxable Café Base} \\times 0.0825$$

#### **3\. State Machine Checkout Phases**

The lifecycle transitions through three terminal validation barriers to protect payment workflows:

```

+------------------------------------------------------------------------+
|                            1. OPEN WORKSPACE                           |
|       - Accepts scanned items into active checkout data line arrays    |
|       - Systematically updates totals based on data attribute tags      |
+------------------------------------------------------------------------+
                                    |
                                    v
+------------------------------------------------------------------------+
|                            2. TENDER LOCK                              |
|       - Disables inline updates upon receiving a card signal          |
|       - Awaits confirmation signature from external terminals          |
+------------------------------------------------------------------------+
                                    |
                                    v
+------------------------------------------------------------------------+
|                            3. COMPLETED STATE                          |
|       - Freezes all buttons via programmatic pointer exclusions        |
|       - Formats and prints sequential receipt receipts (e.g., #104892) |
+------------------------------------------------------------------------+

```

* **State 1: Open Workspace (Active Modification):** Accepts scanned identifiers, inserts records into data tables, and dynamically sets total values via structured data attributes (data-price, data-discount).  
* **State 2: Tender Lock (Verification Step):** When a user selects a payment method (such as Card), inline data updates lock down. The system prompts the cashier to run the transaction on an external terminal and manually confirm authorization approval.  
* **State 3: Completed State (Finalization):** Once outstanding values fall to zero, the final processing step freezes interface elements (disabled \= true) and logs a permanent receipt reference code across the centralized system database.
