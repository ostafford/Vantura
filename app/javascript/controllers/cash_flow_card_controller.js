// app/javascript/controllers/cash_flow_card_controller.js

import { Controller } from "@hotwired/stimulus"

/**
 * Cash Flow Card Controller
 * 
 * Manages:
 * - Expand/collapse of merchant/category section
 * - Toggle between merchant and category view
 * - Responsive behavior (expanded on desktop, collapsed on mobile)
 */
export default class extends Controller {
  static targets = ["content", "toggleButton", "merchantView", "categoryView", "merchantButton", "categoryButton"]
  static values = {
    defaultExpanded: { type: Boolean, default: true },
    viewType: { type: String, default: "merchant" }
  }

  connect() {
    // Set initial expanded state based on screen size
    // CSS handles responsive: hidden md:block means hidden on mobile, visible on desktop
    const isDesktop = window.innerWidth >= 768 // md breakpoint
    this.isExpanded = isDesktop ? this.defaultExpandedValue : false
    
    // Set initial view type from value or default to merchant
    this.currentViewType = this.viewTypeValue || "merchant"
    
    // Apply initial state
    this.updateExpandedState()
    this.updateViewType()
    
    // Listen for window resize to adjust on mobile/desktop switch
    this.handleResize = this.handleResize.bind(this)
    window.addEventListener("resize", this.handleResize)
  }

  disconnect() {
    window.removeEventListener("resize", this.handleResize)
  }

  handleResize() {
    const isDesktop = window.innerWidth >= 768
    // Only auto-expand on desktop if it was previously expanded
    if (isDesktop && this.defaultExpandedValue) {
      this.isExpanded = true
      this.updateExpandedState()
    } else if (!isDesktop) {
      // Collapse on mobile
      this.isExpanded = false
      this.updateExpandedState()
    }
  }

  toggle() {
    this.isExpanded = !this.isExpanded
    this.updateExpandedState()
  }

  updateExpandedState() {
    if (this.hasContentTarget) {
      // Toggle hidden class while preserving md:block for responsive behavior
      if (this.isExpanded) {
        // Remove hidden, but ensure md:block is present for desktop visibility
        this.contentTarget.classList.remove("hidden")
        if (!this.contentTarget.classList.contains("md:block")) {
          this.contentTarget.classList.add("md:block")
        }
        this.contentTarget.setAttribute("aria-hidden", "false")
      } else {
        // Add hidden, but keep md:block for when user expands again
        this.contentTarget.classList.add("hidden")
        this.contentTarget.setAttribute("aria-hidden", "true")
      }
    }

    if (this.hasToggleButtonTarget) {
      this.toggleButtonTarget.setAttribute("aria-expanded", this.isExpanded.toString())
      
      // Update button text
      const textElement = this.toggleButtonTarget.querySelector("span")
      if (textElement) {
        textElement.textContent = this.isExpanded ? "Hide Details" : "Show Details"
      }
      
      // Update icon rotation if present
      const icon = this.toggleButtonTarget.querySelector("svg")
      if (icon) {
        if (this.isExpanded) {
          icon.classList.remove("rotate-180")
        } else {
          icon.classList.add("rotate-180")
        }
      }
    }
  }

  switchToMerchant() {
    this.currentViewType = "merchant"
    this.updateViewType()
  }

  switchToCategory() {
    this.currentViewType = "category"
    this.updateViewType()
  }

  updateViewType() {
    // Update merchant/category views
    if (this.hasMerchantViewTarget) {
      if (this.currentViewType === "merchant") {
        this.merchantViewTarget.classList.remove("hidden")
        this.merchantViewTarget.setAttribute("aria-hidden", "false")
      } else {
        this.merchantViewTarget.classList.add("hidden")
        this.merchantViewTarget.setAttribute("aria-hidden", "true")
      }
    }

    if (this.hasCategoryViewTarget) {
      if (this.currentViewType === "category") {
        this.categoryViewTarget.classList.remove("hidden")
        this.categoryViewTarget.setAttribute("aria-hidden", "false")
      } else {
        this.categoryViewTarget.classList.add("hidden")
        this.categoryViewTarget.setAttribute("aria-hidden", "true")
      }
    }

    // Update button states
    if (this.hasMerchantButtonTarget) {
      if (this.currentViewType === "merchant") {
        this.merchantButtonTarget.classList.remove("btn-toggle-inactive")
        this.merchantButtonTarget.classList.add("btn-toggle-active")
      } else {
        this.merchantButtonTarget.classList.remove("btn-toggle-active")
        this.merchantButtonTarget.classList.add("btn-toggle-inactive")
      }
    }

    if (this.hasCategoryButtonTarget) {
      if (this.currentViewType === "category") {
        this.categoryButtonTarget.classList.remove("btn-toggle-inactive")
        this.categoryButtonTarget.classList.add("btn-toggle-active")
      } else {
        this.categoryButtonTarget.classList.remove("btn-toggle-active")
        this.categoryButtonTarget.classList.add("btn-toggle-inactive")
      }
    }
  }
}

