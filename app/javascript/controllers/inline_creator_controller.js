import { Controller } from "@hotwired/stimulus"

// Opens the shared inline-creator dialog in a row-aware way.
export default class extends Controller {
  static values = { rowIndex: String }

  open(event) {
    event.preventDefault()
    const dialog = document.getElementById("inline-creator-dialog")
    if (!dialog) return

    const row = event.currentTarget.closest("[data-creator-assignments-target='row']")
    const rowIndex = row?.dataset?.creatorRowIndex || this.rowIndexValue || ""
    const rowIndexInput = dialog.querySelector("#inline_creator_row_index")
    if (rowIndexInput) rowIndexInput.value = rowIndex

    const form = dialog.querySelector("form.form")
    form?.reset()
    if (rowIndexInput) rowIndexInput.value = rowIndex

    this._opener = event.currentTarget
    dialog.dataset.openerId = this._opener.id || ""
    if (!this._opener.id) {
      this._opener.id = `inline-creator-opener-${Date.now()}`
      dialog.dataset.openerId = this._opener.id
    }

    if (typeof dialog.showModal === "function") {
      dialog.showModal()
    } else {
      dialog.setAttribute("open", "open")
    }

    const firstField = dialog.querySelector("input[name='creator[display_name]']")
    firstField?.focus()
  }
}
