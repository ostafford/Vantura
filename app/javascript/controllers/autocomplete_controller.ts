import { Controller } from '@hotwired/stimulus'
import { escapeHtml } from '../utils/html'

interface TransactionResult {
  id: number
  description: string
  amount: number
  transaction_date: string
  category: string | null
}

// Connects to data-controller="autocomplete"
export default class extends Controller {
  static targets = ['input', 'results']
  static values = {
    url: String,
    minLength: Number,
    month: Number,
    year: Number,
  }

  declare readonly hasInputTarget: boolean
  declare readonly inputTarget: HTMLInputElement
  declare readonly hasResultsTarget: boolean
  declare readonly resultsTarget: HTMLElement
  declare urlValue: string
  declare minLengthValue: number
  declare readonly hasMonthValue: boolean
  declare monthValue: number
  declare readonly hasYearValue: boolean
  declare yearValue: number

  private timeout: number | null = null
  private searchResults: TransactionResult[] = []
  private searchHandler!: () => void
  private outsideClickHandler?: (e: MouseEvent) => void

  connect(): void {
    this.minLengthValue = this.minLengthValue || 3
    this.timeout = null
    this.searchResults = []
    this.searchHandler = this.search.bind(this)

    // Listen for input events
    this.inputTarget.addEventListener('input', this.searchHandler)

    // Close results when clicking outside
    this.outsideClickHandler = (e: MouseEvent) => {
      const target = e.target as Node
      if (!this.element.contains(target)) {
        this.hideResults()
      }
    }
    document.addEventListener('click', this.outsideClickHandler)
  }

  disconnect(): void {
    this.inputTarget.removeEventListener('input', this.searchHandler)
    if (this.outsideClickHandler) {
      document.removeEventListener('click', this.outsideClickHandler)
    }
    if (this.timeout !== null) {
      window.clearTimeout(this.timeout)
    }
  }

  search(): void {
    const query = this.inputTarget.value.trim()

    // If query is too short, reset table to current month via Turbo Stream
    if (query.length < this.minLengthValue) {
      if (this.timeout !== null) window.clearTimeout(this.timeout)
      this.timeout = window.setTimeout(() => {
        void this.performSearch('')
      }, 150)
      this.hideResults()
      return
    }

    // Debounce the search
    if (this.timeout !== null) {
      window.clearTimeout(this.timeout)
    }

    this.timeout = window.setTimeout(() => {
      void this.performSearch(query)
    }, 300)
  }

  async performSearch(query: string): Promise<void> {
    try {
      const url = new URL(this.urlValue, window.location.origin)
      if (query && query.length > 0) {
        url.searchParams.set('q', query)
      }

      // Add month/year from Stimulus values
      if (this.hasMonthValue) {
        url.searchParams.set('month', this.monthValue.toString())
      }
      if (this.hasYearValue) {
        url.searchParams.set('year', this.yearValue.toString())
      }

      const response = await fetch(url.toString(), {
        headers: { Accept: 'text/vnd.turbo-stream.html' },
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
        this.hideResults()
      } else {
        console.error('Search failed with status:', response.status)
        this.hideResults()
      }
    } catch (error) {
      console.error('Search error:', error)
      this.hideResults()
    }
  }

  displayResults(data: TransactionResult[]): void {
    if (data.length === 0) {
      this.resultsTarget.innerHTML = `
        <li class="px-4 py-3 text-sm text-gray-500 dark:text-gray-400">No results found</li>
      `
      this.showResults()
      return
    }

    this.searchResults = data // Store results for selection

    const html = data
      .map((transaction, index) => {
        const amount =
          transaction.amount < 0
            ? `<span class="text-red-600 dark:text-red-400">${this.formatCurrency(transaction.amount)}</span>`
            : `<span class="text-green-600 dark:text-green-400">${this.formatCurrency(transaction.amount)}</span>`

        const date = new Date(transaction.transaction_date).toLocaleDateString('en-US', {
          month: 'short',
          day: 'numeric',
          year: 'numeric',
        })

        return `
        <li class="px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-800 cursor-pointer border-b border-gray-200 dark:border-gray-700 last:border-b-0" 
            data-index="${index}">
          <div class="flex items-center justify-between">
            <div class="flex-1">
              <p class="text-sm font-medium text-gray-900 dark:text-white">${escapeHtml(transaction.description)}</p>
              <p class="text-xs text-gray-500 dark:text-gray-400">${date} • ${escapeHtml(transaction.category || 'Uncategorized')}</p>
            </div>
            <div class="ml-4 text-sm font-medium">${amount}</div>
          </div>
        </li>
      `
      })
      .join('')

    this.resultsTarget.innerHTML = html

    // Attach click listeners to the list items
    this.resultsTarget.querySelectorAll<HTMLElement>('li[data-index]').forEach((item, index) => {
      item.addEventListener('click', () => {
        this.selectItem(this.searchResults[index])
      })
    })

    this.showResults()
  }

  selectItem(transaction: TransactionResult): void {
    // Navigate to the transaction details or just scroll to it on the page
    // Since there's no show page, let's go to transactions index and scroll to the transaction
    const transactionDate = new Date(transaction.transaction_date)
    const year = transactionDate.getFullYear()
    const month = String(transactionDate.getMonth() + 1).padStart(2, '0')

    // Navigate to that month's transactions page
    window.location.href = `/transactions/${year}/${month}`
  }

  showResults(): void {
    this.resultsTarget.classList.remove('hidden')
  }

  hideResults(): void {
    this.resultsTarget.classList.add('hidden')
  }

  formatCurrency(value: number): string {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'AUD',
      minimumFractionDigits: 2,
    }).format(value)
  }
}
