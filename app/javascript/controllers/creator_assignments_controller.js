import { Controller } from "@hotwired/stimulus"

// Ordered Creator-assignment rows on the product form (Gate 8b). The server
// derives final positions from submission order, so reordering only needs to
// move each row's DOM node -- there is no position input to keep in sync.
export default class extends Controller {
  static targets = ["rows", "row", "template"]

  connect() {
    this.rowCounter = 0
  }

  addRow(event) {
    event?.preventDefault()
    const token = `new_${Date.now()}_${this.rowCounter++}`
    const html = this.templateTarget.innerHTML.replaceAll("NEW_RECORD", token)
    const wrapper = document.createElement("div")
    wrapper.innerHTML = html.trim()
    const row = wrapper.firstElementChild
    if (row) {
      row.dataset.creatorRowIndex = token
      row.id = `creator-assignment-row-${token}`
      this.rowsTarget.appendChild(row)
    }
  }

  removeRow(event) {
    event.preventDefault()
    event.target.closest("[data-creator-assignments-target='row']").remove()
  }

  moveUp(event) {
    event.preventDefault()
    const row = event.target.closest("[data-creator-assignments-target='row']")
    const previous = row.previousElementSibling
    if (previous) row.parentElement.insertBefore(row, previous)
  }

  moveDown(event) {
    event.preventDefault()
    const row = event.target.closest("[data-creator-assignments-target='row']")
    const next = row.nextElementSibling
    if (next) row.parentElement.insertBefore(next, row)
  }
}
