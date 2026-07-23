# Recommended X/Z Report Family

ShelfStack should use **one shared report grammar** across four reports:

| Report | Scope | State effect | Primary purpose |
| :---- | :---- | ----: | :---- |
| **Session X** | One open session | None | Current activity and expected drawer position |
| **Session Z** | One closed session | Closes session | Final operational close and cash accountability |
| **Business-Day X** | Entire open business day | None | Store-wide progress and session supervision |
| **Business-Day Z** | Entire closed business day | Closes business day | Final store close with session tie-out |

The X reports are live and recalculated. The Z reports are persisted close records. Session and business-day Z reports remain distinct, and closing remains separate from later reconciliation.

## 1\. Shared design principles

### Use the same section order

Every X or Z report should follow this structure:

1. Report identity  
2. Commercial activity  
3. Tax  
4. Stored-value activity  
5. Transaction settlement  
6. Tenders  
7. Cash accountability  
8. Activity counts  
9. Exceptions  
10. Close or generation information

This makes the four reports easy to compare.

### Show activity layers separately

The report must not collapse everything into one “sales” number.

It should separately show:

* gross sales;  
* price-override variance;  
* discounts;  
* customer returns;  
* post-void effects;  
* net sales;  
* tax;  
* stored-value issuance and reloads;  
* tender received;  
* tender refunded;  
* net tender.

Tender reports should show received and refunded amounts, not only net activity. Stored-value issuance is not ordinary sales revenue, and customer returns remain separate from post-voids.

### Use line activity, not transaction labels

A mixed transaction can contain sales and returns. Therefore:

* sales totals come from completed sale lines;  
* return totals come from completed return lines;  
* post-void totals come from reversing lines;  
* transaction counts are secondary operational statistics.

A transaction should not need to be classified as only a sale, return, or exchange.

### Keep compact print and electronic detail different

The printed report should contain operational totals and a concise exception summary. The on-screen report can provide drill-downs into transactions, departments, tenders, approvals, and exceptions. The reporting specification already anticipates that not every audit detail belongs on the compact printed Z report.

---

# 2\. Session X Report

## Purpose

The Session X report answers:

> What has happened in this session so far, and what should the drawer currently contain?

It must prominently state that:

* the session remains open;  
* totals may change;  
* no count has been finalized;  
* the report is not a Z report;  
* generating it does not close or reconcile anything.

## On-screen layout

```
┌──────────────────────────────────────────────────────────────┐
│ SESSION X                          LIVE · SESSION OPEN        │
│ Main Street Books · Register 2 · Drawer D02                  │
│ Session 005511 · Business Date July 21, 2026                 │
│ Opened 8:42 AM by Morgan Lee                                 │
│ Generated 3:18 PM by Alex Kim                                │
└──────────────────────────────────────────────────────────────┘

┌────────────────┐ ┌────────────────┐ ┌────────────────┐
│ Net Sales                 │ │ Transaction              │ │ Tender Net     │
│ $2,099.50                 │ │ Total                    │ │ $2,347.20      │
│                           │ │ $2,347.20                │ │ ✓ Ties         │
└────────────────┘ └────────────────┘ └────────────────┘

┌────────────────┐ ┌────────────────┐ ┌────────────────┐
│ Expected Cash             │ │ Completed                │ │ Exceptions     │
│ $552.20                   │ │ Receipts                 │ │ 8              │
│ Not counted               │ │ 47                       │ │ 2 need review  │
└────────────────┘ └────────────────┘ └────────────────┘
```

Below the summary cards:

### Commercial activity

| Measure | Amount |
| :---- | ----: |
| Gross sales | $2,450.00 |
| Price-override variance | $32.00 |
| Discounts | ($185.50) |
| Customer returns | ($120.00) |
| Post-void net effect | ($45.00) |
| **Net sales** | **$2,099.50** |

Price-override variance is informational and is **not** deducted again from gross sales. It explains the difference between regular and approved selling prices.

