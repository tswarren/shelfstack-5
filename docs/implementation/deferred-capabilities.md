# Deferred Capabilities

**Status:** Explicitly out of implementation scope until designed  
**Delivery phase label:** Phase 8 in [roadmap.md](roadmap.md)

Do not scaffold speculative tables, statuses, or services for these areas. When work approaches one of them, implement only what the current task requires, document assumptions, and open a design question.

## Deferred list

| Capability | Notes |
| --- | --- |
| Detailed buyback | Acquisition workflow; not an ordinary return |
| Inventory counts | Dedicated count documents and posting |
| Inter-store transfers | Changes authoritative store ownership |
| Complete return-to-vendor (RTV) | Beyond disposition flags / deferred unit statuses |
| Full customer CRM | Beyond Phase 5 opaque `customer_reference`; no Customer master in Phase 5 |
| Customer notifications platform | After customer domain design |
| Automated replenishment / forecasting | Manual replenishment review and stock_replenishment demand in Phase 5 |
| Full frontlist / ONIX campaign management | Product-backed frontlist_selection in Phase 5; full campaign tooling deferred |
| Vendor EDI / acknowledgements / cascading | Phase 5 preserves structural hooks; full lifecycle deferred — see [phase-05-ordering-scope-and-future-lifecycle-boundaries.md](phase-05-ordering-scope-and-future-lifecycle-boundaries.md) |
| Customer holds / special-order product beyond requests | Extend Product Requests carefully |
| Reusable tax exemptions | Transaction-specific exemptions may exist earlier |
| Selected-line / selected-component tax exemptions | Phase 4b is `whole_transaction` coverage only; later `pos_tax_exemption_applications` |
| Tax-inclusive pricing | Initial release is tax-exclusive (ADR-0014) |
| Jurisdiction-configurable line-level tax rounding | v1 uses hybrid transaction-component rounding (ADR-0014) |
| Advanced promotions | `promotion_id` may remain nullable until designed |
| Loyalty | Separate domain |
| Stored-value replacement, transfer, expiration | Ledger baseline comes first (Phase 6) |
| Accounting export batches | Department GL codes may remain provisional |
| Integrated payment processing | Standalone card tender stub first |
| Offline POS | Requires dedicated design |
| Optional physical shelf-location tracking | Must not fragment store inventory |
| Weighted / decimal quantities | Integer quantities for initial release |
| Multi-tenant SaaS | Single-organization installation |

## Unit status values reserved but not implemented early

`inventory_units.status` may include deferred-capable values such as `rtv` and `in_transfer` without implementing those workflows. Do not build transfer or RTV documents until designed.

## Related

- [System Overview §1.9](../architecture/system-overview.md)
- [AGENTS.md §3](../../AGENTS.md)
- [roadmap.md](roadmap.md)
