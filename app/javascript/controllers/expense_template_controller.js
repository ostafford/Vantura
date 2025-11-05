import { Controller } from "@hotwired/stimulus"

/**
 * Expense Template Controller
 * 
 * Manages expense template autocomplete search and selection.
 * Provides template suggestions based on merchant/category input.
 * 
 * Cross-controller access: None (all elements are within controller scope)
 * 
 * @see .cursor/rules/conventions/code_style/stimulus_controller_style.mdc
 * @see .cursor/rules/development/hotwire/stimulus_controllers.mdc
 */
export default class extends Controller {
  static targets = ["input", "results", "merchant", "category", "notes", "resultsList", "resultItem"]
  static values = { 
    url: String
  }

  connect() {
    this.timeout = null
    this.templates = []
    
    // Close results when clicking outside
    this.outsideClickHandler = (e) => {
      if (!this.element.contains(e.target)) {
        this.hideResults()
      }
    }
    document.addEventListener("click", this.outsideClickHandler)
    
    // Load all templates on initial focus if input is empty
    this.inputTarget.addEventListener("focus", () => {
      if (!this.inputTarget.value.trim()) {
        this.performSearch("")
      }
    })
    
    // Listen for input events
    this.inputTarget.addEventListener("input", () => {
      const query = this.inputTarget.value.trim()
      this.search(query)
    })
  }

  disconnect() {
    if (this.outsideClickHandler) {
      document.removeEventListener("click", this.outsideClickHandler)
    }
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  search(query) {
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
      
      const response = await fetch(url, { 
        headers: { 
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        } 
      })
      
      if (response.ok) {
        const data = await response.json()
        this.displayResults(data)
      } else {
        console.error("Template search failed with status:", response.status)
        this.hideResults()
      }
    } catch (error) {
      console.error("Template search error:", error)
      this.hideResults()
    }
  }

  displayResults(templates) {
    this.templates = templates
    
    // Use Stimulus target instead of querySelector
    // Per rules: Elements within controller scope should use targets
    if (!this.hasResultsListTarget) return
    
    const ul = this.resultsListTarget
    
    if (templates.length === 0) {
      ul.innerHTML = `
        <li class="px-4 py-3 text-sm text-gray-500 dark:text-gray-400">
          ${this.inputTarget.value.trim() ? 'No templates found' : 'No templates available'}
        </li>
      `
      this.showResults()
      return
    }

    const html = templates.map((template, index) => {
      const merchant = this.escapeHtml(template.merchant || '')
      const category = this.escapeHtml(template.category || 'Uncategorized')
      const amount = template.last_amount ? this.formatCurrency(template.last_amount / 100.0) : 'N/A'
      
      return `
        <li class="px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-800 cursor-pointer border-b border-gray-200 dark:border-gray-700 last:border-b-0" 
            data-index="${index}"
            role="button"
            tabindex="0">
          <div class="flex items-center justify-between">
            <div class="flex-1">
              <p class="text-sm font-medium text-gray-900 dark:text-white">${merchant} - ${category}</p>
              <p class="text-xs text-gray-500 dark:text-gray-400">Last: ${amount}</p>
            </div>
          </div>
        </li>
      `
    }).join("")
    
    ul.innerHTML = html
    
    // Attach click listeners and keyboard navigation
    // Use querySelectorAll for dynamically created items (acceptable per rules)
    // @see .cursor/rules/development/hotwire/stimulus_controllers.mdc
    ul.querySelectorAll('li[data-index]').forEach((item, index) => {
      item.addEventListener('click', () => {
        this.selectTemplate(this.templates[index])
      })
      item.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault()
          this.selectTemplate(this.templates[index])
        }
      })
    })
    
    this.showResults()
  }

  selectTemplate(template) {
    // Populate form fields
    if (this.hasMerchantTarget) {
      this.merchantTarget.value = template.merchant || ''
    }
    if (this.hasCategoryTarget) {
      this.categoryTarget.value = template.category || ''
    }
    if (this.hasNotesTarget) {
      this.notesTarget.value = template.notes || ''
    }
    
    // Clear the search input and hide results
    this.inputTarget.value = ''
    this.hideResults()
    
    // Focus on merchant field for user to continue editing
    if (this.hasMerchantTarget) {
      this.merchantTarget.focus()
    }
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
    if (!text) return ''
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
