import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "kind", "reason", "reasonOption", "lineFields",
    "lines", "line", "lineTemplate", "removeButton", "position"
  ]

  connect() {
    // Unique index for lines added client-side; large enough to never collide
    // with the server-rendered 0..n indices.
    this.newIndex = Date.now()
    this.refresh()
    this.updateLineControls()
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

  addLine() {
    const html = this.lineTemplateTarget.innerHTML.replace(/__INDEX__/g, this.newIndex++)
    const fragment = document.createRange().createContextualFragment(html)
    this.linesTarget.appendChild(fragment)
    this.refresh()
    this.updateLineControls()
  }

  removeLine(event) {
    // Always retain at least one line row.
    if (this.lineTargets.length <= 1) return

    event.target.closest("[data-inventory-adjustment-form-target='line']").remove()
    this.updateLineControls()
  }

  moveUp(event) {
    const line = event.target.closest("[data-inventory-adjustment-form-target='line']")
    const previous = line.previousElementSibling
    if (previous) {
      line.parentNode.insertBefore(line, previous)
      this.updateLineControls()
    }
  }

  moveDown(event) {
    const line = event.target.closest("[data-inventory-adjustment-form-target='line']")
    const next = line.nextElementSibling
    if (next) {
      line.parentNode.insertBefore(next, line)
      this.updateLineControls()
    }
  }

  // Keep hidden position fields aligned with DOM order and disable the remove
  // button when only one line remains (the last line can never be removed).
  updateLineControls() {
    const lines = this.lineTargets
    const onlyOne = lines.length <= 1

    lines.forEach((line, index) => {
      const position = line.querySelector("[data-inventory-adjustment-form-target='position']")
      if (position) position.value = index

      const removeButton = line.querySelector("[data-inventory-adjustment-form-target='removeButton']")
      if (removeButton) removeButton.disabled = onlyOne
    })
  }
}