### Tax

| Component | Taxable basis | Collected | Refunded/reversed | Net |
| :---- | ----: | ----: | ----: | ----: |
| State Sales Tax | $1,925.00 | $115.50 | ($6.30) | $109.20 |
| Food/Beverage Tax | $325.00 | $4.06 | ($0.56) | $3.50 |
| Other components | — | $12.00 | ($2.00) | $10.00 |
| **Total tax** |  | **$131.56** | **($8.86)** | **$122.70** |

The electronic view should allow drilling into taxable, exempt, and zero-rated basis where applicable.

### Stored-value line activity

| Activity | Gift card | Store credit | Trade credit | Total |
| :---- | ----: | ----: | ----: | ----: |
| Issued | $100.00 | — | — | $100.00 |
| Reloaded | $25.00 | — | — | $25.00 |
| Other liability additions | — | — | — | — |
| **Customer-funded stored value** |  |  |  | **$125.00** |

### Settlement bridge

This section explains why tender does not equal net sales:

| Settlement component | Amount |
| :---- | ----: |
| Net sales | $2,099.50 |
| Net tax | $122.70 |
| Stored value issued/reloaded | $125.00 |
| **Transaction total settled** | **$2,347.20** |

### Tender summary

| Tender | Received | Refunded/restored | Change | Net settlement |
| :---- | ----: | ----: | ----: | ----: |
| Cash | $800.00 presented | ($40.00) | ($12.80) | $747.20 |
| Card | $1,500.00 | ($50.00) | — | $1,450.00 |
| Stored value | $150.00 redeemed | $0.00 restored | — | $150.00 |
| **Total** |  |  |  | **$2,347.20** |

Use a visible tie-out:

```
Transaction total settled     $2,347.20
Net completed tenders         $2,347.20
Difference                         $0.00  ✓
```

### Cash accountability

```
Opening cash                         $300.00
Cash received                         800.00
Less cash refunds                     (40.00)
Less change given                     (12.80)
Additional float                        0.00
Paid in                                20.00
Paid out                              (15.00)
Safe drops                           (500.00)
Cash pickups                            0.00
Transfers, net                          0.00
Corrections, net                        0.00
                                      -------
EXPECTED DRAWER CASH                  $552.20
```

A cashier’s Session X may hide expected cash when blind counting is enabled. A manager-authorized X report can show it.

### Open-work section

Session X should additionally show unfinished operational work:

```
Open transaction assigned to session       1
Unresolved tender activity                 0
Suspended transactions created             3
Suspended transactions recalled            1
Active reservations retained               7
```

Open and suspended work should not be included in completed financial totals.

---

# 3\. Session Z Report

## Purpose

The Session Z report answers:

> What completed during this session, what should the drawer contain, what was counted, and what variance existed when the session closed?

It should use the same sections as Session X, with these additions:

* close timestamp and closing user;  
* session Z number;  
* final closing count;  
* variance;  
* count or recount history;  
* exception summary;  
* reconciliation status;  
* immutable report identity.

## Recommended screen header

```
┌──────────────────────────────────────────────────────────────┐
│ SESSION Z 005511                    FINAL CLOSE REPORT        │
│ Main Street Books · Register 2 · Drawer D02                  │
│ Business Date July 21, 2026                                 │
│ Opened 8:42 AM · Closed 5:06 PM                              │
│ Responsible user: Morgan Lee                                │
│ Closed by: Morgan Lee                                       │
│ Reconciliation: NOT YET RECONCILED                          │
└──────────────────────────────────────────────────────────────┘
```

## Cash close section

```
Expected drawer cash                  $552.20
Closing count                         $551.20
                                      -------
CASH VARIANCE                          ($1.00)

Variance status: Explanation required
Explanation: Minor counting difference
Reviewed by: Pending
```

The original count must remain available if a manager performs a recount:

