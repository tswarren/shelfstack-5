import { Controller } from "@hotwired/stimulus"

// Focus-safe POS overlay host (POS-UI-008).
// Dialogs are loaded into turbo-frame#pos_overlay and opened on turbo:frame-load.
export default class extends Controller {
  static targets = ["dialog"]

  connect() {
    this._returnFocusTo = null
    this._openDialog = null
    this.onClickCapture = this.rememberInvoker.bind(this)
    this.element.addEventListener("click", this.onClickCapture, true)
  }

  disconnect() {
    this.element.removeEventListener("click", this.onClickCapture, true)
  }

  rememberInvoker(event) {
    const launcher = event.target.closest('[data-turbo-frame="pos_overlay"]')
    if (launcher && this.element.contains(launcher)) {
      this._returnFocusTo = launcher
    }
  }

  onFrameLoad(event) {
    const frame = event.target
    if (!(frame instanceof HTMLElement) || frame.id !== "pos_overlay") return
    const dialog = frame.querySelector("dialog")
    if (!dialog) return
    this.openDialog(dialog)
  }

  open(event) {
    event?.preventDefault()
    this._returnFocusTo = event?.currentTarget || document.activeElement
    const id = event?.params?.id
    const dialog = id
      ? this.element.querySelector(`#${CSS.escape(id)}`) || document.getElementById(id)
      : this.dialogTargets[0]
    if (dialog) this.openDialog(dialog)
  }

  openDialog(dialog) {
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

    const frame = this.element.querySelector("turbo-frame#pos_overlay")
    if (frame) frame.innerHTML = ""

    const restore = this._returnFocusTo
    this._returnFocusTo = null
    if (restore && typeof restore.focus === "function") {
      restore.focus()
    }
  }
}
