import { Controller } from "@hotwired/stimulus"

/**
 * Calendar Controller
 * 
 * Manages calendar view switching, scroll preservation, and day detail toggling.
 * Handles transaction creation events and refreshes calendar display.
 * 
 * Cross-controller access:
 * - getElementById('calendar_content') - Turbo Frame accessed by multiple controllers
 * - getElementById('main-content-container') - Shared layout element accessed by sidebar
 * - getElementById('details-drawer-*') - Drawer elements accessed outside controller scope
 * 
 * @see .cursor/rules/conventions/ID_naming_strategy/id_naming_category.mdc (lines 668-678)
 * @see .cursor/rules/development/hotwire/stimulus_controllers.mdc
 */
// Global flag to ensure scroll listeners are only added once
let scrollListenersAdded = false

export default class extends Controller {
  static targets = ["viewLink", "dayDetails"]

  connect() {
    // Save current view to localStorage for persistence
    // Use Stimulus targets instead of querySelector for elements within controller scope
    this.viewLinkTargets.forEach(link => {
      link.addEventListener('click', (e) => {
        const view = e.currentTarget.dataset.view
        localStorage.setItem('calendarView', view)
      })
    })
    
    // Set up scroll preservation only once globally
    if (!scrollListenersAdded) {
      this.setupScrollPreservation()
      scrollListenersAdded = true
    }

    // Listen for transaction creation events and refresh calendar
    this.transactionCreatedHandler = this.handleTransactionCreated.bind(this)
    window.addEventListener('transaction:created', this.transactionCreatedHandler)

    // Set up sticky header with intersection observer for month view on mobile
    this.setupStickyHeaderObserver()

    // Listen for turbo frame loads to re-initialize header data after navigation
    this.frameLoadHandler = this.handleFrameLoad.bind(this)
    const calendarFrame = document.getElementById('calendar_content')
    if (calendarFrame) {
      calendarFrame.addEventListener('turbo:frame-load', this.frameLoadHandler)
    }
  }

  disconnect() {
    // Clean up event listener
    window.removeEventListener('transaction:created', this.transactionCreatedHandler)
    
    // Clean up frame load listener
    const calendarFrame = document.getElementById('calendar_content')
    if (calendarFrame && this.frameLoadHandler) {
      calendarFrame.removeEventListener('turbo:frame-load', this.frameLoadHandler)
    }
    
    // Clean up intersection observers
    if (this.weekObserver) {
      this.weekObserver.disconnect()
      this.weekObserver = null
    }
    if (this.calendarObserver) {
      this.calendarObserver.disconnect()
      this.calendarObserver = null
    }

    // Clean up scroll preservation listeners
    if (this._scrollPreservationCleanup) {
      this._scrollPreservationCleanup()
      this._scrollPreservationCleanup = null
    }
  }

  handleTransactionCreated(event) {
    // Refresh the calendar frame when a transaction is created
    console.log('Transaction created event received, refreshing calendar...')
    // Cross-controller access: calendar_content Turbo Frame is accessed by multiple controllers
    // Per rules: Keep getElementById for elements accessed outside controller scope
    // @see .cursor/rules/conventions/ID_naming_strategy/id_naming_category.mdc (lines 668-678)
    const calendarFrame = document.getElementById('calendar_content')
    if (calendarFrame) {
      const currentUrl = new URL(window.location.href)
      // Add a timestamp to force reload
      currentUrl.searchParams.set('_refresh', Date.now())
      
      // Navigate to the URL with the frame
      Turbo.visit(currentUrl.toString(), { 
        frame: 'calendar_content',
        action: 'replace' 
      })
    } else {
      console.log('Calendar frame not found, reloading page')
      window.location.reload()
    }
  }

  // Handle turbo frame load to re-initialize header data after navigation
  handleFrameLoad(event) {
    // Wait a brief moment for DOM to be fully ready
    setTimeout(() => {
      // Clean up existing observers before re-initializing
      if (this.weekObserver) {
        this.weekObserver.disconnect()
        this.weekObserver = null
      }
      if (this.calendarObserver) {
        this.calendarObserver.disconnect()
        this.calendarObserver = null
      }

      // Re-initialize intersection observer
      this.setupStickyHeaderObserver()

      // Immediately update header data for current view
      const weekViewContainer = document.getElementById('week-view-container')
      const monthViewContainer = document.getElementById('month-view-container')
      
      if (weekViewContainer) {
        // Week view: update immediately
        this.updateWeekViewHeader()
      } else if (monthViewContainer) {
        // Month view: update with first visible week
        const firstWeekSection = monthViewContainer.querySelector('[data-week-index]')
        if (firstWeekSection) {
          this.updateMonthViewHeader(firstWeekSection)
        }
      }
    }, 100)
  }
  
