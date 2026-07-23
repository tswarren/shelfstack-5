Recommended approach
Treat the printed receipt as a customer-facing transaction summary, not a dump of the POS record. ShelfStack can preserve much more detail electronically than should appear on a narrow paper receipt.

For standard 3⅛-inch/80 mm paper:

Design the primary template around 42 monospaced characters.

Optionally support a 48-character condensed printer profile.

Use normal-size text for items, double-height or bold text only for the store name, document type, and final total.

Right-align every monetary amount.

Use blank space and solid rules rather than boxes, shading, or complex columns.

Avoid centered text except for the store header, major banners, barcode, and closing message.

This fits ShelfStack’s existing model: completed transactions preserve line, discount, tax, tender, and classification snapshots, while receipt numbers are assigned only upon successful completion. Reprints retain the original receipt number and must be visibly marked; gift receipts use the original transaction but omit prices and use a secure return token.

Receipt information hierarchy
Section | Recommended contents -- | -- Store header | Store name, address, phone, website, legally required tax registration Document banner | RECEIPT, RETURN, POST-VOID, REPRINT, or GIFT RECEIPT when clarification is needed Transaction identity | Receipt number, completion date/time, register, cashier Contextual references | Original receipt for returns or post-voids; business date only when different from calendar date Merchandise | Description, meaningful variant or condition, quantity, unit price, extended amount Adjustments | Price override, discount, promotion, coupon, or return amount Totals | Merchandise, discounts, returns, tax components, final total Tenders | Each received or refunded tender, cash presented, cash applied, change Tax legend | Short tax codes and component summary Return information | Return deadline or concise policy statement; final-sale indicators Machine-readable lookup | QR code or barcode containing a secure receipt lookup or return token Footer | Thank-you message and configurable store text
Recommended item format
Give the description its own line. Do not force descriptions and amounts into one crowded row.

THE LEFT HAND OF DARKNESS
  ISBN 9780441478125
  1 x 24.99                   24.99 A
  Member 10%                  -2.50
Rules:

Use the product title or concise POS description as the primary line.

Print an ISBN, UPC, or SKU on a secondary line when it is useful for returns or product identification.

Show variant information only when meaningful: Used · Very Good, Large · Blue, Signed, or 12 oz.

For quantity greater than one, always show quantity and unit price.

Do not print 1 x when the receipt needs to be especially compact, but consistency is usually preferable.

Place the tax marker after the line amount.

Print discounts immediately under the affected item.

Print a regular price only when a price override occurred.

Example price override:

HARDCOVER JOURNAL
  Regular 18.99 -> 16.99      16.99 A
A price override and a discount should remain visibly distinct because ShelfStack treats them as different commercial events. Promotions may be presented using a customer-friendly description even when their internal discount is allocated across several lines.

Example full receipt
             SHELFSTACK BOOKS
        123 Main Street, Anytown
          (555) 555-0142
Receipt 01-00018425
Jul 18, 2026  3:42 PM
Register 02   Cashier: Jordan

THE LEFT HAND OF DARKNESS
ISBN 9780441478125
1 x 24.99                   24.99 A
Member 10%                  -2.50


BLUEBERRY SCONE
2 x 3.25                     6.50 B


PANTRY GROCERY ITEM
1 x 4.99                     4.99 E

Merchandise                    36.48
Discounts                      -2.50
Net merchandise                33.98
State Tax 6%  (base 28.99)      1.74
Food Tax 1.25% (base 6.50)      0.08
TOTAL                          35.80

Card **** 4821                 30.00
Cash presented                 10.00
Cash applied                    5.80
CHANGE                          4.20

A State 6%   B State + Food   E Exempt


Returns accepted through Aug 17, 2026
subject to item policy and condition.


  [ receipt lookup QR/barcode ]
    Thank you for shopping!


Totals and tax presentation
The totals section should explain how the system reached the amount due without reproducing every accounting layer.

For an ordinary sale:

Merchandise                    36.48
Discounts                      -2.50
Net merchandise                33.98
Tax                             1.82
TOTAL                          35.80
For a mixed sale-and-return transaction:

