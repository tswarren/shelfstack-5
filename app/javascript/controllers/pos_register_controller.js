import { Controller } from "@hotwired/stimulus"

// Register workspace ergonomics only — no business logic lives here.
// Keeps the scan field focused for continuous scanning, announces server
// results to assistive tech, and offers an optional Complete shortcut.
export default class extends Controller {
  static targets = ["scanInput", "liveRegion", "completeButton", "announce"]

  connect() {
    this.onSubmitEnd = this.handleSubmitEnd.bind(this)
    this.onKeydown = this.handleKeydown.bind(this)
    this.element.addEventListener("turbo:submit-end", this.onSubmitEnd)
    this.element.addEventListener("keydown", this.onKeydown)

    this.announceStatus()
    this.focusScanInput()
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-end", this.onSubmitEnd)
    this.element.removeEventListener("keydown", this.onKeydown)
  }

  handleSubmitEnd(event) {
    // Clear the scan field only when the server accepted the submission.
    if (event.detail?.success && this.hasScanInputTarget) {
      this.scanInputTarget.value = ""
    }
    this.focusScanInput()
  }

  handleKeydown(event) {
    // Ctrl+Enter (or Cmd+Enter) triggers the primary Complete action.
    if ((event.ctrlKey || event.metaKey) && event.key === "Enter" && this.hasCompleteButtonTarget) {
      event.preventDefault()
      this.completeButtonTarget.click()
    }
  }

  focusScanInput() {
    if (!this.hasScanInputTarget) return
    if (this.shouldPreserveFocus()) return

    const input = this.scanInputTarget
    input.focus()
    if (typeof input.select === "function") input.select()
  }

  // Never yank focus away from an open disclosure or approval entry the
  // cashier is actively using (e.g. typing an approver PIN).
  shouldPreserveFocus() {
    const active = document.activeElement
    if (!active || active === document.body) return false
    if (active === this.scanInputTarget) return true
    return Boolean(active.closest("details[open]") || active.closest(".approval-fields"))
  }

  announceStatus() {
    if (!this.hasLiveRegionTarget || !this.hasAnnounceTarget) return

    const message = this.announceTarget.textContent.trim()
    if (message) this.liveRegionTarget.textContent = message
  }
}
