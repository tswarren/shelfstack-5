import { Controller } from "@hotwired/stimulus"

// Progressive enhancement for merchandise class: keep the canonical flat
// select as the only named field; cascade selects are presentation-only.
export default class extends Controller {
  static targets = ["canonical", "primary", "secondary", "minor", "cascade"]
  static values = { tree: Object }

  connect() {
    this.nodes = this.treeValue.nodes || []
    this.byId = Object.fromEntries(this.nodes.map((n) => [String(n.id), n]))
    this.populate("primary", this.nodes.filter((n) => n.level === "primary"))
    this.syncFromCanonical()
    this.cascadeTargets.forEach((el) => { el.hidden = false })
    this.canonicalTarget.classList.add("visually-hidden")
    this.canonicalTarget.setAttribute("tabindex", "-1")
    this.canonicalTarget.setAttribute("aria-hidden", "true")
  }

  primaryChanged() {
    const parentId = this.primaryTarget.value
    this.populate("secondary", this.childrenOf(parentId, "secondary"))
    this.populate("minor", [])
    this.writeCanonical(parentId || "")
  }

  secondaryChanged() {
    const parentId = this.secondaryTarget.value
    this.populate("minor", this.childrenOf(parentId, "minor"))
    this.writeCanonical(parentId || this.primaryTarget.value || "")
  }

  minorChanged() {
    const id = this.minorTarget.value
    this.writeCanonical(id || this.secondaryTarget.value || this.primaryTarget.value || "")
  }

  childrenOf(parentId, level) {
    if (!parentId) return []
    return this.nodes.filter((n) => n.level === level && String(n.parent_id) === String(parentId))
  }

  populate(level, nodes) {
    const select = this[`${level}Target`]
    const current = select.value
    select.innerHTML = ""
    const blank = document.createElement("option")
    blank.value = ""
    blank.textContent = level === "primary" ? "—" : "Any / stop here"
    select.appendChild(blank)
    nodes.forEach((node) => {
      const option = document.createElement("option")
      option.value = String(node.id)
      option.textContent = node.active === false ? `${node.name} (inactive)` : node.name
      select.appendChild(option)
    })
    if (nodes.some((n) => String(n.id) === current)) {
      select.value = current
    } else {
      select.value = ""
    }
  }

  writeCanonical(id) {
    this.canonicalTarget.value = id ? String(id) : ""
  }

  syncFromCanonical() {
    const selectedId = this.canonicalTarget.value || String(this.treeValue.selected_id || "")
    if (!selectedId || !this.byId[selectedId]) {
      this.primaryTarget.value = ""
      this.populate("secondary", [])
      this.populate("minor", [])
      return
    }

    const node = this.byId[selectedId]
    const chain = []
    let cursor = node
    while (cursor) {
      chain.unshift(cursor)
      cursor = cursor.parent_id ? this.byId[String(cursor.parent_id)] : null
    }

    const primary = chain.find((n) => n.level === "primary")
    const secondary = chain.find((n) => n.level === "secondary")
    const minor = chain.find((n) => n.level === "minor")

    if (primary) {
      this.primaryTarget.value = String(primary.id)
      this.populate("secondary", this.childrenOf(primary.id, "secondary"))
    }
    if (secondary) {
      this.secondaryTarget.value = String(secondary.id)
      this.populate("minor", this.childrenOf(secondary.id, "minor"))
    } else {
      this.populate("minor", [])
    }
    if (minor) {
      this.minorTarget.value = String(minor.id)
    }
  }
}
