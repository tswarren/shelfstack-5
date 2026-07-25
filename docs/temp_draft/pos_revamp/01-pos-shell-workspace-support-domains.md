# Supporting Domain Capabilities for the POS Revamp

## Purpose

The POS revamp depends on several capabilities that extend beyond the core transaction-building and tendering interface:

1. Customer records and customer lookup  
2. POS-native Product, Customer, and Stored Value lookup  
3. Receipt document generation and printing

These capabilities are part of the POS revamp milestone and should be available by the time the revised register workflows are implemented.

Register locking and authorized access to another user’s session are no longer prerequisites for this milestone. They are deferred for separate design and implementation.

---

# 1\. Customer Records

## Scope

The initial Customer domain should remain deliberately flat. ShelfStack does not initially need separate contact-method, address, organization-contact, or party-identity tables.

The model should support two customer types:

* Individual  
* Organization

An organization may include one named contact using the same `first_name` and `last_name` fields used for an individual. Multiple organization contacts can be added later if required.

## Customer fields

```
customer_type

organization_name
first_name
last_name

address_line_1
address_line_2
city
region
postal_code
country_code

primary_phone
alternate_phone
primary_email
alternate_email

notes
active
```

## Customer type

`customer_type` should be stored explicitly rather than inferred from whether `organization_name` is present.

Supported values:

```
individual
organization
```

An explicit type:

* records the intended identity of the customer;  
* supports clear validation;  
* prevents incomplete organization records from being misinterpreted as individuals;  
* supports type-specific forms and presentation;  
* leaves a clear path for organization-specific behavior later.

## Name rules

### Individual customer

For an individual:

* `organization_name` should be blank;  
* at least one of `first_name` or `last_name` must be present;  
* both names should not be required.

This permits customers who use a single name or records where only one name is known.

The display name is derived from the available name fields.

Examples:

```
Jordan Lee
Prince
Garcia
```

### Organization customer

For an organization:

* `organization_name` is required;  
* `first_name` and `last_name` are optional;  
* the individual name fields represent the primary contact when supplied.

Example:

```
Northside School District
Primary contact: Maya Chen
```

The organization name remains the customer’s canonical display name. The contact name is presented as secondary information.

## Address rules

Use:

```
address_line_1
address_line_2
```

rather than street-specific names because the fields may contain:

* street addresses;  
* PO boxes;  
* rural routes;  
* suites;  
* departments;  
* building information.

`country_code` should use ISO 3166-1 alpha-2 country codes, such as:

```
US
CA
GB
```

`region` should initially remain a flexible string for a state, province, territory, or other subdivision.

## Contact information normalization

Phone numbers and email addresses should be normalized on save. The initial model does not need to preserve the user-entered, non-normalized representation.

### Phone numbers

Valid phone numbers should be stored in E.164 form:

```
(519) 555-0123
→ +15195550123
```

Phone parsing should use the following country context:

1. An explicit international calling code in the entered value  
2. The customer’s `country_code`  
3. The store’s configured country

Phone normalization should use a proven phone-number library rather than custom regular expressions.

Phone extensions are deferred until a demonstrated workflow requires them.

### Email addresses

Email normalization should:

* trim surrounding whitespace;  
* lowercase the address;  
* validate a reasonable email structure.

Example:

```
" Jordan.Lee@Example.COM "
→ jordan.lee@example.com
```

ShelfStack should not perform provider-specific transformations such as:

* removing periods from Gmail addresses;  
* stripping `+tag` suffixes;  
* assuming provider-specific address equivalence.

## Contact requirements

Phone, email, and address fields should remain optional at the Customer model level.

Individual workflows may impose stronger requirements:

| Workflow | Likely requirement |
| :---- | :---- |
| Basic customer association | Customer name |
| Customer order or reservation | Primary phone or primary email |
| Email receipt | Valid email |
| Shipment | Complete address |
| Organization account | Organization name |
| Tax exemption | Required exemption information |

This avoids requiring cashiers to enter placeholder or fabricated contact information.

## Duplicate detection

Normalized phone numbers and email addresses should be indexed for lookup but should not be unique.

Legitimate duplication may occur when:

* household members share contact information;  
* organizations use a central switchboard;  
* several customers use a shared organization email;  
* an individual and an organization use the same contact details.

ShelfStack should show a possible-duplicate warning rather than reject the record.

Example:

