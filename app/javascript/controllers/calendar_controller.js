import { Controller } from "@hotwired/stimulus"
import { setupCalendarScrollPreservation } from "helpers/calendar_scroll_helper"
import { navigateToCalendarDate } from "helpers/calendar_navigation_helper"

/**
 * Calendar Controller
 * 
 * Main coordinator for calendar functionality.
 * Manages view persistence, transaction event handling, and Turbo frame coordination.
 * Delegates specific behaviors to specialized controllers:
 * - calendar-day: Day detail toggling
 * - calendar-header: Sticky header updates
 * - calendar-legend: Legend panel toggle
 * 
 * Cross-controller access:
 * - getElementById('calendar_content') - Turbo Frame accessed by multiple controllers
 * - getElementById('application-main-container') - Shared layout element accessed by sidebar
 * 
 * @see .cursor/rules/conventions/ID_naming_strategy/id_naming_category.mdc (lines 668-678)
 * @see .cursor/rules/development/hotwire/stimulus_controllers.mdc
 */
export default class extends Controller {
  static targets = ["viewLink"]

  connect() {
    // Save current view to localStorage for persistence
    // Use Stimulus targets instead of querySelector for elements within controller scope
    this.viewLinkTargets.forEach(link => {
      link.addEventListener('click', (e) => {
        const view = e.currentTarget.dataset.view
        localStorage.setItem('calendarView', view)
      })
    })
    
    // Set up scroll preservation (helper manages global flag)
    setupCalendarScrollPreservation()

    // Listen for transaction creation events and refresh calendar
    this.transactionCreatedHandler = this.handleTransactionCreated.bind(this)
    window.addEventListener('transaction:created', this.transactionCreatedHandler)

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
      // Re-initialize header controller (it will set up its own observers)
      // We need to trigger the header controller's setup, but since it's a separate controller,
      // we'll dispatch a custom event that it can listen to, or it will auto-connect on DOM ready
      // For now, the header controller will handle its own initialization in connect()
      
      // Immediately update header data for current view
      // Access header controller methods via DOM events or direct reference
      // Since controllers are separate, we'll use a custom event approach
      const weekViewContainer = document.getElementById('calendar-week-view-container')
      const monthViewContainer = document.getElementById('calendar-month-view-container')
      
      // Dispatch event for header controller to handle
      window.dispatchEvent(new CustomEvent('calendar:frame-loaded', {
        detail: {
          weekView: !!weekViewContainer,
          monthView: !!monthViewContainer,
          weekViewContainer,
          monthViewContainer
        }
      }))
    }, 100)
  }

  // Handle date picker change to jump to specific date
  async jumpToDate(event) {
    const selectedDate = new Date(event.target.value)
    if (!selectedDate || isNaN(selectedDate.getTime())) {
      return
    }

    // Get current view from URL or default to month
    const url = new URL(window.location.href)
    const currentView = url.searchParams.get('view') || 'month'
    
    // Use navigation helper to navigate
    await navigateToCalendarDate(selectedDate, currentView, 'calendar_content')
  }
}
