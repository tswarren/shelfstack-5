# Phase 7 — Reporting and Reconciliation

**Status:** Not started  
**Depends on:** Phase 4c minimum; Phases 5–6 for full coverage  
**Preferred delivery order:** after Phase 6.5 cashier workspace ([phase-06.5-cashier-workspace.md](phase-06.5-cashier-workspace.md)) when schedule allows; 6.5 does not hard-gate reporting schema  
**Governing docs:** [reporting-and-reconciliation](../../domains/reporting-and-reconciliation.md); [architectural-locks](../architectural-locks.md)

## Goal

Produce operational and financial reports from posted facts without rewriting source records or reinterpreting completed history from current master data.

## Reporting sources

| Report class | Primary sources |
| --- | --- |
| Historical sales, returns, tax, classifications, cost, margin | Completed POS snapshots |
| Inventory quantities and valuation movements | Inventory ledger + current balances |
| Stored-value history and liability | Stored-value ledger |
| Open order and receiving operations | Current purchase orders and receipts |
| Active or stale holds | Current reservation records |
| Cash accountability | Sessions, cash movements, counts, business days |

## Capabilities

- Sales, returns, post-voids, discounts, price-override variance
- Tax and tender reporting
- Session and business-day X and Z reports
- Cash variance; close and reconcile as separate events
- Inventory and margin reporting
- Purchasing and receiving operational reports
- Stored-value liability reporting
- Reconciliation adjustments that document differences without mutating completed transactions
- Exception and approval reporting

## Exit criteria

- [ ] Completed sale report unchanged after product/department rename
- [ ] Operational open-PO report reads current purchasing records
- [ ] Reconciliation adjustment does not alter original POS or ledger source rows
- [ ] Business day cannot close while a session remains open

## Out of scope

- Accounting export batches ([deferred](../deferred-capabilities.md))
- Rewriting history to match current catalog

## Related

- [../roadmap.md](../roadmap.md)
- [phase-04-point-of-sale.md](phase-04-point-of-sale.md)
- [phase-05-supply-and-demand.md](phase-05-supply-and-demand.md)
- [phase-06-corrections-and-stored-value.md](phase-06-corrections-and-stored-value.md)