Sales                          42.00
Discounts                      -3.00
Returns                       -14.99
Net merchandise                24.01
Tax                             1.44
TOTAL                          25.45
Tax should be summarized by actual tax component, not merely as one undifferentiated figure when several rates apply:

State Tax 6%  (base 28.99)      1.74
Food Tax 1.25% (base 6.50)      0.08
A short marker legend keeps item lines compact:

A State 6%
B State 6% + Food 1.25%
E Exempt
Z Zero-rated
Exempt and zero-rated should remain distinguishable even when both produce zero tax. For a tax-exempt transaction, print a clear summary such as:

TAX EXEMPT
Certificate: 4821
Exempt merchandise             33.98
Tax                              0.00
Do not print complete exemption certificate numbers unless legally required.

Tender formatting
Print each completed tender separately. ShelfStack supports received and refunded tenders within the same transaction, so the receipt should not collapse everything into one net payment line.

Visa **** 4821                 30.00
Gift Card **** 9304             5.00
Cash presented                 10.00
Cash applied                    0.80
CHANGE                          9.20
For standalone cards, normally print:

Card brand

Masked last four

Approved amount

Authorization code, when operationally useful

Avoid printing full terminal references unless needed for customer support.

For stored value:

Store Credit **** 9304          8.50
Remaining balance              14.25
The remaining balance is useful but should come from the completed stored-value posting, not a later live lookup.

Special receipt types
Return receipt
Use an unmistakable banner and render returned merchandise as negative customer-facing amounts:

******** RETURN ****************

THE LEFT HAND OF DARKNESS
Original receipt 01-00017204
1 x 24.99                  -24.99 A


Tax refunded                  -1.50
REFUND TOTAL                 -26.49


Refund to Visa **** 4821      26.49

For mixed transactions, label individual return lines RETURN rather than placing a return banner over the entire receipt.

Reprint
Place the notice near the top, not only in the footer:

*************** REPRINT ***************
Original receipt 01-00018425
Reprinted Jul 18, 2026  4:16 PM
The financial content should reproduce the completed receipt snapshots rather than use current product names, prices, or tax rules. The reprint retains the original receipt number and creates only a print audit event.

Post-void
************** POST-VOID **************
Reverses receipt 01-00018425
Original completed Jul 18, 2026 3:42 PM
The reversal receives its own receipt number and shows negative reversing amounts.

Gift receipt
Omit all prices, totals, discounts, tax, and tenders.

Identify each eligible item.

Include the original receipt number.

Include a secure return token or barcode.

Do not expose the purchaser’s payment details.

************* GIFT RECEIPT ************

Receipt 01-00018425


THE LEFT HAND OF DARKNESS
ISBN 9780441478125


BLUEBERRY SCONE
Not eligible for return


  [ secure gift-return barcode ]


Gift receipt behavior and print types are already represented in the proposed receipt-print audit structure.

Information that should remain electronic
Do not print the following on the normal customer receipt:

Internal transaction UUIDs or database IDs

POS session IDs, business-day Z numbers, or drawer IDs

Product and variant database keys

Inventory acquisition cost or gross margin

Department and accounting mappings

Manager names or approval credentials

Internal return disposition

Full gift-card, certificate, or card numbers

Detailed tax rounding records

Internal promotion allocations

Inventory warnings or reservation information

Those remain available through the electronic transaction record and receipt lookup. The printed receipt should contain enough information for the customer to understand the purchase, verify the calculation, identify payment, and initiate a return.

The project repository context is available here:

--

Overall assessment
The proposal fits ShelfStack very well. Its strongest decision is treating the receipt as a customer-facing projection of an immutable completed transaction rather than as a printout of database fields. The distinctions among price overrides, discounts, returns, tenders, tax components, stored value, reprints, gift receipts, and post-voids are consistent with ShelfStack’s architecture.

It also aligns with the governing rules that:

completed transactions remain immutable;

corrections create linked return or post-void records;

historical prices, classifications, tax, cost, tenders, and stored-value effects are preserved;

