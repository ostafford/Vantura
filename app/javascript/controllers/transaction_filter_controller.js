import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "filterBar", 
    "filterToggleText", 
    "advancedFilters", 
    "advancedToggleText", 
    "analyticsSection", 
    "analyticsToggleText",
    "mobileFilterDrawer",
    "mobileFilterOverlay",
    "summaryBar",
    "stickyFilterPills"
  ]
  static classes = ["hidden"]

  connect() {
    // Filter bar hidden by default, unless there are active filters
    // CRITICAL: Do NOT check localStorage here - it persists across sessions and causes bar to show on fresh page loads
    if (this.hasFilterBarTarget) {
      // Check if there are active filters in the URL
      const urlParams = new URLSearchParams(window.location.search)
      const hasActiveFilters = Array.from(urlParams.keys()).some(key => 
        key !== 'page' && urlParams.get(key) && urlParams.get(key).trim() !== ''
      )
      
      // Only show filter bar if there are active filters in URL
      if (hasActiveFilters) {
        this.filterBarTarget.classList.remove(this.hiddenClass)
        if (this.hasFilterToggleTextTarget) {
          this.filterToggleTextTarget.textContent = "Hide Filters"
        }
        // Update localStorage to match current state
        localStorage.setItem('transactionFiltersOpen', 'true')
      } else {
        // Always hide by default on fresh page load
        this.filterBarTarget.classList.add(this.hiddenClass)
        if (this.hasFilterToggleTextTarget) {
          this.filterToggleTextTarget.textContent = "Show Filters"
        }
        // Clear localStorage on fresh page load with no filters to prevent persistence issues
        localStorage.removeItem('transactionFiltersOpen')
      }
    }

    // Listen for Turbo Frame loads to keep filter bar open after clearing filters
    this.boundHandleFrameLoad = this.handleFrameLoad.bind(this)
    document.addEventListener("turbo:frame-load", this.boundHandleFrameLoad)
    
    // NOTE: We do NOT listen to turbo:load because it fires on initial page load
    // and conflicts with connect(). Only use handleFrameLoad for filter frame updates.
    
    // Set up scroll detection for sticky summary bar
    this.boundHandleScroll = this.handleScroll.bind(this)
    window.addEventListener('scroll', this.boundHandleScroll, { passive: true })
    
    // Initial check
    this.handleScroll()
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this.boundHandleFrameLoad)
    window.removeEventListener('scroll', this.boundHandleScroll)
  }

  handleFrameLoad(event) {
    // Handle filter frame loads (both desktop and mobile)
    // This maintains filter bar state after filter updates (e.g., Clear All, removing filters)
    if (event.target.id === "transaction-filters" || event.target.id === "transaction-filters-mobile") {
      const isMobile = window.innerWidth < 768
      
      if (isMobile) {
        // On mobile, maintain drawer state based on localStorage (if user had it open)
        if (this.hasMobileFilterDrawerTarget) {
          const wasOpen = localStorage.getItem('transactionFiltersOpen') === 'true'
          if (wasOpen && this.mobileFilterDrawerTarget.classList.contains('translate-x-full')) {
            // Drawer should be open but is closed, reopen it
            this.openMobileDrawer()
          }
        }
      } else {
        // On desktop, maintain filter bar state after filter frame updates
        // If localStorage says it was open, keep it open (even after Clear All)
        if (this.hasFilterBarTarget) {
          const wasOpen = localStorage.getItem('transactionFiltersOpen') === 'true'
          const hasActiveFilters = this.checkActiveFilters()
          
          // Keep open if: user had it open OR there are active filters
          if (wasOpen || hasActiveFilters) {
            this.filterBarTarget.classList.remove(this.hiddenClass)
            if (this.hasFilterToggleTextTarget) {
              this.filterToggleTextTarget.textContent = "Hide Filters"
            }
          } else {
            // Ensure hidden if no filters and wasn't manually opened
            this.filterBarTarget.classList.add(this.hiddenClass)
            if (this.hasFilterToggleTextTarget) {
              this.filterToggleTextTarget.textContent = "Show Filters"
            }
          }
        }
      }
    }
  }

  toggleFilters(event) {
    // Prevent default if event exists
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }
    
    // Check if mobile or desktop
    const isMobile = window.innerWidth < 768 // md breakpoint
    
    if (isMobile) {
      this.toggleMobileDrawer()
    } else {
      // Desktop: toggle filter bar
      if (this.hasFilterBarTarget) {
        const isCurrentlyHidden = this.filterBarTarget.classList.contains(this.hiddenClass)
        
        if (isCurrentlyHidden) {
          // Show filter bar
          this.filterBarTarget.classList.remove(this.hiddenClass)
          localStorage.setItem('transactionFiltersOpen', 'true')
          if (this.hasFilterToggleTextTarget) {
            this.filterToggleTextTarget.textContent = "Hide Filters"
          }
        } else {
          // Hide filter bar
          this.filterBarTarget.classList.add(this.hiddenClass)
          localStorage.setItem('transactionFiltersOpen', 'false')
          if (this.hasFilterToggleTextTarget) {
            this.filterToggleTextTarget.textContent = "Show Filters"
          }
        }
      }
    }
  }

  toggleMobileDrawer() {
    if (this.hasMobileFilterDrawerTarget && this.hasMobileFilterOverlayTarget) {
      const isOpen = !this.mobileFilterDrawerTarget.classList.contains('translate-x-full')
      
      if (isOpen) {
        this.closeMobileDrawer()
      } else {
        this.openMobileDrawer()
      }
    }
  }

  openMobileDrawer() {
    if (this.hasMobileFilterDrawerTarget && this.hasMobileFilterOverlayTarget) {
      // Show overlay
      this.mobileFilterOverlayTarget.classList.remove('hidden')
      
      // Slide in drawer
      this.mobileFilterDrawerTarget.classList.remove('translate-x-full')
      
      // Lock body scroll
      document.body.style.overflow = 'hidden'
      
      // Update toggle button text if visible
      if (this.hasFilterToggleTextTarget) {
        this.filterToggleTextTarget.textContent = "Hide Filters"
      }
      
      localStorage.setItem('transactionFiltersOpen', 'true')
    }
  }

  closeMobileDrawer() {
    if (this.hasMobileFilterDrawerTarget && this.hasMobileFilterOverlayTarget) {
      // Hide overlay
      this.mobileFilterOverlayTarget.classList.add('hidden')
      
      // Slide out drawer
      this.mobileFilterDrawerTarget.classList.add('translate-x-full')
      
      // Restore body scroll
      document.body.style.overflow = ''
      
      // Update toggle button text if visible
      if (this.hasFilterToggleTextTarget) {
        this.filterToggleTextTarget.textContent = "Show Filters"
      }
      
      localStorage.setItem('transactionFiltersOpen', 'false')
    }
  }

  toggleAdvanced(event) {
    event.preventDefault()
    if (this.hasAdvancedFiltersTarget) {
      this.advancedFiltersTarget.classList.toggle(this.hiddenClass)
      const isHidden = this.advancedFiltersTarget.classList.contains(this.hiddenClass)
      if (this.hasAdvancedToggleTextTarget) {
        this.advancedToggleTextTarget.textContent = isHidden ? "▼ Advanced Filters" : "▲ Hide Advanced Filters"
      }
    }
  }

  toggleAnalytics(event) {
    event.preventDefault()
    if (this.hasAnalyticsSectionTarget) {
      this.analyticsSectionTarget.classList.toggle(this.hiddenClass)
      const isHidden = this.analyticsSectionTarget.classList.contains(this.hiddenClass)
      if (this.hasAnalyticsToggleTextTarget) {
        this.analyticsToggleTextTarget.textContent = isHidden ? "▶ Show Analytics" : "▼ Hide Analytics"
      }
    }
  }

  removeFilter(event) {
    event.preventDefault()
    const button = event.target.closest("button")
    if (!button) return
    
    const filterName = button.dataset.filterName
    const form = this.element.querySelector("form")
    
    if (form) {
      const input = form.querySelector(`[name="${filterName}"]`)
      if (input) {
        input.value = ""
        // Submit form to update filters
        form.requestSubmit()
      }
    }

    // Ensure filter bar stays visible after removing filter
    // This allows user to continue filtering without reopening
    if (this.hasFilterBarTarget) {
      this.filterBarTarget.classList.remove(this.hiddenClass)
      localStorage.setItem('transactionFiltersOpen', 'true') // Persist state
      if (this.hasFilterToggleTextTarget) {
        this.filterToggleTextTarget.textContent = "Hide Filters"
      }
    }
  }

  savePreset(event) {
    event.preventDefault()
    
    // Placeholder for filter preset functionality
    // This will be implemented in a future update
    // Planned implementation: Save to localStorage and allow quick access to saved filter combinations
    
    const form = this.element.querySelector("form")
    if (!form) return
    
    const presetName = prompt("Name this filter preset (coming soon):")
    if (!presetName) return
    
    // TODO: Implement localStorage-based filter preset saving
    // For now, just show a message
    alert(`Filter preset "${presetName}" will be saved in a future update. This feature will allow you to quickly apply common filter combinations.`)
    
    // Future implementation:
    // const formData = new FormData(form)
    // const filters = Object.fromEntries(formData)
    // localStorage.setItem(`transaction_filter_preset_${presetName}`, JSON.stringify(filters))
  }

  handleScroll() {
    if (!this.hasSummaryBarTarget || !this.hasStickyFilterPillsTarget) return
    
    const summaryBar = this.summaryBarTarget
    const filterBar = this.hasFilterBarTarget ? this.filterBarTarget : null
    
    // Check if summary bar is sticky (has reached top)
    const summaryRect = summaryBar.getBoundingClientRect()
    const isSummarySticky = summaryRect.top <= 64 // topbar height (64px = 16 * 4)
    
    // Check if filter bar is scrolled past or hidden
    const filterBarVisible = filterBar && !filterBar.classList.contains(this.hiddenClass)
    const filterBarScrolledPast = filterBarVisible ? filterBar.getBoundingClientRect().bottom < 0 : true
    
    // Show sticky filter pills if:
    // 1. Summary bar is sticky AND (filter bar is scrolled past OR filter bar is hidden)
    // 2. AND there are active filters
    const hasActiveFilters = this.checkActiveFilters()
    
    if (isSummarySticky && (filterBarScrolledPast || !filterBarVisible) && hasActiveFilters) {
      this.stickyFilterPillsTarget.classList.remove('hidden')
    } else {
      this.stickyFilterPillsTarget.classList.add('hidden')
    }
  }

  checkActiveFilters() {
    // Check URL params for active filters
    const urlParams = new URLSearchParams(window.location.search)
    return Array.from(urlParams.keys()).some(key => 
      key !== 'page' && urlParams.get(key) && urlParams.get(key).trim() !== ''
    )
  }

  get hiddenClass() {
    return this.hiddenClasses?.[0] || "hidden"
  }
}