```
Possible matching customer

Jordan Lee
jordan.lee@example.com

[ Use existing ]
[ Create separate customer ]
```

---

# 2\. POS-Native Lookup Services

## Purpose

The POS should provide cashier-oriented lookup workflows for:

* Products  
* Customers  
* Stored Value accounts

These services remain inside the POS shell and should not send the cashier into the general administrative application.

They are focused projections of their owning domains rather than duplicate CRUD interfaces.

## Shared lookup rules

### Lookup does not create a transaction

Opening a lookup, entering a query, or selecting a result must not create an empty transaction.

A transaction is created only when valid customer work is submitted, such as:

* adding a Product line;  
* submitting an Open Ring line;  
* creating a Stored Value issue or reload line.

### Lookup remains within the register

From Ready:

```
Ready
→ Lookup
→ Results
→ Return to Ready or perform an action
```

From an active Transaction:

```
Transaction
→ Lookup opens within the POS workspace
→ Transaction summary remains visible
→ Selection applies to the active transaction
```

### Common lookup outcomes

Each lookup service should support structured outcomes such as:

```
exact_match
multiple_matches
no_match
restricted
unavailable
error
```

Controllers and views should not have to infer the difference between these outcomes from a missing record.

### Keyboard behavior

Common keyboard behavior should include:

| Key | Action |
| :---- | :---- |
| Up/Down | Move through results |
| Enter | Open or select the focused result |
| Escape | Return one level or close lookup |
| Tab | Reach result actions and filters |

The visible action button remains authoritative. Keyboard shortcuts are accelerators.

### Context-sensitive actions

Available actions depend on the POS state.

| POS state | Typical lookup behavior |
| :---- | :---- |
| Ready | Lookup and begin new work |
| Transaction | Apply result to active transaction |
| Tender | View-only unless used by the active tender workflow |
| Recovery | Restricted or view-only |
| Receipt | View supporting details only |

All actions remain subject to:

* user permissions;  
* transaction editability;  
* store eligibility;  
* current tender state;  
* domain validation.

---

# 3\. Product Lookup

## Purpose

Product lookup supports cases where:

* an item will not scan;  
* the customer does not have the physical item;  
* the cashier knows a title, creator, SKU, or identifier;  
* several variants need to be compared;  
* the cashier wants to check price or availability without beginning a transaction.

## Search inputs

Product lookup should support:

* canonical trade identifier;  
* ISBN-10 input normalized to canonical ISBN-13;  
* SKU;  
* alternate Product or Variant identifier;  
* title or description;  
* creator;  
* exact Inventory Unit barcode;  
* other useful descriptive metadata where supported.

## Scan versus explicit lookup

The ordinary scan field and Product Lookup have different behavior.

### Ordinary scan

A unique, eligible Product or Variant match may be added immediately.

### Explicit Product Lookup

Even an exact match should display its result rather than automatically adding it.

This allows the cashier to check:

* price;  
* condition;  
* variant;  
* availability;  
* sale eligibility;

without creating or modifying a transaction.

## Product result presentation

Results should be grouped by Product, with relevant Variants beneath them.

A result may show:

* Product title or description;  
* creator or manufacturer;  
* Variant format, condition, or attributes;  
* ISBN, UPC, or SKU where useful;  
* current selling price;  
* current-store availability;  
* sale restrictions or warnings;  
* exact-unit status for individually tracked items.

The POS result should not normally expose:

* acquisition cost;  
* margin;  
* accounting mappings;  
* internal database IDs;  
* detailed Vendor information.

## Product actions

### From Ready

* Add item and begin transaction  
* View Product details

Adding the first item should atomically:

1. validate the Product or Variant;  
2. create the POS transaction;  
3. add the line;  
4. create the inventory reservation;  
5. enter Transaction presentation.

A failure must not leave an empty transaction.

### From Transaction

* Add item  
* Add quantity  
* Select exact Inventory Unit where required  
* View details

### From Return intent

The result may be used to identify an unlinked return item rather than create an ordinary sale line.

### From Tender or Recovery

Product lookup is read-only or unavailable while commercial editing is locked.

---

# 4\. Customer Lookup

## Purpose

Customer lookup supports:

* attaching a customer to a transaction;  
* finding Customer Orders or reservations;  
* applying customer-linked exemptions or benefits;  
* viewing basic contact information;  
* creating or editing a customer without leaving the register.

