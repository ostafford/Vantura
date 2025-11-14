import { Controller } from "@hotwired/stimulus"
import { buildUrl } from "helpers/navigation_helper"
import { visitFrame } from "helpers/frame_navigation_helper"

/**
 * Week Navigation Controller
 * 
 * Handles week selection and navigation for calendar week view.
 * Manages week year/month selection, week generation, and week navigation using Turbo Drive.
 * 
 * Navigation uses Turbo Drive with Turbo Frames for automatic URL updates and browser history.
 * Scroll preservation is handled automatically by Turbo Drive.
 * 
 * Coordinates with: month_nav_controller.js (both use shared helpers)
 * 
 * @see .cursor/rules/conventions/ID_naming_strategy/id_naming_category.mdc (lines 668-678)
 * @see .cursor/rules/development/hotwire/stimulus_controllers.mdc
 * @see docs/stimulus-controllers-architecture.md
 */
export default class extends Controller {
  static targets = ["header", "dropdown", "weekYearSelect", "weekMonthSelect", "weekList"]
  static values = {
    urlPattern: String,
    urlType: String,
    currentYear: Number,
    currentMonth: Number,
    currentWeekYear: Number,
    currentWeekMonth: Number,
    currentWeekDay: Number,
    turboFrame: String
  }

  connect() {
    // Close dropdown when clicking outside
    this.boundHandleClickOutside = this.handleClickOutside.bind(this)
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    
    // Track selected week year and month
    this.selectedWeekYear = this.hasCurrentWeekYearValue ? this.currentWeekYearValue : this.currentYearValue
    this.selectedWeekMonth = this.hasCurrentWeekMonthValue ? this.currentWeekMonthValue : this.currentMonthValue
  }

  disconnect() {
    document.removeEventListener('click', this.boundHandleClickOutside)
    document.removeEventListener('keydown', this.boundHandleKeydown)
  }

  togglePicker(event) {
    event.stopPropagation()
    const isOpen = !this.dropdownTarget.classList.contains('hidden')
    
    if (isOpen) {
      this.closePicker()
    } else {
      this.openPicker()
    }
  }

  openPicker() {
    this.dropdownTarget.classList.remove('hidden')
    
    // Reset to current week values when opening
    this.selectedWeekYear = this.hasCurrentWeekYearValue ? this.currentWeekYearValue : this.currentYearValue
    this.selectedWeekMonth = this.hasCurrentWeekMonthValue ? this.currentWeekMonthValue : this.currentMonthValue
    this.weekYearSelectTarget.value = this.selectedWeekYear
    this.weekMonthSelectTarget.value = this.selectedWeekMonth
    
    // Generate weeks for the selected month
    this.generateWeeksForMonth(this.selectedWeekYear, this.selectedWeekMonth)
    
    // Add event listeners
    setTimeout(() => {
      document.addEventListener('click', this.boundHandleClickOutside)
      document.addEventListener('keydown', this.boundHandleKeydown)
    }, 0)
  }

  closePicker() {
    this.dropdownTarget.classList.add('hidden')
    document.removeEventListener('click', this.boundHandleClickOutside)
    document.removeEventListener('keydown', this.boundHandleKeydown)
  }

  handleClickOutside(event) {
    // Check if click is outside both the dropdown and the header button
    const isOutsideDropdown = !this.dropdownTarget.contains(event.target)
    const isOutsideHeader = !this.headerTarget.contains(event.target)
    
    if (isOutsideDropdown && isOutsideHeader) {
      this.closePicker()
    }
  }

  handleKeydown(event) {
    if (event.key === 'Escape') {
      this.closePicker()
    }
  }

  selectWeekYear(event) {
    this.selectedWeekYear = parseInt(event.target.value)
    this.generateWeeksForMonth(this.selectedWeekYear, this.selectedWeekMonth)
  }

  selectWeekMonth(event) {
    this.selectedWeekMonth = parseInt(event.target.value)
    this.generateWeeksForMonth(this.selectedWeekYear, this.selectedWeekMonth)
  }