| Count | User | Time | Amount | Variance |
| :---- | :---- | :---- | ----: | ----: |
| Closing count | Morgan Lee | 5:04 PM | $551.20 | ($1.00) |
| Manager recount | Alex Kim | 5:17 PM | $552.20 | $0.00 |

The recount does not overwrite the original count. Cash variance is `counted cash − expected cash`.

## Exception summary

The printed Z should show concise counts and amounts:

| Exception | Count | Amount/variance |
| :---- | ----: | ----: |
| Price overrides | 3 | $32.00 variance |
| Manual discounts | 4 | $75.00 |
| No-receipt returns | 1 | $18.00 |
| Post-voids | 1 | ($45.00) sales effect |
| Cancelled transactions | 2 | — |
| Removed lines | 5 | $64.50 provisional |
| No-sale drawer openings | 1 | — |
| Receipt reprints | 1 | — |
| Cash variance | 1 | ($1.00) |

The electronic report should link each row to its underlying records.

## Compact 3-1/8-inch Session Z example

A 48-column thermal format could look like this:

```
              MAIN STREET BOOKS
              SESSION Z REPORT

Session Z: 005511
Business Date: 2026-07-21
Register: REG-02       Drawer: D02
Responsible: Morgan Lee
Opened:  2026-07-21 08:42
Closed:  2026-07-21 17:06
Status: CLOSED / NOT RECONCILED
Generated: 2026-07-21 17:06

-----------------------------------------------
COMMERCIAL ACTIVITY
Gross Sales                         $2,450.00
Price Override Variance                32.00
Discounts                            (185.50)
Customer Returns                     (120.00)
Post-Void Effect                      (45.00)
                                   ----------
NET SALES                           $2,099.50

Units Sold                                68
Units Returned                             4
Units Reversed                             1
Net Units                                 63

-----------------------------------------------
TAX
State Sales Tax                       $109.20
Food/Beverage Tax                        3.50
Other Tax                               10.00
                                   ----------
NET TAX                               $122.70

-----------------------------------------------
STORED VALUE ACTIVITY
Gift Cards Issued                     $100.00
Gift Cards Reloaded                     25.00
Store Credit Issued                      0.00
Trade Credit Issued                      0.00
                                   ----------
VALUE FUNDED                          $125.00

NET SALES                           $2,099.50
NET TAX                               122.70
VALUE FUNDED                          125.00
                                   ----------
TRANSACTION TOTAL                   $2,347.20

-----------------------------------------------
TENDERS
Cash Received                         $800.00
Cash Refunded                          (40.00)
Change Given                           (12.80)
Cash Net                               747.20

Card Received                        1,500.00
Card Refunded                          (50.00)
Card Net                             1,450.00

Stored Value Redeemed                  150.00
Stored Value Restored                    0.00
Stored Value Net                       150.00
                                   ----------
NET TENDERS                         $2,347.20
TENDER DIFFERENCE                       $0.00

-----------------------------------------------
CASH ACCOUNTABILITY
Opening Cash                          $300.00
Cash Received                          800.00
Cash Refunded                          (40.00)
Change Given                           (12.80)
Paid In                                 20.00
Paid Out                               (15.00)
Safe Drops                            (500.00)
                                   ----------
EXPECTED CASH                         $552.20
COUNTED CASH                           551.20
                                   ----------
VARIANCE                               ($1.00)

-----------------------------------------------
EXCEPTIONS
Price Overrides             3       $32.00
Manual Discounts            4       $75.00
No-Receipt Returns          1       $18.00
Post-Voids                  1       $45.00
Cancelled Transactions      2
No-Sale Drawer Opens        1
Receipt Reprints            1

Completed Receipts: 47
First Receipt: 0012841
Last Receipt:  0012888

-----------------------------------------------
Closed by: Morgan Lee
Reconciliation: PENDING
Report Version: SZ-1
Report ID: SZ-005511
             FINAL CLOSE REPORT
```

Cost and margin should not appear on this standard cashier-facing printout. They can appear on a permission-controlled manager view.

---