  setupScrollPreservation() {
    // Note: Month navigation scroll preservation is handled by month_nav_controller.js
    // This method handles scroll preservation for full page loads/navigation (turbo:load)
    // Save scroll position before page is cached
    const beforeCacheHandler = () => {
      if (window.scrollY > 0) {
        sessionStorage.setItem('calendar_scroll_pos', window.scrollY.toString())
      }
    }
    
    // Restore scroll position after page loads
    const loadHandler = () => {
      const savedScroll = sessionStorage.getItem('calendar_scroll_pos')
      if (savedScroll) {
        // Use requestAnimationFrame to ensure DOM is ready
        requestAnimationFrame(() => {
          requestAnimationFrame(() => {
            window.scrollTo(0, parseInt(savedScroll, 10))
            // Clear after use
            sessionStorage.removeItem('calendar_scroll_pos')
          })
        })
      }
    }
    
    document.addEventListener('turbo:before-cache', beforeCacheHandler)
    document.addEventListener('turbo:load', loadHandler)

    // Prevent scroll-to-top on calendar navigation button clicks
    // Turbo Frame already has data-turbo-preserve-scroll="true", but we add extra protection
    const calendarFrame = document.getElementById('calendar_content')
    if (calendarFrame) {
      // Listen for turbo:frame-load to ensure scroll is preserved
      calendarFrame.addEventListener('turbo:frame-load', (event) => {
        // Get the scroll position before the frame loaded
        const savedScroll = sessionStorage.getItem('calendar_scroll_pos_before_frame')
        if (savedScroll) {
          // Restore scroll position after frame loads
          requestAnimationFrame(() => {
            window.scrollTo(0, parseInt(savedScroll, 10))
            sessionStorage.removeItem('calendar_scroll_pos_before_frame')
          })
        }
      })

      // Save scroll position before any navigation within the frame
      const saveScrollBeforeNavigation = (event) => {
        // Only save if clicking calendar navigation buttons
        const target = event.target.closest('a[data-turbo-frame="calendar_content"]')
        if (target) {
          sessionStorage.setItem('calendar_scroll_pos_before_frame', window.scrollY.toString())
        }
      }

      // Listen for clicks on calendar navigation elements
      document.addEventListener('click', saveScrollBeforeNavigation, true)
      
      // Store cleanup function
      this._scrollPreservationCleanup = () => {
        document.removeEventListener('click', saveScrollBeforeNavigation, true)
      }
    }
  }
  
