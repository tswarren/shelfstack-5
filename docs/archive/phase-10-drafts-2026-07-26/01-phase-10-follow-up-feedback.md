This version addresses the substantive concerns well. I would schedule it after a few targeted corrections rather than restructure it again. 

## 1. Add `Catalog::BuildProductSummary` to the implementation scope

The show-page specification now calls for several derived summaries:

* individually tracked unit summary;
* stale-reservation warning;
* open demand count;
* most recent PO and receipt;
* last received date;
* links to owning records.

Those values should not be assembled through queries inside views. Yet `Catalog::BuildProductSummary` is absent from **Touches**, and the service section from the earlier proposal is no longer present.

I would add:

```markdown
**Touches:** ... `app/services/catalog/build_product_summary.rb`,
`app/services/catalog/create_product.rb` ...
```

And add a short section:

```markdown
## Summary-service boundary

`Catalog::BuildProductSummary` may be extended with the bounded,
capability-gated summary values required by §4.

Views must not issue new catalog, inventory, purchasing, receiving,
or request queries directly. Summary additions must:

- remain store-scoped through `Current.store`;
- respect the existing `capabilities` contract;
- avoid loading complete ledgers or operational collections;
- return only the counts, latest records, and links required by the
  product summary surface;
- avoid N+1 queries.
```

This is the most important remaining change. Without it, implementation could drift into controller- or view-level querying despite the otherwise clear domain boundary.

## 2. Define the exact capability for each new summary

Section 3 correctly says existing `caps.*` checks must survive the restructure. Section 4 introduces some information that may not have an obvious existing gate.

For example:

| Information             | Likely gate                                         |
| ----------------------- | --------------------------------------------------- |
| Stock quantities        | `stock_view`                                        |
| Last received date      | `receipt_view` or existing stock-summary visibility |
| Unit summary            | `stock_view`                                        |
| Inventory cost          | `inventory_cost_view`                               |
| Vendor sources          | `vendor_source_view`                                |
| Vendor identity/details | `vendor_view`                                       |
| PO counts and latest PO | `purchase_order_view`                               |
| Latest receipt          | `receipt_view`                                      |
| Demand count            | `request_view`                                      |
| Purchasing cost         | `purchasing_cost_view`                              |

I would add that table—or the application’s actual equivalent—to §3 or §4. This removes ambiguity such as whether someone with stock access but no receiving access may see the last receipt.

The exit criterion currently says each moved field must retain its old gate. That does not completely cover **new aggregate fields** that did not previously exist.

## 3. Tighten the merchandise-class enhancement mechanics

The single canonical field is the right decision. I would specify how the enhanced cascade avoids becoming additional successful form controls:

```markdown
The flat hierarchical select remains the canonical form control.

When enhanced:

- the cascade selects are presentation controls and do not have
  submitted `name` attributes;
- cascade changes synchronize the canonical
  `product[merchandise_class_id]` select;
- the canonical select may be visually hidden but remains present;
- enhancement failure leaves the canonical select visible and usable;
- JavaScript must never create a second successful field with the
  same parameter name.
```

Also change:

> includes the currently assigned class even if inactive

to:

> includes the currently assigned class and the ancestor path required to represent it, even when one or more of those records are inactive.

An inactive assigned minor class cannot initialize a three-level cascade correctly when an inactive parent has been excluded.

## 4. Reconcile the tabs’ server-rendered and JavaScript-added ARIA contracts

Section 5 says Stimulus adds the tab roles and behavior. Section 12 says request/view tests verify `aria-controls` and `aria-labelledby`.

That is not necessarily contradictory, but the ownership should be explicit:

```markdown
Server-rendered HTML provides stable anchor and panel IDs plus the
data relationships needed for enhancement. It does not apply tab
roles or hide panels.

Stimulus applies:

- `role="tablist"`, `role="tab"`, and `role="tabpanel`;
- `aria-selected`;
- roving `tabindex`;
- `aria-controls` and `aria-labelledby`, if they are not rendered
  safely in the baseline markup;