  generateWeeksForMonth(year, month) {
    // Get the first day of the month
    const firstDay = new Date(year, month - 1, 1)
    // Get the last day of the month
    const lastDay = new Date(year, month, 0)
    
    // Find all weeks that have at least one day in this month
    const weeks = []
    
    // Start from the Monday of the week containing the first day of the month
    const currentWeek = new Date(firstDay)
    const dayOfWeek = currentWeek.getDay()
    const mondayOffset = dayOfWeek === 0 ? 6 : dayOfWeek - 1 // Convert Sunday=0 to Monday offset
    currentWeek.setDate(currentWeek.getDate() - mondayOffset)
    
    // Generate weeks until the Monday is past the last day of the month
    const maxIterations = 10
    let iterations = 0
    
    while (iterations < maxIterations) {
      const weekStart = new Date(currentWeek)
      const weekEnd = new Date(currentWeek)
      weekEnd.setDate(weekEnd.getDate() + 6) // Sunday
      
      // Check if this week has any day in the selected month
      // A week belongs to the month if its Monday is in the month OR if it overlaps with the month
      if (weekStart <= lastDay && weekEnd >= firstDay) {
        weeks.push({
          start: new Date(weekStart),
          end: new Date(weekEnd)
        })
      }
      
      // Move to next week (Monday)
      currentWeek.setDate(currentWeek.getDate() + 7)
      
      // Stop if we've passed the last day of the month
      if (weekStart > lastDay) {
        break
      }
      
      iterations++
    }
    
    // Render weeks
    this.renderWeeks(weeks, year, month)
  }

  renderWeeks(weeks, year, month) {
    const weekList = this.weekListTarget
    weekList.innerHTML = ''
    
    // Get current week for highlighting
    const currentWeekYear = this.hasCurrentWeekYearValue ? this.currentWeekYearValue : this.currentYearValue
    const currentWeekMonth = this.hasCurrentWeekMonthValue ? this.currentWeekMonthValue : this.currentMonthValue
    const currentWeekDay = this.hasCurrentWeekDayValue ? this.currentWeekDayValue : 1
    
    const currentWeekStart = new Date(currentWeekYear, currentWeekMonth - 1, currentWeekDay)
    const currentWeekMonday = new Date(currentWeekStart)
    const dayOfWeek = currentWeekMonday.getDay()
    const mondayOffset = dayOfWeek === 0 ? 6 : dayOfWeek - 1
    currentWeekMonday.setDate(currentWeekMonday.getDate() - mondayOffset)
    
    weeks.forEach(week => {
      const isCurrentWeek = week.start.getTime() === currentWeekMonday.getTime()
      
      const button = document.createElement('button')
      button.type = 'button'
      button.className = `w-full px-3 py-2 text-sm text-left rounded-lg transition-all ${
        isCurrentWeek 
          ? 'bg-primary-700 text-white dark:bg-primary-600' 
          : 'bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-600'
      }`
      button.dataset.action = 'click->week-nav#selectWeek'
      button.dataset.weekStartYear = week.start.getFullYear()
      button.dataset.weekStartMonth = week.start.getMonth() + 1
      button.dataset.weekStartDay = week.start.getDate()
      
      // Format: "Jan 1 - Jan 7" or "Dec 30 - Jan 5"
      const formatDate = (date) => {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
        return `${months[date.getMonth()]} ${date.getDate()}`
      }
      
      const startStr = formatDate(week.start)
      const endStr = formatDate(week.end)
      const endYear = week.end.getFullYear() !== year ? `, ${week.end.getFullYear()}` : ''
      
      button.textContent = `${startStr} - ${endStr}${endYear}`
      
      weekList.appendChild(button)
    })
  }

  selectWeek(event) {
    const year = parseInt(event.currentTarget.dataset.weekStartYear)
    const month = parseInt(event.currentTarget.dataset.weekStartMonth)
    const day = parseInt(event.currentTarget.dataset.weekStartDay)
    
    // Navigate to the selected week
    void this.navigateToWeek(year, month, day)
  }

  async navigateToWeek(year, month, day) {
    // Use shared helper to build URL
    const url = buildUrl(this.urlPatternValue, this.urlTypeValue || 'week', year, month, day)
    
    if (!url) {
      console.error('Failed to build URL for week:', year, month, day)
      return
    }

    const frameId = this.hasTurboFrameValue ? this.turboFrameValue : 'calendar_content'
    const frame = document.getElementById(frameId)
    frame?.dispatchEvent(new CustomEvent("frame-navigation:remember-scroll"))
    await visitFrame(url, frameId)
    
    // Dispatch custom event to notify other controllers of week change
    window.dispatchEvent(new CustomEvent('week:changed', { 
      detail: { year, month, day, url } 
    }))
    
    // Close the picker after navigation
    this.closePicker()
  }

}