  // Toggle day details (for month view expandable details)
  toggleDay(event) {
    const dayId = event.currentTarget.dataset.dayId
    // Cross-controller access: day details element may be outside controller scope
    // Per rules: Keep getElementById for dynamic ID-based access
    const detailsEl = document.getElementById(dayId)
    if (!detailsEl) return

    // Mobile: open in drawer/modal instead of inline
    const isMobile = window.matchMedia('(max-width: 640px)').matches
    if (isMobile) {
      // Inject details into the mobile drawer and open it
      // Cross-controller access: drawer elements are accessed outside controller scope
      // Per rules: Keep getElementById for elements accessed by multiple controllers
      // @see .cursor/rules/conventions/ID_naming_strategy/id_naming_category.mdc (lines 668-678)
      try {
        const drawer = document.getElementById('details-drawer-modal')
        const panel = document.getElementById('details-drawer-panel')
        const content = document.getElementById('details-drawer-content')
        const mainContent = document.getElementById('main-content-container')
        const closeBtn = document.getElementById('details-drawer-close-button')

        if (drawer && panel && content && mainContent) {
          // Insert cloned HTML so desktop inline panel can remain hidden/independent
          const clone = detailsEl.cloneNode(true)
          clone.classList.remove('hidden', 'mt-6')
          content.innerHTML = ''
          content.appendChild(clone)

          // Open drawer
          drawer.classList.remove('hidden')
          drawer.classList.add('flex')
          // shrink main content on desktop only; on mobile it's full width already
          if (window.innerWidth >= 640) {
            mainContent.classList.add('sm:mr-96')
          }
          // slide in
          panel.classList.remove('translate-x-full')
          panel.classList.add('translate-x-0')

          // Wire close behavior (idempotent)
          if (closeBtn && !this._detailsCloseBound) {
            closeBtn.addEventListener('click', () => {
              // slide out
              panel.classList.remove('translate-x-0')
              panel.classList.add('translate-x-full')
              // restore content
              mainContent.classList.remove('sm:mr-96')
              setTimeout(() => {
                drawer.classList.add('hidden')
                drawer.classList.remove('flex')
                content.innerHTML = ''
              }, 300)
            })
            this._detailsCloseBound = true
          }
        } else {
          // fallback: reveal in place
          detailsEl.classList.remove('hidden')
        }
      } catch (e) {
        // fallback: reveal in place
        detailsEl.classList.remove('hidden')
      }
      return
    }

    // Desktop: inject into this week's inline slot
    const weekContainer = event.currentTarget.closest('[data-week-index]')
    if (!weekContainer) return
    const weekIndex = weekContainer.getAttribute('data-week-index')
    // Cross-controller access: week details slot is dynamically created and accessed
    // Per rules: Keep getElementById for dynamic ID-based access outside controller scope
    const slot = document.getElementById(`week-details-${weekIndex}`)
    if (!slot) return

    // Ensure we have a cache of all detail elements to hide when needed
    // Use Stimulus targets where possible, but day elements are dynamically created
    // Per rules: For dynamic elements with ID patterns, querySelector is acceptable
    // @see .cursor/rules/development/hotwire/stimulus_controllers.mdc
    if (!this.allDayElements) {
      this.allDayElements = document.querySelectorAll('[id^="calendar-day-"]')
    }

    // If this detailsEl is already shown inside slot, toggle it closed
    const alreadyInSlot = slot.contains(detailsEl) && !detailsEl.classList.contains('hidden')
    if (alreadyInSlot) {
      detailsEl.classList.add('hidden')
      return
    }

    // Hide any currently shown details in this slot
    Array.from(slot.children).forEach(child => child.classList.add('hidden'))

    // Move the selected details element into the slot (keeps a single DOM instance)
    // Normalize spacing when moved inline
    detailsEl.classList.remove('mt-6')
    slot.appendChild(detailsEl)
    detailsEl.classList.remove('hidden')

    // Smooth scroll to the inline details
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        detailsEl.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
      })
    })
  }
  
  // Set up Intersection Observer for calendar viewport detection and sticky header updates
  setupStickyHeaderObserver() {
    const calendarContainer = document.getElementById('calendar-view-container')
    if (!calendarContainer) {
      return
    }

    const headerDataContainer = document.getElementById('calendar-header-week-data')
    if (!headerDataContainer) {
      return
    }

    const weekViewContainer = document.getElementById('week-view-container')
    const monthViewContainer = document.getElementById('month-view-container')
    const isWeekView = !!weekViewContainer
    const isMonthView = !!monthViewContainer

    // Observer for calendar container visibility (show/hide header data)
    this.calendarObserver = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          headerDataContainer.classList.remove('hidden')
        } else {
          headerDataContainer.classList.add('hidden')
        }
      })
    }, {
      threshold: 0.1,
      rootMargin: '-100px 0px 0px 0px' // Account for sticky header
    })

    this.calendarObserver.observe(calendarContainer)

    // Week view: show static week data
    if (isWeekView) {
      this.updateWeekViewHeader()
    }

    // Month view: update dynamically as weeks scroll into view
    if (isMonthView) {
      const weekSections = monthViewContainer.querySelectorAll('[data-week-index]')
      if (weekSections.length === 0) {
        return
      }

      // Observer for week sections (month view only)
      this.weekObserver = new IntersectionObserver((entries) => {
        // Track which week is most visible across all entries
        let mostVisibleWeek = null
        let maxVisibility = 0

        entries.forEach(entry => {
          if (entry.isIntersecting) {
            // Calculate visibility ratio (how much of the element is visible)
            const rect = entry.boundingClientRect
            const viewportHeight = window.innerHeight
            const visibleHeight = Math.min(rect.bottom, viewportHeight) - Math.max(rect.top, 0)
            const visibilityRatio = Math.max(0, visibleHeight / rect.height)

            // Update most visible week if this one is more visible
            if (visibilityRatio > maxVisibility) {
              maxVisibility = visibilityRatio
              mostVisibleWeek = entry.target
            }
          }
        })

        // Update sticky header if we have a most visible week
        if (mostVisibleWeek && maxVisibility > 0.1) {
          this.updateMonthViewHeader(mostVisibleWeek)
        }
      }, {
        threshold: [0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0],
        rootMargin: '-100px 0px -50% 0px' // Account for sticky header height
      })

      // Observe all week sections
      weekSections.forEach(section => {
        this.weekObserver.observe(section)
      })
    }
  }

  // Update header for week view (static data)
  updateWeekViewHeader() {
    const calendarContainer = document.getElementById('calendar-view-container')
    if (!calendarContainer) {
      return
    }

    const currentBalance = parseFloat(calendarContainer.dataset.currentBalance) || 0
    const endOfWeekBalance = parseFloat(calendarContainer.dataset.endOfWeekBalance) || 0
    const endOfWeekDate = calendarContainer.dataset.endOfWeekDate || ''

    // Format amounts with color coding
    const formatBalance = (amount) => {
      const isNegative = amount < 0
      const formatted = Math.abs(amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
      const colorClass = isNegative ? 'text-red-700 dark:text-red-200' : 'text-green-700 dark:text-green-200'
      return { text: `${isNegative ? '-' : ''}$${formatted}`, colorClass }
    }

    const currentBalanceData = formatBalance(currentBalance)
    const endOfWeekData = formatBalance(endOfWeekBalance)

    // Update header elements
    const currentBalanceEl = document.getElementById('calendar-header-current-balance')
    const periodLabelEl = document.getElementById('calendar-header-period-label')
    const periodAmountEl = document.getElementById('calendar-header-period-amount')

    if (currentBalanceEl) {
      currentBalanceEl.textContent = currentBalanceData.text
      currentBalanceEl.className = `text-sm sm:text-base font-bold ${currentBalanceData.colorClass}`
    }

    if (periodLabelEl && periodAmountEl) {
      periodLabelEl.textContent = `End of Week (${endOfWeekDate}):`
      periodAmountEl.textContent = endOfWeekData.text
      periodAmountEl.className = `text-sm sm:text-base font-bold ${endOfWeekData.colorClass}`
    }
  }

  // Update header for month view (dynamic data based on visible week)
  updateMonthViewHeader(weekSection) {
    const calendarContainer = document.getElementById('calendar-view-container')
    if (!calendarContainer) {
      return
    }

    const currentBalance = parseFloat(calendarContainer.dataset.currentBalance) || 0
    const endOfMonthBalance = parseFloat(calendarContainer.dataset.endOfMonthBalance) || 0
    const endOfMonthDate = calendarContainer.dataset.endOfMonthDate || ''

    // Format amounts with color coding
    const formatBalance = (amount) => {
      const isNegative = amount < 0
      const formatted = Math.abs(amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
      const colorClass = isNegative ? 'text-red-700 dark:text-red-200' : 'text-green-700 dark:text-green-200'
      return { text: `${isNegative ? '-' : ''}$${formatted}`, colorClass }
    }

    const currentBalanceData = formatBalance(currentBalance)
    const endOfMonthData = formatBalance(endOfMonthBalance)

    // Update header elements
    const currentBalanceEl = document.getElementById('calendar-header-current-balance')
    const periodLabelEl = document.getElementById('calendar-header-period-label')
    const periodAmountEl = document.getElementById('calendar-header-period-amount')

    if (currentBalanceEl) {
      currentBalanceEl.textContent = currentBalanceData.text
      currentBalanceEl.className = `text-sm sm:text-base font-bold ${currentBalanceData.colorClass}`
    }

    if (periodLabelEl && periodAmountEl) {
      periodLabelEl.textContent = `End of Month (${endOfMonthDate}):`
      periodAmountEl.textContent = endOfMonthData.text
      periodAmountEl.className = `text-sm sm:text-base font-bold ${endOfMonthData.colorClass}`
    }
  }
}

