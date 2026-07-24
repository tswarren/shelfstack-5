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
    this.requestToken = 0
    this.committedId = this.hasHiddenTarget ? this.hiddenTarget.value : ""
    this.committedLabel = this.hasInputTarget ? this.inputTarget.value : ""
    this.syncValidity()
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
    this.clearDebounce()
    this.abortInFlight()
    this.syncValidity()
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
    window.setTimeout(() => {
      this.restoreCommittedIfUnmatched()
      this.closeListbox()
    }, 150)
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
        this.restoreCommittedIfUnmatched()
        this.closeListbox()
        break
    }
  }

  clear(event) {
    event?.preventDefault()
    if (this.disabledValue) return
    this.clearDebounce()
    this.abortInFlight()
    this.committedId = ""
    this.committedLabel = ""
    this.hiddenTarget.value = ""
    this.inputTarget.value = ""
    this.results = []
    this.activeIndex = -1
    this.renderResults()
    this.setStatus("")
    this.syncValidity()
    this.toggleClear()
    this.closeListbox()
    this.inputTarget.focus()
  }

  productIdValueChanged() {
    this.resetForScopeChange()
  }

  resetForScopeChange() {
    this.clearDebounce()
    this.abortInFlight()
    this.results = []
    this.activeIndex = -1
    this.renderResults()
    this.setStatus("")
    this.closeListbox()
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
    const recordType = this.recordTypeValue
    const productId = this.productIdValue || ""
    const token = ++this.requestToken

    this.abortInFlight()
    this.abortController = new AbortController()
    this.setStatus("Searching…")
    this.openListbox()

    const url = new URL(this.searchUrlValue, window.location.origin)
    url.searchParams.set("type", recordType)
    url.searchParams.set("q", query)
    if (this.includeInactiveValue) url.searchParams.set("include_inactive", "1")
    if (productId) url.searchParams.set("product_id", productId)

    try {
      const response = await fetch(url.toString(), {
        headers: { Accept: "application/json", "X-Requested-With": "XMLHttpRequest" },
        credentials: "same-origin",
        signal: this.abortController.signal
      })

      if (!this.isCurrentRequest(token, query, recordType, productId)) return

      if (!response.ok) {
        this.results = []
        this.renderResults()
        this.setStatus(response.status === 403 ? "Not authorized." : "Search failed.")
        return
      }

      const payload = await response.json()
      if (!this.isCurrentRequest(token, query, recordType, productId)) return

      this.results = Array.isArray(payload.results) ? payload.results : []
      this.activeIndex = this.results.length ? 0 : -1
      this.renderResults()
      this.setStatus(this.results.length ? `${this.results.length} result${this.results.length === 1 ? "" : "s"}` : "No matches.")
    } catch (error) {
      if (error.name === "AbortError") return
      if (!this.isCurrentRequest(token, query, recordType, productId)) return
      this.results = []
      this.renderResults()
      this.setStatus("Search failed.")
    }
  }

  isCurrentRequest(token, query, recordType, productId) {
    return (
      token === this.requestToken &&
      query === this.inputTarget.value.trim() &&
      recordType === this.recordTypeValue &&
      productId === (this.productIdValue || "")
    )
  }

  renderResults() {
    this.listboxTarget.innerHTML = ""
    this.results.forEach((result, index) => {
      const option = document.createElement("li")
      option.className = "record-picker-option"
      if (result.inactive) option.classList.add("record-picker-option--inactive")
      option.setAttribute("role", "option")
      option.id = `${this.listboxTarget.id}_opt_${index}`
      option.dataset.index = String(index)
      option.setAttribute("aria-selected", index === this.activeIndex ? "true" : "false")

      const marker = document.createElement("span")
      marker.className = "record-picker-option-marker"
      marker.setAttribute("aria-hidden", "true")
      marker.textContent = "›"

      const label = document.createElement("span")
      label.className = "record-picker-option-label"
      label.textContent = result.label

      option.append(marker, label)
      option.addEventListener("mousedown", (event) => {
        event.preventDefault()
        this.selectResult(result)
      })
      this.listboxTarget.appendChild(option)
    })
    this.syncActiveOption()
  }

  selectResult(result) {
    this.committedId = String(result.id)
    this.committedLabel = result.label
    this.hiddenTarget.value = this.committedId
    this.inputTarget.value = this.committedLabel
    this.results = []
    this.activeIndex = -1
    this.renderResults()
    this.syncValidity()
    this.toggleClear()
    this.closeListbox()
    this.setStatus("")
    this.dispatch("selected", { detail: { id: result.id, label: result.label, recordType: this.recordTypeValue } })
  }

  restoreCommittedIfUnmatched() {
    if (this.disabledValue) return
    const current = this.inputTarget.value
    if (current === this.committedLabel) {
      this.syncValidity()
      return
    }
    if (current.trim() === "" && this.committedId === "") {
      this.syncValidity()
      return
    }
    // Non-empty unmatched text (or emptied while a commit existed): restore commit.
    // Emptying without Clear is treated as unmatched when a prior selection exists.
    this.hiddenTarget.value = this.committedId
    this.inputTarget.value = this.committedLabel
    this.syncValidity()
    this.toggleClear()
  }

  syncValidity() {
    if (!this.hasInputTarget) return
    const current = this.inputTarget.value
    const unmatched = current !== this.committedLabel && current.trim() !== ""
    if (unmatched) {
      this.inputTarget.setCustomValidity("Select a result or clear the field")
    } else {
      this.inputTarget.setCustomValidity("")
    }
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