## Search inputs

Customer lookup should match normalized forms of:

* first name;  
* last name;  
* combined individual name;  
* organization name;  
* organization primary-contact name;  
* primary or alternate phone;  
* primary or alternate email.

Address should not be a primary search method initially, although city, region, or postal code may be shown to distinguish similar records.

## Customer result presentation

### Individual

```
Jordan Lee
(519) 555-0123
jordan.lee@example.com
Springfield, ON
```

### Organization

```
Northside School District
Primary contact: Maya Chen
(519) 555-0100
purchasing@northside.edu
```

Customer result lists should not display internal notes.

## Customer actions

### From Ready

Available actions may include:

* Use for next transaction  
* View customer  
* Edit customer  
* Create customer

Selecting **Use for next transaction** should stage the customer in the register workspace without creating an empty transaction.

Example:

```
Selected customer for next transaction:
Jordan Lee
```

When the first valid line is submitted, ShelfStack atomically creates the transaction with the customer attached.

The staged customer should be cleared when:

* the transaction is successfully created;  
* the cashier removes the selection;  
* the session closes;  
* the cashier begins an incompatible workflow.

### From Transaction

Available actions may include:

* Attach customer  
* Replace customer  
* Remove customer  
* View customer

Changing the customer may require recalculation or reevaluation of:

* customer pricing;  
* membership discounts;  
* tax exemptions;  
* Customer Order associations;  
* transaction readiness.

Customer changes are prohibited once tender activity locks commercial editing.

### Customer creation

The POS should provide a compact Customer form using the flat Customer model.

It should:

* normalize phone and email on save;  
* warn about possible duplicates;  
* apply workflow-specific requirements;  
* avoid requiring every contact field for basic creation.

---

# 5\. Stored Value Account Lookup

## Purpose

Stored Value lookup supports:

* checking an account balance;  
* confirming account type and status;  
* reloading an account;  
* selecting an account for redemption;  
* selecting or creating an account for a refund;  
* viewing limited account information.

## Search model

The initial POS lookup should emphasize exact identifier resolution rather than broad account browsing.

Supported input may include:

* canonical Stored Value account identifier;  
* scanned barcode;  
* configured alternate identifier.

The POS should reuse the Stored Value domain’s authoritative identifier-resolution service.

Broad search by customer name, email, phone, or balance is not required initially.

## Stored Value result presentation

A result may show:

```
Gift Card
Account •••• 9304
Status: Active
Available balance: $40.00
```

It may include:

* customer-facing account type;  
* masked identifier;  
* status;  
* current available balance;  
* expiration information where applicable;  
* associated customer when permitted.

It must not expose:

* the complete account identifier after resolution;  
* internal ledger IDs;  
* full account history;  
* security credentials;  
* internal adjustment notes.

## Stored Value actions

### From Ready

* Check balance  
* Reload account  
* Issue new account  
* View account details where permitted

Checking the balance or resolving an account does not create a transaction.

A reload creates transaction work only when a valid amount is submitted.

### From Transaction

* Add reload line  
* Issue new Stored Value  
* View balance

Issuance and reload are transaction lines, not tenders.

### From Tender with an amount due

* Redeem Stored Value

ShelfStack should:

* show the account type and masked identifier;  
* validate status and balance;  
* default the applied amount appropriately;  
* require explicit confirmation.

### From Tender with a refund due

The workflow may support:

* restoration to original Stored Value;  
* refund to an eligible existing account;  
* creation of Store Credit where policy permits.

### General scan field

Scanning a Stored Value identifier should display or resolve the account according to the current context.

It must never automatically:

* redeem value;  
* reload the account;  
* issue new value;  
* change the balance.

---

# 6\. Receipt Documents and Printing

## Purpose

ShelfStack generates customer-facing receipt documents from completed POS transactions.

Receipts are presentations of completed facts. They are not separate financial records.

Printing occurs after transaction completion and never determines whether the transaction succeeds.

## Governing principles

1. The completed transaction is authoritative.  
2. Receipt documents are generated on demand.  
3. Historical commercial facts are not recalculated from current Product, price, tax, or tender configuration.  
4. Store presentation information may be read from current configuration when printing.  
5. Printing failure does not reverse or invalidate a completed transaction.  
6. Reprinting creates no new commercial activity.

## Receipt generation

```
Completed transaction facts
+ current store receipt settings
+ requested document format
→ generated receipt
→ printable output
```

