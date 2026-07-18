import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["kind", "reason", "reasonOption", "lineFields"]

  connect() {
    this.refresh()
  }

  refresh() {
    const kind = this.kindTarget.value

    this.reasonOptionTargets.forEach((option) => {
      const optionKind = option.dataset.adjustmentKind
      const show = !optionKind || optionKind === kind
      option.hidden = !show
      option.disabled = !show
    })

    const selected = this.reasonTarget.selectedOptions[0]
    if (selected?.disabled) {
      const firstEnabled = Array.from(this.reasonTarget.options).find((o) => !o.disabled && o.value)
      if (firstEnabled) this.reasonTarget.value = firstEnabled.value
    }

    this.lineFieldsTargets.forEach((section) => {
      const forKinds = (section.dataset.forKinds || "").split(",").filter(Boolean)
      const show = forKinds.length === 0 || forKinds.includes(kind)
      section.hidden = !show
      section.querySelectorAll("input, select, textarea").forEach((input) => {
        input.disabled = !show
      })
    })
  }
}
