import { Controller } from "@hotwired/stimulus"

// Summarizes selected linked-return lines (Phase 11.2D).
export default class extends Controller {
  static targets = ["checkbox", "quantity", "row", "summary", "defaultReason", "defaultDisposition"]

  connect() {
    this.syncSummary()
  }

  syncSummary() {
    if (!this.hasSummaryTarget) return

    let selected = 0
    let merchandiseCents = 0

    this.rowTargets.forEach((row) => {
      const checkbox = row.querySelector('[data-linked-return-selector-target="checkbox"]')
      const quantity = row.querySelector('[data-linked-return-selector-target="quantity"]')
      if (!checkbox?.checked || !quantity) return

      selected += 1
      const qty = Number.parseInt(quantity.value, 10) || 0
      const unit = Number.parseInt(quantity.dataset.unitPriceCents || "0", 10) || 0
      merchandiseCents += qty * unit
    })

    const money = (merchandiseCents / 100).toLocaleString(undefined, {
      style: "currency",
      currency: "USD"
    })
    this.summaryTarget.textContent =
      selected === 0
        ? "Selected 0 lines"
        : `Selected ${selected} line${selected === 1 ? "" : "s"} · refund merchandise ${money}`
  }
}
