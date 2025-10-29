import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="autocomplete"
export default class extends Controller {
  static targets = ["input", "results"]
  static values = { 
    url: String,
    minLength: Number,
    month: Number,
    year: Number
  }

  connect() {
    this.minLengthValue = this.minLengthValue || 3
    this.timeout = null
    this.searchResults = []
    this.search = this.search.bind(this)
    
    // Listen for input events
    this.inputTarget.addEventListener("input", this.search)
    
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
    if (this.outsideClickHandler) {
      document.removeEventListener("click", this.outsideClickHandler)
    }
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  search() {
    const query = this.inputTarget.value.trim()
    
    // If query is too short, reset table to current month via Turbo Stream
    if (query.length < this.minLengthValue) {
      if (this.timeout) clearTimeout(this.timeout)
      this.timeout = setTimeout(() => {
        this.performSearch("")
      }, 150)
      this.hideResults()
      return
    }

    // Debounce the search
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
    
    this.timeout = setTimeout(() => {
      this.performSearch(query)
    }, 300)
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

  displayResults(data) {
    if (data.length === 0) {
      this.resultsTarget.innerHTML = `
        <li class="px-4 py-3 text-sm text-gray-500 dark:text-gray-400">No results found</li>
      `
      this.showResults()
      return
    }

    this.searchResults = data // Store results for selection

    const html = data.map((transaction, index) => {
      const amount = transaction.amount < 0 
        ? `<span class="text-red-600 dark:text-red-400">${this.formatCurrency(transaction.amount)}</span>`
        : `<span class="text-green-600 dark:text-green-400">${this.formatCurrency(transaction.amount)}</span>`
      
      const date = new Date(transaction.transaction_date).toLocaleDateString('en-US', { 
        month: 'short', 
        day: 'numeric', 
        year: 'numeric' 
      })
      
      return `
        <li class="px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-800 cursor-pointer border-b border-gray-200 dark:border-gray-700 last:border-b-0" 
            data-index="${index}">
          <div class="flex items-center justify-between">
            <div class="flex-1">
              <p class="text-sm font-medium text-gray-900 dark:text-white">${this.escapeHtml(transaction.description)}</p>
              <p class="text-xs text-gray-500 dark:text-gray-400">${date} • ${this.escapeHtml(transaction.category || 'Uncategorized')}</p>
            </div>
            <div class="ml-4 text-sm font-medium">${amount}</div>
          </div>
        </li>
      `
    }).join("")
    
    this.resultsTarget.innerHTML = html
    
    // Attach click listeners to the list items
    this.resultsTarget.querySelectorAll('li[data-index]').forEach((item, index) => {
      item.addEventListener('click', () => {
        this.selectItem(this.searchResults[index])
      })
    })
    
    this.showResults()
  }

  selectItem(transaction) {
    // Navigate to the transaction details or just scroll to it on the page
    // Since there's no show page, let's go to transactions index and scroll to the transaction
    const transactionDate = new Date(transaction.transaction_date)
    const year = transactionDate.getFullYear()
    const month = String(transactionDate.getMonth() + 1).padStart(2, '0')
    
    // Navigate to that month's transactions page
    window.location.href = `/transactions/${year}/${month}`
  }

  showResults() {
    this.resultsTarget.classList.remove("hidden")
  }

  hideResults() {
    this.resultsTarget.classList.add("hidden")
  }

  formatCurrency(value) {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'AUD',
      minimumFractionDigits: 2
    }).format(value)
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}

