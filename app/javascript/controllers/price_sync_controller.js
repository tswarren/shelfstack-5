import { Controller } from "@hotwired/stimulus"

// linked → regular mirrors list; editing regular → independent;
// "Use list price" → relink. Clearing regular alone does not relink.
// Mode is submitted in a hidden field so validation redisplay preserves it.
export default class extends Controller {
  static targets = ["list", "regular", "relink", "mode"]
  static values = { mode: { type: String, default: "linked" } }

  connect() {
    if (this.hasModeTarget && ["linked", "independent"].includes(this.modeTarget.value)) {
      this.modeValue = this.modeTarget.value
    } else if (this.hasRegularTarget && this.hasListTarget) {
      const list = this.listTarget.value.trim()
      const regular = this.regularTarget.value.trim()
      if (regular && list && regular !== list) {
        this.modeValue = "independent"
      }
    }
    this.syncModeField()
    this.updateRelinkVisibility()
  }

  listChanged() {
    if (this.modeValue === "linked" && this.hasRegularTarget) {
      this.regularTarget.value = this.listTarget.value
    }
  }

  regularChanged() {
    this.modeValue = "independent"
    this.syncModeField()
    this.updateRelinkVisibility()
  }

  useListPrice(event) {
    event.preventDefault()
    if (!this.hasListTarget || !this.hasRegularTarget) return
    this.regularTarget.value = this.listTarget.value
    this.modeValue = "linked"
    this.syncModeField()
    this.updateRelinkVisibility()
  }

  syncModeField() {
    if (this.hasModeTarget) this.modeTarget.value = this.modeValue
  }

  updateRelinkVisibility() {
    if (!this.hasRelinkTarget) return
    this.relinkTarget.hidden = this.modeValue === "linked"
  }
}
