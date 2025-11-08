import { Controller } from "@hotwired/stimulus"

/**
 * Mobile Menu Controller
 * 
 * Manages mobile navigation drawer behavior.
 * Handles slide-in/out drawer animation, overlay backdrop, escape key, and body scroll lock.
 * 
 * Cross-controller access: None (all elements are within controller scope)
 * 
 * @see .cursor/rules/conventions/code_style/stimulus_controller_style.mdc
 * @see .cursor/rules/development/hotwire/stimulus_controllers.mdc
 */
export default class extends Controller {
  static targets = ["button", "drawer", "overlay"]

  connect() {
    // Bind escape key handler
    this.escapeHandler = this.handleEscape.bind(this)
    document.addEventListener('keydown', this.escapeHandler)
    
    // Initialize closed state
    this.isOpen = false
  }

  disconnect() {
    document.removeEventListener('keydown', this.escapeHandler)
    // Ensure menu is closed and body scroll is restored when controller disconnects
    if (this.isOpen) {
      this.close()
    }
  }

  toggle(event) {
    event?.preventDefault()
    
    if (this.isOpen) {
      this.close(event)
    } else {
      this.open(event)
    }
  }

  open(event) {
    event?.preventDefault()
    
    if (this.isOpen) return
    
    // Show overlay
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove('hidden')
      // Trigger opacity transition
      setTimeout(() => {
        this.overlayTarget.classList.remove('opacity-0')
        this.overlayTarget.classList.add('opacity-100')
      }, 10)
    }
    
    // Slide drawer in from right
    if (this.hasDrawerTarget) {
      this.drawerTarget.classList.remove('translate-x-full')
      this.drawerTarget.classList.add('translate-x-0')
    }
    
    // Update button aria-expanded
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute('aria-expanded', 'true')
    }
    
    // Lock body scroll
    document.body.style.overflow = 'hidden'
    
    this.isOpen = true
  }

  close(event) {
    event?.preventDefault()
    
    if (!this.isOpen) return
    
    // Hide overlay
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove('opacity-100')
      this.overlayTarget.classList.add('opacity-0')
      // Hide after transition
      setTimeout(() => {
        this.overlayTarget.classList.add('hidden')
      }, 300)
    }
    
    // Slide drawer out to right
    if (this.hasDrawerTarget) {
      this.drawerTarget.classList.remove('translate-x-0')
      this.drawerTarget.classList.add('translate-x-full')
    }
    
    // Update button aria-expanded
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute('aria-expanded', 'false')
    }
    
    // Restore body scroll
    document.body.style.overflow = ''
    
    this.isOpen = false
  }

  closeOnOverlay(event) {
    // Only close if clicking directly on the overlay
    if (event.target === this.overlayTarget) {
      this.close(event)
    }
  }

  handleEscape(event) {
    if (event.key === 'Escape' && this.isOpen) {
      this.close(event)
    }
  }
}

