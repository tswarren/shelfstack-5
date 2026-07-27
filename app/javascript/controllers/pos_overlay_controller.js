import { Controller } from "@hotwired/stimulus"

// Focus-safe POS overlay host (POS-UI-008). Supports multiple static dialogs
// opened via data-pos-overlay-id-param="<dialog-id>".
export default class extends Controller {
  static targets = ["dialog"]
  static values = { openOnConnect: { type: String, default: "" } }

  connect() {
    this._returnFocusTo = null
    this._openDialog = null

    const id = this.openOnConnectValue || new URLSearchParams(window.location.search).get("overlay")
    if (id) {
      // Defer so dialog targets and nested Stimulus controllers are connected.
      requestAnimationFrame(() => this.openById(id))
    }
  }

  open(event) {
    event?.preventDefault()
    this._returnFocusTo = event?.currentTarget || document.activeElement
    this.openById(event?.params?.id)
  }

  openById(id) {
    const dialog = id
      ? this.element.querySelector(`#${CSS.escape(id)}`) || document.getElementById(id)
      : this.dialogTargets[0]
    if (!dialog) return

    this._openDialog = dialog
    try {
      if (typeof dialog.showModal === "function") {
        if (!dialog.open) dialog.showModal()
      } else {
        dialog.setAttribute("open", "")
      }
    } catch (_error) {
      dialog.setAttribute("open", "")
    }

    // Prefer body fields over the chrome Close button so open doesn't steal
    // focus to a control that immediately dismisses the dialog.
    const body = dialog.querySelector(".pos-overlay-dialog__body") || dialog
    const focusable = body.querySelector(
      "input:not([type=hidden]):not([disabled]), select:not([disabled]), textarea:not([disabled]), button:not([disabled]), [href]"
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
    const dialog =
      this._openDialog ||
      this.dialogTargets.find((el) => el.open) ||
      this.element.querySelector("dialog[open]")
    if (!dialog) return

    if (dialog.open && typeof dialog.close === "function") {
      dialog.close()
    }
    dialog.removeAttribute("open")
    this._openDialog = null

    const restore = this._returnFocusTo
    this._returnFocusTo = null
    if (restore && typeof restore.focus === "function") {
      restore.focus()
    }
  }
}