ShelfStack does not initially need to persist:

* rendered receipts;  
* receipt snapshots;  
* historical store headers;  
* template versions;  
* raw printer output;  
* Gift Receipt records;  
* print-attempt records.

This means a reprint is a functional reproduction of the historical transaction, not necessarily an exact visual facsimile of the originally printed document.

## Historical transaction information

Receipts must use completed transaction facts for:

* receipt number;  
* completion date and time;  
* sale and return lines;  
* item descriptions captured at completion;  
* quantities;  
* selling prices;  
* price overrides;  
* discounts;  
* tax treatment;  
* tenders and refunds;  
* change;  
* Stored Value activity;  
* linked return or post-void references.

## Current store presentation information

The following may be resolved at print time:

* store name;  
* store address;  
* store contact information;  
* logo;  
* receipt header and footer;  
* Gift Receipt footer;  
* layout and formatting;  
* printer-specific presentation.

## Customer receipt

The standard Customer Receipt is itemized and may include:

* store header;  
* receipt number;  
* completion date and time;  
* register and cashier when configured;  
* sale and return lines;  
* quantities and prices;  
* price overrides and discounts;  
* tax components;  
* totals;  
* received and refunded tenders;  
* cash tendered and change;  
* Stored Value activity;  
* return-policy information;  
* receipt lookup barcode;  
* store-defined footer.

The receipt should omit internal information such as:

* database IDs;  
* internal UUIDs;  
* cost and margin;  
* accounting mappings;  
* approval credentials;  
* complete card or Stored Value identifiers;  
* inventory warnings;  
* internal return dispositions.

## Derived receipt presentation

Receipt labels should be derived from completed activity.

| Completed activity | Presentation |
| :---- | :---- |
| Sale activity only | Receipt |
| Return activity only | Return Receipt |
| Mixed sale and return | Receipt with return lines identified |
| Administrative reversal | Post-Void Receipt |
| Later customer copy | Reprint |
| Gift proof of purchase | Gift Receipt |

## Reprints

A Customer Receipt reprint:

* retains the original receipt number;  
* retains the original completion date;  
* uses historical transaction facts;  
* may use current store presentation;  
* is labeled `REPRINT`;  
* does not create a new transaction or receipt number;  
* does not repeat inventory, tender, tax, or Stored Value postings.

A failed print from the immediate Receipt presentation may be retried without being treated as a reprint. A later print from Receipt Lookup is treated as a reprint.

Persistent print-attempt auditing is not initially required.

## Gift receipts

A Gift Receipt is a non-itemized, price-opaque reference to the original transaction.

It contains:

* current store header;  
* `GIFT RECEIPT` label;  
* original receipt number;  
* original transaction date;  
* scannable receipt-number barcode;  
* store-defined Gift Receipt footer.

It omits:

* merchandise descriptions;  
* quantities;  
* prices;  
* discounts;  
* taxes;  
* totals;  
* tenders;  
* payment references;  
* Stored Value activity;  
* customer and purchaser information.

Example:

```
          SHELFSTACK BOOKS
       123 Main Street
         (555) 555-0142

          GIFT RECEIPT

Receipt 01-00018425
Jul 18, 2026  3:42 PM

     [ receipt-number barcode ]

Present this receipt with the item.
Returns are subject to store policy
and item eligibility.
```

The same Gift Receipt may accompany any potentially returnable item from the original transaction.

### Gift return workflow

The Gift Receipt barcode is a lookup reference, not an authorization to return merchandise.

When scanned:

1. ShelfStack locates the original transaction.  
2. The cashier scans or searches for the physical item.  
3. ShelfStack determines whether the item appeared on that transaction.  
4. ShelfStack checks remaining returnable quantity and eligibility.  
5. ShelfStack uses the original selling price and tax treatment.  
6. The return workflow applies current permissions and refund policy.

No separate Gift Receipt record or secure line-specific token is required initially.

## Stored Value slips

ShelfStack may generate a compact informational slip for completed Stored Value activity.

It may show:

* customer-facing account type;  
* masked account identifier;  
* activity type;  
* amount;  
* balance immediately after the posting;  
* receipt number;  
* transaction date.

The balance must come from the completed posting rather than a later live balance.

A Stored Value activity slip is distinct from a bearer voucher whose printed barcode can itself be redeemed. Bearer-voucher security and reprinting are outside the initial receipt scope.

