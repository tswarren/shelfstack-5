# ADR-0016: Treat Standalone Card Activity as Operator-Confirmed External Records

**Status:** Accepted
**Date:** July 22, 2026
**Clarifies:** ADR-009, *Complete POS Transactions Atomically and Idempotently*

## Context

ShelfStack initially supports card payments through standalone payment terminals.

The terminal and its payment processor operate independently from ShelfStack. ShelfStack:

* does not initiate card authorizations;
* does not receive processor callbacks;
* cannot confirm settlement;
* cannot void or refund a terminal transaction;
* cannot include the external card operation in its database transaction.

The cashier performs the payment, refund, or void directly on the external terminal and then records the relevant result in ShelfStack.

Earlier Phase 6 designs attempted to compensate for this separation with durable preparation records, commercial fingerprints, orphan states, replacement operations, reconciliation states, and recovery workflows.

These mechanisms attempted to model circumstances such as:

* an authorization succeeding while the ShelfStack request fails;
* a late authorization arriving after an abandoned workflow;
* a duplicate or retried form submission;
* a refund amount changing after terminal processing;
* an externally reversed payment whose internal correction does not complete;
* an operator leaving a recovery workflow unfinished.

Although these risks are possible, ShelfStack has no direct knowledge of the terminal operation. A reference entered into a form does not independently prove that an external payment occurred, settled, failed, or was voided.

Modeling every possible terminal discrepancy as internal payment state would cause ShelfStack to behave like a payment-processing system even though it does not control the processor.

That complexity is disproportionate to the standalone-terminal scope.

At the same time, once an operator has successfully entered configured terminal references that ShelfStack accepts, discarding that activity because the tender cannot attach to the intended transaction would leave unaudited terminal work inside the store’s POS workflow. A narrow durable recovery state is therefore required without adopting a full payment-lifecycle engine.

## Decision

ShelfStack will treat standalone card activity as **operator-confirmed external activity recorded for transaction and audit purposes**.

The external terminal remains authoritative for whether a card payment, refund, or void occurred.

ShelfStack is authoritative for the card activity that an authorized operator successfully records in ShelfStack.

ShelfStack will not manage the external card transaction lifecycle, processor settlement, or discrepancy reconciliation.

ShelfStack **will** durably track operator-entered terminal activity after configured references validate, even when that activity cannot be attached to the intended transaction. The selected durable recovery status is `void_required`.

That recovery state is a small internal lifecycle. It is not preparation staging, an orphan queue, a replacement workflow, or processor reconciliation.

## Responsibility boundary

ShelfStack is responsible for:

* displaying the amount the operator should process;
* recording an operator-confirmed payment or refund when it attaches;
* storing configured terminal reference values;
* retaining validated but unattachable card activity as `void_required`;
* blocking completion, suspension, and cancellation while `void_required` tenders remain;
* associating a refund with an original tender when applicable;
* requiring confirmation before removing or voiding a recorded card tender;
* requiring confirmation of external reversal before completing a post-void;
* preventing recorded tenders from completing with an internally unsettled transaction;
* preserving completed POS history through explicit reversing records;
* preventing storage of full card numbers or sensitive authentication data.

The operator is responsible for:

* processing the correct amount on the standalone terminal;
* determining whether the terminal operation succeeded;
* entering the correct terminal references;
* manually voiding an incorrect or cancelled terminal transaction;
* manually processing card refunds;
* confirming external voids for `void_required` and authorized card tenders;
* verifying that every original card payment has been reversed before submitting a post-void;
* following store procedures when terminal activity cannot be reconciled with ShelfStack.

ShelfStack does not guarantee recovery of every external operation performed during:

* an abandoned form that never successfully submitted validated references;
* a browser refresh before validated references were accepted;
* a network interruption before validated references were accepted;
* an operator error;
* a terminal operation that was never entered into ShelfStack.

## Retention boundary

Durable ShelfStack records for standalone card activity depend on how far recording progressed:

