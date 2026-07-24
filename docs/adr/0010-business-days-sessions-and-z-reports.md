# ADR-0010: Distinguish Business Days, Sessions, Devices, Drawers, and Z Reports

**Status:** Accepted  
**Reporting-date policy:** v1 accepted in OD-001 / [architectural-locks](../implementation/architectural-locks.md#business--reporting-date-v1-choice) — store `reporting_date` explicitly; assignment = operating date selected when the business day is opened (defaults to store-local calendar date at open). Later policy refinements remain possible without rewriting history.

## Context

ShelfStack must support:

* store-wide operating periods;  
* several registers;  
* several independent sessions;  
* cash and card-only sessions;  
* physical drawers that may move among devices;  
* session close reports;  
* store-wide close reports;  
* operations crossing midnight.

The term “business day” may be interpreted as:

* an operating date;  
* an actual elapsed period;  
* a sequential Z-report cycle.

Choosing only a calendar date or only a Z number would lose important information.

## Decision

ShelfStack will represent the following as distinct concepts:

* business day;  
* reporting date;  
* business-day Z number;  
* POS session;  
* session Z number;  
* POS device;  
* cash drawer.

## Business day

A business day is the store-wide operational and reporting period.

It records:

* store;  
* reporting date;  
* sequential close number;  
* opening timestamp;  
* closing timestamp;  
* reconciliation timestamp;  
* status;  
* opening and closing users.

Suggested statuses are:

```
open
closed
reconciled
```

Only one business day may be open per store.

A business day cannot close while any session remains open.

## Reporting date

The reporting date is stored explicitly on the business day.

**v1 assignment (accepted):** the operating date selected when the business day is opened (defaults to the store-local calendar date at open). See OD-001 and architectural locks.

ShelfStack will not derive the reporting date later solely from timestamps. A later store-configured rule may refine assignment without rewriting historical business days that already store `reporting_date`.

## Business-day Z number

The business-day close receives a sequential store-specific Z-report number.

The Z number identifies the sequence of completed store-wide closes.

The reporting date and Z number are both retained.

Example:

```
Business date: 2026-07-17
Opened at:     2026-07-17 08:41
Closed at:     2026-07-18 00:23
Z number:      0001842
```

## POS session

A POS session is an accountability period within one business day.

A session records:

* business day;  
* store;  
* POS device;  
* optional cash drawer;  
* responsible user;  
* opening and closing timestamps;  
* opening cash;  
* expected cash;  
* counted cash;  
* variance;  
* reconciliation;  
* session Z number where used.

A session may be:

* cash-enabled;  
* card-only.

A card-only session may have no cash drawer.

## POS device

A POS device is a physical or logical register assigned to one store.

It is not itself:

* a cashier;  
* a session;  
* a cash drawer;  
* a business day.

## Cash drawer

A cash drawer is the physical till used for cash accountability.

A drawer:

* belongs to one store;  
* may be associated with different POS devices over time;  
* may have at most one active cash-enabled session.

## Session and business-day Z reports

Session and business-day Z reports remain distinct.

```
Business-day Z 1842
├── Session Z 5511
├── Session Z 5512
└── Session Z 5513
```

A business-day Z consolidates all session activity while retaining the individual session breakdowns.

## Close versus reconciliation

Closing records that operations ended.

Reconciliation records that expected and external or counted totals were reviewed.

A session or business day may close with a documented variance and be reconciled later.

## Consequences

### Benefits

* Supports operations crossing midnight.  
* Preserves both date-based and sequential reporting.  
* Separates physical devices and drawers.  
* Supports several sessions in one business day.  
* Supports card-only sessions.  
* Preserves original cash counts and later recounts.

### Costs

* More operational records are required.  
* Reporting must understand both session and business-day attribution.  
* Sequential numbering requires safe store-level generation.

## Alternatives considered

### Identify the business day only by calendar date

Rejected because business days may cross midnight and the date rule remains a policy choice.

### Identify the business day only by Z number

Rejected because ordinary date-based reporting still requires an explicit business date.

### Treat device, session, and drawer as one record

Rejected because they have different lifecycles and accountability meanings.

## Governing rules

* One business day may be open per store.  
* Every session belongs to one business day.  
* Every active device belongs to one store.  
* Every drawer belongs to one store.  
* A drawer has at most one active cash-enabled session.  
* All sessions must close before the business day closes.  
* Closing and reconciliation remain separate.  
* Both reporting date and sequential Z number are retained.

## Related decisions

Reporting-date assignment for v1 is accepted (OD-001). Session/Business-Day Z persistence and reconciliation delivery are Phase 7 — see [phase-07-reporting-and-reconciliation-v1.md](../implementation/decisions/phase-07-reporting-and-reconciliation-v1.md).

## Related domains

* Stores and Operational Control  
* Point of Sale  
* Reporting and Reconciliation