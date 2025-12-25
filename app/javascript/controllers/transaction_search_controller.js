import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "loading", "count"]
  static values = { url: String }

  connect() {
    this.timeout = null
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  search() {
    clearTimeout(this.timeout)
    
    const query = this.inputTarget.value.trim()
    
    if (query.length === 0) {
      this.clearSearch()
      return
    }

    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove("hidden")
    }
    
    this.timeout = setTimeout(() => {
      this.performSearch(query)
    }, 300) // Debounce 300ms
  }

  async performSearch(query) {
    if (!query || query.length === 0) {
      this.clearSearch()
      return
    }

    const url = `${this.urlValue}?q=${encodeURIComponent(query)}`

    try {
      const response = await fetch(url, {
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-Requested-With": "XMLHttpRequest",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        }
      })
      
      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      } else {
        console.error("Search error:", response.statusText)
        this.showError()
      }
    } catch (error) {
      console.error("Search error:", error)
      this.showError()
    } finally {
      if (this.hasLoadingTarget) {
        this.loadingTarget.classList.add("hidden")
      }
    }
  }

  clearSearch() {
    this.inputTarget.value = ""
    // Reload the transaction list by navigating to base URL
    Turbo.visit(this.urlValue.split('?')[0])
  }

  showError() {
    if (this.hasResultsTarget) {
      this.resultsTarget.innerHTML = `
        <div class="bg-red-50 border border-red-200 rounded-md p-4">
          <p class="text-sm text-red-800">An error occurred while searching. Please try again.</p>
        </div>
      `
    }
  }
}