receipt numbers are assigned only at successful completion;

reprints do not create new financial activity;

stored value is reported separately from merchandise and ordinary tender.

The main weakness is that the proposal currently combines three separate subjects:

what information a receipt means;

how ShelfStack derives that information;

how an 80 mm printer renders it.

Those should become separate design layers.

1. Define the receipt as a projection
ShelfStack should not treat the printed receipt itself as the authoritative record.

A receipt document should be generated from:

the completed transaction snapshot;

completed line items;

completed discount allocations;

completed tax components;

completed tenders;

completed stored-value ledger postings;

correction relationships;

receipt-policy snapshots;

the applicable print template.

Conceptually:

Completed transaction facts
+ Completed related postings
+ Receipt policy/version
+ Printer profile
→ Receipt document
→ Rendered printer output
This reinforces an important distinction:

A receipt is a presentation of completed facts, not an additional financial posting.

A ReceiptPresenter, ReceiptDocumentBuilder, or similar application service would be preferable to embedding receipt formatting directly in transaction models.

2. Separate four configuration layers
A. Transaction semantics
These rules are universal ShelfStack behavior:

returns show reversing amounts;

a post-void references and reverses an original transaction;

a reprint retains the original receipt number;

stored-value issuance is not merchandise revenue;

redemption is tender;

discounts and overrides remain separate;

mixed sale-and-return transactions settle only the net difference.

These should not be configurable per printer.

B. Store receipt policy
Store-level configuration should control:

legal store name;

address and contact information;

tax registration numbers;

return-policy wording;

whether product identifiers print;

whether cashier identity prints;

whether tax bases print;

whether stored-value balances print;

whether QR lookup is enabled;

custom header and footer text;

logo use;

gift-receipt wording.

C. Receipt template
The template controls:

section order;

labels;

alignment;

item wrapping;

tax legend format;

whether blank lines separate items;

which fields appear in compact and detailed modes.

D. Printer profile
The printer profile controls:

32-, 42-, or 48-column width;

character encoding;

supported bold and double-height commands;

logo dimensions;

QR or barcode capabilities;

automatic cutting;

cash-drawer pulse behavior.

The receipt should therefore not be designed around exactly 42 characters. Forty-two characters is a good default profile, but not a business rule.

3. Do not give the transaction a rigid receipt type
ShelfStack transactions can contain both sales and returns. Therefore, SALE, RETURN, and EXCHANGE should usually be derived presentation descriptions, not stored transaction types.

Recommended display logic:

Transaction contents | Receipt presentation -- | -- Sale activity only | RECEIPT or no banner Return activity only | RETURN RECEIPT Mixed sales and returns | RECEIPT, with individual return lines marked Full administrative reversal | POST-VOID Duplicate customer copy | REPRINT Price-suppressed item document | GIFT RECEIPT
A mixed transaction should not have a large RETURN banner simply because it contains one returned item.

4. Refine the tax notation
The proposed tax summary is structurally good, but the line markers need more precise semantics.

The receipt currently suggests:

A State 6%
B State 6% + Food 1.25%
E Exempt
Z Zero-rated
The concern is that no tax charged does not automatically mean exempt.

A line might have no tax because:

its tax category has no applicable rule;

the product is statutorily exempt;

a customer or transaction exemption was applied;

it is zero-rated;

it is outside the scope of the particular tax;

a return is reversing previously collected tax.

ShelfStack should derive receipt tax markers from the completed tax result and exemption snapshot, not simply from the product’s tax category.

A safer scheme would be:

A  State tax
B  State + food tax
X  Exemption applied
Z  Zero-rated
N  No tax applied
Whether N, X, and Z need to be distinguished on customer receipts should be configurable by jurisdiction. Internally, they must remain distinct.

For a simple transaction with one tax component, the item markers may be unnecessary. The receipt can show:

Taxable sales                  28.99
Exempt/non-taxed sales          4.99
State Tax                       1.74
For more complex tax configurations, the component summary is appropriate:

