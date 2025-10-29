import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="filter"
export default class extends Controller {
  static values = {
    url: String,
    turboFrame: String,
  }

  declare urlValue: string
  declare readonly hasTurboFrameValue: boolean
  declare turboFrameValue: string

  // Navigate to filtered results when selection changes
  change(event: Event): void {
    const target = event.target as HTMLSelectElement
    const filterValue = target.value
    const url = `${this.urlValue}?filter=${filterValue}`

    // Use Turbo navigation with frame targeting if specified
    if (this.hasTurboFrameValue && this.turboFrameValue) {
      Turbo.visit(url, { frame: this.turboFrameValue })
    } else {
      // Fallback to regular Turbo navigation
      Turbo.visit(url)
    }
  }
}
