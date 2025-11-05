import { Controller } from "@hotwired/stimulus"

/**
 * Transactions Navigation Controller
 * 
 * Handles Turbo Stream navigation for transactions list with scroll preservation.
 * Syncs autocomplete controller month/year values after navigation.
 * 
 * Cross-controller access:
 * - querySelector('[data-controller~="autocomplete"]') - Accesses autocomplete controller
 *   for syncing month/year values. This is acceptable as it's accessing another controller's
 *   element outside this controller's scope.
 * 
 * @see .cursor/rules/conventions/ID_naming_strategy/id_naming_category.mdc (lines 668-678)
 * @see .cursor/rules/development/hotwire/stimulus_controllers.mdc
 */
export default class extends Controller {
  static values = { 
    turboFrame: String,
    autocompleteController: String // Optional: ID of autocomplete controller to sync
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
        // Cross-controller access: querySelector acceptable for accessing other controller
        // Per rules: Elements accessed outside controller scope can use querySelector/getElementById
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


