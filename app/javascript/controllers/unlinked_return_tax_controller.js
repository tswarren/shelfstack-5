import { Controller } from "@hotwired/stimulus"

// Filters tax-basis options by return source. Server remains authoritative.
export default class extends Controller {
  static targets = ["source", "basis", "explicitTax"]

  connect() {
    this.sync()
  }

  sync() {
    const source = this.sourceTarget.value
    const allowExternal = source === "external_receipt"
    Array.from(this.basisTarget.options).forEach((option) => {
      if (option.value === "external_receipt_tax") {
        option.hidden = !allowExternal
        option.disabled = !allowExternal
      }
    })
    if (!allowExternal && this.basisTarget.value === "external_receipt_tax") {
      this.basisTarget.value = "current_configured_rules"
    }
    if (this.hasExplicitTaxTarget) {
      this.explicitTaxTarget.hidden = this.basisTarget.value !== "external_receipt_tax"
    }
  }
}
