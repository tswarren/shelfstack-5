import { Controller } from "@hotwired/stimulus"

// linked → regular mirrors list; editing regular → independent;
// "Use list price" → relink. Clearing regular alone does not relink.
export default class extends Controller {
  static targets = ["list", "regular", "relink"]
  static values = { mode: { type: String, default: "linked" } }

  connect() {
    if (this.hasRegularTarget && this.hasListTarget) {
      const list = this.listTarget.value.trim()
      const regular = this.regularTarget.value.trim()
      if (regular && list && regular !== list) {
        this.modeValue = "independent"
      }
    }
    this.updateRelinkVisibility()
  }

  listChanged() {
    if (this.modeValue === "linked" && this.hasRegularTarget) {
      this.regularTarget.value = this.listTarget.value
    }
  }

  regularChanged() {
    this.modeValue = "independent"
    this.updateRelinkVisibility()
  }

  useListPrice(event) {
    event.preventDefault()
    if (!this.hasListTarget || !this.hasRegularTarget) return
    this.regularTarget.value = this.listTarget.value
    this.modeValue = "linked"
    this.updateRelinkVisibility()
  }

  updateRelinkVisibility() {
    if (!this.hasRelinkTarget) return
    this.relinkTarget.hidden = this.modeValue === "linked"
  }
}
