import { Controller } from "@hotwired/stimulus"

/**
 * Form Drawer Controller
 * 
 * Manages right-side drawer for form content (replaces sidebar form mode).
 * Handles opening/closing animations and content injection.
 * 
 * @see .cursor/rules/development/hotwire/stimulus_controllers.mdc
 */
export default class extends Controller {
  static targets = ["content"]

  connect() {
    this.isOpen = false
  }

  open() {
    if (this.isOpen) return
    
    this.isOpen = true
    this.element.classList.remove('translate-x-full', 'hidden')
    this.element.classList.add('translate-x-0')
    
    // Add margin to main content to prevent overlap
    const mainContent = document.getElementById('application-main-container')
    if (mainContent) {
      mainContent.classList.add('lg:mr-96')
    }
  }

  close() {
    if (!this.isOpen) return
    
    this.isOpen = false
    this.element.classList.remove('translate-x-0')
    this.element.classList.add('translate-x-full')
    
    // Remove margin from main content
    const mainContent = document.getElementById('application-main-container')
    if (mainContent) {
      mainContent.classList.remove('lg:mr-96')
    }
    
    // Clear content after animation
    setTimeout(() => {
      if (this.hasContentTarget) {
        this.contentTarget.innerHTML = ''
      }
      // Hide drawer after clearing
      this.element.classList.add('hidden')
    }, 300)
  }

  setContent(html) {
    if (this.hasContentTarget) {
      this.contentTarget.innerHTML = html
    }
  }

  setContentElement(element) {
    if (this.hasContentTarget) {
      // Clear existing content
      this.contentTarget.innerHTML = ''
      // Append the element
      this.contentTarget.appendChild(element)
    }
  }

  clearContent() {
    if (this.hasContentTarget) {
      this.contentTarget.innerHTML = ''
    }
  }
}

