import { Controller } from "@hotwired/stimulus"

// Focus-safe POS overlay host (POS-UI-008). Supports multiple static dialogs
// opened via data-pos-overlay-id-param="<dialog-id>".
export default class extends Controller {
  static targets = ["dialog"]

  connect() {
    this._returnFocusTo = null
    this._openDialog = null
  }

  open(event) {
    event?.preventDefault()
    this._returnFocusTo = event?.currentTarget || document.activeElement
    const id = event?.params?.id
    const dialog = id
      ? this.element.querySelector(`#${CSS.escape(id)}`)
      : this.dialogTargets[0]
    if (!dialog) return

    this._openDialog = dialog
    if (typeof dialog.showModal === "function") {
      dialog.showModal()
    } else {
      dialog.setAttribute("open", "")
    }
    const focusable = dialog.querySelector(
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
