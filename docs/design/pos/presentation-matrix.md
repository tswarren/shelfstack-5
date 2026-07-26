# POS presentation matrix

**Status:** Draft acceptance inventory  
**Parent:** [README.md](README.md)  
**Visual contract:** [visual-contract.md](visual-contract.md)

## Purpose

This matrix identifies the cashier-visible scenarios that require deliberate composition and review.

A presentation is not accepted because its controller route renders or because all operations are technically reachable. Each scenario must communicate the next task, preserve necessary context, and satisfy the supported viewport contract.

## Review dimensions

For each scenario, verify:

- dominant task and control;
- required persistent information;
- actions that must be visible;
- actions that must not appear;
- focus target;
- scrolling behavior;
- overlay behavior;
- 1366 × 768 and 1024 × 768 screenshots.

## Ready

| ID | Scenario | Dominant task | Required visible content | Primary action / focus | Must not dominate |
| --- | --- | --- | --- | --- | --- |
| R-01 | Normal Ready | Start customer work | Scan field, quantity, tiered Ready launchers (Product lookup, Start return, supporting strip), staged Customer summary, session identity | Scan field | Day/session tables, cash history, Ready-level Sale intent |
| R-02 | Staged Customer | Start work for known Customer | Scan field, Customer identity, clear/change control | Scan field | Full Customer form |
| R-03 | Suspended transactions | Start or recall work | Scan field, compact suspended-work list or launcher | Scan field; Recall is secondary | Full transaction history |
| R-04 | Active transaction exists | Resume current work | Transaction identity and Resume | Resume Transaction | New empty transaction action |
| R-05 | No business day | Satisfy operational prerequisite | Reason register is unavailable, permitted open-day action | Open Business Day | Transaction intents |
| R-06 | No session | Satisfy operational prerequisite | Open day context, permitted open-session action | Open Session | Scan-to-start |
| R-07 | No transaction permission | Explain unavailable operation | Session identity and permission-safe explanation | Store Operations or exit | Disabled transaction forms |
| R-08 | Ambiguous scan | Correct identifier | Preserved query, clear explanation, Product lookup action | Scan field or Lookup | Empty transaction |
| R-09 | Unresolved scan | Retry or search | Preserved query and non-destructive error | Scan field | Generic exception text |

### Ready launchers versus Transaction entry intents

Ready launchers and Transaction entry intents are different hierarchies (POS-UI-033).

**Ready — primary work area:** scan-to-start, Product lookup, Start return.

**Ready — supporting customer-work actions:** Customer lookup/staging, Receipt lookup, Open Ring, Stored Value issue/reload, Product Request or pickup lookup.

**Ready — register utilities (command area):** Cash Movement, No Sale, Store Operations.

Close Session, Session X detail, day close, and cash history live inside Store Operations (POS-UI-037), reached as `Ready → Store Operations → Close Session` with no extra navigation layer.

Do not show a Ready-level Sale intent. Receipt lookup is a Ready utility, not a Transaction entry intent.

**Transaction — entry intents** (only after a transaction exists):

```text
Sale | Return | Stored Value | Open Ring
```

## Transaction

| ID | Scenario | Dominant task | Required visible content | Primary action / focus | Must not appear expanded |
| --- | --- | --- | --- | --- | --- |
| T-01 | Empty open transaction | Add first line | Entry bar, empty line state, totals, Cancel/Suspend as applicable | Scan field | Tender forms |
| T-02 | One-line sale | Continue scanning | Entry bar, line, totals, Customer, readiness | Scan field | Operational day tables |
| T-03 | Eight-line sale | Continue scanning or select line | Eight visible lines where practical, totals, CTA | Scan field | Document scroll |
| T-04 | Twenty-line sale | Work within long transaction | Internally scrolling line region, persistent totals/CTA | Scan field or selected row | Summary scrolling away |
| T-05 | Selected line | Edit selected merchandise line | Selected state; Quantity, Remove, Discount, Price override; More for uncommon actions | First selected-line action when requested | Full action set on every row; generic Override label |
| T-06 | Customer attached | Continue transaction | Compact Customer identity and change/remove action | Scan field | Full Customer record page |
| T-07 | Individually tracked item | Resolve exact unit | Unit identity/status and required unit resolution | Affected line or overlay | Silent unresolved blocker |
| T-08 | Warning present | Continue with awareness | Persistent warning associated with source | Scan field unless action opened | Warning modal that blocks progress |
| T-09 | Blocker present | Resolve missing requirement | Blocker count, affected line/field, resolution link | First blocker when invoked | Enabled Tender action |
| T-10 | Discount/override approval | Obtain authorization | Affected line, requested result, approval form | Approval control | Loss of selected-line context |
| T-11 | Linked return only | Select and add return lines | Return intent, original receipt context, disposition | Return lookup or scan task | Sale-only labels |
| T-12 | Mixed sale and return | Resolve net transaction | Sale/return distinction, net total, sign-aware CTA | Scan field | Separate unrelated transactions |
| T-13 | Stored Value issue/reload | Add liability line | Operation, account identifier, amount, resulting line | Stored Value task | Redemption-as-discount language |
| T-14 | Open Ring | Add noncatalog line | Department, amount, quantity, description | Open Ring form | Product identifier requirement |
| T-15 | Product Request fulfillment | Associate line with demand | Request identity and remaining quantity | Scan/selection task | Inventory-reservation terminology |

### Transaction primary action matrix

| Situation | Label |
| --- | --- |
| Positive net, unpaid | `Tender $X` |
| Negative net, unpaid | `Issue refund $X` |
| Blockers present | `Resolve N blockers` |
| Empty / continued entry | Continue scanning emphasis; no false progression |

## Tender

