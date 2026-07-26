import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit", "body"]

  connect() {
    this.element.addEventListener("close", this.onClose)
    this.element.addEventListener("cancel", this.onCancel)
    this._onKeydown = (event) => {
      if (event.key === "Escape" && this.element.open) {
        // Native <dialog> handles Escape; ensure focus returns.
        this.returnFocus()
      }
    }
    document.addEventListener("keydown", this._onKeydown)
  }

  disconnect() {
    this.element.removeEventListener("close", this.onClose)
    this.element.removeEventListener("cancel", this.onCancel)
    document.removeEventListener("keydown", this._onKeydown)
  }

  disableSubmit() {
    if (this.hasSubmitTarget) this.submitTarget.disabled = true
  }

  enableSubmit() {
    if (this.hasSubmitTarget) this.submitTarget.disabled = false
  }

  onClose = () => {
    this.enableSubmit()
    this.returnFocus()
  }

  onCancel = () => {
    this.returnFocus()
  }

  returnFocus() {
    const openerId = this.element.dataset.openerId
    if (!openerId) return
    requestAnimationFrame(() => {
      document.getElementById(openerId)?.focus()
    })
  }

  // Called from turbo_stream after successful create.
  closeAndReturnFocus() {
    if (this.element.open) this.element.close()
    this.returnFocus()
  }
}
