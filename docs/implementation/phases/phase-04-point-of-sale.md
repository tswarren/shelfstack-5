# Phase 4 — Point of Sale

**Status:** Not started (Phase 3 complete; UX readiness gate before 4a)  
**Depends on:** Phase 3 (complete); [UX readiness gate](../../design/README.md) before 4a coding; store tax rates/rules before 4b  

**Unlocks:** Phase 5 (after 4c minimum; 4d/4e recommended before broad supply fulfilment)  
**Governing docs:** ADR-0008, ADR-0009, ADR-0010, ADR-0011, [ADR-0014](../../adr/0014-hybrid-transaction-component-tax-calculation.md); [point-of-sale](../../domains/point-of-sale.md); [architectural-locks](../architectural-locks.md); [pos-register-ui](../../design/pos-register-ui.md); [scanner-and-hotkeys](../../design/scanner-and-hotkeys.md)

## Goal

Deliver an inventory-aware POS path ending in atomic, idempotent completion for quantity-tracked and non-inventory lines, then extend to individual units and linked returns.

## UX readiness gate (prerequisite for 4a)

Phase 4a implementation may begin when POS workflow states, scan/focus rules, warning and blocker patterns, principal layout, and accessibility baseline are documented ([../../design/](../../design/README.md)), living prototypes are in place, and shared visual tokens/shell CSS exist in Rails. Visual polish is not a gate; inventing POS interaction ad hoc during 4a is.

Prototype JS and mockup calculations are non-authoritative. Server services own pricing, tax, reservation, tender, completion, and receipt numbering.

## Gates


| Gate | Name | First-sale path? |
| --- | --- | --- |
| 4a | Editable POS | Required |
| 4b | Price, tax, discounts, approvals | Required |
| 4c | Tender and atomic completion | Required — **first demo milestone** |
| 4d | Individually tracked inventory | After 4c |
| 4e | Simple linked returns | After 4c stable |

---

## Phase 4a — Editable POS

### Tables

- `business_days`
- `pos_sessions`
- `pos_session_cash_counts` (as needed for open/close prep)
- `pos_transactions`
- `pos_line_items` (pending lines)

### Behavior

- Open business day with explicit `reporting_date` (see locks).
- Open POS session on device/drawer.
- Open transaction; scan/search; resolve exact variant.
- Product lines, open-ring lines, and `none`-tracked lines.
- Provisional **quantity** reservations on add/update.
- Suspend, recall, cancel (cancel releases provisional effects; no completed posting).

### Exit

- [ ] Suspended transaction retains reservations
- [ ] Cancel releases reservations without inventory movement
- [ ] No receipt number assigned

### UX acceptance (4a)

- [ ] Register workspace follows [pos-register-ui](../../design/pos-register-ui.md) two-panel / session-context principles (coherent, not pixel-perfect)
- [ ] Dedicated scan/search field with Enter handling and focus restore per [scanner-and-hotkeys](../../design/scanner-and-hotkeys.md)
- [ ] Variant resolution UI distinguishes product vs variant; no sale without an exact variant
- [ ] Warning vs blocker presentation for reservation / availability cases
- [ ] Suspend / recall / cancel affordances match draft transaction states
- [ ] Store, session, device/drawer, and cashier context remain visible

### Must not

- Complete transactions or assign receipt numbers

---

## Phase 4b — Price, tax, discounts, approvals


### Prerequisite

