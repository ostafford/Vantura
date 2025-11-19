import { Controller } from "@hotwired/stimulus"
import { buildUrl } from "helpers/navigation_helper"
import { visitFrame } from "helpers/frame_navigation_helper"

/**
 * Month Navigation Controller
 * 
 * Handles month/year selection and navigation for calendar and projects pages.
 * Manages dropdown toggle, year/month selection, and month navigation using Turbo Drive.
 * 
 * Navigation uses Turbo Drive with Turbo Frames for automatic URL updates and browser history.
 * Scroll preservation is handled automatically by Turbo Drive.
 * 
 * Coordinates with: week_nav_controller.js (both use shared helpers)
 * 
 * @see .cursor/rules/conventions/ID_naming_strategy/id_naming_category.mdc (lines 668-678)
 * @see .cursor/rules/development/hotwire/stimulus_controllers.mdc
 * @see docs/stimulus-controllers-architecture.md
 */
export default class extends Controller {
  static targets = ["header", "dropdown", "yearSelect", "monthButton"]
  static values = {
    urlPattern: String,
    urlType: String,
    currentYear: Number,
    currentMonth: Number,
    turboFrame: String
  }

  connect() {
    // Close dropdown when clicking outside
    this.boundHandleClickOutside = this.handleClickOutside.bind(this)
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    
    // Track selected year and month for navigation
    this.selectedYear = this.currentYearValue
    this.selectedMonth = this.currentMonthValue
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
    
    // Reset to current values when opening
    this.selectedYear = this.currentYearValue
    this.selectedMonth = this.currentMonthValue
    this.yearSelectTarget.value = this.selectedYear
    
    // Update month button states
    this.updateMonthButtonStates()
    
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

  selectYear(event) {
    this.selectedYear = parseInt(event.target.value)
    this.updateMonthButtonStates()
  }

  selectMonth(event) {
    this.selectedMonth = parseInt(event.currentTarget.dataset.monthValue)
    
    // Navigate to the selected month/year
    void this.navigateToMonth(this.selectedYear, this.selectedMonth)
  }

  updateMonthButtonStates() {
    this.monthButtonTargets.forEach(button => {
      const monthNum = parseInt(button.dataset.monthValue)
      // Check if this is the currently displayed month (based on current values, not selected)
      const isCurrentMonth = monthNum === this.currentMonthValue && 
                             this.selectedYear === this.currentYearValue
      
      // Update classes based on current month display
      if (isCurrentMonth) {
        button.classList.remove('btn-toggle-inactive')
        button.classList.add('btn-toggle-active')
      } else {
        button.classList.remove('btn-toggle-active')
        button.classList.add('btn-toggle-inactive')
      }
    })
  }

  async navigateToMonth(year, month) {
    // Use shared helper to build URL
    const url = buildUrl(this.urlPatternValue, this.urlTypeValue || 'path', year, month)
    
    if (!url) {
      console.error('Failed to build URL for year:', year, 'month:', month)
      return
    }

    const frameId = this.hasTurboFrameValue ? this.turboFrameValue : 'calendar_content'
    const frame = document.getElementById(frameId)
    frame?.dispatchEvent(new CustomEvent("frame-navigation:remember-scroll"))
    await visitFrame(url, frameId)
    
    // Dispatch custom event to notify other controllers of month change
    window.dispatchEvent(new CustomEvent('month:changed', { 
      detail: { year, month, url } 
    }))
    
    // Close the picker after navigation
    this.closePicker()
  }

}