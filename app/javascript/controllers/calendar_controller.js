import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dayCell"]
  static values = {
    selectedDate: String,
    view: String,
    year: Number,
    month: Number
  }

  connect() {
    // Initialize view from URL params
    const urlParams = new URLSearchParams(window.location.search)
    const view = urlParams.get("view") || "month"
    this.viewValue = view
    
    // Initialize year and month from URL or current date
    const year = urlParams.get("year") ? parseInt(urlParams.get("year")) : new Date().getFullYear()
    const month = urlParams.get("month") ? parseInt(urlParams.get("month")) : new Date().getMonth() + 1
    this.yearValue = year
    this.monthValue = month

    // Set up keyboard navigation
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundHandleKeydown)
    
    // Set up event delegation for buttons inside Turbo Frames
    // This allows buttons loaded dynamically in day-details frame to call calendar controller methods
    this.boundHandleDelegatedClick = this.handleDelegatedClick.bind(this)
    document.addEventListener("click", this.boundHandleDelegatedClick, true)
    
    // Initialize selected date from URL params or current date
    const selectedDate = urlParams.get("selected_date")
    if (selectedDate) {
      this.selectedDateValue = selectedDate
      this.highlightSelectedDay()
      this.updateDayDetailsFrame(selectedDate)
      
      // Show mobile modal if on mobile and date is selected
      if (window.innerWidth < 1024) {
        const dayDetailsModal = document.getElementById("day-details-modal")
        if (dayDetailsModal) {
          dayDetailsModal.classList.remove("hidden")
          document.body.classList.add("overflow-hidden")
        }
      }
    }

    // Listen for Turbo Frame loads to update day details when calendar grid updates
    const calendarGrid = document.getElementById("calendar-grid")
    if (calendarGrid) {
      calendarGrid.addEventListener("turbo:frame-load", () => {
        // Re-check selected date after grid loads
        const urlParams = new URLSearchParams(window.location.search)
        const selectedDate = urlParams.get("selected_date")
        if (selectedDate) {
          this.selectedDateValue = selectedDate
          this.highlightSelectedDay()
          this.updateDayDetailsFrame(selectedDate)
        }
      })
    }
  }
  
  handleDelegatedClick(event) {
    // Handle clicks on elements with data-calendar-action attribute
    // This allows buttons inside Turbo Frames to call calendar controller methods
    // Only handle if the event hasn't been handled by Stimulus already
    const target = event.target.closest('[data-calendar-action]')
    if (!target) return
    
    // Check if Stimulus already handled this (event was handled by action routing)
    // If the target has a data-action attribute, Stimulus should handle it
    // We only use delegation as a fallback
    if (target.hasAttribute('data-action') && !event.defaultPrevented) {
      // Let Stimulus handle it - don't interfere
      return
    }
    
    const action = target.dataset.calendarAction
    if (action === 'openPlannedTransactionModal') {
      // Create a synthetic event for the method
      const syntheticEvent = {
        currentTarget: target,
        preventDefault: () => event.preventDefault(),
        stopPropagation: () => event.stopPropagation()
      }
      this.openPlannedTransactionModal(syntheticEvent)
    } else if (action === 'closeDayDetails') {
      this.closeDayDetails()
    }
  }

  updateDayDetailsFrame(date) {
    if (!date) return

    // Extract year and month from selected date
    const selectedDateObj = new Date(date + 'T00:00:00')
    const year = selectedDateObj.getFullYear()
    const month = selectedDateObj.getMonth() + 1

    // Update day details panel via Turbo Frame (desktop)
    const dayDetailsFrame = document.getElementById("day-details")
    if (dayDetailsFrame) {
      const newSrc = `/calendar?selected_date=${date}&year=${year}&month=${month}`
      // Only update if src has changed to avoid unnecessary reloads
      if (dayDetailsFrame.src !== newSrc) {
        dayDetailsFrame.src = newSrc
        // Ensure Turbo Frame loads by removing and re-adding src if needed
        // Turbo should auto-load when src changes, but this ensures it works
        if (dayDetailsFrame.load) {
          dayDetailsFrame.load()
        }
      }
    }

    // Handle mobile modal
    const dayDetailsModal = document.getElementById("day-details-modal")
    const dayDetailsMobileFrame = document.getElementById("day-details-mobile")
    if (dayDetailsModal && dayDetailsMobileFrame) {
      // Show modal on mobile if not already visible
      if (window.innerWidth < 1024 && dayDetailsModal.classList.contains("hidden")) {
        dayDetailsModal.classList.remove("hidden")
        document.body.classList.add("overflow-hidden")
      }
      // Update mobile frame if modal is visible
      if (!dayDetailsModal.classList.contains("hidden")) {
        const newMobileSrc = `/calendar?selected_date=${date}&year=${year}&month=${month}`
        if (dayDetailsMobileFrame.src !== newMobileSrc) {
          dayDetailsMobileFrame.src = newMobileSrc
          if (dayDetailsMobileFrame.load) {
            dayDetailsMobileFrame.load()
          }
        }
      }
    }
  }

  selectDay(event) {
    event.preventDefault()
    const date = event.currentTarget.dataset.calendarCellDateValue
    if (!date) return

    this.selectedDateValue = date
    this.highlightSelectedDay()

    // Update URL without page reload
    const url = new URL(window.location)
    url.searchParams.set("selected_date", date)
    window.history.pushState({}, "", url)

    // Update day details frame
    this.updateDayDetailsFrame(date)

    // Show mobile modal if on mobile
    const dayDetailsModal = document.getElementById("day-details-modal")
    if (dayDetailsModal && window.innerWidth < 1024) {
      dayDetailsModal.classList.remove("hidden")
      document.body.classList.add("overflow-hidden")
    }
  }

  highlightSelectedDay() {
    // Remove previous selection
    this.dayCellTargets.forEach(cell => {
      cell.classList.remove("ring-2", "ring-blue-500", "dark:ring-blue-400")
    })

    // Highlight selected day
    const selectedCell = this.dayCellTargets.find(cell => 
      cell.dataset.calendarCellDateValue === this.selectedDateValue
    )
    if (selectedCell) {
      selectedCell.classList.add("ring-2", "ring-blue-500", "dark:ring-blue-400")
    }
  }

  openPlannedTransactionModal(event) {
    // Check if this is an edit link (has turbo_frame attribute)
    const isEditLink = event.currentTarget.dataset.turboFrame === "planned-transaction-form"
    
    const modal = document.getElementById("planned-transaction-modal")
    const formFrame = document.getElementById("planned-transaction-form")
    
    if (modal && formFrame) {
      // Remove hidden class to show modal first
      modal.classList.remove("hidden")
      modal.setAttribute("aria-hidden", "false")
      document.body.classList.add("overflow-hidden")
      
      if (isEditLink) {
        // For edit links, let Turbo Frame handle the loading naturally
        // Just open the modal - Turbo Frame will load the form
        // Don't prevent default - let Turbo Frame work
      } else {
        // For new transactions, prevent default and load new form
        event.preventDefault()
        const date = event.params?.date || event.currentTarget.dataset.calendarDateValue || this.selectedDateValue
        if (date) {
          formFrame.src = `/planned_transactions/new?date=${date}`
        }
      }
    }
  }

  closeDayDetails() {
    // Clear selected date
    this.selectedDateValue = ""
    
    // Update URL
    const url = new URL(window.location)
    url.searchParams.delete("selected_date")
    window.history.pushState({}, "", url)

    // Clear day details frame (desktop)
    const dayDetailsFrame = document.getElementById("day-details")
    if (dayDetailsFrame) {
      dayDetailsFrame.innerHTML = '<div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6"><p class="text-gray-500 dark:text-gray-400 text-center">Select a day to view details</p></div>'
    }

    // Close mobile modal and clear frame
    const dayDetailsModal = document.getElementById("day-details-modal")
    const dayDetailsMobileFrame = document.getElementById("day-details-mobile")
    if (dayDetailsModal) {
      dayDetailsModal.classList.add("hidden")
      document.body.classList.remove("overflow-hidden")
    }
    if (dayDetailsMobileFrame) {
      dayDetailsMobileFrame.innerHTML = '<div class="text-center py-8"><div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div><p class="mt-4 text-gray-600 dark:text-gray-400">Loading day details...</p></div>'
    }

    // Remove selection highlight
    this.highlightSelectedDay()
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleKeydown)
    document.removeEventListener("click", this.boundHandleDelegatedClick, true)
  }

  handleKeydown(event) {
    // Don't handle keyboard events if user is typing in an input/textarea
    if (event.target.tagName === "INPUT" || event.target.tagName === "TEXTAREA" || event.target.isContentEditable) {
      return
    }

    // Don't handle if a modal is open (let modal handle Escape)
    const plannedModal = document.getElementById("planned-transaction-modal")
    const dayDetailsModal = document.getElementById("day-details-modal")
    if (plannedModal && !plannedModal.classList.contains("hidden")) {
      if (event.key === "Escape") {
        // Let modal controller handle it
        return
      }
      // Don't navigate calendar when modal is open
      return
    }

    switch (event.key) {
      case "ArrowLeft":
        event.preventDefault()
        this.navigateDay(-1)
        break
      case "ArrowRight":
        event.preventDefault()
        this.navigateDay(1)
        break
      case "ArrowUp":
        event.preventDefault()
        this.navigateDay(-7)
        break
      case "ArrowDown":
        event.preventDefault()
        this.navigateDay(7)
        break
      case "Enter":
      case " ":
        event.preventDefault()
        if (this.selectedDateValue) {
          this.selectDayByDate(this.selectedDateValue)
        }
        break
      case "Escape":
        if (dayDetailsModal && !dayDetailsModal.classList.contains("hidden")) {
          event.preventDefault()
          this.closeDayDetails()
        }
        break
    }
  }

  navigateDay(days) {
    const currentDate = this.selectedDateValue 
      ? new Date(this.selectedDateValue + 'T00:00:00')
      : new Date()
    
    const newDate = new Date(currentDate)
    newDate.setDate(newDate.getDate() + days)
    
    const dateString = newDate.toISOString().split('T')[0]
    this.selectedDateValue = dateString
    this.highlightSelectedDay()
    
    // Update URL
    const url = new URL(window.location)
    url.searchParams.set("selected_date", dateString)
    
    // Update year/month if needed for month view
    if (this.viewValue === "month") {
      const newYear = newDate.getFullYear()
      const newMonth = newDate.getMonth() + 1
      if (newYear !== this.yearValue || newMonth !== this.monthValue) {
        url.searchParams.set("year", newYear)
        url.searchParams.set("month", newMonth)
        this.yearValue = newYear
        this.monthValue = newMonth
        // Reload calendar grid
        window.location.href = url.toString()
        return
      }
    }
    
    window.history.pushState({}, "", url)
    this.updateDayDetailsFrame(dateString)
    
    // Show mobile modal if on mobile
    const dayDetailsModal = document.getElementById("day-details-modal")
    if (dayDetailsModal && window.innerWidth < 1024) {
      dayDetailsModal.classList.remove("hidden")
      document.body.classList.add("overflow-hidden")
    }
  }

  selectDayByDate(dateString) {
    // Trigger click on the day cell if it exists
    const dayCell = document.querySelector(`[data-calendar-cell-date-value="${dateString}"]`)
    if (dayCell) {
      dayCell.click()
    } else {
      // If cell doesn't exist (e.g., navigated to different month), update URL to load it
      const url = new URL(window.location)
      const date = new Date(dateString + 'T00:00:00')
      url.searchParams.set("selected_date", dateString)
      url.searchParams.set("year", date.getFullYear())
      url.searchParams.set("month", date.getMonth() + 1)
      window.location.href = url.toString()
    }
  }
}

