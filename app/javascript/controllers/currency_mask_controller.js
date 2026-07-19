import { Controller } from "@hotwired/stimulus"

// Fixed-point currency entry: digits are cents; display shows $X.XX.
// Hidden field (optional) receives integer cents for form submit.
export default class extends Controller {
  static targets = ["display", "cents"]
  static values = { amountCents: { type: Number, default: 0 } }

  connect() {
    this.render()
  }

  handleInput(event) {
    const digits = event.target.value.replace(/\D/g, "")
    this.amountCentsValue = digits === "" ? 0 : parseInt(digits, 10)
    this.render()
  }

  handlePaste(event) {
    event.preventDefault()
    const text = (event.clipboardData || window.clipboardData).getData("text")
    const normalized = text.replace(/[$,\s]/g, "")
    if (/^\d+(\.\d{1,2})?$/.test(normalized)) {
      const cents = Math.round(parseFloat(normalized) * 100)
      this.amountCentsValue = cents
    } else {
      const digits = normalized.replace(/\D/g, "")
      this.amountCentsValue = digits === "" ? 0 : parseInt(digits, 10)
    }
    this.render()
  }

  render() {
    const cents = this.amountCentsValue || 0
    const formatted = (cents / 100).toLocaleString(undefined, {
      style: "currency",
      currency: "USD"
    })
    if (this.hasDisplayTarget) {
      this.displayTarget.value = formatted
      this.displayTarget.setAttribute("aria-valuetext", formatted)
    }
    if (this.hasCentsTarget) {
      this.centsTarget.value = String(cents)
    }
  }
}
