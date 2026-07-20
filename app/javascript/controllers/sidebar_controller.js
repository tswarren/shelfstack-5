import { Controller } from "@hotwired/stimulus"

// Collapsible / off-canvas sidebar for narrower back-office viewports.
export default class extends Controller {
  static targets = ["panel", "toggle", "backdrop"]

  connect() {
    this.close()
  }

  toggle() {
    if (document.body.classList.contains("sidebar-open")) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    document.body.classList.add("sidebar-open")
    if (this.hasBackdropTarget) this.backdropTarget.hidden = false
    if (this.hasToggleTarget) {
      this.toggleTarget.setAttribute("aria-expanded", "true")
      this._lastFocus = document.activeElement
    }
    this.panelTarget?.querySelector("a,button")?.focus()
  }

  close() {
    document.body.classList.remove("sidebar-open")
    if (this.hasBackdropTarget) this.backdropTarget.hidden = true
    if (this.hasToggleTarget) this.toggleTarget.setAttribute("aria-expanded", "false")
    if (this._lastFocus?.focus) this._lastFocus.focus()
  }
}
