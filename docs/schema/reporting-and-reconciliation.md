# Reporting and Reconciliation schema (Phase 7)

**Status:** Implementing (Phase 7a)  
**Domain:** [reporting-and-reconciliation.md](../domains/reporting-and-reconciliation.md)  
**Decision:** [phase-07-reporting-and-reconciliation-v1.md](../implementation/decisions/phase-07-reporting-and-reconciliation-v1.md)

## Tables

| Table | Purpose |
| --- | --- |
| `pos_session_z_reports` | Immutable Session Z snapshot (1:1 with closed session) |
| `business_day_z_reports` | Immutable Business-Day Z snapshot (1:1 with closed day) |
| `pos_close_card_evidences` | Close-time card evidence rows or `unavailable` exceptions |
| `reconciliations` | Canonical recon header per session or business day (7a.3) |
| `reconciliation_comparisons` | Expected vs observed (or unavailable) comparisons |
| `reconciliation_findings` | Categorized explanations attached to comparisons |
| `reconciliation_resolutions` | Append-only resolution facts (accept / explain / link / supersede) |

Store columns (Phase 7a.1): `card_reconciliation_grain`, `next_session_z_number`, `next_business_day_z_number`.

## Session / Business-Day Z

- Unique per source session or business day.
- Unique `(store_id, z_number)` within each Z namespace.
- Structured `payload` (jsonb) is authoritative for reprint; indexed cash columns on Session Z are derived summaries.
- Immutable after create (application + service-level).

## Card close evidence

- Exactly one scope: `pos_session_id` XOR `business_day_id`.
- `kind`: `merchant_slip` | `machine_batch`.
- `status`: `recorded` | `unavailable` (`unavailable` = `evidence_unavailable`).
- `precision` (when recorded): `net_only` | `received_and_refunded`.
- Unavailable rows require a reason and must not invent numeric amounts.
- Multi-row evidence is allowed; MVP UI typically records one `net_only` row.

## Reconciliation

Operational session/day status remains `open` | `closed` only. The finalized reconciliation header is authoritative. Optional denormalized `reconciled_at` / `reconciled_by_user_id` on session/day are caches written atomically with finalize.

| Table | Notes |
| --- | --- |
| `reconciliations` | `scope_type` `session` \| `business_day`; `status` `draft` \| `finalized`; finalize requires `reconciled_at`/`reconciled_by_user_id` |
| `reconciliation_comparisons` | `session_cash`, `session_merchant_slip`, `day_machine_batch`; `observed_unavailable` forbids numeric variance |
| `reconciliation_findings` | Category + explanation on a comparison |
| `reconciliation_resolutions` | Append-only; may supersede prior resolutions |

Do **not** implement a generic balance-changing `reconciliation_adjustments` table.
