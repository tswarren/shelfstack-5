# Proposed Addition — Cash Movement Identity

**Target document:** `docs/domains/point-of-sale.md`, § Cash accountability
**Status:** Proposed (not yet accepted)
**Domain:** Point of Sale (Cash Movement is already POS-owned; this adds identity to an existing record, it does not introduce a new one)

---

## 1. Problem

`point-of-sale.md` currently defines Cash Movement *types* (`additional_float, safe_drop, cash_pickup, paid_in, paid_out, correction, transfer_in, transfer_out`) but no public identity for an individual posted movement. There is no store-scoped number a cashier can write on an envelope, a manager can search for during reconciliation, or a printed slip can reference.

This surfaced while scoping POS document printing: a Cash Movement Slip needs something to print in place of the internal database ID, and nothing in the domain currently provides it. Rather than invent that inside a printing spec, it belongs here, reviewed as what it is — a small extension of an existing POS-owned record.

## 2. Proposal

Every successfully posted Cash Movement receives a generated, store-scoped **Cash Movement Number**, assigned atomically at posting — the same pattern already used for Receipt Number (POS Transaction) and Z-Report Number (Business Day).

Suggested format: `{store_code}-CM-{sequence}`, e.g. `MAIN-CM-000184`. The exact format is a presentation choice for whoever implements this; the identity guarantees below are the part that needs to be settled.

### Identity guarantees

- Unique within the Store.
- Assigned only on successful posting — a failed or rejected movement never consumes a number.
- Does not reset by Session or Business Day.
- Immutable once assigned; unchanged on reprint or historical lookup.
- Not reused.

### Relationship to the existing reference field

The Cash Movement Number is a system-generated identity, distinct from the existing user-entered reference field (invoice number, deposit-bag ID, payee, etc.). Both remain visible wherever the movement is displayed:

```
Movement: MAIN-CM-000184
Reference: Invoice 10482
```

## 3. Suggested schema

```ruby
# Store-scoped sequence, following the existing Receipt/Z-report numbering pattern
add_column :stores, :next_cash_movement_sequence, :bigint, null: false, default: 1

# Identity fields on the movement itself
add_column :pos_cash_movements, :movement_sequence, :bigint
add_column :pos_cash_movements, :movement_number, :string

add_index :pos_cash_movements, [:store_id, :movement_sequence],
          unique: true, where: "movement_sequence IS NOT NULL"
add_index :pos_cash_movements, [:store_id, :movement_number],
          unique: true, where: "movement_number IS NOT NULL"
```

Sequence assignment should use the same locking discipline AGENTS.md already requires for Receipt numbering — deterministic locking so concurrent postings can't collide, assignment inside the posting transaction, never pre-assigned.

## 4. Proposed additions to `point-of-sale.md`

**Cash accountability section**, append:

> Every successfully posted Cash Movement receives a store-scoped, immutable Cash Movement Number, assigned atomically at posting and never reused. It is a system identity distinct from the movement's user-entered reference field.

**Invariants section**, append:

> - Cash Movement Number is assigned only at successful posting.
> - A posted Cash Movement has one Store-unique Cash Movement Number.

## 5. Open questions for review

- Does this need its own ADR, or is it routine enough to land as a domain-spec + schema-doc update (per AGENTS.md §9, an ADR is required when a decision "changes ownership of important data" or "changes a durable architectural constraint" — this arguably just extends an existing pattern rather than introducing one)?
- Exact number format — is `{store_code}-CM-{sequence}` acceptable, or should it follow whatever format Receipt Number/Z-Report Number actually use today?
- Should Approval records (where a Cash Movement requires one) get a parallel identity, or is the Cash Movement Number sufficient to look up the approval alongside it?

## 6. Non-goals

This proposal does not touch Cash Movement *types*, direction, approval requirements, or reporting — those are already defined and unaffected. It adds identity only.