| Situation | Durable ShelfStack record |
| --- | --- |
| Form never submitted | None |
| Amount or references fail initial validation | None |
| References validate and tender attaches | `authorized` tender |
| References validate but attachment fails | `void_required` tender |
| External void is confirmed | Same tender becomes `voided` |
| Terminal activity never entered into ShelfStack | Outside ShelfStack’s knowledge |

Entered reference values do not, by themselves, prove that an external financial event occurred. After configured references validate, however, ShelfStack treats the operator-entered activity as retained work that must be resolved rather than discarded.

## Tender references

Card tender references use the existing Tender Type reference configuration.

Each tender type may define:

* reference 1 label;
* reference 1 mask or validation rule;
* reference 1 requirement;
* reference 2 label;
* reference 2 mask or validation rule;
* reference 2 requirement.

The current standalone-card configuration may, for example, use:

* reference 1: authorization code;
* reference 2: terminal reference.

ShelfStack stores those values through the tender’s ordinary reference fields. It will enforce the selected tender type’s configured requirements. It will not introduce a separate card-specific reference vocabulary or an additional rule that conflicts with the tender-type configuration.

Optional card brand and last-four information may be stored for display or audit purposes. Full card numbers, expiration dates, security codes, track data, and other sensitive payment credentials must never be stored.

## Card payment workflow

The normal standalone-card payment workflow is:

1. ShelfStack calculates and displays the amount due.
2. The cashier processes an amount on the external terminal.
3. The cashier confirms that the terminal approved the payment.
4. The cashier enters the configured terminal reference values.
5. ShelfStack validates those references against the tender type.
6. When the tender attaches, ShelfStack records an authorized card tender.
7. The POS transaction completes when all settling tenders complete and settle the transaction.

Partial card tenders are permitted when:

* the amount is positive; and
* the amount does not exceed the remaining received balance, unless the tender type explicitly permits over-tender.

A successful card-tender record represents an operator assertion that the corresponding external payment was approved.

ShelfStack does not independently verify that assertion with the processor.

## Unattachable validated card activity

When configured references validate but the card payment or refund cannot attach to the intended transaction—for example because the transaction is no longer open, the amount no longer fits, or another business rule blocks attachment—ShelfStack must retain that activity as a `void_required` tender.

A `void_required` tender:

* retains amount, direction, tender type, and validated references;
* does not participate in settlement;
* blocks transaction completion, suspension, and cancellation until resolved;
* remains resolvable even if the owning transaction’s status later changes;
* remains resolvable even if the tender type is later deactivated or payment-/refund-disabled;
* transitions to `voided` only after explicit confirmation that the external terminal void occurred.

Retries of the same validated activity must not create duplicate durable recovery records.

This mechanism exists so ShelfStack does not discard operator-entered terminal activity after references have been accepted. It is not a processor-reconciliation product and does not invent preparation, orphan, or replacement tables.

## Voiding or removing a recorded card payment

An authorized card tender must not be silently deleted.

To remove or void a recorded authorized card tender:

1. ShelfStack warns that the external terminal transaction must be voided separately.
2. The operator manually voids the transaction on the external terminal.
3. The operator explicitly confirms the external void in ShelfStack.
4. The operator may enter an external void reference and reason.
5. ShelfStack marks the tender voided and retains its original amount and references.

The same external-void confirmation resolves a `void_required` tender to `voided`.

The confirmation records who confirmed the void and when.

ShelfStack does not itself void the external transaction.

## Card refund workflow

A card refund is a new external terminal operation.

The normal workflow is:

1. ShelfStack calculates the refund amount.
2. ShelfStack displays relevant information from the original transaction and tender, including:

   * receipt number;
   * transaction date;
   * original tender amount;
   * remaining refundable amount;
   * original configured terminal references.
3. The operator processes the refund on the standalone terminal.
4. The operator enters the new refund transaction’s configured references.
5. ShelfStack validates those references and, when attachable, records an authorized refund tender.

