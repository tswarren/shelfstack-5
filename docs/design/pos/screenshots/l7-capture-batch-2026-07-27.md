# L7 capture batch — 2026-07-27 (MVP remediations)

**Branch:** `feat/phase-11-layout`  
**Browser:** Playwright via MCP Docker (`host.docker.internal:3000`)  
**OS:** macOS (host) / Docker MCP browser  
**Zoom:** 100%  
**Fixture:** demo org (`admin` / open Ready session)

## Captured this session (both viewports where noted)

| Scenario | 1366×768 | 1024×768 | Notes |
| --- | --- | --- | --- |
| Ready normal | Captured | Captured | Scan + supporting actions + session rail |
| Product lookup overlay | Captured | — | Frame-loaded dialog on Ready |
| Transaction one-line | Captured | Captured | After Open Ring first-valid-work |
| Transaction eight-line | Captured | Captured | Open-ring lines; L2 composition check |
| Tender unpaid | Captured | Captured | Positive balance before tender |
| Tender settled | Captured | Captured | Cash amount covering net |
| Receipt cash / change | Captured | Captured | Post-complete receipt surface |

In-repo copies (pulled from MCP container `focused_hoover` `/home/node`):

```text
ready/ready-normal-1366x768-review.png
ready/ready-normal-1024x768-review.png
ready/ready-with-open-txn-1366x768-review.png
overlays/overlays-product-lookup-1366x768-review.png
transaction/transaction-one-line-1366x768-review.png
transaction/transaction-one-line-1024x768-review.png
transaction/transaction-eight-lines-1366x768-review.png
transaction/transaction-eight-lines-1024x768-review.png
tender/tender-unpaid-1366x768-review.png
tender/tender-unpaid-1024x768-review.png
tender/tender-settled-1366x768-review.png
tender/tender-settled-1024x768-review.png
receipt/receipt-cash-change-1366x768-review.png
receipt/receipt-cash-change-1024x768-review.png
```

Attach these to [#150](https://github.com/tswarren/shelfstack-5/pull/150) from this directory.

## Still incomplete vs full [screenshots/README.md](README.md) set

- Ready staged Customer / suspended / ambiguous / no day / no session
- Transaction twenty-line, selected-line commands, warning/blocker, mixed return, individual unit
- Tender partial card / split / net refund / forced Tender
- Recovery `void_required`
- Additional receipt variants and remaining overlays

**L7 status:** Needs refinement until the residual set is attached and scored. Core Ready / Transaction / Tender / Receipt / Product lookup evidence at both primary viewports is present for review.

## L2 Must criteria (still merge blockers)

Single ordinary line scroller, stable selected-line commands, pinned totals/progression CTA, keyboard line selection, eight-line 1366 composition — score on the eight-line captures above.

## Financial checkpoints (code remediations)

- **F1:** source/tax matrix; merchandise+tax no-receipt authority; two-step cost confirm; unlinked Discard disabled
- **F2:** session-scoped No Sale idempotency; same payload replay / changed payload conflict; audited-event-only
