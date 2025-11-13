import { Controller } from "@hotwired/stimulus"

/**
 * Handles navigation controls in the transactions table using Turbo Streams.
 * Ensures pagination and filter actions update the table without a full page refresh.
 */
export default class extends Controller {
  static values = {
    frameId: String
  }

  async navigate(event) {
    const link = event.currentTarget
    if (!(link instanceof HTMLAnchorElement)) {
      return
    }

    const url = link.href
    const frameId = this.frameIdValue || link.dataset.turboFrame
    const frame = frameId ? document.getElementById(frameId) : null

    event.preventDefault()

    try {
      const response = await fetch(url, {
        headers: {
          Accept: "text/vnd.turbo-stream.html, text/html",
          "X-Requested-With": "XMLHttpRequest"
        },
        credentials: "same-origin"
      })

      if (!response.ok) {
        throw new Error(`[transactions-navigation] HTTP ${response.status}`)
      }

      const contentType = response.headers.get("content-type") || ""

      if (contentType.includes("text/vnd.turbo-stream.html")) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
        frame?.dispatchEvent(new CustomEvent("transactions:restore-scroll"))
        return
      }

      if (frameId) {
        Turbo.visit(url, { frame: frameId })
      } else {
        Turbo.visit(url)
      }
    } catch (error) {
      console.error("[transactions-navigation] Turbo stream navigation failed", error)
      if (frameId) {
        Turbo.visit(url, { frame: frameId })
      } else {
        Turbo.visit(url)
      }
    }
  }
}