| ID | Scenario | Dominant task | Required visible content | Primary action / focus | Must not appear |
| --- | --- | --- | --- | --- | --- |
| P-01 | Positive balance, no tenders | Record payment | Amount due, methods, active form, compact transaction summary | Amount field or selected method | Editable commercial lines |
| P-02 | Negative balance, no tenders | Record refund | Refund due, permitted methods, direction | Amount field | Payment-only language |
| P-03 | Partial cash | Record remaining payment | Recorded cash, change logic if applicable, remaining balance | Next tender amount | Settled completion state |
| P-04 | Partial card | Confirm and continue settlement | Card confirmation metadata, recorded tender, remaining balance | Next method/amount | Full card data fields |
| P-05 | Split tender | Complete settlement | Ordered tender list, total tendered, remaining balance | Next amount or Complete | Hidden recorded tenders |
| P-06 | Cash with change | Confirm completion | Amount due, cash presented, change due | Complete Transaction | Negative remaining balance presented as error |
| P-07 | Stored Value redemption | Confirm liability redemption | Account, available balance where permitted, redemption amount | Amount/confirm | Discount terminology |
| P-08 | Settled | Complete authoritative posting | Settled status, recorded tenders, Complete Transaction | Complete Transaction | Additional payment as dominant action |
| P-09 | Safe return to Transaction | Resume commercial editing | Clear Return to Transaction control and safety explanation | Return to Transaction | Forced-tender warning |
| P-10 | Forced Tender | Resolve tender activity | Reason editing is locked, remaining required action | Tender task | Return to Transaction |

## Recovery

| ID | Scenario | Dominant task | Required visible content | Primary action / focus | Must not appear |
| --- | --- | --- | --- | --- | --- |
| V-01 | `void_required` | Verify and resolve uncertain external activity | Affected tender, amount, masked reference, numbered steps, allowed resolutions | Primary permitted resolution | Normal tender entry, Cancel transaction |
| V-02 | Validation failure before posting | Resolve authoritative blocker | Structured reason, affected field/line, safe return path | First resolution | Generic exception dump |
| V-03 | Duplicate/already completed | Continue from completed fact | Receipt/transaction identity and safe next action | View Receipt / Next Transaction | Second completion action |
| V-04 | Session/day invalid | Restore operational validity | Closed/invalid context, permitted navigation | Store Operations or authorized recovery | Editable transaction controls |
| V-05 | Reservation stale/invalid | Re-resolve inventory fact | Affected line/unit and permitted correction | Affected line resolution | Silent automatic substitution |
| V-06 | Stored Value balance changed | Reconfirm liability action | Account, requested amount, current permitted result | Adjust or remove tender | Completion enabled |

Recovery categories remain a closed list driven by structured server outcome codes.

## Receipt

| ID | Scenario | Dominant task | Required visible content | Primary action / focus | Must remain secondary |
| --- | --- | --- | --- | --- | --- |
| C-01 | Cash completion | Give change and receipt | Complete status, receipt number, final total, change due | Next Transaction after announcement | Post-void, transaction detail |
| C-02 | Card completion | Give receipt | Complete status, receipt number, final total, tender summary | Next Transaction | Card metadata beyond permitted fields |
| C-03 | Split tender completion | Confirm final settlement | Tender summary, receipt number, final total | Next Transaction | Editable tender controls |
| C-04 | Refund completion | Give refund receipt | Refund result, receipt number, tender directions | Next Transaction | Sale-only completion wording |
| C-05 | Stored Value issuance | Provide receipt/slip | Account identifier where permitted, issuance amount, receipt | Next Transaction / Print | Revenue language |
| C-06 | Reprint | Produce marked duplicate | Original receipt number and REPRINT indication | Print/Reprint | New receipt number |
| C-07 | Returnable completed sale | Start linked return when authorized | Receipt actions and subordinate linked-return action | Next Transaction remains dominant | Return action replacing normal completion flow |
| C-08 | Post-void eligible | Access correction workflow when authorized | Subordinate correction action | Next Transaction remains dominant | Inline editable correction form |

## Overlay scenarios

| ID | Overlay | Required result |
| --- | --- | --- |
| O-01 | Product lookup | Compare operationally relevant variants and deliberately add one |
| O-02 | Customer lookup | Select, stage, or attach an existing Customer |
| O-03 | Compact Customer creation | Create minimum required record and return to POS context |
| O-04 | Receipt lookup | Resolve receipt and continue to linked return or read-only receipt |
| O-05 | Linked-return selection | Select eligible original lines and quantities |
| O-06 | Stored Value lookup | Resolve account and display only permitted balance/context |
| O-07 | Open Ring editor | Capture department, amount, quantity, and description |
| O-08 | Discount | Capture reason, amount/rule, and approval when required |
| O-09 | Price override | Capture replacement price, reason, and authorization |
| O-10 | Tax override/exemption | Capture explicit classification/exemption evidence |
| O-11 | Cash Movement | Capture type, amount, reason, and authorization |

Every overlay must restore meaningful focus and preserve the underlying authoritative workspace.

## Minimum deterministic review data

The visual review seed or fixture set should support:

- eight ordinary sale lines with varied title lengths;
- twenty ordinary sale lines;
- one return line;
- one individually tracked line;
- one discounted line;
- one line with a warning;
- one line with a blocker;
- attached and staged Customers;
- positive, negative, and zero net totals;
- cash, card, Stored Value, and split-tender examples;
- a `void_required` tender;
- a completed cash transaction with change;
- a completed split-tender transaction.

## Acceptance status

Use one of:

- **Not reviewed**
- **Needs refinement**
- **Accepted**

Do not average acceptance. Failure in task clarity, financial safety, focus flow, or supported viewport behavior blocks the scenario.
