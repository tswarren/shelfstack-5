import { Controller } from "@hotwired/stimulus"

// Whole-row line selection for the compact POS line table.
export default class extends Controller {
  static values = { url: String }

  select(event) {
    if (event.target.closest("a, button, input, select, textarea, label")) return
    if (!this.urlValue) return

    if (window.Turbo?.visit) {
      Turbo.visit(this.urlValue)
    } else {
      window.location.href = this.urlValue
    }
  }

  keySelect(event) {
    if (event.key !== "Enter" && event.key !== " ") return
    event.preventDefault()
    if (!this.urlValue) return

    if (window.Turbo?.visit) {
      Turbo.visit(this.urlValue)
    } else {
      window.location.href = this.urlValue
    }
  }
}