## Printing

The initial implementation may use:

* printable HTML;  
* browser printing;  
* layouts optimized for 80 mm or 3⅛-inch paper;  
* ordinary full-page printing where necessary.

Receipt semantics must remain independent of printer width or hardware technology.

After transaction completion, the Receipt presentation may offer:

* Next transaction  
* Print receipt  
* Gift receipt  
* Stored Value slip where applicable

If printing fails, ShelfStack should allow the cashier to:

* retry;  
* select another available printer where supported;  
* continue without printing.

The transaction remains completed.

## Receipt Lookup

Receipt Lookup should permit authorized users to:

* view the generated Customer Receipt;  
* print a reprint;  
* print a Gift Receipt;  
* print an applicable Stored Value slip;  
* begin a linked return.

Receipt Lookup must not modify the completed transaction.

---

# 7\. Deferred Register Lock and Session Access

## Status

Register locking and authorized access to another user’s session are deferred. They are not prerequisites for the POS revamp milestone.

The milestone assumes:

```
Authenticated user
→ their open POS session
→ their active transaction
```

The milestone does not initially need:

* temporary register locking;  
* same-user unlock;  
* authorized takeover;  
* assigned cashier versus acting user;  
* cross-user operational access;  
* cross-device session control;  
* force release;  
* session-control tokens;  
* session-access audit events.

## What remains required

Ordinary authentication and authorization remain in scope:

* users must have permission to access the POS;  
* users operate their permitted sessions;  
* transaction actions use the authenticated user’s permissions;  
* approvals record the actual approver;  
* completion and cancellation retain actual user attribution where already supported.

Manager approval remains separate from session takeover. A supervisor may authorize an action without becoming the cashier operating the session.

## Architectural seams to preserve

Although the feature is deferred, the milestone should preserve a clean future path.

### Retain actor distinctions

Continue to distinguish where applicable:

* assigned session cashier;  
* session opened by;  
* session closed by;  
* transaction cashier;  
* transaction completed by;  
* transaction cancelled by;  
* approval granted by.

### Centralize session resolution

The POS should resolve the current user’s session through a central application service rather than duplicating direct queries throughout the controllers.

For the initial milestone, that resolver may simply return the authenticated user’s open session.

### Restore workspace from authoritative state

Ready, Transaction, Tender, Recovery, and Receipt should be derived from persisted transaction and tender facts.

This supports:

* page refresh;  
* navigation recovery;  
* failed requests;  
* future register locking;  
* future session takeover.

## Deferred capability definition

A later Register Security and Session Access milestone may address:

* temporary workstation locking;  
* same-user reauthentication;  
* authorized takeover;  
* viewing another session;  
* releasing or force-releasing control;  
* closing another user’s session;  
* exclusive control and stale-request invalidation;  
* actor-aware cash and transaction reporting.

---

# 8\. Milestone Summary

## Supporting capabilities included

### Customer domain

* Flat Individual and Organization customer records  
* Explicit `customer_type`  
* Organization primary-contact name using flat name fields  
* Normalized phone and email storage  
* Compact POS Customer creation  
* Duplicate warnings  
* Customer search and transaction association

### POS-native lookup

* Product lookup  
* Customer lookup  
* Stored Value account lookup  
* Shared inline register behavior  
* No empty transaction creation from lookup alone  
* Context-sensitive result actions  
* Keyboard-accessible result navigation  
* Domain-authoritative validation

### Receipt documents

* Customer Receipts  
* Return and mixed-transaction presentation  
* Post-Void Receipts  
* Functional reprints  
* Non-itemized Gift Receipts  
* Receipt-number barcodes  
* Stored Value activity slips  
* Current store headers and footers  
* Printable output and Receipt Lookup

## Deferred

* Register locking  
* Same-user unlock  
* Authorized session takeover  
* Cross-user or cross-device operational session access  
* Detailed session-control auditing  
* Persisted Receipt documents  
* Historical presentation snapshots  
* Gift Receipt records or line selection  
* Print-attempt auditing  
* Bearer Stored Value voucher rules

## Governing principle

> The POS revamp includes the supporting Customer, lookup, and receipt capabilities required for a complete cashier workflow. These capabilities should remain focused, domain-owned, and integrated into the register shell. Register security and cross-user session access are deferred so they can be designed separately without blocking the core milestone.  
