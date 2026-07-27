# L7 capture batch — 2026-07-27 (PR #150 remediations)

**Commit (pre-push):** remediations on `feat/phase-11-layout` (uncommitted at capture time; attach SHA after push)  
**Browser:** Playwright via MCP Docker (`host.docker.internal:3000`)  
**OS:** macOS (host) / Docker MCP browser  
**Zoom:** 100%  
**Fixture:** demo org bootstrap (`admin` / seeded Ready session open)

## Captured in session

| Scenario | Viewport | Status |
| --- | --- | --- |
| Ready normal | 1366×768 | Reviewed in agent session (composition matches Ready wireframe regions) |
| Ready normal | 1024×768 | Captured in browser session |
| Product lookup overlay | 1366×768 | Captured in browser session |

## Still required before L7 Accepted / merge

Attach the full [screenshots/README.md](screenshots/README.md) set to [#150](https://github.com/tswarren/shelfstack-5/pull/150), including Transaction 1/8/20-line, Tender unpaid/settled, Recovery, Receipt, and remaining overlays. Score each gate Accepted / Needs refinement / Fail.

**L2 Must criteria remain merge blockers** even if non-Must polish is deferred.

## Financial review checkpoints (not L7 substitutes)

- **F1 Unlinked return basis:** tax basis + cost MAC→estimate→block; valuation/approval tests green
- **F2 No Sale:** `PosNoSaleEvent` log-only; session race / idempotency / no cash movement tests green
