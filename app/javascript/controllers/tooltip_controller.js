import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    content: String,
    position: { type: String, default: "top" }
  }

  connect() {
    this.tooltip = null
    this.showTimeout = null
    this.hideTimeout = null
  }

  disconnect() {
    this.hideTooltip()
    if (this.showTimeout) clearTimeout(this.showTimeout)
    if (this.hideTimeout) clearTimeout(this.hideTimeout)
  }

  show(event) {
    event.preventDefault()
    
    // Clear any pending hide
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout)
      this.hideTimeout = null
    }

    // Delay showing tooltip slightly for better UX
    this.showTimeout = setTimeout(() => {
      if (!this.tooltip) {
        this.createTooltip()
      }
      this.positionTooltip()
      this.tooltip.classList.remove("opacity-0", "pointer-events-none")
      this.tooltip.classList.add("opacity-100")
    }, 300)
  }

  hide(event) {
    event.preventDefault()
    
    // Clear any pending show
    if (this.showTimeout) {
      clearTimeout(this.showTimeout)
      this.showTimeout = null
    }

    // Delay hiding tooltip slightly
    this.hideTimeout = setTimeout(() => {
      if (this.tooltip) {
        this.tooltip.classList.remove("opacity-100")
        this.tooltip.classList.add("opacity-0", "pointer-events-none")
      }
    }, 100)
  }

  createTooltip() {
    this.tooltip = document.createElement("div")
    this.tooltip.className = "fixed z-50 px-3 py-2 text-sm font-medium text-white bg-gray-900 dark:bg-gray-800 rounded-lg shadow-lg pointer-events-none transition-opacity duration-200 opacity-0 max-w-xs"
    this.tooltip.innerHTML = this.contentValue || this.element.getAttribute("title") || ""
    
    // Remove title attribute to prevent default browser tooltip
    if (this.element.hasAttribute("title")) {
      this.element.removeAttribute("title")
    }
    
    document.body.appendChild(this.tooltip)
  }

  positionTooltip() {
    if (!this.tooltip) return

    const rect = this.element.getBoundingClientRect()
    const tooltipRect = this.tooltip.getBoundingClientRect()
    const position = this.positionValue

    let top, left

    switch (position) {
      case "top":
        top = rect.top - tooltipRect.height - 8
        left = rect.left + (rect.width / 2) - (tooltipRect.width / 2)
        break
      case "bottom":
        top = rect.bottom + 8
        left = rect.left + (rect.width / 2) - (tooltipRect.width / 2)
        break
      case "left":
        top = rect.top + (rect.height / 2) - (tooltipRect.height / 2)
        left = rect.left - tooltipRect.width - 8
        break
      case "right":
        top = rect.top + (rect.height / 2) - (tooltipRect.height / 2)
        left = rect.right + 8
        break
      default:
        top = rect.top - tooltipRect.height - 8
        left = rect.left + (rect.width / 2) - (tooltipRect.width / 2)
    }

    // Keep tooltip within viewport
    const padding = 8
    if (left < padding) left = padding
    if (left + tooltipRect.width > window.innerWidth - padding) {
      left = window.innerWidth - tooltipRect.width - padding
    }
    if (top < padding) {
      top = rect.bottom + 8 // Switch to bottom if no room on top
    }
    if (top + tooltipRect.height > window.innerHeight - padding) {
      top = window.innerHeight - tooltipRect.height - padding
    }

    this.tooltip.style.top = `${top}px`
    this.tooltip.style.left = `${left}px`
  }

  hideTooltip() {
    if (this.tooltip) {
      this.tooltip.remove()
      this.tooltip = null
    }
  }
}

