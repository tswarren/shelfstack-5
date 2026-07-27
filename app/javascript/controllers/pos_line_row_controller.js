import { Controller } from "@hotwired/stimulus"

// Whole-row pointer selection forwards to the explicit select link (workspace frame).
export default class extends Controller {
  select(event) {
    if (event.target.closest("a, button, input, select, textarea, label")) return
    const link = this.element.querySelector("a.pos-line-select-link")
    link?.click()
  }
}
