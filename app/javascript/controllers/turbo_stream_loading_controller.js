import { Controller } from "@hotwired/stimulus"

// Controller to show loading states during Turbo Stream updates
// Usage: Add data-controller="turbo-stream-loading" to elements that receive Turbo Stream updates
export default class extends Controller {
  static targets = ["overlay", "content"]

  connect() {
    // Listen for Turbo Stream events
    this.element.addEventListener("turbo:before-stream-render", this.showLoading.bind(this))
    this.element.addEventListener("turbo:after-stream-render", this.hideLoading.bind(this))
    this.element.addEventListener("turbo:frame-load", this.hideLoading.bind(this))
  }

  disconnect() {
    this.element.removeEventListener("turbo:before-stream-render", this.showLoading.bind(this))
    this.element.removeEventListener("turbo:after-stream-render", this.hideLoading.bind(this))
    this.element.removeEventListener("turbo:frame-load", this.hideLoading.bind(this))
  }

  showLoading(event) {
    // Only show loading if this element is the target of the stream action
    const targetId = event.detail?.target || event.target?.getAttribute("target")
    if (targetId && this.element.id === targetId) {
      this.createOverlay()
      if (this.hasContentTarget) {
        this.contentTarget.classList.add("opacity-50")
      } else {
        this.element.classList.add("opacity-50")
      }
    }
  }

  hideLoading(event) {
    this.removeOverlay()
    if (this.hasContentTarget) {
      this.contentTarget.classList.remove("opacity-50")
    } else {
      this.element.classList.remove("opacity-50")
    }
  }

  createOverlay() {
    // Don't create duplicate overlays
    if (this.hasOverlayTarget && this.overlayTarget) {
      return
    }

    const overlay = document.createElement("div")
    overlay.className = "absolute inset-0 flex items-center justify-center bg-gray-100 bg-opacity-75 dark:bg-gray-800 dark:bg-opacity-75 z-10"
    overlay.setAttribute("data-turbo-stream-loading-target", "overlay")
    
    // Add spinner
    overlay.innerHTML = `
      <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 dark:border-blue-400"></div>
    `

    // Ensure parent has relative positioning
    const computedStyle = window.getComputedStyle(this.element)
    if (computedStyle.position === "static") {
      this.element.style.position = "relative"
    }

    this.element.appendChild(overlay)
  }

  removeOverlay() {
    if (this.hasOverlayTarget) {
      this.overlayTarget?.remove()
    } else {
      const overlay = this.element.querySelector("[data-turbo-stream-loading-target='overlay']")
      overlay?.remove()
    }
  }
}