State Tax 6.00%                 1.74
Food Tax 1.25%                  0.08
Printing the taxable base is useful but should be configurable because it consumes substantial space.

5. Snapshot receipt-sensitive policy
The proposal correctly says that reprints must use historical commercial facts. It should go slightly further.

The following may change after completion:

store legal name;

store address;

tax registration number;

return-policy wording;

return window;

final-sale designation;

store contact information;

receipt template.

ShelfStack should explicitly decide between two reprint policies.

Functional reprint
Reprints historical transaction facts using the current visual template and current generic footer.

Facsimile reprint
Reproduces what would have printed at the time of sale, including the historical header, policy wording, and template version.

For ShelfStack, I recommend:

historical financial and item information is always mandatory;

item return eligibility and deadline are snapshotted;

legal store identity and tax identifiers are snapshotted;

presentation may use the current renderer;

the receipt records the template/policy version used at completion.

It is probably unnecessary to store an image or raw printer byte stream. A structured receipt snapshot or versioned rendering contract should be sufficient.

6. Improve return-policy presentation
This line is useful:

Returns accepted through Aug 17, 2026
subject to item policy and condition.
However, one transaction may contain items with different policies:

ordinary books;

final-sale periodicals;

opened media;

café items;

used or collectible merchandise;

stored-value issuance;

discounted clearance merchandise.

ShelfStack should derive a return result per completed line, including:

returnable or final sale;

return deadline, when determinable;

receipt requirement;

condition requirement;

gift-receipt eligibility.

A receipt could then show:

MAGAZINE TITLE
  1 x 8.99                     8.99 N
  FINAL SALE
THE LEFT HAND OF DARKNESS
1 x 24.99                   24.99 A

And the footer:

Eligible items returnable through Aug 17.
See store policy for conditions.
If several return windows exist, print the deadline beneath the affected items rather than presenting one misleading transaction-wide date.

7. Simplify cash presentation
The proposal shows:

Cash presented                 10.00
Cash applied                    5.80
CHANGE                          4.20
Cash applied is accurate but sounds like internal accounting terminology. A customer receipt can usually show:

Cash tendered                  10.00
Change                          4.20
The retained cash is evident from the transaction total and other tenders.

ShelfStack should still store all three values:

amount presented;

amount applied;

change given.

But not every stored value needs to print.

For split tender:

Visa **** 4821                 30.00
Cash tendered                  10.00
Change                          4.20
This is easier to read while remaining mathematically understandable.

8. Treat the card terminal receipt separately
Because ShelfStack initially uses standalone card terminals, its receipt is not necessarily the formal payment-processor receipt.

ShelfStack should distinguish:

ShelfStack transaction receipt

standalone terminal card receipt

The ShelfStack receipt normally needs only:

Visa **** 4821                 30.00
Authorization code and terminal reference should be configurable and generally omitted unless needed for support or reconciliation.

ShelfStack should never imply that it captured processor details it did not actually receive.

9. Strengthen stored-value presentation
Stored value deserves more explicit receipt patterns because it appears in several different roles.

Issuance or reload
GIFT CARD LOAD
Account **** 9304            25.00
New balance                  25.00
Redemption
Gift Card **** 9304            12.50
Remaining balance              14.25
Refund to store credit
Refund to Store Credit         18.75
Account **** 4418
New balance                    18.75
Reversal
Gift Card Issuance Reversed   -25.00
Account **** 9304
New balance                     0.00
The displayed balance must be the balance immediately after the completed posting, not a later live lookup. That matches the proposal and should become an explicit invariant.

Gift card, store credit, and trade credit should always use their actual customer-facing names rather than a generic Stored Value label.

10. Improve gift-receipt security
The proposal correctly uses a secure return token. The barcode or QR code should not contain:

the database transaction ID;

an unsigned transaction UUID;

the stored-value account number;

customer identity;

tender information;

a predictable URL parameter.

It should contain an opaque, signed, revocable token that identifies:

the originating transaction;

eligible lines;

eligible quantity;

organization or store;

gift-return context;

token status or expiry policy.