- inactive-panel hiding.
```

Then revise the tests accordingly:

* request/view tests verify IDs, fragments, content, links, and enhancement data attributes;
* system tests verify the applied roles and synchronized ARIA state.

This prevents request tests from asserting markup that only exists after Stimulus connects.

## 5. Remove or define “stale reservation”

The Inventory tab includes:

> a stale-reservation warning where relevant

But the proposal does not define stale, and ShelfStack intentionally has no automatic expiration for suspended reservations.

Unless there is already an accepted age threshold, I would either remove this from Phase 10 or replace it with:

> an old-reservation indication when the existing reporting/configuration policy already classifies a reservation as old; Phase 10 introduces no new expiration or stale-age policy.

Otherwise, a display phase would inadvertently decide a reservation-governance policy.

Similarly, only promise a “link to full inventory history” when such a route currently exists. Where it does not, use:

> link to the applicable existing inventory surface, where available.

The phase should not quietly acquire a new inventory-history screen.

## 6. Fix the language-default assumption

Section 10.3 refers to:

> the organization's ordinary default (normalized `eng`)

That is safe only if ShelfStack already stores or otherwise defines an organization-level language default. If it does not, this conflicts with the no-schema-change boundary.

Use one of these:

```markdown
language when it equals the existing configured catalog-language
default;
```

or, if there is no configuration:

```markdown
language when it is the normalized application default `eng`;
Phase 10 does not introduce organization-specific language settings.
```

Do not describe it as organization-specific unless the organization actually owns that setting.

## 7. Express the new-form default as a controller/form-object state

This wording is slightly fragile:

> no submitted params

A controller action can receive unrelated query parameters, and relying on generic parameter presence is easy to implement incorrectly.

I would replace it with:

```markdown
`sellable: true` is assigned only when constructing the initial
new-product form in `ProductsController#new`.

`ProductsController#create` validation rerenders reuse the submitted
product and variant values and do not reapply the default.
```

Also clarify the parameter model:

* If there are separate product and standard-variant sellability fields, each defaults independently to true.
* If the form exposes one combined control, state that the submitted value becomes the requested final state for both records.

The existing text establishes the desired result but not how the form represents two values.

## 8. Choose one identifier-warning binding mechanism

The current wording allows either:

> normalized value (or a warning fingerprint)

That leaves an implementation decision inside an otherwise precise contract. I would choose the simpler rule:

```markdown
On resubmission, the server re-normalizes the currently submitted
identifier. Warning acceptance is valid only when:

- `accept_identifier_warning=true`; and
- the re-normalized current identifier is still a warning; and
- its normalized value matches the normalized value presented in the
  warning confirmation.

Client-supplied warning state is never accepted without rerunning
normalization.
```

A signed fingerprint is unnecessary unless warning metadata is too complex to reproduce. The important part is that the server reruns normalization rather than trusting hidden state.

## 9. Make the sticky condition testable

“Sufficiently tall” and “narrow/constrained” are understandable design language but weak acceptance criteria.

Either name the actual design breakpoints:

```markdown
The action bar becomes sticky at the existing desktop breakpoint
when viewport height is at least the documented minimum.
```

or define concrete CSS conditions during Gate 10b and record them in the design guide.

The exact pixel/rem values do not need to appear in the phase plan now, but the exit criterion should require that the chosen conditions be documented and covered by responsive screenshots or system checks.

## 10. Slightly revise 10e’s double-submission promise

The clarification about not deduplicating Creator entities by name is correct. I would make the UI guarantee even narrower:

```markdown
The submit control is disabled while a creator request is in flight,
and Turbo responses replace the invoking assignment row rather than
append blindly. Replayed presentation responses must not insert
multiple assignment rows.

Cross-request Creator-creation idempotency is not introduced by this
phase.
```

That distinguishes protection against ordinary double clicks and duplicated DOM insertion from financial-grade request idempotency.

## What I would leave unchanged

I would retain:

* the full Phase 10 designation;
* the explanation of why store resolution is not being redesigned;
* the capability-preservation framing;
* the show page as a summary surface;
* the anchor-first tab baseline;
* the single canonical merchandise-class field;
* the explicit price-link state machine;
* 10e as a should-have rather than a core gate;
* the price display matrix;
* the gate-specific exit criteria and test-layer split;
* the scheduling checklist.

With the summary-service boundary and the few contract clarifications above, this is implementation-ready.