The new refund tender stores the references for the **new refund operation**. Original payment references are displayed for guidance but are not copied into the new refund tender.

A refund tender may reference an original received tender.

Where no original tender is selected, or the refund destination differs from the normal original-tender policy, the existing refund-exception approval rules apply.

ShelfStack may enforce the remaining refundable amount of an identified original tender. It does not otherwise attempt to model processor-side refund capacity or settlement.

If validated refund references cannot attach, the same `void_required` recovery rule applies.

## Post-void workflow

A post-void creates an explicit reversing transaction for a previously completed POS transaction.

For a transaction containing completed card tenders, the normal sequence is:

1. The post-void reason and authorization are approved.
2. ShelfStack displays each original card tender and its recorded references.
3. The operator manually voids or refunds each original card payment on the external terminal.
4. The operator explicitly confirms that each required external reversal occurred.
5. The operator may enter the external void or refund reference and a note.
6. ShelfStack creates the reversing transaction.

The reversing tender records or links the operator-supplied external reversal information.

ShelfStack does not create a processor void, refund, or settlement reversal.

Approval of the post-void authorizes the ShelfStack correction and the associated operational procedure. It does not prove that the external processor accepted the reversal.

## Failed or abandoned card recording

Before configured references validate, ShelfStack creates no durable card tender solely because a form contained plausible terminal references.

In that case ShelfStack should clearly tell the operator:

* the card activity was not recorded in ShelfStack;
* the operator must verify the result on the external terminal;
* any successful external operation must be manually voided before trying again.

After configured references validate, the retention boundary above applies. Unattachable activity becomes `void_required` rather than being discarded.

Stores may document an exceptional terminal discrepancy that never entered ShelfStack through operational notes, audit procedures, or a later reconciliation process.

Phase 6 does not require preparation tables, orphan queues, replacement workflows, or a processor-reconciliation product.

## Internal transaction atomicity

ADR-009 continues to govern ShelfStack’s internal completion operation.

Within ShelfStack, completion remains:

* atomic;
* idempotent;
* lock-protected;
* responsible for finalizing tenders, inventory, stored value, taxes, costs, classifications, receipt numbers, and transaction status together.

The external terminal operation remains outside that database transaction.

For standalone terminals, “confirm before complete” means that the operator confirms and records the successful external card activity before ShelfStack completes the POS transaction.

It does not mean that ShelfStack guarantees atomicity between the terminal and the internal transaction.

A transaction with unresolved `void_required` card activity is not ready to complete, suspend, or cancel.

## Idempotency boundary

POS transaction completion remains idempotent as required by ADR-009.

Ordinary interface protections may also be used for card-tender submission, including:

* disabling repeated submission;
* transaction row locking;
* recalculating the remaining balance before recording;
* rejecting a tender that no longer fits the transaction as an attachable authorized tender.

Retained `void_required` activity must itself be idempotent so retries do not create duplicate recovery records.

Phase 6 does not require a broad card-lifecycle state machine to recover every repeated, delayed, or abandoned request. The `void_required` recovery state is intentionally narrow.

A future generic request-idempotency mechanism may be added without changing the external-terminal responsibility boundary established by this ADR.

## Reconciliation boundary

Phase 6 provides auditable records for card activity successfully recorded in ShelfStack, including authorized, `void_required`, and voided tenders.

Phase 6 does not provide a processor-reconciliation product.

The following are deferred to Phase 7 or a future integrated-payments capability:

* processor settlement reconciliation;
* chargebacks;
* processor disputes;
* duplicate terminal transactions not recorded in ShelfStack;
* terminal batches;
* processor fees;
* externally successful operations never entered into ShelfStack;
* automated matching of processor reports to ShelfStack tenders;
* acceptance or write-off of external payment discrepancies;
* integrated authorization, capture, refund, and void APIs.

Operational investigation may use:

* completed POS transactions;
* card tender references;
* `void_required` and voided tenders;
* refund tender links;
* post-void reversal records;
* audit events;
* processor reports.

