import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["lines", "line", "lineTemplate", "removeButton", "position"]

  connect() {
    // Unique index for lines added client-side; large enough to never collide
    // with the server-rendered 0..n indices.
    this.newIndex = Date.now()
    this.updateLineControls()
  }

  addLine() {
    const html = this.lineTemplateTarget.innerHTML.replace(/__INDEX__/g, this.newIndex++)
    const fragment = document.createRange().createContextualFragment(html)
    this.linesTarget.appendChild(fragment)
    this.updateLineControls()
  }

  removeLine(event) {
    // Always retain at least one line row.
    if (this.lineTargets.length <= 1) return

    event.target.closest("[data-purchase-order-form-target='line']").remove()
    this.updateLineControls()
  }

  updateLineControls() {
    const lines = this.lineTargets
    const onlyOne = lines.length <= 1

    lines.forEach((line, index) => {
      const position = line.querySelector("[data-purchase-order-form-target='position']")
      if (position) position.value = index

      const removeButton = line.querySelector("[data-purchase-order-form-target='removeButton']")
      if (removeButton) removeButton.disabled = onlyOne
    })
  }
}
