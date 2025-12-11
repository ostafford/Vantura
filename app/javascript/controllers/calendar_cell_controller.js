import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tooltip"]
  static values = {
    date: String
  }

  connect() {
    // Set up hover handlers
    this.boundShowTooltip = this.showTooltip.bind(this)
    this.boundHideTooltip = this.hideTooltip.bind(this)
    
    this.element.addEventListener("mouseenter", this.boundShowTooltip)
    this.element.addEventListener("mouseleave", this.boundHideTooltip)
  }

  disconnect() {
    this.element.removeEventListener("mouseenter", this.boundShowTooltip)
    this.element.removeEventListener("mouseleave", this.boundHideTooltip)
  }

  showTooltip(event) {
    if (this.hasTooltipTarget) {
      // Position tooltip relative to cell
      const rect = this.element.getBoundingClientRect()
      const tooltip = this.tooltipTarget
      
      tooltip.classList.remove("hidden")
      tooltip.style.position = "fixed"
      tooltip.style.left = `${rect.left + rect.width / 2}px`
      tooltip.style.top = `${rect.bottom + 10}px`
      tooltip.style.transform = "translateX(-50%)"
    }
  }

  hideTooltip() {
    if (this.hasTooltipTarget) {
      this.tooltipTarget.classList.add("hidden")
    }
  }

  selectDay(event) {
    event.preventDefault()
    // Get date from data attribute
    const date = this.element.dataset.calendarCellDateValue
    if (!date) return

    // Find the calendar controller (it's on the parent calendar-page div)
    // Since we're inside a Turbo Frame, we need to look outside the frame
    const calendarPage = document.querySelector('.calendar-page[data-controller*="calendar"]')
    
    // Get the Stimulus application instance and find the calendar controller
    const application = this.application
    let calendarController = null
    
    if (calendarPage) {
      calendarController = application.getControllerForElementAndIdentifier(calendarPage, "calendar")
    }
    
    // Fallback: try to find any element with calendar controller (not calendar-cell)
    if (!calendarController) {
      const calendarElement = document.querySelector('[data-controller*="calendar"]:not([data-controller*="calendar-cell"])')
      if (calendarElement) {
        calendarController = application.getControllerForElementAndIdentifier(calendarElement, "calendar")
      }
    }
    
    if (calendarController && typeof calendarController.selectDay === 'function') {
      // Create a synthetic event with the date set on the element's dataset
      // so the calendar controller's selectDay method can read it
      const syntheticEvent = {
        currentTarget: this.element,
        preventDefault: () => event.preventDefault()
      }
      calendarController.selectDay(syntheticEvent)
    } else {
      // Fallback: directly update URL and day details if controller not found
      // This handles cases where Stimulus hasn't initialized the controller yet
      const url = new URL(window.location)
      url.searchParams.set("selected_date", date)
      window.history.pushState({}, "", url)
      
      // Update day details frame - setting src triggers Turbo Frame to load
      const selectedDateObj = new Date(date + 'T00:00:00')
      const year = selectedDateObj.getFullYear()
      const month = selectedDateObj.getMonth() + 1
      
      const dayDetailsFrame = document.getElementById("day-details")
      if (dayDetailsFrame) {
        // Update src to trigger Turbo Frame load
        const newSrc = `/calendar?selected_date=${date}&year=${year}&month=${month}`
        dayDetailsFrame.src = newSrc
        // Try to trigger load if method exists
        if (dayDetailsFrame.load) {
          dayDetailsFrame.load()
        }
      }
      
      // Also update mobile frame if visible
      const dayDetailsMobileFrame = document.getElementById("day-details-mobile")
      if (dayDetailsMobileFrame) {
        const newMobileSrc = `/calendar?selected_date=${date}&year=${year}&month=${month}`
        dayDetailsMobileFrame.src = newMobileSrc
        if (dayDetailsMobileFrame.load) {
          dayDetailsMobileFrame.load()
        }
      }
    }
  }
}