# 4\. Business-Day X Report

## Purpose

The Business-Day X answers:

> How is the entire store performing right now, and what is the state of each session?

Its top-level commercial sections mirror the Session X, but it must add a **session status table**.

## Suggested screen layout

```
┌──────────────────────────────────────────────────────────────┐
│ BUSINESS-DAY X                     LIVE · DAY OPEN           │
│ Main Street Books                                            │
│ Business Date July 21, 2026                                 │
│ Opened 8:30 AM by Alex Kim                                  │
│ Generated 3:24 PM                                           │
└──────────────────────────────────────────────────────────────┘
```

### Store summary cards

```
Net Sales              $8,421.70
Transaction Total      $9,036.12
Net Tenders            $9,036.12  ✓
Open Sessions          2
Closed Sessions        1
Expected Cash          $1,284.60
Exceptions             17
```

### Session status

| Session | Register | Drawer | Responsible user | Status | Net sales | Expected cash | Variance |
| :---- | :---- | :---- | :---- | :---- | ----: | ----: | ----: |
| 005510 | REG-01 | D01 | Alex Kim | Closed | $3,250.30 | $482.40 | $0.00 |
| 005511 | REG-02 | D02 | Morgan Lee | Open | $2,099.50 | $552.20 | — |
| 005512 | REG-03 | — | Shared/card only | Open | $3,071.90 | — | — |

The Business-Day X should permit drill-down into any Session X or completed Session Z.

### Close blockers

A prominent panel should show:

```
BUSINESS DAY CANNOT CLOSE

2 sessions remain open:
- Session 005511 · REG-02
- Session 005512 · REG-03

1 unresolved active transaction
0 unresolved tenders
```

A business day cannot close while any session remains open.

---

# 5\. Business-Day Z Report

## Purpose

The Business-Day Z answers:

> What was the final store-wide activity for the business day, and do all session close reports tie to the store totals?

It should contain:

1. consolidated commercial totals;  
2. consolidated tax;  
3. consolidated stored-value activity;  
4. consolidated tenders;  
5. consolidated cash;  
6. session-by-session breakdown;  
7. exception summary;  
8. tie-out validation;  
9. reconciliation status.

## Session roll-up

| Session Z | Register | Responsible user | Net sales | Net tenders | Expected cash | Counted cash | Variance |
| :---- | :---- | :---- | ----: | ----: | ----: | ----: | ----: |
| 005510 | REG-01 | Alex Kim | $3,250.30 | $3,410.22 | $482.40 | $482.40 | $0.00 |
| 005511 | REG-02 | Morgan Lee | $2,099.50 | $2,347.20 | $552.20 | $551.20 | ($1.00) |
| 005512 | REG-03 | Shared | $3,071.90 | $3,278.70 | — | — | — |
| **Total** |  |  | **$8,421.70** | **$9,036.12** | **$1,034.60** | **$1,033.60** | **($1.00)** |

Card-only sessions have no drawer values.

## Required integrity checks

The Business-Day Z should show explicit checks:

```
Session net sales sum        $8,421.70
Business-day net sales       $8,421.70
Difference                       $0.00  ✓

Session net tenders sum      $9,036.12
Business-day net tenders     $9,036.12
Difference                       $0.00  ✓

Session expected cash sum    $1,034.60
Business-day expected cash   $1,034.60
Difference                       $0.00  ✓
```

An internal mismatch should prevent the day from being marked successfully closed until the integrity problem is resolved.

## Compact Business-Day Z example

