import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="calendar"
export default class extends Controller {
  // Toggle day details
  toggleDay(event) {
    const dayId = event.currentTarget.dataset.dayId
    const element = document.getElementById(dayId)
    
    if (!element) return
    
    if (element.classList.contains('hidden')) {
      // Hide all other day details first
      document.querySelectorAll('[id^="day-"]').forEach(el => {
        if (el.id !== dayId) {
          el.classList.add('hidden')
        }
      })
      // Show this day's details
      element.classList.remove('hidden')
      // Smooth scroll to the details
      setTimeout(() => {
        element.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
      }, 100)
    } else {
      // Hide this day's details
      element.classList.add('hidden')
    }
  }
}