A dedicated reconciliation model should be introduced only when ShelfStack has concrete reporting or processor-integration requirements.

## Consequences

### Benefits

* The card workflow matches the actual standalone-terminal operating model.
* Cashier actions remain understandable and direct.
* Validated but unattachable terminal activity is not discarded.
* Payment, refund, tender void, recovery, and post-void behavior are auditable.
* ShelfStack does not claim processor knowledge it does not possess.
* Phase 6 avoids a premature payment-lifecycle engine while retaining a narrow recovery state.
* Completion atomicity remains strong for all internal ShelfStack effects.
* Future integrated payments can introduce stronger guarantees behind a different implementation boundary.

### Costs

* ShelfStack cannot automatically detect whether an operator forgot to record a terminal transaction.
* A browser or network failure before validated references are accepted may still require manual terminal verification.
* An external card operation may exist without a matching ShelfStack tender.
* `void_required` is a small internal lifecycle that operators must resolve before continuing.
* Operational discrepancies may require manual investigation.
* Stores must train staff to void unsuccessful or abandoned terminal operations.
* Processor reconciliation remains a later capability.
* Standalone terminals cannot provide true end-to-end payment atomicity.

## Alternatives considered

### Model the complete external card lifecycle in ShelfStack

Rejected for the standalone-terminal implementation.

Without processor integration, ShelfStack cannot reliably determine authorization, capture, settlement, void, refund, or reversal state. A detailed internal lifecycle would primarily model operator assertions and inferred conditions rather than processor facts.

### Create durable preparation, orphan, replacement, and reconciliation records

Rejected for Phase 6 because the resulting state machine was disproportionate to operator-confirmed tracking.

The additional records created more failure combinations without giving ShelfStack authority over the external terminal.

### Persist every failed form submission containing terminal references

Rejected because entered references do not prove that an external operation occurred until ShelfStack has validated them under the tender-type rules.

Persisting every unvalidated attempt as financial workflow state could create misleading audit records and block otherwise valid POS activity.

### Discard validated references when attachment fails

Rejected because that leaves operator-entered terminal activity unaudited inside an active POS workflow after ShelfStack has already accepted the references.

### Store no card references

Rejected because stores need practical audit and lookup information for refunds, post-voids, receipts, and reconciliation.

### Require integrated payments before supporting cards

Rejected because independent stores commonly use standalone terminals, and operator-confirmed card recording is sufficient for the initial ShelfStack scope.

## Governing rules

* The external terminal is authoritative for external card activity.
* ShelfStack is authoritative for card activity successfully recorded in ShelfStack.
* ShelfStack does not initiate, void, refund, settle, or verify standalone-terminal transactions with the processor.
* Card reference labels and requirements come from the selected tender type.
* Full card data and sensitive authentication data must never be stored.
* Partial card tenders are allowed within the remaining transaction balance.
* After configured references validate, unattachable card activity must be retained as `void_required`.
* `void_required` tenders are non-settling and block completion, suspension, and cancellation until resolved.
* External-void confirmation transitions `void_required` or authorized card tenders to `voided`.
* Resolution of `void_required` must remain possible after transaction-status or tender-type configuration changes.
* Card refunds record new terminal references and may link to an original received tender.
* Post-void requires approval and explicit confirmation that each original card payment was externally reversed.
* Completed POS records remain immutable; corrections use returns or reversing post-void transactions.
* Preparation tables, orphan queues, replacement workflows, and processor reconciliation are outside the Phase 6 boundary.
* Internal POS completion remains atomic and idempotent under ADR-009.

## Related ADRs

* ADR-008: Keep Completed POS Transactions Immutable and Use Explicit Corrections
* ADR-009: Complete POS Transactions Atomically and Idempotently
* ADR-010: Distinguish Business Days, Sessions, Devices, Drawers, and Z Reports
* ADR-011: Separate Permissions, Numeric Authority, and Approval Events

## Related domains

* Point of Sale
* Stored Value
* Reporting and Reconciliation
* Authorization and Approvals
