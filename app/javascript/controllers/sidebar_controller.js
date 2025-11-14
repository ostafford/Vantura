import { Controller } from "@hotwired/stimulus"

/**
 * Sidebar Controller
 * 
 * Manages sidebar expand/collapse state with localStorage persistence.
 * Handles responsive behavior and updates main content margins.
 * 
 * Cross-controller access:
 * - getElementById('application-main-container') - Shared layout element accessed by
 *   multiple controllers (sidebar, month_nav, calendar). This is acceptable as the
 *   element is accessed outside controller scope and shared across controllers.
 * 
 * @see .cursor/rules/conventions/ID_naming_strategy/id_naming_category.mdc (lines 668-678)
 * @see .cursor/rules/development/hotwire/stimulus_controllers.mdc
 */
export default class extends Controller {
  static targets = ["toggleButton", "toggleIcon"]

  connect() {
    // Cross-controller access: application-main-container is shared layout element
    // Per rules: Keep getElementById for elements accessed outside controller scope
    // @see .cursor/rules/conventions/ID_naming_strategy/id_naming_category.mdc (lines 668-678)
    this.mainContentElement = document.getElementById('application-main-container')
    this.sidebarHeader = document.getElementById('sidebar-header')
    this.pageHeader = document.getElementById('page-header')
    
    // Load saved state from localStorage (defaults to collapsed)
    const savedState = localStorage.getItem('sidebarExpanded')
    this.isExpanded = savedState === null ? false : savedState === 'true'
    
    // Set up media query listener for responsive behavior
    this.mediaQuery = window.matchMedia('(min-width: 1024px)')
    this.mediaQueryHandler = this.handleBreakpointChange.bind(this)
    this.mediaQuery.addEventListener('change', this.mediaQueryHandler)
    
    // Set up header height syncing
    this.setupHeaderHeightSync()
    
    // Apply initial state
    this.updateSidebarState()
    
    // Sync after Turbo navigation (for dynamic page loads)
    document.addEventListener('turbo:load', () => {
      this.pageHeader = document.getElementById('page-header')
      this.syncHeaderHeights()
    })
    
    // Also sync after frame updates
    document.addEventListener('turbo:frame-load', () => {
      setTimeout(() => this.syncHeaderHeights(), 100)
    })
  }

  disconnect() {
    if (this.mediaQueryHandler) {
      this.mediaQuery.removeEventListener('change', this.mediaQueryHandler)
    }
    if (this.headerResizeObserver) {
      this.headerResizeObserver.disconnect()
    }
    if (this.resizeHandler) {
      window.removeEventListener('resize', this.resizeHandler)
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
        this.mainContentElement.classList.remove('lg:ml-48', 'lg:ml-16')
      }
      return
    }

    // Desktop: ensure sidebar is visible
    this.element.classList.remove('hidden')
    this.element.classList.add('lg:flex', 'flex')

    // Apply expanded/collapsed state
    if (this.isExpanded) {
      // Expanded: w-48 sidebar, lg:ml-48 margin
      this.element.classList.remove('w-16')
      this.element.classList.add('w-48')
      // Update icon to point left (<<)
      this.updateToggleIcon(true)
    } else {
      // Collapsed: w-16 sidebar, lg:ml-16 margin
      this.element.classList.remove('w-48')
      this.element.classList.add('w-16')
      // Update icon to point right (>>)
      this.updateToggleIcon(false)
    }

    // Update main content margin classes
    if (this.mainContentElement) {
      // Remove all margin classes
      this.mainContentElement.classList.remove('lg:ml-48', 'lg:ml-16')
      
      // Add appropriate margin class
      if (this.isExpanded) {
        this.mainContentElement.classList.add('lg:ml-48')
      } else {
        this.mainContentElement.classList.add('lg:ml-16')
      }
    }
  }

  handleBreakpointChange(event) {
    // Update state when crossing breakpoint
    this.updateSidebarState()
    // Re-setup header height sync if entering desktop view
    if (event.matches) {
      this.setupHeaderHeightSync()
    } else {
      // Clean up when leaving desktop view
      if (this.headerResizeObserver) {
        this.headerResizeObserver.disconnect()
        this.headerResizeObserver = null
      }
      if (this.resizeHandler) {
        window.removeEventListener('resize', this.resizeHandler)
        this.resizeHandler = null
      }
      // Reset sidebar header height
      if (this.sidebarHeader) {
        this.sidebarHeader.style.height = ''
      }
    }
  }

  saveState() {
    localStorage.setItem('sidebarExpanded', this.isExpanded.toString())
  }

  updateToggleIcon(isExpanded) {
    if (!this.hasToggleIconTarget) return

    // Left arrows (<<) when expanded, right arrows (>>) when collapsed
    const leftArrows = 'M11 19l-7-7 7-7m8 14l-7-7 7-7'
    const rightArrows = 'M13 5l7 7-7 7M5 5l7 7-7 7'
    
    const path = this.toggleIconTarget.querySelector('path')
    if (path) {
      path.setAttribute('d', isExpanded ? leftArrows : rightArrows)
    }
  }

  setupHeaderHeightSync() {
    // Only sync on desktop (lg breakpoint and above)
    if (!this.mediaQuery.matches) return

    // Bind resize handler for proper cleanup
    this.resizeHandler = () => this.syncHeaderHeights()

    // Sync heights initially and on resize
    this.syncHeaderHeights()
    window.addEventListener('resize', this.resizeHandler)

    // Use ResizeObserver to watch for content changes in page header
    if (this.pageHeader && window.ResizeObserver) {
      this.headerResizeObserver = new ResizeObserver(() => {
        this.syncHeaderHeights()
      })
      this.headerResizeObserver.observe(this.pageHeader)
    }

    // Also sync after sidebar state changes
    const originalUpdateSidebarState = this.updateSidebarState.bind(this)
    this.updateSidebarState = () => {
      originalUpdateSidebarState()
      // Small delay to ensure DOM has updated
      setTimeout(() => this.syncHeaderHeights(), 50)
    }
  }

  syncHeaderHeights() {
    // Only sync on desktop
    if (!this.mediaQuery.matches) return
    
    // Re-fetch page header in case it wasn't available on connect
    if (!this.pageHeader) {
      this.pageHeader = document.getElementById('page-header')
    }
    
    if (!this.sidebarHeader || !this.pageHeader) return

    // Get the natural height of the page header
    const pageHeaderHeight = this.pageHeader.offsetHeight

    // Set sidebar header to match (only if page header has a valid height)
    if (pageHeaderHeight > 0) {
      this.sidebarHeader.style.height = `${pageHeaderHeight}px`
    }
  }
}
