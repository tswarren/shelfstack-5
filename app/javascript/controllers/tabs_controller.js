import { Controller } from "@hotwired/stimulus"

// Progressive-enhancement tabs: server renders anchors + all panels;
// this controller adds tablist semantics, panel hiding, keyboard nav, and
// fragment synchronization.
//
// History updates go through Turbo.navigator.history when available so
// tab fragment changes do not desync Turbo Drive (native pushState alone
// can leave the URL updated while the next visit fails to swap content).
export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    this.enhance()
    this.activateFromFragment()
    this._onPopState = () => {
      if (!this.element.isConnected) return
      this.activateFromFragment()
    }
    this._onBeforeCache = () => this.revealAllPanels()
    this._onBeforeVisit = (event) => this.prepareForVisit(event)

    window.addEventListener("popstate", this._onPopState)
    document.addEventListener("turbo:before-cache", this._onBeforeCache)
    document.addEventListener("turbo:before-visit", this._onBeforeVisit)
  }

  disconnect() {
    window.removeEventListener("popstate", this._onPopState)
    document.removeEventListener("turbo:before-cache", this._onBeforeCache)
    document.removeEventListener("turbo:before-visit", this._onBeforeVisit)
  }

  enhance() {
    const list = this.element.querySelector("[data-tabs-target='list']")
    if (list) {
      list.setAttribute("role", "tablist")
    }

    this.tabTargets.forEach((tab, index) => {
      const panelId = tab.getAttribute("href")?.replace(/^#/, "")
      tab.setAttribute("role", "tab")
      if (panelId) tab.setAttribute("aria-controls", panelId)
      tab.setAttribute("tabindex", index === 0 ? "0" : "-1")
      tab.setAttribute("aria-selected", index === 0 ? "true" : "false")
      tab.addEventListener("click", this.onTabClick)
      tab.addEventListener("keydown", this.onTabKeydown)
    })

    this.panelTargets.forEach((panel) => {
      const id = panel.id
      const tab = this.tabTargets.find((t) => t.getAttribute("href") === `#${id}`)
      panel.setAttribute("role", "tabpanel")
      if (tab?.id) panel.setAttribute("aria-labelledby", tab.id)
    })
  }

  onTabClick = (event) => {
    event.preventDefault()
    const tab = event.currentTarget
    const id = tab.getAttribute("href")?.replace(/^#/, "")
    if (!id) return
    this.activate(id, { updateHistory: true })
  }

  onTabKeydown = (event) => {
    const keys = ["ArrowLeft", "ArrowRight", "Home", "End"]
    if (!keys.includes(event.key)) return

    event.preventDefault()
    const tabs = this.tabTargets
    const current = tabs.indexOf(event.currentTarget)
    if (current < 0) return

    let next = current
    if (event.key === "ArrowRight") next = (current + 1) % tabs.length
    if (event.key === "ArrowLeft") next = (current - 1 + tabs.length) % tabs.length
    if (event.key === "Home") next = 0
    if (event.key === "End") next = tabs.length - 1

    const tab = tabs[next]
    tab.focus()
    const id = tab.getAttribute("href")?.replace(/^#/, "")
    if (id) this.activate(id, { updateHistory: true })
  }

  activateFromFragment() {
    const hash = window.location.hash.replace(/^#/, "")
    const known = this.panelTargets.some((panel) => panel.id === hash)
    this.activate(known ? hash : this.defaultPanelId(), { updateHistory: false })
  }

  defaultPanelId() {
    return this.panelTargets[0]?.id || "overview"
  }

  activate(panelId, { updateHistory }) {
    const activeId = this.panelTargets.some((p) => p.id === panelId)
      ? panelId
      : this.defaultPanelId()

    this.tabTargets.forEach((tab) => {
      const id = tab.getAttribute("href")?.replace(/^#/, "")
      const selected = id === activeId
      tab.setAttribute("aria-selected", selected ? "true" : "false")
      tab.setAttribute("tabindex", selected ? "0" : "-1")
      tab.classList.toggle("is-active", selected)
    })

    this.panelTargets.forEach((panel) => {
      const selected = panel.id === activeId
      panel.hidden = !selected
      panel.classList.toggle("is-active", selected)
    })

    if (updateHistory) this.updateFragment(activeId)
  }

  updateFragment(activeId) {
    const url = new URL(window.location.href)
    const nextHash = `#${activeId}`
    if (url.hash === nextHash) return
    url.hash = activeId

    const turboHistory = window.Turbo?.navigator?.history
    if (turboHistory && typeof turboHistory.push === "function") {
      turboHistory.push(url)
      return
    }

    // Fallback: replaceState avoids stacking entries that desync Turbo Drive.
    history.replaceState(history.state, "", url)
  }

  // Leaving for another page: restore panels so Turbo's snapshot is complete,
  // and strip a dangling fragment that can confuse same-document handling.
  prepareForVisit(event) {
    const location = event.detail?.url
    if (!location) return

    try {
      const next = new URL(location, window.location.origin)
      if (next.pathname === window.location.pathname && next.search === window.location.search) {
        return
      }
    } catch (_error) {
      return
    }

    this.revealAllPanels()
  }

  revealAllPanels() {
    this.panelTargets.forEach((panel) => {
      panel.hidden = false
    })
  }
}
