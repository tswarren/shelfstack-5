import { Controller } from "@hotwired/stimulus"

// Register workspace ergonomics only — no business logic lives here.
export default class extends Controller {
  static targets = ["scanInput", "scanForm", "liveRegion", "completeButton", "announce", "backToRegister"]
  static values = {
    scanOutcome: String,
    completed: { type: Boolean, default: false }
  }

  connect() {
    this.onSubmitEnd = this.handleSubmitEnd.bind(this)
    this.onKeydown = this.handleKeydown.bind(this)
    this.element.addEventListener("turbo:submit-end", this.onSubmitEnd)
    this.element.addEventListener("keydown", this.onKeydown)

    this.announceStatus()
    this.applyScanOutcome()
    if (!this.completedValue) this.focusScanInput()
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-end", this.onSubmitEnd)
    this.element.removeEventListener("keydown", this.onKeydown)
  }

  handleSubmitEnd(event) {
    const form = event.target
    if (form && this.hasScanFormTarget && form !== this.scanFormTarget) return

    this.focusScanInput()
  }

  applyScanOutcome() {
    if (!this.hasScanInputTarget) return

    if (this.scanOutcomeValue === "added") {
      this.scanInputTarget.value = ""
    }
  }

  handleKeydown(event) {
    if ((event.ctrlKey || event.metaKey) && event.key === "Enter" && this.hasCompleteButtonTarget) {
      event.preventDefault()
      this.completeButtonTarget.click()
      return
    }

    // On the completed summary, Enter returns to the register when focus is not
    // inside another interactive control.
    if (this.completedValue && event.key === "Enter" && this.hasBackToRegisterTarget) {
      const active = document.activeElement
      if (active && (active.matches("input, textarea, select, button, a") || active.isContentEditable)) {
        return
      }
      event.preventDefault()
      this.backToRegisterTarget.click()
    }
  }

  focusScanInput() {
    if (!this.hasScanInputTarget) return
    if (this.shouldPreserveFocus()) return

    const input = this.scanInputTarget
    input.focus()
    if (typeof input.select === "function" && this.scanOutcomeValue === "added") {
      input.select()
    }
  }

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
