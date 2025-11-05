import { Controller } from "@hotwired/stimulus"

/**
 * Sidebar Controller
 * 
 * Manages sidebar expand/collapse state with localStorage persistence.
 * Handles responsive behavior and updates main content margins.
 * 
 * Cross-controller access:
 * - getElementById('main-content-container') - Shared layout element accessed by
 *   multiple controllers (sidebar, month_nav, calendar). This is acceptable as the
 *   element is accessed outside controller scope and shared across controllers.
 * 
 * @see .cursor/rules/conventions/ID_naming_strategy/id_naming_category.mdc (lines 668-678)
 * @see .cursor/rules/development/hotwire/stimulus_controllers.mdc
 */
export default class extends Controller {
  static targets = ["toggleButton"]

  connect() {
    // Cross-controller access: main-content-container is shared layout element
    // Per rules: Keep getElementById for elements accessed outside controller scope
    // @see .cursor/rules/conventions/ID_naming_strategy/id_naming_category.mdc (lines 668-678)
    this.mainContentElement = document.getElementById('main-content-container')
    
    // Load saved state from localStorage (defaults to expanded)
    const savedState = localStorage.getItem('sidebarExpanded')
    this.isExpanded = savedState === null ? true : savedState === 'true'
    
    // Set up media query listener for responsive behavior
    this.mediaQuery = window.matchMedia('(min-width: 1024px)')
    this.mediaQueryHandler = this.handleBreakpointChange.bind(this)
    this.mediaQuery.addEventListener('change', this.mediaQueryHandler)
    
    // Apply initial state
    this.updateSidebarState()
  }

  disconnect() {
    if (this.mediaQueryHandler) {
      this.mediaQuery.removeEventListener('change', this.mediaQueryHandler)
    }
  }

  toggle(event) {
    event?.preventDefault()
    event?.stopPropagation()
    this.isExpanded = !this.isExpanded
    this.updateSidebarState()
    this.saveState()
  }

  updateSidebarState() {
    // Only apply state on desktop (lg breakpoint and above)
    if (!this.mediaQuery.matches) {
      // On mobile: hide sidebar, remove margins
      this.element.classList.add('hidden')
      this.element.classList.remove('lg:flex', 'flex')
      if (this.mainContentElement) {
        this.mainContentElement.classList.remove('lg:ml-64', 'lg:ml-16')
      }
      return
    }

    // Desktop: ensure sidebar is visible
    this.element.classList.remove('hidden')
    this.element.classList.add('lg:flex', 'flex')

    // Apply expanded/collapsed state
    if (this.isExpanded) {
      // Expanded: w-64 sidebar, lg:ml-64 margin
      this.element.classList.remove('w-16')
      this.element.classList.add('w-64')
    } else {
      // Collapsed: w-16 sidebar, lg:ml-16 margin
      this.element.classList.remove('w-64')
      this.element.classList.add('w-16')
    }

    // Update main content margin classes
    if (this.mainContentElement) {
      // Remove all margin classes
      this.mainContentElement.classList.remove('lg:ml-64', 'lg:ml-16')
      
      // Add appropriate margin class
      if (this.isExpanded) {
        this.mainContentElement.classList.add('lg:ml-64')
      } else {
        this.mainContentElement.classList.add('lg:ml-16')
      }
    }
  }

  handleBreakpointChange(event) {
    // Update state when crossing breakpoint
    this.updateSidebarState()
  }

  saveState() {
    localStorage.setItem('sidebarExpanded', this.isExpanded.toString())
  }
}
