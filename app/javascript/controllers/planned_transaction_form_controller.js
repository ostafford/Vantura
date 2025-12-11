import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["amountInput", "amountCents", "recurrenceToggle", "recurrenceFields", "recurrencePattern", "recurrenceEndDate", "recurrencePreview", "form"]

  connect() {
    // Initialize recurrence fields visibility
    this.toggleRecurrence()
    
    // Convert initial amount from cents to dollars
    const amountCents = this.amountCentsTarget.value
    if (amountCents) {
      this.amountInputTarget.value = (parseFloat(amountCents) / 100).toFixed(2)
    }
    
    // Use event delegation on the form to catch change events on recurrence pattern select
    // This works even if the select is added after connect() runs (Turbo Frame loading)
    this.boundHandleRecurrencePatternChange = (event) => {
      // Check if the changed element is the recurrence pattern select
      if (event.target && event.target.name === 'planned_transaction[recurrence_pattern]') {
        this.updatePreview()
      }
    }
    this.formTarget.addEventListener('change', this.boundHandleRecurrencePatternChange)
    
    // Also trigger updatePreview if pattern is already selected
    setTimeout(() => {
      if (this.recurrenceToggleTarget.checked && this.hasRecurrencePatternTarget && this.recurrencePatternTarget.value && this.hasRecurrencePreviewTarget) {
        this.updatePreview()
      }
    }, 100)
  }
  
  disconnect() {
    // Clean up event listener
    if (this.boundHandleRecurrencePatternChange) {
      this.formTarget.removeEventListener('change', this.boundHandleRecurrencePatternChange)
    }
  }

  updateAmount() {
    // Get and validate input
    const inputValue = this.amountInputTarget.value.trim()
    const dollars = parseFloat(inputValue)
    
    // Validate input
    if (isNaN(dollars) || dollars < 0) {
      // Show error styling
      this.amountInputTarget.classList.add('border-red-500')
      this.amountCentsTarget.value = ''
      return
    }
    
    // Clear error styling
    this.amountInputTarget.classList.remove('border-red-500')
    
    // Convert dollars to cents
    const cents = Math.round(dollars * 100)
    this.amountCentsTarget.value = cents
  }

  toggleRecurrence() {
    const isRecurring = this.recurrenceToggleTarget.checked
    if (isRecurring) {
      this.recurrenceFieldsTarget.classList.remove("hidden")
      // Only call updatePreview if targets are available
      if (this.hasRecurrencePatternTarget && this.hasRecurrenceEndDateTarget && this.hasRecurrencePreviewTarget) {
        this.updatePreview()
      }
    } else {
      this.recurrenceFieldsTarget.classList.add("hidden")
      if (this.hasRecurrencePreviewTarget) {
        this.recurrencePreviewTarget.innerHTML = '<div class="text-xs text-gray-600 dark:text-gray-400"><p>Select a recurrence pattern to see preview</p></div>'
      }
    }
  }

  updatePreview() {
    if (!this.recurrenceToggleTarget.checked) return
    
    // Check if required targets exist before accessing
    if (!this.hasRecurrencePatternTarget || !this.hasRecurrenceEndDateTarget || !this.hasRecurrencePreviewTarget) {
      return
    }

    const pattern = this.recurrencePatternTarget.value
    const endDate = this.recurrenceEndDateTarget.value
    let plannedDate = document.querySelector('input[name="planned_transaction[planned_date]"]')?.value
    
    // If planned_date is not set, use today's date as fallback
    if (!plannedDate) {
      const today = new Date()
      plannedDate = today.toISOString().split('T')[0] // Format as YYYY-MM-DD
    }

    if (!pattern) {
      this.recurrencePreviewTarget.innerHTML = '<div class="text-xs text-gray-600 dark:text-gray-400"><p>Select a recurrence pattern to see preview</p></div>'
      return
    }

    // Generate preview of next 5 occurrences
    const occurrences = this.generateOccurrences(plannedDate, pattern, endDate, 5)
    
    if (occurrences.length === 0) {
      this.recurrencePreviewTarget.innerHTML = '<div class="text-xs text-gray-600 dark:text-gray-400"><p>No occurrences found</p></div>'
      return
    }

    const previewHTML = `
      <div class="space-y-1">
        ${occurrences.map(date => `
          <div class="text-xs text-gray-700 dark:text-gray-300">
            ${new Date(date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
          </div>
        `).join('')}
        ${occurrences.length === 5 ? '<p class="text-xs text-gray-500 dark:text-gray-400 mt-1">...</p>' : ''}
      </div>
    `
    this.recurrencePreviewTarget.innerHTML = previewHTML
  }

  generateOccurrences(startDateStr, pattern, endDateStr, maxOccurrences) {
    // Parse date as local date (avoid timezone issues)
    // Input format: YYYY-MM-DD
    const [year, month, day] = startDateStr.split('-').map(Number)
    const startDate = new Date(year, month - 1, day) // month is 0-indexed
    
    const endDate = endDateStr ? (() => {
      const [y, m, d] = endDateStr.split('-').map(Number)
      return new Date(y, m - 1, d)
    })() : null
    
    const occurrences = []
    let currentDate = new Date(startDate)

    // Skip the start date (it's the first occurrence)
    switch (pattern) {
      case "daily":
        currentDate.setDate(currentDate.getDate() + 1)
        while (occurrences.length < maxOccurrences && (!endDate || currentDate <= endDate)) {
          occurrences.push(new Date(currentDate))
          currentDate.setDate(currentDate.getDate() + 1)
        }
        break
      case "weekly":
        currentDate.setDate(currentDate.getDate() + 7)
        while (occurrences.length < maxOccurrences && (!endDate || currentDate <= endDate)) {
          occurrences.push(new Date(currentDate))
          currentDate.setDate(currentDate.getDate() + 7)
        }
        break
      case "monthly":
        // Handle month boundaries correctly (e.g., Jan 31 -> Feb 28/29)
        currentDate.setMonth(currentDate.getMonth() + 1)
        while (occurrences.length < maxOccurrences && (!endDate || currentDate <= endDate)) {
          occurrences.push(new Date(currentDate))
          // Preserve day of month, handling month boundaries
          const nextMonth = currentDate.getMonth() + 1
          const nextYear = currentDate.getFullYear()
          const dayOfMonth = Math.min(day, new Date(nextYear, nextMonth + 1, 0).getDate())
          currentDate = new Date(nextYear, nextMonth, dayOfMonth)
        }
        break
      case "yearly":
        currentDate.setFullYear(currentDate.getFullYear() + 1)
        while (occurrences.length < maxOccurrences && (!endDate || currentDate <= endDate)) {
          occurrences.push(new Date(currentDate))
          currentDate.setFullYear(currentDate.getFullYear() + 1)
        }
        break
    }

    return occurrences
  }
}

