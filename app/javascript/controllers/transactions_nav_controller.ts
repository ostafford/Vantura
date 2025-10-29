import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="transactions-nav"
export default class extends Controller {
  static values = {
    turboFrame: String,
  }

  declare readonly hasTurboFrameValue: boolean
  declare turboFrameValue: string

  navigate(event: Event): void {
    event.preventDefault()
    const link = event.currentTarget as HTMLAnchorElement
    const url = new URL(link.href, window.location.origin)

    // Make the request with Turbo Stream accept header
    const headers: HeadersInit = {
      Accept: 'text/vnd.turbo-stream.html',
    }

    if (this.hasTurboFrameValue && this.turboFrameValue) {
      headers['Turbo-Frame'] = this.turboFrameValue
    }

    fetch(url.toString(), { headers })
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
          autoEl.setAttribute('data-autocomplete-month-value', month)
          autoEl.setAttribute('data-autocomplete-year-value', year)
        }
      })
      .catch(err => {
        console.error('Navigation error:', err)
      })
  }
}
