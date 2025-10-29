import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="transactions-nav"
export default class extends Controller {
  static values = { 
    turboFrame: String
  }

  navigate(event) {
    event.preventDefault()
    const link = event.currentTarget
    const url = new URL(link.href, window.location.origin)
    
    // Make the request with Turbo Stream accept header
    fetch(url, { 
      headers: { 
        'Accept': 'text/vnd.turbo-stream.html',
        'Turbo-Frame': this.hasTurboFrameValue ? this.turboFrameValue : undefined
      }
    })
      .then(response => {
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`)
        }
        return response.text()
      })
      .then(html => {
        Turbo.renderStreamMessage(html)
        
        // Sync autocomplete month/year values
        const month = url.searchParams.get('month')
        const year = url.searchParams.get('year')
        const autoEl = document.querySelector('[data-controller~="autocomplete"]')
        if (autoEl && month && year) {
          autoEl.dataset.autocompleteMonthValue = month
          autoEl.dataset.autocompleteYearValue = year
        }
      })
      .catch(err => {
        console.error('Navigation error:', err)
      })
  }
}


