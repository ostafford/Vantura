import { Controller } from "@hotwired/stimulus"
import { formatBalance, formatHeaderData } from "helpers/calendar_header_helper"

/**
 * Calendar Header Controller
 * 
 * Manages sticky header with intersection observers and dynamic data updates.
 * Shows/hides header data based on bento card visibility and updates header
 * content based on visible week (month view) or static week data (week view).
 * 
 * Attached to: Main calendar container
 * 
 * Cross-controller access:
 * - getElementById('calendar-overview-hero-card') - Bento card for visibility detection
 * - getElementById('calendar-header-*') - Header elements accessed by ID
 * - getElementById('calendar-view-container') - Container with data attributes
 * 
 * @see .cursor/rules/conventions/ID_naming_strategy/id_naming_category.mdc (lines 668-678)
 * @see .cursor/rules/development/hotwire/stimulus_controllers.mdc
 */
export default class extends Controller {
  connect() {
    this.setupStickyHeaderObserver()
    this.setupFrameLoadListeners()
  }

  disconnect() {
    this.cleanupObservers()
    this.cleanupFrameLoadListeners()
  }
  
  setupFrameLoadListeners() {
    this.frameLoadHandler = this.handleFrameLoad.bind(this)
    const calendarFrame = document.getElementById('calendar_content')
    if (calendarFrame) {
      calendarFrame.addEventListener('turbo:frame-load', this.frameLoadHandler)
    }
    window.addEventListener('calendar:frame-loaded', this.frameLoadHandler)
  }
  
  cleanupFrameLoadListeners() {
    const calendarFrame = document.getElementById('calendar_content')
    if (calendarFrame && this.frameLoadHandler) {
      calendarFrame.removeEventListener('turbo:frame-load', this.frameLoadHandler)
    }
    if (this.frameLoadHandler) {
      window.removeEventListener('calendar:frame-loaded', this.frameLoadHandler)
    }
  }
  
  cleanupObservers() {
    if (this.weekObserver) {
      this.weekObserver.disconnect()
      this.weekObserver = null
    }
    if (this.calendarObserver) {
      this.calendarObserver.disconnect()
      this.calendarObserver = null
    }
  }
  
  handleFrameLoad() {
    setTimeout(() => {
      this.cleanupObservers()
      this.setupStickyHeaderObserver()
      this.updateHeaderForCurrentView()
    }, 100)
  }
  
  updateHeaderForCurrentView() {
    const weekViewContainer = document.getElementById('calendar-week-view-container')
    const monthViewContainer = document.getElementById('calendar-month-view-container')
    
    if (weekViewContainer) {
      this.updateWeekViewHeader()
    } else if (monthViewContainer) {
      const firstWeekSection = monthViewContainer.querySelector('[data-week-index]')
      if (firstWeekSection) {
        this.updateMonthViewHeader(firstWeekSection)
      }
    }
  }

  // Set up Intersection Observer for calendar viewport detection and sticky header updates
  setupStickyHeaderObserver() {
    const bentoCard = document.getElementById('calendar-overview-hero-card')
    if (!bentoCard) {
      return
    }

    const headerDataContainer = document.getElementById('calendar-header-week-data')
    if (!headerDataContainer) {
      return
    }

    const weekViewContainer = document.getElementById('calendar-week-view-container')
    const monthViewContainer = document.getElementById('calendar-month-view-container')
    const isWeekView = !!weekViewContainer
    const isMonthView = !!monthViewContainer

    // Observer for bento card visibility (show/hide header data when bento card disappears)
    const subtitleElement = document.getElementById('calendar-header-subtitle')
    this.calendarObserver = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (!entry.isIntersecting) {
          // Show header data when bento card disappears from view
          headerDataContainer.classList.remove('hidden')
          // Hide subtitle when week data is shown to make room
          if (subtitleElement) {
            subtitleElement.classList.add('hidden')
          }
        } else {
          // Hide header data when bento card is visible
          headerDataContainer.classList.add('hidden')
          // Show subtitle when week data is hidden
          if (subtitleElement) {
            subtitleElement.classList.remove('hidden')
          }
        }
      })
    }, {
      threshold: 0.1,
      rootMargin: '-100px 0px 0px 0px' // Account for sticky header
    })

    this.calendarObserver.observe(bentoCard)

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

  updateWeekViewHeader() {
    const container = document.getElementById('calendar-view-container')
    if (!container) return

    const headerData = formatHeaderData(
      parseFloat(container.dataset.currentBalance) || 0,
      parseFloat(container.dataset.endOfWeekBalance) || 0,
      container.dataset.endOfWeekDate || '',
      'End of Week'
    )
    this.applyHeaderData(headerData)
  }

  updateMonthViewHeader(weekSection) {
    const container = document.getElementById('calendar-view-container')
    if (!container) return

    const headerData = formatHeaderData(
      parseFloat(container.dataset.currentBalance) || 0,
      parseFloat(container.dataset.endOfMonthBalance) || 0,
      container.dataset.endOfMonthDate || '',
      'End of Month'
    )
    this.applyHeaderData(headerData)
  }
  
  applyHeaderData(headerData) {
    const currentBalanceEl = document.getElementById('calendar-header-current-balance')
    const periodLabelEl = document.getElementById('calendar-header-period-label')
    const periodAmountEl = document.getElementById('calendar-header-period-amount')

    if (currentBalanceEl) {
      currentBalanceEl.textContent = headerData.currentBalance.text
      currentBalanceEl.className = `text-sm sm:text-base font-bold text-right ${headerData.currentBalance.colorClass}`
    }

    if (periodLabelEl && periodAmountEl) {
      periodLabelEl.textContent = headerData.period.label
      periodAmountEl.textContent = headerData.period.amount
      periodAmountEl.className = `text-sm sm:text-base font-bold text-right ${headerData.period.colorClass}`
    }
  }
}

