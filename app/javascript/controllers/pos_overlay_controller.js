import { Controller } from "@hotwired/stimulus"

// Focus-safe POS overlay host (POS-UI-008). Mechanism is implementation-level
// (native <dialog>); interaction contract stays in the decision log.
export default class extends Controller {
  static targets = ["dialog"]

  connect() {
    this._returnFocusTo = null
    this._onTurboLoad = () => this.clearIfWorkspaceReplaced()
    document.addEventListener("turbo:load", this._onTurboLoad)
    document.addEventListener("turbo:frame-load", this._onTurboLoad)
  }

  disconnect() {
    document.removeEventListener("turbo:load", this._onTurboLoad)
    document.removeEventListener("turbo:frame-load", this._onTurboLoad)
  }

  open(event) {
    event?.preventDefault()
    this._returnFocusTo = event?.currentTarget || document.activeElement
    if (!this.hasDialogTarget) return
    if (typeof this.dialogTarget.showModal === "function") {
      this.dialogTarget.showModal()
    } else {
      this.dialogTarget.setAttribute("open", "")
    }
    const focusable = this.dialogTarget.querySelector(
      "input:not([type=hidden]), select, textarea, button, [href]"
    )
    focusable?.focus()
  }

  close(event) {
    event?.preventDefault()
    this.closeAndRestore()
  }

  onCancel(event) {
    event.preventDefault()
    this.closeAndRestore()
  }

  closeAndRestore() {
    if (!this.hasDialogTarget) return
    if (this.dialogTarget.open) this.dialogTarget.close()
    this.dialogTarget.removeAttribute("open")
    const content = this.dialogTarget.querySelector("[data-pos-overlay-target='content']")
    if (content) content.innerHTML = ""
    const restore = this._returnFocusTo
    this._returnFocusTo = null
    if (restore && typeof restore.focus === "function") restore.focus()
  }

  clearIfWorkspaceReplaced() {
    if (this.hasDialogTarget && this.dialogTarget.open) {
      this.closeAndRestore()
    }
  }
}