```
              MAIN STREET BOOKS
           BUSINESS-DAY Z REPORT

Business Date: 2026-07-21
Business-Day Z: 0001842
Opened:  2026-07-21 08:30
Closed:  2026-07-21 22:18
Closed by: Alex Kim
Status: CLOSED / NOT RECONCILED

-----------------------------------------------
STORE TOTALS
Gross Sales                         $9,675.20
Discounts                            (702.50)
Customer Returns                     (381.00)
Post-Void Effect                     (170.00)
                                   ----------
NET SALES                           $8,421.70
Net Tax                               489.42
Stored Value Funded                   125.00
                                   ----------
TRANSACTION TOTAL                   $9,036.12
NET TENDERS                         $9,036.12
DIFFERENCE                              $0.00

-----------------------------------------------
SESSION SUMMARY
Z 005510  REG-01
Net Sales                          $3,250.30
Net Tenders                        $3,410.22
Cash Variance                          $0.00

Z 005511  REG-02
Net Sales                          $2,099.50
Net Tenders                        $2,347.20
Cash Variance                         ($1.00)

Z 005512  REG-03  CARD ONLY
Net Sales                          $3,071.90
Net Tenders                        $3,278.70

-----------------------------------------------
CASH SUMMARY
Opening Cash                         $600.00
Cash Received                       2,100.00
Cash Refunded                        (110.00)
Change Given                          (34.40)
Paid In                                45.00
Paid Out                              (25.00)
Safe Drops                         (1,540.00)
                                   ----------
EXPECTED CASH                       $1,035.60
COUNTED CASH                        $1,034.60
                                   ----------
TOTAL CASH VARIANCE                    ($1.00)

-----------------------------------------------
EXCEPTION SUMMARY
Price Overrides            11      $108.00
Manual Discounts            8      $145.00
No-Receipt Returns           2       $36.00
Post-Voids                   3      $170.00
Cancelled Transactions       5
No-Sale Drawer Opens         2
Receipt Reprints             3

Sessions Included: 3
All Sessions Closed: YES
Internal Tie-Outs: PASSED
Reconciliation: PENDING

Report Version: BDZ-1
Report ID: BDZ-0001842
             FINAL CLOSE REPORT
```

---

# 6\. Recommended differences between X and Z

| Feature | X | Z |
| :---- | :---- | :---- |
| Status banner | Live / preliminary | Final close report |
| Can totals change? | Yes | No |
| Closes anything? | No | Yes |
| Z number | No | Yes |
| Count required | No | Session Z: yes for cash session |
| Expected cash | Yes, permission-dependent | Yes |
| Counted cash | Usually absent | Yes |
| Variance | Usually absent | Yes |
| Reconciliation status | Not applicable | Pending, exception, or reconciled |
| Open work | Prominent | Must be resolved before close |
| Reprint semantics | New current snapshot | Reprint original persisted report |
| Report version | Optional | Required |
| Drill-down source | Current posted records | Persisted close plus source records |

---

# 7\. Design decisions I recommend locking

## Include a settlement bridge

The report should explicitly bridge:

```
Net Sales
+ Net Tax
+ Stored Value Issued or Reloaded
= Transaction Total
= Net Tenders
```

Without this bridge, gift-card issuance makes the tender report appear not to match sales.

## Treat cash settlement and drawer movement separately

Cash has two relevant values:

* **tender settlement:** cash applied to transactions;  
* **drawer movement:** cash physically received minus refunds and change.

The report should retain both. Otherwise change given can either disappear or be counted twice.

## Make department breakdown optional on thermal reports

Department reporting is useful, but a large department table can make the Z report excessively long.

Recommended behavior:

* screen: always available;  
* full-page PDF: include by default;  
* thermal Session Z: optional;  
* thermal Business-Day Z: configurable summary;  
* CSV: full detail.

## Restrict margin and cost

A standard cashier X/Z should omit:

* COGS;  
* gross margin;  
* unit costs.

A manager report may add them when the user possesses the appropriate cost and margin permissions. The reporting specification anticipates cost and margin access being more restricted than ordinary sales access.

## Persist Z reports as structured data

Do not store only rendered receipt text. Persist:

* report identity;  
* source session or business day;  
* report-definition version;  
* totals and section data;  
* source cutoff;  
* generation user and timestamp;  
* original rendered format where useful.

This allows exact reprints while preserving searchable and exportable report data.  