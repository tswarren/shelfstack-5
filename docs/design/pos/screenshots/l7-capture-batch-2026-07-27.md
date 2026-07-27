# L7 capture batch — 2026-07-27 (reduced MVP merge gate)

**Branch:** `feat/phase-11-layout`  
**Browser:** Playwright via MCP Docker (`host.docker.internal:3000`)  
**OS:** macOS (host) / Docker MCP browser  
**Zoom:** 100%  
**Fixture:** demo org (`admin` / open Ready session)

## Reduced critical set (both viewports)

| Scenario | 1366×768 | 1024×768 | Notes |
| --- | --- | --- | --- |
| Ready normal | Captured | Captured | Scan + supporting actions + session rail |
| Product lookup overlay | Captured | Captured | Frame-loaded dialog on Ready; closable |
| Transaction one-line | Captured | Captured | After Open Ring / scan first-valid-work |
| Transaction eight-line | Captured | Captured | Open-ring lines; L2 composition check |
| Selected-line commands | Captured | Captured | Qty / Remove / Discount / Price (+ Tax) in command bar |
| Tender unpaid | Captured | Captured | Positive balance before tender |
| Tender settled | Captured | Captured | Cash amount covering net |
| Recovery `void_required` | Captured | Captured | Card mismatch → Recovery workspace |
| Receipt cash / change | Captured | Captured | Post-complete receipt surface |

In-repo copies (pulled from MCP container `focused_hoover` `/home/node`):

```text
ready/ready-normal-1366x768-review.png
ready/ready-normal-1024x768-review.png
ready/ready-with-open-txn-1366x768-review.png
overlays/overlays-product-lookup-1366x768-review.png
overlays/overlays-product-lookup-1024x768-review.png
transaction/transaction-one-line-1366x768-review.png
transaction/transaction-one-line-1024x768-review.png
transaction/transaction-eight-lines-1366x768-review.png
transaction/transaction-eight-lines-1024x768-review.png
transaction/transaction-selected-line-commands-1366x768-review.png
transaction/transaction-selected-line-commands-1024x768-review.png
tender/tender-unpaid-1366x768-review.png
tender/tender-unpaid-1024x768-review.png
tender/tender-settled-1366x768-review.png
tender/tender-settled-1024x768-review.png
recovery/recovery-void-required-1366x768-review.png
recovery/recovery-void-required-1024x768-review.png
receipt/receipt-cash-change-1366x768-review.png
receipt/receipt-cash-change-1024x768-review.png
```

Attach these to [#150](https://github.com/tswarren/shelfstack-5/pull/150) from this directory.

## L2 Must criteria (capture score)

Scored from eight-line + selected-line + Recovery captures:

| Criterion | Score | Evidence |
| --- | --- | --- |
| One ordinary line scroller | Accepted | Transaction eight-line / selected-line |
| Pinned totals + primary CTA | Accepted | Totals rail + Tender CTA remain visible |
| Keyboard / click line selection | Accepted | Selected-line command bar with Qty/Remove/Discount/Price |
| No clipped primary controls | Accepted | Both viewports; Recovery Void confirmed visible |
| Overlay bounded and closable | Accepted | Product lookup @1366 and @1024 |

Residual exhaustive matrix (twenty-line, staged customer, all tender/receipt variants, etc.) stays deferred.

## Still incomplete vs full [screenshots/README.md](README.md) set

- Ready staged Customer / suspended / ambiguous / no day / no session
- Transaction twenty-line, warning/blocker, mixed return, individual unit
- Tender partial card / split / net refund / forced Tender
- Additional receipt variants and remaining overlays

**L7 status (reduced MVP):** **Accepted** — human review confirmed 2026-07-27 on [#150](https://github.com/tswarren/shelfstack-5/pull/150). Exhaustive matrix remains deferred.

## Financial checkpoints (code remediations)

- **F1:** source/tax matrix; cumulative no-receipt authority; two-step cost confirm with reviewed cost fields; PIN not replayed/logged; unlinked Discard disabled
- **F2:** session-scoped No Sale idempotency; same payload replay / changed payload conflict; audited-event-only
