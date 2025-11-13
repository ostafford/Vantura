import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="filter"
export default class extends Controller {
  static values = {
    url: String,
    turboFrame: String
  }

  // Navigate to filtered results when selection changes
  async change(event) {
    const filterValue = event.target.value
    const { dataset } = event.target
    const baseUrlString = dataset.filterUrlValue || this.urlValue || window.location.href
    const frameId = dataset.filterTurboFrameValue || this.turboFrameValue
    const frame = frameId ? document.getElementById(frameId) : null

    const targetUrl = new URL(baseUrlString, window.location.origin)
    targetUrl.searchParams.set("filter", filterValue)

    try {
      const response = await fetch(targetUrl.toString(), {
        headers: {
          Accept: "text/vnd.turbo-stream.html, text/html",
          "X-Requested-With": "XMLHttpRequest"
        },
        credentials: "same-origin"
      })

      if (!response.ok) {
        throw new Error(`[filter#change] HTTP ${response.status}`)
      }

      const contentType = response.headers.get("content-type") || ""
      if (contentType.includes("text/vnd.turbo-stream.html")) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
        frame?.dispatchEvent(new CustomEvent("transactions:restore-scroll"))
        return
      }
    } catch (error) {
      console.error("[filter#change] Turbo stream request failed", error)
    }

    if (frameId) {
      Turbo.visit(targetUrl.toString(), { frame: frameId })
      return
    }

    Turbo.visit(targetUrl.toString())
  }
}

