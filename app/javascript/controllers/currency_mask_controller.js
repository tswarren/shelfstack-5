import { Controller } from "@hotwired/stimulus"

// Fixed-point currency UX: digits enter as cents; the named input holds a
// decimal-dollar string (e.g. "12.95") that the server parses. JS enhances
// formatting but is not required for correct submission.
export default class extends Controller {
  static targets = ["input"]
  static values = {
    amountCents: { type: Number, default: 0 },
    currencyCode: { type: String, default: "USD" }
  }

  connect() {
    if (this.hasInputTarget && this.inputTarget.value.trim() === "" && this.amountCentsValue) {
      this.render()
    }
  }

  handleInput(event) {
    const digits = event.target.value.replace(/\D/g, "")
    this.amountCentsValue = digits === "" ? 0 : parseInt(digits, 10)
    this.render()
  }

  handlePaste(event) {
    event.preventDefault()
    const text = (event.clipboardData || window.clipboardData).getData("text")
    const normalized = text.replace(/[$,\s]/g, "").replace(/^CA/, "")
    if (/^\d+(\.\d{1,2})?$/.test(normalized)) {
      this.amountCentsValue = Math.round(parseFloat(normalized) * 100)
    } else {
      const digits = normalized.replace(/\D/g, "")
      this.amountCentsValue = digits === "" ? 0 : parseInt(digits, 10)
    }
    this.render()
  }

  render() {
    if (!this.hasInputTarget) return

    const cents = this.amountCentsValue || 0
    // Named field submits decimal dollars for server-side parse_money.
    this.inputTarget.value = (cents / 100).toFixed(2)
    const formatted = this.formatCurrency(cents)
    this.inputTarget.setAttribute("aria-valuetext", formatted)
  }

  formatCurrency(cents) {
    try {
      return (cents / 100).toLocaleString(undefined, {
        style: "currency",
        currency: this.currencyCodeValue || "USD"
      })
    } catch (_e) {
      return `${(cents / 100).toFixed(2)} ${this.currencyCodeValue || "USD"}`
    }
  }
}
