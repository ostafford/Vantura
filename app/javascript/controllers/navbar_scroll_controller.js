import { Controller } from "@hotwired/stimulus"

/**
 * Navbar Scroll Controller
 * 
 * Auto-hides navbar when scrolling down, shows when scrolling up.
 * Maximizes vertical screen space on mobile while maintaining easy access to navigation.
 * 
 * Only applies to mobile navigation bar. Desktop navbar remains sticky and always visible.
 * 
 * Cross-controller access: None (all elements are within controller scope)
 * 
 * @see .cursor/rules/conventions/code_style/stimulus_controller_style.mdc
 * @see .cursor/rules/development/hotwire/stimulus_controllers.mdc
 */
export default class extends Controller {
  static values = {
    threshold: { type: Number, default: 10 } // Minimum scroll distance to trigger
  }

  connect() {
    // Find the scrollable container (application-main-container)
    this.scrollContainer = document.getElementById('application-main-container') || window
    this.isWindow = this.scrollContainer === window
    
    // Initialize scroll position
    this.lastScrollY = this.isWindow ? window.scrollY : this.scrollContainer.scrollTop
    this.isVisible = true

    // Bind scroll handler
    this.handleScroll = this.handleScroll.bind(this)
    this.scrollContainer.addEventListener('scroll', this.handleScroll, { passive: true })
  }

  disconnect() {
    this.scrollContainer.removeEventListener('scroll', this.handleScroll)
  }

  handleScroll() {
    const currentScrollY = this.isWindow ? window.scrollY : this.scrollContainer.scrollTop
    const scrollDifference = Math.abs(currentScrollY - this.lastScrollY)

    // Only process if scroll difference exceeds threshold
    if (scrollDifference < this.thresholdValue) {
      return
    }

    // Determine scroll direction
    if (currentScrollY > this.lastScrollY && currentScrollY > this.thresholdValue) {
      // Scrolling down - hide navbar
      this.hide()
    } else if (currentScrollY < this.lastScrollY) {
      // Scrolling up - show navbar
      this.show()
    }

    this.lastScrollY = currentScrollY
  }

  hide() {
    if (!this.isVisible) return
    
    // For bottom navbar: translate down (positive y) to hide
    this.element.classList.add('translate-y-full')
    this.element.classList.remove('translate-y-0')
    this.isVisible = false
  }

  show() {
    if (this.isVisible) return
    
    // For bottom navbar: translate to 0 to show
    this.element.classList.remove('translate-y-full')
    this.element.classList.add('translate-y-0')
    this.isVisible = true
  }
}

