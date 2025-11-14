import { Controller } from "@hotwired/stimulus"

/**
 * Autocomplete Controller
 * 
 * Provides autocomplete search functionality for transactions.
 * Displays search results and handles selection with Turbo Stream navigation.
 * 
 * Cross-controller access: None (all elements are within controller scope)
 * 
 * @see .cursor/rules/conventions/code_style/stimulus_controller_style.mdc
 * @see .cursor/rules/development/hotwire/stimulus_controllers.mdc
 */
export default class extends Controller {
  static targets = ["input", "results"]
  static values = { 
    url: String,
    minLength: Number,
    month: Number,
    year: Number,
    startDate: String,
    endDate: String
  }

  connect() {
    this.minLengthValue = this.minLengthValue || 3
    this.timeout = null
    this.search = this.search.bind(this)
    this.handleEnterKey = this.handleEnterKey.bind(this)
    
    // Listen for input events
    this.inputTarget.addEventListener("input", this.search)
    
    // Listen for Enter key to trigger search
    this.inputTarget.addEventListener("keydown", this.handleEnterKey)
    
    // Close results when clicking outside
    this.outsideClickHandler = (e) => {
      if (!this.element.contains(e.target)) {
        this.hideResults()
      }
    }
    document.addEventListener("click", this.outsideClickHandler)
  }

  disconnect() {
    this.inputTarget.removeEventListener("input", this.search)
    this.inputTarget.removeEventListener("keydown", this.handleEnterKey)
    if (this.outsideClickHandler) {
      document.removeEventListener("click", this.outsideClickHandler)
    }
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  search() {
    const query = this.inputTarget.value.trim()
    const previousQuery = this.previousQuery || ""
    
    // Clear any pending search
    if (this.timeout) {
      clearTimeout(this.timeout)
      this.timeout = null
    }
    
    // If input becomes empty (was not empty before), reset search
    if (query.length === 0 && previousQuery.length > 0) {
      this.timeout = setTimeout(() => {
        this.performSearch("")
      }, 150)
      this.hideResults()
      this.previousQuery = ""
      return
    }
    
    // If query is too short, just hide results - don't trigger a search
    if (query.length < this.minLengthValue) {
      this.hideResults()
      this.previousQuery = query
      return
    }

    // Debounce the search
    this.previousQuery = query
    this.timeout = setTimeout(() => {
      this.performSearch(query)
    }, 300)
  }

  handleEnterKey(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      const query = this.inputTarget.value.trim()
      
      if (query.length >= this.minLengthValue) {
        if (this.timeout) {
          clearTimeout(this.timeout)
        }
        this.performSearch(query)
      } else if (query.length === 0) {
        // If empty, reset search
        if (this.timeout) {
          clearTimeout(this.timeout)
        }
        this.performSearch("")
      }
    }
  }

  async performSearch(query) {
    try {
      const url = new URL(this.urlValue, window.location.origin)
      if (query && query.length > 0) {
        url.searchParams.set('q', query)
      }
      
      // Add month/year from Stimulus values
      if (this.hasMonthValue) {
        url.searchParams.set('month', this.monthValue)
      }
      if (this.hasYearValue) {
        url.searchParams.set('year', this.yearValue)
      }
      
      // Add date range from Stimulus values or URL params
      if (this.hasStartDateValue) {
        url.searchParams.set('start_date', this.startDateValue)
      } else {
        // Try to get from URL params if not in Stimulus values
        const urlParams = new URLSearchParams(window.location.search)
        const startDate = urlParams.get('start_date')
        if (startDate) {
          url.searchParams.set('start_date', startDate)
        }
      }
      
      if (this.hasEndDateValue) {
        url.searchParams.set('end_date', this.endDateValue)
      } else {
        // Try to get from URL params if not in Stimulus values
        const urlParams = new URLSearchParams(window.location.search)
        const endDate = urlParams.get('end_date')
        if (endDate) {
          url.searchParams.set('end_date', endDate)
        }
      }
      
      const response = await fetch(url, { headers: { Accept: 'text/vnd.turbo-stream.html' } })
      
      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
        this.hideResults()
      } else {
        console.error("Search failed with status:", response.status)
        this.hideResults()
      }
    } catch (error) {
      console.error("Search error:", error)
      this.hideResults()
    }
  }

  showResults() {
    this.resultsTarget.classList.remove("hidden")
  }

  hideResults() {
    this.resultsTarget.classList.add("hidden")
  }
}

