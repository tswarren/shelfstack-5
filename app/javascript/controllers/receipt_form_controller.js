import { Controller } from "@hotwired/stimulus"

// Keeps receipt-line Purchase-Order Line options scoped to the receipt vendor
// and the line's Product Variant so a line cannot be linked to a different item.
// Defaults unit cost from PO / vendor suggestions while preserving manual edits.
export default class extends Controller {
  static targets = [
    "vendor", "lines", "line", "lineTemplate", "removeButton", "position",
    "variantSelect", "purchaseOrderLineSelect", "unitCost", "costQuality", "costProvenance"
  ]
  static values = { vendorCostSuggestions: Object }

  connect() {
    this.newIndex = Date.now()
    this.updateLineControls()
    this.refreshPurchaseOrderLineOptions()
    this.lineTargets.forEach((line) => this.ensureCostMeta(line))
  }

  addLine() {
    const html = this.lineTemplateTarget.innerHTML.replace(/__INDEX__/g, this.newIndex++)
    const fragment = document.createRange().createContextualFragment(html)
    this.linesTarget.appendChild(fragment)
    this.updateLineControls()
    this.refreshPurchaseOrderLineOptions()
    const line = this.lineTargets[this.lineTargets.length - 1]
    this.ensureCostMeta(line)
    this.applySuggestedCost(line)
  }

  removeLine(event) {
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
    this.applySuggestedCost(line)
  }

  costEdited(event) {
    const line = event.target.closest("[data-receipt-form-target='line']")
    if (!line) return

    const quality = line.querySelector("[data-receipt-form-target='costQuality']")
    if (quality?.value === "unknown" || quality?.value === "confirmed_zero") {
      line.dataset.costAutoSuggested = "false"
      line.dataset.costSuggestionContext = this.contextKey(line)
      if (quality.value === "unknown") {
        const unitCost = line.querySelector("[data-receipt-form-target='unitCost']")
        const provenance = line.querySelector("[data-receipt-form-target='costProvenance']")
        if (unitCost) unitCost.value = ""
        if (provenance) provenance.value = "unknown"
      }
      return
    }

    line.dataset.costAutoSuggested = "false"
    const provenance = line.querySelector("[data-receipt-form-target='costProvenance']")
    if (provenance && (!provenance.value || this.isAutoProvenance(provenance.value))) {
      provenance.value = "manual_receipt"
    }
    const unitCost = line.querySelector("[data-receipt-form-target='unitCost']")
    if (quality && unitCost?.value !== "" && !quality.value) {
      quality.value = "actual"
    }
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

  applySuggestedCost(line) {
    const unitCost = line.querySelector("[data-receipt-form-target='unitCost']")
    if (!unitCost) return

    this.ensureCostMeta(line)
    const context = this.contextKey(line)
    const auto = line.dataset.costAutoSuggested === "true"
    const empty = unitCost.value === ""
    const contextChanged = line.dataset.costSuggestionContext !== context

    if (!auto && !empty) return

    const suggestion = this.suggestionFor(line)
    if (!suggestion) {
      if (auto || empty) {
        unitCost.value = ""
        const quality = line.querySelector("[data-receipt-form-target='costQuality']")
        const provenance = line.querySelector("[data-receipt-form-target='costProvenance']")
        if (quality) quality.value = ""
        if (provenance) provenance.value = ""
        line.dataset.costAutoSuggested = "false"
        line.dataset.costSuggestionContext = context
      }
      return
    }

    if (!auto && !empty && !contextChanged) return

    unitCost.value = suggestion.unit_cost_cents
    const quality = line.querySelector("[data-receipt-form-target='costQuality']")
    if (quality) quality.value = suggestion.cost_quality || "estimated"
    const provenance = line.querySelector("[data-receipt-form-target='costProvenance']")
    if (provenance) provenance.value = suggestion.cost_provenance || ""
    line.dataset.costAutoSuggested = "true"
    line.dataset.costSuggestionContext = context
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

  contextKey(line) {
    const vendorId = this.hasVendorTarget ? this.vendorTarget.value : ""
    const variantId = line.querySelector("[data-receipt-form-target='variantSelect']")?.value || ""
    const poId = line.querySelector("[data-receipt-form-target='purchaseOrderLineSelect']")?.value || ""
    return `${vendorId}:${variantId}:${poId}`
  }

  ensureCostMeta(line) {
    if (line.dataset.costAutoSuggested == null) {
      const unitCost = line.querySelector("[data-receipt-form-target='unitCost']")
      const provenance = line.querySelector("[data-receipt-form-target='costProvenance']")?.value || ""
      const auto = unitCost && unitCost.value !== "" && this.isAutoProvenance(provenance)
      line.dataset.costAutoSuggested = auto ? "true" : "false"
    }
    if (line.dataset.costSuggestionContext == null) {
      line.dataset.costSuggestionContext = this.contextKey(line)
    }
  }

  isAutoProvenance(value) {
    return [
      "purchase_order_expected",
      "purchase_order_list_discount",
      "vendor_source_expected",
      "vendor_list_discount"
    ].includes(value)
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
