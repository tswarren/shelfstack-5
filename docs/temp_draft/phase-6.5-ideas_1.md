> **Planning status:** Non-governing draft. Accepted thin Phase 6.5 scope lives in [../implementation/phases/phase-06.5-cashier-workspace.md](../implementation/phases/phase-06.5-cashier-workspace.md). Items here that expand beyond that plan (separate Review stage, printers, etc.) are deferred or rejected unless the phase plan is revised.

Static QA review: aligning ShelfStack POS with the cashier workflow map
ShelfStack already has many of the underlying POS records and services needed for the workflow map: open/suspend/recall/cancel/complete transactions, scan resolution, mixed sale/return support, stored-value lines/tenders, card tender void handling, post-void, session/business-day operations, and scanner focus support. The main gap is that the cashier UI still exposes these as many record/forms/details panels instead of one guided operational path.

1. Add an explicit Ready → Build → Review → Tender → Complete → Receipt state model to the POS UI
Current app/views/register/show.html.erb and app/views/pos_transactions/show.html.erb have pieces of the workflow, but the transaction screen jumps straight into a combined build/payment/actions layout. There is no explicit cashier-facing progression through Build, Review, Tender, Complete, and Receipt. As a result, tender controls are always visible beside line-entry controls, and “Complete transaction” is available in the same area as normal editing actions.

Suggested task
Introduce cashier-facing POS workflow stages

Start task
2. Separate Review and Tender from the Build workspace
app/views/pos_transactions/show.html.erb currently renders _scan_form, _line_items, _secondary_actions, _totals, _tenders, _tender_entry, and _transaction_actions together. That conflicts with the mapped workflow where build is scanner-first, review gathers warnings/blockers/approvals, and tender becomes a focused settlement state.

Suggested task
Split the POS workspace into build, review, and tender panels

Start task
3. Make scan-to-start possible from the register-ready screen
The workflow map expects “scan an item to start automatically” from Ready. The current ready screen in app/views/register/show.html.erb only offers a “New transaction” button when a session exists and no transaction is open. Scanning is only available after creating a transaction via _scan_form.

Suggested task
Support scan-to-start from Register Ready

Start task
4. Replace form-heavy exceptional operations with contextual cashier modes
The current build panel embeds stored-value issue/reload, open-ring, and linked return as separate <details> sections in _scan_form.html.erb. This keeps functionality available, but it does not feel like temporary cashier modes. It also makes the ordinary sale screen visually compete with exception workflows.

Suggested task
Convert exceptional POS actions into contextual entry modes

Start task
5. Improve line selection and line-level action grouping
Line actions are currently rendered as a separate <details> block inside each row via _line_actions.html.erb. This exposes many nested forms per line and makes the cashier search through repeated controls. The workflow map expects: select a line first, then show applicable line actions in one stable contextual area.

Suggested task
Create a selected-line action panel for POS line edits

Start task
6. Add a cashier-facing validation/review summary with warnings, approvals, and blockers
Pos::ValidateCompletionReadiness appears to exist, and completion failures can be shown via flash, but the UI does not provide a structured Review stage that distinguishes informational messages, warnings, approvals, and blockers. Cashiers therefore discover problems at completion time or by interpreting scattered alerts.

Suggested task
Add a POS review checklist for warnings, approvals, and blockers

Start task
7. Make tender mode visually and operationally distinct
The current _tender_entry.html.erb renders cash, card, stored-value tender, and refund forms as multiple <details> panels, while line editing remains visible on the same page unless tenders make the transaction non-editable. The workflow map expects a focused Tender mode with remaining amount, available tender methods, tender list, and clear lock/reversal messaging.

Suggested task
Create a focused tender workspace

Start task
8. Add explicit receipt actions after completion
Completed transactions currently show “Transaction complete,” receipt number, tender summary, “Back to register,” and optional “Post-void” in app/views/pos_transactions/show.html.erb. The mapped Receipt state expects print/display receipt, gift receipt, reprint after printer failure, and “Next transaction” as the dominant action. The current primary action is “Back to register,” which is close but not cashier-optimized.

Suggested task
Build a receipt-stage action panel

Start task
9. Improve suspended transaction recall so material changes are reviewed as a stage
There is already recall support, including Pos::RecallTransaction, Pos::RefreshRecalledTransaction, and _recall_summary.html.erb. However, the mapped workflow expects “Refresh and Review” before returning to Build, with material changes clearly confirmed rather than compressed into flash or a passive summary.

Suggested task
Turn recall refresh changes into a confirmation step

Start task
10. Add receipt lookup as a first-class Register Ready action
The workflow map expects lookup of completed receipts from Ready, including starting returns and post-voids from transaction lookup. The current register view shows suspended transactions and session details, but receipt lookup is not a prominent ready-state action. Linked return lookup exists only inside an already-open transaction.

Suggested task
Add completed receipt lookup to Register Ready

Start task
11. Make approval prompts modal/contextual instead of embedded repeated fields
The workflow map treats approval as an interruption that returns the cashier to the exact point of action. Current views render shared/approval_fields inside multiple forms: line discount, price override, tax override, transaction discount, tax exemption, cash movement, and refund exceptions. This works mechanically, but it makes approvals feel like form data entry rather than a contextual approver authentication/review step.

Suggested task
Create a contextual POS approval prompt

Start task
12. Strengthen recovery messaging for failed completion
The completion workflow should leave the cashier certain whether the sale completed and what to do if external card approval exists. PosTransactionsController#complete redirects back with an alert on failure, and _void_required_tenders.html.erb handles some card tender cleanup. But there is no dedicated recovery state that explains completion status, external tender status, and next required action.

Suggested task
Add explicit POS completion recovery state

Start task
