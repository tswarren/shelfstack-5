import { Controller } from "@hotwired/stimulus"

// Keeps a dependent record-picker (e.g. variant) scoped to a parent selection (e.g. product).
export default class extends Controller {
  static targets = ["parent", "dependent"]
  static values = {
    dependentParam: { type: String, default: "productId" }
  }

  parentSelected(event) {
    const id = event.detail?.id
    this.dependentTargets.forEach((element) => {
      const picker = this.application.getControllerForElementAndIdentifier(element, "record-picker")
      if (!picker) return

      if (this.dependentParamValue === "productId") {
        picker.productIdValue = id ? String(id) : ""
      }

      picker.committedId = ""
      picker.committedLabel = ""
      picker.hiddenTarget.value = ""
      picker.inputTarget.value = ""
      picker.syncValidity()
      picker.toggleClear()
      if (typeof picker.resetForScopeChange === "function") {
        picker.resetForScopeChange()
      } else {
        picker.closeListbox()
      }
    })
  }
}
