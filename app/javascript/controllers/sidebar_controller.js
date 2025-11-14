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
  static targets = ["toggleButton", "toggleIcon", "navContainer", "formContainer", "header", "footer"]

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
    
    // Form mode state (managed by modal controllers)
    this.formMode = false
    this.previousState = null // Store state before entering form mode
    this.originalHeaderHTML = null // Store original header HTML for restoration
    
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
    
    // Disable toggle when in form mode
    if (this.formMode) {
      return
    }
    
    this.isExpanded = !this.isExpanded
    this.updateSidebarState()
    this.saveState()
  }
  
  // Enter form mode (called by modal controllers)
  enterFormMode() {
    if (this.formMode) return // Already in form mode
    
    // Store current state
    this.previousState = {
      isExpanded: this.isExpanded
    }
    
    this.formMode = true
    this.updateSidebarState()
    
    // Hide nav, header, and footer; show form container
    if (this.hasNavContainerTarget) {
      this.navContainerTarget.classList.add('hidden')
    }
    if (this.hasHeaderTarget) {
      this.headerTarget.classList.add('hidden')
    }
    if (this.hasFooterTarget) {
      this.footerTarget.classList.add('hidden')
    }
    if (this.hasFormContainerTarget) {
      this.formContainerTarget.classList.remove('hidden')
    }
  }
  
  // Exit form mode (called by modal controllers)
  exitFormMode() {
    if (!this.formMode) return // Not in form mode
    
    this.formMode = false
    
    // Restore previous state
    if (this.previousState) {
      this.isExpanded = this.previousState.isExpanded
      this.previousState = null
    }
    
    this.updateSidebarState()
    
    // Show nav, header, and footer; hide form container
    if (this.hasNavContainerTarget) {
      this.navContainerTarget.classList.remove('hidden')
    }
    if (this.hasHeaderTarget) {
      this.headerTarget.classList.remove('hidden')
    }
    if (this.hasFooterTarget) {
      this.footerTarget.classList.remove('hidden')
    }
    if (this.hasFormContainerTarget) {
      this.formContainerTarget.classList.add('hidden')
    }
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

    // Apply expanded/collapsed/form mode state
    if (this.formMode) {
      // Form mode: w-96 sidebar, lg:ml-96 margin
      this.element.classList.remove('w-16', 'w-48')
      this.element.classList.add('w-96')
      // Update icon to point left (<<)
      this.updateToggleIcon(true)
      
      // Update main content margin
      if (this.mainContentElement) {
        this.mainContentElement.classList.remove('lg:ml-48', 'lg:ml-16')
        this.mainContentElement.classList.add('lg:ml-96')
      }
    } else if (this.isExpanded) {
      // Expanded: w-48 sidebar, lg:ml-48 margin
      this.element.classList.remove('w-16', 'w-96')
      this.element.classList.add('w-48')
      // Update icon to point left (<<)
      this.updateToggleIcon(true)
      
      // Update main content margin
      if (this.mainContentElement) {
        this.mainContentElement.classList.remove('lg:ml-48', 'lg:ml-16', 'lg:ml-96')
        this.mainContentElement.classList.add('lg:ml-48')
      }
    } else {
      // Collapsed: w-16 sidebar, lg:ml-16 margin
      this.element.classList.remove('w-48', 'w-96')
      this.element.classList.add('w-16')
      // Update icon to point right (>>)
      this.updateToggleIcon(false)
      
      // Update main content margin
      if (this.mainContentElement) {
        this.mainContentElement.classList.remove('lg:ml-48', 'lg:ml-16', 'lg:ml-96')
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
