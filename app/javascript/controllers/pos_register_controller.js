import { Controller } from "@hotwired/stimulus"

// Register workspace ergonomics only — no business logic lives here.
export default class extends Controller {
  static targets = [
    "scanInput", "scanForm", "liveRegion", "completeButton", "announce",
    "backToRegister", "recoveryPanel", "lineActions"
  ]
  static values = {
    scanOutcome: String,
    completed: { type: Boolean, default: false },
    focusTarget: String
  }

  connect() {
    this.onSubmitEnd = this.handleSubmitEnd.bind(this)
    this.onKeydown = this.handleKeydown.bind(this)
    this.onBeforeCache = this.handleBeforeCache.bind(this)
    this.element.addEventListener("turbo:submit-end", this.onSubmitEnd)
    document.addEventListener("turbo:before-cache", this.onBeforeCache)

    if (this.completedValue) {
      document.addEventListener("keydown", this.onKeydown)
    } else {
      this.element.addEventListener("keydown", this.onKeydown)
    }

    this.announceStatus()
    this.applyScanOutcome()
    this.applyFocusTarget()
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-end", this.onSubmitEnd)
    this.element.removeEventListener("keydown", this.onKeydown)
    document.removeEventListener("keydown", this.onKeydown)
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
  }

  handleBeforeCache() {
    if (this.hasCompleteButtonTarget) {
      this.completeButtonTarget.disabled = false
    }
  }

  startProcessing(event) {
    // Defer disable so the submit (or button default) is not cancelled by
    // disabling the control in the same click turn.
    const button = this.hasCompleteButtonTarget ? this.completeButtonTarget : null
    if (!button) return

    queueMicrotask(() => {
      button.disabled = true
      button.value = "Processing…"
    })
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

  applyFocusTarget() {
    if (this.completedValue && this.hasBackToRegisterTarget) {
      this.backToRegisterTarget.focus({ preventScroll: true })
      return
    }

    if (this.focusTargetValue === "line_actions" && this.hasLineActionsTarget) {
      const focusable = this.lineActionsTarget.querySelector("input, button, select, a")
      if (focusable) focusable.focus({ preventScroll: true })
      return
    }

    if (this.focusTargetValue === "recovery" && this.hasRecoveryPanelTarget) {
      const focusable = this.recoveryPanelTarget.querySelector("button, a, input")
      if (focusable) focusable.focus({ preventScroll: true })
      return
    }

    if (!this.completedValue) this.focusScanInput()
  }

  handleKeydown(event) {
    if ((event.ctrlKey || event.metaKey) && event.key === "Enter" && this.hasCompleteButtonTarget) {
      event.preventDefault()
      this.completeButtonTarget.click()
      return
    }

    if (event.key === "Escape") {
      // Intent cancel is server-driven via Sale intent link; restore scan focus.
      this.focusScanInput()
      return
    }

    if (this.completedValue && event.key === "Enter" && this.hasBackToRegisterTarget) {
      if (event.ctrlKey || event.metaKey || event.altKey || event.shiftKey) return

      const interactive = event.target.closest(
        "input, textarea, select, button, a, summary, [role='button'], [role='link'], [contenteditable='true']"
      )
      if (interactive) return

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