Store tax rates and store tax rules with effective dates, taxable fraction, calculation order, compounding, component labels, Tax Category status, and hybrid transaction-component rounding per [ADR-0014](../../adr/0014-hybrid-transaction-component-tax-calculation.md) ([architectural-locks](../architectural-locks.md#tax-before-phase-4b)). OD-004 / OD-005 are accepted.

### Tables / records

- `pos_discounts` (including `tax_treatment`), `pos_discount_allocations`
- `pos_line_item_taxes` (with ADR-0014 snapshots)
- `pos_tax_exemptions` (transaction-scoped as needed)
- `pos_approvals`

### Behavior

- Price overrides distinct from discounts.
- Line and transaction discounts with deterministic allocations; ordinary discounts default to `reduces_taxable_base`.
- Tax per ADR-0014: per-line taxable base; round once per transaction component and direction; largest-remainder allocation; compounding uses finalized prior line components.
- Approval records with requester, approver, reason, values, authority context.
- Historical snapshots on lines (product/variant, identifiers, description, department, merchandise class, tax category, return policy, prices, cost inputs as available).

### Exit

- [ ] Tax fixtures prove aggregation residual allocation, compounding, and taxable fraction (ADR-0014)
- [ ] Discount allocation totals match line caches
- [ ] Missing store tax rule for a taxable category blocks completion
- [ ] Insufficient authority requires independent approver credentials

### UX acceptance (4b)

- [ ] Price, discount, and tax components displayed from server-resolved values (not title-based tax)
- [ ] Approval UI supports independent approver credentials and retains requester/approver context
- [ ] Snapshot-facing labels use merchandise class and tax category terminology

---

## Phase 4c — Tender and atomic completion


### Tables

- Tender types (if not seeded earlier)
- `pos_tenders`
- `pos_cash_movements` (as needed)
- Completion fields on `pos_transactions` (`receipt_number`, `completion_idempotency_key`, totals)

### Behavior

- Cash tender and standalone card stub; split tender.
- Cash counts toward session close (full Z/reconciliation can mature in Phase 7).
- **Atomic idempotent completion** coordinates: final lines, discounts, tax, tenders, reservation conversion, inventory movements, cost snapshots, receipt-number assignment, transaction completion.
- Receipt sequence: locked increment on store (v1 lock); assign only on success.
- Scope: tracking modes `quantity` and `none` only.

### First demo milestone

```text
opening inventory adjustment
→ reserve on POS line
→ tender
→ complete
→ inventory movement + cost snapshot + receipt number
```

Double-submit of the same completion request must not duplicate postings.

### Exit

- [ ] Successful completion posts inventory and assigns receipt number
- [ ] Failed completion leaves no partial inventory/tender/receipt effects
- [ ] Idempotency key prevents duplicate completion
- [ ] Quantity negative-sale warning path tested

### UX acceptance (4c)

- [ ] Tender panel and balance-due presentation; shortcuts request completion only
- [ ] Completion in-progress / failed / retry UI aligned with idempotency (no duplicate-submit ambiguity)
- [ ] Receipt presentation after successful completion
- [ ] Critical browser paths covered by system tests (not pixel snapshots)

### Must not

- Post-void sophistication (Phase 6)
- Full stored-value issuance/redemption (Phase 6)
- Individual unit sales (Phase 4d)


---

## Phase 4d — Individually tracked inventory

### Tables

- `inventory_units` (`27` identifiers)
- Reservation and line FKs to exact units

### Behavior

- Unit create/lookup; status transitions; one active reservation per unit.
- Exact acquisition cost; exact-unit completion.
- Never oversell an individual unit.

### Exit

- [ ] Exact-unit sale completes and marks unit sold
- [ ] Concurrent reserve of same unit fails safely

---

## Phase 4e — Simple linked returns

### Behavior

- Return lines linked to original completed sale lines.
- Use original completed commercial values.
- Return reason and disposition; inventory effects per disposition.
- Only after 4c is stable.

### Exit

- [ ] Linked return completes without mutating the original sale line
- [ ] Inventory disposition posts through ledger services

---

## Out of scope for Phase 4

- Vendors, purchase orders, receipts, product requests (Phase 5)
- Post-void and full stored value (Phase 6)
- Advanced promotions, offline POS, integrated payments ([deferred](../deferred-capabilities.md))

## Related

- [phase-03-quantity-inventory-bootstrap.md](phase-03-quantity-inventory-bootstrap.md)
- [../architectural-locks.md](../architectural-locks.md)
- [../../design/README.md](../../design/README.md)
- [../../design/prototypes/ui_mockup/](../../design/prototypes/ui_mockup/)

