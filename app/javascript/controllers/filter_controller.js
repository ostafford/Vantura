import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="filter"
export default class extends Controller {
  static values = {
    url: String,
    turboFrame: String
  }

  // Navigate to filtered results when selection changes
  change(event) {
    const filterValue = event.target.value
    const url = this.urlValue + '?filter=' + filterValue
    
    // Use Turbo navigation with frame targeting if specified
    if (this.hasTurboFrameValue && this.turboFrameValue) {
      Turbo.visit(url, { frame: this.turboFrameValue })
    } else {
      // Fallback to regular Turbo navigation
      Turbo.visit(url)
    }
  }
}

