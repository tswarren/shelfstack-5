import { Controller } from "@hotwired/stimulus"

// Client-side filter for open-ring department list (Phase 11.2E).
export default class extends Controller {
  static targets = ["query", "item"]

  filter() {
    const q = (this.queryTarget.value || "").trim().toLowerCase()
    this.itemTargets.forEach((item) => {
      const hay = (item.dataset.searchText || "").toLowerCase()
      item.hidden = q.length > 0 && !hay.includes(q)
    })
  }
}
