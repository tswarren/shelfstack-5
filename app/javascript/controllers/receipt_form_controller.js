import { Controller } from "@hotwired/stimulus"

// Keeps receipt-line Purchase-Order Line options scoped to the receipt vendor
// and the line's Product Variant so a line cannot be linked to a different item.
// Also defaults unit cost from PO / vendor list−discount suggestions.
export default class extends Controller {
  static targets = [
    "vendor", "lines", "line", "lineTemplate", "removeButton", "position",
    "variantSelect", "purchaseOrderLineSelect", "unitCost", "costQuality", "costProvenance"
  ]
  static values = { vendorCostSuggestions: Object }

  connect() {
    // Unique index for lines added client-side; large enough to never collide
    // with the server-rendered 0..n indices.
    this.newIndex = Date.now()
    this.updateLineControls()
    this.refreshPurchaseOrderLineOptions()
  }

  addLine() {
    const html = this.lineTemplateTarget.innerHTML.replace(/__INDEX__/g, this.newIndex++)
    const fragment = document.createRange().createContextualFragment(html)
    this.linesTarget.appendChild(fragment)
    this.updateLineControls()
    this.refreshPurchaseOrderLineOptions()
  }

  removeLine(event) {
    // Always retain at least one line row.
    if (this.lineTargets.length <= 1) return

    event.target.closest("[data-receipt-form-target='line']").remove()
    this.updateLineControls()
  }

  vendorChanged() {
    this.refreshPurchaseOrderLineOptions({ clearIncompatible: true })
    this.lineTargets.forEach((line) => this.applySuggestedCost(line))
  }

  variantChanged(event) {
    const line = event.target.closest("[data-receipt-form-target='line']")
    this.refreshLinePurchaseOrderOptions(line, { clearIncompatible: true })
    this.applySuggestedCost(line)
  }

  purchaseOrderLineChanged(event) {
    const line = event.target.closest("[data-receipt-form-target='line']")
    const select = line.querySelector("[data-receipt-form-target='purchaseOrderLineSelect']")
    const option = select?.selectedOptions?.[0]
    const variantId = option?.dataset?.productVariantId
    if (variantId) {
      const variantSelect = line.querySelector("[data-receipt-form-target='variantSelect']")
      if (variantSelect && variantSelect.value !== variantId) {
        variantSelect.value = variantId
      }
    }

    this.refreshLinePurchaseOrderOptions(line)
    this.applySuggestedCost(line, { force: true })
  }

  refreshPurchaseOrderLineOptions({ clearIncompatible = false } = {}) {
    this.lineTargets.forEach((line) => {
      this.refreshLinePurchaseOrderOptions(line, { clearIncompatible })
    })
  }

  refreshLinePurchaseOrderOptions(line, { clearIncompatible = false } = {}) {
    const vendorId = this.hasVendorTarget ? this.vendorTarget.value : ""
    const variantSelect = line.querySelector("[data-receipt-form-target='variantSelect']")
    const poSelect = line.querySelector("[data-receipt-form-target='purchaseOrderLineSelect']")
    if (!poSelect) return

    const variantId = variantSelect?.value || ""

    Array.from(poSelect.options).forEach((option) => {
      if (!option.value) {
        option.hidden = false
        option.disabled = false
        return
      }

      const optionVendorId = option.dataset.vendorId || ""
      const optionVariantId = option.dataset.productVariantId || ""
      const vendorOk = !vendorId || optionVendorId === vendorId
      const variantOk = !variantId || optionVariantId === variantId
      const show = vendorOk && variantOk
      option.hidden = !show
      option.disabled = !show
    })

    const selected = poSelect.selectedOptions[0]
    if (clearIncompatible && selected && selected.disabled) {
      poSelect.value = ""
    }
  }

  applySuggestedCost(line, { force = false } = {}) {
    const unitCost = line.querySelector("[data-receipt-form-target='unitCost']")
    if (!unitCost) return

    if (!force && unitCost.value !== "") return

    const suggestion = this.suggestionFor(line)
    if (!suggestion) return

    unitCost.value = suggestion.unit_cost_cents

    const quality = line.querySelector("[data-receipt-form-target='costQuality']")
    if (quality && (force || quality.value === "")) {
      quality.value = suggestion.cost_quality || ""
    }

    const provenance = line.querySelector("[data-receipt-form-target='costProvenance']")
    if (provenance && (force || provenance.value === "")) {
      provenance.value = suggestion.cost_provenance || ""
    }
  }

  suggestionFor(line) {
    const poSelect = line.querySelector("[data-receipt-form-target='purchaseOrderLineSelect']")
    const poOption = poSelect?.selectedOptions?.[0]
    if (poOption?.value && poOption.dataset.suggestedUnitCostCents) {
      return {
        unit_cost_cents: poOption.dataset.suggestedUnitCostCents,
        cost_quality: poOption.dataset.suggestedCostQuality || "estimated",
        cost_provenance: poOption.dataset.suggestedCostProvenance || "purchase_order_expected"
      }
    }

    const vendorId = this.hasVendorTarget ? this.vendorTarget.value : ""
    const variantId = line.querySelector("[data-receipt-form-target='variantSelect']")?.value || ""
    if (!vendorId || !variantId) return null

    return this.vendorCostSuggestionsValue?.[`${variantId}:${vendorId}`] || null
  }

  updateLineControls() {
    const lines = this.lineTargets
    const onlyOne = lines.length <= 1

    lines.forEach((line, index) => {
      const position = line.querySelector("[data-receipt-form-target='position']")
      if (position) position.value = index

      const removeButton = line.querySelector("[data-receipt-form-target='removeButton']")
      if (removeButton) removeButton.disabled = onlyOne
    })
  }
}
