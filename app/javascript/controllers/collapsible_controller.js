import { Controller } from "@hotwired/stimulus"

/**
 * Collapsible Controller
 * 
 * Manages collapsible/expandable section behavior.
 * Toggles visibility of content and updates icon state with rotation.
 * 
 * Cross-controller access: None (all elements are within controller scope)
 * 
 * @see .cursor/rules/conventions/code_style/stimulus_controller_style.mdc
 * @see .cursor/rules/development/hotwire/stimulus_controllers.mdc
 */
export default class extends Controller {
  static targets = ["toggle", "content", "icon"]
  static values = {
    expandedText: { type: String, default: "Hide" },
    collapsedText: { type: String, default: "Show" }
  }

  connect() {
    // Initialize isExpanded property
    this.isExpanded = false
    
    // Initialize state based on content visibility or aria-expanded attribute
    if (this.hasContentTarget) {
      // Check aria-expanded first (most reliable), then fall back to hidden class check
      if (this.hasToggleTarget && this.toggleTarget.hasAttribute('aria-expanded')) {
        this.isExpanded = this.toggleTarget.getAttribute('aria-expanded') === 'true'
      } else {
        // Fall back to checking if content is hidden
        this.isExpanded = !this.contentTarget.classList.contains("hidden")
      }
      this.updateAriaExpanded()
      this.updateToggleText()
    }
  }

  toggle(event) {
    event?.preventDefault()
    
    if (!this.hasContentTarget) return
    
    if (this.isExpanded) {
      // Collapse
      this.contentTarget.classList.add("hidden")
      if (this.hasIconTarget) {
        this.iconTarget.classList.remove("rotate-180")
      }
      this.isExpanded = false
    } else {
      // Expand
      this.contentTarget.classList.remove("hidden")
      if (this.hasIconTarget) {
        this.iconTarget.classList.add("rotate-180")
      }
      this.isExpanded = true
    }
    
    this.updateAriaExpanded()
    this.updateToggleText()
  }

  updateAriaExpanded() {
    if (this.hasToggleTarget) {
      this.toggleTarget.setAttribute("aria-expanded", this.isExpanded.toString())
    }
  }

  updateToggleText() {
    if (this.hasToggleTarget) {
      // Find any element with class containing "toggle-text" for generic support
      // Also check for direct text content if no specific element found
      const textElement = this.toggleTarget.querySelector("[class*='toggle-text']")
      if (textElement) {
        textElement.textContent = this.isExpanded ? this.expandedTextValue : this.collapsedTextValue
      } else {
        // Fallback: if toggle button has direct text content and no child elements with toggle-text class,
        // update the button's text directly (but preserve any icon elements)
        const hasIcon = this.toggleTarget.querySelector('svg, [class*="icon"]')
        if (!hasIcon && this.toggleTarget.textContent.trim()) {
          // Only update if there's no icon (to avoid breaking icon buttons)
          this.toggleTarget.textContent = this.isExpanded ? this.expandedTextValue : this.collapsedTextValue
        }
      }
    }
  }

  closeIfOutside(event) {
    // Only close if clicking outside the controller element
    if (this.isExpanded && !this.element.contains(event.target)) {
      this.toggle(event)
    }
  }
}

