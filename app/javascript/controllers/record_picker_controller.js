import { Controller } from "@hotwired/stimulus"

// Shared org-scoped search-to-link combobox (Gate 8a).
export default class extends Controller {
  static targets = ["hidden", "input", "listbox", "status", "clear"]
  static values = {
    searchUrl: String,
    recordType: String,
    includeInactive: { type: Boolean, default: false },
    productId: { type: String, default: "" },
    disabled: { type: Boolean, default: false }
  }

  connect() {
    this.results = []
    this.activeIndex = -1
    this.debounceTimer = null
    this.abortController = null
    this.selectedLabel = this.hasInputTarget ? this.inputTarget.value : ""
    if (this.disabledValue) {
      this.inputTarget.setAttribute("aria-disabled", "true")
    }
  }

  disconnect() {
    this.clearDebounce()
    this.abortInFlight()
  }

  onInput() {
    if (this.disabledValue) return
    this.scheduleSearch()
  }

  onFocus() {
    if (this.disabledValue) return
    if (this.inputTarget.value.trim() !== "" || this.results.length) {
      this.openListbox()
    }
  }

  onBlur() {
    // Delay so option mousedown/click can run first.
    window.setTimeout(() => this.closeListbox(), 150)
  }

  onKeydown(event) {
    if (this.disabledValue) return

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.openListbox()
        this.moveActive(1)
        break
      case "ArrowUp":
        event.preventDefault()
        this.openListbox()
        this.moveActive(-1)
        break
      case "Enter":
        if (this.isOpen() && this.activeIndex >= 0 && this.results[this.activeIndex]) {
          event.preventDefault()
          this.selectResult(this.results[this.activeIndex])
        }
        break
      case "Escape":
        event.preventDefault()
        this.closeListbox()
        break
    }
  }

  clear(event) {
    event?.preventDefault()
    if (this.disabledValue) return
    this.hiddenTarget.value = ""
    this.inputTarget.value = ""
    this.results = []
    this.activeIndex = -1
    this.setStatus("")
    this.toggleClear()
    this.closeListbox()
    this.inputTarget.focus()
  }

  scheduleSearch() {
    this.clearDebounce()
    this.debounceTimer = window.setTimeout(() => this.search(), 200)
  }

  clearDebounce() {
    if (this.debounceTimer) {
      window.clearTimeout(this.debounceTimer)
      this.debounceTimer = null
    }
  }

  abortInFlight() {
    if (this.abortController) {
      this.abortController.abort()
      this.abortController = null
    }
  }

  async search() {
    const query = this.inputTarget.value.trim()
    // Typing after a selection clears the hidden id until a new choice is made.
    if (this.hiddenTarget.value && this.inputTarget.value !== this.selectedLabel) {
      this.hiddenTarget.value = ""
      this.toggleClear()
    }

    this.abortInFlight()
    this.abortController = new AbortController()
    this.setStatus("Searching…")
    this.openListbox()

    const url = new URL(this.searchUrlValue, window.location.origin)
    url.searchParams.set("type", this.recordTypeValue)
    url.searchParams.set("q", query)
    if (this.includeInactiveValue) url.searchParams.set("include_inactive", "1")
    if (this.productIdValue) url.searchParams.set("product_id", this.productIdValue)

    try {
      const response = await fetch(url.toString(), {
        headers: { Accept: "application/json", "X-Requested-With": "XMLHttpRequest" },
        credentials: "same-origin",
        signal: this.abortController.signal
      })

      if (!response.ok) {
        this.results = []
        this.renderResults()
        this.setStatus(response.status === 403 ? "Not authorized." : "Search failed.")
        return
      }

      const payload = await response.json()
      this.results = Array.isArray(payload.results) ? payload.results : []
      this.activeIndex = this.results.length ? 0 : -1
      this.renderResults()
      this.setStatus(this.results.length ? `${this.results.length} result${this.results.length === 1 ? "" : "s"}` : "No matches.")
    } catch (error) {
      if (error.name === "AbortError") return
      this.results = []
      this.renderResults()
      this.setStatus("Search failed.")
    }
  }

  renderResults() {
    this.listboxTarget.innerHTML = ""
    this.results.forEach((result, index) => {
      const option = document.createElement("li")
      option.className = "record-picker-option"
      option.setAttribute("role", "option")
      option.id = `${this.listboxTarget.id}_opt_${index}`
      option.dataset.index = String(index)
      option.setAttribute("aria-selected", index === this.activeIndex ? "true" : "false")
      option.textContent = result.label
      option.addEventListener("mousedown", (event) => {
        event.preventDefault()
        this.selectResult(result)
      })
      this.listboxTarget.appendChild(option)
    })
    this.syncActiveOption()
  }

  selectResult(result) {
    this.hiddenTarget.value = result.id
    this.inputTarget.value = result.label
    this.selectedLabel = result.label
    this.results = []
    this.activeIndex = -1
    this.toggleClear()
    this.closeListbox()
    this.setStatus("")
    this.dispatch("selected", { detail: { id: result.id, label: result.label, recordType: this.recordTypeValue } })
  }

  moveActive(delta) {
    if (!this.results.length) return
    const next = this.activeIndex + delta
    this.activeIndex = Math.max(0, Math.min(this.results.length - 1, next))
    this.syncActiveOption()
  }

  syncActiveOption() {
    const options = this.listboxTarget.querySelectorAll("[role='option']")
    options.forEach((option, index) => {
      const active = index === this.activeIndex
      option.setAttribute("aria-selected", active ? "true" : "false")
      option.classList.toggle("is-active", active)
      if (active) option.scrollIntoView({ block: "nearest" })
    })
    const activeOption = options[this.activeIndex]
    if (activeOption) {
      this.inputTarget.setAttribute("aria-activedescendant", activeOption.id)
    } else {
      this.inputTarget.removeAttribute("aria-activedescendant")
    }
  }

  openListbox() {
    this.listboxTarget.hidden = false
    this.inputTarget.setAttribute("aria-expanded", "true")
  }

  closeListbox() {
    this.listboxTarget.hidden = true
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.inputTarget.removeAttribute("aria-activedescendant")
  }

  isOpen() {
    return !this.listboxTarget.hidden
  }

  setStatus(message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message || ""
  }

  toggleClear() {
    if (!this.hasClearTarget) return
    this.clearTarget.hidden = !this.hiddenTarget.value
  }
}