The visible original receipt number may remain because that is already part of the ShelfStack design, but the secure token—not the visible number—should authorize gift-return lookup.

A gift receipt should also support selection of particular lines. Customers often need a gift receipt for only one item from a larger transaction.

11. Model printing attempts separately from reprints
Printing occurs after successful atomic completion. A printer failure must not roll back the transaction.

This creates an important distinction:

the first automatic print was attempted and failed;

the system retried the original print;

the cashier intentionally requested another copy;

a later user printed a reprint.

Only the latter cases should normally display REPRINT.

The existing proposed print-event concept should be expanded modestly:

pos_receipt_print_events


pos_transaction_id

print_type

trigger

status

printer_id

template_version

copy_number

requested_by_user_id

requested_at

completed_at

failure_code
Possible values:

print_type:
customer_receipt
gift_receipt
post_void_receipt

trigger:
automatic
retry
manual_reprint


status:
requested
succeeded
failed

The transaction is completed before any of these printer events occur.

12. Account for printer character limitations
Book titles, author names, customer names, and store information may contain:

accented Latin characters;

curly quotation marks;

em dashes;

non-Latin scripts;

trademark symbols.

Many thermal printers have limited code pages.

The printer profile should define:

supported encoding;

transliteration or substitution behavior;

replacement glyph behavior;

title wrapping;

maximum printable width;

whether raster text is supported for unsupported characters.

ShelfStack should not silently produce corrupted title text. A browser/PDF receipt and an ESC/POS receipt may need different rendering implementations from the same structured receipt document.

13. Refined ordinary receipt example
             SHELFSTACK BOOKS
123 Main Street, Anytown
(555) 555-0142

Receipt 01-00018425
Jul 18, 2026  3:42 PM
Register 02   Cashier: Jordan

THE LEFT HAND OF DARKNESS
ISBN 9780441478125
1 @ 24.99                   24.99 A
Member discount             -2.50


BLUEBERRY SCONE
2 @ 3.25                     6.50 B


PANTRY GROCERY ITEM
1 @ 4.99                     4.99 N

Merchandise                    36.48
Discounts                      -2.50
Net merchandise                33.98
State Tax 6.00%                 1.74
Food Tax 1.25%                  0.08
TOTAL                          35.80

Visa **** 4821                 30.00
Cash tendered                  10.00
CHANGE                          4.20

A State tax
B State and food tax
N No tax applied


Eligible items returnable through Aug 17.
Item condition and policy restrictions apply.


   [ secure receipt lookup QR ]

    Thank you for shopping.


This version removes the somewhat internal Cash applied, avoids calling the grocery item legally exempt without evidence, and keeps the tax summary tied to actual applied components.

14. Recommended receipt design principles
The receipt specification should ultimately establish these governing rules:

Receipts are derived only from completed or posted records.

Printing never determines whether a transaction completed.

Printer failure does not reverse completion.

Historical monetary and classification facts are never recalculated.

Receipt document labels are derived; they do not impose transaction types.

Tax markers describe completed tax treatment, not merely tax-category assignment.

Return eligibility and deadlines come from completed-line snapshots.

Price overrides and discounts remain visibly distinct.

Received and refunded tenders are presented separately.

Stored-value issuance, redemption, refund, and reversal remain distinct.

Gift-receipt tokens are opaque and line-scoped.

Reprints are auditable but create no commercial activity.

The structured receipt is independent of printer width or technology.

Sensitive internal identifiers and authorization details never print.

Conclusion
The original proposal is a strong foundation and already reflects most of ShelfStack’s governing decisions. Its content hierarchy and special-receipt handling are substantially correct.

The most important improvements are to:

separate receipt semantics from formatting and printer mechanics;

derive receipt labels rather than creating transaction types;

make tax markers reflect actual completed tax treatment;

snapshot return and legal receipt policy;

distinguish print retries from true reprints;

define a structured, versioned receipt document contract;

treat standalone payment-terminal output as separate from the ShelfStack receipt.

With those changes, this can become the basis of a formal POS Receipt and Printing Specification, rather than remaining only a formatting proposal.